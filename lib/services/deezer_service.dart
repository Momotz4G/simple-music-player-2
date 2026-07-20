import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_metadata.dart';

import '../models/album_model.dart';
import '../models/artist_model.dart';

class DeezerService {
  static const String _baseUrl = 'https://api.deezer.com';

  /// Search for tracks on Deezer and map to SongMetadata
  static Future<List<SongMetadata>> searchSongs(String query,
      {int limit = 10}) async {
    try {
      final uri = Uri.parse('$_baseUrl/search/track?q=$query&limit=$limit');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'] ?? [];

        return items.map<SongMetadata>((item) {
          final artist = item['artist'];
          final album = item['album'];

          return SongMetadata(
            title: item['title'],
            artist: artist['name'],
            album: album['title'],
            year:
                null, // Deezer search often omits year in simple track objects
            genre:
                "Pop", // Default, detailed genre requires extra fetch usually
            trackNumber: null,
            discNumber: null,
            durationSeconds: item['duration'],
            albumArtUrl: album['cover_xl'] ??
                album['cover_medium'] ??
                album['cover_small'],
            isrc:
                null, // Search result usually lacks ISRC, needs detailed fetch if critical
            spotifyId: null, // It's Deezer
            deezerId: item['id'].toString(), // CAPTURE DEEZER ID
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Deezer Search Error: $e");
    }
    return <SongMetadata>[];
  }

  /// Helper to get the best track image URL from Deezer
  static Future<String?> getTrackImage(String title, String artist) async {
    try {
      final query = Uri.encodeComponent('$title $artist');
      final results = await searchSongs(query, limit: 1);
      if (results.isNotEmpty && results.first.albumArtUrl.isNotEmpty) {
        return results.first.albumArtUrl;
      }
    } catch (e) {
      debugPrint("Deezer getTrackImage Error: $e");
    }
    return null;
  }

  /// Get Artist Info
  static Future<ArtistModel?> getArtist(String artistName) async {
    try {
      final uri = Uri.parse('$_baseUrl/search/artist?q=$artistName&limit=1');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'];
        if (items.isNotEmpty) {
          final item = items[0];
          return ArtistModel(
            id: item['id'].toString(),
            name: item['name'],
            imageUrl: item['picture_xl'] ?? item['picture_medium'] ?? "",
          );
        }
      }
    } catch (e) {
      debugPrint("Deezer Artist Error: $e");
    }
    return null;
  }

  /// Get Artist Info by ID
  static Future<ArtistModel?> getArtistById(String artistId) async {
    try {
      final uri = Uri.parse('$_baseUrl/artist/$artistId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) return null;

        return ArtistModel(
          id: data['id'].toString(),
          name: data['name'],
          imageUrl: data['picture_xl'] ?? data['picture_medium'] ?? "",
        );
      }
    } catch (e) {
      debugPrint("Deezer Artist ID Error: $e");
    }
    return null;
  }

  /// Get Song details by ID (includes ISRC)
  static Future<SongMetadata?> getTrack(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/track/$id');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) return null;

        return SongMetadata(
          title: data['title'],
          artist: data['artist']['name'],
          album: data['album']['title'],
          durationSeconds: data['duration'],
          albumArtUrl:
              data['album']['cover_xl'] ?? data['album']['cover_medium'] ?? "",
          trackNumber: data['track_position'],
          discNumber: data['disk_number'],
          genre: "Pop", // Detailed genre might be available in 'genres'
          year: data['release_date']?.split('-')?.first ?? "",
          isrc: data['isrc'],
          spotifyId: null,
          deezerId: data['id'].toString(), // CAPTURE DEEZER ID
        );
      }
    } catch (e) {
      debugPrint("Deezer Track Error: $e");
    }
    return null;
  }

