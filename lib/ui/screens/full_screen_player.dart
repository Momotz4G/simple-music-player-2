import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:window_manager/window_manager.dart';

import '../../providers/player_provider.dart';
import '../../models/song_model.dart';
import '../../services/canvas_service.dart';
import '../../services/spotify_service.dart';
import '../components/smart_art.dart';

class FullScreenPlayer extends ConsumerStatefulWidget {
  const FullScreenPlayer({super.key});

  @override
  ConsumerState<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends ConsumerState<FullScreenPlayer>
    with WindowListener {
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  String _loadingStatus = "";

  // UI State
  bool _showControls = true;
  Timer? _hideTimer;

  // Window State to remember previous state
  bool _wasMaximizedOnEntry = false;

  @override
  void initState() {
    super.initState();
    // Desktop-only: window listener
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }

    // 1. Setup Window
    _initWindowMode();

    // 2. Setup UI Timers
    _startHideTimer();

    // 3. Load Art
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final song = ref.read(playerProvider).currentSong;
      if (song != null) {
        _autoLoadCanvas(song.title, song.artist);
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
    super.dispose();
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
    final oldController = _videoController;
    if (mounted) {
      setState(() {
        _videoController = null;
        _isLoading = true;
        _loadingStatus = "Searching Spotify...";
      });
    }
    if (oldController != null) await oldController.dispose();

    final spotifyUrl = await SpotifyService.getTrackLink(title, artist);

    if (spotifyUrl != null) {
      if (!mounted) return;
      setState(() => _loadingStatus = "Fetching Canvas...");
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

  Future<void> _loadCanvasFromUrl(String url) async {
    final videoUrl = await CanvasService.getCanvasUrl(url);

    if (videoUrl != null) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
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

    if (song == null)
      return const Scaffold(body: Center(child: Text("No music")));

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _exitAndPop(); // 🚀 Uses Simple Exit
      },
      child: MouseRegion(
        onHover: (_) => _onUserInteraction(),
        cursor:
            _showControls ? SystemMouseCursors.basic : SystemMouseCursors.none,
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
                                      color: Colors.black.withOpacity(0.5),
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
                    child: Container(color: Colors.black.withOpacity(0.5)),
                  ),
                ),

                // --- LAYER 2: FOREGROUND ART ---
                Center(
                  child: hasVideo
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 2)
                              ],
                            ),
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
                                      color: Colors.black.withOpacity(0.5),
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

                            if (isReady) {
                              return Hero(
                                tag: 'current_artwork',
                                child: artWidget,
                              );
                            } else {
                              return artWidget;
                            }
                          },
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
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                          Colors.black.withOpacity(0.9),
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
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.1)),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "UP NEXT",
                                      style: TextStyle(
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
                                          color: Colors.white70, fontSize: 11),
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
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      bottom: _showControls ? 240 : 40,
                      left: 40,
                      right: 40,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                shadows: [
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
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 22,
                                shadows: [
                                  Shadow(
                                      color: Colors.black87,
                                      blurRadius: 10,
                                      offset: Offset(0, 2))
                                ]),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      left: 40,
                      right: 40,
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
                                    ref.read(playerProvider.notifier).seek(val);
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatTime(playerState.currentPosition),
                                      style: const TextStyle(
                                          color: Colors.white54)),
                                  Text(_formatTime(playerState.totalDuration),
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
                                          ? Icons.pause_circle_filled_rounded
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
                                    icon: const Icon(Icons.skip_next_rounded,
                                        color: Colors.white, size: 48),
                                    onPressed: () {
                                      _onUserInteraction();
                                      ref
                                          .read(playerProvider.notifier)
                                          .playNext();
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
      ),
    );
  }

  String _formatTime(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
