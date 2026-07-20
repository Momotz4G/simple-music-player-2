import 'dart:convert';
import 'dart:io';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import '../utils/chinese_romanizer.dart';
import '../utils/japanese_romanizer.dart';
import '../utils/korean_romanizer.dart';
import '../services/ai_lyrics_service.dart';
import '../services/smart_download_service.dart';
import '../models/song_metadata.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';

class LyricWord {
  final String text;
  final double startTime;
  final double endTime;

  LyricWord({
    required this.text,
    required this.startTime,
    required this.endTime,
  });
}

class LyricLine {
  final String text;
  final String? romanizedText;
  final double time;
  final double? endTime;
  final List<LyricWord>? words;

  LyricLine({
    required this.text,
    this.romanizedText,
    required this.time,
    this.endTime,
    this.words,
  });

  LyricLine copyWith({
    String? text,
    String? romanizedText,
    double? time,
    double? endTime,
    List<LyricWord>? words,
  }) {
    return LyricLine(
      text: text ?? this.text,
      romanizedText: romanizedText ?? this.romanizedText,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      words: words ?? this.words,
    );
  }
}

class LyricsState {
  final String rawLyrics;
  final List<LyricLine> parsedLyrics;
  final bool isLoading;
  final double syncOffset;
  final bool isFromApi;
  final bool hasLocalLrc;
  final bool showTranslation;
  final bool isKaraokeMode;
  final String? generationStatus;
  final List<String> generationLogs;

  LyricsState({
    this.rawLyrics = '',
    this.parsedLyrics = const [],
    this.isLoading = false,
    this.syncOffset = 0.0,
    this.isFromApi = false,
    this.hasLocalLrc = false,
    this.showTranslation = false,
    this.isKaraokeMode = false,
    this.generationStatus,
    this.generationLogs = const [],
  });

  LyricsState copyWith({
    String? rawLyrics,
    List<LyricLine>? parsedLyrics,
    bool? isLoading,
    double? syncOffset,
    bool? isFromApi,
    bool? hasLocalLrc,
    bool? showTranslation,
    bool? isKaraokeMode,
    String? generationStatus,
    List<String>? generationLogs,
  }) {
    return LyricsState(
      rawLyrics: rawLyrics ?? this.rawLyrics,
      parsedLyrics: parsedLyrics ?? this.parsedLyrics,
      isLoading: isLoading ?? this.isLoading,
      syncOffset: syncOffset ?? this.syncOffset,
      isFromApi: isFromApi ?? this.isFromApi,
      hasLocalLrc: hasLocalLrc ?? this.hasLocalLrc,
      showTranslation: showTranslation ?? this.showTranslation,
      isKaraokeMode: isKaraokeMode ?? this.isKaraokeMode,
      generationStatus: generationStatus != null
          ? (generationStatus == "" ? null : generationStatus)
          : this.generationStatus,
      generationLogs: generationLogs ?? this.generationLogs,
    );
  }
}

class LyricsNotifier extends StateNotifier<LyricsState> {
  final Ref ref;
  LyricsNotifier(this.ref) : super(LyricsState());

  /// Track the current song to avoid resetting syncOffset on same-song reload
  String? _currentSongKey;

  void setShowTranslation(bool value) {
    state = state.copyWith(showTranslation: value);
  }

  void toggleTranslation() {
    state = state.copyWith(showTranslation: !state.showTranslation);
  }

  void setKaraokeMode(bool value) {
    state = state.copyWith(isKaraokeMode: value);
  }

  void toggleKaraokeMode() {
    state = state.copyWith(isKaraokeMode: !state.isKaraokeMode);
  }

  @override
  set state(LyricsState value) {
    final oldLyrics = state.parsedLyrics;
    super.state = value;
    if (value.parsedLyrics.isNotEmpty && value.parsedLyrics != oldLyrics) {
      _prefetchAsianRomanization(value.parsedLyrics);
    }
  }

