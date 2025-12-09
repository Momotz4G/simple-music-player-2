import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;

import '../../providers/library_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
import '../components/song_card_overlay.dart';
import '../components/playlist_collage.dart';
import '../../providers/search_bridge_provider.dart';

class PlaylistDetailPage extends ConsumerWidget {
  final String playlistId;

  const PlaylistDetailPage({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistProvider);
    final notifier = ref.read(playlistProvider.notifier);

    final playlistIndex = playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex == -1) {
      return const Scaffold(body: Center(child: Text("Playlist not found")));
    }

    final playlist = playlists[playlistIndex];

    final library = p.Provider.of<LibraryProvider>(context);
    final allLibrarySongs = library.songs;

    // Map Entries to Songs + Dates
    final List<_PlaylistRowData> rowData = [];
    // ✅ CHANGED: Collect paths (String) instead of bytes
    final List<String> headerImagePaths = [];
    final List<String?> headerArtUrls = [];

    for (var entry in playlist.entries) {
      // 🚀 TRY TO FIND IN LIBRARY FIRST
      try {
        final song =
            allLibrarySongs.firstWhere((s) => s.filePath == entry.path);
        rowData.add(_PlaylistRowData(song, entry.dateAdded));

        if (headerImagePaths.length < 4) {
          headerImagePaths.add(song.filePath);
          headerArtUrls.add(song.onlineArtUrl);
        }
      } catch (e) {
        // 🚀 FALLBACK: USE METADATA FROM ENTRY
        // Even if title is null, we should try to show something
        final title = entry.title ?? entry.path.split('/').last;

        final song = SongModel(
          title: title.isEmpty ? "Unknown Song" : title,
          artist: entry.artist ?? "Unknown Artist",
          album: entry.album ?? "Unknown Album",
          filePath: entry.path,
          fileExtension: ".mp3", // Assumption
          duration: 0, // We might not have duration
          onlineArtUrl: entry.artUrl,
          sourceUrl: entry.sourceUrl ?? "", // USE SOURCE URL
        );
        rowData.add(_PlaylistRowData(song, entry.dateAdded));
        if (headerImagePaths.length < 4) {
          // Use URL if path doesn't exist? SmartArt handles it.
          headerImagePaths.add(entry.path);
          headerArtUrls.add(entry.artUrl);
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () {
                // 🚀 POP FROM STACK
                ref.read(navigationStackProvider.notifier).pop();
              },
            ),
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(playlist.name),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Blur
                  if (headerImagePaths.isNotEmpty)
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Opacity(
                        opacity: 0.4,
                        child: PlaylistCollage(
                            // ✅ PASS PATHS & URLS
                            imagePaths: headerImagePaths,
                            onlineArtUrls: headerArtUrls,
                            size: 400),
                      ),
                    ),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Theme.of(context).scaffoldBackgroundColor
                        ],
                      ),
                    ),
                  ),

                  // Foreground Collage
                  Center(
                    child: Container(
                      decoration: const BoxDecoration(boxShadow: [
                        BoxShadow(
                            color: Colors.black45,
                            blurRadius: 20,
                            offset: Offset(0, 10))
                      ]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: PlaylistCollage(
                            // ✅ PASS PATHS & URLS
                            imagePaths: headerImagePaths,
                            onlineArtUrls: headerArtUrls,
                            size: 160),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      onPressed: rowData.isNotEmpty
                          ? () {
                              ref.read(playerProvider.notifier).playSong(
                                  rowData.first.song,
                                  newQueue:
                                      rowData.map((r) => r.song).toList());
                            }
                          : null,
                      backgroundColor: accentColor,
                      child: const Icon(Icons.play_arrow, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'delete') {
                    notifier.deletePlaylist(playlistId);
                    // POP FROM STACK
                    ref.read(navigationStackProvider.notifier).pop();
                  } else if (value == 'rename') {
                    _showRenameDialog(context, ref, playlist);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'rename', child: Text("Rename")),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text("Delete Playlist",
                          style: TextStyle(color: Colors.red))),
                ],
              ),
              const SizedBox(width: 16),
            ],
          ),
          if (rowData.isEmpty)
            SliverFillRemaining(
              child: Center(
                  child: Text("No songs added yet",
                      style: TextStyle(color: subtitleColor))),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final data = rowData[index];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Number
                        SizedBox(
                            width: 30,
                            child: Text("${index + 1}",
                                style: TextStyle(
                                    color: subtitleColor,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center)),
                        const SizedBox(width: 10),
                        // Overlay
                        SongCardOverlay(
                            song: data.song,
                            size: 48,
                            playQueue: rowData.map((r) => r.song).toList(),
                            radius: 6),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                            child: Text(data.song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w500))),
                        const SizedBox(width: 10),
                        // Date Added
                        Text(_formatDate(data.dateAdded),
                            style:
                                TextStyle(color: subtitleColor, fontSize: 12)),
                      ],
                    ),
                    subtitle: Text(
                        (data.song.artist == "Unknown Artist" ||
                                data.song.artist == "Unknown")
                            ? data.song.filePath
                            : data.song.artist,
                        maxLines: 1,
                        style: TextStyle(color: subtitleColor, fontSize: 12)),
                    trailing: IconButton(
                      icon: Icon(Icons.remove_circle_outline,
                          color: subtitleColor),
                      tooltip: "Remove from Playlist",
                      onPressed: () => notifier.removeSongFromPlaylist(
                          playlistId, data.song.filePath),
                    ),
                    onTap: () {
                      ref.read(playerProvider.notifier).playSong(data.song,
                          newQueue: rowData.map((r) => r.song).toList());
                    },
                  );
                },
                childCount: rowData.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showRenameDialog(
      BuildContext context, WidgetRef ref, PlaylistModel playlist) {
    final controller = TextEditingController(text: playlist.name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("Rename Playlist", style: TextStyle(color: textColor)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(playlistProvider.notifier)
                    .renamePlaylist(playlist.id, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }
}

class _PlaylistRowData {
  final SongModel song;
  final DateTime dateAdded;
  _PlaylistRowData(this.song, this.dateAdded);
}
