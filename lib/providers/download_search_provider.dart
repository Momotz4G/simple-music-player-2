// lib/providers/download_search_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_metadata.dart';
import '../services/spotify_service.dart';

// State for the search results panel
class DownloadSearchNotifier extends StateNotifier<List<SongMetadata>> {
  DownloadSearchNotifier() : super([]);

  Future<void> searchSpotify(String query) async {
    if (query.isEmpty) {
      state = [];
      return;
    }

    // THIS NOW CALLS THE NEW METHOD ADDED TO SpotifyService
    final results = await SpotifyService.searchTracks(query);

    state = results;
  }
}

final downloadSearchProvider =
    StateNotifierProvider<DownloadSearchNotifier, List<SongMetadata>>((ref) {
  return DownloadSearchNotifier();
});
