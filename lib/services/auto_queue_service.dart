import '../models/song_model.dart';
import '../models/song_metadata.dart';
import 'spotify_service.dart';

/// Service for managing the Endless Queue feature
/// Automatically fetches and adds similar songs to keep the queue going
class AutoQueueService {
  // Cache to avoid duplicate recommendations in a session
  final Set<String> _recentlyRecommended = {};

  // Debounce flag to prevent multiple simultaneous fetches
  bool _isFetching = false;

  // Last fetch time for rate limiting
  DateTime? _lastFetchTime;
  static const Duration _minFetchInterval = Duration(seconds: 10);

  AutoQueueService();

  /// Fetches 20 recommended songs based on the current song
  /// Returns SongModel list ready to add to queue
  Future<List<SongModel>> getRecommendedSongs(SongModel currentSong) async {
    // Rate limiting
    if (_isFetching) {
      print("⏳ AutoQueue: Already fetching, skipping...");
      return [];
    }

    if (_lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _minFetchInterval) {
      print("⏳ AutoQueue: Rate limited, skipping...");
      return [];
    }

    _isFetching = true;
    _lastFetchTime = DateTime.now();

    try {
      // Try to get Spotify track ID if not already present
      String? trackId = currentSong.spotifyId;
      String? artistId = currentSong.spotifyArtistId;

      // If we don't have spotify IDs, try to look them up
      if (trackId == null) {
        trackId = await SpotifyService.getTrackId(
          currentSong.title,
          currentSong.artist,
        );
      }

      // If we still don't have track ID, try artist ID
      if (trackId == null && artistId == null) {
        artistId = await SpotifyService.getArtistId(
          artistName: currentSong.artist,
          trackTitle: currentSong.title,
        );
      }

      // If we still have no seeds, try a simpler search
      if (trackId == null && artistId == null) {
        // Try just artist name search
        artistId = await SpotifyService.getArtistId(
          artistName: currentSong.artist,
        );
      }

      // If STILL no seeds, we can't get recommendations
      if (trackId == null && artistId == null) {
        return [];
      }

      List<SongMetadata> recommendations = await SpotifyService.getRecommendations(
        seedTracks: trackId != null ? [trackId] : null,
        seedArtists: artistId != null ? [artistId] : null,
        limit: 20,
      );

      // Filter out recently recommended songs
      recommendations = recommendations.where((meta) {
        final key = "${meta.title.toLowerCase()}_${meta.artist.toLowerCase()}";
        if (_recentlyRecommended.contains(key)) {
          return false;
        }
        _recentlyRecommended.add(key);
        return true;
      }).toList();

      // Also filter out current song
      recommendations = recommendations
          .where((meta) =>
              meta.title.toLowerCase() != currentSong.title.toLowerCase() ||
              meta.artist.toLowerCase() != currentSong.artist.toLowerCase())
          .toList();

      // Limit cache size
      if (_recentlyRecommended.length > 100) {
        _recentlyRecommended.clear();
      }

      // Convert SongMetadata to SongModel
      final songs =
          recommendations.map((meta) => _metadataToSongModel(meta)).toList();

      print(
          "✅ AutoQueue: Got ${songs.length} recommendations for '${currentSong.title}'");
      return songs;
    } finally {
      _isFetching = false;
    }
  }

  /// Convert SongMetadata to SongModel for playback
  SongModel _metadataToSongModel(SongMetadata meta) {
    return SongModel(
      title: meta.title,
      artist: meta.artist,
      album: meta.album,
      filePath: "", // Will be JIT cached when playing
      fileExtension: "mp3",
      duration: meta.durationSeconds.toDouble(),
      onlineArtUrl: meta.albumArtUrl,
      isrc: meta.isrc,
      spotifyId: meta.spotifyId,
      spotifyArtistId: meta.spotifyArtistId,
      trackNumber: meta.trackNumber,
      discNumber: meta.discNumber,
      year: meta.year,
      genre: meta.genre,
    );
  }

  /// Reset the recommendation cache (call when starting new playlist)
  void resetCache() {
    _recentlyRecommended.clear();
    // print("🔄 AutoQueue: Cache cleared");
  }

  /// Check if we should fetch more recommendations
  bool shouldFetchMore(int remainingInQueue) {
    return remainingInQueue < 3;
  }
}
