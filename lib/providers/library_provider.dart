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
import '../services/db_service.dart'; // 🚀 IMPORT DBService class
import '../models/song_model.dart';
import 'settings_provider.dart'; // 🚀 IMPORT SettingsState
import '../services/audio_info_service.dart';
import '../services/art_cache_service.dart'; // 🚀 Art Cache

class LibraryProvider extends ChangeNotifier {
  final Ref ref; // We need Ref to talk to other providers (DB)

  // 🚀 REACTIVE STATE: Managed internally to prevent disposal crashes
  // This allows LibraryProvider to stay alive even when settings change.
  bool _ignoreSubfolders = true;

  List<SongModel> _songs = [];
  List<SongModel> _filteredSongs = [];
  String _searchQuery = "";

  bool _isLoading = false;
  String? _selectedFolder;
  String? _error;
  bool _isPermissionDenied = false;
  bool _disposed = false; // 🚀 Track disposal state

  List<SongModel> get songs => _searchQuery.isEmpty ? _songs : _filteredSongs;
  bool get isLoading => _isLoading;
  String? get selectedFolder => _selectedFolder;
  String? get error => _error;
  bool get isPermissionDenied => _isPermissionDenied;
  bool get ignoreSubfolders => _ignoreSubfolders;

  final List<String> _audioExtensions = [
    '.mp3',
    '.wav',
    '.flac',
    '.m4a',
    '.ogg',
    '.aac',
    '.opus',
    '.dsf',
    '.dff'
  ];

