import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../providers/lyrics_provider.dart';
import '../../providers/player_provider.dart';
import '../components/smart_art.dart';
import '../components/vinyl_disk.dart';

class LyricsPanel extends ConsumerStatefulWidget {
  const LyricsPanel({super.key});

  @override
  ConsumerState<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<LyricsPanel> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  int _activeLyricIndex = -1;
  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final currentSong = ref.read(playerProvider).currentSong;
      if (currentSong != null) {
        ref.read(lyricsProvider.notifier).loadLyrics(
              currentSong.filePath,
              currentSong.title,
              currentSong.artist,
              currentSong.duration,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(lyricsProvider.notifier);

    final accentColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final solidBgColor = isDark ? Colors.black : Colors.white;
    final inactiveTextColor = isDark ? Colors.white60 : Colors.black54;
    final headerTextColor = isDark ? Colors.white : Colors.black;
    final subHeaderColor = isDark ? Colors.white70 : Colors.black54;

    final screenHeight = MediaQuery.of(context).size.height;

    ref.listen(playerProvider, (previous, next) {
      if (!mounted) return;

      if (next.currentSong != null &&
          previous?.currentSong?.filePath != next.currentSong!.filePath) {
        ref.read(lyricsProvider.notifier).loadLyrics(
              next.currentSong!.filePath,
              next.currentSong!.title,
              next.currentSong!.artist,
              next.currentSong!.duration,
            );
      }

      final currentLyrics = ref.read(lyricsProvider).parsedLyrics;
      if (currentLyrics.isNotEmpty) {
        _syncLyrics(
          next.currentPosition,
          currentLyrics,
          ref.read(lyricsProvider).syncOffset,
        );
      }
    });

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
          ref.read(playerProvider.notifier).setLyricsVisibility(false);
        }
      },
      child: Container(
        color: solidBgColor,
        child: Stack(
          children: [
            // LAYER 1: BACKGROUND
            if (playerState.currentSong != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  // ✅ FIX: Use SmartArt with path
                  child: SmartArt(
                    path: playerState.currentSong!.filePath,
                    size: 800,
                    borderRadius: 0,
                    onlineArtUrl: playerState.currentSong!.onlineArtUrl,
                  ),
                ),
              ),

            // LAYER 2: TINT
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            Colors.black.withOpacity(0.5),
                            Colors.black.withOpacity(0.9)
                          ]
                        : [
                            Colors.white.withOpacity(0.5),
                            Colors.white.withOpacity(0.9)
                          ],
                  ),
                ),
              ),
            ),

            // LAYER 3: CONTENT
            Column(
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.keyboard_arrow_down,
                            color: headerTextColor),
                        onPressed: () {
                          ref
                              .read(playerProvider.notifier)
                              .setLyricsVisibility(false);
                        },
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              "Now Playing",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: subHeaderColor,
                                  letterSpacing: 1.0),
                            ),
                            if (playerState.currentSong != null)
                              Text(
                                playerState.currentSong!.title,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: headerTextColor),
                              ),
                            const SizedBox(height: 8),
                            Container(
                              width: 60,
                              height: 3,
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Removed: const SizedBox(width: 48) to prevent overlap
                    ],
                  ),
                ),

                // Lyrics List
                Expanded(
                  child: lyricsState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : lyricsState.parsedLyrics.isEmpty
                          ? _buildRawLyrics(
                              lyricsState.rawLyrics,
                              isDark,
                              playerState.currentSong?.filePath, // Pass Path
                              playerState.currentSong?.onlineArtUrl, // Pass URL
                              playerState.isPlaying,
                            )
                          : _buildSyncedLyricsList(
                              lyricsState.parsedLyrics,
                              accentColor,
                              inactiveTextColor,
                              ref.read(playerProvider.notifier),
                              screenHeight,
                            ),
                ),
                const SizedBox(height: 95),
              ],
            ),

            // LAYER 4: WATERMARK
            if (lyricsState.isFromApi && !lyricsState.isLoading)
              Positioned(
                top: 24,
                right: 24,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white12)),
                  child: const Text(
                    "Lyrics by LRCLIB",
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ),
              ),

            // LAYER 5: TIMESHIFT
            if (lyricsState.parsedLyrics.isNotEmpty)
              Positioned(
                bottom: 110,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black87 : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMiniButton(
                          Icons.remove, () => notifier.addOffset(-0.5), isDark),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "${lyricsState.syncOffset > 0 ? '+' : ''}${lyricsState.syncOffset}s",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: accentColor),
                        ),
                      ),
                      _buildMiniButton(
                          Icons.add, () => notifier.addOffset(0.5), isDark),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniButton(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(icon,
            size: 14, color: isDark ? Colors.white70 : Colors.black87),
      ),
    );
  }

  void _syncLyrics(double currentPos, List<LyricLine> lyrics, double offset) {
    double effectiveTime = currentPos - offset + 0.5; // Bias
    int index = -1;

    for (int i = 0; i < lyrics.length; i++) {
      if (effectiveTime >= lyrics[i].time) {
        index = i;
      } else {
        break;
      }
    }

    if (index != _activeLyricIndex) {
      setState(() => _activeLyricIndex = index);
      if (!_isUserScrolling && _activeLyricIndex >= 0) {
        _scrollToActiveLine();
      }
    }
  }

  void _scrollToActiveLine() {
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: _activeLyricIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        alignment: 0.5,
      );
    }
  }

  Widget _buildSyncedLyricsList(
    List<LyricLine> lyrics,
    Color activeColor,
    Color inactiveColor,
    dynamic playerNotifier,
    double screenHeight,
  ) {
    return Listener(
      onPointerDown: (_) => _isUserScrolling = true,
      onPointerUp: (_) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _isUserScrolling = false;
        });
      },
      child: ScrollablePositionedList.builder(
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: lyrics.length + 1,
        itemBuilder: (context, index) {
          if (index == lyrics.length) {
            return SizedBox(height: screenHeight * 0.5);
          }

          final line = lyrics[index];
          final isActive = index == _activeLyricIndex;
          double opacity = 0.3;
          if (isActive) {
            opacity = 1.0;
          } else if ((index - _activeLyricIndex).abs() <= 1) opacity = 0.6;

          return GestureDetector(
            onTap: () {
              playerNotifier.seek(line.time);
              setState(() => _activeLyricIndex = index);
              _itemScrollController.scrollTo(
                index: index,
                duration: const Duration(milliseconds: 300),
                alignment: 0.5,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 12),
              transform: Matrix4.identity()..scale(isActive ? 1.05 : 1.0),
              alignment: Alignment.center,
              child: Text(
                line.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isActive ? 32 : 22,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                  color: isActive
                      ? activeColor
                      : inactiveColor.withOpacity(opacity),
                  height: 1.4,
                  shadows: isActive
                      ? [
                          BoxShadow(
                              color: activeColor.withOpacity(0.5),
                              blurRadius: 20)
                        ]
                      : [],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRawLyrics(String text, bool isDark, String? artPath,
      String? onlineArtUrl, bool isPlaying) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Use VinylDisk for fallback visual (with path)
          VinylDisk(
              artPath: artPath,
              onlineArtUrl: onlineArtUrl,
              isPlaying: isPlaying),
          const SizedBox(height: 40),
          Text(
            "No Synced Lyrics Found",
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            text.contains("Error") ? text : "Just enjoy the vibes.",
            style: TextStyle(
                fontSize: 14, color: isDark ? Colors.white54 : Colors.black54),
          ),
        ],
      ),
    );
  }
}
