import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_usage_provider.dart';
import '../providers/settings_provider.dart';
import '../env/env.dart';
import 'pocketbase_service.dart';
import 'metadata_service.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'debug_log_service.dart';

class AppleMusicBackendService {
  static Ref? globalRef; // Added for Data Usage tracking
  static String get _baseUrl => Env.appleMusicApiUrl;

  /// Searches Apple Music via the VPS backend.
  /// Returns a list of tracks, each containing title, artist, album, url, and cover.
  static Future<List<Map<String, dynamic>>> search(String query, {int limit = 5}) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse('$_baseUrl/search?q=$encodedQuery&limit=$limit');
      final response = await http.get(url).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
        return results;
      }
    } catch (e) {
      debugPrint("⚠️ Apple Music Search Error: $e");
    }
    return [];
  }

  /// Sends the Apple Music URL to the VPS backend to be fetched via Telegram.
  /// Returns the absolute URL for the `.m4a` ALAC file hosted on the VPS.
  /// [onQueueUpdate] is called with the current queue position.
  static Future<String?> requestDownload(
    String appleMusicUrl, {
    bool fetchLyrics = false,
    String? title,
    String? artist,
    Function(int)? onQueueUpdate,
    bool Function()? isCancelled,
  }) async {
    try {
      debugPrint('🎵 Sending Apple Music link to VPS for processing...');
      final url = Uri.parse('$_baseUrl/download');

      final settings = globalRef?.read(settingsProvider);
      final rawFormat = settings?.audioFormat ?? 'alac';
      final format = (rawFormat == 'flac' || rawFormat == 'alac') ? 'alac' : rawFormat;

      final body = {
        'url': appleMusicUrl,
        'fetch_lyrics': fetchLyrics,
        'user_id': PocketBaseService().userId ?? '',
        'format': format,
      };
      if (title != null) body['title'] = title;
      if (artist != null) body['artist'] = artist;

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 180));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'queued') {
          final taskId = data['task_id'] as String;
          debugPrint('✅ Task queued: $taskId');

          // Polling Loop
          int attempts = 0;
          const maxAttempts = 60; // 2 minutes max polling (2s * 60)

          while (attempts < maxAttempts) {
            if (isCancelled != null && isCancelled()) {
              debugPrint('⛔ User cancelled task $taskId. Sending DELETE to VPS...');
              try {
                await http.delete(Uri.parse('$_baseUrl/task/$taskId'));
              } catch (e) {
                debugPrint('⚠️ Failed to send cancel request: $e');
              }
              return null;
            }

            await Future.delayed(const Duration(seconds: 2));
            attempts++;

            final statusUrl = Uri.parse('$_baseUrl/task/$taskId');
            final statusRes = await http.get(statusUrl);

            if (statusRes.statusCode == 200) {
              final statusData = json.decode(statusRes.body);
              final status = statusData['status'];

              if (status == 'success') {
                final result = statusData['result'];
                final audioUrlPath = result['audio_url'] as String;
                // Workaround for VPS backend double-unquote bug:
                // The VPS automatically unquotes the path in the ASGI framework,
                // but then its api.py unquotes it AGAIN. This breaks folders with '%' in their name.
                // We pre-compensate by double-encoding all percent signs.
                final workaroundPath = audioUrlPath.replaceAll('%', '%25');
                final fullUrl = '$_baseUrl$workaroundPath';
                debugPrint('✅ Task $taskId completed! URL: $fullUrl');
                return fullUrl;
              } else if (status == 'error') {
                debugPrint('❌ Task $taskId failed: ${statusData['error']}');
                return null;
              } else if (status == 'queued' && onQueueUpdate != null) {
                final pos = statusData['queue_position'] as int? ?? 0;
                onQueueUpdate(pos);
              } else if (status == 'processing' && onQueueUpdate != null) {
                // position 0 means processing
                onQueueUpdate(0);
              }
            }
          }
          debugPrint('❌ Polling timed out for task $taskId');
          return null;
        } else if (data['status'] == 'success') {
          // Direct success (already cached)
          final audioUrlPath = data['audio_url'] as String;
          final workaroundPath = audioUrlPath.replaceAll('%', '%25');
          return '$_baseUrl$workaroundPath';
        } else if (data['status'] == 'gofile_fallback') {
          // VPS can't reach Gofile — try downloading directly from client
          final gofileUrl = data['external_url'] as String;
          debugPrint(
              '🔄 Gofile fallback: VPS blocked, trying direct download from $gofileUrl');
          final directUrl = await _downloadFromGofile(gofileUrl);
          if (directUrl != null) {
            return directUrl;
          }
          // Throw specific exception for the UI to show a beautiful interactive popup
          throw Exception('GOFILE_FALLBACK_URL:$gofileUrl');
        } else {
          debugPrint(
              '⚠️ Apple Music Backend returned unknown status: ${data['status']}');
          return null;
        }
      } else {
        debugPrint(
            '❌ Apple Music Backend Error: ${response.statusCode} — ${response.body}');
        if (response.statusCode == 403) {
          try {
            final errData = json.decode(response.body);
            if (errData['detail'] != null) {
              throw Exception('QUOTA_EXCEEDED:${errData['detail']}');
            }
          } catch (_) {}
          throw Exception('QUOTA_EXCEEDED:Daily quota reached. Upgrade to Premium!');
        }
        return null;
      }
    } catch (e) {
      debugPrint('💥 Apple Music Backend Exception: $e');
      if (e.toString().contains('GOFILE_FALLBACK_URL:') || 
          e.toString().contains('QUOTA_EXCEEDED:')) {
        rethrow;
      }
      return null;
    }
  }

  /// Sends the Apple Music URL to the VPS backend specifically to fetch lyrics.
  /// Returns the absolute URL for the `.ttml` or `.lrc` file hosted on the VPS.
  static Future<String?> requestLyricsDownload(
    String appleMusicUrl, {
    String? title,
    String? artist,
    Function(int)? onQueueUpdate,
  }) async {
    try {
      debugPrint('🎵 Sending Apple Music link to VPS for lyrics processing...');
      final url = Uri.parse('$_baseUrl/download');

      final body = {
        'url': appleMusicUrl,
        'fetch_lyrics': true,
        'user_id': PocketBaseService().userId ?? '',
      };
      if (title != null) body['title'] = title;
      if (artist != null) body['artist'] = artist;

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 180));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'queued') {
          final taskId = data['task_id'] as String;
          debugPrint('✅ Task queued for lyrics: $taskId');

          // Polling Loop
          int attempts = 0;
          const maxAttempts = 60; // 2 minutes max polling (2s * 60)

          while (attempts < maxAttempts) {
            await Future.delayed(const Duration(seconds: 2));
            attempts++;

            final statusUrl = Uri.parse('$_baseUrl/task/$taskId');
            final statusRes = await http.get(statusUrl);

            if (statusRes.statusCode == 200) {
              final statusData = json.decode(statusRes.body);
              final status = statusData['status'];

              if (status == 'success') {
                final result = statusData['result'];
                final lyricsUrlPath = result['lyrics_url'] as String?;
                if (lyricsUrlPath == null || lyricsUrlPath.isEmpty) {
                  return null;
                }

                final workaroundPath = lyricsUrlPath.replaceAll('%', '%25');
                final fullUrl = '$_baseUrl$workaroundPath';
                debugPrint('✅ Lyrics Task $taskId completed! URL: $fullUrl');
                return fullUrl;
              } else if (status == 'error') {
                debugPrint('❌ Task $taskId failed: ${statusData['error']}');
                return null;
              } else if (status == 'queued' && onQueueUpdate != null) {
                final pos = statusData['queue_position'] as int? ?? 0;
                onQueueUpdate(pos);
              } else if (status == 'processing' && onQueueUpdate != null) {
                onQueueUpdate(0);
              }
            }
          }
          debugPrint('❌ Polling timed out for task $taskId');
          return null;
        } else if (data['status'] == 'success') {
          final lyricsUrlPath = data['lyrics_url'] as String?;
          if (lyricsUrlPath == null || lyricsUrlPath.isEmpty) return null;
          final workaroundPath = lyricsUrlPath.replaceAll('%', '%25');
          return '$_baseUrl$workaroundPath';
        } else {
          debugPrint(
              '⚠️ Apple Music Backend returned unknown status: ${data['status']}');
          return null;
        }
      } else {
        debugPrint('❌ Apple Music Backend Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('💥 Apple Music Backend Exception: $e');
      return null;
    }
  }

  static Future<bool> downloadFile(String remoteUrl, String localPath,
      {Function(double progress, int receivedBytes, int totalBytes)? onProgress,
      bool Function()? isCancelled}) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(remoteUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) return false;

      final isFlacRequest = localPath.toLowerCase().endsWith('.flac');
      final tempDir = await getTemporaryDirectory();
      final timeStamp = DateTime.now().millisecondsSinceEpoch;

      final String tempDownloadPath = isFlacRequest
          ? '${tempDir.path}/am_dl_$timeStamp.m4a'
          : localPath;

      final file = File(tempDownloadPath);
      if (!file.parent.existsSync()) {
        await file.parent.create(recursive: true);
      }

      final total = response.contentLength ?? 0;
      int received = 0;

      final sink = file.openWrite();
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 30))) {
        if (isCancelled != null && isCancelled()) {
          await sink.close();
          final f = File(tempDownloadPath);
          if (await f.exists()) await f.delete();
          return false;
        }
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null) {
          onProgress(total > 0 ? (received / total) : 0.0, received, total);
        }
      }
      await sink.close();

      if (globalRef != null && received > 0) {
        globalRef!.read(dataUsageProvider.notifier).addBytes(received);
      }

      if (isFlacRequest) {
        final tempFlacPath = '${tempDir.path}/am_flac_$timeStamp.flac';
        bool transcodeSuccess = false;

        // Pre-transcode diagnostics
        final inputFile = File(tempDownloadPath);
        final inputExists = await inputFile.exists();
        final inputSize = inputExists ? await inputFile.length() : 0;
        DebugLogService().info('🔍 [FFmpeg] Input: $tempDownloadPath | exists=$inputExists | size=${(inputSize / 1024).toStringAsFixed(1)}KB');
        DebugLogService().info('🔍 [FFmpeg] Output target: $tempFlacPath');

        // Test if temp dir is writable by native code
        final testFile = File('${tempDir.path}/ffmpeg_write_test_$timeStamp.tmp');
        try {
          await testFile.writeAsString('test');
          final testExists = await testFile.exists();
          DebugLogService().info('🔍 [FFmpeg] Temp dir writable=$testExists (${tempDir.path})');
          if (testExists) await testFile.delete();
        } catch (e) {
          DebugLogService().error('🔍 [FFmpeg] Temp dir NOT writable: $e');
        }

        if (!inputExists || inputSize == 0) {
          DebugLogService().error('❌ [FFmpeg] Input file missing or empty! Cannot transcode.');
        } else if (Platform.isAndroid || Platform.isIOS) {
          // First: check if FLAC encoder is available in this FFmpegKit build
          try {
            final encoderSession = await FFmpegKit.executeWithArguments(['-encoders']);
            final encoderOutput = await encoderSession.getLogsAsString();
            final hasFlacEncoder = encoderOutput.contains('flac');
            DebugLogService().info('🔍 [FFmpeg] FLAC encoder available: $hasFlacEncoder');
            if (!hasFlacEncoder) {
              DebugLogService().error('❌ [FFmpeg] FLAC encoder NOT compiled in this FFmpegKit build!');
            }
          } catch (e) {
            DebugLogService().error('🔍 [FFmpeg] Could not check encoders: $e');
          }

          // -vn strips embedded album art (MJPEG) which FFmpegKit audio build can't re-encode as PNG
          final attempts = [
            ['-y', '-i', tempDownloadPath, '-vn', '-c:a', 'flac', tempFlacPath],
          ];

          for (int i = 0; i < attempts.length; i++) {
            final args = attempts[i];
            try {
              DebugLogService().info('🎵 [FFmpeg] Attempt ${i + 1}/${attempts.length}: ${args.join(" ")}');
              final session = await FFmpegKit.executeWithArguments(args);
              final returnCode = await session.getReturnCode();
              final rc = returnCode?.getValue() ?? -999;
              final createdFlac = File(tempFlacPath);
              final flacExists = await createdFlac.exists();
              final flacSize = flacExists ? await createdFlac.length() : 0;

              DebugLogService().info('🔍 [FFmpeg] Attempt ${i + 1} result: rc=$rc | flacExists=$flacExists | flacSize=${(flacSize / 1024).toStringAsFixed(1)}KB');

              if (ReturnCode.isSuccess(returnCode) && flacExists && flacSize > 0) {
                DebugLogService().success('✅ [FFmpeg] Transcode successful! rc=$rc, size=${(flacSize / 1024).toStringAsFixed(1)}KB');
                transcodeSuccess = true;
                break;
              } else {
                final allLogs = await session.getLogsAsString();
                // Filter for actual error lines (skip the build header and metadata)
                final logLines = allLogs.trim().split('\n');
                final errorLines = logLines.where((line) =>
                    line.toLowerCase().contains('error') ||
                    line.toLowerCase().contains('invalid') ||
                    line.toLowerCase().contains('not found') ||
                    line.toLowerCase().contains('not supported') ||
                    line.toLowerCase().contains('unknown') ||
                    line.toLowerCase().contains('conversion failed') ||
                    line.toLowerCase().contains('no such') ||
                    line.toLowerCase().contains('permission') ||
                    line.toLowerCase().contains('encoder') ||
                    line.startsWith('Output ')
                ).toList();

                if (errorLines.isNotEmpty) {
                  DebugLogService().warning('⚠️ [FFmpeg] Attempt ${i + 1} ERRORS:\n${errorLines.join("\n")}');
                } else {
                  // Fallback: show last 20 lines
                  final tail = logLines.length > 20
                      ? logLines.sublist(logLines.length - 20).join('\n')
                      : allLogs;
                  DebugLogService().warning('⚠️ [FFmpeg] Attempt ${i + 1} FAILED (rc=$rc, no error keyword found):\n$tail');
                }
              }
            } catch (e) {
              DebugLogService().error('⚠️ [FFmpeg] Attempt ${i + 1} Exception: $e');
            }
          }

          if (!transcodeSuccess) {
            DebugLogService().error('❌ [FFmpeg] All ${attempts.length} transcode attempts failed for ALAC -> FLAC.');
          }
        } else {
          final ffmpegPath = await MetadataService.getFFmpegPath();
          if (ffmpegPath != null) {
            final attempts = [
              ['-y', '-i', tempDownloadPath, tempFlacPath],
              ['-y', '-i', tempDownloadPath, '-c:a', 'flac', tempFlacPath],
            ];
            for (final args in attempts) {
              final process = await Process.run(ffmpegPath, args);
              final createdFlac = File(tempFlacPath);
              if (process.exitCode == 0 &&
                  await createdFlac.exists() &&
                  await createdFlac.length() > 0) {
                transcodeSuccess = true;
                break;
              }
            }
          }
        }

        final targetFile = File(localPath);
        if (!targetFile.parent.existsSync()) {
          await targetFile.parent.create(recursive: true);
        }

        if (transcodeSuccess) {
          await File(tempFlacPath).copy(localPath);
          final tempFlac = File(tempFlacPath);
          if (await tempFlac.exists()) await tempFlac.delete();

          final tempAlac = File(tempDownloadPath);
          if (await tempAlac.exists()) await tempAlac.delete();
          debugPrint('✅ FLAC Transcode complete: $localPath');
          return true;
        } else {
          // Fallback: If FLAC conversion fails, save downloaded ALAC file as .m4a
          debugPrint('⚠️ FLAC conversion failed. Falling back to saving ALAC (.m4a) file...');
          final fallbackM4aPath = '${localPath.substring(0, localPath.length - 5)}.m4a';
          final fallbackFile = File(fallbackM4aPath);
          if (!fallbackFile.parent.existsSync()) {
            await fallbackFile.parent.create(recursive: true);
          }
          await File(tempDownloadPath).copy(fallbackM4aPath);
          final tempAlac = File(tempDownloadPath);
          if (await tempAlac.exists()) await tempAlac.delete();

          debugPrint('✅ Saved ALAC fallback: $fallbackM4aPath');
          return true;
        }
      }

      return true;
    } catch (e) {
      debugPrint('Apple Music Local Download Error: $e');
      return false;
    }
  }

  /// Download audio from a Gofile link directly from the client's network.
  /// Uses GoFileDownloader approach: dynamic X-Website-Token via SHA-256.
  /// Returns a local file path to the downloaded file, or null on failure.
  static Future<String?> _downloadFromGofile(String gofileUrl) async {
    try {
      final contentId =
          gofileUrl.split('/d/').last.split('?').first.split('#').first;
      debugPrint('🔄 Gofile: Downloading content $contentId from client...');

      const userAgent =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

      // Step 1: Create guest account
      final accRes = await http.post(
        Uri.parse('https://api.gofile.io/accounts'),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 30));
      final accData = json.decode(accRes.body);
      if (accData['status'] != 'ok') {
        debugPrint('❌ Gofile: Guest account failed: ${accData['status']}');
        return null;
      }
      final token = accData['data']['token'] as String;
      debugPrint('✓ Gofile: Got guest token');

      // Step 2: Get wt from config.js (static value, not SHA-256)
      String wt = '';
      try {
        final configRes = await http.get(
          Uri.parse('https://gofile.io/dist/js/config.js'),
          headers: {'User-Agent': userAgent},
        ).timeout(const Duration(seconds: 15));
        if (configRes.statusCode == 200) {
          final match =
              RegExp(r'appdata\.wt\s*=\s*"([^"]+)"').firstMatch(configRes.body);
          if (match != null) {
            wt = match.group(1)!;
            debugPrint(
                '✓ Gofile: Got wt from config.js: ${wt.substring(0, wt.length > 8 ? 8 : wt.length)}...');
          }
        }
      } catch (e) {
        debugPrint('⚠ Gofile: config.js fetch failed: $e');
      }

      // If config.js failed, generate wt via SHA-256 (GoFileDownloader approach)
      if (wt.isEmpty) {
        final timeWindow =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ 14400;
        final tokenSeed =
            '$userAgent::en-US::$token::$timeWindow::5d4f7g8sd45fsd';
        wt = crypto.sha256.convert(utf8.encode(tokenSeed)).toString();
        debugPrint(
            '✓ Gofile: Generated wt via SHA-256: ${wt.substring(0, 16)}...');
      }

      // Step 3: Try API first
      Map<String, dynamic>? contentData;
      try {
        final contentRes = await http.get(
          Uri.parse('https://api.gofile.io/contents/$contentId'),
          headers: {
            'Authorization': 'Bearer $token',
            'X-Website-Token': wt,
            'User-Agent': userAgent,
          },
        ).timeout(const Duration(seconds: 45));
        contentData = json.decode(contentRes.body) as Map<String, dynamic>;
        debugPrint('🔍 Gofile API: ${contentData['status']}');
      } catch (e) {
        debugPrint('⚠ Gofile: API request failed: $e');
      }

      // Step 4: If API fails with notPremium, try web session fallback
      if (contentData == null || contentData['status'] != 'ok') {
        debugPrint('🔄 Gofile: Trying web session fallback...');
        try {
          // Visit the page first to establish session cookies
          final pageRes = await http.get(
            Uri.parse('https://gofile.io/d/$contentId'),
            headers: {
              'User-Agent': userAgent,
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.5',
              'Referer': 'https://gofile.io/',
            },
          ).timeout(const Duration(seconds: 30));

          // Extract cookies from page response
          final cookies = pageRes.headers['set-cookie'] ?? '';
          debugPrint(
              '✓ Gofile: Page visited, cookies: ${cookies.isNotEmpty ? 'yes' : 'none'}');

          // Retry API with browser-like session
          final retryRes = await http.get(
            Uri.parse('https://api.gofile.io/contents/$contentId'),
            headers: {
              'User-Agent': userAgent,
              'Accept': 'application/json',
              'Accept-Language': 'en-US,en;q=0.5',
              'Origin': 'https://gofile.io',
              'Referer': 'https://gofile.io/d/$contentId',
              'Authorization': 'Bearer $token',
              'X-Website-Token': wt,
              'Cookie':
                  'accountToken=$token${cookies.isNotEmpty ? '; $cookies' : ''}',
            },
          ).timeout(const Duration(seconds: 45));
          contentData = json.decode(retryRes.body) as Map<String, dynamic>;
          debugPrint('🔍 Gofile web fallback: ${contentData['status']}');
        } catch (e) {
          debugPrint('❌ Gofile: Web fallback failed: $e');
          return null;
        }
      }

      if (contentData['status'] != 'ok') {
        debugPrint('❌ Gofile: All methods failed: ${contentData['status']}');
        return null;
      }

      // Step 5: Extract and download audio files
      final data = contentData['data'] as Map<String, dynamic>;
      final children = data['children'] ?? data['contents'] ?? {};
      Map<String, dynamic> fileMap;
      if (children is Map) {
        fileMap = Map<String, dynamic>.from(children);
      } else {
        debugPrint('❌ Gofile: Unexpected children format');
        return null;
      }

      for (final entry in fileMap.values) {
        if (entry['type'] != 'file') continue;
        final fileName = entry['name'] as String? ?? 'download.m4a';
        final downloadUrl = entry['link'] as String?;
        if (downloadUrl == null) continue;

        final ext = fileName.toLowerCase();
        if (!ext.endsWith('.m4a') &&
            !ext.endsWith('.flac') &&
            !ext.endsWith('.mp3') &&
            !ext.endsWith('.alac')) {
          continue;
        }

        debugPrint('⬇ Gofile: Downloading $fileName...');
        final tempDir = await Directory.systemTemp.createTemp('gofile_');
        final filePath = '${tempDir.path}/$fileName';

        final fileRes = await http.get(
          Uri.parse(downloadUrl),
          headers: {
            'Cookie': 'accountToken=$token',
            'User-Agent': userAgent,
          },
        ).timeout(const Duration(seconds: 300));

        if (fileRes.statusCode == 200 && fileRes.bodyBytes.length > 1024) {
          await File(filePath).writeAsBytes(fileRes.bodyBytes);
          debugPrint(
              '✓ Gofile: Downloaded to $filePath (${fileRes.bodyBytes.length} bytes)');
          return filePath;
        } else {
          debugPrint(
              '❌ Gofile: Download failed — status ${fileRes.statusCode}, size ${fileRes.bodyBytes.length}');
        }
      }

      debugPrint('❌ Gofile: No audio files found');
      return null;
    } catch (e) {
      debugPrint('💥 Gofile direct download error: $e');
      return null;
    }
  }
}
