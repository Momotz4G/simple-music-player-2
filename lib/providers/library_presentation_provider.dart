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
  tools,
  leaderboard
}

enum LibraryFilter { songs, folders, artists, albums }

enum LibrarySort { title, artist, fileName }

class LibraryPresentationState {
  final LibraryView currentView;
  final bool isGridView;
  final LibraryFilter currentFilter;
  final LibrarySort sortBy;
  final bool isSortDescending;
  final String? selectedFolderPath; // 🚀 Use FULL PATH for precise filtering

  LibraryPresentationState({
    this.currentView = LibraryView.localLibrary,
    this.isGridView = true,
    this.currentFilter = LibraryFilter.songs,
    this.sortBy = LibrarySort.title,
    this.isSortDescending = false,
    this.selectedFolderPath,
  });

  LibraryPresentationState copyWith({
    LibraryView? currentView,
    bool? isGridView,
    LibraryFilter? currentFilter,
    LibrarySort? sortBy,
    bool? isSortDescending,
    String? Function()? selectedFolderPath,
  }) {
    return LibraryPresentationState(
      currentView: currentView ?? this.currentView,
      isGridView: isGridView ?? this.isGridView,
      currentFilter: currentFilter ?? this.currentFilter,
      sortBy: sortBy ?? this.sortBy,
      isSortDescending: isSortDescending ?? this.isSortDescending,
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

  void setSortBy(LibrarySort sort) {
    if (state.sortBy == sort) {
      state = state.copyWith(isSortDescending: !state.isSortDescending);
    } else {
      state = state.copyWith(sortBy: sort, isSortDescending: false);
    }
  }

  void setFilter(LibraryFilter filter) {
    if (filter == LibraryFilter.artists || filter == LibraryFilter.albums) {
      state = state.copyWith(
        currentFilter: filter,
        sortBy: LibrarySort.title,
        isSortDescending: false,
        selectedFolderPath: () => null,
      );
    } else {
      state = state.copyWith(
        currentFilter: filter,
        selectedFolderPath: () => null,
      );
    }
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
// --- SYNC PROVIDERS FOR INSTANT UPDATES ---
// -------------------------------------------------------------------

/// Provides a list of songs sorted by the user's preference (Synchronous for speed)
/// 🚀 Uses allSongs (unfiltered) to avoid re-sorting on every search keystroke.
/// 🚀 Uses .select((p) => p.allSongs) so it ONLY rebuilds when the actual library changes, NOT when searching!
final sortedSongsProvider = Provider<List<SongModel>>((ref) {
  final allSongs = ref.watch(libraryProvider.select((p) => p.allSongs));
  final presentationState = ref.watch(libraryPresentationProvider);

  if (allSongs.isEmpty) return [];

  final List<SongModel> songs = List<SongModel>.from(allSongs);
  final LibrarySort sortBy = presentationState.sortBy;
  final bool isSortDescending = presentationState.isSortDescending;

  switch (sortBy) {
    case LibrarySort.title:
      // Compare strings efficiently without allocating new lowercase strings for every comparison
      songs.sort((a, b) => a.title.compareTo(b.title));
      break;
    case LibrarySort.artist:
      songs.sort((a, b) => a.artist.compareTo(b.artist));
      break;
    case LibrarySort.fileName:
      songs.sort((a, b) {
        return p.basename(a.filePath).compareTo(p.basename(b.filePath));
      });
      break;
  }

  if (isSortDescending) {
    return songs.reversed.toList();
  }
  return songs;
});

final displaySortedSongsProvider = Provider<List<SongModel>>((ref) {
  // 🚀 MASTER SOURCE: Use the already-sorted list as the base for filtering.
  // This physically guarantees the result is sorted without ever calling `.sort()` again.
  final allSortedSongs = ref.watch(sortedSongsProvider);
  final hasSearchQuery = ref.watch(libraryProvider.select((p) => p.hasSearchQuery));
  
  if (!hasSearchQuery) return allSortedSongs;

  // 🚀 FAST FILTER: Simply filter the sorted master list.
  // The results stay in the correct relative sorted order automatically!
  final query = ref.watch(libraryProvider.select((p) => p.searchQuery)).toLowerCase();
  
  return allSortedSongs.where((song) => song.searchKey.contains(query)).toList();
});

/// Provides a Map of Artist Name -> List of SongModel objects by that artist.
final groupedArtistsProvider = Provider<Map<String, List<SongModel>>>((ref) {
  final songs = ref.watch(displaySortedSongsProvider);
  if (songs.isEmpty) return const {};

  final Map<String, List<SongModel>> grouped = {};
  for (var song in songs) {
    final artist =
        (song.artist.isNotEmpty ? song.artist : 'Unknown Artist').trim();
    if (!grouped.containsKey(artist)) {
      grouped[artist] = [];
    }
    grouped[artist]!.add(song);
  }

  // 🚀 Alphabetical Sort for Artist Names
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return {for (final key in sortedKeys) key: grouped[key]!};
});

/// Provides a Map of Album Name -> List of SongModel objects in that album.
final groupedAlbumsProvider = Provider<Map<String, List<SongModel>>>((ref) {
  final songs = ref.watch(displaySortedSongsProvider);
  if (songs.isEmpty) return const {};

  final Map<String, List<SongModel>> grouped = {};
  for (final song in songs) {
    final album = (song.album.isNotEmpty ? song.album : "Unknown Album").trim();
    if (!grouped.containsKey(album)) {
      grouped[album] = [];
    }
    grouped[album]!.add(song);
  }
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return {for (final key in sortedKeys) key: grouped[key]!};
});

/// Provides a Map of Folder Name -> List of SongModel objects in that folder.
final groupedFoldersProvider = Provider<Map<String, List<SongModel>>>((ref) {
  final songs = ref.watch(displaySortedSongsProvider);
  if (songs.isEmpty) return const {};

  final Map<String, List<SongModel>> grouped = {};
  for (final song in songs) {
    final folderPath = p.dirname(song.filePath);
    if (!grouped.containsKey(folderPath)) {
      grouped[folderPath] = [];
    }
    grouped[folderPath]!.add(song);
  }
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) {
      final nameA = p.basename(a).toLowerCase();
      final nameB = p.basename(b).toLowerCase();
      return nameA.compareTo(nameB);
    });
  return {for (final key in sortedKeys) key: grouped[key]!};
});
