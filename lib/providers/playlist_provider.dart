import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/spotify_service.dart';
import '../services/smart_download_service.dart';
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
                  sourceUrl: song.sourceUrl, // SAVE SOURCE URL
                  isrc: song.isrc, // SAVE ISRC
                  duration: song.duration.toInt()) // SAVE DURATION
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
                      isrc: s.isrc, // SAVE ISRC
                      duration: s.duration.toInt(), // SAVE DURATION
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

  // 🚀 IMPORT SPOTIFY PLAYLIST
  /// Imports a Spotify playlist by URL and creates a new local playlist
  /// Returns the new playlist ID on success, null on failure
  Future<String?> importSpotifyPlaylist(
    String spotifyUrl, {
    Function(String status)? onProgress,
  }) async {
    try {
      // 1. Extract playlist ID
      final playlistId = SpotifyService.extractPlaylistId(spotifyUrl);
      if (playlistId == null) {
        onProgress?.call("❌ Invalid Spotify playlist URL");
        return null;
      }

      onProgress?.call("📋 Fetching playlist info...");

      // 2. Get playlist info (name, cover)
      final info = await SpotifyService.getPlaylistInfo(playlistId);
      if (info == null) {
        onProgress?.call("❌ Could not fetch playlist info");
        return null;
      }

      final playlistName = info['name'] ?? "Imported Playlist";
      final coverUrl = info['image'];

      onProgress?.call("🎵 Fetching tracks from \"$playlistName\"...");

      // 3. Fetch all tracks
      final tracks = await SpotifyService.getPlaylistTracks(playlistId);
      if (tracks.isEmpty) {
        onProgress?.call("❌ No tracks found in playlist");
        return null;
      }

      onProgress?.call("📝 Creating playlist with ${tracks.length} tracks...");

      // 4. Convert to SongModels with predicted paths
      final smartService = SmartDownloadService();
      final entries = <PlaylistEntry>[];

      for (var track in tracks) {
        final predictedPath = await smartService.getPredictedCachePath(track);
        entries.add(PlaylistEntry(
          path: predictedPath,
          dateAdded: DateTime.now(),
          title: track.title,
          artist: track.artist,
          album: track.album,
          artUrl: track.albumArtUrl.isNotEmpty ? track.albumArtUrl : coverUrl,
          sourceUrl: null, // Will be resolved via YouTube on play
          isrc: track.isrc,
          duration: track.durationSeconds,
        ));
      }

      // 5. Create the playlist
      final newId = _uuid.v4();
      final newPlaylist = PlaylistModel(
        id: newId,
        name: playlistName,
        entries: entries,
        createdAt: DateTime.now(),
        coverUrl: coverUrl,
      );

      state = [...state, newPlaylist];
      await _save();

      onProgress?.call("✅ Imported ${tracks.length} tracks!");
      return newId;
    } catch (e) {
      print("Import Error: $e");
      onProgress?.call("❌ Import failed: $e");
      return null;
    }
  }
}

final playlistProvider =
    StateNotifierProvider<PlaylistNotifier, List<PlaylistModel>>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return PlaylistNotifier(prefs);
});
