import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'spotify_service.dart';
import '../env/env.dart';

class SpotifyLyricsService {
  static String get _baseUrl => Env.externalLyricsUrl;

  /// Fetches Spotify lyrics (which are officially powered by Musixmatch).
  /// Returns the raw LRC string if found, otherwise returns null.
  static Future<String?> fetchSpotifyLyrics(String title, String artist) async {
    try {
      debugPrint(
          ' [SpotifyLyrics] Fetching Spotify lyrics for: $title - $artist');

      // 1. Search for the track ID
      final query = Uri.encodeComponent('$title $artist');
      final searchUrl = Uri.parse('$_baseUrl/spotify/search?q=$query');

      final searchRes =
          await http.get(searchUrl).timeout(const Duration(seconds: 15));
      if (searchRes.statusCode != 200) {
        debugPrint(
            ' [SpotifyLyrics] Spotify search failed: ${searchRes.statusCode}');
        return null;
      }

      final searchData = json.decode(searchRes.body) as List<dynamic>;
      if (searchData.isEmpty) {
        debugPrint(
            ' [SpotifyLyrics] No Spotify tracks found for: $title - $artist');
        return null;
      }

      // Get the first result's trackId
      final trackId = searchData[0]['trackId'] as String?;
      if (trackId == null) return null;

      debugPrint(' [SpotifyLyrics] Found Spotify track ID: $trackId');

      // 2. Fetch lyrics using the track ID
      final lyricsUrl = Uri.parse('$_baseUrl/spotify/lyrics?id=$trackId');
      final lyricsRes =
          await http.get(lyricsUrl).timeout(const Duration(seconds: 15));

      if (lyricsRes.statusCode == 200) {
        // The Spotify endpoint returns the raw LRC string encoded as JSON (e.g. "[00:09.87]...")
        final rawLrc = json.decode(lyricsRes.body);

        if (rawLrc is String && rawLrc.trim().isNotEmpty) {
          debugPrint(' [SpotifyLyrics] Spotify lyrics fetched successfully');
          return rawLrc;
        }
      }

      debugPrint(
          ' [SpotifyLyrics] Spotify lyrics fetch failed: ${lyricsRes.statusCode}');
      return null;
    } catch (e) {
      debugPrint('💥 [SpotifyLyrics] Spotify lyrics exception: $e');
      return null;
    }
  }

