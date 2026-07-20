import 'package:flutter/foundation.dart';
import '../models/song_metadata.dart';
import '../models/album_model.dart';

import '../models/artist_model.dart';
import '../services/spotify_service.dart';
import '../services/deezer_service.dart';
import '../services/itunes_api_service.dart';
import '../providers/settings_provider.dart';

class HybridService {
  /// Search for songs. Tries Spotify first, falls back to Deezer.
  static Future<List<SongMetadata>> searchSongs(String query,
      {int limit = 10}) async {
    try {
      // Use searchMetadata to avoid N+1 genre lookups that trigger rate limits

      final maps = await SpotifyService.searchMetadata(query);
      return maps
          .map((m) => SongMetadata(
                title: m['title'],
                artist: m['artist'],
                album: m['album'],
                durationSeconds: (m['duration_ms'] as int) ~/ 1000,
                albumArtUrl: m['image_url'] ?? "",
                spotifyId: m['spotify_id'],
                isrc: m['isrc'],
                trackNumber: m['track_number'],
                discNumber: m['disc_number'],
                genre: "",
                year: m['year'].toString(),
              ))
          .toList();
    } catch (e) {
      if (e.toString().contains("rate_limit_429") ||
          e.toString().contains("Auth Failed")) {
        debugPrint("⚠️ Spotify Rate Limit Hit! Falling back to Deezer...");
        return await DeezerService.searchSongs(query, limit: limit);
      }
      debugPrint(
          "HybridService: Spotify Error $e. (Not Rate Limit). Falling back anyway for robustness.");
      return await DeezerService.searchSongs(query, limit: limit);
    }
  }

  /// Search Metadata with Fallback (For Editor)
  static Future<List<Map<String, dynamic>>> searchMetadata(String query, {int limit = 10}) async {
    try {
      return await SpotifyService.searchMetadata(query);
    } catch (e) {
      debugPrint("HybridService: Spotify Metadata Search Error $e. Falling back to Deezer...");
      final songs = await DeezerService.searchSongs(query, limit: limit);
      return songs.map((s) => {
        'title': s.title,
        'artist': s.artist,
        'album': s.album,
        'year': s.year,
        'image_url': s.albumArtUrl,
        'spotify_id': s.spotifyId,
        'duration_ms': s.durationSeconds * 1000,
        'track_number': s.trackNumber,
        'disc_number': s.discNumber,
        'isrc': s.isrc,
        'deezer_id': s.deezerId,
      }).toList();
    }
  }

