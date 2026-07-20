import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Chinese text to Pinyin conversion via Vercel-hosted API.
/// Handles Simplified and Traditional Chinese → Pinyin with tone marks.
import '../env/env.dart';

class ChineseRomanizer {
  static String get _apiUrl => '${Env.romajiApiUrl}/api/pinyin';

  // In-memory cache: original text → pinyin
  static final Map<String, String> _cache = {};

  /// Check if a string contains Chinese characters (CJK without Japanese kana)
  static bool containsChinese(String text) {
    bool hasCJK = false;
    bool hasKana = false;

    for (final code in text.runes) {
      // CJK Unified Ideographs (shared by Chinese and Japanese)
      if ((code >= 0x4E00 && code <= 0x9FFF) ||
          (code >= 0x3400 && code <= 0x4DBF)) {
        hasCJK = true;
      }
      // Hiragana or Katakana → Japanese, not Chinese
      if ((code >= 0x3040 && code <= 0x309F) ||
          (code >= 0x30A0 && code <= 0x30FF)) {
        hasKana = true;
      }
    }

    // Chinese = has CJK characters but NO Japanese kana
    return hasCJK && !hasKana;
  }

  /// Get romanization from cache synchronously. Returns null if not cached.
  static String? getCached(String text) => _cache[text];

  /// Convert Chinese text to Pinyin via the Vercel API.
  /// Returns null if the API call fails.
  static Future<String?> romanize(String text) async {
    if (_cache.containsKey(text)) {
      return _cache[text];
    }

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
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
      debugPrint('Chinese pinyin error: $e');
    }
    return null;
  }

  /// Clear the cache
  static void clearCache() => _cache.clear();
}
