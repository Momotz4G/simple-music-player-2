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
import '../../utils/layout_engine.dart';

enum PlaylistSortColumn { none, originalIndex, title, artist, dateAdded }

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

  PlaylistSortColumn _currentSortColumn = PlaylistSortColumn.none;
  bool _isSortAscending = true;

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

  // 🚀 Resolve Queue to use Local Files (Priority Chain)
  Future<List<SongModel>> _resolveLocalFiles(
      List<SongModel> songs, String playlistName) async {
    final baseDir =
        await BulkDownloadService().getAlbumDownloadDirectory(playlistName);
    if (baseDir == null) return songs;

    final smartService = SmartDownloadService();
    final List<SongModel> resolvedSongs = [];

    for (var i = 0; i < songs.length; i++) {
      var song = songs[i];

      // 🚀 PRIORITY 1 (highest): Use original filePath if it exists on disk
      if (song.filePath != "cloud_stream" &&
          await File(song.filePath).exists()) {
        resolvedSongs.add(song);
        continue;
      }

      // Predict filename for download folder checks
      final meta = SongMetadata(
        title: song.title,
        artist: song.artist,
        album: song.album,
        albumArtUrl: song.onlineArtUrl ?? "",
        durationSeconds: song.duration.toInt(),
      );

      final filename = await smartService.generateFilename(meta,
          patternKey: 'playlist_filename_pattern', playlistIndex: i + 1);

      // 🚀 PRIORITY 2: Check for FLAC cache in download folder
      final flacPath = "${baseDir.path}/$filename.flac";
      if (await File(flacPath).exists()) {
        resolvedSongs.add(song.copyWith(filePath: flacPath));
        continue;
      }

      // 🚀 PRIORITY 3: Check for .m4a in download folder (existing logic)
      final predictedPath = "${baseDir.path}/$filename.m4a";
      if (await File(predictedPath).exists()) {
        resolvedSongs.add(song.copyWith(filePath: predictedPath));
      } else {
        // Fallback to streaming (no local file found)
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
      final fromYtImport = resolvedSong.sourceUrl != null &&
          resolvedSong.sourceUrl!.contains('youtube');

      if (isStream && fromYtImport) {
        try {
          final query = "${resolvedSong.title} ${resolvedSong.artist}";
          List<SongMetadata> results = [];

          try {
            results = await SpotifyService.searchTracks(query);
          } catch (e) {
            debugPrint("Spotify enrichment failed: $e, falling back to Deezer");
          }

          if (results.isEmpty) {
            try {
              results = await DeezerService.searchSongs(query);
            } catch (e) {
              debugPrint("Deezer enrichment failed: $e");
            }
          }

          if (results.isNotEmpty) {
            final bestMatch = results.first;
            // Enrich the song with Spotify/Deezer Data
            resolvedSong = resolvedSong.copyWith(
              title: bestMatch.title,
              artist: bestMatch.artist,
              album: bestMatch.album,
              onlineArtUrl: bestMatch.albumArtUrl.isNotEmpty
                  ? bestMatch.albumArtUrl
                  : resolvedSong.onlineArtUrl,
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
          debugPrint("Metadata enrichment failed completely: $e, playing original");
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

  void _onSortTapped(PlaylistSortColumn column) {
    setState(() {
      if (_currentSortColumn == column) {
        if (_isSortAscending) {
          _isSortAscending = false;
        } else {
          _currentSortColumn = PlaylistSortColumn.none;
          _isSortAscending = true;
        }
      } else {
        _currentSortColumn = column;
        _isSortAscending = true;
      }
    });
  }

  Widget _buildSortHeader(Color textColor, Color subtitleColor, Color accentColor, bool isMobile) {
    if (isMobile) {
      String sortLabel = "Default Order";
      IconData sortIcon = Icons.sort;
      switch (_currentSortColumn) {
        case PlaylistSortColumn.originalIndex:
          sortLabel = "Original Order (#)";
          sortIcon = Icons.tag;
          break;
        case PlaylistSortColumn.title:
          sortLabel = AppLocalizations.of(context)!.title;
          sortIcon = Icons.title;
          break;
        case PlaylistSortColumn.artist:
          sortLabel = AppLocalizations.of(context)!.artist;
          sortIcon = Icons.person;
          break;
        case PlaylistSortColumn.dateAdded:
          sortLabel = "Date Added";
          sortIcon = Icons.calendar_today;
          break;
        case PlaylistSortColumn.none:
          sortLabel = "Default Order";
          sortIcon = Icons.sort;
          break;
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showMobileSortMenu(context, textColor),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(sortIcon, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      sortLabel,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: accentColor),
                  ],
                ),
              ),
            ),
            if (_currentSortColumn != PlaylistSortColumn.none)
              IconButton(
                icon: Icon(
                  _isSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18,
                  color: accentColor,
                ),
                onPressed: () {
                  setState(() {
                    _isSortAscending = !_isSortAscending;
                  });
                },
                tooltip: "Toggle Sort Order",
              ),
          ],
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: SizedBox(
        width: 30 + 10 + 48,
        child: InkWell(
          onTap: () => _onSortTapped(PlaylistSortColumn.originalIndex),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("#", style: TextStyle(color: _currentSortColumn == PlaylistSortColumn.originalIndex ? accentColor : subtitleColor, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 2),
              Icon(
                _currentSortColumn == PlaylistSortColumn.originalIndex
                    ? (_isSortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
                    : Icons.unfold_more_rounded,
                color: _currentSortColumn == PlaylistSortColumn.originalIndex ? accentColor : subtitleColor.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
      title: Row(
        children: [
          InkWell(
            onTap: () => _onSortTapped(PlaylistSortColumn.title),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context)!.title, style: TextStyle(color: _currentSortColumn == PlaylistSortColumn.title ? accentColor : subtitleColor, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 2),
                Icon(
                  _currentSortColumn == PlaylistSortColumn.title
                      ? (_isSortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
                      : Icons.unfold_more_rounded,
                  color: _currentSortColumn == PlaylistSortColumn.title ? accentColor : subtitleColor.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          InkWell(
            onTap: () => _onSortTapped(PlaylistSortColumn.artist),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context)!.artist, style: TextStyle(color: _currentSortColumn == PlaylistSortColumn.artist ? accentColor : subtitleColor, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 2),
                Icon(
                  _currentSortColumn == PlaylistSortColumn.artist
                      ? (_isSortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
                      : Icons.unfold_more_rounded,
                  color: _currentSortColumn == PlaylistSortColumn.artist ? accentColor : subtitleColor.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 45,
            child: Icon(Icons.access_time, color: subtitleColor, size: 16),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 32),
            SizedBox(
              width: 75,
              child: InkWell(
                onTap: () => _onSortTapped(PlaylistSortColumn.dateAdded),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Date", style: TextStyle(color: _currentSortColumn == PlaylistSortColumn.dateAdded ? accentColor : subtitleColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 2),
                    Icon(
                      _currentSortColumn == PlaylistSortColumn.dateAdded
                          ? (_isSortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
                          : Icons.unfold_more_rounded,
                      color: _currentSortColumn == PlaylistSortColumn.dateAdded ? accentColor : subtitleColor.withValues(alpha: 0.5),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 48), // Spacer for download/remove buttons
        ],
      ),
    );
  }

  void _showMobileSortMenu(BuildContext context, Color textColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final localizations = AppLocalizations.of(context)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Sort by",
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildSortMenuItem(
                context,
                column: PlaylistSortColumn.none,
                label: "Default Order",
                icon: Icons.sort,
              ),
              _buildSortMenuItem(
                context,
                column: PlaylistSortColumn.originalIndex,
                label: "Original Order (#)",
                icon: Icons.tag,
              ),
              _buildSortMenuItem(
                context,
                column: PlaylistSortColumn.title,
                label: localizations.title,
                icon: Icons.title,
              ),
              _buildSortMenuItem(
                context,
                column: PlaylistSortColumn.artist,
                label: localizations.artist,
                icon: Icons.person,
              ),
              _buildSortMenuItem(
                context,
                column: PlaylistSortColumn.dateAdded,
                label: "Date Added",
                icon: Icons.calendar_today,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortMenuItem(
    BuildContext context, {
    required PlaylistSortColumn column,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _currentSortColumn == column;
    final accentColor = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? accentColor : textColor.withValues(alpha: 0.6),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? accentColor : textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(
              _isSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              color: accentColor,
            )
          : null,
      onTap: () {
        Navigator.pop(context);
        setState(() {
          if (_currentSortColumn == column) {
            _isSortAscending = !_isSortAscending;
          } else {
            _currentSortColumn = column;
            _isSortAscending = true;
          }
        });
      },
    );
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

    for (var i = 0; i < playlist.entries.length; i++) {
      var entry = playlist.entries[i];
      // 🚀 O(1) LOOKUP instead of O(n) firstWhere
      final librarySong = libraryMap[entry.path];

      if (librarySong != null) {
        rowData.add(_PlaylistRowData(i + 1, librarySong, entry.dateAdded));

        if (headerImagePaths.length < 4) {
          headerImagePaths.add(librarySong.filePath);
          headerArtUrls.add(librarySong.onlineArtUrl);
        }
      } else {
        // 🚀 FALLBACK: USE METADATA FROM ENTRY (For Spotify/YTMusic imports)
        final title = entry.title ??
            (entry.path.isNotEmpty
                ? entry.path.split('/').last
                : "Unknown Song");

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
          spotifyId: entry.spotifyId,
        );
        rowData.add(_PlaylistRowData(i + 1, song, entry.dateAdded));
        if (headerImagePaths.length < 4) {
          headerImagePaths.add(entry.path);
          headerArtUrls.add(entry.artUrl);
        }
      }
    }

    // 🚀 APPLY SORTING
    if (_currentSortColumn != PlaylistSortColumn.none) {
      rowData.sort((a, b) {
        int result = 0;
        switch (_currentSortColumn) {
          case PlaylistSortColumn.originalIndex:
            result = a.originalIndex.compareTo(b.originalIndex);
            break;
          case PlaylistSortColumn.title:
            result = a.song.title.toLowerCase().compareTo(b.song.title.toLowerCase());
            break;
          case PlaylistSortColumn.artist:
            result = a.song.artist.toLowerCase().compareTo(b.song.artist.toLowerCase());
            break;
          case PlaylistSortColumn.dateAdded:
            result = a.dateAdded.compareTo(b.dateAdded);
            break;
          case PlaylistSortColumn.none:
            break;
        }
        return _isSortAscending ? result : -result;
      });
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
      body: LayoutEngine.isTablet(context)
          ? _buildTabletBody(
              context,
              playlist,
              notifier,
              rowData,
              songList,
              headerImagePaths,
              headerArtUrls,
              textColor,
              subtitleColor,
              accentColor,
              isDark,
              totalDurationSeconds,
              songCount)
          : CustomScrollView(
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
                            imageFilter:
                                ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
                              SizedBox(
                                  height: isSmallScreen
                                      ? 40
                                      : 60), // Account for Back button
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
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
                            child: const Icon(Icons.play_arrow,
                                color: Colors.white),
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
                              rowData.every((r) =>
                                  _downloadStatus[r.song.filePath] == true))
                          ? const Icon(Icons.download_done_rounded,
                              color: Colors.greenAccent, size: 28)
                          : Icon(Icons.download_rounded,
                              color: textColor, size: 28),
                      tooltip: AppLocalizations.of(context)!.downloadAll,
                      onPressed: () async {
                        if (rowData.isEmpty) return;

                        final allDownloaded = rowData.isNotEmpty &&
                            rowData.every((r) =>
                                _downloadStatus[r.song.filePath] == true);

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
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(l10n.cancel)),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(l10n.delete,
                                        style: const TextStyle(
                                            color: Colors.red))),
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
                          final songsToDownload =
                              rowData.map((r) => r.song).toList();

                          // 🚀 Just trigger logic, service handles checking duplicates
                          BulkDownloadService()
                              .downloadAlbum(playlist.name, songsToDownload);

                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(AppLocalizations.of(context)!
                                .startedDownloadingAll),
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
                              title: Text(
                                  AppLocalizations.of(context)!.deletePlaylist,
                                  style: TextStyle(color: textColor)),
                              content: Text(
                                  AppLocalizations.of(context)!
                                      .deletePlaylistPermanentConfirm,
                                  style: TextStyle(color: textColor)),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(
                                        AppLocalizations.of(context)!.cancel)),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(
                                        AppLocalizations.of(context)!.delete,
                                        style: const TextStyle(
                                            color: Colors.red))),
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
                        } else if (value == 'export_m3u') {
                          ref.read(playlistProvider.notifier).exportM3uPlaylist(
                              widget.playlistId, onStatus: (statusKey, {args}) {
                            if (statusKey == 'exportedM3u') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .exportToM3u),
                                    backgroundColor: Colors.green),
                              );
                            }
                          });
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                            value: 'export_m3u',
                            child: Row(
                              children: [
                                Icon(Icons.file_download_outlined,
                                    size: 18,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(AppLocalizations.of(context)!.exportToM3u),
                              ],
                            )),
                        PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_outlined,
                                    size: 18,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(AppLocalizations.of(context)!
                                    .sharePlaylist),
                              ],
                            )),
                        PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 18,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(AppLocalizations.of(context)!
                                    .renamePlaylist),
                              ],
                            )),
                        PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(
                                    AppLocalizations.of(context)!
                                        .deletePlaylist,
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
                else ...[
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildSortHeader(textColor, subtitleColor!, accentColor, isSmallScreen),
                        Divider(height: 1, color: subtitleColor.withValues(alpha: 0.2)),
                      ],
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final data = rowData[index];
                        final isThisLoading =
                            _loadingSongTitle == data.song.title;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
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
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: accentColor)))
                                          : Text("${data.originalIndex}",
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
                                  color:
                                      isThisLoading ? accentColor : textColor,
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(
                              (data.song.artist == "Unknown Artist" ||
                                      data.song.artist == "Unknown")
                                  ? data.song.filePath
                                  : data.song.artist,
                              maxLines: 1,
                              style: TextStyle(
                                  color: subtitleColor, fontSize: 12)),
                          trailing: LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile =
                                  MediaQuery.of(context).size.width < 600;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Duration (Fixed Width)
                                  SizedBox(
                                    width: 45,
                                    child: Text(
                                        _formatDuration(data.song.duration),
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                            color: subtitleColor,
                                            fontSize: 12)),
                                  ),
                                  // 🚀 DOWNLOAD INDICATOR
                                  if (_downloadStatus[data.song.filePath] ==
                                      true)
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
                                              color: subtitleColor,
                                              fontSize: 12)),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.remove_circle_outline,
                                        color: subtitleColor),
                                    tooltip: AppLocalizations.of(context)!
                                        .removeFromPlaylist,
                                    onPressed: () => _confirmAndRemoveSong(
                                        context, notifier, data.song, textColor),
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
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  /// Builds the tablet-specific body layout for the playlist detail page.
  /// Landscape: two-column layout with header (art + info) on left, track list on right.
  /// Portrait: single-column with header above track list, header constrained to 35% screen height.
  Widget _buildTabletBody(
    BuildContext context,
    PlaylistModel playlist,
    dynamic notifier,
    List<_PlaylistRowData> rowData,
    List<SongModel> songList,
    List<String> headerImagePaths,
    List<String?> headerArtUrls,
    Color textColor,
    Color? subtitleColor,
    Color accentColor,
    bool isDark,
    double totalDurationSeconds,
    int songCount,
  ) {
    final isLandscape = LayoutEngine.isLandscape(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final hasCover = playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty;

    if (isLandscape) {
      // --- TABLET LANDSCAPE: Two-column layout ---
      return Column(
        children: [
          // App bar area
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () =>
                        ref.read(navigationStackProvider.notifier).pop(),
                  ),
                  const Spacer(),
                  _buildPlaylistActions(context, playlist, notifier, rowData,
                      textColor, accentColor),
                ],
              ),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: Header (art + info + play button)
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.38,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 12, 24),
                    child: _buildPlaylistTabletHeader(
                      context,
                      playlist,
                      headerImagePaths,
                      headerArtUrls,
                      textColor,
                      subtitleColor,
                      accentColor,
                      hasCover,
                      totalDurationSeconds,
                      songCount,
                      rowData,
                      songList,
                    ),
                  ),
                ),
                // Right column: Track list
                Expanded(
                  child: Column(
                    children: [
                      _buildSortHeader(textColor, subtitleColor!, accentColor, false),
                      Divider(height: 1, color: subtitleColor.withValues(alpha: 0.2)),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 160),
                          itemCount: rowData.length,
                          itemBuilder: (context, index) {
                            return _buildPlaylistTrackTile(
                                context,
                                index,
                                rowData,
                                songList,
                                notifier,
                                textColor,
                                subtitleColor,
                                accentColor);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // --- TABLET PORTRAIT: Single-column, header constrained to 35% screen height ---
      final maxHeaderHeight = screenHeight * 0.35;
      return CustomScrollView(
        slivers: [
          // Compact app bar
          SliverAppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => ref.read(navigationStackProvider.notifier).pop(),
            ),
            title: Text(playlist.name,
                style: TextStyle(color: textColor, fontSize: 16)),
            centerTitle: true,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            actions: [
              _buildPlaylistActions(
                  context, playlist, notifier, rowData, textColor, accentColor),
            ],
          ),
          // Header constrained to 35% screen height
          SliverToBoxAdapter(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeaderHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: _buildPlaylistHeaderCompact(
                  context,
                  playlist,
                  headerImagePaths,
                  headerArtUrls,
                  textColor,
                  subtitleColor,
                  accentColor,
                  hasCover,
                  totalDurationSeconds,
                  songCount,
                  rowData,
                  songList,
                ),
              ),
            ),
          ),
          // Track list
          if (rowData.isEmpty)
            SliverFillRemaining(
              child: Center(
                  child: Text(AppLocalizations.of(context)!.noSongsAdded,
                      style: TextStyle(color: subtitleColor))),
            )
          else ...[
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildSortHeader(textColor, subtitleColor!, accentColor, false),
                  Divider(height: 1, color: subtitleColor.withValues(alpha: 0.2)),
                ],
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildPlaylistTrackTile(
                      context,
                      index,
                      rowData,
                      songList,
                      notifier,
                      textColor,
                      subtitleColor,
                      accentColor);
                },
                childCount: rowData.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      );
    }
  }

  /// Builds the playlist header for tablet landscape (left column).
  Widget _buildPlaylistTabletHeader(
    BuildContext context,
    PlaylistModel playlist,
    List<String> headerImagePaths,
    List<String?> headerArtUrls,
    Color textColor,
    Color? subtitleColor,
    Color accentColor,
    bool hasCover,
    double totalDurationSeconds,
    int songCount,
    List<_PlaylistRowData> rowData,
    List<SongModel> songList,
  ) {
    const collageSize = 180.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Playlist Art
        Container(
          decoration: const BoxDecoration(boxShadow: [
            BoxShadow(
                color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))
          ]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: hasCover
                ? Image.network(playlist.coverUrl!,
                    width: collageSize, height: collageSize, fit: BoxFit.cover)
                : PlaylistCollage(
                    imagePaths: headerImagePaths,
                    onlineArtUrls: headerArtUrls,
                    size: collageSize),
          ),
        ),
        const SizedBox(height: 16),
        // Title
        Text(
          playlist.name,
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // Stats
        Text(
          "${AppLocalizations.of(context)!.countSongs(songCount)} • ${_formatTotalDuration(totalDurationSeconds, AppLocalizations.of(context)!)}",
          style: TextStyle(
            color: subtitleColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        // Play button
        FloatingActionButton(
          onPressed: rowData.isNotEmpty
              ? () => _playTrack(rowData.first.song, songList)
              : null,
          backgroundColor: accentColor,
          child: const Icon(Icons.play_arrow, color: Colors.white),
        ),
      ],
    );
  }

  /// Builds a compact playlist header for tablet portrait (constrained to 35% height).
  Widget _buildPlaylistHeaderCompact(
    BuildContext context,
    PlaylistModel playlist,
    List<String> headerImagePaths,
    List<String?> headerArtUrls,
    Color textColor,
    Color? subtitleColor,
    Color accentColor,
    bool hasCover,
    double totalDurationSeconds,
    int songCount,
    List<_PlaylistRowData> rowData,
    List<SongModel> songList,
  ) {
    const collageSize = 120.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Playlist Art (compact)
        Container(
          decoration: const BoxDecoration(boxShadow: [
            BoxShadow(
                color: Colors.black45, blurRadius: 15, offset: Offset(0, 8))
          ]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: hasCover
                ? Image.network(playlist.coverUrl!,
                    width: collageSize, height: collageSize, fit: BoxFit.cover)
                : PlaylistCollage(
                    imagePaths: headerImagePaths,
                    onlineArtUrls: headerArtUrls,
                    size: collageSize),
          ),
        ),
        const SizedBox(width: 20),
        // Info column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playlist.name,
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                "${AppLocalizations.of(context)!.countSongs(songCount)} • ${_formatTotalDuration(totalDurationSeconds, AppLocalizations.of(context)!)}",
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              // Play button inline
              FloatingActionButton.small(
                onPressed: rowData.isNotEmpty
                    ? () => _playTrack(rowData.first.song, songList)
                    : null,
                backgroundColor: accentColor,
                child:
                    const Icon(Icons.play_arrow, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the playlist action buttons (download, menu) for the app bar.
  Widget _buildPlaylistActions(
    BuildContext context,
    PlaylistModel playlist,
    dynamic notifier,
    List<_PlaylistRowData> rowData,
    Color textColor,
    Color accentColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: (rowData.isNotEmpty &&
                  rowData
                      .every((r) => _downloadStatus[r.song.filePath] == true))
              ? const Icon(Icons.download_done_rounded,
                  color: Colors.greenAccent, size: 28)
              : Icon(Icons.download_rounded, color: textColor, size: 28),
          tooltip: AppLocalizations.of(context)!.downloadAll,
          onPressed: () async {
            if (rowData.isEmpty) return;
            final allDownloaded = rowData.isNotEmpty &&
                rowData.every((r) => _downloadStatus[r.song.filePath] == true);
            if (!allDownloaded) {
              final songsToDownload = rowData.map((r) => r.song).toList();
              BulkDownloadService()
                  .downloadAlbum(playlist.name, songsToDownload);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.startedDownloadingAll),
                duration: const Duration(seconds: 2),
              ));
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
            } else if (value == 'export_m3u') {
              ref.read(playlistProvider.notifier).exportM3uPlaylist(
                  widget.playlistId, onStatus: (statusKey, {args}) {
                if (statusKey == 'exportedM3u') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text(AppLocalizations.of(context)!.exportToM3u),
                        backgroundColor: Colors.green),
                  );
                }
              });
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
                value: 'export_m3u',
                child: Row(children: [
                  Icon(Icons.file_download_outlined,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.exportToM3u),
                ])),
            PopupMenuItem(
                value: 'share',
                child: Row(children: [
                  Icon(Icons.share_outlined,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.sharePlaylist),
                ])),
            PopupMenuItem(
                value: 'rename',
                child: Row(children: [
                  Icon(Icons.edit_outlined,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.renamePlaylist),
                ])),
            PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.deletePlaylist,
                      style: const TextStyle(color: Colors.red)),
                ])),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmAndRemoveSong(BuildContext context, dynamic notifier, SongModel song, Color textColor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(AppLocalizations.of(context)!.removeFromPlaylist,
            style: TextStyle(color: textColor)),
        content: Text(song.title, style: TextStyle(color: textColor)),
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
      notifier.removeSongFromPlaylist(widget.playlistId, song.filePath);
    }
  }

  /// Builds a single playlist track tile for tablet layouts.
  Widget _buildPlaylistTrackTile(
    BuildContext context,
    int index,
    List<_PlaylistRowData> rowData,
    List<SongModel> songList,
    dynamic notifier,
    Color textColor,
    Color? subtitleColor,
    Color accentColor,
  ) {
    final data = rowData[index];
    final isThisLoading = _loadingSongTitle == data.song.title;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 30,
              child: isThisLoading
                  ? Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: accentColor)))
                  : (BulkDownloadService().currentSongNotifier.value ==
                          data.song.filePath)
                      ? Center(
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: accentColor)))
                      : Text("${data.originalIndex}",
                          style: TextStyle(
                              color: subtitleColor,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center)),
          const SizedBox(width: 10),
          SongCardOverlay(
              song: data.song, size: 48, playQueue: songList, radius: 6),
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
          SizedBox(
            width: 45,
            child: Text(_formatDuration(data.song.duration),
                textAlign: TextAlign.end,
                style: TextStyle(color: subtitleColor, fontSize: 12)),
          ),
          if (_downloadStatus[data.song.filePath] == true)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.download_done_rounded,
                  size: 16, color: accentColor),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: subtitleColor),
            tooltip: AppLocalizations.of(context)!.removeFromPlaylist,
            onPressed: () => _confirmAndRemoveSong(
                context, notifier, data.song, textColor),
          ),
        ],
      ),
      onTap: () => _playTrack(data.song, songList),
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
  final int originalIndex;
  final SongModel song;
  final DateTime dateAdded;
  _PlaylistRowData(this.originalIndex, this.song, this.dateAdded);
}
