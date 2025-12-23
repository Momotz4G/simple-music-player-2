import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../providers/player_provider.dart';
import '../../models/song_model.dart';
import 'smart_art.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    final currentSong = playerState.currentSong;
    final userQueue = playerState.userQueue;
    final playlist = playerState.playlist;

    // FULL LIST GENERATION (Lazy Loaded via Slivers)
    List<SongModel> upNextFromLibrary = [];

    if (currentSong != null && playlist.isNotEmpty) {
      final currentIndex =
          playlist.indexWhere((s) => s.filePath == currentSong.filePath);
      final bool isLoopAll = playerState.loopMode == ja.LoopMode.all;

      if (currentIndex != -1) {
        final int fullPlaylistLength = playlist.length;
        final int itemsToDisplay = fullPlaylistLength;

        for (int i = 1; i <= itemsToDisplay; i++) {
          int nextIndex = currentIndex + i;

          if (isLoopAll) {
            nextIndex = nextIndex % fullPlaylistLength;
          } else if (nextIndex >= fullPlaylistLength) {
            break;
          }

          if (playlist[nextIndex].filePath != currentSong.filePath) {
            upNextFromLibrary.add(playlist[nextIndex]);
          }
        }
      }
    }

    final int totalLibraryCount = upNextFromLibrary.length;

    // Theme Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF1E1E1E)
        : Colors.white; // Solid color for sheet
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final accentColor = Theme.of(context).colorScheme.primary;

    // 🚀 FIXED HEIGHT (1/2 Screen to 100%)
    return DraggableScrollableSheet(
      initialChildSize: 0.5, // Start at 1/2 screen
      minChildSize: 0.4,
      maxChildSize: 1.0, // 🚀 Allow full screen drag
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            children: [
              // --- SCROLLABLE LIST ---
              Expanded(
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    // 0. HEADER (Moved here to be draggable)
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- DRAG HANDLE ---
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 8),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: subTextColor!.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          // --- HEADER TEXT ---
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Icons.queue_music, color: accentColor),
                                const SizedBox(width: 12),
                                Text(
                                  "Play Queue",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      ),
                    ),

                    // 1. NOW PLAYING
                    if (currentSong != null) ...[
                      SliverToBoxAdapter(
                        child: _buildSectionHeader(
                            "NOW PLAYING", subTextColor, context),
                      ),
                      SliverToBoxAdapter(
                        child: _buildQueueTile(
                          context,
                          currentSong,
                          isNowPlaying: true,
                          isPlayingState: playerState.isPlaying,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          accentColor: accentColor,
                          onTap: null, // Tap to maximize?
                        ),
                      ),
                    ],

                    // 2. UP NEXT
                    if (userQueue.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildSectionHeader(
                              "UP NEXT (${userQueue.length})",
                              subTextColor,
                              context),
                        ),
                      ),
                      SliverReorderableList(
                        itemCount: userQueue.length,
                        onReorder: notifier.reorderUserQueue,
                        itemBuilder: (context, index) {
                          final song = userQueue[index];
                          return _buildQueueTile(
                            context,
                            song,
                            key: ValueKey("queue_${song.filePath}_$index"),
                            number: index + 1,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            accentColor: accentColor,
                            onTap: () => notifier.playPrioritySong(song),
                            isDraggable: true,
                            indexForDrag: index,
                          );
                        },
                      ),
                    ],

                    // 3. FROM LIBRARY
                    if (upNextFromLibrary.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildSectionHeader(
                              "FROM LIBRARY (${totalLibraryCount})",
                              subTextColor,
                              context),
                        ),
                      ),
                      SliverReorderableList(
                        itemCount: upNextFromLibrary.length,
                        onReorder: (oldVisIndex, newVisIndex) {
                          // Handle reordering context playlist if supported
                          // For now, limited support or relying on notifier
                          // (Usually reordering main playlist is complex)
                        },
                        itemBuilder: (context, index) {
                          final song = upNextFromLibrary[index];
                          final originalIndex = playlist.indexOf(song);
                          return _buildQueueTile(
                            context,
                            song,
                            key:
                                ValueKey('lib_${song.filePath}_$originalIndex'),
                            number: index + 1,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            accentColor: accentColor,
                            onTap: () => notifier.playSong(song),
                            // Disable dragging for library tracks to simplify for now
                            // unless notifier supports it robustly
                            isDraggable: false,
                          );
                        },
                      ),
                    ] else if (userQueue.isEmpty && currentSong == null) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Center(child: Text("Queue is empty")),
                        ),
                      )
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 50)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Color? color, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildQueueTile(
    BuildContext context,
    SongModel song, {
    Key? key,
    bool isNowPlaying = false,
    bool isPlayingState = false,
    int? number,
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
    VoidCallback? onTap,
    bool isDraggable = false,
    int? indexForDrag,
  }) {
    final tileContent = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: isNowPlaying
          ? BoxDecoration(
              color: accentColor.withOpacity(0.1),
              border: Border(
                left: BorderSide(color: accentColor, width: 4),
              ),
            )
          : null,
      child: Row(
        children: [
          if (isDraggable && indexForDrag != null)
            Padding(
              // Removed ReorderableDragStartListener wrapper as it's implicit in ReorderableList usually, or needs handle
              // Actually SliverReorderableList needs ReorderableDragStartListener
              padding: const EdgeInsets.only(right: 12.0),
              child: ReorderableDragStartListener(
                index: indexForDrag,
                child: Icon(Icons.drag_handle_rounded,
                    size: 18, color: subTextColor),
              ),
            )
          else
            const SizedBox(width: 30),
          if (isNowPlaying && isPlayingState)
            SizedBox(
              width: 30,
              height: 30,
              child: Center(
                  child: Icon(Icons.equalizer,
                      color: accentColor, size: 18)), // Simple static for now
            )
          else if (number != null)
            SizedBox(
              width: 30,
              child: Text(
                "$number",
                style: TextStyle(
                    color: subTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            )
          else
            const SizedBox(width: 30),
          const SizedBox(width: 12),
          SmartArt(
            path: song.filePath,
            size: 40,
            borderRadius: 4,
            onlineArtUrl: song.onlineArtUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isNowPlaying ? accentColor : textColor,
                    fontWeight:
                        isNowPlaying ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      key: key,
      child: InkWell(
        onTap: onTap,
        child: tileContent,
      ),
    );
  }
}
