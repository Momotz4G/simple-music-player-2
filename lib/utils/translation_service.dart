import 'dart:convert';
import 'package:http/http.dart' as http;

/// Lyrics translation service via Vercel-hosted Google Translate API.
/// Supports batch translation of all lyric lines in a single API call.
import '../env/env.dart';

class TranslationService {
  static String get _apiUrl => '${Env.romajiApiUrl}/api/translate';

  // In-memory cache: songKey → list of translated lines
  static final Map<String, List<String>> _cache = {};

  // Track loading state per song
  static final Map<String, bool> _loading = {};

  /// Check if translations are cached for a song
  static bool hasCached(String songKey) => _cache.containsKey(songKey);

  /// Get cached translations for a song (null if not cached)
  static List<String>? getCached(String songKey) => _cache[songKey];

  /// Check if translation is currently loading for a song
  static bool isLoading(String songKey) => _loading[songKey] == true;

  /// Translate all lyric lines for a song.
  /// Returns the list of translated strings, or null on failure.
  static Future<List<String>?> translateLyrics({
    required String songKey,
    required List<String> lines,
    String targetLang = 'en',
  }) async {
    // Return from cache if available
    if (_cache.containsKey(songKey)) {
      return _cache[songKey];
    }

    // Prevent duplicate requests
    if (_loading[songKey] == true) return null;
    _loading[songKey] = true;

    try {
      // Filter out empty lines but keep their positions
      final nonEmptyIndices = <int>[];
      final nonEmptyLines = <String>[];
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim().isNotEmpty) {
          nonEmptyIndices.add(i);
          nonEmptyLines.add(lines[i]);
        }
      }

      if (nonEmptyLines.isEmpty) {
        final emptyResult = List<String>.filled(lines.length, '');
        _cache[songKey] = emptyResult;
        _loading[songKey] = false;
        return emptyResult;
      }

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': nonEmptyLines,
              'to': targetLang,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translations = List<String>.from(data['translations'] ?? []);

        // Reconstruct full list with empty strings for originally empty lines
        final result = List<String>.filled(lines.length, '');
        for (int i = 0;
            i < nonEmptyIndices.length && i < translations.length;
            i++) {
          result[nonEmptyIndices[i]] = translations[i];
        }

        _cache[songKey] = result;
        _loading[songKey] = false;
        return result;
      }
    } catch (e) {
      print('Translation error: $e');
    }

    _loading[songKey] = false;
    return null;
  }

  /// Translate a single text string.
  /// Returns the translated string, or null on failure.
  static Future<String?> translateText({
    required String text,
    String targetLang = 'en',
  }) async {
    try {
      if (text.trim().isEmpty) return text;

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': [text],
              'to': targetLang,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translations = List<String>.from(data['translations'] ?? []);
        if (translations.isNotEmpty) {
          return translations.first;
        }
      }
    } catch (e) {
      print('Translation error: $e');
    }
    return null;
  }

  /// Clear cache for a specific song
  static void clearSongCache(String songKey) {
    _cache.remove(songKey);
    _loading.remove(songKey);
  }

  /// Clear all cached translations
  static void clearCache() {
    _cache.clear();
    _loading.clear();
  }
}
