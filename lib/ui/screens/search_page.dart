import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/music_notification.dart';
import '../components/song_context_menu.dart';
import '../../services/youtube_downloader_service.dart';
import '../../services/smart_download_service.dart';
import '../../models/song_metadata.dart';
import '../../models/debug_match_result.dart';
import '../../models/youtube_search_result.dart';
import '../../models/song_model.dart';
import '../../providers/download_search_provider.dart';
import '../../services/metrics_service.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/search_bridge_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _urlController = TextEditingController();

  // Services
  final YoutubeDownloaderService _ytDlpService = YoutubeDownloaderService();
  final SmartDownloadService _smartDownloadService = SmartDownloadService();

  // State
  bool _isDownloading = false;
  bool _isBuffering = false;
  bool _isInitialized = false;
  String _currentStatus = 'Initializing Downloader...';
  double _progressValue = 0.0;
  String _downloadingTitle = '';

  String? _bufferingVideoId;
  DebugMatchResult? _currentMatchData;

  @override
  void initState() {
    super.initState();

    // 1. Initialize Service
    _ytDlpService.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _currentStatus = 'Ready. Search for a song.';
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _currentStatus = 'Error: Failed to initialize yt-dlp.';
          _isInitialized = false;
        });
      }
    });

    // 🚀 2. CHECK BRIDGE ON LOAD (Fixes the redirect issue)
    // We wait one frame to ensure the widget is built before triggering state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBridge();
    });
  }

  // 🚀 NEW: Checks if a song was passed from the Top Bar
  void _checkBridge() {
    final bridgeSong = ref.read(searchBridgeProvider);
    if (bridgeSong != null) {
      // Clear the bridge so we don't re-trigger on back button
      ref.read(searchBridgeProvider.notifier).state = null;

      // Update UI
      _urlController.text = "${bridgeSong.artist} - ${bridgeSong.title}";

      // Auto-Run the Match Logic
      _viewMatchResults(bridgeSong);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // --- 1. Search Logic ---
  Future<void> _runSearch() async {
    final keyword = _urlController.text.trim();
    if (keyword.isEmpty || _isDownloading || !_isInitialized) {
      ref.read(downloadSearchProvider.notifier).searchSpotify('');
      return;
    }

    setState(() {
      _currentStatus = 'Searching Spotify for "$keyword"...';
    });

    await ref.read(downloadSearchProvider.notifier).searchSpotify(keyword);

    setState(() {
      final results = ref.read(downloadSearchProvider);
      _currentStatus = results.isNotEmpty
          ? 'Found ${results.length} results. Select one to check matches.'
          : 'No Spotify results found.';
    });
  }

  // --- 2. Match Logic ---
  void _viewMatchResults(SongMetadata metadata) async {
    if (_isDownloading) {
      _showError('A download is already in progress.');
      return;
    }

    setState(() {
      _currentStatus = 'Searching YouTube for match verification...';
    });

    final debugResult =
        await _smartDownloadService.searchYouTubeForMatch(metadata);

    if (debugResult != null && mounted) {
      setState(() {
        _currentMatchData = debugResult;
        _currentStatus = 'Matches found. Click to Play, or Download.';
      });
    } else {
      _showError('Failed to retrieve YouTube results for matching.');
      setState(() {
        _currentStatus = 'Search failed. Try again.';
      });
    }
  }

  // --- 3. STREAM (CACHE & PLAY) LOGIC ---
  Future<void> _streamSong(YoutubeSearchResult video) async {
    if (_isBuffering || _isDownloading) return;

    final metadata = _currentMatchData!.spotifyMetadata;

    setState(() {
      _isBuffering = true;
      _bufferingVideoId = video.url;
      _currentStatus = "Buffering...";
    });

    try {
      final SongModel? song = await _smartDownloadService.cacheAndPlay(
        video: video,
        metadata: metadata,
        onProgress: (p) {},
      );

      if (song != null && mounted) {
        // PLAY SONG WITH CONTEXT
        // We pass the song as a single-item queue so it becomes the "playlist".
        // This enables "Repeat One" and prevents empty playlist issues.
        ref.read(playerProvider.notifier).playSong(song, newQueue: [song]);
        showCenterNotification(context,
            label: "NOW PLAYING",
            title: song.title,
            subtitle: song.artist,
            artPath: song.filePath,
            onlineArtUrl: song.onlineArtUrl);
      } else {
        _showError("Stream failed. Check internet connection.");
      }
    } catch (e) {
      if (kDebugMode) print("Stream Error: $e");
      _showError("Stream failed.");
    } finally {
      if (mounted) {
        setState(() {
          _isBuffering = false;
          _bufferingVideoId = null;
          _currentStatus = "Ready.";
        });
      }
    }
  }

  // --- 4. PERMANENT DOWNLOAD LOGIC ---
  void _initiateFinalDownload(YoutubeSearchResult result) async {
    if (_currentMatchData == null) return;

    final metadata = _currentMatchData!.spotifyMetadata;
    final finalTitle = await _smartDownloadService.generateFilename(metadata);
    final tempFileName = finalTitle;

    final preferredFormat = ref.read(settingsProvider).audioFormat;

    setState(() {
      _isDownloading = true;
      _downloadingTitle = finalTitle;
      _currentStatus = 'Checking permissions...'; // Updated status
      _progressValue = 0.0;
    });

    // 🚀 GATEKEEPER CHECK (Ban/Limit)
    // Check ban status first
    final isBanned = await MetricsService().isUserBanned();
    if (isBanned) {
      if (mounted) {
        _showError(
            "⛔ Your account has been suspended. Downloads are disabled.");
        _resetDownloadState();
      }
      return;
    }

    final canDownload = await MetricsService().canDownload();
    if (!canDownload) {
      if (mounted) {
        _showError(
            "📊 Daily Download Limit Reached (50/day). Try again tomorrow!");
        _resetDownloadState();
      }
      return;
    }

    if (mounted) {
      setState(
          () => _currentStatus = 'Starting download ($preferredFormat)...');
    }

    final outputPath =
        await _ytDlpService.getDownloadPath(tempFileName, ext: preferredFormat);

    if (outputPath == null) {
      _showError('Storage permission denied.');
      _resetDownloadState();
      return;
    }

    await _ytDlpService.startDownloadFromUrl(
      youtubeUrl: result.url,
      outputFilePath: outputPath,
      audioFormat: preferredFormat,
      onProgress: (p) {
        setState(() {
          _progressValue = p;
          _currentStatus = 'Downloading ${(p * 100).toStringAsFixed(0)}%';
        });
      },
      onComplete: (success) async {
        if (success) {
          if (mounted) {
            setState(() => _currentStatus = "Writing Metadata & Tags...");
          }

          try {
            await _smartDownloadService.tagFile(
              filePath: outputPath,
              metadata: metadata,
            );
          } catch (e) {
            print("Tagging warning: $e");
          }

          _showSuccess('Download Complete', finalTitle);

          // 🚀 Track Download
          MetricsService().trackDownloadMetadata(metadata);

          if (mounted) {
            setState(() {
              _currentMatchData = null;
            });
          }
        } else {
          _showError('Download failed.');
        }
        _resetDownloadState();
      },
    );
  }

  void _resetDownloadState() {
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _progressValue = 0.0;
        _downloadingTitle = '';
        if (_currentStatus.startsWith('Download') ||
            _currentStatus.startsWith('Writing')) {
          _currentStatus = 'Ready.';
        }
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _currentStatus = 'Error: $message');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  void _showSuccess(String title, String subtitle) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$title: $subtitle'), backgroundColor: Colors.green));
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 3. KEEP LISTENING for subsequent searches
    ref.listen<SongMetadata?>(searchBridgeProvider, (previous, next) {
      if (next != null) {
        if (mounted) {
          // Visual Sync
          _urlController.text = "${next.artist} - ${next.title}";
          // Trigger
          _viewMatchResults(next);
          // Clear
          ref.read(searchBridgeProvider.notifier).state = null;
        }
      }
    });

    if (_currentMatchData != null) {
      return _buildMatchSelectionView(context);
    }
    return _buildSearchView(context);
  }

  Widget _buildSearchView(BuildContext context) {
    final searchResults = ref.watch(downloadSearchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = Theme.of(context).colorScheme.primary;
    final bool isActionDisabled =
        _isDownloading || _isBuffering || !_isInitialized;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text('Music Search',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              enabled: !isActionDisabled,
              style: TextStyle(color: textColor),
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                labelText: 'Song Title or Keyword',
                hintText: 'Search Spotify...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search, color: textColor.withOpacity(0.7)),
                  onPressed: isActionDisabled ? null : _runSearch,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Status: $_currentStatus',
                style: TextStyle(color: textColor.withOpacity(0.6))),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final result = searchResults[index];
                  final durationDisplay =
                      '${(result.durationSeconds ~/ 60)}:${(result.durationSeconds % 60).toString().padLeft(2, '0')}';
                  return Card(
                    color: textColor.withOpacity(0.05),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Image.network(result.albumArtUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (c, o, s) =>
                              const Icon(Icons.music_note)),
                      title: Text(result.title,
                          style: TextStyle(color: textColor)),
                      subtitle: Text('${result.artist} • $durationDisplay',
                          style: TextStyle(color: textColor.withOpacity(0.7))),
                      trailing: Icon(Icons.chevron_right, color: accentColor),
                      onTap: isActionDisabled
                          ? null
                          : () => _viewMatchResults(result),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchSelectionView(BuildContext context) {
    final target = _currentMatchData!.spotifyMetadata;
    final matches = _currentMatchData!.youtubeMatches;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Select Version'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: (_isDownloading || _isBuffering)
              ? null
              : () => setState(() => _currentMatchData = null),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                        image: NetworkImage(target.albumArtUrl),
                        fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(target.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: textColor, fontWeight: FontWeight.bold)),
                    Text(target.artist,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: textColor.withOpacity(0.7))),
                    Text(
                        'Target Duration: ${_formatDuration(target.durationSeconds)}',
                        style: TextStyle(
                            color: accentColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const Divider(height: 40),
            if (_isDownloading || _isBuffering) ...[
              LinearProgressIndicator(
                  value: _progressValue > 0 ? _progressValue : null,
                  backgroundColor: textColor.withOpacity(0.1),
                  color: accentColor),
              const SizedBox(height: 10),
              Text(_currentStatus, style: TextStyle(color: textColor)),
              const SizedBox(height: 20),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final ytResult = matches[index];
                  final ytDuration = _smartDownloadService
                          .parseDurationToSeconds(ytResult.duration) ??
                      0;
                  final diff = (target.durationSeconds - ytDuration).abs();
                  final isMatch =
                      diff <= SmartDownloadService.maxDurationDifferenceSeconds;
                  final isThisBuffering = _bufferingVideoId == ytResult.url;

                  // 🚀 CREATE TEMP SONG FOR CONTEXT MENU
                  // We need to predict the path so the player knows where to look
                  // and pass the sourceUrl so it knows what to download.
                  final tempMeta = SongMetadata(
                    title: ytResult.title,
                    artist: ytResult.artist,
                    album: "YouTube Search",
                    albumArtUrl: ytResult.thumbnailUrl,
                    durationSeconds: ytDuration,
                    year: "",
                    genre: "",
                  );

                  return FutureBuilder<String>(
                    future:
                        SmartDownloadService().getPredictedCachePath(tempMeta),
                    builder: (context, snapshot) {
                      final predictedPath = snapshot.data ?? "";

                      final tempSong = SongModel(
                        title: target.title, // 🚀 USE SPOTIFY TITLE
                        artist: target.artist, // 🚀 USE SPOTIFY ARTIST
                        album: target.album, // 🚀 USE SPOTIFY ALBUM
                        filePath: predictedPath,
                        fileExtension: '.mp3',
                        duration: target.durationSeconds
                            .toDouble(), // 🚀 USE SPOTIFY DURATION
                        onlineArtUrl: target.albumArtUrl, // 🚀 USE SPOTIFY ART
                        sourceUrl: ytResult.url, // Keep YouTube Source URL
                      );

                      return SongContextMenuRegion(
                        song: tempSong,
                        currentQueue: const [],
                        child: Card(
                          color: isMatch
                              ? Colors.green.withOpacity(0.1)
                              : textColor.withOpacity(0.05),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ListTile(
                              onTap: (_isDownloading || _isBuffering)
                                  ? null
                                  : () => _streamSong(ytResult),
                              leading: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.network(ytResult.thumbnailUrl,
                                      width: 60, height: 45, fit: BoxFit.cover),
                                  if (isThisBuffering)
                                    const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white)),
                                  if (!isThisBuffering)
                                    const Icon(Icons.play_circle_fill,
                                        color: Colors.white70, size: 24),
                                  if (isMatch)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        color: Colors.black54,
                                        child: const Icon(Icons.check_circle,
                                            color: Colors.green, size: 14),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(ytResult.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: textColor)),
                              subtitle: Text(
                                '${ytResult.artist} • ${ytResult.duration} (Diff: ${diff}s)',
                                style: TextStyle(
                                    color: isMatch
                                        ? Colors.green
                                        : Colors.redAccent),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.download),
                                    color: accentColor,
                                    tooltip: "Download Permanently",
                                    onPressed: (_isDownloading || _isBuffering)
                                        ? null
                                        : () =>
                                            _initiateFinalDownload(ytResult),
                                  ),
                                  PopupMenuButton<SongAction>(
                                    icon:
                                        Icon(Icons.more_vert, color: textColor),
                                    tooltip: "More Options",
                                    onSelected: (action) {
                                      SongContextMenuRegion.handleAction(
                                          context, ref, action, tempSong);
                                    },
                                    itemBuilder: (context) => [
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
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
