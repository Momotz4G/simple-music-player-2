import 'dart:convert';
import 'package:http/http.dart' as http;

/// Japanese text romanization via Vercel-hosted Kuroshiro API.
/// Handles Kanji, Hiragana, and Katakana → Romaji conversion.
import '../env/env.dart';

class JapaneseRomanizer {
  static String get _apiUrl => '${Env.romajiApiUrl}/api/romanize';

  // In-memory cache: original text → romanized text
  static final Map<String, String> _cache = {};

  /// Check if a string contains Japanese characters.
  /// Requires presence of Hiragana or Katakana (Japanese-only scripts).
  /// CJK characters alone are NOT enough (they're shared with Chinese).
  static bool containsJapanese(String text) {
    bool hasKana = false;
    for (final code in text.runes) {
      if ((code >= 0x3040 && code <= 0x309F) || // Hiragana
          (code >= 0x30A0 && code <= 0x30FF)) {
        // Katakana
        hasKana = true;
        break;
      }
    }
    return hasKana;
  }

  /// Get romanization from cache synchronously. Returns null if not cached.
  static String? getCached(String text) => _cache[text];

  /// Romanize Japanese text via the Vercel API.
  /// Returns null if the API call fails.
  static Future<String?> romanize(String text) async {
    // Check cache first
    if (_cache.containsKey(text)) {
      return _cache[text];
    }

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'to': 'romaji', 'mode': 'spaced'}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'] as String?;
        if (result != null && result.isNotEmpty) {
          _cache[text] = result;
          return result;
        }
      }
    } catch (e) {
      print('Japanese romanize error: $e');
    }
    return null;
  }


  /// Clear the cache (e.g., when switching songs)
  static void clearCache() => _cache.clear();
}