  /// Search All Entities (Fallback support)
  static Future<Map<String, dynamic>> searchAll(String query,
      {int limit = 5}) async {
    try {
      return await SpotifyService.searchAll(query, limit: limit);
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) {
        debugPrint(
            "HybridService: Spotify SearchAll Rate Limit! Falling back to Deezer...");
        return await DeezerService.searchAll(query, limit: limit);
      }
      // Optional: fallback on other errors too?
      debugPrint("HybridService: Spotify SearchAll Error $e. Falling back...");
      return await DeezerService.searchAll(query, limit: limit);
    }
  }

  /// Get Artist Details. Tries Spotify, falls back to Deezer.
  static Future<ArtistModel?> getArtist(String artistId,
      {String? artistName}) async {
    // Note: Spotify IDs don't work on Deezer and vice versa.
    // If we are here, we likely have a Spotify ID or a Name.
    // If we only have an ID and it fails, we can't easily fallback to Deezer using the same ID.
    // Strategy: Use Artist Name to find on Deezer if ID fails.

    // For now, let's assume if we are browsing an Artist Page, we might have come from a Search.
    // If the Search came from Spotify, we have a Spotify ID.
    // If the Search came from Deezer, we have a Deezer ID.
    // This method signature might need to change to accept the "Source" or just try both.

    // But wait, the app stores "spotifyArtistId".
    // If we try to fetch by ID and it fails, we need the Name to switch to Deezer.
    // If we don't have the name, we are stuck.

    // Simple approach: Expect Caller to ideally provide Name.

    if (artistName == null) {
      // We only have ID. Try Spotify.
      // If fail, we can't switch to Deezer without name.
      // Unless we guess or stored it.
      // Assume ID is Spotify ID.
    }

    try {
      // Try Spotify Info (which returns image mainly)
      // SpotifyService.getArtistImage returns String?, not Model.
      // We might need to map it.
      // Let's rely on name if possible.

      final image = await SpotifyService.getArtistImage(
          artistName: artistName ?? "Unknown");
      if (image != null) {
        return ArtistModel(
            id: artistId, name: artistName ?? "Unknown", imageUrl: image);
      }
    } catch (e) {
      debugPrint("HybridService: Spotify Artist Error $e");
    }

    // Fallback to Deezer Search by Name
    if (artistName != null) {
      return await DeezerService.getArtist(artistName);
    }

    return null;
  }

  static Future<List<SongMetadata>> getArtistTopTracks(
      String artistName, {SearchEngine? engine}) async {
    // Strategy: Try to find artist ID on Spotify via Name, then get Top Tracks.
    // If fail, search Artist on Deezer, get ID, then Top Tracks.

    if (engine == SearchEngine.appleMusic) {
      try {
        final itunesId = await ITunesApiService.getArtistId(artistName);
        if (itunesId != null) {
          return await ITunesApiService.getArtistTopTracks(itunesId);
        }
      } catch (e) {
        debugPrint("HybridTopTracks: iTunes failed ($e), falling back to Spotify...");
      }
    }

    try {
      final spotifyId =
          await SpotifyService.getArtistId(artistName: artistName);
      if (spotifyId != null) {
        return await SpotifyService.getArtistTopTracks(spotifyId);
      }
    } catch (e) {
      debugPrint("HybridTopTracks: Spotify failed ($e), trying Deezer...");
    }

    // Fallback
    final deezerArtist = await DeezerService.getArtist(artistName);
    if (deezerArtist != null) {
      return await DeezerService.getArtistTopTracks(deezerArtist.id);
    }
    return <SongMetadata>[];
  }

  // --- NEW METHODS ---

  static Future<List<Map<String, dynamic>>> getNewReleases(
      {String market = 'US'}) async {
    try {
      return await SpotifyService.getNewReleases(market: market);
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) {
        return await DeezerService.getNewReleases();
      }
    }
    // Try fallback anyway on error
    try {
      return await DeezerService.getNewReleases();
    } catch (e) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<List<SongMetadata>> getAlbumTracks(String albumId) async {
    // NOTE: Spotify Album ID != Deezer Album ID.
    // If we are here, we likely have an ID.
    // If it's a Spotify ID and it fails, we cannot guess the Deezer ID easily without searching the Album Name.
    // But we don't have the Album Name passed here!
    // This suggests we need to change how we call this.

    // However, if the Album object itself was retrieved via HybridService, it might have both IDs?
    // Or we just fail gracefully.

    try {
      return await SpotifyService.getAlbumTracks(albumId);
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) {
        debugPrint(
            "Hybrid: Spotify Album Tracks 429. Cannot easily fallback without Album Name. Returning empty.");
        // Note: Real solution requires passing Album Name or having a cross-reference.
      }
    }
    return <SongMetadata>[];
  }

  /// Get Album Tracks with Fallback Strategy requiring Album Name
  static Future<List<SongMetadata>> getAlbumTracksSafe(
      String albumId, String albumName, String artistName) async {
    try {
      return await SpotifyService.getAlbumTracks(albumId);
    } catch (e) {
      debugPrint("Hybrid: Spotify Album Tracks Error $e. Searching Deezer for '$albumName'...");
      // Fallback: Search Album on Deezer by Name + Artist
      final deezerAlbums =
          await DeezerService.searchAlbums("$albumName $artistName");
      if (deezerAlbums.isNotEmpty) {
        return await DeezerService.getAlbumTracks(deezerAlbums.first.id);
      }
    }
    return <SongMetadata>[];
  }

  static Future<List<AlbumModel>> getArtistAlbums(String artistName, {SearchEngine? engine}) async {
    if (engine == SearchEngine.appleMusic) {
      try {
        final itunesId = await ITunesApiService.getArtistId(artistName);
        if (itunesId != null) {
          return await ITunesApiService.getArtistAlbums(itunesId);
        }
      } catch (e) {
        debugPrint("HybridArtistAlbums: iTunes failed ($e), falling back to Spotify...");
      }
    }

    try {
      final spotifyId =
          await SpotifyService.getArtistId(artistName: artistName);
      if (spotifyId != null) {
        return await SpotifyService.getArtistAlbums(spotifyId);
      }
    } catch (e) {
      // Fallback
    }

    final deezerArtist = await DeezerService.getArtist(artistName);
    if (deezerArtist != null) {
      return await DeezerService.getArtistAlbums(deezerArtist.id);
    }
    return <AlbumModel>[];
  }

  static Future<List<AlbumModel>> searchAlbums(String query) async {
    try {
      return await SpotifyService.searchAlbums(query);
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) {
        return await DeezerService.searchAlbums(query);
      }
    }
    // Fallback
    return await DeezerService.searchAlbums(query);
  }

  static Future<String?> getTrackImage(String title, String artist) async {
    try {
      return await SpotifyService.getTrackImage(title, artist);
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) {
        final songs =
            await DeezerService.searchSongs("$title $artist", limit: 1);
        if (songs.isNotEmpty) return songs.first.albumArtUrl;
      }
    }
    return null;
  }

  static Future<String?> getTrackLink(String title, String artist) async {
    try {
      return await SpotifyService.getTrackLink(title, artist);
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) {
        // Deezer doesn't provide a "Spotify Link" obviously, but maybe we just return null
        // or a Deezer link if the app supports it.
        // The app uses this for 'sourceUrl'.
        // Let's return null to avoid confusion, or try to get a YouTube link if we had that service here?
        // For now, return null as strict fallback.
        return null;
      }
    }
    return null;
  }
}
