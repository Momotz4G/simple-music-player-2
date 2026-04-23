import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../env/env.dart';

class VpsScraperService {
  static String get _baseUrl {
    try {
      return dotenv.env['VPS_SCRAPER_URL'] ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get _bannerUrl => Env.spotifyBannerUrl;

  /// Fetches an artist image from the custom VPS scraper
  static Future<String?> getArtistImage(String artistName, {String? artistId}) async {
    return _fetchFromVps(artistName, id: artistId, type: 'artist');
  }

  /// Fetches a high-resolution banner from the new Spotify Banner Scraper
  static Future<Map<String, String?>> getArtistBanner(String artistId) async {
    try {
      final String baseUrl = _bannerUrl;
      if (baseUrl.isEmpty) return {};

      final response = await http.post(
        Uri.parse('$baseUrl/api/extractbanner'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'artistUrl': 'https://open.spotify.com/artist/$artistId',
          'forceRefresh': true // Always try for fresh data if we reached this point
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final res = data['data'];
          return {
            'banner': res['bannerUrl'] as String?,
            'profile': res['profileUrl'] as String?,
            'gallery': res['galleryUrl'] as String?,
          };
        }
      }
    } catch (e) {
      debugPrint("⚠️ Spotify Banner Scraper Error: $e");
    }
    return {};
  }

  /// Fetches a track image (album art) from the custom VPS scraper
  static Future<String?> getTrackImage(String title, String artist, {String? trackId}) async {
    return _fetchFromVps('$title $artist', id: trackId, type: 'track');
  }

  static Future<String?> _fetchFromVps(String query, {String? id, String type = 'artist'}) async {
    try {
      if (_baseUrl.isEmpty) return null;
      String url = '$_baseUrl/artist-image?name=${Uri.encodeComponent(query)}&type=$type';
      if (id != null && id.isNotEmpty) {
        url += '&id=$id';
      }
      
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'];
      }
    } catch (e) {
      debugPrint("⚠️ VPS Scraper Error ($type): $e");
    }
    return null;
  }
}
