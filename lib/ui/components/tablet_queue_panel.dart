import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../providers/player_provider.dart';
import '../../models/song_model.dart';
import '../../l10n/app_localizations.dart';
import 'smart_art.dart';

/// A 320dp wide side panel for the playback queue, designed for tablet
/// landscape mode. Slides in from the trailing (right) edge using a
/// [SlideTransition]. Reuses the same queue tile building logic as
/// [QueueDrawer] — now playing, user queue (drag-to-reorder), library
/// tracks, and recommendations.
///
/// In portrait mode, use [TabletQueuePanel.showAsBottomSheet] to present
/// the queue as a modal bottom sheet covering the lower 60% of the screen.
class TabletQueuePanel extends ConsumerStatefulWidget {
  /// Whether the panel is currently visible (open).
  final bool isVisible;

  /// Called when the user taps the close button.
  final VoidCallback? onClose;

  const TabletQueuePanel({
    super.key,
    required this.isVisible,
    this.onClose,
  });

  /// Shows the queue as a modal bottom sheet covering the lower 60% of the
  /// screen. Designed for tablet portrait mode per requirement 5.2.
  ///
  /// Returns the [Future] from [showModalBottomSheet] so callers can await
  /// dismissal if needed.
  static Future<void> showAsBottomSheet(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SizedBox(
          height: screenHeight * 0.6,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _QueuePanelContent(
              onClose: () => Navigator.of(sheetContext).pop(),
              isBottomSheet: true,
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<TabletQueuePanel> createState() => _TabletQueuePanelState();
}

class _TabletQueuePanelState extends ConsumerState<TabletQueuePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Off-screen to the right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    if (widget.isVisible) {
      _slideController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant TabletQueuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _slideController.forward();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _slideController.reverse();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: _QueuePanelContent(onClose: widget.onClose),
    );
  }
}

/// The actual content of the queue panel — header + scrollable queue list.
///
/// When [isBottomSheet] is true, the panel omits the fixed width and left
/// border styling (used in the portrait bottom sheet variant).
class _QueuePanelContent extends ConsumerWidget {
  final VoidCallback? onClose;
  final bool isBottomSheet;

  const _QueuePanelContent({this.onClose, this.isBottomSheet = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    final currentSong = playerState.currentSong;
    final userQueue = playerState.userQueue;
    final playlist = playerState.playlist;

    // Build the "up next from library" list
    List<SongModel> upNextFromLibrary = [];

    if (playlist.isNotEmpty) {
      int currentIndex = notifier.currentPlaylistIndex;
      final bool isLoopAll = playerState.loopMode == ja.LoopMode.all;

      if (currentIndex >= 0 && currentIndex < playlist.length) {
        final int fullPlaylistLength = playlist.length;

        for (int i = 1; i <= fullPlaylistLength; i++) {
          int nextIndex = currentIndex + i;

          if (isLoopAll) {
            nextIndex = nextIndex % fullPlaylistLength;
          } else if (nextIndex >= fullPlaylistLength) {
            break;
          }

          if (playlist[nextIndex].filePath != currentSong?.filePath) {
            upNextFromLibrary.add(playlist[nextIndex]);
          }
        }
      }
    }

    final int totalLibraryCount = upNextFromLibrary.length;

    // Theme Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF1E1E1E).withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.98);
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: isBottomSheet ? null : 320,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : null,
        border: isBottomSheet
            ? null
            : Border(
                left: BorderSide(color: dividerColor, width: 1),
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: isBottomSheet ? const Offset(0, -2) : const Offset(-2, 0),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Column(
            children: [
              // --- HEADER ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                child: Row(
                  children: [
                    Icon(Icons.queue_music, color: accentColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.playQueue,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: subTextColor, size: 20),
                      onPressed: onClose,
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: dividerColor),

              // --- SCROLLABLE QUEUE LIST (SLIVERS) ---
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // 1. NOW PLAYING
                    if (currentSong != null) ...[
                      SliverToBoxAdapter(
                        child: _buildSectionHeader(
                            l10n.nowPlayingSection, subTextColor),
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
                          onTap: null,
                          isDraggable: false,
                        ),
                      ),
                    ],

                    // 2. UP NEXT (Priority Queue - Reorderable)
                    if (userQueue.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildSectionHeader(
                              l10n.upNextCount(userQueue.length), subTextColor),
                        ),
                      ),
                      SliverReorderableList(
                        itemCount: userQueue.length,
                        onReorder: notifier.reorderUserQueue,
                        itemBuilder: (context, index) {
                          final song = userQueue[index];
                          final uniqueKey =
                              ValueKey("tq_queue_${song.filePath}_$index");

                          return Dismissible(
                            key: uniqueKey,
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              color: Colors.red.withValues(alpha: 0.8),
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete,
                                  color: Colors.white, size: 20),
                            ),
                            onDismissed: (_) =>
                                notifier.removeUserQueueItem(index),
                            child: _buildQueueTile(
                              context,
                              song,
                              number: index + 1,
                              textColor: textColor,
                              subTextColor: subTextColor,
                              accentColor: accentColor,
                              onTap: () => notifier.playPrioritySong(song),
                              isDraggable: true,
                              indexForDrag: index,
                            ),
                          );
                        },
                      ),
                    ],