  LibraryProvider(this.ref) {
    // 1. Initial State
    final initialSettings = ref.read(settingsProvider);
    _ignoreSubfolders = initialSettings.ignoreSubfolders;

    // 2. 🚀 DECOUPLED LISTENER: Update internal state without provider disposal
    // This is the permanent fix for: Cannot use ref functions after the dependency of a provider changed...
    ref.listen(settingsProvider, (previous, next) {
      bool shouldFetch = false;
      if (previous?.ignoreSubfolders != next.ignoreSubfolders) {
        _ignoreSubfolders = next.ignoreSubfolders;
        shouldFetch = true;
      }
      if (previous?.additionalMusicFolders != next.additionalMusicFolders) {
        shouldFetch = true;
      }

      if (shouldFetch) {
        final dbService = ref.read(dbServiceProvider);
        _fetchFromDatabase(dbService, next);
      }
    });

    _loadSavedPath();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Safe wrapper to prevent calling notifyListeners after dispose
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // 🚀 New Method: Request Permissions manually
  Future<void> requestPermissions() async {
    // Capture dependencies at ENTRY
    final dbService = ref.read(dbServiceProvider);
    final settings = ref.read(settingsProvider);

    _error = null;
    _isPermissionDenied = false;
    _safeNotify();

    if (_selectedFolder != null) {
      await _scanFolder(_selectedFolder!, dbService, settings);
    }
  }

  Future<void> _loadSavedPath() async {
    // 🚀 Capture dependencies at ENTRY
    final dbService = ref.read(dbServiceProvider);
    final settings = ref.read(settingsProvider);

    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    final savedPath = prefs.getString('saved_music_folder');

    // 1. First, load whatever is already in the DB (Instant Load)
    await _fetchFromDatabase(dbService, settings);
    if (_disposed) return;

    // 2. Then, if we have a main path, verify it and scan for changes
    if (savedPath != null) {
      final canonicalPath = p.canonicalize(savedPath);
      _selectedFolder = canonicalPath;
      _safeNotify();
      await _scanFolder(canonicalPath, dbService, settings);
      if (_disposed) return;
    }

    // 3. Also scan additional folders from settings
    for (final folder in settings.additionalMusicFolders) {
      await _scanFolder(p.canonicalize(folder), dbService, settings);
      if (_disposed) return;
    }

    // 4. Clean up stale DB entries that no longer exist on disk
    if (_songs.isNotEmpty) {
      final existingPaths = _songs.map((s) => s.filePath).toList();
      await dbService.cleanMissingSongs(existingPaths);
    }
  }

  // Fetch from Isar Database
  Future<void> _fetchFromDatabase(
      DBService dbService, SettingsState settings) async {
    final dbSongs = await dbService.getAllSongs();

    // 🚀 DISPOSAL GUARD
    if (_disposed) return;

    // Convert Isar 'Song' entities back to 'SongModel' for the UI
    final allSongs = dbSongs.map((e) => _mapToModel(e)).toList();

    // Get all folders to filter: main folder + additional folders
    final List<String> allFolders = [
      if (_selectedFolder != null) p.canonicalize(_selectedFolder!),
      ...settings.additionalMusicFolders.map((f) => p.canonicalize(f)),
    ];

    // 🚀 FILTERING LOGIC
    if (allFolders.isNotEmpty) {
      _songs = allSongs.where((s) {
        for (final folder in allFolders) {
          if (_ignoreSubfolders) {
            // Use reactive internal state
            final parent = p.dirname(s.filePath);
            if (p.equals(parent, folder)) return true;
          } else {
            if (p.isWithin(folder, s.filePath) ||
                p.equals(p.dirname(s.filePath), folder)) {
              return true;
            }
          }
        }
        return false;
      }).toList();
    } else {
      _songs = allSongs;
    }

    // 🚀 DEDUPLICATE by filePath — prevents stale DB entries from
    // creating duplicates during the old-load + new-scan overlap window
    final seen = <String>{};
    _songs = _songs.where((s) => seen.add(s.filePath)).toList();

    _sortSongs();

    if (_searchQuery.isNotEmpty) {
      search(_searchQuery);
    } else {
      _filteredSongs = List.from(_songs);
    }
    _safeNotify();
  }

  SongModel _mapToModel(Song dbSong) {
    return SongModel(
      title: dbSong.title,
      artist: dbSong.artist,
      album: dbSong.album ?? "Unknown Album",
      duration: dbSong.duration,
      filePath: dbSong.path,
      fileExtension: p.extension(dbSong.path),
      year: dbSong.year,
      trackNumber: dbSong.trackNumber,
      discNumber: dbSong.discNumber,
      genre: dbSong.genre,
      dateAdded: dbSong.dateAdded,
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
    _safeNotify();
  }

  Future<void> pickFolder() async {
    // 🚀 Capture dependencies at ENTRY
    final dbService = ref.read(dbServiceProvider);
    final settings = ref.read(settingsProvider);

    String? result = await FilePicker.platform.getDirectoryPath();
    if (_disposed || result == null) return;

    final canonicalPath = p.canonicalize(result);
    _selectedFolder = canonicalPath;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    await prefs.setString('saved_music_folder', canonicalPath);
    _error = null;
    _isPermissionDenied = false;
    await _scanFolder(canonicalPath, dbService, settings);
  }

  Future<void> _scanFolder(
      String path, DBService dbService, SettingsState settings) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    _isPermissionDenied = false;
    _safeNotify();

    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        if (_disposed) return;
        final List<FileSystemEntity> entities = await dir
            .list(recursive: !_ignoreSubfolders, followLinks: false)
            .toList();
        if (_disposed) return;

        List<Song> batchToAdd = [];

        for (final entity in entities) {
          if (entity is File) {
            String extension = p.extension(entity.path).toLowerCase();
            if (_audioExtensions.contains(extension)) {
              Song? newSong = await _processFileForDB(entity, extension);
              if (_disposed) return;

              if (newSong != null) {
                batchToAdd.add(newSong);
              }

              if (batchToAdd.length >= 50) {
                await dbService.saveSongs(batchToAdd);
                if (_disposed) return;
                batchToAdd.clear();
              }
            }
          }
        }

        if (batchToAdd.isNotEmpty) {
          await dbService.saveSongs(batchToAdd);
          if (_disposed) return;
        }
      } else {
        _error = "Directory does not exist or access denied.";
      }
    } catch (e) {
      print("Scan Error: $e");
      _error = "Scan failed: $e";
      if (e.toString().contains("Permission denied") ||
          e.toString().contains("os_error: 13")) {
        _isPermissionDenied = true;
        _error = "Permission Denied. Please grant Storage access.";
      }
    }

