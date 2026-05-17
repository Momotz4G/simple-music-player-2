import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../models/song_model.dart';
import '../../l10n/app_localizations.dart';
import 'smart_art.dart';
import 'music_notification.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    final currentSong = playerState.currentSong;
    final userQueue = playerState.userQueue;
    final playlist = playerState.playlist;

    // DEBUG: Log recommendation queue status
    print(
        "🎨 QueueSheet build: recommendationQueue.length = ${playerState.recommendationQueue.length}");

    // FULL LIST GENERATION (Lazy Loaded via Slivers)
    List<SongModel> upNextFromLibrary = [];

    if (playlist.isNotEmpty) {
      int currentIndex = notifier.currentPlaylistIndex;
      final bool isLoopAll = playerState.loopMode == ja.LoopMode.all;

      if (currentIndex >= 0 && currentIndex < playlist.length) {
        final int fullPlaylistLength = playlist.length;
        final int itemsToDisplay = fullPlaylistLength;

        for (int i = 1; i <= itemsToDisplay; i++) {
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
                color: Colors.black.withValues(alpha: 0.3),
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
                                color: subTextColor!.withValues(alpha: 0.3),
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
                                  l10n.playQueue,
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
                            l10n.nowPlayingSection, subTextColor, context),
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
                              "${l10n.upNextSection} (${userQueue.length})",
                              subTextColor,
                              context),
                        ),
                      ),
                      SliverReorderableList(
                        itemCount: userQueue.length,
                        onReorder: notifier.reorderUserQueue,
                        itemBuilder: (context, index) {
                          final song = userQueue[index];
                          final uniqueKey =
                              ValueKey("queue_${song.filePath}_$index");

                          return Dismissible(
                            key: uniqueKey,
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              color: Colors.redAccent,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white, size: 28),
                            ),
                            onDismissed: (_) {
                              // Remove from queue
                              notifier.removeUserQueueItem(index);
                            },
                            child: _buildQueueTile(
                              context,
                              song,
                              // Key is now on Dismissible, but we pass it down if needed
                              // (though mostly needed by the ReorderableList parent)
                              // key: uniqueKey,
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

                    // 3. FROM LIBRARY / PLAYING FROM (Remote)
                    if (upNextFromLibrary.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildSectionHeader(
                              notifier.isMaster
                                  ? "${l10n.fromLibrarySection} ($totalLibraryCount)"
                                  : "${l10n.fromLibrarySection} ($totalLibraryCount)",
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
                    ],

                    // 4. RECOMMENDATIONS (Endless Queue)
                    if (playerState.recommendationQueue.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildSectionHeader(
                              "${l10n.recommendationsSection} (${playerState.recommendationQueue.length})",
                              Colors.purple[300],
                              context),
                        ),
                      ),
                      SliverReorderableList(
                        itemCount: playerState.recommendationQueue.length,
                        onReorder: notifier.reorderRecommendationQueue,
                        itemBuilder: (context, index) {
                          final song = playerState.recommendationQueue[index];
                          final uniqueKey = ValueKey(
                              'rec_${song.spotifyId ?? song.title}_$index');

                          return Dismissible(
                            key: uniqueKey,
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              color: Colors.redAccent,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white, size: 28),
                            ),
                            onDismissed: (_) =>
                                notifier.removeRecommendationQueueItem(index),
                            child: GestureDetector(
                              onSecondaryTapUp: (details) => _showRecContextMenu(
                                  context, details.globalPosition, song, notifier, ref, index: index),
                              onLongPressStart: (details) => _showRecContextMenu(
                                  context, details.globalPosition, song, notifier, ref, index: index),
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
                                trailingWidget: (Platform.isAndroid || Platform.isIOS)
                                    ? Builder(
                                        builder: (btnContext) => IconButton(
                                          icon: Icon(Icons.more_vert,
                                              size: 18, color: subTextColor),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                              minWidth: 32, minHeight: 32),
                                          onPressed: () {
                                            final RenderBox box = btnContext
                                                .findRenderObject() as RenderBox;
                                            final position =
                                                box.localToGlobal(Offset.zero);
                                            _showRecContextMenu(
                                                context,
                                                Offset(position.dx,
                                                    position.dy + box.size.height),
                                                song,
                                                notifier,
                                                ref,
                                                index: index);
                                          },
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    // 🚀 Loading indicator while fetching recommendations
                    if (playerState.isLoadingRecommendations &&
                        playerState.recommendationQueue.isEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.purple[300],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Loading recommendations...',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (userQueue.isEmpty &&
                        upNextFromLibrary.isEmpty &&
                        playerState.recommendationQueue.isEmpty &&
                        currentSong == null) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Center(child: Text(l10n.queueIsEmpty)),
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
    Widget? trailingWidget,
  }) {
    final tileContent = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: isNowPlaying
          ? BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
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
          if (trailingWidget != null) ...[
            const SizedBox(width: 8),
            trailingWidget,
          ],
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

  /// 🚀 Context menu for recommendation songs (right-click, long-press, or 3-dot button)
  void _showRecContextMenu(BuildContext context, Offset position,
      SongModel song, PlayerNotifier notifier, WidgetRef ref, {int? index}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final textColor = isDark ? Colors.white : Colors.black;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      items: [
        PopupMenuItem(
          value: 'play_next',
          child: Row(
            children: [
              Icon(Icons.playlist_play, size: 20, color: textColor),
              const SizedBox(width: 12),
              Text(l10n.playNext, style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'add_to_queue',
          child: Row(
            children: [
              Icon(Icons.queue_music, size: 20, color: textColor),
              const SizedBox(width: 12),
              Text(l10n.addToQueue, style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'add_to_playlist',
          child: Row(
            children: [
              Icon(Icons.playlist_add, size: 20, color: textColor),
              const SizedBox(width: 12),
              Text(l10n.addToPlaylist, style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'add_to_favorite',
          child: Row(
            children: [
              Icon(Icons.favorite_border, size: 20, color: textColor),
              const SizedBox(width: 12),
              Text(l10n.addToFavorite, style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'go_to_artist',
          child: Row(
            children: [
              Icon(Icons.person_search, size: 20, color: textColor),
              const SizedBox(width: 12),
              Text(l10n.goToArtist, style: TextStyle(color: textColor)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'remove_from_rec',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
              const SizedBox(width: 12),
              const Text('Remove from recommendations', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'play_next') {
        notifier.insertSongNext(song);
        if (context.mounted) {
          showCenterNotification(context,
              label: l10n.playingNext,
              title: l10n.playingNext,
              subtitle: song.title,
              artPath: song.onlineArtUrl,
              onlineArtUrl: song.onlineArtUrl);
        }
      } else if (value == 'add_to_queue') {
        notifier.addToQueue(song);
        if (context.mounted) {
          showCenterNotification(context,
              label: l10n.addedToQueue,
              title: l10n.addedToQueue,
              subtitle: song.title,
              artPath: song.onlineArtUrl,
              onlineArtUrl: song.onlineArtUrl);
        }
      } else if (value == 'add_to_playlist') {
        if (context.mounted) {
          _showAddToPlaylistDialog(context, song, ref);
        }
      } else if (value == 'add_to_favorite') {
        final playlistNotifier = ref.read(playlistProvider.notifier);
        playlistNotifier.addToLikedSongs(song);
        if (context.mounted) {
          showCenterNotification(context,
              label: l10n.addToFavorite,
              title: l10n.addToFavorite,
              subtitle: song.title,
              artPath: song.onlineArtUrl,
              onlineArtUrl: song.onlineArtUrl);
        }
      } else if (value == 'go_to_artist') {
        final librarySongs = ref.read(libraryProvider).songs;
        final artistSongs =
            librarySongs.where((s) => s.artist == song.artist).toList();
        ref.read(navigationStackProvider.notifier).push(
              NavigationItem(
                type: NavigationType.artist,
                data: ArtistSelection(
                  artistName: song.artist,
                  songs: artistSongs,
                ),
              ),
            );
      } else if (value == 'remove_from_rec' && index != null) {
        notifier.removeRecommendationQueueItem(index);
      }
    });
  }

  /// 🚀 Add to Playlist dialog (same as library context menu)
  void _showAddToPlaylistDialog(
      BuildContext context, SongModel song, WidgetRef ref) {
    final playlists = ref.read(playlistProvider);
    final playlistNotifier = ref.read(playlistProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    if (playlists.isEmpty) {
      showCenterNotification(context,
          label: l10n.error,
          title: l10n.noPlaylistsFound,
          backgroundColor: Colors.orangeAccent.withValues(alpha: 0.9));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.addToPlaylist),
        backgroundColor: Theme.of(ctx).cardColor,
        children: playlists
            .map((p) => SimpleDialogOption(
                  onPressed: () {
                    final exists = p.entries.any((e) =>
                        e.title?.toLowerCase() == song.title.toLowerCase() &&
                        e.artist?.toLowerCase() == song.artist.toLowerCase());

                    if (exists) {
                      Navigator.pop(ctx);
                      showCenterNotification(context,
                          label: l10n.error,
                          title: l10n.songAlreadyInPlaylist,
                          subtitle: p.name,
                          onlineArtUrl: song.onlineArtUrl,
                          backgroundColor:
                              Colors.redAccent.withValues(alpha: 0.85));
                    } else {
                      playlistNotifier.addSongToPlaylist(p.id, song);
                      Navigator.pop(ctx);
                      showCenterNotification(context,
                          label: l10n.addedToPlaylistSuccess,
                          title: p.name,
                          subtitle: song.title,
                          onlineArtUrl: song.onlineArtUrl);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(p.name),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
