import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/folder_picker.dart';
import 'package:path/path.dart' as p;
import '../services/metadata_service.dart';
import '../services/cue_parser_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';
import 'package:metadata_god/metadata_god.dart' show Metadata;

// Imports for Database
import '../data/schemas.dart'; // The Isar Schema
import 'db_provider.dart'; // To access the DB Service
import '../services/db_service.dart'; // 🚀 IMPORT DBService class
import '../models/song_model.dart';
import 'settings_provider.dart'; // 🚀 IMPORT SettingsState

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
  int _scanToken = 0; // 🚀 Cancellation token for scan operations

  List<SongModel> get songs => _searchQuery.isEmpty ? _songs : _filteredSongs;
  List<SongModel> get allSongs => _songs; // 🚀 Unfiltered — for grouped providers
  String get searchQuery => _searchQuery; // 🚀 Public getter for efficient presentation filtering
  bool get hasSearchQuery => _searchQuery.isNotEmpty; // 🚀 UI can distinguish empty search vs empty library
  int get totalSongCount => _songs.length; // 🚀 Total before filtering
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
    '.dff',
    '.aiff',
    '.aif'
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
    
    debugPrint("📂 [_fetchFromDatabase] Finished! allSongs: ${allSongs.length}, filteredToFolder: ${_songs.length}");
    // 🚀 Only notify if search() didn't already do it — prevents double notification per batch
    if (_searchQuery.isEmpty) {
      _safeNotify();
    }
  }

  SongModel _mapToModel(Song dbSong) {
    // 🚀 CUE SUPPORT: Extract the real audio file extension for CUE virtual paths
    final effectivePath = CuePath.isCuePath(dbSong.path)
        ? CuePath.extractAudioPath(dbSong.path)
        : dbSong.path;
    return SongModel(
      title: dbSong.title,
      artist: dbSong.artist,
      album: dbSong.album ?? "Unknown Album",
      duration: dbSong.duration,
      filePath: dbSong.path,
      fileExtension: p.extension(effectivePath),
      year: dbSong.year,
      trackNumber: dbSong.trackNumber,
      discNumber: dbSong.discNumber,
      genre: dbSong.genre,
      dateAdded: dbSong.dateAdded,
    );
  }

  Future<void> search(String query) async {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _safeNotify(); // Notify display providers to perform the filter ONCE.
  }

  /// Called from UI after the user has already picked a folder via FilePicker.
  /// This avoids a known file_picker deadlock when getDirectoryPath() is called
  /// from a ChangeNotifier provider context with bitsdojo_window on Windows.
  Future<void> setFolder(String path) async {
    debugPrint("📂 [setFolder] Setting folder: $path");

    try {
      final dbService = ref.read(dbServiceProvider);
      final settings = ref.read(settingsProvider);

      final canonicalPath = p.canonicalize(path);
      _selectedFolder = canonicalPath;
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      await prefs.setString('saved_music_folder', canonicalPath);
      _error = null;
      _isPermissionDenied = false;
      
      // 🚀 Cancel any in-progress scan
      _scanToken++;
      
      // 🚀 IMMEDIATE UI REFRESH — don't block
      _songs = [];
      _filteredSongs = [];
      _isLoading = true;
      _safeNotify();
      debugPrint("📂 [setFolder] UI state cleared. Firing background work...");
      
      // 🚀 NON-BLOCKING: Fire DB fetch and scan in background
      // This prevents the UI hang when changing folders.
      _fetchFromDatabase(dbService, settings).then((_) {
        if (!_disposed) {
          _scanFolder(canonicalPath, dbService, settings);
        }
      });
      
      debugPrint("📂 [setFolder] Method completed — UI thread released.");
    } catch (e, stack) {
      debugPrint("❌ [setFolder] ERROR: $e");
      debugPrint("❌ [setFolder] Stack: $stack");
      _error = "Set folder failed: $e";
      _safeNotify();
    }
  }


  Future<void> _scanFolder(
      String path, DBService dbService, SettingsState settings) async {
    if (_isLoading && _selectedFolder == path) {
       // Allow if triggered from setFolder (isLoading already true)
       // but guard against duplicate concurrent scans on same path
    }
    
    // 🚀 Capture token at start for cancellation
    final myToken = _scanToken;
    
    _isLoading = true;
    _error = null;
    _isPermissionDenied = false;
    _safeNotify();

    try {
      debugPrint("🔍 [_scanFolder] Target path: $path (token: $myToken)");
      final dir = Directory(path);
      if (await dir.exists()) {
        if (_disposed || _scanToken != myToken) return;
        
        debugPrint("🔍 [_scanFolder] Directory exists. Starting directory walk...");
        final existingSongs = await dbService.getAllSongs();
        debugPrint("🔍 [_scanFolder] Fetched ${existingSongs.length} existing songs from DB.");
        final existingPaths = existingSongs.map((s) => p.canonicalize(s.path)).toSet();
        
        // Use `await for` instead of `.toList()` to prevent ANR via massive memory buffer block
        final List<String> pathsToProcess = [];
        final List<String> cueFilesToProcess = []; // 🚀 CUE SUPPORT
        
        // Listen to the directory stream and yield frequently to avoid freezing the UI Isolate
        int filesScanned = 0;
        await for (final FileSystemEntity entity in dir.list(
          recursive: !_ignoreSubfolders, 
          followLinks: false
        )) {
          if (_disposed || _scanToken != myToken) return;
          filesScanned++;
          
          if (entity is File) {
            String extension = p.extension(entity.path).toLowerCase();
            if (_audioExtensions.contains(extension)) {
              final canonicalPath = p.canonicalize(entity.path);
              if (!existingPaths.contains(canonicalPath)) {
                pathsToProcess.add(entity.path);
              }
            }
            // 🚀 CUE SUPPORT: Also collect .cue files for parsing
            if (extension == '.cue') {
              cueFilesToProcess.add(entity.path);
            }
          }
          // Yield to the event loop so the UI doesn't hang
          if (filesScanned % 100 == 0) {
            await Future.delayed(Duration.zero);
          }
        }
        
        debugPrint("🔍 [_scanFolder] Found ${pathsToProcess.length} NEW track paths, ${cueFilesToProcess.length} CUE sheets out of total recursive file scope.");

        if (pathsToProcess.isEmpty && cueFilesToProcess.isEmpty) {
           _isLoading = false;
           _safeNotify();
           return;
        }

        // 🚀 Processing in chunks of 20 (reduced from 50 to limit ffprobe pressure)
        for (int i = 0; i < pathsToProcess.length; i += 20) {
          if (_disposed || _scanToken != myToken) return;
          
          final end = (i + 20 < pathsToProcess.length) ? i + 20 : pathsToProcess.length;
          final chunk = pathsToProcess.sublist(i, end);
          
          final metadataBatch = await MetadataService().readMetadataBatch(chunk);
          
          List<Song> batchToAdd = [];
          for (int j = 0; j < chunk.length; j++) {
            final filePath = chunk[j];
            final metadata = metadataBatch[j];
            final ext = p.extension(filePath).toLowerCase();
            
            final Song song = _mapMetadataToSong(filePath, metadata, ext);
            
            // 🚀 DSD tags are already handled by MetadataService._readMetadataViaFFprobe()
            // via the combined getTagsAndInfo() call — no extra ffprobe needed here.
            
            batchToAdd.add(song);
          }

          if (batchToAdd.isNotEmpty) {
            await dbService.saveSongs(batchToAdd);
            debugPrint("🔍 [_scanFolder] Saved chunk index $i to DB (${batchToAdd.length} songs)");
            await _fetchFromDatabase(dbService, settings);
            _safeNotify();
          }
          await Future.delayed(Duration.zero);
        }

        // =====================================================================
        // 🚀 CUE SHEET PROCESSING: Parse .cue files and create virtual tracks
        // =====================================================================
        if (cueFilesToProcess.isNotEmpty) {
          debugPrint("🎵 [_scanFolder] Processing ${cueFilesToProcess.length} CUE sheets...");
          final cueParser = CueParserService();

          for (final cuePath in cueFilesToProcess) {
            if (_disposed || _scanToken != myToken) return;

            final tracks = await cueParser.parseCueFile(cuePath);
            if (tracks.isEmpty) continue;

            debugPrint("🎵 [_scanFolder] CUE: ${p.basename(cuePath)} → ${tracks.length} tracks");

            List<Song> cueBatch = [];
            for (final track in tracks) {
              // Build the virtual CUE path
              final virtualPath = CuePath.encode(
                track.audioFileName,
                track.startOffset,
                track.endOffset,
              );

              // Skip if already in DB
              if (existingPaths.contains(virtualPath)) continue;

              final song = Song()
                ..path = virtualPath
                ..title = track.title
                ..artist = track.performer
                ..album = track.albumTitle ?? "Unknown Album"
                ..duration = track.trackDuration?.inSeconds.toDouble() ?? 0.0
                ..trackNumber = track.trackNumber
                ..discNumber = track.discNumber
                ..year = track.year
                ..genre = track.genre
                ..dateAdded = DateTime.now();

              cueBatch.add(song);
            }

            if (cueBatch.isNotEmpty) {
              await dbService.saveSongs(cueBatch);
              debugPrint("🎵 [_scanFolder] Saved ${cueBatch.length} CUE virtual tracks from ${p.basename(cuePath)}");
              await _fetchFromDatabase(dbService, settings);
              _safeNotify();
            }
            await Future.delayed(Duration.zero);
          }
        }
        
        debugPrint("✅ [_scanFolder] Fully completed batching ${pathsToProcess.length} tracks + ${cueFilesToProcess.length} CUE sheets.");
      } else {
        _error = "Directory does not exist or access denied.";
      }
    } catch (e) {
      print("Scan Error: $e");
      _error = "Scan failed: $e";
    } finally {
      if (_scanToken == myToken) {
        await _fetchFromDatabase(dbService, settings);
        _isLoading = false;
        _safeNotify();
      }
    }
  }

  Song _mapMetadataToSong(String filePath, Metadata? metadata, String ext) {
    final song = Song()
      ..path = p.canonicalize(filePath)
      ..dateAdded = DateTime.now();

    if (metadata == null) {
      song.title = p.basenameWithoutExtension(filePath);
      song.artist = "Unknown Artist";
      song.album = "Unknown Album";
      song.duration = 0.0;
    } else {
      song.title = (metadata.title != null && metadata.title!.isNotEmpty)
          ? metadata.title!
          : p.basenameWithoutExtension(filePath);
      song.artist = (metadata.artist != null && metadata.artist!.isNotEmpty)
          ? metadata.artist!
          : "Unknown Artist";
      song.album = (metadata.album != null && metadata.album!.isNotEmpty)
          ? metadata.album!
          : "Unknown Album";
      song.duration = (metadata.durationMs ?? 0) / 1000.0;
      song.trackNumber = metadata.trackNumber;
      song.discNumber = metadata.discNumber;
      song.year = metadata.year?.toString();
      song.genre = metadata.genre;
    }
    return song;
  }


  Future<void> refreshLibrary() async {
    final dbService = ref.read(dbServiceProvider);
    final settings = ref.read(settingsProvider);
    final additionalFolders = settings.additionalMusicFolders;

    if (_selectedFolder != null) {
      await _scanFolder(_selectedFolder!, dbService, settings);
      if (_disposed) return;
    }
    for (final folder in additionalFolders) {
      await _scanFolder(p.canonicalize(folder), dbService, settings);
      if (_disposed) return;
    }
    if (_selectedFolder == null && additionalFolders.isEmpty) {
      await _fetchFromDatabase(dbService, settings);
    }
  }

  Future<void> scanAdditionalFolder(String path) async {
    final dbService = ref.read(dbServiceProvider);
    final settings = ref.read(settingsProvider);
    await _scanFolder(p.canonicalize(path), dbService, settings);
  }

  Future<void> updateSingleSong(SongModel newSong) async {
    final dbService = ref.read(dbServiceProvider);
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
      _sortSongs();
      _filteredSongs = List.from(_songs);
      _safeNotify();
    }
  }

  static final RegExp _splitPattern = RegExp(r'(\d+)|(\D+)');

  void _sortSongs() {
    _songs.sort((a, b) =>
        _naturalCompare(p.basename(a.filePath), p.basename(b.filePath)));
  }

  int _naturalCompare(String a, String b) {
    a = a.toLowerCase();
    b = b.toLowerCase();
    
    final matchesA =
        _splitPattern.allMatches(a).map((m) => m.group(0)!).toList();
    final matchesB =
        _splitPattern.allMatches(b).map((m) => m.group(0)!).toList();

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
    final dbService = ref.read(dbServiceProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    _songs.clear();
    _filteredSongs.clear();
    _selectedFolder = null;
    _searchQuery = "";

    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    await prefs.remove('saved_music_folder');
    await settingsNotifier.clearAllMusicFolders();
    if (_disposed) return;

    final isar = await dbService.db;
    await isar.writeTxn(() async {
      await isar.songs.clear();
    });

    _safeNotify();
  }
}

final libraryProvider = ChangeNotifierProvider<LibraryProvider>((ref) {
  return LibraryProvider(ref);
});
