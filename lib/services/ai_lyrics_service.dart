import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../env/env.dart';
import 'package:http/http.dart' as http;

class AiLyricsService {
  static final AiLyricsService _instance = AiLyricsService._internal();
  factory AiLyricsService() => _instance;
  AiLyricsService._internal();

  static String get _apiUrl => Env.aiLyricsApiUrl;

  /// Generates TTML lyrics for the given audio file by streaming from the VPS API.
  Future<String?> generateLyrics(String filePath, {
    void Function(String message)? onProgress,
    Map<String, String>? statusMessages,
  }) async {
    String getMsg(String key, String fallback) => statusMessages?[key] ?? fallback;

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        onProgress?.call(getMsg('localFileMissing', "Error: Local audio file not found."));
        return null;
      }

      final fileSizeMB = (await file.length()) / (1024 * 1024);
      debugPrint("AI Lyrics: Uploading ${fileSizeMB.toStringAsFixed(2)} MB to VPS API...");
      onProgress?.call("Uploading ${fileSizeMB.toStringAsFixed(2)} MB to API...");

      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      // The VPS streams progress updates, so we use a very long timeout (5 mins)
      final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
      
      if (streamedResponse.statusCode != 200) {
        onProgress?.call("Error: Server returned status ${streamedResponse.statusCode}");
        return null;
      }

      bool isResult = false;
      StringBuffer ttmlBuffer = StringBuffer();
      
      // Listen to the chunked streaming response
      final stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (isResult) {
          ttmlBuffer.writeln(line);
          continue;
        }

        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.startsWith('PROGRESS: ')) {
          final msg = trimmed.substring(10);
          onProgress?.call(msg);
        } else if (trimmed.startsWith('RESULT: ')) {
          isResult = true;
          ttmlBuffer.writeln(trimmed.substring(8));
        } else if (trimmed.startsWith('ERROR: ')) {
          onProgress?.call(trimmed);
          return null;
        }
      }

      if (isResult) {
        return ttmlBuffer.toString().trim();
      }
      return null;
    } catch (e) {
      debugPrint("❌ AI Lyrics API Error: $e");
      onProgress?.call("Error: $e");
      return null;
    }
  }
}
