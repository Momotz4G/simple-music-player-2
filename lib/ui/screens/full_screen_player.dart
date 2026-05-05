import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:window_manager/window_manager.dart';

import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/song_model.dart';
import '../../services/canvas_service.dart';
import '../../l10n/app_localizations.dart';

import '../components/player/device_selector_dialog.dart';
import '../components/smart_art.dart';
import '../../providers/lyrics_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../utils/japanese_romanizer.dart';
import '../../utils/chinese_romanizer.dart';
import '../../utils/korean_romanizer.dart';
import '../../utils/translation_service.dart';
import '../../services/spotify_service.dart';
import '../../services/db_service.dart';
import 'package:flutter/scheduler.dart';
import '../widgets/smooth_highlight_text.dart';

class FullScreenPlayer extends ConsumerStatefulWidget {
  const FullScreenPlayer({super.key});

  @override
  ConsumerState<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends ConsumerState<FullScreenPlayer>
    with WindowListener, SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  String _loadingStatus = "";

  // UI State
  bool _showControls = true;
  Timer? _hideTimer;

  // Window State to remember previous state
  bool _wasMaximizedOnEntry = false;

  // Lyrics State
  bool _showLyrics = false;
  final ItemScrollController _lyricScrollController = ItemScrollController();
  final ItemPositionsListener _lyricPositionsListener =
      ItemPositionsListener.create();
  int _activeLyricIndex = -1;
  bool _isUserScrolling = false;
  Timer? _scrollResumeTimer;

