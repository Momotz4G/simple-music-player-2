import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/song_model.dart';
import 'library_provider.dart';

/// Provides a Map of Folder Name -> List of SongModel objects in that folder.
final groupedFoldersProvider = Provider<Map<String, List<SongModel>>>((ref) {
  final library = ref.watch(libraryProvider);

  if (library.isLoading) {
    return const {};
  }

  final songs = library.songs;
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
