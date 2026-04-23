import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_mix_model.dart';
import '../models/song_metadata.dart';
import '../models/stat_model.dart';
import 'spotify_service.dart';
import 'deezer_service.dart';
import 'debug_log_service.dart';

/// Service to generate personalized daily mixes based on user's listening history
class DailyMixService {
  static const String _cacheKey =
      'daily_mixes_cache_v4'; // Force refresh for 6 mixes

  List<DailyMix> _cachedMixes = [];

  /// Get all daily mixes - returns cached version if fresh, otherwise generates new
  Future<List<DailyMix>> getDailyMixes(Map<String, StatEntry> stats) async {
    // 1. Try to load from in-memory cache
    if (_cachedMixes.isNotEmpty && !_cachedMixes.first.isStale) {
      return _cachedMixes;
    }

    // 2. Try to load from disk
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cacheKey);

    if (cachedJson != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(cachedJson);
        final mixes = jsonList.map((j) => DailyMix.fromJson(j)).toList();
        if (mixes.isNotEmpty && !mixes.first.isStale) {
          _cachedMixes = mixes;
          return mixes;
        }
      } catch (e) {
        DebugLogService().error("⚠️ DailyMixes: Failed to parse cache: $e");
      }
    }

    // 3. Generate new mixes
    return await _generateAllMixes(stats, prefs);
  }

  /// Force refresh all mixes
  Future<List<DailyMix>> refreshMixes(Map<String, StatEntry> stats) async {
    final prefs = await SharedPreferences.getInstance();
    return await _generateAllMixes(stats, prefs);
  }

  /// Generate all 6 daily mixes
  Future<List<DailyMix>> _generateAllMixes(
    Map<String, StatEntry> stats,
    SharedPreferences prefs,
  ) async {
    // Get top 30 artists to distribute across 6 mixes (5 artists per mix)
    final allTopArtists = _getTopArtists(stats, limit: 30);

    if (allTopArtists.isEmpty) {
      DebugLogService().info("⚠️ DailyMixes: No listening history yet");
      return [];
    }

    final List<DailyMix> mixes = [];

    // Generate up to 6 mixes
    for (int i = 0; i < 6; i++) {
      // Calculate start index for this mix (0, 5, 10, 15, 20, 25)
      final startIndex = i * 5;

      // Stop if we run out of artists
      if (startIndex >= allTopArtists.length) break;

      // Take next 5 artists
      final mixArtists = allTopArtists.skip(startIndex).take(5).toList();

      // We need at least 1 artist to make a mix
      if (mixArtists.isNotEmpty) {
        final mixNumber = i + 1;
        final mix = await _generateMix(
          mixNumber: mixNumber,
          artists: mixArtists,
          title: 'Daily Mix $mixNumber',
        );
        if (mix != null) mixes.add(mix);
      }
    }

    // Cache all mixes
    if (mixes.isNotEmpty) {
      _cachedMixes = mixes;
      await prefs.setString(
        _cacheKey,
        jsonEncode(mixes.map((m) => m.toJson()).toList()),
      );
    }

    return mixes;
  }

  /// Generate a single mix for given artists
  Future<DailyMix?> _generateMix({
    required int mixNumber,
    required List<String> artists,
    required String title,
  }) async {
    // Get Spotify artist IDs
    final artistIds = <String>[];
    for (final artistName in artists) {
      final id = await SpotifyService.getArtistId(artistName: artistName);
      if (id != null) {
        artistIds.add(id);
      }
    }

    if (artistIds.isEmpty) {
      return null;
    }

    // Try recommendations API first
    var tracks = await SpotifyService.getRecommendations(
      seedArtists: artistIds.take(5).toList(),
      limit: 30,
    );

    // Fallback to track search if recommendations fail
    if (tracks.isEmpty) {
      tracks = await _getFallbackTracks(artists);
    }

    if (tracks.isEmpty) {
      return null;
    }

    return DailyMix(
      id: 'daily_mix_${mixNumber}_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description:
          artists.take(2).join(', ') + (artists.length > 2 ? ' and more' : ''),
      songs: tracks,
      generatedAt: DateTime.now(),
      seedArtists: artists,
    );
  }

  /// Fallback: Search for top tracks by each artist
  Future<List<SongMetadata>> _getFallbackTracks(List<String> artists) async {
    final List<SongMetadata> allTracks = [];
    final Set<String> seenTracks = {};

    for (final artist in artists) {
      try {
        List<SongMetadata> tracks = [];
        try {
          tracks = await SpotifyService.searchTracks('artist:$artist');
        } catch (e) {
          DebugLogService().error("⚠️ Spotify error searching for $artist: $e");
        }

        if (tracks.isEmpty) {
          try {
            tracks = await DeezerService.searchSongs('artist:"$artist"');
          } catch (e) {
            DebugLogService().error("⚠️ Deezer error searching for $artist: $e");
          }
        }

        for (final track in tracks.take(10)) {
          final key = '${track.title}_${track.artist}'.toLowerCase();
          if (!seenTracks.contains(key)) {
            seenTracks.add(key);
            allTracks.add(track);
          }
        }
      } catch (e) {
        DebugLogService().error("⚠️ Error searching for $artist: $e");
      }
    }

    allTracks.shuffle();
    return allTracks.take(30).toList();
  }

  /// Extract top artists from user's stats by play count
  List<String> _getTopArtists(Map<String, StatEntry> stats, {int limit = 5}) {
    if (stats.isEmpty) return [];

    final artistPlayCounts = <String, int>{};

    for (final entry in stats.values) {
      if (entry.playCount > 0) {
        final artist = entry.artist.trim();
        if (artist.isNotEmpty && artist != 'Unknown') {
          final artists = artist
              .split(RegExp(r'[,&]'))
              .map((a) => a.trim())
              .where((a) => a.isNotEmpty);
          for (final a in artists) {
            artistPlayCounts[a] = (artistPlayCounts[a] ?? 0) + entry.playCount;
          }
        }
      }
    }

    final sortedArtists = artistPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedArtists.take(limit).map((e) => e.key).toList();
  }

  /// Clear the cache
  Future<void> clearCache() async {
    _cachedMixes = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    print("🗑️ DailyMixes: Cache cleared");
  }
}
