import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song_metadata.dart';
import 'package:flutter/foundation.dart';

class ITunesApiService {
  static const String _baseUrl = 'https://itunes.apple.com/search';

  /// Search the iTunes API and return SongMetadata objects.
  static Future<List<SongMetadata>> searchSongs(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse('$_baseUrl?term=$encodedQuery&entity=song&limit=$limit');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];

        return results.map((track) {
          final artist = track['artistName'] as String? ?? 'Unknown Artist';
          final title = track['trackName'] as String? ?? 'Unknown Title';
          final album = track['collectionName'] as String? ?? '';
          
          // iTunes returns duration in milliseconds
          final trackTimeMillis = track['trackTimeMillis'] as int? ?? 0;
          final durationSeconds = trackTimeMillis ~/ 1000;

          // Apple Music URL
          final trackViewUrl = track['trackViewUrl'] as String? ?? '';

          // High-Res Artwork
          String artUrl = track['artworkUrl100'] as String? ?? '';
          if (artUrl.isNotEmpty) {
            artUrl = artUrl.replaceAll('100x100bb', '600x600bb');
          }

          // Create SongMetadata
          // We map iTunes URL to spotifyUrl or youtubeUrl or a custom field.
          // Since the app probably expects one of these for the deep search later,
          // we will place the Apple Music URL in `url` field if your SongMetadata supports it, 
          // or we can just pass it through the existing structures.
          return SongMetadata(
            title: title,
            artist: artist,
            album: album,
            durationSeconds: durationSeconds,
            albumArtUrl: artUrl,
            // You can temporarily store the apple music url in youtubeUrl or a new field
            // if you need it for downloading. For now, we put it in youtubeUrl so it can be played/passed.
            youtubeUrl: trackViewUrl,
          );
        }).toList();
      } else {
        debugPrint('iTunes API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('iTunes Search Exception: $e');
      return [];
    }
  }
}