  /// Search by ISRC
  static Future<SongMetadata?> searchByIsrc(String isrc) async {
    try {
      // Deezer supports ISRC lookup via /track/isrc:CODE
      final uri = Uri.parse('$_baseUrl/track/isrc:$isrc');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) return null;

        return SongMetadata(
          title: data['title'],
          artist: data['artist']['name'],
          album: data['album']['title'],
          durationSeconds: data['duration'],
          albumArtUrl:
              data['album']['cover_xl'] ?? data['album']['cover_medium'] ?? "",
          trackNumber: data['track_position'],
          discNumber: data['disk_number'],
          genre: "Pop",
          year: data['release_date']?.split('-')?.first ?? "",
          isrc: data['isrc'],
          spotifyId: null,
          deezerId: data['id'].toString(), // CAPTURE DEEZER ID
        );
      }
    } catch (e) {
      debugPrint("Deezer ISRC Search Error: $e");
    }
    return null;
  }

  /// Get Album Tracks
  static Future<List<SongMetadata>> getAlbumTracks(String albumId) async {
    try {
      final uri = Uri.parse('$_baseUrl/album/$albumId/tracks?limit=50');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'];

        // Need to fetch album details separately to get year/cover if not provided in track list
        // But usually track list has simplified objects.
        // For speed, let's assume we have what we need or minimal.

        return items.map<SongMetadata>((item) {
          return SongMetadata(
            title: item['title_short'] ?? item['title'],
            artist: item['artist']['name'],
            album:
                "", // Track list inside album often hides album name, caller usually knows it
            durationSeconds: item['duration'],
            albumArtUrl: "", // Caller handles cover usually
            trackNumber: item['track_position'],
            discNumber: item['disk_number'],
            genre: "Pop",
            year: "",
            isrc: item['isrc'], // Deezer album tracks often HAVE ISRC
            deezerId: item['id'].toString(), // CAPTURE DEEZER ID
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Deezer Album Tracks Error: $e");
    }
    return <SongMetadata>[];
  }

  /// Get Artist Top Tracks
  static Future<List<SongMetadata>> getArtistTopTracks(String artistId) async {
    try {
      final uri = Uri.parse('$_baseUrl/artist/$artistId/top?limit=10');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'] ?? [];

        return items.map<SongMetadata>((item) {
          final album = item['album'];

          return SongMetadata(
            title: item['title_short'] ?? item['title'],
            artist: item['artist']['name'],
            album: album['title'],
            durationSeconds: item['duration'],
            albumArtUrl: album['cover_xl'] ?? album['cover_medium'] ?? "",
            trackNumber: 0,
            discNumber: 0,
            genre: "Pop",
            year: "",
            deezerId: item['id'].toString(), // CAPTURE DEEZER ID
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Deezer Top Tracks Error: $e");
    }
    return <SongMetadata>[];
  }

  /// Search All (Tracks, Albums, Artists) - Parallel Fetch
  static Future<Map<String, dynamic>> searchAll(String query,
      {int limit = 5}) async {
    try {
      final futures = await Future.wait([
        searchSongs(query, limit: limit),
        _searchAlbums(query, limit: limit),
        _searchArtists(query, limit: limit),
      ]);

      return {
        'songs': futures[0],
        'albums': futures[1],
        'artists': futures[2],
      };
    } catch (e) {
      debugPrint("Deezer Search All Error: $e");
    }
    return {'songs': [], 'albums': [], 'artists': []};
  }

  static Future<List<AlbumModel>> _searchAlbums(String query,
      {int limit = 5}) async {
    return searchAlbums(query, limit: limit);
  }

  /// Public Search Albums
  static Future<List<AlbumModel>> searchAlbums(String query,
      {int limit = 5}) async {
    try {
      final uri = Uri.parse('$_baseUrl/search/album?q=$query&limit=$limit');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'] ?? [];
        return items.map<AlbumModel>((item) {
          return AlbumModel(
            id: item['id'].toString(),
            title: item['title'],
            artist: item['artist']['name'],
            imageUrl: item['cover_xl'] ?? item['cover_medium'] ?? "",
            releaseDate: "", // Generic search might miss this
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Deezer Search Albums Error: $e");
    }
    return <AlbumModel>[];
  }

  /// Get Artist Albums
  static Future<List<AlbumModel>> getArtistAlbums(String artistId) async {
    try {
      final uri = Uri.parse('$_baseUrl/artist/$artistId/albums?limit=20');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'] ?? [];

        return items.map<AlbumModel>((item) {
          return AlbumModel(
            id: item['id'].toString(),
            title: item['title'],
            artist: "", // Often implied
            imageUrl: item['cover_xl'] ?? item['cover_medium'] ?? "",
            releaseDate: item['release_date'] ?? "",
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Deezer Artist Albums Error: $e");
    }
    return <AlbumModel>[];
  }

  /// Get Chart / New Releases
  static Future<List<Map<String, dynamic>>> getNewReleases() async {
    try {
      // Deezer Chart
      final uri = Uri.parse('$_baseUrl/chart/0/tracks?limit=10');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'] ?? [];

        return items.map<Map<String, dynamic>>((item) {
          return {
            'title': item['title'],
            'artist': item['artist']['name'],
            'image_url':
                item['album']['cover_xl'] ?? item['album']['cover_medium'],
            'id': item['id'].toString(),
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Deezer Chart Error: $e");
    }
    return <Map<String, dynamic>>[];
  }

  static Future<List<ArtistModel>> _searchArtists(String query,
      {int limit = 5}) async {
    // Reuse basic logic but return list
    try {
      final uri = Uri.parse('$_baseUrl/search/artist?q=$query&limit=$limit');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'] ?? [];
        return items.map<ArtistModel>((item) {
          return ArtistModel(
            id: item['id'].toString(),
            name: item['name'],
            imageUrl: item['picture_xl'] ?? item['picture_medium'] ?? "",
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Deezer Search Artists Error: $e");
    }
    return <ArtistModel>[];
  }
}

final deezerArtistArtProvider =
    FutureProvider.family<String?, String>((ref, name) async {
  final artist = await DeezerService.getArtist(name);
  return artist?.imageUrl;
});
