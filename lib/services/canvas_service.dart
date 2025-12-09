import 'dart:io';
import 'dart:convert'; // needed for encoding
import 'package:html/parser.dart' as parser;

class CanvasService {
  static const String _baseUrl = "https://www.canvasdownloader.com/canvas";

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
      }
    } catch (e) {
      print("❌ Scraping Error: $e");
    }
    return null;
  }
}
