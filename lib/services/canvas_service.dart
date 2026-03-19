import 'dart:io';
import 'dart:convert'; // needed for encoding
import 'package:html/parser.dart' as parser;
import 'package:path_provider/path_provider.dart'; // Added
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added
import '../providers/data_usage_provider.dart'; // Added

class CanvasService {
  static const String _baseUrl = "https://www.canvasdownloader.com/canvas";
  static Ref? globalRef; // Added for Data Usage tracking

  static Future<File?> downloadCanvasToCache(String videoUrl) async {
    try {
      final tempDir = await getTemporaryDirectory();
      // Safe file name from URL
      final hashedName = videoUrl.replaceAll(RegExp(r'[^\w]'), '_') + '.mp4';
      final cacheDir = Directory('${tempDir.path}/canvas_cache');
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);

      final cacheFile = File('${cacheDir.path}/$hashedName');

      if (await cacheFile.exists()) {
        final size = await cacheFile.length();
        if (size > 1024) return cacheFile; // Already cached and valid size
      }

      // Stream download to count bytes perfectly
      final client = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

      final request = await client.getUrl(Uri.parse(videoUrl));
      final response = await request.close();

      if (response.statusCode != 200) return null;

      final sink = cacheFile.openWrite();
      int chunkAccumulator = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        chunkAccumulator += chunk.length;

        if (chunkAccumulator > 512 * 1024) { // Update every 512KB for small files
          if (globalRef != null) {
            globalRef!.read(dataUsageProvider.notifier).addBytes(chunkAccumulator);
          }
          chunkAccumulator = 0;
        }
      }

      // Flush remaining
      if (chunkAccumulator > 0 && globalRef != null) {
        globalRef!.read(dataUsageProvider.notifier).addBytes(chunkAccumulator);
      }

      await sink.close();
      return cacheFile;
    } catch (e) {
      // ignore: avoid_print
      print("❌ Canvas Cache Error: $e");
    }
    return null;
  }

  static Future<String?> getCanvasUrl(String spotifyTrackUrl) async {
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
        print("✅ Found Canvas URL: $videoUrl");
        return videoUrl;
      } else {
        print("⚠️ CanvasService: No <source> element with .mp4 found in response.");
      }
    } catch (e) {
      print("❌ Scraping Error: $e");
    }
    return null;
  }
}
