import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../providers/download_search_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../models/song_metadata.dart';

import '../../services/hybrid_service.dart';
import '../../services/tidal_service.dart';
import '../../providers/tidal_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../services/youtube_downloader_service.dart';
import '../../services/itunes_api_service.dart';

import '../../services/pocketbase_service.dart'; // 🔒 OFFLINE MODE
import '../../env/env.dart';
import '../../utils/layout_engine.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _urlController = TextEditingController();

  // SUGGESTION STATE
  Timer? _debounce;
  List<SongMetadata> _songSuggestions = [];
  List<AlbumModel> _albumSuggestions = [];
  List<ArtistModel> _artistSuggestions = [];
  bool _isSuggesting = false;
  bool _isLoadingSuggestions = false;
  String _currentStatus = '';
  
  // YOUTUBE PAGINATION STATE
  int _currentYoutubeLimit = 20;
  bool _isLoadingMore = false;

  // NETWORK STATE
  bool _isOnline = true;
  Timer? _connectivityTimer;

  late AppLocalizations _l10n;

  @override
  void initState() {
    super.initState();
    // Periodic check is fine
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkConnectivity(),
    );

    // CHECK BRIDGE ON LOAD (Fixes the redirect issue)
    // We wait one frame to ensure the widget is built before triggering state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBridge();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context)!;
    // Perform initial connectivity check here instead of initState
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    // 🔒 OFFLINE MODE: Force offline state
    if (PocketBaseService.isOffline) {
      if (mounted) {
        setState(() {
          _isOnline = false;
          _currentStatus = "Offline Mode Active";
        });
      }
      return;
    }

    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
          if (_isOnline &&
              (_currentStatus == _l10n.offline ||
                  _currentStatus == 'Offline')) {
            _currentStatus = _l10n.readySearchSong;
          } else if (!_isOnline) {
            _currentStatus = _l10n.offline;
          }
        });
      }
    } catch (_) {
      // SocketException, TimeoutException, or any other error = offline
      if (mounted) {
        setState(() {
          _isOnline = false;
          _currentStatus = _l10n.offline;
        });
      }
    }
  }

  // NEW: Checks if a song was passed from the Top Bar
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

  // NEW: Suggestions Logic
  void _onSearchQueryChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _currentYoutubeLimit = 20; // Reset limit on new search

    // 🔒 OFFLINE MODE: Disable suggestions
    if (PocketBaseService.isOffline || query.isEmpty) {
      setState(() {
        _isSuggesting = false;
        _songSuggestions = [];
        _albumSuggestions = [];
        _artistSuggestions = [];
      });
      return;
    }

    setState(() {
      _isSuggesting = true;
      _isLoadingSuggestions = true;
    });

    _debounce = Timer(const Duration(milliseconds: 600), () {
      _performSearch(query);
    });
  }

  Future<void> _loadMoreYoutube() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _currentYoutubeLimit += 10;
    });
    
    await _performSearch(_urlController.text, isLoadMore: true);
    
    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _performSearch(String keyword, {bool isLoadMore = false}) async {
      if (!isLoadMore) {
        setState(() => _isLoadingSuggestions = true);
      }

      final settings = ref.read(settingsProvider);
      final searchEngine = settings.searchEngine;

      try {
        if (searchEngine == SearchEngine.appleMusic) {
          final results = await ITunesApiService.searchAll(keyword, limit: 5);
          if (mounted && _isSuggesting) {
            setState(() {
              _songSuggestions = (results['songs'] as List?)?.cast<SongMetadata>() ?? [];
              _albumSuggestions = (results['albums'] as List?)?.cast<AlbumModel>() ?? [];
              _artistSuggestions = (results['artists'] as List?)?.cast<ArtistModel>() ?? [];
              _isLoadingSuggestions = false;
            });
          }
        } else if (searchEngine == SearchEngine.youtube) {
          // Use yt-dlp directly for raw YouTube results (no cleaning, original thumbnails)
          final ytService = YoutubeDownloaderService();
          final results = await ytService.searchVideo(keyword, limit: _currentYoutubeLimit);
          if (mounted && _isSuggesting) {
            setState(() {
              _songSuggestions = results
                  .map((yt) => SongMetadata(
                        title: yt.title,
                        artist: yt.artist,
                        album: "",
                        durationSeconds: _parseDuration(yt.duration),
                        albumArtUrl: yt.thumbnailUrl,
                        youtubeUrl: yt.url,
                      ))
                  .toList();
              _albumSuggestions = [];
              _artistSuggestions = [];
              _isLoadingSuggestions = false;
            });
          }
        } else {
          final results = await HybridService.searchAll(keyword, limit: 5);
          if (mounted && _isSuggesting) {
            setState(() {
              _songSuggestions =
                  (results['songs'] as List?)?.cast<SongMetadata>() ??
                      <SongMetadata>[];
              _albumSuggestions =
                  (results['albums'] as List?)?.cast<AlbumModel>() ??
                      <AlbumModel>[];
              _artistSuggestions =
                  (results['artists'] as List?)?.cast<ArtistModel>() ??
                      <ArtistModel>[];
              _isLoadingSuggestions = false;
            });
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingSuggestions = false);
      }
  }

  int _parseDuration(String duration) {
    try {
      final parts = duration.split(':');
      if (parts.length == 2) {
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      } else if (parts.length == 3) {
        return int.parse(parts[0]) * 3600 +
            int.parse(parts[1]) * 60 +
            int.parse(parts[2]);
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }



  void _onSuggestionSelected(dynamic item) {
    // Hide keyboard
    FocusManager.instance.primaryFocus?.unfocus();

    // Clear suggestions
    setState(() => _isSuggesting = false);

    final navStack = ref.read(navigationStackProvider.notifier);

    if (item is SongMetadata) {
      // For songs, we can act as if we searched for it?
      // OR navigate to track detail (if we had one).
      // The user said: "view artist/album detailed".
      // For songs, let's trigger the MATCH LOGIC directly (Deep Search)
      // This mimics the behavior of clicking a result in the existing search.

      _urlController.text = "${item.artist} - ${item.title}";
      _viewMatchResults(item);
    } else if (item is AlbumModel) {
      navStack.push(NavigationItem(type: NavigationType.album, data: item));
    } else if (item is ArtistModel) {
      navStack.push(
        NavigationItem(
          type: NavigationType.artist,
          data: ArtistSelection(artistName: item.name),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _connectivityTimer?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  // --- 1. Search Logic ---
  Future<void> _runSearch() async {
    // 🔒 OFFLINE MODE: Block search
    if (PocketBaseService.isOffline) return;

    final keyword = _urlController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _songSuggestions = [];
        _albumSuggestions = [];
        _artistSuggestions = [];
        _isSuggesting = false;
        _currentStatus = _l10n.readySearchSong;
      });
      return;
    }

    // Show loading state
    setState(() {
      final settings = ref.read(settingsProvider);
      final engineName = settings.searchEngine == SearchEngine.appleMusic 
          ? "Apple Music" 
          : (settings.searchEngine == SearchEngine.youtube ? "YouTube" : "Spotify");
      _currentStatus = _l10n.searchingEngine(engineName, keyword);
      _isLoadingSuggestions = true;
      _isSuggesting = true; // Keep suggestion list visible
    });

    try {
      final settings = ref.read(settingsProvider);
      if (settings.searchEngine == SearchEngine.appleMusic) {
        final results = await ITunesApiService.searchAll(keyword, limit: 10);
        if (mounted) {
          setState(() {
            _songSuggestions = (results['songs'] as List?)?.cast<SongMetadata>() ?? [];
            _albumSuggestions = (results['albums'] as List?)?.cast<AlbumModel>() ?? [];
            _artistSuggestions = (results['artists'] as List?)?.cast<ArtistModel>() ?? [];
            _isLoadingSuggestions = false;

            final songCount = _songSuggestions.length;
            final albumCount = _albumSuggestions.length;
            final artistCount = _artistSuggestions.length;
            
            if (songCount + albumCount + artistCount > 0) {
              _currentStatus = _l10n.foundResults(songCount, albumCount, artistCount);
            } else {
              _currentStatus = _l10n.noSpotifyResults; // Generic fallback
            }
          });
        }
      } else if (settings.searchEngine == SearchEngine.youtube) {
        // Use yt-dlp directly for raw YouTube results (no cleaning, original thumbnails)
        final ytService = YoutubeDownloaderService();
        final results = await ytService.searchVideo(keyword, limit: _currentYoutubeLimit);

        if (mounted) {
          setState(() {
            _songSuggestions = results
                .map((yt) => SongMetadata(
                      title: yt.title,
                      artist: yt.artist,
                      album: "",
                      durationSeconds: _parseDuration(yt.duration),
                      albumArtUrl: yt.thumbnailUrl,
                      youtubeUrl: yt.url,
                    ))
                .toList();
            _albumSuggestions = [];
            _artistSuggestions = [];
            _isLoadingSuggestions = false;

            final songCount = _songSuggestions.length;
            if (songCount > 0) {
              _currentStatus = _l10n.foundYoutubeResults(songCount);
            } else {
              _currentStatus = _l10n.noYoutubeResults;
            }
          });
        }
      } else {
        // Use searchAll to get Songs, Albums, Artists (5 each)
        final results = await HybridService.searchAll(keyword, limit: 5);

        if (mounted) {
          setState(() {
            _songSuggestions =
                (results['songs'] as List?)?.cast<SongMetadata>() ??
                    <SongMetadata>[];
            _albumSuggestions =
                (results['albums'] as List?)?.cast<AlbumModel>() ??
                    <AlbumModel>[];
            _artistSuggestions =
                (results['artists'] as List?)?.cast<ArtistModel>() ??
                    <ArtistModel>[];
            _isLoadingSuggestions = false;

            final songCount = _songSuggestions.length;
            final albumCount = _albumSuggestions.length;
            final artistCount = _artistSuggestions.length;

            if (songCount + albumCount + artistCount > 0) {
              _currentStatus =
                  _l10n.foundResults(songCount, albumCount, artistCount);
            } else {
              _currentStatus = _l10n.noSpotifyResults;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
          _currentStatus = _l10n.searchFailedStatus(e.toString());
        });
      }
    }
  }

  // --- 2. Match Logic ---
  void _viewMatchResults(SongMetadata metadata) {
    // NAVIGATE TO TRACK DETAIL PAGE (Replaces inline match selection)
    ref.read(navigationStackProvider.notifier).push(
          NavigationItem(
            type: NavigationType.track,
            data: metadata,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10nObj = AppLocalizations.of(context);
    if (l10nObj == null) return const SizedBox.shrink();
    _l10n = l10nObj;

    // Robust Locale Switching: Update status if it's currently a "ready" or "offline" string
    if (_currentStatus.isEmpty ||
        _currentStatus == 'Ready. Search for a song.' ||
        _currentStatus == 'Offline') {
      _currentStatus = _l10n.readySearchSong;
    }
    // 3. KEEP LISTENING for subsequent searches
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

    return _buildSearchView(context);
  }

  Widget _buildSearchView(BuildContext context) {
    final searchResults = ref.watch(downloadSearchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = Theme.of(context).colorScheme.primary;

    // Tablet layout detection
    final isTablet = LayoutEngine.isTablet(context);
    final isLandscape = LayoutEngine.isLandscape(context);

    if (isTablet) {
      return _buildTabletSearchView(
        context,
        searchResults: searchResults,
        textColor: textColor,
        accentColor: accentColor,
        isLandscape: isLandscape,
      );
    }

    // --- Phone layout (unchanged) ---
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            // HEADER (Shifted on Mobile)
            Padding(
              padding: EdgeInsets.only(
                  left: (Platform.isAndroid || Platform.isIOS) ? 40.0 : 0.0),
              child: Text(_l10n.musicSearch,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold, color: textColor)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              enabled: true,

              style: TextStyle(color: textColor),
              onChanged: _onSearchQueryChanged, // Trigger suggestions
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                labelText: _l10n.songTitleKeyword,
                hintText: ref.watch(settingsProvider).searchEngine ==
                        SearchEngine.youtube
                    ? _l10n.searchYoutubeHint
                    : _l10n.searchSpotifyHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search,
                      color: textColor.withValues(alpha: 0.7)),
                  onPressed: _runSearch,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_l10n.statusWithText(_currentStatus),
                    style: TextStyle(color: textColor.withValues(alpha: 0.6))),
                Consumer(
                  builder: (context, ref, _) {
                    final tidalStatus = ref.watch(tidalStatusProvider);
                    return tidalStatus.when(
                      data: (state) {
                        final color = _getTidalColor(state.status);
                        final text = _getTidalStatusText(context, state.status);

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("${_l10n.tidalApiStatus}: ",
                                style: TextStyle(
                                    color: textColor.withValues(alpha: 0.6),
                                    fontSize: 11)),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(text,
                                style: TextStyle(
                                    color: color.withValues(alpha: 0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          ],
                        );
                      },
                      loading: () => Text("${_l10n.tidalApiStatus}: ...",
                          style: TextStyle(
                              color: textColor.withValues(alpha: 0.4),
                              fontSize: 11)),
                      error: (_, __) => Text(
                          "${_l10n.tidalApiStatus}: ${_l10n.offlineStatus}",
                          style: TextStyle(
                              color: Colors.redAccent.withValues(alpha: 0.6),
                              fontSize: 11)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // NO INTERNET CONNECTION MESSAGE
            if (!_isOnline)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 64,
                        color: textColor.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _l10n.noInternetConnection,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _l10n.checkNetworkTryAgain,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // SUGGESTIONS LIST (Overlay Behavior)
            else if (_isSuggesting)
              Expanded(
                child: _buildSuggestionsList(textColor),
              )
            else
              // EXISTING RESULTS
              Expanded(
                child: ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final result = searchResults[index];
                    final durationDisplay =
                        '${(result.durationSeconds ~/ 60)}:${(result.durationSeconds % 60).toString().padLeft(2, '0')}';
                    return Card(
                      color: textColor.withValues(alpha: 0.05),
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
                            style: TextStyle(
                                color: textColor.withValues(alpha: 0.7))),
                        trailing: Icon(Icons.chevron_right, color: accentColor),
                        onTap: () => _viewMatchResults(result),
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

  // --- Tablet Search Layout ---
  Widget _buildTabletSearchView(
    BuildContext context, {
    required List<SongMetadata> searchResults,
    required Color textColor,
    required Color accentColor,
    required bool isLandscape,
  }) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_l10n.musicSearch,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold, color: textColor)),
            ),
            const SizedBox(height: 20),
            // Search bar: max 600dp, centered horizontally
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: TextField(
                  controller: _urlController,
                  enabled: true,
                  style: TextStyle(color: textColor),
                  onChanged: _onSearchQueryChanged,
                  onSubmitted: (_) => _runSearch(),
                  decoration: InputDecoration(
                    labelText: _l10n.songTitleKeyword,
                    hintText: ref.watch(settingsProvider).searchEngine ==
                            SearchEngine.youtube
                        ? _l10n.searchYoutubeHint
                        : _l10n.searchSpotifyHint,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search,
                          color: textColor.withValues(alpha: 0.7)),
                      onPressed: _runSearch,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Status row
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(_l10n.statusWithText(_currentStatus),
                          style: TextStyle(
                              color: textColor.withValues(alpha: 0.6))),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final tidalStatus = ref.watch(tidalStatusProvider);
                        return tidalStatus.when(
                          data: (state) {
                            final color = _getTidalColor(state.status);
                            final text =
                                _getTidalStatusText(context, state.status);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("${_l10n.tidalApiStatus}: ",
                                    style: TextStyle(
                                        color: textColor.withValues(alpha: 0.6),
                                        fontSize: 11)),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(text,
                                    style: TextStyle(
                                        color: color.withValues(alpha: 0.8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500)),
                              ],
                            );
                          },
                          loading: () => Text("${_l10n.tidalApiStatus}: ...",
                              style: TextStyle(
                                  color: textColor.withValues(alpha: 0.4),
                                  fontSize: 11)),
                          error: (_, __) => Text(
                              "${_l10n.tidalApiStatus}: ${_l10n.offlineStatus}",
                              style: TextStyle(
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.6),
                                  fontSize: 11)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Results area
            if (!_isOnline)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 64, color: textColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(_l10n.noInternetConnection,
                          style: TextStyle(
                              color: textColor.withValues(alpha: 0.6),
                              fontSize: 18,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text(_l10n.checkNetworkTryAgain,
                          style: TextStyle(
                              color: textColor.withValues(alpha: 0.4),
                              fontSize: 14)),
                    ],
                  ),
                ),
              )
            else if (_isSuggesting)
              Expanded(
                child: _buildTabletSuggestions(
                  textColor: textColor,
                  accentColor: accentColor,
                  isLandscape: isLandscape,
                ),
              )
            else
              Expanded(
                child: _buildTabletResults(
                  searchResults: searchResults,
                  textColor: textColor,
                  accentColor: accentColor,
                  isLandscape: isLandscape,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Tablet suggestions layout: landscape = 2-column, portrait = single column
  /// with horizontal scrollable row for albums/artists.
  Widget _buildTabletSuggestions({
    required Color textColor,
    required Color accentColor,
    required bool isLandscape,
  }) {
    if (_isLoadingSuggestions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_songSuggestions.isEmpty &&
        _albumSuggestions.isEmpty &&
        _artistSuggestions.isEmpty) {
      return Center(
        child: Text(_l10n.noSuggestionsFound,
            style: TextStyle(color: textColor.withValues(alpha: 0.5))),
      );
    }

    if (isLandscape) {
      // Landscape: 2-column layout — songs on left, albums/artists grid on right
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Songs list
          Expanded(
            child: _buildTabletSongsList(textColor: textColor),
          ),
          const SizedBox(width: 16),
          // Right column: Albums/Artists grid
          Expanded(
            child: _buildTabletAlbumsArtistsGrid(
              textColor: textColor,
              accentColor: accentColor,
            ),
          ),
        ],
      );
    } else {
      // Portrait: single column with horizontal scrollable row for albums/artists
      return ListView(
        children: [
          if (_songSuggestions.isNotEmpty) ...[
            _buildHeader(_l10n.songs, textColor),
            ..._songSuggestions.asMap().entries.map((entry) => 
                _buildSongTile(entry.value, textColor, 
                    index: ref.read(settingsProvider).searchEngine == SearchEngine.youtube ? entry.key : null)),
            if (ref.read(settingsProvider).searchEngine == SearchEngine.youtube)
              _buildLoadMoreButton(),
          ],
          if (_albumSuggestions.isNotEmpty) ...[
            _buildHeader(_l10n.albums, textColor),
            _buildHorizontalScrollableRow(
              items: _albumSuggestions,
              textColor: textColor,
              isAlbum: true,
            ),
          ],
          if (_artistSuggestions.isNotEmpty) ...[
            _buildHeader(_l10n.artists, textColor),
            _buildHorizontalScrollableRow(
              items: _artistSuggestions,
              textColor: textColor,
              isAlbum: false,
            ),
          ],
        ],
      );
    }
  }

  /// Tablet results layout for non-suggestion mode.
  Widget _buildTabletResults({
    required List<SongMetadata> searchResults,
    required Color textColor,
    required Color accentColor,
    required bool isLandscape,
  }) {
    if (searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isLandscape) {
      // Landscape: 2-column — songs list on left, albums/artists grid on right
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: songs list
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final result = searchResults[index];
                final durationDisplay =
                    '${(result.durationSeconds ~/ 60)}:${(result.durationSeconds % 60).toString().padLeft(2, '0')}';
                return Card(
                  color: textColor.withValues(alpha: 0.05),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(result.albumArtUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (c, o, s) =>
                              const Icon(Icons.music_note)),
                    ),
                    title:
                        Text(result.title, style: TextStyle(color: textColor)),
                    subtitle: Text('${result.artist} • $durationDisplay',
                        style:
                            TextStyle(color: textColor.withValues(alpha: 0.7))),
                    trailing: Icon(Icons.chevron_right, color: accentColor),
                    onTap: () => _viewMatchResults(result),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          // Right: albums/artists grid (if available from suggestions state)
          Expanded(
            child: _buildTabletAlbumsArtistsGrid(
              textColor: textColor,
              accentColor: accentColor,
            ),
          ),
        ],
      );
    } else {
      // Portrait: single column with results
      return ListView.builder(
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final result = searchResults[index];
          final durationDisplay =
              '${(result.durationSeconds ~/ 60)}:${(result.durationSeconds % 60).toString().padLeft(2, '0')}';
          return Card(
            color: textColor.withValues(alpha: 0.05),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(result.albumArtUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (c, o, s) => const Icon(Icons.music_note)),
              ),
              title: Text(result.title, style: TextStyle(color: textColor)),
              subtitle: Text('${result.artist} • $durationDisplay',
                  style: TextStyle(color: textColor.withValues(alpha: 0.7))),
              trailing: Icon(Icons.chevron_right, color: accentColor),
              onTap: () => _viewMatchResults(result),
            ),
          );
        },
      );
    }
  }

  /// Builds the songs list column for tablet landscape layout.
  Widget _buildTabletSongsList({required Color textColor}) {
    if (_songSuggestions.isEmpty) {
      return Center(
        child: Text(_l10n.songs,
            style: TextStyle(color: textColor.withValues(alpha: 0.4))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(_l10n.songs, textColor),
        Expanded(
          child: ListView(
            children: [
              ..._songSuggestions.asMap().entries.map((entry) => 
                  _buildSongTile(entry.value, textColor, 
                      index: ref.read(settingsProvider).searchEngine == SearchEngine.youtube ? entry.key : null)),
              if (ref.read(settingsProvider).searchEngine == SearchEngine.youtube)
                _buildLoadMoreButton(),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the albums/artists grid for tablet landscape layout.
  /// Shows grid tiles with minimum 3 per row.
  Widget _buildTabletAlbumsArtistsGrid({
    required Color textColor,
    required Color accentColor,
  }) {
    final hasAlbums = _albumSuggestions.isNotEmpty;
    final hasArtists = _artistSuggestions.isNotEmpty;

    if (!hasAlbums && !hasArtists) {
      return Center(
        child: Text('${_l10n.albums} & ${_l10n.artists}',
            style: TextStyle(color: textColor.withValues(alpha: 0.4))),
      );
    }

    return ListView(
      children: [
        if (hasAlbums) ...[
          _buildHeader(_l10n.albums, textColor),
          _buildGridTiles(
            items: _albumSuggestions,
            textColor: textColor,
            isAlbum: true,
          ),
        ],
        if (hasArtists) ...[
          _buildHeader(_l10n.artists, textColor),
          _buildGridTiles(
            items: _artistSuggestions,
            textColor: textColor,
            isAlbum: false,
          ),
        ],
      ],
    );
  }

  /// Builds grid tiles for albums or artists (minimum 3 per row).
  Widget _buildGridTiles({
    required List<dynamic> items,
    required Color textColor,
    required bool isAlbum,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildGridTile(item, textColor, isAlbum);
      },
    );
  }

  /// Builds a single grid tile for an album or artist.
  Widget _buildGridTile(dynamic item, Color textColor, bool isAlbum) {
    final String imageUrl;
    final String title;
    final String? subtitle;

    if (isAlbum && item is AlbumModel) {
      imageUrl = item.imageUrl;
      title = item.title;
      subtitle = item.artist;
    } else if (!isAlbum && item is ArtistModel) {
      imageUrl = item.imageUrl;
      title = item.name;
      subtitle = null;
    } else {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _onSuggestionSelected(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isAlbum ? 8 : 100),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (c, o, e) => Container(
                    color: textColor.withValues(alpha: 0.1),
                    child: Icon(
                      isAlbum ? Icons.album : Icons.person,
                      color: textColor.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(title,
              style: TextStyle(color: textColor, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          if (subtitle != null)
            Text(subtitle,
                style: TextStyle(
                    color: textColor.withValues(alpha: 0.6), fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
        ],
      ),
    );
  }

  /// Builds a horizontal scrollable row of grid tiles for portrait tablet mode.
  Widget _buildHorizontalScrollableRow({
    required List<dynamic> items,
    required Color textColor,
    required bool isAlbum,
  }) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final String imageUrl;
          final String title;
          final String? subtitle;

          if (isAlbum && item is AlbumModel) {
            imageUrl = item.imageUrl;
            title = item.title;
            subtitle = item.artist;
          } else if (!isAlbum && item is ArtistModel) {
            imageUrl = item.imageUrl;
            title = item.name;
            subtitle = null;
          } else {
            return const SizedBox.shrink();
          }

          return GestureDetector(
            onTap: () => _onSuggestionSelected(item),
            child: SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(isAlbum ? 8 : 50),
                    child: Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, e) => Container(
                        width: 100,
                        height: 100,
                        color: textColor.withValues(alpha: 0.1),
                        child: Icon(
                          isAlbum ? Icons.album : Icons.person,
                          color: textColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(title,
                      style: TextStyle(color: textColor, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                  if (subtitle != null)
                    Text(subtitle,
                        style: TextStyle(
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongTile(SongMetadata s, Color textColor, {int? index}) {
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index != null) ...[
            SizedBox(
              width: 24,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                    color: textColor.withValues(alpha: 0.5), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(s.albumArtUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (c, o, e) => const Icon(Icons.music_note)),
          ),
        ],
      ),
      title: Text(s.title,
          style: TextStyle(color: textColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(s.artist,
          style: TextStyle(color: textColor.withValues(alpha: 0.7)),
          maxLines: 1),
      onTap: () => _onSuggestionSelected(s),
      dense: true,
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Center(
        child: ElevatedButton(
          onPressed: _isLoadingMore ? null : _loadMoreYoutube,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            foregroundColor: Theme.of(context).colorScheme.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isLoadingMore 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Show More"),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(Color textColor) {
    if (_isLoadingSuggestions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_songSuggestions.isEmpty &&
        _albumSuggestions.isEmpty &&
        _artistSuggestions.isEmpty) {
      return Center(
        child: Text(_l10n.noSuggestionsFound,
            style: TextStyle(color: textColor.withValues(alpha: 0.5))),
      );
    }

    return ListView(
      children: [
        if (_songSuggestions.isNotEmpty) ...[
          _buildHeader(_l10n.songs, textColor),
          ..._songSuggestions.asMap().entries.map((entry) => ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ref.read(settingsProvider).searchEngine == SearchEngine.youtube) ...[
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${entry.key + 1}',
                          style: TextStyle(
                              color: textColor.withValues(alpha: 0.5), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(entry.value.albumArtUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (c, o, e) => const Icon(Icons.music_note)),
                    ),
                  ],
                ),
                title: Text(entry.value.title,
                    style: TextStyle(color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(entry.value.artist,
                    style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                    maxLines: 1),
                onTap: () => _onSuggestionSelected(entry.value),
                dense: true,
              )),
          if (ref.read(settingsProvider).searchEngine == SearchEngine.youtube)
            _buildLoadMoreButton(),
        ],
        if (_albumSuggestions.isNotEmpty) ...[
          _buildHeader(_l10n.albums, textColor),
          ..._albumSuggestions.map((a) => ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(a.imageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, e) => const Icon(Icons.album)),
                ),
                title: Text(a.title,
                    style: TextStyle(color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(a.artist,
                    style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                    maxLines: 1),
                onTap: () => _onSuggestionSelected(a),
                dense: true,
              )),
        ],
        if (_artistSuggestions.isNotEmpty) ...[
          _buildHeader(_l10n.artists, textColor),
          ..._artistSuggestions.map((a) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(a.imageUrl),
                  radius: 20,
                ),
                title: Text(a.name,
                    style: TextStyle(color: textColor), maxLines: 1),
                onTap: () => _onSuggestionSelected(a),
                dense: true,
              )),
        ],
      ],
    );
  }

  Widget _buildHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4, left: 16),
      child: Text(title,
          style: TextStyle(
              color: textColor.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              fontSize: 12)),
    );
  }

  Color _getTidalColor(TidalApiStatus status) {
    switch (status) {
      case TidalApiStatus.online:
        return Colors.greenAccent;
      case TidalApiStatus.unauthorize:
        return Colors.orangeAccent;
      case TidalApiStatus.offlineStatus:
      case TidalApiStatus.noInternet:
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _getTidalStatusText(BuildContext context, TidalApiStatus status) {
    try {
      switch (status) {
        case TidalApiStatus.online:
          return _l10n.online;
        case TidalApiStatus.unauthorize:
          return _l10n.unauthorize;
        case TidalApiStatus.offlineStatus:
          return _l10n.offlineStatus;
        case TidalApiStatus.noInternet:
          return _l10n.checkInternetConnection;
        default:
          return "...";
      }
    } catch (e) {
      return status.name.toUpperCase();
    }
  }
}
