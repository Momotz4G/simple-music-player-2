import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_model.dart';
import 'library_provider.dart';

final groupedAlbumsProvider = Provider<Map<String, List<SongModel>>>((ref) {
  final library = ref.watch(libraryProvider);
  final songs = library.songs;

  final Map<String, List<SongModel>> grouped = {};

  for (final song in songs) {
    final album = song.album.isNotEmpty ? song.album : "Unknown Album";
    if (!grouped.containsKey(album)) {
      grouped[album] = [];
    }
    grouped[album]!.add(song);
  }

  // Sort albums alphabetically
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final Map<String, List<SongModel>> sortedGrouped = {
    for (final key in sortedKeys) key: grouped[key]!
  };

  return sortedGrouped;
});
