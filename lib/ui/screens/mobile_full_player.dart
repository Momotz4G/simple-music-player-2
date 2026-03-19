import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:video_player/video_player.dart';
import 'package:qr_flutter/qr_flutter.dart'; // 🚀 QR Code

import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/timer_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/lyrics_provider.dart'; // 🚀 For mini lyrics preview
import '../../services/canvas_service.dart';
import '../../services/spotify_service.dart';
import '../../services/pocketbase_service.dart'; // 🚀 Session ID
import '../../env/env.dart'; // 🚀 URLs
import '../../models/song_model.dart';
import '../components/smart_art.dart';

import '../components/timer_display.dart';
import '../components/equalizer_sheet.dart';
import '../components/version_selection_dialog.dart';
import '../components/song_context_menu.dart';
import 'lyrics_panel.dart';
import '../components/queue_sheet.dart'; // 🚀 IMPORT
import '../components/song_info_dialog.dart'; // 🚀 IMPORT
import '../../services/audio_info_service.dart'; // 🚀 Audio Quality Info
import '../components/audio_output_dialog.dart'; // 🚀 Audio Output
import '../../utils/chinese_romanizer.dart';
import '../../utils/japanese_romanizer.dart';
import '../../utils/korean_romanizer.dart';
import '../../utils/translation_service.dart';

/// Mobile-optimized full player page with Canvas video support
/// Opens when user taps the mini player bar on mobile
class MobileFullPlayer extends ConsumerStatefulWidget {
  const MobileFullPlayer({super.key});

  @override
  ConsumerState<MobileFullPlayer> createState() => _MobileFullPlayerState();
}