    await _fetchFromDatabase(dbService, settings);
    _isLoading = false;
    _safeNotify();
  }

  Future<Song?> _processFileForDB(File file, String extension) async {
    try {
      final metadata = await MetadataGod.readMetadata(file: file.path);
      final canonicalPath = p.canonicalize(file.path);

      final song = Song()
        ..path = canonicalPath
        ..title = metadata.title ?? p.basenameWithoutExtension(file.path)
        ..artist = metadata.artist ?? "Unknown Artist"
        ..album = metadata.album ?? "Unknown Album"
        ..duration = (metadata.durationMs ?? 0) / 1000.0
        ..year = metadata.year?.toString()
        ..trackNumber = metadata.trackNumber
        ..discNumber = metadata.discNumber
        ..genre = metadata.genre
        ..dateAdded = DateTime.now();

      if (metadata.picture != null) {
        ArtCacheService().saveArt(canonicalPath, metadata.picture!.data);
      }

      if (extension == '.dsf' || extension == '.dff') {
        if (song.artist == "Unknown Artist" || song.album == "Unknown Album") {
          final tags = await AudioInfoService().getTags(file.path);
          if (tags.isNotEmpty) {
            song.title = tags['title'] ?? tags['TITLE'] ?? song.title;
            song.artist = tags['artist'] ?? tags['ARTIST'] ?? song.artist;
            song.album = tags['album'] ?? tags['ALBUM'] ?? song.album;
            song.year =
                tags['date'] ?? tags['DATE'] ?? tags['year'] ?? song.year;
            song.genre = tags['genre'] ?? tags['GENRE'] ?? song.genre;
          }
        }
      }

      return song;
    } catch (e) {
      if (extension == '.dsf' || extension == '.dff') {
        try {
          final tags = await AudioInfoService().getTags(file.path);
          final canonicalPath = p.canonicalize(file.path);
          if (tags.isNotEmpty) {
            return Song()
              ..path = canonicalPath
              ..title = tags['title'] ??
                  tags['TITLE'] ??
                  p.basenameWithoutExtension(file.path)
              ..artist = tags['artist'] ?? tags['ARTIST'] ?? "Unknown Artist"
              ..album = tags['album'] ?? tags['ALBUM'] ?? "Unknown Album"
              ..duration = 0.0
              ..year = tags['date'] ?? tags['DATE'] ?? tags['year']
              ..genre = tags['genre'] ?? tags['GENRE']
              ..dateAdded = DateTime.now();
          }
        } catch (_) {}
      }
      final canonicalPath = p.canonicalize(file.path);
      return Song()
        ..path = canonicalPath
        ..title = p.basenameWithoutExtension(file.path)
        ..artist = "Unknown Artist"
        ..album = "Unknown Album"
        ..duration = 0.0
        ..dateAdded = DateTime.now();
    }
  }

  Future<void> refreshLibrary() async {
    // 🚀 Capture dependencies at ENTRY
    final dbService = ref.read(dbServiceProvider);
    final settings = ref.read(settingsProvider);
    final additionalFolders = settings.additionalMusicFolders;

    if (_selectedFolder != null) {
      await _scanFolder(_selectedFolder!, dbService, settings);
      if (_disposed) return;
    }
    for (final folder in additionalFolders) {
      await _scanFolder(folder, dbService, settings);
      if (_disposed) return;
    }
    if (_selectedFolder == null && additionalFolders.isEmpty) {
      await _fetchFromDatabase(dbService, settings);
    }
  }

  Future<void> scanAdditionalFolder(String path) async {
    // 🚀 Capture dependencies at ENTRY
    final dbService = ref.read(dbServiceProvider);
    final settings = ref.read(settingsProvider);
    await _scanFolder(p.canonicalize(path), dbService, settings);
  }

  Future<void> updateSingleSong(SongModel newSong) async {
    // 🚀 Capture dependencies at ENTRY
    final dbService = ref.read(dbServiceProvider);
    final settings = ref.read(settingsProvider);
    final isar = await dbService.db;

    await isar.writeTxn(() async {
      final existingSong =
          await isar.songs.filter().pathEqualTo(newSong.filePath).findFirst();

      if (existingSong != null) {
        existingSong.title = newSong.title;
        existingSong.artist = newSong.artist;
        existingSong.album = newSong.album;
        existingSong.duration = newSong.duration;
        existingSong.year = newSong.year;
        existingSong.trackNumber = newSong.trackNumber;
        existingSong.discNumber = newSong.discNumber;
        existingSong.genre = newSong.genre;
        await isar.songs.put(existingSong);
      }
    });

    final index = _songs.indexWhere((s) => s.filePath == newSong.filePath);
    if (index != -1) {
      _songs[index] = newSong;
      if (_searchQuery.isNotEmpty) {
        search(_searchQuery);
      } else {
        _filteredSongs = List.from(_songs);
      }
      _safeNotify();
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
    // 🚀 Capture dependencies at ENTRY
    final dbService = ref.read(dbServiceProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    _songs.clear();
    _filteredSongs.clear();
    _selectedFolder = null;
    _searchQuery = "";

    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    await prefs.remove('saved_music_folder');

    // This call modifies settingsProvider effectively invalidating watchers,
    // but since we no longer 'watch', LibraryProvider stays alive!
    await settingsNotifier.clearAllMusicFolders();
    if (_disposed) return;

    final isar = await dbService.db;
    await isar.writeTxn(() async {
      await isar.songs.clear();
    });

    _safeNotify();
  }
}

// 🚀 FINAL FIX: No more watch here!
final libraryProvider = ChangeNotifierProvider<LibraryProvider>((ref) {
  return LibraryProvider(ref);
});
