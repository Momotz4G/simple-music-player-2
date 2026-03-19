import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'dart:async';

import '../../providers/download_search_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../models/song_metadata.dart';

import '../../services/hybrid_service.dart';
import '../../services/tidal_service.dart';
import '../../providers/tidal_provider.dart';
import '../../l10n/app_localizations.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _urlController = TextEditingController();

  // 🚀 SUGGESTION STATE
  Timer? _debounce;
  List<SongMetadata> _songSuggestions = [];
  List<AlbumModel> _albumSuggestions = [];
  List<ArtistModel> _artistSuggestions = [];
  bool _isSuggesting = false;
  bool _isLoadingSuggestions = false;
  String _currentStatus = '';

  // 🚀 NETWORK STATE
  bool _isOnline = true;
  Timer? _connectivityTimer;

  late AppLocalizations _l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context)!;
    if (_currentStatus.isEmpty ||
        _currentStatus == 'Ready. Search for a song.') {
      _currentStatus = _l10n.readySearchSong;
    }
  }

  @override
  void initState() {
    super.initState();
    // Check connectivity on load and periodically
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkConnectivity(),
    );

    // 🚀 CHECK BRIDGE ON LOAD (Fixes the redirect issue)
    // We wait one frame to ensure the widget is built before triggering state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBridge();
    });
  }

  Future<void> _checkConnectivity() async {
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

  // 🚀 NEW: Suggestions Logic
  void _onSearchQueryChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      setState(() {
        _isSuggesting = false;
        _songSuggestions = [];
        _albumSuggestions = [];
        _artistSuggestions = [];
      });
      return;
    }

    // Passively switch to suggestion mode if not already
    setState(() => _isSuggesting = true);

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoadingSuggestions = true);

      try {
        final results = await HybridService.searchAll(query, limit: 5);
        if (mounted && _isSuggesting) {
          setState(() {
            _songSuggestions = (results['songs'] as List?)?.cast<SongMetadata>() ?? <SongMetadata>[];
            _albumSuggestions = (results['albums'] as List?)?.cast<AlbumModel>() ?? <AlbumModel>[];
            _artistSuggestions = (results['artists'] as List?)?.cast<ArtistModel>() ?? <ArtistModel>[];
            _isLoadingSuggestions = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingSuggestions = false);
      }
    });
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

    // 🚀 Show loading state
    setState(() {
      _currentStatus = _l10n.searchingSpotifyFor(keyword);
      _isLoadingSuggestions = true;
      _isSuggesting = true; // Keep suggestion list visible
    });

    try {
      // 🚀 Use searchAll to get Songs, Albums, Artists (5 each)
      final results = await HybridService.searchAll(keyword, limit: 5);

      if (mounted) {
        setState(() {
          _songSuggestions = (results['songs'] as List?)?.cast<SongMetadata>() ?? <SongMetadata>[];
          _albumSuggestions = (results['albums'] as List?)?.cast<AlbumModel>() ?? <AlbumModel>[];
          _artistSuggestions = (results['artists'] as List?)?.cast<ArtistModel>() ?? <ArtistModel>[];
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
    // 🚀 NAVIGATE TO TRACK DETAIL PAGE (Replaces inline match selection)
    ref.read(navigationStackProvider.notifier).push(
          NavigationItem(
            type: NavigationType.track,
            data: metadata,
          ),
        );
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

    return _buildSearchView(context);
  }

  Widget _buildSearchView(BuildContext context) {
    final searchResults = ref.watch(downloadSearchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = Theme.of(context).colorScheme.primary;

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
              onChanged: _onSearchQueryChanged, // 🚀 Trigger suggestions
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                labelText: _l10n.songTitleKeyword,
                hintText: _l10n.searchSpotifyHint,
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
                                style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11)),
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
                                style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        );
                      },
                      loading: () => Text("${_l10n.tidalApiStatus}: ...", 
                          style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 11)),
                      error: (_, __) => Text("${_l10n.tidalApiStatus}: ${_l10n.offlineStatus}", 
                          style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.6), fontSize: 11)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 🚀 NO INTERNET CONNECTION MESSAGE
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
            // 🚀 SUGGESTIONS LIST (Overlay Behavior)
            else if (_isSuggesting)
              Expanded(
                child: _buildSuggestionsList(textColor),
              )
            else
              // 🚀 EXISTING RESULTS
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
          ..._songSuggestions.map((s) => ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(s.albumArtUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, e) => const Icon(Icons.music_note)),
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
              )),
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
