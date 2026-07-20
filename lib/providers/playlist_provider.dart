import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../models/song_metadata.dart';
import '../services/spotify_service.dart';
import '../services/smart_download_service.dart';
import '../services/pocketbase_service.dart';
import 'settings_provider.dart';

class PlaylistNotifier extends StateNotifier<List<PlaylistModel>> {
  final SharedPreferences _prefs;
  final _uuid = const Uuid();

  PlaylistNotifier(this._prefs) : super([]) {
    _loadPlaylists();
  }

  static const String _storageKey = 'user_playlists_v2';

  void _loadPlaylists() {
    final String? jsonString = _prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = json.decode(jsonString);
        state = decoded.map((map) => PlaylistModel.fromMap(map)).toList();
      } catch (e) {
        debugPrint("Error loading playlists: $e");
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
                duration: song.duration.toInt(), // SAVE DURATION
                spotifyId: song.spotifyId, // SAVE SPOTIFY ID
              )
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
                      spotifyId: s.spotifyId, // SAVE SPOTIFY ID
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

  // IMPORT SPOTIFY PLAYLIST
  /// Imports a Spotify playlist by URL and creates a new local playlist
  /// Returns the new playlist ID on success, null on failure
  Future<String?> importSpotifyPlaylist(
    String spotifyUrl, {
    Function(String statusKey, {Map<String, dynamic>? args})? onStatus,
  }) async {
    try {
      // 1. Extract playlist ID
      final playlistId = SpotifyService.extractPlaylistId(spotifyUrl);
      if (playlistId == null) {
        onStatus?.call("invalidSpotifyUrl");
        return null;
      }

      onStatus?.call("fetchingPlaylistInfo");

      // 2. Get playlist info (name, cover)
      final info = await SpotifyService.getPlaylistInfo(playlistId);
      if (info == null) {
        onStatus?.call("failedFetchPlaylistInfo");
        return null;
      }

      final playlistName = info['name'] ?? "Imported Playlist";
      final coverUrl = info['image'];

      onStatus?.call("fetchingTracksFrom", args: {'name': playlistName});

      // 3. Fetch all tracks
      final tracks = await SpotifyService.getPlaylistTracks(playlistId);
      if (tracks.isEmpty) {
        onStatus?.call("noTracksFound");
        return null;
      }

      onStatus
          ?.call("creatingPlaylistWithTracks", args: {'count': tracks.length});

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
          sourceUrl: null,
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

      onStatus?.call("importedTracks", args: {'count': tracks.length});
      return newId;
    } catch (e) {
      debugPrint("Import Error: $e");
      onStatus?.call("importFailed", args: {'error': e.toString()});
      return null;
    }
  }

  // IMPORT YOUTUBE MUSIC PLAYLIST (via Vercel API)
  static const String _ytMusicApiBase = 'https://ytmusic-api-omega.vercel.app';

  Future<String?> importYoutubeMusicPlaylist(
    String youtubeUrl, {
    Function(String statusKey, {Map<String, dynamic>? args})? onStatus,
  }) async {
    try {
      // 1. Extract playlist ID from URL
      String? playlistId;
      try {
        final uri = Uri.parse(youtubeUrl);
        playlistId = uri.queryParameters['list'];
        // Handle direct playlist ID input (no URL)
        if (playlistId == null && !youtubeUrl.contains('/')) {
          playlistId = youtubeUrl.trim();
        }
      } catch (_) {}

      if (playlistId == null || playlistId.isEmpty) {
        onStatus?.call("invalidYoutubeMusicUrl");
        return null;
      }

      onStatus?.call("fetchingPlaylistInfo");

      // 2. Fetch playlist data from Vercel API (limit=5000 to get all tracks)
      final apiUrl =
          Uri.parse('$_ytMusicApiBase/api/playlist?id=$playlistId&limit=5000');
      final response = await http.get(apiUrl).timeout(
            const Duration(seconds: 60),
          );

      if (response.statusCode != 200) {
        onStatus?.call("failedFetchPlaylistInfo");
        return null;
      }

      final body = json.decode(response.body);
      if (body['success'] != true || body['data'] == null) {
        onStatus?.call("failedFetchPlaylistInfo");
        return null;
      }

      final data = body['data'] as Map<String, dynamic>;
      final playlistName = data['title'] ?? 'Imported Playlist';
      final tracks = data['tracks'] as List<dynamic>? ?? [];

      // Get cover from playlist thumbnails
      String? coverUrl;
      final thumbnails = data['thumbnails'] as List<dynamic>?;
      if (thumbnails != null && thumbnails.isNotEmpty) {
        coverUrl = thumbnails.last['url'] as String?;
      }

      if (tracks.isEmpty) {
        onStatus?.call("noTracksFound");
        return null;
      }

      onStatus?.call("fetchingTracksFrom", args: {'name': playlistName});
      onStatus
          ?.call("creatingPlaylistWithTracks", args: {'count': tracks.length});

      // 3. Build playlist entries from API response
      final smartService = SmartDownloadService();
      final entries = <PlaylistEntry>[];

      for (var track in tracks) {
        final title = track['title'] as String? ?? 'Unknown';

        // Artists is a list of {name, id}
        final artists = track['artists'] as List<dynamic>? ?? [];
        final artist = artists.isNotEmpty
            ? artists.map((a) => a['name'] as String? ?? '').join(', ')
            : 'Unknown Artist';

        // Album
        final albumData = track['album'] as Map<String, dynamic>?;
        final album = albumData?['name'] as String? ?? playlistName;

        // Duration
        final durationSeconds = track['duration_seconds'] as int? ?? 0;

        // Thumbnail - pick highest resolution
        final trackThumbnails = track['thumbnails'] as List<dynamic>? ?? [];
        String? artUrl;
        if (trackThumbnails.isNotEmpty) {
          artUrl = trackThumbnails.last['url'] as String?;
        }
        artUrl ??= coverUrl;

        // Video ID for source URL
        final videoId = track['videoId'] as String?;
        final sourceUrl =
            videoId != null ? 'https://www.youtube.com/watch?v=$videoId' : null;

        // Generate predicted cache path for file matching
        final trackMetadata = SongMetadata(
          title: title,
          artist: artist,
          album: album,
          durationSeconds: durationSeconds,
          albumArtUrl: artUrl ?? '',
        );

        final predictedPath =
            await smartService.getPredictedCachePath(trackMetadata);

        entries.add(PlaylistEntry(
          path: predictedPath,
          dateAdded: DateTime.now(),
          title: title,
          artist: artist,
          album: album,
          artUrl: artUrl,
          sourceUrl: sourceUrl,
          isrc: null,
          duration: durationSeconds,
        ));
      }

      // 4. Create the playlist
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

      onStatus?.call("importedTracks", args: {'count': tracks.length});
      return newId;
    } catch (e) {
      onStatus?.call("importFailed", args: {'error': e.toString()});
      return null;
    }
  }

