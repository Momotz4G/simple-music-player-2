import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/playlist_provider.dart';
import '../../models/playlist_model.dart';
import '../components/playlist_collage.dart';
import '../../providers/search_bridge_provider.dart';
import '../../providers/settings_provider.dart';
import '../../l10n/app_localizations.dart';

import '../components/playlist_sharing_dialogs.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistProvider);
    final notifier = ref.read(playlistProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final hasTheme = settings.atmosphereTheme != AtmosphereTheme.none;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = hasTheme
        ? (isDark
            ? Colors.black.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.15))
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, notifier),
        label: Text(AppLocalizations.of(context)!.newPlaylist),
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
            // HEADER (Shifted Mobile)
            Padding(
              padding: EdgeInsets.only(
                  left: (Platform.isAndroid || Platform.isIOS) ? 40.0 : 0.0),
              child: Text(
                AppLocalizations.of(context)!.playlists,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
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
                          size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.noPlaylistsYet,
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
                    // SORT: Pinned "Liked Songs" first
                    final sortedPlaylists = [...playlists];
                    sortedPlaylists.sort((a, b) {
                      if (a.name == "Liked Songs") return -1;
                      if (b.name == "Liked Songs") return 1;
                      return 0; // Keep original order for others
                    });

                    final playlist = sortedPlaylists[index];
                    final isLikedSongs = playlist.name == "Liked Songs";

                    // GET IMAGES FOR COLLAGE
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
          // FIX: Use Provider Navigation instead of Push
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
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 4-TILE COLLAGE or SPOTIFY COVER
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
                      AppLocalizations.of(context)!
                          .songsCount(playlist.entries.length),
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
        title: Text(AppLocalizations.of(context)!.createPlaylist,
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Option 1: Create Empty Playlist
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: Text(AppLocalizations.of(context)!.emptyPlaylist),
              subtitle:
                  Text(AppLocalizations.of(context)!.emptyPlaylistSubtitle),
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
              title: Text(AppLocalizations.of(context)!.importFromSpotify),
              subtitle:
                  Text(AppLocalizations.of(context)!.importFromSpotifySubtitle),
              onTap: () {
                Navigator.pop(context);
                _showSpotifyImportDialog(context, notifier);
              },
            ),
            const Divider(),
            // Option 3: Import from YouTube Music
            ListTile(
              leading:
                  const Icon(Icons.music_video_outlined, color: Colors.red),
              title: Text(AppLocalizations.of(context)!.importFromYoutubeMusic),
              subtitle: Text(
                  AppLocalizations.of(context)!.importFromYoutubeMusicSubtitle),
              onTap: () {
                Navigator.pop(context);
                _showYoutubeMusicImportDialog(context, notifier);
              },
            ),
            const Divider(),
            // Option 4: Import from M3U
            ListTile(
              leading:
                  const Icon(Icons.file_upload_outlined, color: Colors.blue),
              title: Text(AppLocalizations.of(context)!.importFromM3u),
              subtitle:
                  Text(AppLocalizations.of(context)!.importFromM3uSubtitle),
              onTap: () async {
                final l10n = AppLocalizations.of(context)!;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);

                await notifier.importM3uPlaylist(onStatus: (statusKey, {args}) {
                  final msg = _getLocalizedStatus(l10n, statusKey, args);
                  messenger.showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                });
              },
            ),
            const Divider(),
            // Option 5: Import via Code
            ListTile(
              leading: Icon(Icons.share_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(AppLocalizations.of(context)!.importViaCode),
              subtitle:
                  Text(AppLocalizations.of(context)!.importViaCodeSubtitle),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => const ImportPlaylistDialog(),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel)),
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
        title: Text(AppLocalizations.of(context)!.newPlaylist,
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.playlistNameHint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                notifier.createPlaylist(controller.text);
                Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.of(context)!.createPlaylist),
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
              Text(AppLocalizations.of(context)!.importSpotifyPlaylist,
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
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (controller.text.isEmpty) return;
                              final l10n = AppLocalizations.of(context)!;
                              isLoadingNotifier.value = true;

                              final result =
                                  await notifier.importSpotifyPlaylist(
                                controller.text,
                                onStatus: (key, {args}) {
                                  statusNotifier.value =
                                      _getLocalizedStatus(l10n, key, args);
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
                      label: Text(AppLocalizations.of(context)!.download),
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

  void _showYoutubeMusicImportDialog(
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
              Icon(Icons.music_video, color: Colors.red[400]),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.importYoutubeMusicPlaylist,
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
                    hintText: "https://music.youtube.com/playlist?list=...",
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
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (controller.text.isEmpty) return;
                              final l10n = AppLocalizations.of(context)!;
                              isLoadingNotifier.value = true;

                              final result =
                                  await notifier.importYoutubeMusicPlaylist(
                                controller.text,
                                onStatus: (key, {args}) {
                                  statusNotifier.value =
                                      _getLocalizedStatus(l10n, key, args);
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
                      label: Text(AppLocalizations.of(context)!.download),
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

  String _getLocalizedStatus(
      AppLocalizations l10n, String key, Map<String, dynamic>? args) {
    switch (key) {
      case "invalidSpotifyUrl":
        return "❌ ${l10n.invalidSpotifyUrl}";
      case "invalidYoutubeMusicUrl":
        return "❌ ${l10n.invalidYoutubeMusicUrl}";
      case "invalidM3uFile":
        return "❌ Invalid M3U File";
      case "fetchingPlaylistInfo":
        return "📋 ${l10n.fetchingPlaylistInfo}";
      case "failedFetchPlaylistInfo":
        return "❌ ${l10n.failedFetchPlaylistInfo}";
      case "fetchingTracksFrom":
        return "🎵 ${l10n.fetchingTracksFrom(args?['name'] ?? '')}";
      case "noTracksFound":
        return "❌ ${l10n.noTracksFound}";
      case "creatingPlaylistWithTracks":
        return "📝 ${l10n.creatingPlaylistWithTracks(args?['count'] ?? 0)}";
      case "importedTracks":
        return "✅ ${l10n.importedTracks(args?['count'] ?? 0)}";
      case "importFailed":
        return "❌ ${l10n.importFailed(args?['error'] ?? '')}";
      default:
        return key;
    }
  }

  void _showDeleteDialog(
      BuildContext context, PlaylistNotifier notifier, PlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deletePlaylistTitle),
        content: Text(
            AppLocalizations.of(context)!.deletePlaylistConfirm(playlist.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              notifier.deletePlaylist(playlist.id);
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }
}
