import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class LibraryPresentationState {
  final LibraryView currentView;
  final bool isGridView;

  LibraryPresentationState({
    this.currentView = LibraryView.localLibrary,
    this.isGridView = true,
  });

  LibraryPresentationState copyWith(
      {LibraryView? currentView, bool? isGridView}) {
    return LibraryPresentationState(
      currentView: currentView ?? this.currentView,
      isGridView: isGridView ?? this.isGridView,
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

  // 🚀 CRITICAL OPTIMIZATION:
  // If the library is currently scanning (isLoading is true), return empty immediately.
  // This prevents the heavy grouping logic from running hundreds of times
  // while the library counts up "1, 2, 3..." during the scan.
  if (library.isLoading) {
    return const {};
  }

  final songs = library.songs;

  // Return empty if no songs found
  if (songs.isEmpty) {
    return const {};
  }

  final Map<String, List<SongModel>> grouped = {};

  for (var song in songs) {
    // Group songs by Artist name, using 'Unknown Artist' as a fallback
    final artist = song.artist.isNotEmpty ? song.artist : 'Unknown Artist';

    if (!grouped.containsKey(artist)) {
      grouped[artist] = [];
    }
    grouped[artist]!.add(song);
  }

  // Debug log to confirm it only runs once at the end
  // print("🎨 Grouping Artists: Processed ${grouped.length} artists.");

  return grouped;
});
