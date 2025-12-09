import 'dart:convert';
import 'package:http/http.dart' as http;

// This service mimics the function of specialized sites like 9xbuddy.
class ExternalAudioService {
  // Use a reliable proxy/conversion API for stability.
  final String _apiUrl = "https://yt-api.com/api";

  // You will need a simple, free API key for this specific service.
  // Replace 'YOUR_RAPIDAPI_KEY' with a key obtained from a service like RapidAPI
  // that hosts the yt-api.com endpoint.
  final String _apiKey = "YOUR_RAPIDAPI_KEY";

  /// Downloads the MP3 link from a YouTube video ID.
  Future<String?> getMp3LinkFromId(String youtubeId) async {
    final youtubeUrl = 'https://www.youtube.com/watch?v=$youtubeId';

    try {
      final uri = Uri.parse(_apiUrl).replace(queryParameters: {
        'url': youtubeUrl,
        'format': 'mp3',
        'type': 'download',
      });

      final response = await http.get(uri, headers: {
        // You must provide an API key for this service
        'X-RapidAPI-Key': _apiKey,
        'X-RapidAPI-Host': 'yt-api.com',
      }).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check for download link in response
        if (data['status'] == 'success' && data['result']['url'] != null) {
          return data['result']['url'];
        }
      }
      print('⚠️ External API failed (Status: ${response.statusCode})');
    } catch (e) {
      print('❌ Error contacting external API: $e');
    }
    return null;
  }
}
