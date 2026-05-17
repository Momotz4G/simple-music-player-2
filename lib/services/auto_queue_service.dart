import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/song_model.dart';
import '../models/song_metadata.dart';
import 'spotify_service.dart';

/// Service for managing the Endless Queue feature.
/// Primary: YouTube Music's "Up Next" radio algorithm (better variety).
/// Fallback: Spotify recommendations (if YT Music fails).
class AutoQueueService {
  // Cache to avoid duplicate recommendations in a session
  final Set<String> _recentlyRecommended = {};

  // Debounce flag to prevent multiple simultaneous fetches
  bool _isFetching = false;

  // Last fetch time for rate limiting
  DateTime? _lastFetchTime;
  static const Duration _minFetchInterval = Duration(seconds: 10);

  // YT Music API base URL
  static const String _ytMusicApiBase = 'https://ytmusic-api-omega.vercel.app';

  AutoQueueService();

  /// Fetches recommended songs based on the current song.
  /// Strategy: YouTube Music radio (primary) → Spotify (fallback)
  Future<List<SongModel>> getRecommendedSongs(SongModel currentSong) async {
    // Rate limiting
    if (_isFetching) {
      debugPrint("⏳ AutoQueue: Already fetching, skipping...");
      return [];
    }

    if (_lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _minFetchInterval) {
      debugPrint("⏳ AutoQueue: Rate limited, skipping...");
      return [];
    }

    _isFetching = true;
    _lastFetchTime = DateTime.now();

    try {
      // 🚀 PRIMARY: YouTube Music radio (better variety, YouTube's algorithm)
      final ytSongs = await _getYouTubeMusicRadio(currentSong);
      if (ytSongs.isNotEmpty) {
        debugPrint(
            "✅ AutoQueue [YT Music]: Got ${ytSongs.length} recommendations for '${currentSong.title}'");
        return ytSongs;
      }

      // 🚀 FALLBACK: Spotify recommendations
      debugPrint(
          "⚠️ AutoQueue: YT Music failed, falling back to Spotify for '${currentSong.title}'");
      final spotifySongs = await _getSpotifyRecommendations(currentSong);
      if (spotifySongs.isNotEmpty) {
        debugPrint(
            "✅ AutoQueue [Spotify]: Got ${spotifySongs.length} recommendations for '${currentSong.title}'");
      }
      return spotifySongs;
    } finally {
      _isFetching = false;
    }
  }

