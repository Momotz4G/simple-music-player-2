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
import '../../services/spotify_service.dart'; // 🚀 ADDED SPOTIFY SERVICE
import '../../services/deezer_service.dart'; // 🚀 ADDED DEEZER SERVICE
import 'dart:io'; // 🚀 IMPORT
import 'dart:async'; // 🚀 IMPORT
import '../components/playlist_sharing_dialogs.dart'; // 🚀 IMPORT

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

    for (var i = 0; i < playlist.entries.length; i++) {
      try {
        final entry = playlist.entries[i];
        final meta = SongMetadata(
          title: entry.title ?? "Unknown Title",
          artist: entry.artist ?? "Unknown Artist",
          album: entry.album ?? "Unknown Album",
          albumArtUrl: entry.artUrl ?? "",
          durationSeconds: (entry.duration ?? 0).toInt(),
        );

        final filename = await smartService.generateFilename(meta,
            patternKey: 'playlist_filename_pattern', playlistIndex: i + 1);

        final predictedPath = "${baseDir.path}/$filename.m4a";
        if (File(predictedPath).existsSync()) {
          newStatus[entry.path] = true;
        } else {
          newStatus[entry.path] = false;
        }
      } catch (_) {}

      // 🚀 Yield to UI thread every 10 items to prevent "not responding"
      if (i % 10 == 9) {
        await Future.delayed(Duration.zero);
        if (!mounted) return;
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

      final resolvedQueue = await _resolveLocalFiles(queue, playlist.name);

      // Find the target song in the resolved queue
      final index = queue.indexOf(song);
      var resolvedSong = (index != -1 && index < resolvedQueue.length)
          ? resolvedQueue[index]
          : song;

      // 🚀 SPOTIFY METADATA ENRICHMENT FOR NON-LOCAL TRACKS
      // Only enrich if it's a stream (not downloaded) AND if it's from YT Music import (sourceUrl is YT)
      final isStream = !await File(resolvedSong.filePath).exists();
      final fromYtImport = resolvedSong.sourceUrl != null && resolvedSong.sourceUrl!.contains('youtube');
      
      if (isStream && fromYtImport) {
        try {
          final query = "${resolvedSong.title} ${resolvedSong.artist}";
          List<SongMetadata> results = [];
          
          try {
            results = await SpotifyService.searchTracks(query);
          } catch (e) {
            print("Spotify enrichment failed: $e, falling back to Deezer");
          }

          if (results.isEmpty) {
            try {
              results = await DeezerService.searchSongs(query);
            } catch (e) {
              print("Deezer enrichment failed: $e");
            }
          }
          
          if (results.isNotEmpty) {
            final bestMatch = results.first;
            // Enrich the song with Spotify/Deezer Data
            resolvedSong = resolvedSong.copyWith(
              title: bestMatch.title,
              artist: bestMatch.artist,
              album: bestMatch.album,
              onlineArtUrl: bestMatch.albumArtUrl.isNotEmpty ? bestMatch.albumArtUrl : resolvedSong.onlineArtUrl,
              isrc: bestMatch.isrc ?? resolvedSong.isrc,
              spotifyId: bestMatch.spotifyId ?? resolvedSong.spotifyId,
              deezerId: bestMatch.deezerId ?? resolvedSong.deezerId,
              // Keep original youtube source URL so downloader works
            );
            
            // Also enrich the corresponding item in the queue so the player has it
            if (index != -1 && index < resolvedQueue.length) {
              resolvedQueue[index] = resolvedSong;
            }
          }
        } catch (e) {
          print("Metadata enrichment failed completely: $e, playing original");
        }
      }

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
        // 🚀 FALLBACK: USE METADATA FROM ENTRY (For Spotify/YTMusic imports)
        final title = entry.title ?? 
            (entry.path.isNotEmpty ? entry.path.split('/').last : "Unknown Song");

        final song = SongModel(
          title: title.isEmpty ? "Unknown Song" : title,
          artist: entry.artist ?? "Unknown Artist",
          album: entry.album ?? "Unknown Album",
          filePath: entry.path,
          fileExtension: ".mp3",
          duration: (entry.duration ?? 0).toDouble(),
          onlineArtUrl: entry.artUrl,
          sourceUrl: entry.sourceUrl,
          isrc: entry.isrc,
        );
        rowData.add(_PlaylistRowData(song, entry.dateAdded));
        if (headerImagePaths.length < 4) {
          headerImagePaths.add(entry.path);
          headerArtUrls.add(entry.artUrl);
        }
      }
    }

    // 🚀 CACHE song list once — avoid re-creating per tile
    final List<SongModel> songList = rowData.map((r) => r.song).toList();

    // 🚀 CALCULATE PLAYLIST STATS
    final totalDurationSeconds =
        rowData.fold<double>(0, (sum, item) => sum + item.song.duration);
    final songCount = rowData.length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // 🚀 Use Spotify cover if available
    final hasCover = playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty;

    // 🚀 RESPONSIVENESS: Adjust sizes for mobile
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    final expandedHeight = isSmallScreen ? 340.0 : 420.0;
    final collageSize = isSmallScreen ? 140.0 : 200.0;
    final titleFontSize = isSmallScreen ? 20.0 : 26.0;

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
            // Title for collapsed state
            title: Text(playlist.name,
                style: TextStyle(color: textColor, fontSize: 16)),
            centerTitle: true,
            expandedHeight: expandedHeight, 
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              // Expanded title is handled in the background stack for more control
              title: null,
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
                    Container(color: const Color(0xFF1C1C1C)),

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

                  // Foreground Content: Collage + Title + Stats
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: isSmallScreen ? 40 : 60), // Account for Back button
                        // Collage
                        Container(
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
                                    width: collageSize,
                                    height: collageSize,
                                    fit: BoxFit.cover,
                                  )
                                : PlaylistCollage(
                                    imagePaths: headerImagePaths,
                                    onlineArtUrls: headerArtUrls,
                                    size: collageSize),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Title (TRUNCATED)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            playlist.name,
                            style: TextStyle(
                              color: textColor,
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Stats (Song Count & Total Duration)
                        Text(
                          "${AppLocalizations.of(context)!.countSongs(songCount)} • ${_formatTotalDuration(totalDurationSeconds, AppLocalizations.of(context)!)}",
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                onSelected: (value) async {
                  if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Theme.of(context).cardColor,
                        title: Text(AppLocalizations.of(context)!.deletePlaylist,
                            style: TextStyle(color: textColor)),
                        content: Text(
                            AppLocalizations.of(context)!
                                .deletePlaylistPermanentConfirm,
                            style: TextStyle(color: textColor)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(AppLocalizations.of(context)!.cancel)),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(AppLocalizations.of(context)!.delete,
                                  style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      notifier.deletePlaylist(widget.playlistId);
                      if (mounted) {
                        ref.read(navigationStackProvider.notifier).pop();
                      }
                    }
                  } else if (value == 'rename') {
                    _showRenameDialog(context, ref, playlist);
                  } else if (value == 'share') {
                    showDialog(
                      context: context,
                      builder: (context) => SharePlaylistDialog(
                        playlistId: widget.playlistId,
                        playlistName: playlist.name,
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.sharePlaylist),
                        ],
                      )),
                  PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.renamePlaylist),
                        ],
                      )),
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.deletePlaylist,
                              style: const TextStyle(color: Colors.red)),
                        ],
                      )),
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
                            playQueue: songList,
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
                    trailing: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = MediaQuery.of(context).size.width < 600;
                        return Row(
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
                            // Date - HIDE ON MOBILE
                            if (!isMobile) ...[
                              const SizedBox(width: 32),
                              SizedBox(
                                width: 75,
                                child: Text(_formatDate(data.dateAdded),
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                        color: subtitleColor, fontSize: 12)),
                              ),
                            ],
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
                        );
                      },
                    ),
                    onTap: () {
                      _playTrack(data.song, songList);
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

  String _formatTotalDuration(double durationSeconds, AppLocalizations l10n) {
    if (durationSeconds <= 0) return "0 ${l10n.minuteShort}";
    final duration = Duration(seconds: durationSeconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return "$hours ${l10n.hourShort} $minutes ${l10n.minuteShort}";
    } else {
      return "$minutes ${l10n.minuteShort}";
    }
  }
}

class _PlaylistRowData {
  final SongModel song;
  final DateTime dateAdded;
  _PlaylistRowData(this.song, this.dateAdded);
}
