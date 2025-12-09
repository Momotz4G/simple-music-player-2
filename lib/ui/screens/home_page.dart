import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:path/path.dart' as path_lib;

// --- PROVIDERS ---
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../providers/library_presentation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../data/schemas.dart';

// --- SERVICES ---
import '../../services/spotify_service.dart';

// --- COMPONENTS ---
import '../components/horizontal_section.dart';
import '../components/horizontal_playlist_section.dart';
import '../components/rediscover_feed.dart';
import '../components/auto_scroll_section.dart';
import '../components/hero_banner.dart';

// --- MODELS ---
import '../../models/song_model.dart';
import '../../models/song_metadata.dart';
import '../../models/stat_model.dart'; // REQUIRED for ID generation

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<SongModel> _cachedDeepCuts = [];
  List<SongModel> _quickMix = [];
  bool _isMixInitialized = false;

  // New Releases for Banner
  List<Map<String, dynamic>> _newReleases = [];

  ScrollPhysics _pageScrollPhysics = const BouncingScrollPhysics();

  @override
  void initState() {
    super.initState();
    // 🚀 FIX: Pass the current market from settings
    final market = ref.read(settingsProvider).spotifyMarket;
    _loadNewReleases(market);
  }

  // 🚀 UPDATED: Accepts market parameter
  Future<void> _loadNewReleases(String market) async {
    final releases = await SpotifyService.getNewReleases(market: market);
    if (mounted) {
      setState(() {
        _newReleases = releases;
      });
    }
  }

  Future<void> _onBannerTap(Map<String, dynamic> item) async {
    // 1. Construct a query to find the specific track
    final query = "${item['artist']} ${item['title']}";

    // 2. Fetch full metadata (to get Duration, Album Name, etc.)
    final results = await SpotifyService.searchMetadata(query);

    SongMetadata meta;

    if (results.isNotEmpty) {
      // ✅ Found track details! Use real duration.
      final best = results.first;
      meta = SongMetadata(
        title: best['title'],
        artist: best['artist'],
        album: best['album'],
        year: best['year'],
        genre: "",
        durationSeconds: (best['duration_ms'] as int) ~/ 1000, // Real Duration
        albumArtUrl: best['image_url'] ?? item['image_url'],
        trackNumber: best['track_number'],
        discNumber: best['disc_number'],
      );
    } else {
      // Fallback (just in case search fails)
      meta = SongMetadata(
        title: item['title'],
        artist: item['artist'],
        album: item['title'],
        year: "",
        genre: "",
        durationSeconds: 0, // Still 0, but better than crashing
        albumArtUrl: item['image_url'],
      );
    }

    // 3. Switch to Search View & Bridge Data
    if (mounted) {
      ref
          .read(libraryPresentationProvider.notifier)
          .setView(LibraryView.search);
      ref.read(searchBridgeProvider.notifier).state = meta;
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  List<SongModel> _mapHistoryToSongs(
      List<HistoryEntry> entries, List<SongModel> librarySongs) {
    final libMap = {for (var s in librarySongs) s.filePath: s};
    final List<SongModel> result = [];

    for (var entry in entries) {
      if (libMap.containsKey(entry.originalFilePath)) {
        result.add(libMap[entry.originalFilePath]!);
        continue;
      }

      result.add(SongModel(
        title: entry.title,
        artist: entry.artist,
        album: entry.album,
        filePath: entry.originalFilePath,
        duration: entry.duration,
        fileExtension: '.mp3',
        sourceUrl: entry.youtubeUrl,
        onlineArtUrl: entry.albumArtUrl,
      ));
    }
    return result;
  }

  List<SongModel> _resolveSongs(
      List<String> paths, List<SongModel> librarySongs) {
    final List<SongModel> resolved = [];
    for (var path in paths) {
      try {
        final song = librarySongs.firstWhere((s) => s.filePath == path);
        resolved.add(song);
      } catch (e) {}
    }
    return resolved;
  }

  void _initializeDeepCuts(
      List<SongModel> allSongs, Map<String, dynamic> statsEntries) {
    if (allSongs.isEmpty || statsEntries.isEmpty) return;
    if (_cachedDeepCuts.isNotEmpty) return;

    final sortedStats = statsEntries.values.toList()
      ..sort((a, b) => (b.playCount as int).compareTo(a.playCount as int));

    final playedStats =
        sortedStats.where((e) => (e.playCount as int) > 0).toList();

    int skipCount = 0;
    if (playedStats.length > 50) {
      skipCount = 20;
    } else if (playedStats.length > 10) {
      skipCount = 5;
    } else {
      return;
    }

    final deepCutStats = playedStats.skip(skipCount).take(200).toList();
    if (deepCutStats.isEmpty) return;

    deepCutStats.shuffle();

    final selectedPaths =
        deepCutStats.take(10).map((e) => e.lastKnownPath as String).toList();

    _cachedDeepCuts = _resolveSongs(selectedPaths, allSongs);
  }

  void _generateQuickMix(List<SongModel> allSongs) {
    if (_isMixInitialized || allSongs.isEmpty) return;
    final randomMix = List<SongModel>.from(allSongs)..shuffle();
    _quickMix = randomMix.take(10).toList();
    _isMixInitialized = true;
  }

  void _setScrollLock(bool isLocked) {
    setState(() {
      _pageScrollPhysics = isLocked
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = p.Provider.of<LibraryProvider>(context);
    final allSongs = library.songs;
    _generateQuickMix(allSongs);

    final statsState = ref.watch(statsProvider);
    final historyEntries = ref.watch(historyProvider);
    final playlists = ref.watch(playlistProvider);
    final settings = ref.watch(settingsProvider); // 🚀 WATCH SETTINGS

    // 🚀 AUTO-RELOAD BANNER WHEN MARKET CHANGES
    ref.listen<String>(settingsProvider.select((s) => s.spotifyMarket),
        (previous, next) {
      _loadNewReleases(next);
    });

    final recentSongs =
        _mapHistoryToSongs(historyEntries.take(10).toList(), allSongs);

    _initializeDeepCuts(allSongs, statsState.entries);

    final topStatsEntries = statsState.entries.values.toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));

    final List<SongModel> topPlayedSongs = [];
    final libMap = {for (var s in allSongs) s.filePath: s};

    for (var stat in topStatsEntries.take(10)) {
      if (libMap.containsKey(stat.lastKnownPath)) {
        topPlayedSongs.add(libMap[stat.lastKnownPath]!);
      } else {
        topPlayedSongs.add(SongModel(
          title: stat.title,
          artist: stat.artist,
          album: stat.album,
          filePath: stat.lastKnownPath,
          duration: 0,
          fileExtension: path_lib.extension(stat.lastKnownPath),
          onlineArtUrl: stat.onlineArtUrl,
          sourceUrl: stat.youtubeUrl,
        ));
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = Theme.of(context).colorScheme.primary;

    // 🚀 BACKFILL METADATA (Automatic Restoration)
    // Combine lists to check both History and Stats
    final combinedForBackfill = [...recentSongs, ...topPlayedSongs];
    _backfillMetadata(combinedForBackfill);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: _pageScrollPhysics,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Row(
                children: [
                  Text(
                    _getGreeting(),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  // 🚀 REMOTE BUTTON MOVED TO PLAYER BAR
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      if (allSongs.isNotEmpty) {
                        ref.read(playerProvider.notifier).playRandom(allSongs);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    icon: const Icon(Icons.shuffle, size: 18),
                    label: const Text("Shuffle All"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_newReleases.isNotEmpty)
              HeroBanner(
                items: _newReleases,
                onTap: _onBannerTap,
              ),
            const SizedBox(height: 40),
            if (recentSongs.isNotEmpty)
              AutoScrollSection(
                title: "Jump Back In",
                songs: recentSongs,
                onScrollFocus: _setScrollLock,
              ),
            if (topPlayedSongs.isNotEmpty)
              AutoScrollSection(
                title: "Your Top Mix",
                songs: topPlayedSongs,
                onScrollFocus: _setScrollLock,
              ),
            if (_cachedDeepCuts.isNotEmpty)
              RediscoverFeed(
                initialPool: _cachedDeepCuts,
                allLibrarySongs: allSongs,
              ),
            if (playlists.isNotEmpty)
              HorizontalPlaylistSection(
                title: "Your Playlists",
                playlists: playlists,
                allLibrarySongs: allSongs,
                onScrollFocus: _setScrollLock,
              ),
            if (_quickMix.isNotEmpty)
              HorizontalSection(
                title: "Quick Mix",
                songs: _quickMix,
                onScrollFocus: _setScrollLock,
              ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // METADATA BACKFILL LOGIC
  final Set<String> _processedBackfill = {};

  Future<void> _backfillMetadata(List<SongModel> songs) async {
    for (var song in songs) {
      // If we already have metadata, skip
      if (song.onlineArtUrl != null && song.sourceUrl != null) continue;

      // Generate a unique ID for tracking (using StatEntry logic for consistency)
      // We can't use StatEntry.generateId directly if it's not imported or if we want to be generic.
      // But we know title/artist/album are the keys.
      final id = "${song.title}_${song.artist}_${song.album}";

      if (_processedBackfill.contains(id)) continue;
      _processedBackfill.add(id);

      // Run in background
      Future.delayed(Duration.zero, () async {
        try {
          // 1. Fetch Art
          String? artUrl = song.onlineArtUrl;
          if (artUrl == null || artUrl.isEmpty) {
            artUrl =
                await SpotifyService.getTrackImage(song.title, song.artist);
          }

          // 2. Fetch URL (Spotify Link as placeholder/source)
          String? youtubeUrl = song.sourceUrl;
          if (youtubeUrl == null || youtubeUrl.isEmpty) {
            youtubeUrl =
                await SpotifyService.getTrackLink(song.title, song.artist);
          }

          if (artUrl != null || youtubeUrl != null) {
            if (mounted) {
              // A. Update Stats (if exists)
              final statId =
                  StatEntry.generateId(song.title, song.artist, song.album);
              ref.read(statsProvider.notifier).updateMetadata(statId,
                  artUrl: artUrl, youtubeUrl: youtubeUrl);

              // B. Update History
              final history = ref.read(historyProvider);
              try {
                final entryToUpdate = history.firstWhere(
                    (e) => e.title == song.title && e.artist == song.artist);

                entryToUpdate.albumArtUrl = artUrl ?? entryToUpdate.albumArtUrl;
                entryToUpdate.youtubeUrl =
                    youtubeUrl ?? entryToUpdate.youtubeUrl;

                ref
                    .read(historyProvider.notifier)
                    .updateHistoryEntry(entryToUpdate);
              } catch (e) {
                // Not in history
              }
            }
          }
        } catch (e) {
          print("Backfill failed for ${song.title}: $e");
        }
      });
    }
  }
}
