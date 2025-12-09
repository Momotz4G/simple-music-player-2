import 'package:soundcloud_explode_dart/soundcloud_explode_dart.dart';

class SoundcloudService {
  final SoundcloudClient _sc = SoundcloudClient();

  Future<String?> getAudioStream(String title, String artist) async {
    try {
      final query = "$title - $artist";
      // 1. Search for the track
      final resultStream = _sc.search(query, searchFilter: SearchFilter.tracks);

      // 2. Get the first batch of results
      final firstBatch = await resultStream.first;

      if (firstBatch.isEmpty) return null;

      // 🛑 FIX IS HERE: Explicitly cast the result to 'Track'
      // The search returns a generic 'SearchResult', so we must tell Dart
      // "This is definitely a Track" to access .title and .id
      final basicResult = firstBatch.first;
      if (basicResult is! Track) return null;

      final Track track = basicResult as Track; // Explicit casting

      print("✅ SoundCloud Match: ${track.title}");

      // 3. Get the list of streams using the Track ID
      final streams = await _sc.tracks.getStreams(track.id);
      if (streams.isEmpty) return null;

      // 4. Select the best stream (Progressive MP3 preferred)
      final bestStream = streams.firstWhere(
          (s) => s.container.toString().toLowerCase().contains('mp3'),
          orElse: () => streams.first);

      return bestStream.url.toString();
    } catch (e) {
      print("SoundCloud Error: $e");
      return null;
    }
  }

  void dispose() {
    // SoundcloudClient doesn't require manual disposal
  }
}