  // M3U PLAYLIST EXPORT/IMPORT

  Future<void> exportM3uPlaylist(String playlistId,
      {Function(String statusKey, {Map<String, dynamic>? args})?
          onStatus}) async {
    try {
      final playlist = state.firstWhere((p) => p.id == playlistId);
      final buffer = StringBuffer();
      buffer.writeln("#EXTM3U");

      for (final entry in playlist.entries) {
        final durationStr =
            entry.duration != null ? entry.duration.toString() : "-1";
        final artistStr = entry.artist ?? "Unknown Artist";
        final titleStr = entry.title ?? "Unknown Title";

        buffer.writeln("#EXTINF:$durationStr,$artistStr - $titleStr");

        if (entry.album != null && entry.album!.isNotEmpty) {
          buffer.writeln("#EXTALB:${entry.album}");
        }
        if (entry.artUrl != null && entry.artUrl!.isNotEmpty) {
          buffer.writeln("#EXTART:${entry.artUrl}");
        }

        if (entry.spotifyId != null && entry.spotifyId!.isNotEmpty) {
          buffer.writeln("spotify-track://${entry.spotifyId}");
        } else if (entry.sourceUrl != null && entry.sourceUrl!.isNotEmpty) {
          buffer.writeln(entry.sourceUrl);
        } else {
          // Prevent exporting local temp/cache paths which break cross-device portability
          if (entry.path.contains('SimpleMusicCache') ||
              entry.path.contains('Temp') ||
              entry.path.contains('/cache/') ||
              entry.path == 'cloud_stream') {
            final query = Uri.encodeComponent('$artistStr $titleStr');
            buffer.writeln("yt-search://$query");
          } else {
            buffer.writeln(entry.path);
          }
        }
      }

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Playlist As',
        fileName: '${playlist.name}.m3u',
        type: FileType.custom,
        allowedExtensions: ['m3u'],
      );

      if (outputFile == null) {
        // User canceled the picker
        return;
      }

      final file = File(outputFile);
      await file.writeAsString(buffer.toString());

      onStatus?.call("exportedM3u");
    } catch (e) {
      debugPrint("Export M3U Error: $e");
      onStatus?.call("exportFailed", args: {'error': e.toString()});
    }
  }

  Future<String?> importM3uPlaylist(
      {Function(String statusKey, {Map<String, dynamic>? args})?
          onStatus}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final lines = await file.readAsLines();

        if (lines.isEmpty || !lines[0].startsWith("#EXTM3U")) {
          onStatus?.call("invalidM3uFile");
          return null;
        }

        final playlistName =
            result.files.single.name.replaceAll(RegExp(r'\.m3u8?$'), '');
        final entries = <PlaylistEntry>[];

        String? currentTitle;
        String? currentArtist;
        int? currentDuration;
        String? currentAlbum;
        String? currentArtUrl;

        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          if (line.startsWith("#EXTINF:")) {
            // Parse #EXTINF:duration,Artist - Title
            final info = line.substring(8);
            final parts = info.split(',');
            if (parts.isNotEmpty) {
              currentDuration = int.tryParse(parts[0]);
              if (parts.length > 1) {
                final trackInfo = parts.sublist(1).join(',');
                final trackParts = trackInfo.split(' - ');
                if (trackParts.length > 1) {
                  currentArtist = trackParts[0].trim();
                  currentTitle = trackParts.sublist(1).join(' - ').trim();
                } else {
                  currentTitle = trackInfo.trim();
                  currentArtist = "Unknown Artist";
                }
              }
            }
          } else if (line.startsWith("#EXTALB:")) {
            currentAlbum = line.substring(8);
          } else if (line.startsWith("#EXTART:")) {
            currentArtUrl = line.substring(8);
          } else if (!line.startsWith("#")) {
            // URI line
            String path = "cloud_stream";
            String? spotifyId;
            String? sourceUrl;

            if (line.startsWith("spotify-track://")) {
              spotifyId = line.replaceFirst("spotify-track://", "");
            } else if (line.startsWith("yt-search://")) {
              path = "cloud_stream";
            } else if (line.startsWith("http://") ||
                line.startsWith("https://")) {
              sourceUrl = line;
            } else {
              path = line;
            }

            entries.add(PlaylistEntry(
              path: path,
              dateAdded: DateTime.now(),
              title: currentTitle ?? "Unknown Title",
              artist: currentArtist ?? "Unknown Artist",
              album: currentAlbum,
              duration: currentDuration,
              spotifyId: spotifyId,
              sourceUrl: sourceUrl,
              artUrl: currentArtUrl,
            ));

            // Reset for next track
            currentTitle = null;
            currentArtist = null;
            currentDuration = null;
            currentAlbum = null;
            currentArtUrl = null;
          }
        }

        if (entries.isEmpty) {
          onStatus?.call("noTracksFound");
          return null;
        }

        final newId = _uuid.v4();
        final newPlaylist = PlaylistModel(
          id: newId,
          name: playlistName,
          entries: entries,
          createdAt: DateTime.now(),
        );

        state = [...state, newPlaylist];
        await _save();

        onStatus?.call("importedTracks", args: {'count': entries.length});
        return newId;
      }
    } catch (e) {
      debugPrint("Import M3U Error: $e");
      onStatus?.call("importFailed", args: {'error': e.toString()});
    }
    return null;
  }

  // SHAREABLE PLAYLISTS (PocketBase)

  /// Shares a playlist and returns the 6-digit code
  Future<String?> sharePlaylist(String playlistId) async {
    final playlist = state.firstWhere((p) => p.id == playlistId);
    final data = playlist.toMap();
    return await PocketBaseService().sharePlaylist(playlistId, data);
  }

  /// Removes a playlist from public sharing
  Future<bool> unsharePlaylist(String playlistId) async {
    return await PocketBaseService().unsharePlaylist(playlistId);
  }

  /// Checks if a playlist is shared and returns the code
  Future<String?> getShareCode(String playlistId) async {
    return await PocketBaseService().getShareCode(playlistId);
  }

  /// Imports a shared playlist by its 6-digit code
  Future<String?> importSharedPlaylist(
    String shareCode, {
    Function(String statusKey, {Map<String, dynamic>? args})? onStatus,
  }) async {
    try {
      onStatus?.call("fetchingSharedPlaylist");
      final data = await PocketBaseService().fetchSharedPlaylist(shareCode);

      if (data == null) {
        onStatus?.call("playlistNotFoundOrError");
        return null;
      }

      onStatus?.call("parsingPlaylistData");
      final importedPlaylist = PlaylistModel.fromMap(data);

      // Create a unique local copy
      final newId = _uuid.v4();

      // Actually, PlaylistModel constructor is easier if we don't have copyWithId
      final localPlaylist = PlaylistModel(
        id: newId,
        name: "${importedPlaylist.name} (Shared)",
        entries: importedPlaylist.entries,
        createdAt: DateTime.now(),
        coverUrl: importedPlaylist.coverUrl,
      );

      state = [...state, localPlaylist];
      await _save();

      onStatus
          ?.call("importedPlaylistName", args: {'name': localPlaylist.name});
      return newId;
    } catch (e) {
      debugPrint("Import Shared Error: $e");
      onStatus?.call("importFailed", args: {'error': e.toString()});
      return null;
    }
  }
}

// Helper to change ID for PlaylistModel
extension PlaylistModelExt on PlaylistModel {
  PlaylistModel copyWithId(String newId) {
    return PlaylistModel(
      id: newId,
      name: name,
      entries: entries,
      createdAt: createdAt,
      coverUrl: coverUrl,
    );
  }
}

final playlistProvider =
    StateNotifierProvider<PlaylistNotifier, List<PlaylistModel>>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return PlaylistNotifier(prefs);
});
