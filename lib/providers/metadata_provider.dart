import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'dart:typed_data';

import '../models/song_model.dart';
import '../services/spotify_service.dart';
import 'library_provider.dart';

class MetadataState {
  final SongModel? selectedSong;
  final List<SongModel> importedSongs;

  final String title;
  final String artist;
  final String album;
  final String year;
  final String trackNumber;
  final String discNumber;
  final String genre;

  final String? coverUrl;
  final bool isSaving;
  final bool isLoadingMetadata;
  final String statusMessage;
  final int progressCurrent;
  final int progressTotal;

  MetadataState({
    this.selectedSong,
    this.importedSongs = const [],
    this.title = "",
    this.artist = "",
    this.album = "",
    this.year = "",
    this.trackNumber = "",
    this.discNumber = "",
    this.genre = "",
    this.coverUrl,
    this.isSaving = false,
    this.isLoadingMetadata = false,
    this.statusMessage = "",
    this.progressCurrent = 0,
    this.progressTotal = 0,
  });

  MetadataState copyWith({
    SongModel? selectedSong,
    List<SongModel>? importedSongs,
    String? title,
    String? artist,
    String? album,
    String? year,
    String? trackNumber,
    String? discNumber,
    String? genre,
    String? coverUrl,
    bool? isSaving,
    bool? isLoadingMetadata,
    String? statusMessage,
    int? progressCurrent,
    int? progressTotal,
  }) {
    return MetadataState(
      selectedSong: selectedSong ?? this.selectedSong,
      importedSongs: importedSongs ?? this.importedSongs,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      genre: genre ?? this.genre,
      coverUrl: coverUrl ?? this.coverUrl,
      isSaving: isSaving ?? this.isSaving,
      isLoadingMetadata: isLoadingMetadata ?? this.isLoadingMetadata,
      statusMessage: statusMessage ?? this.statusMessage,
      progressCurrent: progressCurrent ?? this.progressCurrent,
      progressTotal: progressTotal ?? this.progressTotal,
    );
  }
}

class MetadataNotifier extends StateNotifier<MetadataState> {
  final Ref ref;
  MetadataNotifier(this.ref) : super(MetadataState());

  String _buildSmartQuery(SongModel song) {
    String artist =
        song.artist.replaceAll(RegExp(r'(?i)unknown artist'), '').trim();
    String title = song.title.replaceAll(RegExp(r'(?i)track \d+'), '').trim();
    const badTitles = ["track", "untitled", "unknown", "audio", "mp3"];
    bool isTitleBad =
        title.isEmpty || badTitles.any((k) => title.toLowerCase().contains(k));
    bool isArtistBad = artist.isEmpty ||
        badTitles.any((k) => artist.toLowerCase().contains(k));

    if (isArtistBad || isTitleBad) {
      String filename = p.basenameWithoutExtension(song.filePath);
      String cleanName = filename
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .replaceAll(RegExp(r'^\d+[\.\-\s]+'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleanName.isEmpty || cleanName.length < 2) return filename;
      return cleanName;
    }
    return "$artist $title".trim();
  }

  Future<void> pickExternalFiles({bool folder = false}) async {
    state = state.copyWith(
        isSaving: true,
        statusMessage: "Scanning files...",
        progressCurrent: 0,
        progressTotal: 0);
    List<File> filesToProcess = [];

    try {
      if (folder) {
        String? dirPath = await FilePicker.platform.getDirectoryPath();
        if (dirPath != null) {
          final dir = Directory(dirPath);
          if (await dir.exists()) {
            await for (var entity in dir.list(recursive: false)) {
              if (entity is File) filesToProcess.add(entity);
            }
          }
        }
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: ['mp3', 'flac', 'm4a', 'wav', 'ogg', 'aac'],
        );
        if (result != null) {
          filesToProcess = result.paths
              .where((p) => p != null)
              .map((path) => File(path!))
              .toList();
        }
      }

      final bool shouldLoadImages = filesToProcess.length <= 50;

      List<SongModel> newSongs = [];
      for (var file in filesToProcess) {
        try {
          final ext = p.extension(file.path).toLowerCase();
          if (!['.mp3', '.flac', '.m4a', '.wav', '.ogg', '.aac'].contains(ext))
            continue;

          final metadata = await MetadataGod.readMetadata(file: file.path);
          final song = SongModel.fromFile(
              file.path,
              metadata.title ?? p.basenameWithoutExtension(file.path),
              metadata.artist ?? "Unknown Artist",
              metadata.album ?? "Unknown Album",
              (metadata.durationMs ?? 0) / 1000,
              ext,
              shouldLoadImages ? metadata.picture?.data : null);
          newSongs.add(song);
        } catch (e) {}
      }

      state = state.copyWith(
        importedSongs: [...state.importedSongs, ...newSongs],
        isSaving: false,
        statusMessage: "Imported ${newSongs.length} files.",
      );
    } catch (e) {
      state =
          state.copyWith(isSaving: false, statusMessage: "Import failed: $e");
    }
  }

