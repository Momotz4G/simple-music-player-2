import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;

import '../../providers/playlist_provider.dart';
import '../../providers/library_provider.dart';
import '../../models/playlist_model.dart';
import '../components/playlist_collage.dart';
import '../../providers/search_bridge_provider.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistProvider);
    final notifier = ref.read(playlistProvider.notifier);
    // We don't strictly need library provider anymore for paths,
    // but keeping it if you use it elsewhere.
    final library = p.Provider.of<LibraryProvider>(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, notifier),
        label: const Text("New Playlist"),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              'Playlists',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
            ),
            const SizedBox(height: 24),
            if (playlists.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.queue_music,
                          size: 64, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        "No playlists yet",
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    // 🚀 SORT: Pinned "Liked Songs" first
                    final sortedPlaylists = [...playlists];
                    sortedPlaylists.sort((a, b) {
                      if (a.name == "Liked Songs") return -1;
                      if (b.name == "Liked Songs") return 1;
                      return 0; // Keep original order for others
                    });

                    final playlist = sortedPlaylists[index];
                    final isLikedSongs = playlist.name == "Liked Songs";

                    // 🚀 GET IMAGES FOR COLLAGE
                    // ✅ FIX: Get Paths instead of Bytes
                    final imagePaths = playlist.entries
                        .take(4)
                        .map((entry) => entry.path)
                        .toList();

                    return _buildPlaylistCard(context, playlist, cardColor,
                        textColor, notifier, imagePaths, ref, isLikedSongs);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(
      BuildContext context,
      PlaylistModel playlist,
      Color cardColor,
      Color textColor,
      PlaylistNotifier notifier,
      List<String> imagePaths,
      WidgetRef ref,
      bool isLikedSongs) {
    // ✅ CHANGED TYPE

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 🚀 FIX: Use Provider Navigation instead of Push
          ref.read(navigationStackProvider.notifier).push(
                NavigationItem(
                    type: NavigationType.playlist, data: playlist.id),
              );
        },
        onSecondaryTap: () => _showDeleteDialog(context, notifier, playlist),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🚀 4-TILE COLLAGE or SPOTIFY COVER
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  // Use Spotify cover if available, else collage
                  child:
                      playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty
                          ? Image.network(
                              playlist.coverUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => PlaylistCollage(
                                  imagePaths: imagePaths,
                                  onlineArtUrls: playlist.entries
                                      .take(4)
                                      .map((e) => e.artUrl)
                                      .toList(),
                                  size: 200),
                            )
                          : PlaylistCollage(
                              imagePaths: imagePaths,
                              onlineArtUrls: playlist.entries
                                  .take(4)
                                  .map((e) => e.artUrl)
                                  .toList(),
                              size: 200),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isLikedSongs)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(Icons.push_pin_rounded,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        Expanded(
                          child: Text(
                            playlist.name,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${playlist.entries.length} songs",
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, PlaylistNotifier notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("Create Playlist",
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Option 1: Create Empty Playlist
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text("Empty Playlist"),
              subtitle: const Text("Create a new empty playlist"),
              onTap: () {
                Navigator.pop(context);
                _showNameDialog(context, notifier);
              },
            ),
            const Divider(),
            // Option 2: Import from Spotify
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined,
                  color: Colors.green),
              title: const Text("Import from Spotify"),
              subtitle: const Text("Paste a Spotify playlist URL"),
              onTap: () {
                Navigator.pop(context);
                _showSpotifyImportDialog(context, notifier);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
        ],
      ),
    );
  }

  void _showNameDialog(BuildContext context, PlaylistNotifier notifier) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("New Playlist",
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: const InputDecoration(hintText: "Playlist Name"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                notifier.createPlaylist(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showSpotifyImportDialog(
      BuildContext context, PlaylistNotifier notifier) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusNotifier = ValueNotifier<String?>(null);
    final isLoadingNotifier = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Row(
            children: [
              Icon(Icons.music_note, color: Colors.green[400]),
              const SizedBox(width: 8),
              Text("Import Spotify Playlist",
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: const InputDecoration(
                    hintText: "https://open.spotify.com/playlist/...",
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<String?>(
                  valueListenable: statusNotifier,
                  builder: (context, status, _) {
                    if (status == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: status.startsWith("❌")
                              ? Colors.red
                              : status.startsWith("✅")
                                  ? Colors.green
                                  : Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: isLoadingNotifier,
                  builder: (context, isLoading, _) {
                    if (!isLoading) return const SizedBox.shrink();
                    return const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: isLoadingNotifier,
              builder: (context, isLoading, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (controller.text.isEmpty) return;

                              isLoadingNotifier.value = true;

                              final result =
                                  await notifier.importSpotifyPlaylist(
                                controller.text,
                                onProgress: (status) {
                                  statusNotifier.value = status;
                                },
                              );

                              isLoadingNotifier.value = false;

                              if (result != null && context.mounted) {
                                await Future.delayed(
                                    const Duration(milliseconds: 500));
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                      icon: const Icon(Icons.download),
                      label: const Text("Import"),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, PlaylistNotifier notifier, PlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Playlist?"),
        content: Text("Delete '${playlist.name}'?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              notifier.deletePlaylist(playlist.id);
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
