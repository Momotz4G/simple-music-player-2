import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:video_player/video_player.dart';

import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/timer_provider.dart';
import '../../providers/lyrics_provider.dart'; // 🚀 For mini lyrics preview
import '../../services/canvas_service.dart';
import '../../services/spotify_service.dart';
import '../../models/song_model.dart';
import '../components/smart_art.dart';

import '../components/timer_display.dart';
import '../components/equalizer_sheet.dart';
import '../components/version_selection_dialog.dart';
import '../components/song_context_menu.dart';
import 'lyrics_panel.dart';
import '../components/queue_sheet.dart'; // 🚀 IMPORT

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
  String _canvasStatus = "Loading canvas...";
  double _dragOffset = 0.0; // 🚀 Track drag distance
  double _panningOffset = 0.0; // 🚀 Visual scroll cancellation
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0; // 🚀 Track scroll for lyrics visibility
  AnimationController? _dragAnimationController; // 🚀 For interactive drag

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
    final oldController = _videoController;
    if (mounted) {
      setState(() {
        _videoController = null;
        _isLoadingCanvas = true;
        _canvasStatus = "Searching Spotify...";
      });
    }
    if (oldController != null) await oldController.dispose();

    final spotifyUrl = await SpotifyService.getTrackLink(title, artist);

    if (spotifyUrl != null) {
      if (!mounted) return;
      setState(() => _canvasStatus = "Fetching Canvas...");
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
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
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

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final song = playerState.currentSong;

    final hasVideo =
        _videoController != null && _videoController!.value.isInitialized;

    // Listen for song changes to reload canvas
    ref.listen<PlayerState>(playerProvider, (previous, next) {
      if (previous?.currentSong?.filePath != next.currentSong?.filePath) {
        if (next.currentSong != null) {
          _autoLoadCanvas(next.currentSong!.title, next.currentSong!.artist);
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
        body: const Center(
          child: Text(
            "No music playing",
            style: TextStyle(color: Colors.white54),
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
                        _canvasStatus,
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
                  itemBuilder: (context) => [
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
                    const PopupMenuItem(
                      value: 'equalizer',
                      child: Row(
                        children: [
                          Icon(
                            Icons.equalizer_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text("Equalizer",
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    // Select Version
                    const PopupMenuItem(
                      value: 'version',
                      child: Row(
                        children: [
                          Icon(
                            Icons.switch_video_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Select Version",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    // Add to Playlist
                    const PopupMenuItem(
                      value: 'add_to_playlist',
                      child: Row(
                        children: [
                          Icon(Icons.playlist_add,
                              color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text(
                            "Add to Playlist",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    // Add to Favorites
                    const PopupMenuItem(
                      value: 'add_to_favorite',
                      child: Row(
                        children: [
                          Icon(
                            Icons.favorite_border,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Add to Favorites",
                            style: TextStyle(color: Colors.white),
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
                          const Text(
                            "Download Song",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    // Queue removed from here
                  ],
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
                    color: Colors.black.withOpacity(hasVideo ? 0.4 : 0.6),
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
                              color: Colors.black.withOpacity(0.5),
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
                          Colors.black.withOpacity(0.5),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
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
                                                        .withOpacity(0.5),
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
                                        Icon(
                                          Icons.keyboard_arrow_down,
                                          color: Colors.white30,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Scroll for lyrics",
                                          style: TextStyle(
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
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: const LyricsPanel(),
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
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "Loading lyrics...",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                )
              else if (lyrics.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: const [
                      Icon(Icons.lyrics_outlined,
                          color: Colors.white38, size: 32),
                      SizedBox(height: 12),
                      Text(
                        "No lyrics available",
                        style: TextStyle(color: Colors.white54, fontSize: 14),
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      lyrics[idx].text,
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
                    tooltip: "View Queue",
                    onPressed: () => _showQueueSheet(context),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Switching to: ${result.title}")));

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
          SongAction.addToFavorites,
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

  void _showTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Sleep Timer", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _timerOption(15, "15 Minutes"),
            _timerOption(30, "30 Minutes"),
            _timerOption(45, "45 Minutes"),
            _timerOption(60, "1 Hour"),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Colors.white70),
              title: const Text("Custom Time",
                  style: TextStyle(color: Colors.white)),
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
              title: const Text(
                "Turn Off Timer",
                style: TextStyle(color: Colors.redAccent),
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
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("Set Custom Timer",
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter duration...",
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.5)),
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
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text("Hr")),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text("Min")),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text("Sec")),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.white70)),
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
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Timer set for $value ${unit.name}s")));
                    }
                  },
                  child: const Text("Start",
                      style: TextStyle(color: Colors.white)),
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
        ).showSnackBar(SnackBar(content: Text("Music will stop in $label")));
      },
    );
  }
}

enum TimeUnit { hour, minute, second }
