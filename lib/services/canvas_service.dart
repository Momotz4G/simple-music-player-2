import 'dart:io';
import 'dart:isolate';
import 'dart:convert'; // needed for encoding
import 'package:html/parser.dart' as parser;
import 'package:path_provider/path_provider.dart'; // Added
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added
import '../providers/data_usage_provider.dart'; // Added
import 'pocketbase_service.dart'; // 🔒 OFFLINE MODE
import 'debug_log_service.dart';

final canvasCacheInvalidationProvider = StateProvider<int>((ref) => 0);

class CanvasService {
  static const String _baseUrl = "https://www.canvasdownloader.com/canvas";
  static Ref? globalRef; // Added for Data Usage tracking
  static final Set<String> _activeDownloads = {};

  static Future<File?> downloadCanvasToCache(String videoUrl) async {
    if (PocketBaseService.isOffline || !PocketBaseService.enableCanvas) return null; // 🔒 OFFLINE or Canvas Disabled
    
    if (_activeDownloads.contains(videoUrl)) {
      DebugLogService().info("ℹ️ [CanvasService] Download already in progress for: $videoUrl");
      return null;
    }

    try {
      _activeDownloads.add(videoUrl);
      final tempDir = await getTemporaryDirectory();
      // Safe file name from URL
      final hashedName = '${videoUrl.replaceAll(RegExp(r'[^\w]'), '_')}.mp4';
      final cacheDir = Directory('${tempDir.path}/canvas_cache');
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);

      // 🧹 Auto-cleanup cache if total size > 50MB or file is > 2 days old
      _cleanupCacheIfNeeded(cacheDir);

      final cacheFile = File('${cacheDir.path}/$hashedName');

      if (await cacheFile.exists()) {
        final size = await cacheFile.length();
        if (size > 1024) {
          DebugLogService().info("ℹ️ [CanvasService] Already cached and valid size: $hashedName");
          return cacheFile; // Already cached and valid size
        }
      }

      final bool isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      int totalBytes = 0;

      if (isDesktop) {
        // Offload download to an isolate to prevent UI thread from hanging on Desktop
        totalBytes = await Isolate.run(() async {
          final client = HttpClient()
            ..badCertificateCallback =
                (X509Certificate cert, String host, int port) => true;

          final request = await client.getUrl(Uri.parse(videoUrl));
          request.headers.set(HttpHeaders.userAgentHeader,
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
          final response = await request.close();

          if (response.statusCode != 200) return 0;

          final sink = cacheFile.openWrite();
          int chunkAccumulator = 0;

          await for (final chunk in response) {
            sink.add(chunk);
            chunkAccumulator += chunk.length;
          }

          await sink.close();
          return chunkAccumulator;
        });
      } else {
        // Perform async download natively on mobile (Isolates can drop networking on Android)
        DebugLogService().info("🌐 [CanvasService] Starting native Mobile download...");
        final client = HttpClient()
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;

        final request = await client.getUrl(Uri.parse(videoUrl));
        request.headers.set(HttpHeaders.userAgentHeader,
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
        final response = await request.close();

        DebugLogService().info("🌐 [CanvasService] Native Download Status: ${response.statusCode}");

        if (response.statusCode == 200) {
          final sink = cacheFile.openWrite();
          int chunkAccumulator = 0;

          await for (final chunk in response) {
            sink.add(chunk);
            chunkAccumulator += chunk.length;
          }

          await sink.close();
          totalBytes = chunkAccumulator;
          DebugLogService().info("✅ [CanvasService] Native Download Complete: $totalBytes bytes");
        } else {
          DebugLogService().error("❌ [CanvasService] Native Download Failed with status ${response.statusCode}");
        }
      }

      if (totalBytes > 0) {
        if (globalRef != null) {
          globalRef!.read(dataUsageProvider.notifier).addBytes(totalBytes);
        }
        return cacheFile;
      }
    } catch (e) {
      DebugLogService().error("❌ Canvas Cache Error: $e");
    } finally {
      _activeDownloads.remove(videoUrl);
    }
    return null;
  }

  static Future<File?> getCachedCanvasFile(String videoUrl) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final hashedName = '${videoUrl.replaceAll(RegExp(r'[^\w]'), '_')}.mp4';
      final cacheFile = File('${tempDir.path}/canvas_cache/$hashedName');
      if (await cacheFile.exists()) {
        final size = await cacheFile.length();
        if (size > 1024) return cacheFile;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> getCanvasUrl(String spotifyTrackUrl) async {
    if (PocketBaseService.isOffline || !PocketBaseService.enableCanvas) return null; // 🔒 OFFLINE or Canvas Disabled
    try {
      final uri =
          Uri.parse("$_baseUrl?link=${Uri.encodeComponent(spotifyTrackUrl)}");

      // 1. Custom Client (Bypass SSL)
      final client = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader,
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");

      final response = await request.close();

      if (response.statusCode != 200) return null;

      // 2. Read Body
      final body = await response.transform(utf8.decoder).join();

      // 3. Parse
      var document = parser.parse(body);
      var sourceElement = document.querySelector('source[src*=".mp4"]');

      if (sourceElement != null) {
        final videoUrl = sourceElement.attributes['src'];
        DebugLogService().info("✅ Found Canvas URL: $videoUrl");
        return videoUrl;
      } else {
        DebugLogService().error("⚠️ CanvasService: No <source> element with .mp4 found in response.");
      }
    } catch (e) {
      DebugLogService().error("❌ Scraping Error: $e");
    }
    return null;
  }

  static Future<String?> getAppleMusicAnimatedArtworkUrl(String title, String artist, {bool preferVertical = false, bool preferHls = false}) async {
    if (PocketBaseService.isOffline || !PocketBaseService.enableCanvas) return null; // 🔒 OFFLINE or Canvas Disabled
    try {
      final uri = Uri.parse("https://artwork.boidu.dev/artwork?s=${Uri.encodeComponent(title)}&a=${Uri.encodeComponent(artist)}");

      // Custom Client (Bypass SSL)
      final client = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader,
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");

      final response = await request.close();

      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = json.decode(body);

      DebugLogService().info("🍎 [Apple Music Artwork API] Fetched metadata successfully.");

      final videoUrl = data['videoUrl'] as String?;
      final videoUrlVertical = data['videoUrlVertical'] as String?;
      final hlsUrl = data['animated'] as String?;
      final hlsUrlVertical = data['animatedVertical'] as String?;

      if (preferHls) {
        if (preferVertical) {
          return hlsUrlVertical ?? hlsUrl ?? videoUrlVertical ?? videoUrl;
        } else {
          return hlsUrl ?? hlsUrlVertical ?? videoUrl ?? videoUrlVertical;
        }
      } else {
        if (preferVertical) {
          return videoUrlVertical ?? videoUrl ?? hlsUrlVertical ?? hlsUrl;
        } else {
          return videoUrl ?? videoUrlVertical ?? hlsUrl ?? hlsUrlVertical;
        }
      }
    } catch (e) {
      DebugLogService().error("❌ Apple Music Artwork API Error: $e");
    }
    return null;
  }

  /// Downscale Apple Music video URL for mobile devices.
  /// Apple Music video URLs contain resolution in format '_WxH-' (e.g. '_2160x2160-').
  /// On mobile, cap to [maxDimension] to avoid decode failures on Android's ExoPlayer.
  static String downscaleAppleMusicUrl(String url, {int maxDimension = 720}) {
    // Return original URL because Apple CDN serves static files and changing
    // the dimension values in the file name leads to 404 errors.
    return url;
  }

  /// Clean up old canvas cache files if total size > 50MB or > 2 days old
  static Future<void> _cleanupCacheIfNeeded(Directory cacheDir) async {
    try {
      final files = cacheDir.listSync().whereType<File>().toList();
      final now = DateTime.now();
      int totalSize = 0;

      // Delete files older than 2 days
      for (var file in files) {
        final lastModified = file.lastModifiedSync();
        if (now.difference(lastModified).inDays >= 2) {
          try { file.deleteSync(); } catch (_) {}
        } else {
          totalSize += file.lengthSync();
        }
      }

      // If total size > 50MB (50 * 1024 * 1024), delete oldest files first
      if (totalSize > 50 * 1024 * 1024) {
        final remainingFiles = cacheDir.listSync().whereType<File>().toList();
        remainingFiles.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        for (var file in remainingFiles) {
          if (totalSize <= 30 * 1024 * 1024) break; // Trim down to 30MB
          totalSize -= file.lengthSync();
          try { file.deleteSync(); } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
