import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_metadata.dart';
import '../services/hybrid_service.dart';

// State for the search results panel
class DownloadSearchNotifier extends StateNotifier<List<SongMetadata>> {
  DownloadSearchNotifier() : super([]);

  Future<void> searchSpotify(String query) async {
    if (query.isEmpty) {
      state = [];
      return;
    }

    // Use HybridService to support fallback and prevent crashes
    final results = await HybridService.searchSongs(query);

    state = results;
  }
}

final downloadSearchProvider =
    StateNotifierProvider<DownloadSearchNotifier, List<SongMetadata>>((ref) {
  return DownloadSearchNotifier();
});
