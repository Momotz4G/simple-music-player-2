import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_metadata.dart';
import '../models/album_model.dart';
import '../models/song_model.dart';

// Holds the song selected from the Global Search Bar
final searchBridgeProvider = StateProvider<SongMetadata?>((ref) => null);

// --- NAVIGATION STACK IMPLEMENTATION ---

enum NavigationType {
  none,
  artist,
  album,
  playlist,
}

class NavigationItem {
  final NavigationType type;
  final dynamic data; // ArtistSelection, AlbumModel, or String (Playlist ID)

  NavigationItem({required this.type, required this.data});
}

class NavigationStackNotifier extends StateNotifier<List<NavigationItem>> {
  NavigationStackNotifier() : super([]);

  void push(NavigationItem item) {
    // Avoid duplicates at the top of the stack
    if (state.isNotEmpty) {
      final top = state.last;
      if (top.type == item.type && top.data == item.data) return;
    }
    state = [...state, item];
  }

  void pop() {
    if (state.isNotEmpty) {
      state = state.sublist(0, state.length - 1);
    }
  }

  void clear() {
    state = [];
  }
}

final navigationStackProvider =
    StateNotifierProvider<NavigationStackNotifier, List<NavigationItem>>((ref) {
  return NavigationStackNotifier();
});

// --- LEGACY PROVIDERS (Kept for compatibility during migration, mapped to stack if needed) ---
// We will transition MainShell to use navigationStackProvider directly.

final selectedAlbumProvider = StateProvider<AlbumModel?>((ref) => null);
final selectedArtistProvider = StateProvider<ArtistSelection?>((ref) => null);
final selectedPlaylistProvider = StateProvider<String?>((ref) => null);

class ArtistSelection {
  final String artistName;
  final List<SongModel>? songs;

  ArtistSelection({required this.artistName, this.songs});
}
