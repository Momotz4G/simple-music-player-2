import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../providers/player_provider.dart';
import '../../models/song_model.dart';
import 'smart_art.dart';

class QueueDrawer extends ConsumerWidget {
  const QueueDrawer({super.key});

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
        // No limit needed with Slivers! It handles thousands easily.
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
    // -------------------------------------------------------------------------

    // Theme Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF1E1E1E).withOpacity(0.9)
        : Colors.white.withOpacity(0.95);
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final dividerColor = isDark ? Colors.white12 : Colors.black12;
    final accentColor = Theme.of(context).colorScheme.primary;

    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = (screenWidth * 0.5).clamp(320.0, double.infinity);

    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: bgColor,
            child: Column(
              children: [
                // --- HEADER ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 10),
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
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: subTextColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: dividerColor),

                // --- SCROLLABLE LIST (USING SLIVERS) ---
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // 1. NOW PLAYING (Static Box)
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
                            subTextColor: subTextColor!,
                            accentColor: accentColor,
                            onTap: null,
                            isDraggable: false,
                          ),
                        ),
                      ],

                      // 2. UP NEXT (Priority Queue - Reorderable Sliver)
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
                              subTextColor: subTextColor!,
                              accentColor: accentColor,
                              onTap: () => notifier.playPrioritySong(song),
                              isDraggable: true,
                              indexForDrag: index,
                            );
                          },
                        ),
                      ],

                      // 3. FROM LIBRARY (Context Queue - Reorderable Sliver)
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
                            final song = upNextFromLibrary[oldVisIndex];
                            final actualOldIndex = playlist.indexOf(song);
                            int actualNewIndex =
                                actualOldIndex + (newVisIndex - oldVisIndex);
                            notifier.reorderMainPlaylist(
                                actualOldIndex, actualNewIndex);
                          },
                          itemBuilder: (context, index) {
                            final song = upNextFromLibrary[index];
                            final originalIndex = playlist.indexOf(song);
                            return _buildQueueTile(
                              context,
                              song,
                              key: ValueKey(
                                  'lib_${song.filePath}_$originalIndex'),
                              number: index + 1,
                              textColor: textColor,
                              subTextColor: subTextColor!,
                              accentColor: accentColor,
                              onTap: () => notifier.playSong(song),
                              isDraggable: true,
                              indexForDrag: index,
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

                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    final bool isClickable = onTap != null;

    final tileContent = Container(
      height: 56, // Fixed Height for Optimization
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
          // DRAG HANDLE (Left Side)
          if (isDraggable && indexForDrag != null)
            ReorderableDragStartListener(
              index: indexForDrag,
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Icon(Icons.drag_handle_rounded,
                    size: 18, color: subTextColor),
              ),
            )
          else
            const SizedBox(width: 30),

          // Number / Visualizer
          if (isNowPlaying && isPlayingState)
            SizedBox(
              width: 30,
              height: 30,
              child: Center(child: _MiniVisualizer(color: accentColor)),
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

          // Use SmartArt here
          SmartArt(
            path: song.filePath,
            size: 40,
            borderRadius: 4,
            onlineArtUrl: song.onlineArtUrl,
          ),

          const SizedBox(width: 12),

          // Info
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

          // Duration
          Text(
            _formatDuration(song.duration),
            style: TextStyle(color: subTextColor, fontSize: 12),
          ),
        ],
      ),
    );

    return MouseRegion(
      key: key,
      cursor: isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: tileContent,
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _MiniVisualizer extends StatefulWidget {
  final Color color;
  const _MiniVisualizer({required this.color});

  @override
  State<_MiniVisualizer> createState() => _MiniVisualizerState();
}

class _MiniVisualizerState extends State<_MiniVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final value = (1 + 0.5 * index * _controller.value).remainder(1.0);
            return Container(
              width: 3,
              height: 8 + (12 * value),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }
}
