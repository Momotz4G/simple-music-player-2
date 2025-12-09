import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/search_bridge_provider.dart';
import 'music_notification.dart';

enum SongAction {
  playNext,
  addToQueue,
  addToPlaylist,
  addToFavorites,
  goToArtist
}

class SongContextMenuRegion extends ConsumerWidget {
  final SongModel song;
  final List<SongModel> currentQueue;
  final Widget child;

  const SongContextMenuRegion({
    super.key,
    required this.song,
    required this.currentQueue,
    required this.child,
  });

  static void handleAction(
      BuildContext context, WidgetRef ref, SongAction action, SongModel song) {
    final notifier = ref.read(playerProvider.notifier);

    switch (action) {
      case SongAction.playNext:
        notifier.insertSongNext(song);
        showCenterNotification(context,
            label: "QUEUE UPDATED",
            title: "Playing Next",
            subtitle: song.title,
            // Use artPath instead of artBytes
            artPath: song.filePath,
            onlineArtUrl: song.onlineArtUrl);
        break;

      case SongAction.addToQueue:
        notifier.addToQueue(song);
        showCenterNotification(context,
            label: "QUEUE UPDATED",
            title: "Added to Queue",
            subtitle: song.title,
            // Use artPath instead of artBytes
            artPath: song.filePath,
            onlineArtUrl: song.onlineArtUrl);
        break;

      case SongAction.addToPlaylist:
        final playlists = ref.read(playlistProvider);
        final playlistNotifier = ref.read(playlistProvider.notifier);

        if (playlists.isEmpty) {
          showCenterNotification(context,
              label: "ERROR",
              title: "No Playlists Found",
              backgroundColor: Colors.orangeAccent.withOpacity(0.9));
          return;
        }

        showDialog(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text("Add to Playlist"),
            backgroundColor: Theme.of(context).cardColor,
            children: playlists
                .map((p) => SimpleDialogOption(
                      onPressed: () {
                        // Check duplicate
                        final exists =
                            p.entries.any((e) => e.path == song.filePath);

                        if (exists) {
                          Navigator.pop(context);
                          // 🔴 GLASS RED ERROR
                          showCenterNotification(context,
                              label: "ERROR",
                              title: "Song Already in Playlist",
                              subtitle: p.name,
                              // Use artPath instead of artBytes
                              artPath: song.filePath,
                              backgroundColor:
                                  Colors.redAccent.withOpacity(0.85),
                              onlineArtUrl: song.onlineArtUrl);
                        } else {
                          playlistNotifier.addSongToPlaylist(p.id, song);
                          Navigator.pop(context);
                          // 🟢 SUCCESS
                          showCenterNotification(context,
                              label: "ADDED TO PLAYLIST",
                              title: p.name,
                              subtitle: song.title,
                              // Use artPath instead of artBytes
                              artPath: song.filePath,
                              onlineArtUrl: song.onlineArtUrl);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(p.name),
                      ),
                    ))
                .toList(),
          ),
        );
        break;

      case SongAction.addToFavorites:
        final playlistNotifier = ref.read(playlistProvider.notifier);
        playlistNotifier.addToLikedSongs(song);

        showCenterNotification(context,
            label: "LIKED SONGS",
            title: "Added to Liked Songs",
            subtitle: song.title,
            // FIX: Use artPath instead of artBytes
            artPath: song.filePath,
            onlineArtUrl: song.onlineArtUrl,
            icon: Icons.favorite_rounded, // 🚀 Heart Icon
            backgroundColor: Colors.pinkAccent.withOpacity(0.85));
        break;

      case SongAction.goToArtist:
        final librarySongs = ref.read(libraryProvider).songs;
        final artistSongs =
            librarySongs.where((s) => s.artist == song.artist).toList();

        // FIX: Use Provider Navigation instead of manual Push
        // This ensures MainShell switches the view correctly
        ref.read(navigationStackProvider.notifier).push(
              NavigationItem(
                type: NavigationType.artist,
                data: ArtistSelection(
                  artistName: song.artist,
                  songs: artistSongs,
                ),
              ),
            );
        break;
    }
  }

  Future<void> _showMenu(
      BuildContext context, Offset offset, WidgetRef ref) async {
    final selected = await showMenu<SongAction>(
      context: context,
      position:
          RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx, offset.dy),
      items: [
        const PopupMenuItem(
            value: SongAction.playNext,
            child: Row(children: [
              Icon(Icons.playlist_play),
              SizedBox(width: 12),
              Text('Play Next')
            ])),
        const PopupMenuItem(
            value: SongAction.addToPlaylist,
            child: Row(children: [
              Icon(Icons.playlist_add),
              SizedBox(width: 12),
              Text('Add to Playlist')
            ])),
        const PopupMenuItem(
            value: SongAction.addToFavorites,
            child: Row(children: [
              Icon(Icons.favorite_border),
              SizedBox(width: 12),
              Text('Add to Favorites')
            ])),
        const PopupMenuItem(
            value: SongAction.goToArtist,
            child: Row(children: [
              Icon(Icons.person_search),
              SizedBox(width: 12),
              Text('Go to Artist')
            ])),
      ],
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).cardColor,
    );

    if (selected != null) {
      handleAction(context, ref, selected, song);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          _showMenu(context, details.globalPosition, ref);
        },
        child: child,
      ),
    );
  }
}