                    // 3. FROM LIBRARY
                    if (upNextFromLibrary.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildSectionHeader(
                              l10n.fromLibraryCount(totalLibraryCount),
                              subTextColor),
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
                                'tq_lib_${song.filePath}_$originalIndex'),
                            number: index + 1,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            accentColor: accentColor,
                            onTap: () => notifier.playSong(song),
                            isDraggable: true,
                            indexForDrag: index,
                          );
                        },
                      ),
                    ],

                    // 4. RECOMMENDATIONS (Endless Queue)
                    if (playerState.recommendationQueue.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildSectionHeader(
                              l10n.recommendationsCount(
                                  playerState.recommendationQueue.length),
                              Colors.purple[300]),
                        ),
                      ),
                      SliverReorderableList(
                        itemCount: playerState.recommendationQueue.length,
                        onReorder: notifier.reorderRecommendationQueue,
                        itemBuilder: (context, index) {
                          final song = playerState.recommendationQueue[index];
                          final uniqueKey = ValueKey(
                              'tq_rec_${song.spotifyId ?? song.title}_$index');

                          return Dismissible(
                            key: uniqueKey,
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              color: Colors.red.withValues(alpha: 0.8),
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete,
                                  color: Colors.white, size: 20),
                            ),
                            onDismissed: (_) =>
                                notifier.removeRecommendationQueueItem(index),
                            child: _buildQueueTile(
                              context,
                              song,
                              number: index + 1,
                              textColor: textColor,
                              subTextColor: subTextColor,
                              accentColor: Colors.purple[300]!,
                              onTap: () =>
                                  notifier.playRecommendationSong(index),
                              isDraggable: true,
                              indexForDrag: index,
                            ),
                          );
                        },
                      ),
                    ],

                    // Loading indicator for recommendations
                    if (playerState.isLoadingRecommendations &&
                        playerState.recommendationQueue.isEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.purple[300],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Loading recommendations...',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Empty state
                    if (userQueue.isEmpty &&
                        upNextFromLibrary.isEmpty &&
                        playerState.recommendationQueue.isEmpty &&
                        currentSong == null) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Center(
                            child: Text(
                              l10n.queueIsEmpty,
                              style: TextStyle(color: subTextColor),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Bottom padding
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color? color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
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
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: isNowPlaying
          ? BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              border: Border(
                left: BorderSide(color: accentColor, width: 3),
              ),
            )
          : null,
      child: Row(
        children: [
          // Drag handle or spacer
          if (isDraggable && indexForDrag != null)
            ReorderableDragStartListener(
              index: indexForDrag,
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(Icons.drag_handle_rounded,
                    size: 16, color: subTextColor),
              ),
            )
          else
            const SizedBox(width: 24),

          // Number / Now Playing indicator
          if (isNowPlaying && isPlayingState)
            SizedBox(
              width: 24,
              child: Icon(Icons.equalizer, color: accentColor, size: 16),
            )
          else if (number != null)
            SizedBox(
              width: 24,
              child: Text(
                "$number",
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            const SizedBox(width: 24),

          const SizedBox(width: 8),

          // Album art
          SmartArt(
            path: song.filePath,
            size: 36,
            borderRadius: 4,
            onlineArtUrl: song.onlineArtUrl,
          ),

          const SizedBox(width: 10),

          // Song info
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
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Duration
          Text(
            _formatDuration(song.duration),
            style: TextStyle(color: subTextColor, fontSize: 11),
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

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
