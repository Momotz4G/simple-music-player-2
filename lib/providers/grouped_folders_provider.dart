import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/song_model.dart';
import 'library_provider.dart';

/// Provides a Map of Folder Name -> List of SongModel objects in that folder.
final groupedFoldersProvider = Provider<Map<String, List<SongModel>>>((ref) {
  // 🚀 Use selective watch + allSongs (unfiltered) to avoid recalculating
  // on every search keystroke — matches pattern of other grouped providers
  final isLoading = ref.watch(libraryProvider.select((p) => p.isLoading));

  if (isLoading) {
    return const {};
  }

  final songs = ref.watch(libraryProvider.select((p) => p.allSongs));
  if (songs.isEmpty) {
    return const {};
  }

  final Map<String, List<SongModel>> grouped = {};

  for (final song in songs) {
    // Get the name of the folder containing the song
    final folderPath = p.dirname(song.filePath);
    final folderName = p.basename(folderPath);

    if (!grouped.containsKey(folderName)) {
      grouped[folderName] = [];
    }
    grouped[folderName]!.add(song);
  }

  // Sort folder names alphabetically
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return {for (final key in sortedKeys) key: grouped[key]!};
});