class _MobileFullPlayerState extends ConsumerState<MobileFullPlayer>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isLoadingCanvas = false;
  String? _canvasStatus;
  double _dragOffset = 0.0; // 🚀 Track drag distance
  bool _showTranslation = false;
  bool _translationLoading = false;
  double _panningOffset = 0.0; // 🚀 Visual scroll cancellation
  final ScrollController _scrollController = ScrollController();
  AnimationController? _dragAnimationController; // 🚀 For interactive drag

  // 🚀 AUDIO QUALITY INFO STATE
  AudioInfo? _audioInfo;
  bool _isLoadingInfo = false;

  @override
  void initState() {
    super.initState();
    // Auto-load canvas on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final song = ref.read(playerProvider).currentSong;
      if (song != null) {
        _autoLoadCanvas(song.title, song.artist);
        // 🚀 Auto-load lyrics when player opens
        ref.read(lyricsProvider.notifier).loadLyrics(
              song.filePath,
              song.title,
              song.artist,
              song.duration,
            );
        // 🚀 Fetch Audio Quality
        _fetchAudioInfo(song);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose(); // 🚀 Dispose scroll controller
    _videoController?.dispose();
    _dragAnimationController?.dispose();
    super.dispose();
  }

  void _runDragAnimation(double target) {
    _dragAnimationController?.dispose();
    _dragAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    final animation = Tween<double>(begin: _dragOffset, end: target).animate(
        CurvedAnimation(
            parent: _dragAnimationController!, curve: Curves.easeOutCubic));

    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (target > 0) {
          Navigator.pop(context);
        }
        _dragAnimationController?.dispose();
        _dragAnimationController = null;
      }
    });

    _dragAnimationController!.forward();
  }

  String _formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return "0:00";
    final duration = Duration(seconds: seconds.round());
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // Canvas loading logic (from desktop full_screen_player)
  Future<void> _autoLoadCanvas(String title, String artist) async {
    // 🚀 Check if canvas is disabled in settings
    final settings = ref.read(settingsProvider);
    if (settings.disableCanvas) {
      if (mounted) {
        setState(() {
          _videoController?.dispose();
          _videoController = null;
          _isLoadingCanvas = false;
          _canvasStatus = "";
        });
      }
      return;
    }

    final oldController = _videoController;
    if (mounted) {
      setState(() {
        _videoController = null;
        _isLoadingCanvas = true;
        _canvasStatus = AppLocalizations.of(context)!.searchingSpotify;
      });
    }
    if (oldController != null) await oldController.dispose();

    final spotifyUrl = await SpotifyService.getTrackLink(title, artist);

    if (spotifyUrl != null) {
      if (!mounted) return;
      setState(
          () => _canvasStatus = AppLocalizations.of(context)!.fetchingCanvas);
      await _loadCanvasFromUrl(spotifyUrl);
    } else {
      if (mounted) {
        setState(() {
          _isLoadingCanvas = false;
          _canvasStatus = "";
        });
      }
    }
  }

  Future<void> _loadCanvasFromUrl(String url) async {
    final videoUrl = await CanvasService.getCanvasUrl(url);

    if (videoUrl != null) {
      if (!mounted) return;
      setState(() => _canvasStatus = "Downloading canvas...");

      final cachedFile = await CanvasService.downloadCanvasToCache(videoUrl);

      if (cachedFile == null) {
        if (mounted) setState(() => _isLoadingCanvas = false);
        return;
      }

      final controller = VideoPlayerController.file(
        cachedFile,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      try {
        await controller.initialize();
        controller.setLooping(true);
        controller.setVolume(0);
        await controller.play();

        if (mounted) {
          setState(() {
            _videoController = controller;
            _isLoadingCanvas = false;
          });
        } else {
          controller.dispose();
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingCanvas = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingCanvas = false);
    }
  }

  // 🚀 FETCH AUDIO INFO
  Future<void> _fetchAudioInfo(SongModel song) async {
    if (!mounted) return;
    setState(() {
      _isLoadingInfo = true;
      _audioInfo = null;
    });

    final info = await AudioInfoService().getAudioInfoForSong(song);

    if (mounted) {
      setState(() {
        _audioInfo = info;
        _isLoadingInfo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final song = playerState.currentSong;

    final hasVideo =
        _videoController != null && _videoController!.value.isInitialized;

    // Listen for song changes to reload canvas, lyrics, and audio info
    ref.listen<PlayerState>(playerProvider, (previous, next) {
      final prevSong = previous?.currentSong;
      final nextSong = next.currentSong;

      // Check if song has actually changed (path or title/artist)
      if (prevSong?.filePath != nextSong?.filePath ||
          prevSong?.title != nextSong?.title ||
          prevSong?.artist != nextSong?.artist) {
        if (nextSong != null) {
          // Reset states immediately for UI feedback
          setState(() {
            _audioInfo = null;
            _isLoadingInfo = true;
          });

          _autoLoadCanvas(nextSong.title, nextSong.artist);
          _fetchAudioInfo(nextSong); // 🚀 Update Info

          // 🚀 Update Lyrics Preview
          ref.read(lyricsProvider.notifier).loadLyrics(
                nextSong.filePath,
                nextSong.title,
                nextSong.artist,
                nextSong.duration,
              );
        }
      }
    });

    // 🚀 Reactive Canvas Disable: Watch settings and dispose if disabled mid-session
    ref.listen<SettingsState>(settingsProvider, (prev, next) {
      if (next.disableCanvas && _videoController != null) {
        setState(() {
          _videoController?.dispose();
          _videoController = null;
          _isLoadingCanvas = false;
          _canvasStatus = "";
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
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            AppLocalizations.of(context)!.noMusicPlaying,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    // Dynamic slider logic
    double currentPos = playerState.currentPosition;
    double totalDur = playerState.totalDuration;
    double sliderMax = totalDur;
    if (sliderMax < currentPos) sliderMax = currentPos;
    if (sliderMax <= 0) sliderMax = 1.0;
    double sliderValue = currentPos;
    if (sliderValue > sliderMax) sliderValue = sliderMax;

    // Wrap in Dismissible for drag-to-close behavior
    // Custom Drag-to-Dismiss using Transform
    return Transform.translate(
      offset: Offset(0, _dragOffset),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                // Canvas loading indicator
                if (_isLoadingCanvas)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: Text(
                        _canvasStatus ??
                            AppLocalizations.of(context)!.loadingCanvas,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white54),
                      ),
                    ),
                  ),
                if (_isLoadingCanvas)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                  ),

                // 3-dots menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                  color: Colors.grey[900],
                  onSelected: (value) => _handleMenuAction(value, song),
                  itemBuilder: (context) {
                    final l10n = AppLocalizations.of(context)!;
                    return [
                      // Timer
                      PopupMenuItem(
                        value: 'timer',
                        child: Row(
                          children: [
                            Icon(
                              ref.read(timerProvider).isActive
                                  ? Icons.timer_rounded
                                  : Icons.timer_outlined,
                              color: ref.read(timerProvider).isActive
                                  ? settings.accentColor
                                  : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const TimerDisplay(),
                          ],
                        ),
                      ),
                      // Equalizer
                      PopupMenuItem(
                        value: 'equalizer',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.equalizer_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(l10n.equalizer,
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      // Song Info
                      PopupMenuItem(
                        value: 'song_info',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(l10n.songInformation,
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      // Select Version
                      PopupMenuItem(
                        value: 'version',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.switch_video_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.selectVersion,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      // Add to Playlist
                      PopupMenuItem(
                        value: 'add_to_playlist',
                        child: Row(
                          children: [
                            const Icon(Icons.playlist_add,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              l10n.addToPlaylist,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      // Add to Favorites
                      PopupMenuItem(
                        value: 'add_to_favorite',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.favorite_border,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.addToFavorite,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      // Download
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(
                              Icons.download_rounded,
                              color: settings.accentColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.downloadSong,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      // Listening Party
                      PopupMenuItem(
                        value: 'listening_party',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.qr_code_2_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.listeningParty,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      // Audio Output
                      PopupMenuItem(
                        value: 'audio_output',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.output_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.audioOutput,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
            body: Stack(
              children: [
                // LAYER 1: Background - Canvas video OR blurred album art
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
                      : SmartArt(
                          path: song.filePath,
                          onlineArtUrl: song.onlineArtUrl,
                          size: MediaQuery.of(context).size.width,
                          borderRadius: 0,
                        ),
                ),
                // LAYER 2: Blur overlay (less blur when video is playing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: hasVideo ? 0.4 : 0.6),
                  ),
                ),
                // LAYER 3: Video in center (if playing)
                if (hasVideo)
                  Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  ),
                // LAYER 4: Gradient overlay for controls visibility
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.0, 0.2, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),

                // LAYER 5: Scrollable Controls + Lyrics
                Listener(
                  onPointerDown: (_) {
                    // Stop animation if user catches it
                    if (_dragAnimationController != null) {
                      _dragAnimationController!.stop();
                      _dragAnimationController!.dispose();
                      _dragAnimationController = null;
                    }
                  },
                  onPointerUp: (_) {
                    // Reset scroll on release to ensure clean state
                    if (_dragOffset > 0) _scrollController.jumpTo(0);

                    if (_dragOffset > 200) {
                      // Continue to bottom (Close)
                      _runDragAnimation(MediaQuery.of(context).size.height);
                    } else if (_dragOffset > 0) {
                      // Snap back to top (Restore)
                      _runDragAnimation(0);
                    }
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification ||
                          notification is OverscrollNotification) {
                        DragUpdateDetails? dragDetails;
                        if (notification is ScrollUpdateNotification) {
                          dragDetails = notification.dragDetails;
                        } else if (notification is OverscrollNotification) {
                          dragDetails = notification.dragDetails;
                        }

                        if (dragDetails != null) {
                          // 🚀 PRIORITY: If controlling page offset, consume ALL touches
                          if (_dragOffset > 0) {
                            setState(() {
                              _dragOffset += dragDetails!.delta.dy;
                              if (_dragOffset < 0) _dragOffset = 0;
                              // Track visual cancellation offset
                              _panningOffset = notification.metrics.pixels;
                            });
                          }
                          // 🚀 START: Initiate drag if at top and pulling down
                          else if (notification.metrics.pixels <= 0 &&
                              dragDetails.delta.dy > 0) {
                            setState(() {
                              _dragOffset += dragDetails!.delta.dy;
                            });
                          }
                        }
                      }
                      return false;
                    },
                    child: SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            controller: _scrollController,
                            physics: const ClampingScrollPhysics(),
                            child: Transform.translate(
                              offset: Offset(
                                  0, _dragOffset > 0 ? _panningOffset : 0),
                              child: Column(
                                children: [
                                  // 🚀 PAGE 1: FULL HEIGHT CLEAN PLAYER
                                  SizedBox(
                                    height: constraints.maxHeight,
                                    child: Column(
                                      children: [
                                        const Spacer(flex: 3),
                                        // Album Art
                                        if (!hasVideo)
                                          Hero(
                                            tag: 'mobile_player_art',
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.5),
                                                    blurRadius: 30,
                                                    spreadRadius: 5,
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: SmartArt(
                                                  path: song.filePath,
                                                  onlineArtUrl:
                                                      song.onlineArtUrl,
                                                  size: MediaQuery.of(context)
                                                          .size
                                                          .width -
                                                      80,
                                                  borderRadius: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          SizedBox(
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .width -
                                                80,
                                          ),
                                        const Spacer(flex: 2),
                                        // Title and Artist
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 32),
                                          child: Column(
                                            children: [
                                              Text(
                                                song.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  shadows: [
                                                    Shadow(
                                                        color: Colors.black87,
                                                        blurRadius: 10),
                                                  ],
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                song.artist,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 18,
                                                  shadows: [
                                                    Shadow(
                                                        color: Colors.black87,
                                                        blurRadius: 8),
                                                  ],
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        // Seekbar
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24),
                                          child: SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                              activeTrackColor: Colors.white,
                                              inactiveTrackColor:
                                                  Colors.white24,
                                              thumbColor: Colors.white,
                                              trackHeight: 4,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                enabledThumbRadius: 6,
                                              ),
                                            ),
                                            child: Slider(
                                              value: sliderValue,
                                              min: 0.0,
                                              max: sliderMax,
                                              onChanged: (val) =>
                                                  notifier.seek(val),
                                            ),
                                          ),
                                        ),
                                        // Time labels
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 32),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _formatTime(sliderValue),
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                _formatTime(totalDur),
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // 🚀 AUDIO QUALITY INFO BAR
                                        if (_audioInfo != null ||
                                            _isLoadingInfo)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 16),
                                            child: _isLoadingInfo
                                                ? const SizedBox(
                                                    height: 14,
                                                    width: 14,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                Colors.white24))
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      // Format (FLAC/MP3)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white
                                                              .withValues(
                                                                  alpha: 0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                          border: Border.all(
                                                              color: Colors
                                                                  .white12),
                                                        ),
                                                        child: Text(
                                                          _audioInfo?.format ??
                                                              "UNK",
                                                          style: TextStyle(
                                                            color: settings
                                                                .accentColor,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      // Sample Rate
                                                      Text(
                                                        _audioInfo
                                                                ?.sampleRateDisplay ??
                                                            "",
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white70,
                                                            fontSize: 11),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const Text("•",
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white24)),
                                                      const SizedBox(width: 6),
                                                      // Bit Depth
                                                      Text(
                                                        _audioInfo
                                                                ?.bitDepthDisplay ??
                                                            "",
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white70,
                                                            fontSize: 11),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const Text("•",
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white24)),
                                                      const SizedBox(width: 6),
                                                      // Bitrate
                                                      Text(
                                                        _audioInfo
                                                                ?.bitrateDisplay ??
                                                            "",
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white70,
                                                            fontSize: 11),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        // Controls row
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            // Shuffle
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.shuffle_rounded),
                                              iconSize: 28,
                                              color: playerState.isShuffle
                                                  ? settings.accentColor
                                                  : Colors.white54,
                                              onPressed: notifier.toggleShuffle,
                                            ),
                                            // Previous
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.skip_previous_rounded),
                                              iconSize: 40,
                                              color: Colors.white,
                                              onPressed: notifier.playPrevious,
                                            ),
                                            // Play/Pause
                                            Container(
                                              width: 72,
                                              height: 72,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: IconButton(
                                                icon: AnimatedSwitcher(
                                                  duration: const Duration(
                                                      milliseconds: 200),
                                                  child: Icon(
                                                    playerState.isPlaying
                                                        ? Icons.pause_rounded
                                                        : Icons
                                                            .play_arrow_rounded,
                                                    key: ValueKey(
                                                        playerState.isPlaying),
                                                    color: Colors.black,
                                                    size: 40,
                                                  ),
                                                ),
                                                onPressed: notifier.togglePlay,
                                              ),
                                            ),
                                            // Next
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.skip_next_rounded),
                                              iconSize: 40,
                                              color: Colors.white,
                                              onPressed: notifier.playNext,
                                            ),
                                            // Repeat & Queue Stack
                                            // Repeat & Queue Column (Balanced High)
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // 🚀 Spacer to counterbalance Queue button (keeps Repeat centered)
                                                const SizedBox(height: 48),
                                                IconButton(
                                                  icon: Icon(
                                                    playerState.loopMode ==
                                                            ja.LoopMode.one
                                                        ? Icons
                                                            .repeat_one_rounded
                                                        : Icons.repeat_rounded,
                                                  ),
                                                  iconSize: 28,
                                                  color: playerState.loopMode ==
                                                          ja.LoopMode.off
                                                      ? Colors.white54
                                                      : settings.accentColor,
                                                  onPressed:
                                                      notifier.cycleLoopMode,
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons
                                                      .queue_music_rounded),
                                                  iconSize: 24,
                                                  color: Colors.white70,
                                                  onPressed: () {
                                                    showModalBottomSheet(
                                                      context: context,
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      isScrollControlled: true,
                                                      builder: (context) =>
                                                          const QueueSheet(),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const Spacer(flex: 2),
                                        // Scroll Indicator
                                        const Icon(
                                          Icons.keyboard_arrow_down,
                                          color: Colors.white30,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          AppLocalizations.of(context)!
                                              .scrollForLyrics,
                                          style: const TextStyle(
                                              color: Colors.white30,
                                              fontSize: 11),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  ),
                                  // 🚀 PAGE 2: LYRICS CONTAINER
                                  _buildScrollableLyrics(
                                      playerState, settings, notifier),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // LYRICS OVERLAY - ABSOLUTELY ON TOP OF EVERYTHING
          if (playerState.isLyricsVisible)
            const Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: LyricsPanel(),
              ),
            ),
        ],
      ),
    );
  }

  // 🚀 SCROLLABLE LYRICS SECTION - Appears when scroll down
  Widget _buildScrollableLyrics(
      PlayerState playerState, dynamic settings, PlayerNotifier notifier) {
    final lyricsState = ref.watch(lyricsProvider);
    final currentPosition =
        playerState.currentPosition + lyricsState.syncOffset;
    final lyrics = lyricsState.parsedLyrics;

    // Find current lyric index
    int currentIndex = -1;
    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (currentPosition >= lyrics[i].time) {
        currentIndex = i;
        break;
      }
    }

    return GestureDetector(
        onTap: () => notifier.setLyricsVisibility(true),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: settings.accentColor.withOpacity(0.7),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Lyrics content
              if (lyricsState.isLoading)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    AppLocalizations.of(context)!.loadingLyrics,
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                )
              else if (lyrics.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.lyrics_outlined,
                          color: Colors.white38, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.noLyricsAvailable,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                )
              else
                // Show 5-7 synced lines
                ...List.generate(7, (offset) {
                  final idx = currentIndex - 3 + offset;
                  if (idx < 0 || idx >= lyrics.length) {
                    return const SizedBox.shrink();
                  }
                  final isCurrent = idx == currentIndex;
                  final text = lyrics[idx].text;

                  // Check romanization
                  final hasKorean = KoreanRomanizer.containsKorean(text);
                  final hasJapanese =
                      !hasKorean && JapaneseRomanizer.containsJapanese(text);
                  final hasChinese = !hasKorean &&
                      !hasJapanese &&
                      ChineseRomanizer.containsChinese(text);

                  String? romanized;
                  final disableRoman =
                      ref.read(settingsProvider).disableRomanization;
                  if (!disableRoman) {
                    if (hasKorean) {
                      romanized = KoreanRomanizer.romanize(text);
                    } else if (hasJapanese) {
                      romanized = JapaneseRomanizer.getCached(text);
                    } else if (hasChinese) {
                      romanized = ChineseRomanizer.getCached(text);
                    }
                  }

                  // Translation display
                  final song = ref.read(playerProvider).currentSong;
                  final songKey =
                      song != null ? '${song.title}-${song.artist}' : '';
                  final translations = _showTranslation
                      ? TranslationService.getCached(songKey)
                      : null;
                  final hasTranslation = translations != null &&
                      idx < translations.length &&
                      translations[idx].isNotEmpty;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Text(
                          text,
                          style: TextStyle(
                            color: isCurrent ? Colors.white : Colors.white38,
                            fontSize: isCurrent ? 18 : 15,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (romanized != null && romanized.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              romanized,
                              style: TextStyle(
                                fontSize: isCurrent ? 14 : 12,
                                fontWeight: isCurrent
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                color:
                                    isCurrent ? Colors.white70 : Colors.white30,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (hasTranslation)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '(${translations[idx]})',
                              style: TextStyle(
                                fontSize: isCurrent ? 13 : 11,
                                fontWeight: FontWeight.normal,
                                color:
                                    isCurrent ? Colors.white54 : Colors.white24,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.queue_music_rounded),
                    color: Colors.white54,
                    iconSize: 24,
                    tooltip: AppLocalizations.of(context)!.viewQueue,
                    onPressed: () => _showQueueSheet(context),
                  ),
                  _translationLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.translate_rounded),
                          color: _showTranslation
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white54,
                          iconSize: 24,
                          tooltip:
                              AppLocalizations.of(context)!.translateLyrics,
                          onPressed: () async {
                            if (_showTranslation) {
                              setState(() => _showTranslation = false);
                              return;
                            }
                            final song = ref.read(playerProvider).currentSong;
                            if (song == null) return;
                            final lyrics =
                                ref.read(lyricsProvider).parsedLyrics;
                            if (lyrics.isEmpty) return;
                            final songKey = '${song.title}-${song.artist}';
                            if (TranslationService.hasCached(songKey)) {
                              setState(() => _showTranslation = true);
                              return;
                            }
                            setState(() => _translationLoading = true);
                            final targetLang =
                                ref.read(settingsProvider).translationLanguage;
                            final lines =
                                lyrics.map<String>((l) => l.text).toList();
                            await TranslationService.translateLyrics(
                              songKey: songKey,
                              lines: lines,
                              targetLang: targetLang,
                            );
                            if (mounted) {
                              setState(() {
                                _translationLoading = false;
                                _showTranslation = true;
                              });
                            }
                          },
                        ),
                ],
              ),
            ],
          ),
        ));
  }

  Future<void> _showVersionDialog(dynamic song) async {
    // Ensure we have a valid song model
    if (song is! SongModel) return;

    final result = await showDialog(
      context: context,
      builder: (context) => VersionSelectionDialog(
        initialQuery: "${song.title} ${song.artist}",
        song: song,
      ),
    );

    if (result != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
          content: Text(
              "${AppLocalizations.of(context)!.switchingTo}: ${result.title}")));

      ref.read(playerProvider.notifier).swapCurrentSongVersion(result.url);
    }
  }

  void _handleMenuAction(String action, dynamic song) {
    switch (action) {
      case 'timer':
        _showTimerDialog();
        break;
      case 'equalizer':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const EqualizerSheet(),
        );
        break;
      case 'song_info':
        showDialog(
          context: context,
          builder: (context) => SongInfoDialog(song: song as SongModel),
        );
        break;
      case 'version':
        _showVersionDialog(song);
        break;
      case 'add_to_playlist':
        SongContextMenuRegion.handleAction(
          context,
          ref,
          SongAction.addToPlaylist,
          song,
        );
        break;
      case 'add_to_favorite':
        SongContextMenuRegion.handleAction(
          context,
          ref,
          SongAction.addToFavorite,
          song,
        );
        break;
      case 'download':
        SongContextMenuRegion.handleAction(
          context,
          ref,
          SongAction.download,
          song,
        );
        break;
      case 'listening_party':
        _showListeningPartyDialog();
        break;
      case 'audio_output':
        showDialog(
          context: context,
          builder: (context) => AudioOutputDialog(
            audioInfo: _audioInfo,
            filePath: (song as SongModel).filePath,
          ),
        );
        break;
    }
  }

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Required for DraggableScrollableSheet
      backgroundColor: Colors.transparent,
      builder: (context) => const QueueSheet(),
    );
  }

  // 🚀 LISTENING PARTY DIALOG
  void _showListeningPartyDialog() async {
    String? sessionId = await PocketBaseService().getUniqueSessionId();
    if (sessionId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Could not create session.")),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final url = "${Env.remoteControlUrl}/?sid=$sessionId";

          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Listening Party",
                    style: TextStyle(color: Colors.white)),
                IconButton(
                  icon:
                      const Icon(Icons.refresh_rounded, color: Colors.white70),
                  onPressed: () async {
                    // Start refreshing animation if needed, but for now just regenerate
                    final newId = await PocketBaseService()
                        .getUniqueSessionId(forceRegenerate: true);
                    if (newId != null) {
                      setDialogState(() {
                        sessionId = newId;
                      });
                    }
                  },
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(
                      data: url,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Scan with another phone to control playback.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  "Code: $sessionId",
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTimerDialog() {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            Text(l10n.sleepTimer, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _timerOption(15, l10n.minutesDuration(15)),
            _timerOption(30, l10n.minutesDuration(30)),
            _timerOption(45, l10n.minutesDuration(45)),
            _timerOption(60, l10n.hoursDuration(1)),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Colors.white70),
              title: Text(l10n.customTime,
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showCustomTimerInput();
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(
                Icons.timer_off_rounded,
                color: Colors.redAccent,
              ),
              title: Text(
                l10n.turnOffTimer,
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                ref.read(timerProvider.notifier).cancelTimer();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomTimerInput() {
    final TextEditingController controller = TextEditingController();
    TimeUnit unit = TimeUnit.minute;
    const accentColor = Colors.deepPurpleAccent; // Or use settings.accentColor

    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(l10n.setCustomTimer,
                  style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: l10n.enterDuration,
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      border: const OutlineInputBorder(),
                      enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ToggleButtons(
                    isSelected: [
                      unit == TimeUnit.hour,
                      unit == TimeUnit.minute,
                      unit == TimeUnit.second,
                    ],
                    onPressed: (index) {
                      setState(() {
                        if (index == 0) unit = TimeUnit.hour;
                        if (index == 1) unit = TimeUnit.minute;
                        if (index == 2) unit = TimeUnit.second;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    selectedColor: Colors.white,
                    fillColor: accentColor,
                    color: Colors.white70,
                    children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(l10n.hourShort)),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(l10n.minuteShort)),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(l10n.secondShort)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel,
                      style: const TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                  onPressed: () {
                    final value = int.tryParse(controller.text);
                    if (value != null && value > 0) {
                      Duration duration;
                      if (unit == TimeUnit.hour) {
                        duration = Duration(hours: value);
                      } else if (unit == TimeUnit.minute) {
                        duration = Duration(minutes: value);
                      } else {
                        duration = Duration(seconds: value);
                      }

                      ref.read(timerProvider.notifier).startTimer(duration);
                      Navigator.pop(context);
                      String message = "";
                      if (unit == TimeUnit.hour) {
                        message = l10n.timerSetForHours(value);
                      } else if (unit == TimeUnit.minute) {
                        message = l10n.timerSetForMinutes(value);
                      } else {
                        message = l10n.timerSetForSeconds(value);
                      }
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(message)));
                    }
                  },
                  child: Text(l10n.start,
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _timerOption(int minutes, String label) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        ref.read(timerProvider.notifier).startTimer(Duration(minutes: minutes));
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content:
                Text(AppLocalizations.of(context)!.musicWillStopIn(label))));
      },
    );
  }
}

enum TimeUnit { hour, minute, second }