  /// YouTube Music radio: Uses get_watch_playlist for "Up Next" recommendations.
  /// This is the same algorithm YouTube Music uses when you play a song.
  Future<List<SongModel>> _getYouTubeMusicRadio(SongModel currentSong) async {
    try {
      // Step 1: Find the videoId for the current song
      String? videoId = await _searchYouTubeMusicVideoId(currentSong);
      if (videoId == null) {
        debugPrint(
            "⚠️ AutoQueue [YT Music]: Could not find videoId for '${currentSong.title}'");
        return [];
      }

      // Step 2: Get the radio/watch playlist (YouTube's "Up Next")
      final radioUrl =
          Uri.parse('$_ytMusicApiBase/api/radio?videoId=$videoId&limit=25');
      final response = await http.get(radioUrl).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode != 200) {
        debugPrint(
            "⚠️ AutoQueue [YT Music]: Radio API returned ${response.statusCode}");
        return [];
      }

      final body = json.decode(response.body);
      if (body['success'] != true || body['data'] == null) {
        return [];
      }

      final data = body['data'] as Map<String, dynamic>;
      final tracks = data['tracks'] as List<dynamic>? ?? [];

      // Debug: Log first track structure to diagnose field names
      if (tracks.isNotEmpty) {
        debugPrint(
            "🔍 AutoQueue [YT Music]: First track keys: ${(tracks[0] as Map<String, dynamic>).keys.toList()}");
        final firstTrack = tracks[0] as Map<String, dynamic>;
        debugPrint(
            "🔍 AutoQueue [YT Music]: duration=${firstTrack['duration']}, duration_seconds=${firstTrack['duration_seconds']}, length=${firstTrack['length']}");
        debugPrint(
            "🔍 AutoQueue [YT Music]: thumbnails=${firstTrack['thumbnails']}");
      }

      // Convert to SongModels, filtering duplicates (cap at 25)
      final songs = <SongModel>[];
      for (final track in tracks) {
        if (songs.length >= 25) break;

        final title = track['title'] as String? ?? '';
        final artists = track['artists'] as List<dynamic>? ?? [];
        final artist = artists.isNotEmpty
            ? artists.map((a) => a['name'] as String? ?? '').join(', ')
            : 'Unknown Artist';

        // Skip the current song
        if (title.toLowerCase() == currentSong.title.toLowerCase() &&
            artist.toLowerCase() == currentSong.artist.toLowerCase()) {
          continue;
        }

        // Skip recently recommended
        final key = "${title.toLowerCase()}_${artist.toLowerCase()}";
        if (_recentlyRecommended.contains(key)) continue;
        _recentlyRecommended.add(key);

        // Album
        final albumData = track['album'] as Map<String, dynamic>?;
        final album = albumData?['name'] as String? ?? '';

        // Duration: try duration_seconds first, then length string, then duration string
        int durationSeconds = 0;
        if (track['duration_seconds'] != null) {
          final ds = track['duration_seconds'];
          durationSeconds = (ds is int) ? ds : int.tryParse(ds.toString()) ?? 0;
        }
        if (durationSeconds == 0 && track['length'] != null) {
          final len = track['length'];
          if (len is int) {
            durationSeconds = len ~/ 1000; // milliseconds
          } else if (len is String) {
            durationSeconds = _parseDuration(len); // "3:13" format
          }
        }
        if (durationSeconds == 0 && track['duration'] != null) {
          final dur = track['duration'];
          if (dur is int) {
            durationSeconds = dur;
          } else if (dur is String) {
            durationSeconds = _parseDuration(dur);
          }
        }

        // Thumbnail — try 'thumbnail' (singular from watch_playlist) then 'thumbnails' (plural)
        String? artUrl;
        final thumbnail = track['thumbnail'];
        if (thumbnail is List && thumbnail.isNotEmpty) {
          artUrl = thumbnail.last['url'] as String?;
        } else if (thumbnail is Map) {
          // Sometimes thumbnail is a single object with 'url'
          artUrl = thumbnail['url'] as String?;
        } else if (thumbnail is String) {
          artUrl = thumbnail;
        }
        // Fallback to thumbnails (plural)
        if (artUrl == null) {
          final thumbnails = track['thumbnails'] as List<dynamic>? ?? [];
          if (thumbnails.isNotEmpty) {
            artUrl = thumbnails.last['url'] as String?;
          }
        }
        // Fallback to album thumbnail
        if (artUrl == null && albumData != null) {
          final albumThumbs = albumData['thumbnails'] as List<dynamic>? ?? [];
          if (albumThumbs.isNotEmpty) {
            artUrl = albumThumbs.last['url'] as String?;
          }
        }

        // Video ID for source URL (only used as fallback if Tidal streaming fails)
        // Don't set sourceUrl to YouTube URL — this allows Tidal JIT streaming (lossless)
        // The YouTube URL is only needed if Tidal can't find the song
        final trackVideoId = track['videoId'] as String?;

        songs.add(SongModel(
          title: title,
          artist: artist,
          album: album,
          filePath:
              "", // Will be resolved via Tidal JIT stream or YouTube cache
          fileExtension: "mp3",
          duration: durationSeconds.toDouble(),
          onlineArtUrl: artUrl,
          sourceUrl: trackVideoId != null
              ? 'query: $artist - $title'
              : null, // Use query format (not youtube URL) so Tidal is tried first
        ));
      }

      // Limit cache size
      if (_recentlyRecommended.length > 200) {
        _recentlyRecommended.clear();
      }

      return songs;
    } catch (e) {
      debugPrint("⚠️ AutoQueue [YT Music]: Error: $e");
      return [];
    }
  }

  /// Search YouTube Music for a song's videoId
  Future<String?> _searchYouTubeMusicVideoId(SongModel song) async {
    try {
      final query = Uri.encodeComponent('${song.artist} ${song.title}');
      final searchUrl =
          Uri.parse('$_ytMusicApiBase/api/search?q=$query&limit=3');
      final response = await http.get(searchUrl).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) return null;

      final body = json.decode(response.body);
      if (body['success'] != true || body['data'] == null) return null;

      final results = body['data'] as List<dynamic>;
      if (results.isEmpty) return null;

      // Return the first result's videoId
      return results[0]['videoId'] as String?;
    } catch (e) {
      debugPrint("⚠️ AutoQueue [YT Music]: Search failed: $e");
      return null;
    }
  }

  /// Parse duration string like "3:45" to seconds
  int _parseDuration(String duration) {
    final parts = duration.split(':');
    if (parts.length == 2) {
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }
    if (parts.length == 3) {
      return (int.tryParse(parts[0]) ?? 0) * 3600 +
          (int.tryParse(parts[1]) ?? 0) * 60 +
          (int.tryParse(parts[2]) ?? 0);
    }
    return 0;
  }

  /// Spotify fallback: Uses Spotify's recommendation API
  Future<List<SongModel>> _getSpotifyRecommendations(
      SongModel currentSong) async {
    try {
      String? trackId = currentSong.spotifyId;
      String? artistId = currentSong.spotifyArtistId;

      // Look up Spotify IDs if not present
      trackId ??= await SpotifyService.getTrackId(
        currentSong.title,
        currentSong.artist,
      );

      if (trackId == null && artistId == null) {
        artistId = await SpotifyService.getArtistId(
          artistName: currentSong.artist,
          trackTitle: currentSong.title,
        );
      }

      if (trackId == null && artistId == null) {
        artistId = await SpotifyService.getArtistId(
          artistName: currentSong.artist,
        );
      }

      if (trackId == null && artistId == null) return [];

      List<SongMetadata> recommendations =
          await SpotifyService.getRecommendations(
        seedTracks: trackId != null ? [trackId] : null,
        seedArtists: artistId != null ? [artistId] : null,
        limit: 20,
      );

      // Filter duplicates and current song
      recommendations = recommendations
          .where((meta) {
            final key =
                "${meta.title.toLowerCase()}_${meta.artist.toLowerCase()}";
            if (_recentlyRecommended.contains(key)) return false;
            _recentlyRecommended.add(key);
            return true;
          })
          .where((meta) =>
              meta.title.toLowerCase() != currentSong.title.toLowerCase() ||
              meta.artist.toLowerCase() != currentSong.artist.toLowerCase())
          .toList();

      if (_recentlyRecommended.length > 200) {
        _recentlyRecommended.clear();
      }

      return recommendations.map((meta) => _metadataToSongModel(meta)).toList();
    } catch (e) {
      debugPrint("⚠️ AutoQueue [Spotify]: Error: $e");
      return [];
    }
  }

  /// Convert SongMetadata to SongModel for playback
  SongModel _metadataToSongModel(SongMetadata meta) {
    return SongModel(
      title: meta.title,
      artist: meta.artist,
      album: meta.album,
      filePath: "", // Will be JIT cached when playing
      fileExtension: "mp3",
      duration: meta.durationSeconds.toDouble(),
      onlineArtUrl: meta.albumArtUrl,
      isrc: meta.isrc,
      spotifyId: meta.spotifyId,
      spotifyArtistId: meta.spotifyArtistId,
      trackNumber: meta.trackNumber,
      discNumber: meta.discNumber,
      year: meta.year,
      genre: meta.genre,
    );
  }

  /// Reset the recommendation cache (call when starting new playlist)
  void resetCache() {
    _recentlyRecommended.clear();
    debugPrint("🔄 AutoQueue: Cache cleared");
  }

  /// Check if we should fetch more recommendations
  bool shouldFetchMore(int remainingInQueue) {
    return remainingInQueue < 3;
  }
}
