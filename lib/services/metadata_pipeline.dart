import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metadata_god/metadata_god.dart';
import '../services/spotify_service.dart';

/// A unified result object that the UI will use.
class RecognitionResult {
  final String title;
  final String artist;
  final String album;
  final String? albumArtUrl;
  final String? spotifyId;
  final String? releaseYear;
  final double confidence;

  RecognitionResult({
    required this.title,
    required this.artist,
    this.album = '',
    this.albumArtUrl,
    this.spotifyId,
    this.releaseYear,
    required this.confidence,
  });
}

final metadataPipelineProvider = Provider((ref) => MetadataPipeline());

class MetadataPipeline {
  Future<RecognitionResult?> resolveSong(String filePath) async {
    try {
      print("Pipeline: Reading local tags for metadata...");

      // 1. Read tags directly from the file (No FFI/Fingerprinting)
      final metadata = await MetadataGod.readMetadata(file: filePath);

      final localTitle = metadata.title ?? "";
      final localArtist = metadata.artist ?? "";

      // If the file has no title, we can't search for it.
      if (localTitle.isEmpty) {
        print("Pipeline: No title found in file tags. Cannot perform lookup.");
        return null;
      }

      print("Pipeline: Found Tags -> '$localTitle' by '$localArtist'");
      print("Pipeline: Searching Spotify...");

      // 2. Search Spotify using the tags
      // If artist is unknown, we just search the title.
      final query =
          localArtist.isNotEmpty ? "$localTitle $localArtist" : localTitle;

      final spotifyResults = await SpotifyService.searchMetadata(query);

      if (spotifyResults.isNotEmpty) {
        final track = spotifyResults.first;
        print("Pipeline: Spotify Sync Success -> ${track['title']}");

        return RecognitionResult(
          title: track['title'],
          artist: track['artist'],
          album: track['album'],
          albumArtUrl: track['image_url'],
          spotifyId: track['spotify_id'],
          releaseYear: track['year'],
          confidence: 1.0, // High confidence because we matched text
        );
      }

      print(
          "Pipeline: Spotify returned no results. Falling back to local tags.");

      // 3. Fallback: Return basic info from file tags if Spotify fails
      return RecognitionResult(
        title: localTitle,
        artist: localArtist.isNotEmpty ? localArtist : "Unknown Artist",
        album: metadata.album ?? "Unknown Album",
        confidence: 0.5, // Lower confidence since it's just raw tags
      );
    } catch (e) {
      print("Pipeline Error: $e");
      return null;
    }
  }
}