  /// Automatically pre-fetch Japanese and Chinese romanization
  Future<void> _prefetchAsianRomanization(List<LyricLine> lyrics) async {
    final linesToFetch = <String, String>{}; // text → 'ja' or 'zh'

    for (final l in lyrics) {
      if (KoreanRomanizer.containsKorean(l.text)) continue;

      // Optimization: Only queue if NOT in cache
      if (JapaneseRomanizer.containsJapanese(l.text) &&
          JapaneseRomanizer.getCached(l.text) == null) {
        linesToFetch[l.text] = 'ja';
      } else if (ChineseRomanizer.containsChinese(l.text) &&
          ChineseRomanizer.getCached(l.text) == null) {
        linesToFetch[l.text] = 'zh';
      }
    }

    if (linesToFetch.isEmpty) return;

    final entriesList = linesToFetch.entries.toList();
    const chunkSize = 5; // Safe limit concurrent requests

    for (int i = 0; i < entriesList.length; i += chunkSize) {
      final chunk = entriesList.sublist(
          i,
          (i + chunkSize) < entriesList.length
              ? (i + chunkSize)
              : entriesList.length);

      final futures = chunk.map((entry) async {
        if (entry.value == 'ja') {
          await JapaneseRomanizer.romanize(entry.key);
        } else {
          await ChineseRomanizer.romanize(entry.key);
        }
      });

      await Future.wait(futures);
    }
  }

  void addOffset(double delta) {
    state = state.copyWith(syncOffset: state.syncOffset + delta);
  }

  /// Force re-fetch lyrics from LRCLib API (skips local .lrc check).
  Future<void> refreshLyricsFromApi(
      String title, String artist, double durationSecs) async {
    _currentSongKey = null; // Allow loadLyrics to reload after refresh
    state = state.copyWith(
        isLoading: true,
        rawLyrics: '',
        parsedLyrics: [],
        syncOffset: 0.0,
        isFromApi: false);
    try {
      debugPrint("🔄 Refreshing lyrics from LRCLib for: $title - $artist");
      // OFFLINE MODE: Block online lyrics refresh
      final settings = ref.read(settingsProvider);
      if (settings.isOfflineMode || !settings.enableOnlineLyrics) {
        state = state.copyWith(
          isLoading: false,
          rawLyrics: "Offline or Disabled: Online lyrics unavailable.",
        );
        return;
      }
      await _fetchFromApi(title, artist, durationSecs);
    } catch (e) {
      debugPrint("Refresh Lyrics Error: $e");
      state = state.copyWith(
          isLoading: false, rawLyrics: "Error refreshing lyrics.");
    }
  }

