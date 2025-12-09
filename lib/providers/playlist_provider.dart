import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/playlist_model.dart';
import '../models/song_model.dart';
import 'settings_provider.dart';

class PlaylistNotifier extends StateNotifier<List<PlaylistModel>> {
  final SharedPreferences _prefs;
  final _uuid = const Uuid();

  PlaylistNotifier(this._prefs) : super([]) {
    _loadPlaylists();
  }

  static const String _storageKey =
      'user_playlists_v2'; // New key to avoid crash

  void _loadPlaylists() {
    final String? jsonString = _prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = json.decode(jsonString);
        state = decoded.map((map) => PlaylistModel.fromMap(map)).toList();
      } catch (e) {
        print("Error loading playlists: $e");
      }
    }
  }

  Future<void> _save() async {
    final String encoded = json.encode(state.map((p) => p.toMap()).toList());
    await _prefs.setString(_storageKey, encoded);
  }

  void createPlaylist(String name) {
    final newPlaylist = PlaylistModel(
      id: _uuid.v4(),
      name: name,
      entries: [],
      createdAt: DateTime.now(),
    );
    state = [...state, newPlaylist];
    _save();
  }

  void deletePlaylist(String id) {
    state = state.where((p) => p.id != id).toList();
    _save();
  }

  void renamePlaylist(String id, String newName) {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(name: newName) else p
    ];
    _save();
  }

  // ADDS WITH TIMESTAMP
  void addSongToPlaylist(String playlistId, SongModel song) {
    state = [
      for (final p in state)
        if (p.id == playlistId)
          // Check for duplicates based on path
          if (!p.entries.any((e) => e.path == song.filePath))
            p.copyWith(entries: [
              ...p.entries,
              PlaylistEntry(
                  path: song.filePath,
                  dateAdded: DateTime.now(),
                  title: song.title,
                  artist: song.artist,
                  album: song.album,
                  artUrl: song.onlineArtUrl,
                  sourceUrl: song.sourceUrl) // SAVE SOURCE URL
            ])
          else
            p
        else
          p
    ];
    _save();
  }

  // BATCH ADD SONGS
  void addSongsToPlaylist(String playlistId, List<SongModel> songs) {
    state = [
      for (final p in state)
        if (p.id == playlistId)
          p.copyWith(entries: [
            ...p.entries,
            ...songs
                .where((s) => !p.entries.any((e) => e.path == s.filePath))
                .map((s) => PlaylistEntry(
                      path: s.filePath,
                      dateAdded: DateTime.now(),
                      title: s.title,
                      artist: s.artist,
                      album: s.album,
                      artUrl: s.onlineArtUrl,
                      sourceUrl: s.sourceUrl, // SAVE SOURCE URL
                    ))
          ])
        else
          p
    ];
    _save();
  }

  void removeSongFromPlaylist(String playlistId, String songPath) {
    state = [
      for (final p in state)
        if (p.id == playlistId)
          p.copyWith(
              entries: p.entries.where((e) => e.path != songPath).toList())
        else
          p
    ];
    _save();
  }

  // ADD TO LIKED SONGS (AUTO-CREATE)
  void addToLikedSongs(SongModel song) {
    final likedPlaylist = state.firstWhere(
      (p) => p.name == "Liked Songs",
      orElse: () {
        // Create if not exists
        final newPlaylist = PlaylistModel(
          id: _uuid.v4(),
          name: "Liked Songs",
          entries: [],
          createdAt: DateTime.now(),
        );
        state = [...state, newPlaylist];
        _save();
        return newPlaylist;
      },
    );

    addSongToPlaylist(likedPlaylist.id, song);
  }
}

final playlistProvider =
    StateNotifierProvider<PlaylistNotifier, List<PlaylistModel>>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return PlaylistNotifier(prefs);
});
