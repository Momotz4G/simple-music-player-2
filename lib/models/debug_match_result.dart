// lib/models/debug_match_result.dart

// FIX: Use relative paths to access other models in the same directory.
import 'song_metadata.dart';
import 'youtube_search_result.dart';

class DebugMatchResult {
  final SongMetadata spotifyMetadata;
  final List<YoutubeSearchResult> youtubeMatches;

  DebugMatchResult({
    required this.spotifyMetadata,
    required this.youtubeMatches,
  });
}
