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
