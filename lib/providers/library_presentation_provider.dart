import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// --- CORE DEPENDENCIES ---
import '../models/song_model.dart';
import './library_provider.dart';

// --- ENUMS & STATE ---
enum LibraryView {
  browse,
  search,
  history,
  stats,
  playlists,
  artists,
  albums,
  localLibrary,
  downloads,
  settings,
  albumDetail,
  artistDetail,
  tools
}

enum LibraryFilter { songs, folders, artists, albums }

class LibraryPresentationState {
  final LibraryView currentView;
  final bool isGridView;
  final LibraryFilter currentFilter;
  final String? selectedFolderPath; // 🚀 Use FULL PATH for precise filtering

  LibraryPresentationState({
    this.currentView = LibraryView.localLibrary,
    this.isGridView = true,
    this.currentFilter = LibraryFilter.songs,
    this.selectedFolderPath,
  });

  LibraryPresentationState copyWith({
    LibraryView? currentView,
    bool? isGridView,
    LibraryFilter? currentFilter,
    String? Function()? selectedFolderPath,
  }) {
    return LibraryPresentationState(
      currentView: currentView ?? this.currentView,
      isGridView: isGridView ?? this.isGridView,
      currentFilter: currentFilter ?? this.currentFilter,
      selectedFolderPath: selectedFolderPath != null
          ? selectedFolderPath()
          : this.selectedFolderPath,
    );
  }
}

// --- NOTIFIER ---
class LibraryPresentationNotifier
    extends StateNotifier<LibraryPresentationState> {
  LibraryPresentationNotifier() : super(LibraryPresentationState());

  void setView(LibraryView view) {
    state = state.copyWith(currentView: view);
  }

  void toggleViewMode() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

  void setFilter(LibraryFilter filter) {
    state =
        state.copyWith(currentFilter: filter, selectedFolderPath: () => null);
  }

  void selectFolder(String? folderPath) {
    state = state.copyWith(
      currentFilter: LibraryFilter.songs,
      selectedFolderPath: () => folderPath,
    );
  }

  void clearFolderFilter() {
    state = state.copyWith(selectedFolderPath: () => null);
  }
}

final libraryPresentationProvider = StateNotifierProvider<
    LibraryPresentationNotifier, LibraryPresentationState>((ref) {
  return LibraryPresentationNotifier();
});

// -------------------------------------------------------------------
// --- PROVIDER FOR ARTISTS PAGE ---
// -------------------------------------------------------------------

/// Provides a Map of Artist Name -> List of SongModel objects by that artist.
final groupedArtistsProvider = Provider<Map<String, List<SongModel>>>((ref) {
  final library = ref.watch(libraryProvider);

  // 🚀 OPTIMIZATION:
  // We no longer return empty during scan, so user can see partial data.
  // But we watch 'libraryProvider' so it updates automatically.

  final songs = library.songs;

  // Return empty if no songs found
  if (songs.isEmpty) {
    return const {};
  }

  final Map<String, List<SongModel>> grouped = {};

  for (var song in songs) {
    // Group songs by Artist name, using 'Unknown Artist' as a fallback
    final artist =
        (song.artist.isNotEmpty ? song.artist : 'Unknown Artist').trim();

    if (!grouped.containsKey(artist)) {
      grouped[artist] = [];
    }
    grouped[artist]!.add(song);
  }

  // Debug log to confirm it only runs once at the end
  // print("🎨 Grouping Artists: Processed ${grouped.length} artists.");

  return grouped;
});

// -------------------------------------------------------------------
// --- PROVIDER FOR ALBUMS PAGE ---
// -------------------------------------------------------------------

/// Provides a Map of Album Name -> List of SongModel objects in that album.
final groupedAlbumsProvider = Provider<Map<String, List<SongModel>>>((ref) {
  final library = ref.watch(libraryProvider);
  final songs = library.songs;

  if (songs.isEmpty) return const {};

  final Map<String, List<SongModel>> grouped = {};

  for (final song in songs) {
    final album = (song.album.isNotEmpty ? song.album : "Unknown Album").trim();
    if (!grouped.containsKey(album)) {
      grouped[album] = [];
    }
    grouped[album]!.add(song);
  }

  // Sort albums alphabetically
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return {for (final key in sortedKeys) key: grouped[key]!};
});

// -------------------------------------------------------------------
// --- PROVIDER FOR FOLDERS PAGE ---
// -------------------------------------------------------------------

/// Provides a Map of Folder Name -> List of SongModel objects in that folder.
final groupedFoldersProvider = Provider<Map<String, List<SongModel>>>((ref) {
  final library = ref.watch(libraryProvider);
  final songs = library.songs;

  if (songs.isEmpty) return const {};

  final Map<String, List<SongModel>> grouped = {};

  for (final song in songs) {
    // 🚀 Use FULL PATH as key to avoid name collisions (e.g., ArtistA/Album1 vs ArtistB/Album1)
    final folderPath = p.dirname(song.filePath);

    if (!grouped.containsKey(folderPath)) {
      grouped[folderPath] = [];
    }
    grouped[folderPath]!.add(song);
  }

  // Sort by folder name (basename) but keep full path as key
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) {
      final nameA = p.basename(a).toLowerCase();
      final nameB = p.basename(b).toLowerCase();
      return nameA.compareTo(nameB);
    });

  return {for (final key in sortedKeys) key: grouped[key]!};
});
