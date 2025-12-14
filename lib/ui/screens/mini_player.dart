import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_music_player_2/providers/player_provider.dart';
import 'package:simple_music_player_2/ui/components/smart_art.dart';
import 'package:window_manager/window_manager.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../../providers/interface_provider.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final song = state.currentSong;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // Allow dragging the window from anywhere (desktop only)
        onPanUpdate: (details) async {
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
            await windowManager.startDragging();
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black, // Fallback
            borderRadius: BorderRadius.zero,
          ),
          child: Stack(
            children: [
              // 1. Background Art
              if (song != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.6,
                    child: SmartArt(
                      path: song.filePath,
                      onlineArtUrl: song.onlineArtUrl,
                      size: 400, // Cover entire background
                      borderRadius: 0,
                    ),
                  ),
                ),

              // 2. Glass Overlay
              Positioned.fill(
                child: GlassmorphicContainer(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 0,
                  blur: 20,
                  alignment: Alignment.center,
                  border: 0,
                  linearGradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderGradient: const LinearGradient(colors: [
                    Colors.white24,
                    Colors.white10,
                  ]),
                  child: Container(),
                ),
              ),

              // 3. Content
              if (song != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      // Art
                      SmartArt(
                        path: song.filePath,
                        onlineArtUrl: song.onlineArtUrl,
                        size: 80,
                        borderRadius: 8,
                      ),
                      const SizedBox(width: 16),
                      // Info & Controls
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Controls Row
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.skip_previous_rounded,
                                      color: Colors.white),
                                  onPressed: () => ref
                                      .read(playerProvider.notifier)
                                      .playPrevious(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      state.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(playerProvider.notifier)
                                          .togglePlay();
                                    },
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(),
                                    iconSize: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.skip_next_rounded,
                                      color: Colors.white),
                                  onPressed: () => ref
                                      .read(playerProvider.notifier)
                                      .playNext(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Center(
                  child: Text(
                    "No Music Playing",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),

              // 4. Return to Full Button (Top Right Absolute)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.open_in_full_rounded,
                      color: Colors.white54, size: 20),
                  tooltip: "Expand",
                  onPressed: () {
                    ref.read(interfaceProvider.notifier).exitMiniPlayer();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
