import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:metadata_god/metadata_god.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';

// Imports for Database
import '../data/schemas.dart'; // The Isar Schema
import 'db_provider.dart'; // To access the DB Service
import '../models/song_model.dart';

class LibraryProvider extends ChangeNotifier {
  final Ref ref; // We need Ref to talk to other providers (DB)

  List<SongModel> _songs = [];
  List<SongModel> _filteredSongs = [];
  String _searchQuery = "";

  bool _isLoading = false;
  String? _selectedFolder;

  List<SongModel> get songs => _searchQuery.isEmpty ? _songs : _filteredSongs;
  bool get isLoading => _isLoading;
  String? get selectedFolder => _selectedFolder;

  final List<String> _audioExtensions = [
    '.mp3',
    '.wav',
    '.flac',
    '.m4a',
    '.ogg',
    '.aac'
  ];

  // Constructor now requires 'Ref'
  LibraryProvider(this.ref) {
    _loadSavedPath();
  }

  Future<void> _loadSavedPath() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('saved_music_folder');

    // 1. First, load whatever is already in the DB (Instant Load)
    await _fetchFromDatabase();

    // 2. Then, if we have a path, verify it and scan for changes
    if (savedPath != null && await Directory(savedPath).exists()) {
      _selectedFolder = savedPath;
      notifyListeners();
      // Run scan in background so UI shows DB data immediately
      _scanFolder(savedPath);
    }
  }

  // Fetch from Isar Database
  Future<void> _fetchFromDatabase() async {
    final dbService = ref.read(dbServiceProvider);
    final dbSongs = await dbService.getAllSongs();

    // Convert Isar 'Song' entities back to 'SongModel' for the UI
    _songs = dbSongs.map((e) => _mapToModel(e)).toList();

    // Apply your Natural Sort
    _sortSongs();

    // Apply current search filter if any
    if (_searchQuery.isNotEmpty) {
      search(_searchQuery);
    } else {
      _filteredSongs = List.from(_songs);
    }
    notifyListeners();
  }

  // Helper to convert DB Schema -> UI Model
  SongModel _mapToModel(Song dbSong) {
    return SongModel(
      title: dbSong.title,
      artist: dbSong.artist,
      album: dbSong.album ?? "Unknown Album",
      duration: dbSong.duration,
      filePath: dbSong.path,
      fileExtension: p.extension(dbSong.path),
      // artwork: null, // Removed as per your SongModel
    );
  }

  void search(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredSongs = List.from(_songs);
    } else {
      final lowerQuery = query.toLowerCase();
      _filteredSongs = _songs.where((song) {
        return song.title.toLowerCase().contains(lowerQuery) ||
            song.artist.toLowerCase().contains(lowerQuery) ||
            song.album.toLowerCase().contains(lowerQuery);
      }).toList();
    }
    notifyListeners();
  }

  Future<void> pickFolder() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      _selectedFolder = result;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_music_folder', result);
      await _scanFolder(result);
    }
  }

  Future<void> _scanFolder(String path) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    final dbService = ref.read(dbServiceProvider);

    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        final List<FileSystemEntity> entities =
            await dir.list(recursive: false, followLinks: false).toList();

        List<Song> batchToAdd = [];

        for (final entity in entities) {
          if (entity is File) {
            String extension = p.extension(entity.path).toLowerCase();
            if (_audioExtensions.contains(extension)) {
              // Process Metadata
              Song? newSong = await _processFileForDB(entity, extension);

              if (newSong != null) {
                batchToAdd.add(newSong);
              }

              // Save in batches of 50 to prevent freezing
              if (batchToAdd.length >= 50) {
                await dbService.saveSongs(batchToAdd);
                batchToAdd.clear();
              }
            }
          }
        }

        // Save remaining songs
        if (batchToAdd.isNotEmpty) {
          await dbService.saveSongs(batchToAdd);
        }
      }
    } catch (e) {
      print("Scan Error: $e");
    }

    // Scan complete, now refresh the UI from the Source of Truth (DB)
    await _fetchFromDatabase();

    _isLoading = false;
    notifyListeners();
  }

  // Returns an Isar 'Song' object
  Future<Song?> _processFileForDB(File file, String extension) async {
    try {
      final metadata = await MetadataGod.readMetadata(file: file.path);

      final song = Song()
        ..path = file.path
        ..title = metadata.title ?? p.basenameWithoutExtension(file.path)
        ..artist = metadata.artist ?? "Unknown Artist"
        ..album = metadata.album ?? "Unknown Album"
        ..duration = (metadata.durationMs ?? 0) / 1000.0
        ..dateAdded = DateTime.now();

      return song;
    } catch (e) {
      // Return basic info if metadata fails
      return Song()
        ..path = file.path
        ..title = p.basenameWithoutExtension(file.path)
        ..artist = "Unknown Artist"
        ..album = "Unknown Album"
        ..duration = 0.0
        ..dateAdded = DateTime.now();
    }
  }

  // RE-ADDED HELPERS

  Future<void> refreshLibrary() async {
    if (_selectedFolder != null) {
      await _scanFolder(_selectedFolder!);
    } else {
      await _fetchFromDatabase();
    }
  }

  Future<void> updateSingleSong(SongModel newSong) async {
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;

    await isar.writeTxn(() async {
      // Updated to use the standard 'filter' syntax which is safer
      final existingSong =
          await isar.songs.filter().pathEqualTo(newSong.filePath).findFirst();

      if (existingSong != null) {
        existingSong.title = newSong.title;
        existingSong.artist = newSong.artist;
        existingSong.album = newSong.album;
        existingSong.duration = newSong.duration;

        await isar.songs.put(existingSong);
      }
    });

    // Refresh the UI list
    final index = _songs.indexWhere((s) => s.filePath == newSong.filePath);
    if (index != -1) {
      _songs[index] = newSong;
      if (_searchQuery.isNotEmpty) {
        search(_searchQuery);
      } else {
        _filteredSongs = List.from(_songs);
      }
      notifyListeners();
    }
  }

  void _sortSongs() {
    _songs.sort((a, b) =>
        _naturalCompare(p.basename(a.filePath), p.basename(b.filePath)));
  }

  int _naturalCompare(String a, String b) {
    a = a.toLowerCase();
    b = b.toLowerCase();
    final RegExp splitPattern = RegExp(r'(\d+)|(\D+)');
    final matchesA =
        splitPattern.allMatches(a).map((m) => m.group(0)!).toList();
    final matchesB =
        splitPattern.allMatches(b).map((m) => m.group(0)!).toList();

    int i = 0;
    while (i < matchesA.length && i < matchesB.length) {
      final partA = matchesA[i];
      final partB = matchesB[i];
      final int? numA = int.tryParse(partA);
      final int? numB = int.tryParse(partB);
      if (numA != null && numB != null) {
        final int comparison = numA.compareTo(numB);
        if (comparison != 0) return comparison;
      } else {
        final int comparison = partA.compareTo(partB);
        if (comparison != 0) return comparison;
      }
      i++;
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  Future<void> resetLibrary() async {
    // 1. Clear In-Memory Lists
    _songs.clear();
    _filteredSongs.clear();
    _selectedFolder = null;
    _searchQuery = "";

    // 2. Clear SharedPreferences (Saved Folder)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_music_folder');

    // 3. Clear the Database
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;
    await isar.writeTxn(() async {
      await isar.songs.clear(); // Wipes all songs from Isar
    });

    notifyListeners();
  }
}

// UPDATE THE PROVIDER DEFINITION (Must pass ref!)
final libraryProvider = ChangeNotifierProvider<LibraryProvider>((ref) {
  return LibraryProvider(ref);
});