  /// Generates AI lyrics using AI service.
  Future<void> generateAiLyrics(String filePath,
      {Map<String, String>? statusMessages}) async {
    String getMsg(String key, String fallback) =>
        statusMessages?[key] ?? fallback;

    // OFFLINE MODE: Block AI lyrics generation
    final settings = ref.read(settingsProvider);
    if (settings.isOfflineMode || !settings.enableAiLyrics) {
      state = state.copyWith(
        isLoading: false,
        rawLyrics: settings.isOfflineMode
            ? "Offline Mode active"
            : "AI Lyrics disabled",
        generationStatus: settings.isOfflineMode
            ? "Offline Mode active"
            : "AI Lyrics disabled",
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) state = state.copyWith(generationStatus: "");
      });
      return;
    }
    final currentSong = ref.read(playerProvider).currentSong;
    if (currentSong != null) {
      _currentSongKey = '${currentSong.filePath}|${currentSong.title}';
    }

    try {
      String resolvedPath = filePath;

      // STREAMING RESOLUTION: If song is a stream, try to find its preloaded/cached file
      if (filePath == "cloud_stream" || filePath.startsWith('http')) {
        final currentSong = ref.read(playerProvider).currentSong;
        if (currentSong != null) {
          final meta = SongMetadata(
            title: currentSong.title,
            artist: currentSong.artist,
            album: currentSong.album,
            durationSeconds: currentSong.duration.toInt(),
            albumArtUrl: currentSong.onlineArtUrl ?? "",
            spotifyId: currentSong.spotifyId,
            deezerId: currentSong.deezerId,
            isrc: currentSong.isrc,
          );

          final predicted =
              await SmartDownloadService().getPredictedCachePath(meta);
          if (predicted.isNotEmpty && await File(predicted).exists()) {
            debugPrint(
                "📡 AI Lyrics: Resolved streaming path to local cache: $predicted");
            resolvedPath = predicted;
          } else {
            debugPrint(
                "⚠️ AI Lyrics: Could not resolve local file for stream. AI may fail.");
            state = state.copyWith(
              isLoading: false,
              rawLyrics:
                  getMsg('localFileMissing', "Local audio file not found."),
              generationStatus:
                  getMsg('localFileMissing', "Error: Local file missing."),
            );
            return; // Exit point 1
          }
        }
      }

      debugPrint("🎬 AI Lyrics Generation Started for: $resolvedPath");
      state = state.copyWith(
        isLoading: true,
        rawLyrics: getMsg('initializing', 'Generating AI Lyrics...'),
        parsedLyrics: [],
        syncOffset: 0.0,
        isFromApi: false,
        generationStatus: getMsg('initializing', "Initializing..."),
        generationLogs: [getMsg('initializing', "Initializing...")],
      );

      try {
        final ttml = await AiLyricsService().generateLyrics(
          resolvedPath,
          onProgress: (msg) {
            state = state.copyWith(
              generationStatus: msg,
              generationLogs: [...state.generationLogs, msg],
            );
          },
          statusMessages: statusMessages,
        );

        if (ttml != null && ttml.isNotEmpty) {
          final parsed = _parseTtml(ttml);

          state = state.copyWith(
            isLoading: false,
            rawLyrics: ttml,
            parsedLyrics: parsed,
            isFromApi: false,
            hasLocalLrc: false, // Wait for manual save
            generationStatus: getMsg('complete', "Complete!"),
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            rawLyrics: "Failed to generate AI lyrics.",
            generationStatus: "Error: Generation failed.",
          );
        }
      } catch (e) {
        debugPrint("AI Lyrics Generation Error: $e");
        state = state.copyWith(
          isLoading: false,
          rawLyrics: "Error generating AI lyrics.",
          generationStatus: "Error: $e",
        );
      }
    } finally {
      // GUARANTEE: Always clear status after a delay, no matter how we exited
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          state = state.copyWith(
              generationStatus: ""); // Use empty string to signal "CLEAR"
        }
      });
    }
  }

  /// Updates the current lyrics state from the editor.
  void updateFromEditor({String? raw, List<LyricLine>? parsed}) {
    state = state.copyWith(
      rawLyrics: raw ?? state.rawLyrics,
      parsedLyrics: parsed ?? state.parsedLyrics,
      isLoading: false,
    );
  }

  /// Saves the current lyrics to a file.
  Future<bool> saveLyrics(String filePath, {bool asTtml = true}) async {
    try {
      final String content;
      if (state.parsedLyrics.isNotEmpty) {
        if (asTtml) {
          content = _convertToTtml(state.parsedLyrics);
        } else {
          content = _convertToLrc(state.parsedLyrics);
        }
      } else {
        // Plain text mode
        if (asTtml) {
          content = _convertPlainToTtml(state.rawLyrics);
        } else {
          content = state.rawLyrics;
        }
      }

      final File file = File(filePath);
      await file.writeAsString(content);

      // Update state to reflect local file exists
      state = state.copyWith(
        rawLyrics: content,
        hasLocalLrc: true,
      );
      return true;
    } catch (e) {
      debugPrint("Error saving lyrics: $e");
      return false;
    }
  }

  /// Embeds the current lyrics directly into the audio file's metadata using FFmpegKit.
  Future<bool> embedLyrics(String filePath) async {
    try {
      final String content;
      if (state.parsedLyrics.isNotEmpty) {
        content = _convertToLrc(state.parsedLyrics);
      } else {
        content = state.rawLyrics;
      }

      final tempDir = await Directory.systemTemp.createTemp('embed_lyrics');
      final tempFile = File(p.join(tempDir.path, p.basename(filePath)));

      // We use FFmpeg to copy the file and add the lyrics tag
      final args = [
        '-y',
        '-i',
        filePath,
        '-c',
        'copy',
        '-metadata',
        'lyrics=$content',
        tempFile.path,
      ];

      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        if (await tempFile.exists() && await tempFile.length() > 0) {
          // Replace the original file
          await tempFile.copy(filePath);
          await tempFile.delete();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("Error embedding lyrics: $e");
      return false;
    }
  }

  String _convertToTtml(List<LyricLine> lines) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<tt xmlns="http://www.w3.org/ns/ttml">');
    buffer.writeln('  <body>');
    buffer.writeln('    <div>');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final begin = _formatTtmlTime(line.time);
      final end = _formatTtmlTime(line.endTime ??
          (i < lines.length - 1 ? lines[i + 1].time : line.time + 5.0));
      if (line.romanizedText != null && line.romanizedText!.isNotEmpty) {
        buffer.writeln(
            '      <p begin="$begin" end="$end" data-romanized="${line.romanizedText!.replaceAll('"', '&quot;')}">${line.text}</p>');
      } else {
        buffer.writeln('      <p begin="$begin" end="$end">${line.text}</p>');
      }
    }
    buffer.writeln('    </div>');
    buffer.writeln('  </body>');
    buffer.writeln('</tt>');
    return buffer.toString();
  }

  String _convertPlainToTtml(String text) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer
        .writeln('<tt xmlns="http://www.w3.org/ns/ttml" itunes:timing="None">');
    buffer.writeln('  <body>');
    buffer.writeln('    <div>');
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) {
        buffer.writeln(
            '      <p>${t.replaceAll('<', '&lt;').replaceAll('>', '&gt;')}</p>');
      }
    }
    buffer.writeln('    </div>');
    buffer.writeln('  </body>');
    buffer.writeln('</tt>');
    return buffer.toString();
  }

  String _convertToLrc(List<LyricLine> lines) {
    final buffer = StringBuffer();
    for (final line in lines) {
      final minutes = (line.time / 60).floor();
      final seconds = line.time % 60;
      final timeStr =
          "${minutes.toString().padLeft(2, '0')}:${seconds.toStringAsFixed(2).padLeft(5, '0')}";
      buffer.writeln('[$timeStr]${line.text}');
    }
    return buffer.toString();
  }

  String _formatTtmlTime(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).toInt());
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return "$h:$m:$s.$ms";
  }

  void loadLyricsFromContent(String rawContent) {
    String content = _fixMojibake(rawContent);
    final currentSong = ref.read(playerProvider).currentSong;
    if (currentSong != null) {
      _currentSongKey = '${currentSong.filePath}|${currentSong.title}';
    }

    List<LyricLine> parsed = [];
    if (content.trim().startsWith('<')) {
      parsed = _parseTtml(content);
    } else if (content.contains(' --> ')) {
      parsed = _parseSrt(content);
    } else {
      parsed = _parseLrc(content);
    }

    if (parsed.isNotEmpty) {
      // Has synced timestamps
      state = state.copyWith(
        isLoading: false,
        rawLyrics: content,
        parsedLyrics: parsed,
        syncOffset: 0.0,
        isFromApi: false,
        hasLocalLrc: false,
      );
    } else {
      // Plain text lyrics (no timestamps)
      String plainText = content;
      if (content.trim().startsWith('<')) {
        plainText = _extractPlainTextFromTtml(content);
      }

      state = state.copyWith(
        isLoading: false,
        rawLyrics: plainText,
        parsedLyrics: [],
        syncOffset: 0.0,
        isFromApi: false,
        hasLocalLrc: false,
      );
    }
  }

  String _extractPlainTextFromTtml(String ttml) {
    try {
      final document = parse(ttml);
      final pTags = document.getElementsByTagName('p');
      if (pTags.isEmpty) return ttml;

      final buffer = StringBuffer();
      for (final p in pTags) {
        final text = p.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      return ttml;
    }
  }

  String _fixMojibake(String input) {
    try {
      if (input.contains('Ã') || input.contains('ì') || input.contains('ë')) {
        final bytes = latin1.encode(input);
        return utf8.decode(bytes);
      }
    } catch (_) {}
    return input;
  }

  Future<void> loadLyrics(
      String filePath, String title, String artist, double durationSecs) async {
    // Delay lyrics fetch by 2 seconds to prioritize initial audio buffering
    await Future.delayed(const Duration(seconds: 2));

    // Same-song guard: preserve syncOffset if lyrics already loaded for this song
    final songKey = '$filePath|$title';
    if (songKey == _currentSongKey &&
        !state.isLoading &&
        (state.parsedLyrics.isNotEmpty || state.rawLyrics.isNotEmpty)) {
      return; // Already loaded — keep existing lyrics & syncOffset
    }

    _currentSongKey = songKey;
    state = state.copyWith(
        isLoading: true,
        rawLyrics: '',
        parsedLyrics: [],
        syncOffset: 0.0,
        isFromApi: false,
        hasLocalLrc: false);

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

      // 2. LOCAL .LRC OR .TTML FILE (Priority 2)
      final lrcPath = p.setExtension(filePath, '.lrc');
      final ttmlPath = p.setExtension(filePath, '.ttml');
      final srtPath = p.setExtension(filePath, '.srt');

      File? foundLocalFile;

      for (final path in [lrcPath, ttmlPath, srtPath]) {
        File file = File(path);
        if (!await file.exists()) {
          final dir = p.dirname(filePath);
          final filename = p.basename(path);
          file = File(p.join(dir, 'lyrics', filename));
          if (!await file.exists()) {
            file = File(p.join(dir, 'Lyrics', filename));
          }
        }
        if (await file.exists()) {
          foundLocalFile = file;
          break;
        }
      }

      if (foundLocalFile != null) {
        debugPrint("📂 Found local lyrics file: ${foundLocalFile.path}");
        final rawContent = await foundLocalFile.readAsString();
        final content = _fixMojibake(rawContent);

        List<LyricLine> parsed = [];
        if (content.trim().startsWith('<')) {
          parsed = _parseTtml(content);
        } else if (content.contains(' --> ')) {
          parsed = _parseSrt(content);
        } else {
          parsed = _parseLrc(content);
        }

        String rawText = content;
        if (parsed.isEmpty && content.trim().startsWith('<')) {
          rawText = _extractPlainTextFromTtml(content);
        }

        state = state.copyWith(
          isLoading: false,
          rawLyrics: rawText,
          parsedLyrics: parsed,
          isFromApi: false, // It's local
          hasLocalLrc: true,
        );
        return;
      }

      // 2. API (LRC LIB) (Priority 2)
      // OFFLINE MODE: Skip online lyrics search
      final settings = ref.read(settingsProvider);
      if (settings.isOfflineMode || !settings.enableOnlineLyrics) {
        state = state.copyWith(
          isLoading: false,
          rawLyrics: "No local lyrics found. Online search disabled.",
          parsedLyrics: [],
          isFromApi: false,
        );
        return;
      }
      debugPrint("🌍 Fetching lyrics from LRC LIB for: $title - $artist");
      await _fetchFromApi(title, artist, durationSecs);
    } catch (e) {
      debugPrint("Lyrics Logic Error: $e");
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
          debugPrint("✅ Found Synced Lyrics from API");
          debugPrint("🔗 Fetched URL: $uri"); //Debug URL LRCLIB
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
        debugPrint("⚠️ API 404: Trying fallback search...");
        await _searchFallback(cleanTitle, artist);
        return;
      }
      throw Exception("Lyrics not found");
    } catch (e) {
      debugPrint("❌ No lyrics found via API: $e");
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

      debugPrint("🔍 Fallback Search: q=$cleanTitle $cleanArtist");

      final uri =
          Uri.parse("https://lrclib.net/api/search").replace(queryParameters: {
        "q": "$cleanTitle $cleanArtist",
      });

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          // Find best match by checking title similarity
          final lowerTargetTitle = cleanTitle.toLowerCase();

          Map<String, dynamic>? bestMatch;

          // Priority 1: Exact matching title + synced lyrics
          bestMatch = data.firstWhere(
            (item) =>
                (item['trackName']
                        ?.toString()
                        .toLowerCase()
                        .contains(lowerTargetTitle) ??
                    false) &&
                item['syncedLyrics'] != null &&
                item['syncedLyrics'].toString().trim().isNotEmpty,
            orElse: () => null,
          );

          // Priority 2: Exact matching title + plain lyrics
          bestMatch ??= data.firstWhere(
            (item) =>
                (item['trackName']
                        ?.toString()
                        .toLowerCase()
                        .contains(lowerTargetTitle) ??
                    false) &&
                item['plainLyrics'] != null &&
                item['plainLyrics'].toString().trim().isNotEmpty,
            orElse: () => null,
          );

          // Priority 3: Fallback to the first result that has synced lyrics
          bestMatch ??= data.firstWhere(
            (item) =>
                item['syncedLyrics'] != null &&
                item['syncedLyrics'].toString().trim().isNotEmpty,
            orElse: () => null,
          );

          // Final fallback: just take the absolute first result
          bestMatch ??= data.first;

          String lyrics = bestMatch?['syncedLyrics'] ?? "";
          // If still empty, try plain lyrics
          if (lyrics.isEmpty) lyrics = bestMatch?['plainLyrics'] ?? "";

          if (lyrics.isNotEmpty) {
            debugPrint(
                "✅ Found Search Result Lyrics for: ${bestMatch?['trackName']}");
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
      debugPrint("Fallback Search Error: $e");
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

  List<LyricLine> _parseTtml(String ttml) {
    final List<LyricLine> lines = [];
    try {
      final document = parse(ttml);
      final pTags = document.getElementsByTagName('p');
      for (final p in pTags) {
        final beginStr = p.attributes['begin'];
        final endStr = p.attributes['end'];
        if (beginStr != null) {
          final time = _parseTtmlTime(beginStr);
          final endTime = endStr != null ? _parseTtmlTime(endStr) : null;
          final text = p.text.trim().replaceAll(RegExp(r'\s+'), ' ');
          final romanized = p.attributes['data-romanized'];

          List<LyricWord>? words;
          final spanTags = p.getElementsByTagName('span');
          if (spanTags.isNotEmpty) {
            words = [];
            for (final span in spanTags) {
              final spanBegin = span.attributes['begin'];
              final spanEnd = span.attributes['end'];
              final spanText = span.text.trim();
              // In some TTML, spaces between spans might be lost if we only take span.text.
              // But spanText is enough for word-level sync highlighting.
              if (spanBegin != null && spanEnd != null && spanText.isNotEmpty) {
                words.add(LyricWord(
                  text: spanText,
                  startTime: _parseTtmlTime(spanBegin),
                  endTime: _parseTtmlTime(spanEnd),
                ));
              }
            }
            if (words.isEmpty) words = null;
          }

          if (text.isNotEmpty) {
            lines.add(LyricLine(
                time: time,
                endTime: endTime,
                text: text,
                romanizedText: romanized,
                words: words));
          }
        }
      }
    } catch (e) {
      debugPrint("TTML parsing error: $e");
    }
    return lines;
  }

  double _parseTtmlTime(String timeStr) {
    try {
      timeStr = timeStr.replaceAll('s', '').trim();
      final parts = timeStr.split(':');
      if (parts.length == 3) {
        return double.parse(parts[0]) * 3600 +
            double.parse(parts[1]) * 60 +
            double.parse(parts[2]);
      } else if (parts.length == 2) {
        return double.parse(parts[0]) * 60 + double.parse(parts[1]);
      } else if (parts.length == 1) {
        return double.parse(parts[0]);
      }
    } catch (e) {
      debugPrint("Time parsing error: $e");
    }
    return 0.0;
  }

  List<LyricLine> _parseSrt(String srt) {
    final List<LyricLine> lines = [];
    // Split by double newline to get blocks
    final List<String> blocks = srt.split(RegExp(r'\r?\n\r?\n'));

    final RegExp timeRegex = RegExp(
        r'(\d{2}:\d{2}:\d{2}[.,]\d{3}) --> (\d{2}:\d{2}:\d{2}[.,]\d{3})');

    for (var block in blocks) {
      final linesInBlock = block.trim().split(RegExp(r'\r?\n'));
      if (linesInBlock.length < 2) continue;

      // The time is usually on the second line (after the index)
      // but some SRTs might skip the index. Let's find the time line.
      int timeLineIndex = -1;
      Match? timeMatch;

      for (int i = 0; i < linesInBlock.length && i < 2; i++) {
        timeMatch = timeRegex.firstMatch(linesInBlock[i]);
        if (timeMatch != null) {
          timeLineIndex = i;
          break;
        }
      }

      if (timeMatch != null && timeLineIndex != -1) {
        final startTime = _parseSrtTime(timeMatch.group(1)!);
        final endTime = _parseSrtTime(timeMatch.group(2)!);

        // Everything after the time line is text
        final text = linesInBlock
            .sublist(timeLineIndex + 1)
            .join(' ')
            .replaceAll(RegExp(r'<[^>]*>'), '') // Strip HTML tags like <i>
            .trim();

        if (text.isNotEmpty) {
          lines.add(LyricLine(time: startTime, endTime: endTime, text: text));
        }
      }
    }
    return lines;
  }

  double _parseSrtTime(String timeStr) {
    // Format: 00:00:20,000 or 00:00:20.000
    try {
      final parts = timeStr.split(':');
      final secondsWithMs = parts[2].replaceAll(',', '.');

      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final seconds = double.parse(secondsWithMs);

      return (hours * 3600) + (minutes * 60) + seconds;
    } catch (e) {
      debugPrint("SRT Time parsing error: $e");
      return 0.0;
    }
  }
}

final lyricsProvider =
    StateNotifierProvider<LyricsNotifier, LyricsState>((ref) {
  return LyricsNotifier(ref);
});