  void clearImported() {
    state = state.copyWith(importedSongs: []);
  }

  void selectSong(SongModel song) {
    state = MetadataState(
      importedSongs: state.importedSongs,
      selectedSong: song,
      title: song.title,
      artist: song.artist,
      album: song.album,
      year: "",
      trackNumber: "",
      discNumber: "",
      genre: "",
      coverUrl: null,
      statusMessage: "",
      isLoadingMetadata: true,
    );
    _readFreshTags(song.filePath);
  }

  Future<void> _readFreshTags(String path) async {
    try {
      final metadata = await MetadataGod.readMetadata(file: path);
      if (state.selectedSong?.filePath != path) return;

      // Only load from disk if our current model has null artwork (e.g. optimized import).
      final existingBytes = state.selectedSong?.albumArtBytes;
      final diskBytes = metadata.picture?.data;

      final updatedSong = state.selectedSong?.copyWith(
        albumArtBytes: existingBytes ?? diskBytes,
      );

      state = state.copyWith(
        selectedSong: updatedSong,
        title: metadata.title ?? state.selectedSong?.title ?? "",
        artist: metadata.artist ?? state.selectedSong?.artist ?? "",
        album: metadata.album ?? state.selectedSong?.album ?? "",
        year: metadata.year?.toString() ?? "",
        trackNumber: metadata.trackNumber?.toString() ?? "",
        discNumber: metadata.discNumber?.toString() ?? "",
        genre: metadata.genre ?? "",
        isLoadingMetadata: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMetadata: false);
    }
  }

  void updateField(
      {String? title,
      String? artist,
      String? album,
      String? year,
      String? track,
      String? disc,
      String? genre}) {
    state = state.copyWith(
        title: title,
        artist: artist,
        album: album,
        year: year,
        trackNumber: track,
        discNumber: disc,
        genre: genre);
  }

  Future<void> applySpotifyData(Map<String, dynamic> data) async {
    state = state.copyWith(
      title: data['title'],
      artist: data['artist'],
      album: data['album'],
      year: data['year'].toString(),
      trackNumber: data['track_number']?.toString() ?? "",
      discNumber: data['disc_number']?.toString() ?? "1",
      coverUrl: data['image_url'],
      statusMessage: "Fetching genre...",
    );

    String genre = "";
    if (data['artist_id'] != null) {
      genre = await SpotifyService.getArtistGenres(data['artist_id']);
    }

    if (mounted) {
      state = state.copyWith(
        genre: genre,
        statusMessage: "Synced with Spotify!",
      );
    }
  }

  Future<void> smartMatchCurrent() async {
    if (state.selectedSong == null) return;
    await autoMatchAll([state.selectedSong!]);
  }