  /// Fetches Musixmatch lyrics directly.
  /// Note: The endpoint might return a JSON error if their proxy is down,
  /// which this function will safely catch.
  static Future<String?> fetchMusixmatchLyrics(
      String title, String artist) async {
    try {
      debugPrint(
          ' [SpotifyLyrics] Fetching Musixmatch lyrics for: $title - $artist');

      final query = Uri.encodeComponent('$title $artist');
      final url = Uri.parse('$_baseUrl/musixmatch/lyrics?q=$query');

      final res = await http.get(url).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        // Handle server-side errors
        if (data is Map && data['isError'] == true) {
          debugPrint(
              ' [SpotifyLyrics] Musixmatch proxy error: ${data['error']}');
          return null;
        }

        if (data is String) {
          return data;
        } else if (data is Map) {
          final lrc = data['lyrics'] ?? data['lrc'] ?? data['syncedLyrics'];
          if (lrc is String && lrc.trim().isNotEmpty) {
            debugPrint(
                ' [SpotifyLyrics] Musixmatch lyrics fetched successfully');
            return lrc;
          }
        }
      }

      debugPrint(
          ' [SpotifyLyrics] Musixmatch lyrics fetch failed: ${res.statusCode}');
      return null;
    } catch (e) {
      debugPrint('💥 [SpotifyLyrics] Musixmatch lyrics exception: $e');
      return null;
    }
  }

  /// Fetches the Spotify Home page payload and extracts the first featured section
  /// to be used for the Home Page Banner.
  static Future<List<Map<String, dynamic>>> fetchSpotifyHomeBanner() async {
    try {
      debugPrint(' [SpotifyLyrics] Fetching Spotify Home Banner');
      final url = Uri.parse('$_baseUrl/spotify/home');

      final res = await http.get(url).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint(
            ' [SpotifyLyrics] Spotify Home fetch failed: ${res.statusCode}');
        return [];
      }

      final data = json.decode(res.body);

      // Traverse JSON: data -> home -> sectionContainer -> sections -> items
      final homeData = data['data']?['home'];
      if (homeData == null) return [];

      final sections =
          homeData['sectionContainer']?['sections']?['items'] as List<dynamic>?;
      if (sections == null || sections.isEmpty) return [];

      // Find the first section that contains items
      for (final section in sections) {
        final sectionItems =
            section['sectionItems']?['items'] as List<dynamic>?;
        if (sectionItems != null && sectionItems.isNotEmpty) {
          List<Map<String, dynamic>> bannerItems = [];

          for (final item in sectionItems) {
            try {
              final contentData = item['content']?['data'];
              if (contentData == null) continue;

              final uri = item['uri'] as String? ?? '';
              if (!uri.startsWith('spotify:track:') &&
                  !uri.startsWith('spotify:album:')) {
                continue;
              }

              final title = contentData['name'] ?? '';

              // Extract artist
              String artist = 'Unknown Artist';
              final artistsItems =
                  contentData['artists']?['items'] as List<dynamic>?;
              if (artistsItems != null && artistsItems.isNotEmpty) {
                artist = artistsItems
                    .map((a) => a['profile']?['name'] ?? '')
                    .where((n) => n.toString().isNotEmpty)
                    .join(', ');
              }

              // Extract image
              String imageUrl = '';
              final coverArtSources = contentData['albumOfTrack']?['coverArt']
                      ?['sources'] ??
                  contentData['coverArt']?['sources'];
              if (coverArtSources != null &&
                  coverArtSources is List &&
                  coverArtSources.isNotEmpty) {
                // Get the highest resolution image (usually the last or first, let's just grab the first valid one, or sort by width)
                imageUrl = coverArtSources[0]['url'] ?? '';
              }

              if (title.isNotEmpty && imageUrl.isNotEmpty) {
                bannerItems.add({
                  'title': title,
                  'artist': artist,
                  'image_url': imageUrl,
                  'uri': uri,
                  'id': uri.split(':').last,
                  'type': uri.startsWith('spotify:track:') ? 'track' : 'album',
                });
              }
            } catch (e) {
              // Skip malformed items
              continue;
            }
          }

          if (bannerItems.isNotEmpty) {
            debugPrint(
                ' [SpotifyLyrics] Parsed ${bannerItems.length} banner items');
            return bannerItems;
          }
        }
      }

      return [];
    } catch (e) {
      debugPrint('💥 [SpotifyLyrics] Spotify Home exception: $e');
      return [];
    }
  }

  /// Fetches a Spotify Track Link by searching the external API.
  /// This saves quota on the official Spotify API when fetching Canvas video URLs.
  static Future<String?> getTrackLink(String title, String artist) async {
    try {
      final cleanTitle = SpotifyService.cleanTerm(title);
      final cleanArtist = SpotifyService.cleanTerm(artist);
      debugPrint(
          ' [SpotifyLyrics] Fetching Track Link via Proxy: $cleanTitle - $cleanArtist');

      final query = Uri.encodeComponent('$cleanTitle $cleanArtist');
      final searchUrl = Uri.parse('$_baseUrl/spotify/search?q=$query');

      final searchRes =
          await http.get(searchUrl).timeout(const Duration(seconds: 30));
      if (searchRes.statusCode != 200) {
        return null;
      }

      final searchDataRaw = json.decode(searchRes.body);
      List<dynamic> searchData = [];
      if (searchDataRaw is List) {
        searchData = searchDataRaw;
      } else if (searchDataRaw is Map && searchDataRaw['data'] is List) {
        searchData = searchDataRaw['data'];
      }

      if (searchData.isEmpty) {
        return null;
      }

      final trackId = searchData[0]['trackId'] as String?;
      if (trackId == null) return null;

      return 'https://open.spotify.com/track/$trackId';
    } catch (e) {
      debugPrint('💥 [SpotifyLyrics] Proxy getTrackLink exception: $e');
      return null;
    }
  }

  /// Fetches SongMetadata via the external proxy service.
  /// Useful as a fallback when the official Spotify API is rate-limited,
  /// or when fetching metadata for local songs synced from another device.
  static Future<Map<String, dynamic>?> searchMetadataViaProxy(
      String title, String artist) async {
    try {
      final cleanTitle = SpotifyService.cleanTerm(title);
      final cleanArtist = SpotifyService.cleanTerm(artist);
      debugPrint(
          ' [SpotifyLyrics] Fetching Metadata via Proxy: $cleanTitle - $cleanArtist');

      final query = Uri.encodeComponent('$cleanTitle $cleanArtist');
      final searchUrl = Uri.parse('$_baseUrl/spotify/search?q=$query');

      final searchRes =
          await http.get(searchUrl).timeout(const Duration(seconds: 30));
      if (searchRes.statusCode != 200) {
        return null;
      }

      final searchDataRaw = json.decode(searchRes.body);
      List<dynamic> searchData = [];
      if (searchDataRaw is List) {
        searchData = searchDataRaw;
      } else if (searchDataRaw is Map && searchDataRaw['data'] is List) {
        searchData = searchDataRaw['data'];
      }

      if (searchData.isNotEmpty) {
        // Try to find a match that contains the artist or title, or just fallback to the first result
        var bestMatch = searchData[0];
        final qArtist = cleanArtist.toLowerCase().trim();
        for (var item in searchData) {
          final itemName = (item['name'] as String?)?.toLowerCase() ?? ''; // ignore: unused_local_variable
          final itemArtist =
              (item['artistName'] as String?)?.toLowerCase() ?? '';
          if (qArtist.isNotEmpty && itemArtist.contains(qArtist)) {
            bestMatch = item;
            break;
          }
        }

        int durationMs = 0;
        final durationStr = bestMatch['duration'] as String?;
        if (durationStr != null) {
          final parts = durationStr.split(':');
          if (parts.length == 2) {
            durationMs = ((int.tryParse(parts[0]) ?? 0) * 60 +
                    (int.tryParse(parts[1]) ?? 0)) *
                1000;
          }
        }

        return {
          'title': bestMatch['name'] ?? title,
          'artist': bestMatch['artistName'] ?? artist,
          'album': bestMatch['albumName'] ?? '',
          'year': '',
          'image_url': bestMatch['albumCover'] ?? '',
          'spotify_id': bestMatch['trackId'] ?? '',
          'duration_ms': durationMs,
          'track_number': 1,
          'disc_number': 1,
          'isrc': '',
        };
      }

      return null;
    } catch (e) {
      debugPrint('💥 [SpotifyLyrics] Proxy searchMetadata exception: $e');
      return null;
    }
  }
}
