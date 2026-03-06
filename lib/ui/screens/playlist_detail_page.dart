import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart' as p;

import '../../providers/library_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
import '../components/song_card_overlay.dart';
import '../components/playlist_collage.dart';
import '../../providers/search_bridge_provider.dart';
import '../../services/bulk_download_service.dart';
import '../../services/smart_download_service.dart'; // 🚀 IMPORT
import '../../models/song_metadata.dart'; // 🚀 IMPORT
import 'dart:io'; // 🚀 IMPORT
import 'dart:async'; // 🚀 IMPORT

class PlaylistDetailPage extends ConsumerStatefulWidget {
  final String playlistId;

  const PlaylistDetailPage({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage> {
  String? _loadingSongTitle;
  Map<String, bool> _downloadStatus = {}; // 🚀 Track local status
  bool _isCheckingDownloads = false;

  StreamSubscription? _completionSubscription;

  @override
  void initState() {
    super.initState();
    // 🚀 Check status on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDownloadStatus();
    });

    // 🚀 LISTEN FOR UPDATES
    _completionSubscription =
        BulkDownloadService().songCompleteStream.listen((path) {
      if (mounted) {
        setState(() {
          _downloadStatus[path] = true;
        });
      }
    });

    // Listen to current download to show spinner
    BulkDownloadService().currentSongNotifier.addListener(_onDownloadChange);
  }

  @override
  void dispose() {
    _completionSubscription?.cancel();
    BulkDownloadService().currentSongNotifier.removeListener(_onDownloadChange);
    super.dispose();
  }

  void _onDownloadChange() {
    if (mounted) setState(() {});
  }

  // 🚀 Logic to check if files exist locally
  Future<void> _checkDownloadStatus() async {
    if (_isCheckingDownloads) return;
    setState(() => _isCheckingDownloads = true);

    final playlists = ref.read(playlistProvider);
    final playlistIndex =
        playlists.indexWhere((p) => p.id == widget.playlistId);
    if (playlistIndex == -1) {
      setState(() => _isCheckingDownloads = false);
      return;
    }
    final playlist = playlists[playlistIndex];

    // Determine Base Dir
    final baseDir =
        await BulkDownloadService().getAlbumDownloadDirectory(playlist.name);
    if (baseDir == null) {
      setState(() => _isCheckingDownloads = false);
      return;
    }

    final newStatus = <String, bool>{};
    final smartService = SmartDownloadService();

    // Loop through entries
    for (var i = 0; i < playlist.entries.length; i++) {
      final entry = playlist.entries[i];
      // 🚀 STRICT CHECK: Ignore library path, only check playlist folder

      // 2. Predict Filename for Playlist Download
      final meta = SongMetadata(
        title: entry.title ?? "Unknown Title",
        artist: entry.artist ?? "Unknown Artist",
        album: entry.album ?? "Unknown Album",
        albumArtUrl: entry.artUrl ?? "",
        durationSeconds: (entry.duration ?? 0).toInt(),
      );

      // We need to match the index used in BulkDownloadService (1-based)
      final filename = await smartService.generateFilename(meta,
          patternKey: 'playlist_filename_pattern', playlistIndex: i + 1);

      final predictedPath = "${baseDir.path}/$filename.m4a";
      if (await File(predictedPath).exists()) {
        newStatus[entry.path] = true;
      } else {
        newStatus[entry.path] = false;
      }
    }

    if (mounted) {
      setState(() {
        _downloadStatus = newStatus;
        _isCheckingDownloads = false;
      });
    }
  }

  // 🚀 Resolve Queue to use Local Files
  Future<List<SongModel>> _resolveLocalFiles(
      List<SongModel> songs, String playlistName) async {
    final baseDir =
        await BulkDownloadService().getAlbumDownloadDirectory(playlistName);
    if (baseDir == null) return songs;

    final smartService = SmartDownloadService();
    final List<SongModel> resolvedSongs = [];

    for (var i = 0; i < songs.length; i++) {
      var song = songs[i];
      // 🚀 PRIORITY: Check Playlist Folder FIRST
      // If it exists there, we use it. If not, we use the original (stream/local).

      // Predict Path
      final meta = SongMetadata(
        title: song.title,
        artist: song.artist,
        album: song.album,
        albumArtUrl: song.onlineArtUrl ?? "",
        durationSeconds: song.duration.toInt(),
      );

      final filename = await smartService.generateFilename(meta,
          patternKey: 'playlist_filename_pattern', playlistIndex: i + 1);

      final predictedPath = "${baseDir.path}/$filename.m4a";

      if (await File(predictedPath).exists()) {
        //    print("✅ Resolved local playlist file: $predictedPath");
        resolvedSongs.add(song.copyWith(filePath: predictedPath));
      } else {
        // Fallback to original (which implies if it was local, it stays local, if stream, stays stream)
        resolvedSongs.add(song);
      }
    }
    return resolvedSongs;
  }

  Future<void> _playTrack(SongModel song, List<SongModel> queue) async {
    if (_loadingSongTitle != null) return;

    setState(() => _loadingSongTitle = song.title);

    try {
      // 🚀 RESOLVE LOCAL FILES BEFORE PLAYING
      final playlists = ref.read(playlistProvider);
      final playlist = playlists.firstWhere((p) => p.id == widget.playlistId);

      // Show "Preparing..." or similar?
      final resolvedQueue = await _resolveLocalFiles(queue, playlist.name);

      // Find the target song in the resolved queue (by index or reference)
      final index = queue.indexOf(song);
      final resolvedSong = (index != -1 && index < resolvedQueue.length)
          ? resolvedQueue[index]
          : song;

      if (mounted) {
        await ref
            .read(playerProvider.notifier)
            .playSong(resolvedSong, newQueue: resolvedQueue);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSongTitle = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistProvider);
    final notifier = ref.read(playlistProvider.notifier);

    final playlistIndex =
        playlists.indexWhere((p) => p.id == widget.playlistId);
    if (playlistIndex == -1) {
      return Scaffold(
          body: Center(
              child: Text(AppLocalizations.of(context)!.playlistNotFound)));
    }

    final playlist = playlists[playlistIndex];

    final library = p.Provider.of<LibraryProvider>(context);

    // 🚀 OPTIMIZATION: Create HashMap for O(1) lookup instead of O(n) firstWhere
    final Map<String, SongModel> libraryMap = {
      for (var song in library.songs) song.filePath: song
    };

    // Map Entries to Songs + Dates
    final List<_PlaylistRowData> rowData = [];
    // ✅ CHANGED: Collect paths (String) instead of bytes
    final List<String> headerImagePaths = [];
    final List<String?> headerArtUrls = [];

    for (var entry in playlist.entries) {
      // 🚀 O(1) LOOKUP instead of O(n) firstWhere
      final librarySong = libraryMap[entry.path];

      if (librarySong != null) {
        rowData.add(_PlaylistRowData(librarySong, entry.dateAdded));

        if (headerImagePaths.length < 4) {
          headerImagePaths.add(librarySong.filePath);
          headerArtUrls.add(librarySong.onlineArtUrl);
        }
      } else {
        // 🚀 FALLBACK: USE METADATA FROM ENTRY (For Spotify imports)
        final title = entry.title ?? entry.path.split('/').last;

        final song = SongModel(
          title: title.isEmpty ? "Unknown Song" : title,
          artist: entry.artist ?? "Unknown Artist",
          album: entry.album ?? "Unknown Album",
          filePath: entry.path,
          fileExtension: ".mp3", // Assumption
          duration: (entry.duration ?? 0).toDouble(), // 🚀 USE SAVED DURATION
          onlineArtUrl: entry.artUrl,
          sourceUrl: (entry.sourceUrl != null &&
                  !entry.sourceUrl!.contains("spotify.com"))
              ? entry.sourceUrl
              : "", // 🚀 IGNORE SPOTIFY URLS
          isrc: entry.isrc, // USE ISRC
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

    // 🚀 Use Spotify cover if available
    final hasCover = playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty;

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
                  // Background Blur - Use Spotify cover or collage
                  if (hasCover)
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Opacity(
                        opacity: 0.4,
                        child: Image.network(
                          playlist.coverUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else if (headerImagePaths.isNotEmpty)
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Opacity(
                        opacity: 0.4,
                        child: PlaylistCollage(
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

                  // Foreground Cover - Use Spotify cover or collage
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
                        child: hasCover
                            ? Image.network(
                                playlist.coverUrl!,
                                width: 160,
                                height: 160,
                                fit: BoxFit.cover,
                              )
                            : PlaylistCollage(
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
                              _playTrack(rowData.first.song,
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
              // 🚀 DOWNLOAD ALL BUTTON
              IconButton(
                // 🚀 SHOW CHECKLIST IF ALL DOWNLOADED
                icon: (rowData.isNotEmpty &&
                        rowData.every(
                            (r) => _downloadStatus[r.song.filePath] == true))
                    ? const Icon(Icons.download_done_rounded,
                        color: Colors.greenAccent, size: 28)
                    : Icon(Icons.download_rounded, color: textColor, size: 28),
                tooltip: AppLocalizations.of(context)!.downloadAll,
                onPressed: () async {
                  if (rowData.isEmpty) return;

                  final allDownloaded = rowData.isNotEmpty &&
                      rowData.every(
                          (r) => _downloadStatus[r.song.filePath] == true);

                  if (allDownloaded) {
                    // 🚀 DELETE MODE
                    final l10n = AppLocalizations.of(context)!;
                    final messenger = ScaffoldMessenger.of(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Theme.of(context).cardColor,
                        title: Text(l10n.deleteDownloadsTitle,
                            style: TextStyle(color: textColor)),
                        content: Text(l10n.deleteDownloadsConfirm,
                            style: TextStyle(color: textColor)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l10n.cancel)),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(l10n.delete,
                                  style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final baseDir = await BulkDownloadService()
                          .getAlbumDownloadDirectory(playlist.name);
                      if (baseDir != null && await baseDir.exists()) {
                        await baseDir.delete(recursive: true);

                        // Reset status
                        if (mounted) {
                          setState(() {
                            // Clear all statuses for this playlist's songs
                            for (var r in rowData) {
                              _downloadStatus[r.song.filePath] = false;
                            }
                          });
                          messenger.showSnackBar(
                            SnackBar(
                                content: Text(l10n.allDownloadsRemoved),
                                backgroundColor: Colors.red),
                          );
                          // Force re-check just in case
                          _checkDownloadStatus();
                        }
                      }
                    }
                  } else {
                    // 🚀 DOWNLOAD MODE
                    // Convert RowData back to SongModel list
                    final songsToDownload = rowData.map((r) => r.song).toList();

                    // 🚀 Just trigger logic, service handles checking duplicates
                    BulkDownloadService()
                        .downloadAlbum(playlist.name, songsToDownload);

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          AppLocalizations.of(context)!.startedDownloadingAll),
                      duration: const Duration(seconds: 2),
                    ));

                    // 🚀 Wait and check status (Poor man's refresh, better to listen to service in future)
                    await Future.delayed(const Duration(seconds: 2));
                    _checkDownloadStatus();
                  }
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'delete') {
                    notifier.deletePlaylist(widget.playlistId);
                    // POP FROM STACK
                    ref.read(navigationStackProvider.notifier).pop();
                  } else if (value == 'rename') {
                    _showRenameDialog(context, ref, playlist);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: 'rename',
                      child: Text(AppLocalizations.of(context)!.rename)),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text(AppLocalizations.of(context)!.renamePlaylist,
                          style: const TextStyle(color: Colors.red))),
                ],
              ),
              const SizedBox(width: 16),
            ],
          ),
          if (rowData.isEmpty)
            SliverFillRemaining(
              child: Center(
                  child: Text(AppLocalizations.of(context)!.noSongsAdded,
                      style: TextStyle(color: subtitleColor))),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final data = rowData[index];
                  final isThisLoading = _loadingSongTitle == data.song.title;
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Number OR Spinner
                        SizedBox(
                            width: 30,
                            child: isThisLoading
                                ? Center(
                                    child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: accentColor)))
                                : (BulkDownloadService()
                                            .currentSongNotifier
                                            .value ==
                                        data.song.filePath)
                                    ? Center(
                                        // 🚀 DOWNLOADING SPINNER
                                        child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: accentColor)))
                                    : Text("${index + 1}",
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
                    title: Text(data.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isThisLoading ? accentColor : textColor,
                            fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        (data.song.artist == "Unknown Artist" ||
                                data.song.artist == "Unknown")
                            ? data.song.filePath
                            : data.song.artist,
                        maxLines: 1,
                        style: TextStyle(color: subtitleColor, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Duration (Fixed Width)
                        SizedBox(
                          width: 45,
                          child: Text(_formatDuration(data.song.duration),
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  color: subtitleColor, fontSize: 12)),
                        ),
                        // 🚀 DOWNLOAD INDICATOR
                        if (_downloadStatus[data.song.filePath] == true)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(Icons.download_done_rounded,
                                size: 16, color: accentColor),
                          ),
                        const SizedBox(width: 32), // 🚀 DOUBLED GAP
                        // Date (Fixed Width)
                        SizedBox(
                          width: 75,
                          child: Text(_formatDate(data.dateAdded),
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  color: subtitleColor, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: subtitleColor),
                          tooltip:
                              AppLocalizations.of(context)!.removeFromPlaylist,
                          onPressed: () => notifier.removeSongFromPlaylist(
                              widget.playlistId, data.song.filePath),
                        ),
                      ],
                    ),
                    onTap: () {
                      _playTrack(
                          data.song, rowData.map((r) => r.song).toList());
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
        title: Text(AppLocalizations.of(context)!.renamePlaylist,
            style: TextStyle(color: textColor)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(playlistProvider.notifier)
                    .renamePlaylist(playlist.id, controller.text);
                Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.of(context)!.saveChangesToFile),
          )
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  String _formatDuration(double duration) {
    if (duration <= 0) return "--:--";
    final int minutes = duration ~/ 60;
    final int seconds = (duration % 60).toInt();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}

class _PlaylistRowData {
  final SongModel song;
  final DateTime dateAdded;
  _PlaylistRowData(this.song, this.dateAdded);
}