  Future<void> saveChanges() async {
    if (state.selectedSong == null) return;
    final filePath = state.selectedSong!.filePath;
    state = state.copyWith(isSaving: true, statusMessage: "Saving tags...");

    try {
      Picture? pictureToWrite;

      if (state.coverUrl != null) {
        final resp = await http.get(Uri.parse(state.coverUrl!));
        if (resp.statusCode == 200) {
          pictureToWrite =
              Picture(data: resp.bodyBytes, mimeType: 'image/jpeg');
        }
      } else if (state.selectedSong!.albumArtBytes != null) {
        pictureToWrite = Picture(
            data: state.selectedSong!.albumArtBytes!, mimeType: 'image/jpeg');
      }

      await MetadataGod.writeMetadata(
        file: filePath,
        metadata: Metadata(
          title: state.title,
          artist: state.artist,
          album: state.album,
          year: int.tryParse(state.year),
          trackNumber: int.tryParse(state.trackNumber),
          discNumber: int.tryParse(state.discNumber),
          genre: state.genre,
          picture: pictureToWrite,
        ),
      );

      // IN-MEMORY UPDATE
      // Create the new song object with the data we JUST wrote (including new bytes)
      final newSong = state.selectedSong!.copyWith(
        title: state.title,
        artist: state.artist,
        album: state.album,
        albumArtBytes: pictureToWrite?.data, // Use the new bytes immediately
      );

      ref.read(libraryProvider).updateSingleSong(newSong);

      final importedIndex =
          state.importedSongs.indexWhere((s) => s.filePath == filePath);
      if (importedIndex != -1) {
        final newList = List<SongModel>.from(state.importedSongs);
        newList[importedIndex] = newSong;
        state = state.copyWith(importedSongs: newList);
      }

      // Reset UI state with the NEW SONG object
      // This ensures when selectSong is called later, it has the new bytes
      if (state.selectedSong?.filePath == filePath) {
        state = MetadataState(
          importedSongs: state.importedSongs,
          selectedSong: newSong,
          title: newSong.title,
          artist: newSong.artist,
          album: newSong.album,
          year: state.year,
          trackNumber: state.trackNumber,
          discNumber: state.discNumber,
          genre: state.genre,
          coverUrl: null,
          isSaving: false,
          statusMessage: "Saved Successfully!",
          isLoadingMetadata: false,
        );
      } else {
        state = state.copyWith(isSaving: false);
      }
    } catch (e) {
      state = state.copyWith(isSaving: false, statusMessage: "Error: $e");
    }
  }

  Future<void> autoMatchAll(List<SongModel> songs) async {
    state = state.copyWith(
        isSaving: true,
        statusMessage: "Starting...",
        progressTotal: songs.length,
        progressCurrent: 0);
    int successCount = 0;

    for (var i = 0; i < songs.length; i++) {
      final song = songs[i];
      state = state.copyWith(
          progressCurrent: i + 1, statusMessage: "Processing: ${song.title}");

      try {
        final query = _buildSmartQuery(song);
        if (query.length > 1) {
          final results = await SpotifyService.searchMetadata(query);
          if (results.isNotEmpty) {
            final match = results.first;
            String genre = "";
            if (match['artist_id'] != null) {
              genre = await SpotifyService.getArtistGenres(match['artist_id']);
            }
            await _writeMetadata(
                song.filePath,
                match['title'],
                match['artist'],
                match['album'],
                match['year'].toString(),
                match['track_number'].toString(),
                match['disc_number'].toString(),
                genre,
                match['image_url']);

            // Update in-memory for bulk too
            // Note: We skip fetching new bytes for bulk to save RAM,
            // but we update text fields.
            // If user clicks it later, selectSong will reload bytes from disk.
            final newMetadata =
                await MetadataGod.readMetadata(file: song.filePath);
            final newSong = song.copyWith(
              title: newMetadata.title,
              artist: newMetadata.artist,
              album: newMetadata.album,
              // Keep null art for bulk list optimization
            );

            ref.read(libraryProvider).updateSingleSong(newSong);

            final importedIdx = state.importedSongs
                .indexWhere((s) => s.filePath == song.filePath);
            if (importedIdx != -1) {
              final newList = List<SongModel>.from(state.importedSongs);
              newList[importedIdx] = newSong;
              state = state.copyWith(importedSongs: newList);
            }
            successCount++;
          }
        }
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {}
    }

    state = state.copyWith(
        isSaving: false,
        statusMessage: "Done! Updated $successCount / ${songs.length} files.",
        progressCurrent: 0,
        progressTotal: 0);
    // Refresh library as fallback
    ref.read(libraryProvider).refreshLibrary();
  }

  Future<void> _writeMetadata(
      String path,
      String title,
      String artist,
      String album,
      String year,
      String track,
      String disc,
      String genre,
      String? url) async {
    Picture? newCover;
    if (url != null) {
      try {
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 200) {
          newCover = Picture(data: resp.bodyBytes, mimeType: 'image/jpeg');
        }
      } catch (_) {}
    }

    await MetadataGod.writeMetadata(
      file: path,
      metadata: Metadata(
        title: title,
        artist: artist,
        album: album,
        year: int.tryParse(year),
        trackNumber: int.tryParse(track),
        discNumber: int.tryParse(disc),
        genre: genre,
        picture: newCover,
      ),
    );
  }
}

final metadataProvider =
    StateNotifierProvider<MetadataNotifier, MetadataState>((ref) {
  return MetadataNotifier(ref);
});