  // Smooth position ticker
  Ticker? _ticker;
  double _smoothPosition = 0;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Desktop-only: window listener
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }

    // 1. Setup Window & Ticker
    _initWindowMode();
    _ticker = createTicker(_onTick);
    _ticker!.start();

    // 2. Setup UI Timers
    _startHideTimer();

    // 3. Load Art & Lyrics
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final song = ref.read(playerProvider).currentSong;
      if (song != null) {
        _autoLoadCanvas(song.title, song.artist);
        ref.read(lyricsProvider.notifier).loadLyrics(
              song.filePath,
              song.title,
              song.artist,
              song.duration,
            );
      }
    });
  }

  @override
  void dispose() {
    // Desktop-only: window listener
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    _videoController?.dispose();
    _hideTimer?.cancel();
    _ticker?.dispose();
    _scrollResumeTimer?.cancel();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    
    final player = ref.read(playerProvider);
    if (!player.isPlaying) {
      _lastTick = elapsed;
      return;
    }

    if (_lastTick != Duration.zero) {
      final delta = (elapsed - _lastTick).inMicroseconds / 1000000.0;
      _smoothPosition += delta;
      
      // Sync with real position periodically
      final realPos = player.currentPosition;
      if ((realPos - _smoothPosition).abs() > 0.1) {
        _smoothPosition = realPos;
      }

      // High-frequency sync check
      if (!_isUserScrolling && _showLyrics) {
        final lyricsState = ref.read(lyricsProvider);
        if (lyricsState.parsedLyrics.isNotEmpty) {
          _syncLyrics(_smoothPosition, lyricsState.parsedLyrics, lyricsState.syncOffset);
        }
      }
    }
    _lastTick = elapsed;
  }


  // --------------------------------------------------------------------------
  // 🚀 SIMPLE WINDOW LOGIC (No Hacks)
  // --------------------------------------------------------------------------

  Future<void> _initWindowMode() async {
    // Desktop-only window management
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    // Check if user was maximized before we started
    bool isMaximized = await windowManager.isMaximized();

    if (mounted) {
      setState(() {
        _wasMaximizedOnEntry = isMaximized;
      });
    }

    // Only go full screen if they were already maximized (desktop feel)
    if (isMaximized) {
      // 🚀 WAIT FOR TRANSITION TO FINISH
      // We wait for the animation to complete to avoid stuttering during the Hero/Fade transition.
      // The OS window resize is heavy and shouldn't happen while we are animating.
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.animation != null) {
        void handler(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            route.animation!.removeStatusListener(handler);
            if (mounted) windowManager.setFullScreen(true);
          }
        }

        route.animation!.addStatusListener(handler);
        // In case it's already done (rare race condition)
        if (route.animation!.status == AnimationStatus.completed) {
          if (mounted) windowManager.setFullScreen(true);
        }
      } else {
        // Fallback if no route animation
        Future.delayed(const Duration(milliseconds: 850), () {
          if (mounted) windowManager.setFullScreen(true);
        });
      }
    }
  }

  // 🚀 SIMPLE EXIT
  // Just revert full screen and close. No delays.
  Future<void> _exitAndPop() async {
    // Desktop-only: window management
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 1. Revert Full Screen
      if (_wasMaximizedOnEntry) {
        // Await the transition to ensure window state is clean before popping
        await windowManager.setFullScreen(false);

        // Small buffer to let OS catch up
        await Future.delayed(const Duration(milliseconds: 50));

        if (mounted) {
          await windowManager.maximize();
        }
      }
    }

    // 2. Pop immediately after window is restored
    if (mounted) Navigator.pop(context);
  }

  // --------------------------------------------------------------------------
  // ⏳ TIMER & CONTROLS
  // --------------------------------------------------------------------------

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onUserInteraction() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
  }

  // --------------------------------------------------------------------------
  // 🎨 CANVAS & VIDEO LOGIC
  // --------------------------------------------------------------------------

  Future<void> _autoLoadCanvas(String title, String artist) async {
    // 🚀 Check if canvas is disabled in settings
    final settings = ref.read(settingsProvider);
    if (settings.disableCanvas) {
      if (mounted) {
        setState(() {
          _videoController?.dispose();
          _videoController = null;
          _isLoading = false;
          _loadingStatus = "";
        });
      }
      return;
    }

    final oldController = _videoController;
    if (mounted) {
      setState(() {
        _videoController = null;
        _isLoading = true;
        _loadingStatus = "Searching Spotify...";
      });
    }
    if (oldController != null) await oldController.dispose();

    // 🚀 TIER 1: Check Video URL Cache (FASTEST)
    try {
      final String videoCacheKey = "canvas_video:$artist-$title";
      final cachedVideoUrl = await DBService().getArtCache(videoCacheKey);
      if (cachedVideoUrl != null && cachedVideoUrl.isNotEmpty) {
        debugPrint("💾 [DB CACHE] Canvas Video Found: $artist - $title");
        if (mounted) {
          setState(() => _loadingStatus = "[Cached] ${AppLocalizations.of(context)!.fetchingCanvas}");
        }
        await _loadCanvasFromUrl(cachedVideoUrl, isDirectVideoUrl: true);
        if (_videoController != null) return; // Success!
      }
    } catch (e) {
      debugPrint("⚠️ Canvas Cache Read Error (Video): $e");
    }

    // 🚀 TIER 2: Check Spotify Link Cache (Saves API Quota)
    String? spotifyUrl;
    bool isLinkFromCache = false;
    final String linkCacheKey = "spotify_link:$artist-$title";
    try {
      spotifyUrl = await DBService().getArtCache(linkCacheKey);
      if (spotifyUrl != null && spotifyUrl.isNotEmpty) {
        debugPrint("💾 [DB CACHE] Spotify Link Found: $artist - $title");
        isLinkFromCache = true;
      }
    } catch (e) {
      debugPrint("⚠️ Canvas Cache Read Error (Link): $e");
    }

    // 🚀 TIER 3: Fetch from Official Spotify API
    if (spotifyUrl == null || spotifyUrl.isEmpty) {
      debugPrint("🌐 [NETWORK] Searching Spotify for: $artist - $title");
      try {
        spotifyUrl = await SpotifyService.getTrackLink(title, artist);
        if (spotifyUrl != null) {
          DBService().saveArtCache(linkCacheKey, spotifyUrl);
        }
      } catch (e) {
        // 429 or other error - cannot load Canvas, gracefully degrade
      }
    }

    if (spotifyUrl != null) {
      if (!mounted) return;
      setState(() {
        final prefix = isLinkFromCache ? "[Cached] " : "";
        _loadingStatus = "$prefix${AppLocalizations.of(context)!.fetchingCanvas}";
      });
      await _loadCanvasFromUrl(spotifyUrl);
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingStatus = "";
        });
      }
    }
  }

  Future<void> _loadCanvasFromUrl(String url, {bool isDirectVideoUrl = false}) async {
    String? videoUrl;
    
    if (isDirectVideoUrl) {
      videoUrl = url;
    } else {
      videoUrl = await CanvasService.getCanvasUrl(url);
      if (videoUrl != null) {
        // Save to Video Cache for next time
        final song = ref.read(playerProvider).currentSong;
        if (song != null) {
          DBService().saveArtCache("canvas_video:${song.artist}-${song.title}", videoUrl);
          // Also save the Spotify Link if we were using an override or found it
          DBService().saveArtCache("spotify_link:${song.artist}-${song.title}", url);
        }
      }
    }

    if (videoUrl != null) {
      if (!mounted) return;
      setState(() => _loadingStatus = AppLocalizations.of(context)!.fetchingCanvas);

      final cachedFile = await CanvasService.downloadCanvasToCache(videoUrl);

      if (cachedFile == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final controller = VideoPlayerController.file(cachedFile);
      try {
        await controller.initialize();
        controller.setLooping(true);
        controller.setVolume(0);
        await controller.play();

        if (mounted) {
          setState(() {
            _videoController = controller;
            _isLoading = false;
          });
        } else {
          controller.dispose();
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLinkDialog() {
    _onUserInteraction();
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Manual Override"),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(hintText: "Paste Spotify Link..."),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (textController.text.isNotEmpty) {
                setState(() => _isLoading = true);
                _loadCanvasFromUrl(textController.text);
              }
            },
            child: const Text("Load"),
          ),
        ],
      ),
    );
  }

  SongModel? _getNextSong(PlayerState state) {
    if (state.loopMode == ja.LoopMode.one) return state.currentSong;
    if (state.userQueue.isNotEmpty) return state.userQueue.first;
    if (state.playlist.isNotEmpty && state.currentSong != null) {
      int currentIndex = state.playlist
          .indexWhere((s) => s.filePath == state.currentSong!.filePath);

      if (currentIndex >= 0 && currentIndex < state.playlist.length - 1) {
        return state.playlist[currentIndex + 1];
      } else if (state.loopMode == ja.LoopMode.all &&
          state.playlist.isNotEmpty) {
        return state.playlist.first;
      }
    }
    return null;
  }

  // --------------------------------------------------------------------------
  // 🖥️ UI BUILD
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;

    final hasVideo =
        _videoController != null && _videoController!.value.isInitialized;

    final bool isDesktop = !Platform.isAndroid && !Platform.isIOS;

    final nextSong = _getNextSong(playerState);
    final remainingTime =
        playerState.totalDuration - playerState.currentPosition;
    final bool showUpNext = (remainingTime <= 5.0 && remainingTime > 0.0) &&
        (playerState.totalDuration > 10) &&
        (nextSong != null);

    ref.listen<PlayerState>(playerProvider, (previous, next) {
      if (previous?.currentSong?.filePath != next.currentSong?.filePath) {
        if (next.currentSong != null) {
          _autoLoadCanvas(next.currentSong!.title, next.currentSong!.artist);
        }
      }
    });

    // 🚀 Reactive Canvas Disable: Watch settings and dispose if disabled mid-session
    ref.listen<SettingsState>(settingsProvider, (prev, next) {
      if (next.disableCanvas && _videoController != null) {
        setState(() {
          _videoController?.dispose();
          _videoController = null;
          _isLoading = false;
        });
      } else if (!next.disableCanvas &&
          prev?.disableCanvas == true &&
          _videoController == null) {
        // Re-load if enabled mid-session
        final song = ref.read(playerProvider).currentSong;
        if (song != null) {
          _autoLoadCanvas(song.title, song.artist);
        }
      }
    });

    if (song == null) {
      return Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context)!.noMusicPlaying),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _exitAndPop(); // 🚀 Uses Simple Exit
      },
      child: Consumer(
        builder: (context, ref, child) {
          final lyricsState = ref.watch(lyricsProvider);

          // Sync position on seek
          ref.listen<double>(playerProvider.select((s) => s.currentPosition), (prev, next) {
            _smoothPosition = next;
          });

          return MouseRegion(
            onHover: (_) => _onUserInteraction(),
            cursor: _showControls
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            child: Scaffold(
              backgroundColor: Colors.black,
              extendBodyBehindAppBar: true,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showControls ? 1.0 : 0.0,
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white),
                      // 🚀 USES SIMPLE EXIT
                      onPressed: _exitAndPop,
                    ),
                    actions: [
                      if (_isLoading)
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: Center(
                              child: Text(_loadingStatus,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white70))),
                        ),
                      IconButton(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search, color: Colors.white54),
                        onPressed: _showLinkDialog,
                      ),
                    ],
                  ),
                ),
              ),
              body: GestureDetector(
                onTap: _onUserInteraction,
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // --- LAYER 1: LIVE BACKGROUND ---
                    Positioned.fill(
                      child: hasVideo
                          ? FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _videoController!.value.size.width,
                                height: _videoController!.value.size.height,
                                child: VideoPlayer(_videoController!),
                              ),
                            )
                          : Builder(
                              builder: (context) {
                                final bool isReady =
                                    SmartArt.isCached(song.filePath);
                                final artWidget = Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.5),
                                          blurRadius: 30,
                                          spreadRadius: 5)
                                    ],
                                  ),
                                  child: SmartArt(
                                    path: song.filePath,
                                    size: 800,
                                    borderRadius: 0,
                                    onlineArtUrl: song.onlineArtUrl,
                                  ),
                                );

                                if (isReady) {
                                  return Hero(
                                    tag: 'current_artwork_bg',
                                    child: artWidget,
                                  );
                                } else {
                                  return artWidget;
                                }
                              },
                            ),
                    ),

                    // Blur Filter
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                            color: Colors.black.withValues(alpha: 0.5)),
                      ),
                    ),
                    // 🚀 REMOTE PLAYBACK BANNER (Only show when in a remote session AND this device is a slave)
                    if (ref.read(playerProvider.notifier).isRemoteSessionActive && !ref.read(playerProvider.notifier).isMaster && playerState.activeDeviceName != null)
                      Positioned(
                        top: 100,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cast_connected,
                                    size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  "Playing on ${playerState.activeDeviceName}",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // --- NEW LAYER: LYRICS ON RIGHT ---
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      top: 0,
                      bottom: 0,
                      left: (_showLyrics && isDesktop)
                          ? MediaQuery.of(context).size.width / 2
                          : MediaQuery.of(context).size.width,
                      right: (_showLyrics && isDesktop)
                          ? 0
                          : -MediaQuery.of(context).size.width / 2,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: (_showLyrics && isDesktop) ? 1.0 : 0.0,
                        child: (_showLyrics && isDesktop)
                            ? _buildLyricsList(lyricsState)
                            : const SizedBox.shrink(),
                      ),
                    ),

                    // --- LAYER 2: FOREGROUND ART ---
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      top: (_showLyrics && isDesktop) ? 40 : 0,
                      bottom: (_showLyrics && isDesktop) ? 300 : 0,
                      left: 0,
                      right: (_showLyrics && isDesktop)
                          ? MediaQuery.of(context).size.width / 2
                          : 0,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: animation.drive(Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).chain(
                                    CurveTween(curve: Curves.easeOutCubic))),
                                child: child,
                              ),
                            );
                          },
                          child: (hasVideo && !(_showLyrics && isDesktop))
                              ? AspectRatio(
                                  key: const ValueKey('video_art'),
                                  aspectRatio:
                                      _videoController!.value.aspectRatio,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.5),
                                            blurRadius: 20,
                                            spreadRadius: 2)
                                      ],
                                    ),
                                    child: VideoPlayer(_videoController!),
                                  ),
                                )
                              : Builder(
                                  key: const ValueKey('image_art'),
                                  builder: (context) {
                                    final bool isReady =
                                        SmartArt.isCached(song.filePath);
                                    final artWidget = Container(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 30,
                                              spreadRadius: 5)
                                        ],
                                      ),
                                      child: SmartArt(
                                        path: song.filePath,
                                        size: 400,
                                        borderRadius: 8,
                                        onlineArtUrl: song.onlineArtUrl,
                                      ),
                                    );

                                    final Widget finalArtWidget = isReady
                                        ? Hero(
                                            tag: 'current_artwork',
                                            child: artWidget,
                                          )
                                        : artWidget;

                                    return finalArtWidget;
                                  },
                                ),
                        ),
                      ),
                    ),

                    // --- LAYER 3: GRADIENT ---
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 500),
                      opacity: _showControls ? 1.0 : 0.4,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.9),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // --- LAYER 4: UP NEXT POPUP ---
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutExpo,
                      top: 80,
                      right: showUpNext ? 20 : -300,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 250,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                if (nextSong != null)
                                  SmartArt(
                                      path: nextSong.filePath,
                                      size: 40,
                                      borderRadius: 6),
                                const SizedBox(width: 12),
                                if (nextSong != null)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!.upNext,
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          nextSong.title,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          nextSong.artist,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- LAYER 5: TEXT & CONTROLS ---
                    Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          top: 0,
                          bottom: 0,
                          left: 40,
                          right: (_showLyrics && isDesktop)
                              ? (MediaQuery.of(context).size.width / 2) + 40
                              : 40,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            alignment: (_showLyrics && isDesktop)
                                ? Alignment.topCenter
                                : Alignment.bottomLeft,
                            padding: EdgeInsets.only(
                              top: (_showLyrics && isDesktop)
                                  ? MediaQuery.of(context).size.height - 315
                                  : 0,
                              bottom: (_showLyrics && isDesktop)
                                  ? 0
                                  : (_showControls ? 240 : 40),
                            ),
                            child: Column(
                              crossAxisAlignment: (_showLyrics && isDesktop)
                                  ? CrossAxisAlignment.center
                                  : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (playerState.isBuffering)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppLocalizations.of(context)!
                                              .fetchingLossless,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  child: Column(
                                    crossAxisAlignment:
                                        (_showLyrics && isDesktop)
                                            ? CrossAxisAlignment.center
                                            : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        textAlign: (_showLyrics && isDesktop)
                                            ? TextAlign.center
                                            : TextAlign.left,
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: (_showLyrics && isDesktop)
                                                ? 28
                                                : 36,
                                            fontWeight: FontWeight.bold,
                                            height: (_showLyrics && isDesktop)
                                                ? 1.2
                                                : null,
                                            shadows: const [
                                              Shadow(
                                                  color: Colors.black87,
                                                  blurRadius: 15,
                                                  offset: Offset(0, 2))
                                            ]),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        song.artist,
                                        textAlign: (_showLyrics && isDesktop)
                                            ? TextAlign.center
                                            : TextAlign.left,
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: (_showLyrics && isDesktop)
                                                ? 18
                                                : 22,
                                            shadows: const [
                                              Shadow(
                                                  color: Colors.black87,
                                                  blurRadius: 10,
                                                  offset: Offset(0, 2))
                                            ]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          bottom: 40,
                          left: 40,
                          right: _showLyrics
                              ? (MediaQuery.of(context).size.width / 2) + 40
                              : 40,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _showControls ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: !_showControls,
                              child: Column(
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: Colors.white,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6),
                                    ),
                                    child: Slider(
                                      value: playerState.currentPosition
                                          .clamp(0, playerState.totalDuration),
                                      max: playerState.totalDuration > 0
                                          ? playerState.totalDuration
                                          : 1,
                                      onChanged: (val) {
                                        _onUserInteraction();
                                        ref
                                            .read(playerProvider.notifier)
                                            .seek(val);
                                      },
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          _formatTime(
                                              playerState.currentPosition),
                                          style: const TextStyle(
                                              color: Colors.white54)),
                                      Text(
                                          _formatTime(
                                              playerState.totalDuration),
                                          style: const TextStyle(
                                              color: Colors.white54)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.lyrics_outlined,
                                          color: _showLyrics
                                              ? Colors.white
                                              : Colors.white54,
                                          size: 28,
                                        ),
                                        onPressed: () {
                                          _onUserInteraction();
                                          setState(
                                              () => _showLyrics = !_showLyrics);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.skip_previous_rounded,
                                            color: Colors.white,
                                            size: 48),
                                        onPressed: () {
                                          _onUserInteraction();
                                          ref
                                              .read(playerProvider.notifier)
                                              .playPrevious();
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          playerState.isPlaying
                                              ? Icons
                                                  .pause_circle_filled_rounded
                                              : Icons.play_circle_fill_rounded,
                                          color: Colors.white,
                                          size: 80,
                                        ),
                                        onPressed: () {
                                          _onUserInteraction();
                                          ref
                                              .read(playerProvider.notifier)
                                              .togglePlay();
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.skip_next_rounded,
                                            color: Colors.white,
                                            size: 48),
                                        onPressed: () {
                                          _onUserInteraction();
                                          ref
                                              .read(playerProvider.notifier)
                                              .playNext();
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.fullscreen_exit_rounded,
                                            color: Colors.white54,
                                            size: 28),
                                        onPressed: () {
                                          _onUserInteraction();
                                          _exitAndPop();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ✨ LYRICS BUILDER
  // --------------------------------------------------------------------------

  Widget _buildLyricsList(LyricsState state) {
    if (state.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white70));
    }

    if (state.parsedLyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text(
              "No Synced Lyrics Found",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              state.rawLyrics.contains("Error")
                  ? state.rawLyrics
                  : "Just enjoy the vibes.",
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Listener(
      onPointerDown: (_) => _isUserScrolling = true,
      onPointerUp: (_) {
        _scrollResumeTimer?.cancel();
        _scrollResumeTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) _isUserScrolling = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ScrollablePositionedList.builder(
            itemCount: state.parsedLyrics.length,
            itemScrollController: _lyricScrollController,
            itemPositionsListener: _lyricPositionsListener,
            padding: const EdgeInsets.only(top: 100, bottom: 300),
          itemBuilder: (context, index) {
            final line = state.parsedLyrics[index];
            final isActive = index == _activeLyricIndex;

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isActive ? 1.0 : 0.3,
              child: GestureDetector(
                onTap: () {
                  _onUserInteraction();
                  ref.read(playerProvider.notifier).seek(line.time);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        !isActive
                            ? Text(
                                line.text,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              )
                            : SmoothHighlightText(
                                text: line.text,
                                startTime: line.time,
                                endTime: index + 1 < state.parsedLyrics.length
                                    ? state.parsedLyrics[index + 1].time
                                    : line.time + 5.0,
                                initialPosition: _smoothPosition,
                                isPlaying: ref.watch(playerProvider).isPlaying,
                                syncOffset: state.syncOffset,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white.withValues(alpha: 0.3),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                      // Optional: Romanization/Translation
                      _buildSubLine(line.text, index, state),
                    ],
                  ),
                ),
              ),
            );
          },
          ),
        ),
      ),
    );
  }

  Widget _buildSubLine(String original, int index, LyricsState lyricsState) {
    final settings = ref.read(settingsProvider);
    String? romanized;
    String? translation;

    // 1. Check Romanization
    if (!settings.disableRomanization) {
      if (JapaneseRomanizer.containsJapanese(original)) {
        romanized = JapaneseRomanizer.getCached(original);
      } else if (ChineseRomanizer.containsChinese(original)) {
        romanized = ChineseRomanizer.getCached(original);
      } else if (KoreanRomanizer.containsKorean(original)) {
        romanized = KoreanRomanizer.romanize(original);
      }
    }

    // 2. Check Translation
    if (lyricsState.showTranslation) {
      final song = ref.read(playerProvider).currentSong;
      if (song != null) {
        final songKey = '${song.title}-${song.artist}';
        final translations = TranslationService.getCached(songKey);
        if (translations != null &&
            index < translations.length &&
            translations[index].isNotEmpty) {
          translation = translations[index];
        }
      }
    }

    if (romanized == null && translation == null) {
      return const SizedBox.shrink();
    }

    final isActive = index == _activeLyricIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (romanized != null && romanized != original)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: !isActive
                ? Text(
                    romanized,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : SmoothHighlightText(
                    text: romanized,
                    startTime: lyricsState.parsedLyrics[index].time,
                    endTime: index + 1 < lyricsState.parsedLyrics.length
                        ? lyricsState.parsedLyrics[index + 1].time
                        : lyricsState.parsedLyrics[index].time + 5.0,
                    initialPosition: _smoothPosition,
                    isPlaying: ref.watch(playerProvider).isPlaying,
                    syncOffset: lyricsState.syncOffset,
                    activeColor: Colors.white70,
                    inactiveColor: Colors.white.withValues(alpha: 0.2),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    isItalic: true,
                    spacing: 6.0,
                  ),
          ),
        if (translation != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '($translation)',
              style: TextStyle(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.15),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  void _syncLyrics(double currentPos, List<LyricLine> lyrics, double offset) {
    double effectiveTime =
        currentPos - offset + 0.3; // Slight bias for prediction
    int index = -1;

    for (int i = 0; i < lyrics.length; i++) {
      if (effectiveTime >= lyrics[i].time) {
        index = i;
      } else {
        break;
      }
    }

    if (index != _activeLyricIndex) {
      // 🚀 Handle song restart/seek to start (index becomes -1)
      if (index == -1 && _activeLyricIndex >= 0) {
        if (mounted) setState(() => _activeLyricIndex = -1);
        if (_lyricScrollController.isAttached) {
          _lyricScrollController.scrollTo(
            index: 0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            alignment: 0.0, // Top
          );
        }
        return;
      }

      if (mounted) setState(() => _activeLyricIndex = index);
      if (_activeLyricIndex >= 0 && _lyricScrollController.isAttached) {
        _lyricScrollController.scrollTo(
          index: _activeLyricIndex,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutQuart,
          alignment: 0.4, // Slightly above center
        );
      }
    }
  }

  String _formatTime(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
