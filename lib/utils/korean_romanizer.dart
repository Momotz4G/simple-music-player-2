/// Offline Korean (Hangul) to Revised Romanization converter.
///
/// Decomposes each Hangul syllable into its constituent jamo
/// and maps them to their romanized equivalents.
class KoreanRomanizer {
  // Initial consonants (초성) - 19 total
  static const List<String> _initials = [
    'g',
    'kk',
    'n',
    'd',
    'tt',
    'r',
    'm',
    'b',
    'pp',
    's',
    'ss',
    '',
    'j',
    'jj',
    'ch',
    'k',
    't',
    'p',
    'h',
  ];

  // Medial vowels (중성) - 21 total
  static const List<String> _medials = [
    'a',
    'ae',
    'ya',
    'yae',
    'eo',
    'e',
    'yeo',
    'ye',
    'o',
    'wa',
    'wae',
    'oe',
    'yo',
    'u',
    'wo',
    'we',
    'wi',
    'yu',
    'eu',
    'ui',
    'i',
  ];

  // Final consonants (종성) - 28 total (first is empty = no final)
  static const List<String> _finals = [
    '',
    'k',
    'k',
    'k',
    'n',
    'n',
    'n',
    't',
    'l',
    'l',
    'l',
    'l',
    'l',
    'l',
    'l',
    'l',
    'm',
    'p',
    'p',
    's',
    'ss',
    'ng',
    't',
    't',
    'k',
    't',
    'p',
    'h',
  ];

  static const int _hangulBase = 0xAC00;
  static const int _hangulEnd = 0xD7A3;

  /// Check if a character is a Hangul syllable
  static bool _isHangul(int code) => code >= _hangulBase && code <= _hangulEnd;

  /// Check if a string contains any Korean characters
  static bool containsKorean(String text) {
    return text.runes.any(_isHangul);
  }

  static final Map<String, String> _cache = {};

  /// Convert a string with Korean text to its romanized form.
  /// Non-Korean characters are kept as-is.
  static String romanize(String text) {
    if (_cache.containsKey(text)) {
      return _cache[text]!;
    }

    final buffer = StringBuffer();

    for (int i = 0; i < text.runes.length; i++) {
      final code = text.runes.elementAt(i);

      if (_isHangul(code)) {
        final syllableIndex = code - _hangulBase;
        final initialIndex = syllableIndex ~/ (21 * 28);
        final medialIndex = (syllableIndex % (21 * 28)) ~/ 28;
        final finalIndex = syllableIndex % 28;

        buffer.write(_initials[initialIndex]);
        buffer.write(_medials[medialIndex]);
        buffer.write(_finals[finalIndex]);
      } else {
        buffer.writeCharCode(code);
      }
    }

    final result = buffer.toString();
    _cache[text] = result;
    return result;
  }
}
