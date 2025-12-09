import 'dart:convert';
import 'dart:io';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class LyricLine {
  final String text;
  final double time;

  LyricLine({required this.text, required this.time});
}

class LyricsState {
  final String rawLyrics;
  final List<LyricLine> parsedLyrics;
  final bool isLoading;
  final double syncOffset;
  final bool isFromApi;

  LyricsState({
    this.rawLyrics = '',
    this.parsedLyrics = const [],
    this.isLoading = false,
    this.syncOffset = 0.0,
    this.isFromApi = false,
  });

  LyricsState copyWith({
    String? rawLyrics,
    List<LyricLine>? parsedLyrics,
    bool? isLoading,
    double? syncOffset,
    bool? isFromApi,
  }) {
    return LyricsState(
      rawLyrics: rawLyrics ?? this.rawLyrics,
      parsedLyrics: parsedLyrics ?? this.parsedLyrics,
      isLoading: isLoading ?? this.isLoading,
      syncOffset: syncOffset ?? this.syncOffset,
      isFromApi: isFromApi ?? this.isFromApi,
    );
  }
}

class LyricsNotifier extends StateNotifier<LyricsState> {
  LyricsNotifier() : super(LyricsState());

  void addOffset(double delta) {
    state = state.copyWith(syncOffset: state.syncOffset + delta);
  }

  Future<void> loadLyrics(
      String filePath, String title, String artist, double durationSecs) async {
    state = state.copyWith(
        isLoading: true,
        rawLyrics: '',
        parsedLyrics: [],
        syncOffset: 0.0,
        isFromApi: false);

    try {
      // 1. EMBEDDED LYRICS (via MetadataRetriever - DISABLED)
      // The Metadata class in flutter_media_metadata doesn't provide a 'lyrics' getter.
      // We skip this check to avoid NoSuchMethodError.
      /*
      try {
        final dynamic metadata =
            await MetadataRetriever.fromFile(File(filePath));
        // final String? embeddedLyrics = metadata.lyrics; // ERROR: Getter not found
      } catch (e) {
        print("MetadataRetriever Error: $e");
      }
      */

      // 2. LOCAL .LRC FILE (Priority 2)
      // Check adjacent .lrc file
      final lrcPath = p.setExtension(filePath, '.lrc');
      File lrcFile = File(lrcPath);

      // Check 'lyrics' subdirectory
      if (!await lrcFile.exists()) {
        final dir = p.dirname(filePath);
        final filename = p.basename(lrcPath);
        lrcFile = File(p.join(dir, 'lyrics', filename));
        if (!await lrcFile.exists()) {
          lrcFile = File(p.join(dir, 'Lyrics', filename));
        }
      }

      if (await lrcFile.exists()) {
        print("📂 Found local .lrc file: ${lrcFile.path}");
        final content = await lrcFile.readAsString();
        state = state.copyWith(
          isLoading: false,
          rawLyrics: content,
          parsedLyrics: _parseLrc(content),
          isFromApi: false, // It's local
        );
        return;
      }

      // 2. API (LRC LIB) (Priority 2)
      print("🌍 Fetching lyrics from LRC LIB for: $title - $artist");
      await _fetchFromApi(title, artist, durationSecs);
    } catch (e) {
      print("Lyrics Logic Error: $e");
      state =
          state.copyWith(isLoading: false, rawLyrics: "Error loading lyrics.");
    }
  }

  Future<void> _fetchFromApi(
      String title, String artist, double duration) async {
    try {
      final cleanTitle = _cleanTerm(title);

      final uri =
          Uri.parse("https://lrclib.net/api/get").replace(queryParameters: {
        "artist_name": artist,
        "track_name": cleanTitle,
        "duration": duration.toInt().toString(),
      });

      final response =
          await http.get(uri, headers: {"User-Agent": "SimpleMusicPlayer/1.0"});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String lyrics = data['syncedLyrics'] ?? "";

        if (lyrics.isNotEmpty) {
          print("✅ Found Synced Lyrics from API");
          print("🔗 Fetched URL: $uri"); //Debug URL LRCLIB
          if (!mounted) return;
          state = state.copyWith(
            isLoading: false,
            rawLyrics: lyrics,
            parsedLyrics: _parseLrc(lyrics),
            isFromApi: true,
          );
          return;
        }
      }

      if (response.statusCode == 404) {
        print("⚠️ API 404: Trying fallback search...");
        await _searchFallback(cleanTitle, artist);
        return;
      }
      throw Exception("Lyrics not found");
    } catch (e) {
      print("❌ No lyrics found via API: $e");
      // Try fallback one last time if we haven't already
      if (!state.isFromApi && state.parsedLyrics.isEmpty) {
        await _searchFallback(title, artist);
      } else {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          rawLyrics: "No lyrics found.",
          parsedLyrics: [],
          isFromApi: false,
        );
      }
    }
  }

  Future<void> _searchFallback(String title, String artist) async {
    try {
      final cleanTitle = _cleanTerm(title);
      final cleanArtist = _cleanTerm(artist);

      print("🔍 Fallback Search: q=$cleanTitle $cleanArtist");

      final uri =
          Uri.parse("https://lrclib.net/api/search").replace(queryParameters: {
        "q": "$cleanTitle $cleanArtist",
      });

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          // Try to find exact match first
          var match = data.firstWhere((item) => item['syncedLyrics'] != null,
              orElse: () => null);

          // If no synced lyrics, just take first result
          match ??= data.first;

          String lyrics = match['syncedLyrics'] ?? "";
          // If still empty, try plain lyrics
          if (lyrics.isEmpty) lyrics = match['plainLyrics'] ?? "";

          if (lyrics.isNotEmpty) {
            print("✅ Found Search Result Lyrics");
            if (!mounted) return;
            state = state.copyWith(
              isLoading: false,
              rawLyrics: lyrics,
              parsedLyrics: _parseLrc(lyrics),
              isFromApi: true,
            );
            return;
          }
        }
      }
    } catch (e) {
      print("Fallback Search Error: $e");
    }

    if (!mounted) return;

    state = state.copyWith(
      isLoading: false,
      rawLyrics: "No lyrics found.",
      parsedLyrics: [],
      isFromApi: false,
    );
  }

  String _cleanTerm(String text) {
    if (text.isEmpty) return "";
    var cleaned = text.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'\s+(feat\.?|ft\.?|featuring|with|prod\.)\s+.*',
            caseSensitive: false),
        '');
    if (cleaned.contains(' x ')) cleaned = cleaned.split(' x ')[0];
    if (cleaned.contains(' X ')) cleaned = cleaned.split(' X ')[0];
    if (cleaned.contains(';')) cleaned = cleaned.split(';')[0];
    if (cleaned.contains(' / ')) cleaned = cleaned.split(' / ')[0];
    return cleaned.trim();
  }

  List<LyricLine> _parseLrc(String lrc) {
    final List<LyricLine> lines = [];
    final RegExp regex = RegExp(r'\[(\d+):(\d+(\.\d+)?)\](.*)');

    for (var line in lrc.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = double.parse(match.group(2)!);
        final text = match.group(4)!.trim();
        if (text.isNotEmpty) {
          lines.add(LyricLine(time: (minutes * 60) + seconds, text: text));
        }
      }
    }
    return lines;
  }
}

final lyricsProvider =
    StateNotifierProvider.autoDispose<LyricsNotifier, LyricsState>((ref) {
  return LyricsNotifier();
});
