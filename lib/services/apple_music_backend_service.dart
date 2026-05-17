import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_usage_provider.dart';
import '../env/env.dart';

class AppleMusicBackendService {
  static Ref? globalRef; // Added for Data Usage tracking
  static String get _baseUrl => Env.appleMusicApiUrl;

  /// Sends the Apple Music URL to the VPS backend to be fetched via Telegram.
  /// Returns the absolute URL for the `.m4a` ALAC file hosted on the VPS.
  /// [onQueueUpdate] is called with the current queue position.
  static Future<String?> requestDownload(
    String appleMusicUrl, {
    bool fetchLyrics = false,
    String? title,
    String? artist,
    Function(int)? onQueueUpdate,
  }) async {
    try {
      debugPrint('🎵 Sending Apple Music link to VPS for processing...');
      final url = Uri.parse('$_baseUrl/download');

      final body = {
        'url': appleMusicUrl,
        'fetch_lyrics': fetchLyrics,
      };
      if (title != null) body['title'] = title;
      if (artist != null) body['artist'] = artist;

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 180));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'queued') {
          final taskId = data['task_id'] as String;
          debugPrint('✅ Task queued: $taskId');

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
          debugPrint('🔄 Gofile fallback: VPS blocked, trying direct download from $gofileUrl');
          final directUrl = await _downloadFromGofile(gofileUrl);
          if (directUrl != null) {
            return directUrl;
          }
          // Throw specific exception for the UI to show a beautiful interactive popup
          throw Exception('GOFILE_FALLBACK_URL:$gofileUrl');
        } else {
          debugPrint('⚠️ Apple Music Backend returned unknown status: ${data['status']}');
          return null;
        }
      } else {
        debugPrint('❌ Apple Music Backend Error: ${response.statusCode} — ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('💥 Apple Music Backend Exception: $e');
      if (e.toString().contains('GOFILE_FALLBACK_URL:')) {
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
      };
      if (title != null) body['title'] = title;
      if (artist != null) body['artist'] = artist;

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 180));

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
          debugPrint('⚠️ Apple Music Backend returned unknown status: ${data['status']}');
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

  /// Downloads the ALAC file from the VPS directly to the device's local storage
  static Future<bool> downloadFile(String remoteUrl, String localPath, {Function(double)? onProgress}) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(remoteUrl));
      final response = await client.send(request);
      
      if (response.statusCode != 200) return false;
      
      final file = File(localPath);
      final total = response.contentLength ?? 0;
      int received = 0;
      
      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
      await sink.close();
      
      if (globalRef != null && received > 0) {
        globalRef!.read(dataUsageProvider.notifier).addBytes(received);
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
      final contentId = gofileUrl.split('/d/').last.split('?').first.split('#').first;
      debugPrint('🔄 Gofile: Downloading content $contentId from client...');

      const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

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
          final match = RegExp(r'appdata\.wt\s*=\s*"([^"]+)"').firstMatch(configRes.body);
          if (match != null) {
            wt = match.group(1)!;
            debugPrint('✓ Gofile: Got wt from config.js: ${wt.substring(0, wt.length > 8 ? 8 : wt.length)}...');
          }
        }
      } catch (e) {
        debugPrint('⚠ Gofile: config.js fetch failed: $e');
      }

      // If config.js failed, generate wt via SHA-256 (GoFileDownloader approach)
      if (wt.isEmpty) {
        final timeWindow = (DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ 14400;
        final tokenSeed = '$userAgent::en-US::$token::$timeWindow::5d4f7g8sd45fsd';
        wt = crypto.sha256.convert(utf8.encode(tokenSeed)).toString();
        debugPrint('✓ Gofile: Generated wt via SHA-256: ${wt.substring(0, 16)}...');
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
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.5',
              'Referer': 'https://gofile.io/',
            },
          ).timeout(const Duration(seconds: 30));
          
          // Extract cookies from page response
          final cookies = pageRes.headers['set-cookie'] ?? '';
          debugPrint('✓ Gofile: Page visited, cookies: ${cookies.length > 0 ? 'yes' : 'none'}');
          
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
              'Cookie': 'accountToken=$token${cookies.isNotEmpty ? '; $cookies' : ''}',
            },
          ).timeout(const Duration(seconds: 45));
          contentData = json.decode(retryRes.body) as Map<String, dynamic>;
          debugPrint('🔍 Gofile web fallback: ${contentData['status']}');
        } catch (e) {
          debugPrint('❌ Gofile: Web fallback failed: $e');
          return null;
        }
      }

      if (contentData == null || contentData['status'] != 'ok') {
        debugPrint('❌ Gofile: All methods failed: ${contentData?['status']}');
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
        if (!ext.endsWith('.m4a') && !ext.endsWith('.flac') && !ext.endsWith('.mp3') && !ext.endsWith('.alac')) {
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
          debugPrint('✓ Gofile: Downloaded to $filePath (${fileRes.bodyBytes.length} bytes)');
          return filePath;
        } else {
          debugPrint('❌ Gofile: Download failed — status ${fileRes.statusCode}, size ${fileRes.bodyBytes.length}');
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
