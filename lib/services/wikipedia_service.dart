import 'dart:convert';
import 'package:http/http.dart' as http;

class WikipediaService {
  /// Fetches the main image URL for an artist from Wikipedia.

  /// 1. Searches for the artist page using OpenSearch.
  /// 2. Fetches the page info to get the 'original' source of the main image.
  static Future<String?> getArtistImage(String artistName) async {
    try {
      // 1. Search for the page
      final searchUri = Uri.parse(
          "https://en.wikipedia.org/w/api.php?action=opensearch&search=$artistName&limit=1&namespace=0&format=json");

      final searchResponse = await http.get(searchUri);

      if (searchResponse.statusCode == 200) {
        final searchData = jsonDecode(searchResponse.body) as List;
        if (searchData.length > 1) {
          final titles = searchData[1] as List;
          if (titles.isNotEmpty) {
            final pageTitle = titles[0] as String;

            // 2. Get Page Image
            return await _getPageImage(pageTitle);
          }
        }
      }
    } catch (e) {
      print("Wikipedia Search Error: $e");
    }
    return null;
  }

  static Future<String?> _getPageImage(String pageTitle) async {
    try {
      final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'titles': pageTitle,
        'prop': 'pageimages',
        'format': 'json',
        'pithumbsize': '1000', // Request large thumbnail
        'piadjust': 'auto',
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']['pages'] as Map<String, dynamic>;

        if (pages.isNotEmpty) {
          final pageId = pages.keys.first;
          final page = pages[pageId];

          if (page['thumbnail'] != null) {
            return page['thumbnail']['source'];
          }
        }
      }
    } catch (e) {
      print("Wikipedia Image Error: $e");
    }
    return null;
  }
}
