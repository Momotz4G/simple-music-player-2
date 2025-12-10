import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert'; // REQUIRED for JSON

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter/foundation.dart';
import 'package:metadata_god/metadata_god.dart';

import '../models/song_model.dart';
import '../services/native_music_service.dart';
import '../services/discord_service.dart';
import '../services/spotify_service.dart';
import '../services/youtube_downloader_service.dart';
import '../services/smart_download_service.dart';
import '../services/windows_taskbar_service.dart';
import '../models/song_metadata.dart';
import 'stats_provider.dart';
import 'history_provider.dart';
import 'settings_provider.dart';

import '../services/db_service.dart';
import '../services/remote_control_service.dart';

// --- STATE CLASS ---
class PlayerState {
  final bool isPlaying;
  final SongModel? currentSong;
  final double currentPosition;
  final double totalDuration;

  // Queue Systems
  final List<SongModel> userQueue; // Priority Queue (Play Next / Add to Queue)
  final List<SongModel> playlist; // Current Context (Album/Playlist/Folder)
  final List<SongModel> originalPlaylist; // Unshuffled / Original order

  final double volume;
  final double unmutedVolume;
  final bool isShuffle;
  final ja.LoopMode loopMode;
  final bool isLyricsVisible;

  // Visuals
  final Color? dominantColor;

  PlayerState({
    this.isPlaying = false,
    this.currentSong,
    this.currentPosition = 0.0,
    this.totalDuration = 0.0,
    this.userQueue = const [],
    this.playlist = const [],
    this.originalPlaylist = const [],
    this.volume = 0.5,
    this.unmutedVolume = 0.5,
    this.isShuffle = false,
    this.loopMode = ja.LoopMode.off,
    this.isLyricsVisible = false,
    this.dominantColor,
  });

  PlayerState copyWith({
    bool? isPlaying,
    SongModel? currentSong,
    double? currentPosition,
    double? totalDuration,
    List<SongModel>? userQueue,
    List<SongModel>? playlist,
    List<SongModel>? originalPlaylist,
    double? volume,
    double? unmutedVolume,
    bool? isShuffle,
    ja.LoopMode? loopMode,
    bool? isLyricsVisible,
    Color? dominantColor,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentSong: currentSong ?? this.currentSong,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      userQueue: userQueue ?? this.userQueue,
      playlist: playlist ?? this.playlist,
      originalPlaylist: originalPlaylist ?? this.originalPlaylist,
      volume: volume ?? this.volume,
      unmutedVolume: unmutedVolume ?? this.unmutedVolume,
      isShuffle: isShuffle ?? this.isShuffle,
      loopMode: loopMode ?? this.loopMode,
      isLyricsVisible: isLyricsVisible ?? this.isLyricsVisible,
      dominantColor: dominantColor ?? this.dominantColor,
    );
  }
}

// --- NOTIFIER CLASS ---
class PlayerNotifier extends StateNotifier<PlayerState> {
  final NativeMusicService _musicService;
  final DiscordService _discordService = DiscordService();
  // Uses the Singleton instance automatically
  final YoutubeDownloaderService _downloaderService =
      YoutubeDownloaderService();
  final SmartDownloadService _smartService = SmartDownloadService();
  final WindowsTaskbarService _taskbarService = WindowsTaskbarService();
  final RemoteControlService _remoteService =
      RemoteControlService(); // Remote Control Service
  final Ref ref;

  Stream<Duration> get positionStream => _musicService.player.positionStream;

  // CRITICAL FOR EQUALIZER: Expose Session ID
  int? get audioSessionId => _musicService.player.androidAudioSessionId;

  int _playlistIndex = 0;
  bool _isSwitchingSong = false;
  bool _isLooping = false;
  bool _isHandlingCompletion = false;

  // Stats config
  bool _isThresholdMet = false;
  bool _isSessionLogged = false;
  double _lastLogPosition = 0.0;
  double _cumulativeSecondsListened = 0.0;
  static const double _playCountThreshold = 0.60;
  DateTime _lastSongChangeTime = DateTime.now();

  // Discord Vars
  String? _cachedDiscordImage;
  String? _lastProcessedSongPath;

  PlayerNotifier(this._musicService, this.ref) : super(PlayerState()) {
    _init();
  }

  void _init() async {
    // Restore Settings
    final prefs = await SharedPreferences.getInstance();
    final volume = prefs.getDouble('volume') ?? 0.5;
    final shuffle = prefs.getBool('shuffle') ?? false;
    final loopIndex = prefs.getInt('loopMode') ?? 0;

    // RESTORE LAST PLAYED SONG
    SongModel? lastSong;
    final lastSongJson = prefs.getString('last_played_song');
    if (lastSongJson != null) {
      try {
        lastSong = SongModel.fromJson(jsonDecode(lastSongJson));
      } catch (e) {
        print("Error restoring last song: $e");
      }
    }

    state = state.copyWith(
      volume: volume,
      unmutedVolume: volume > 0 ? volume : 0.5,
      isShuffle: shuffle,
      loopMode: ja.LoopMode.values[loopIndex],
      currentSong: lastSong, // Set the restored song
    );

    // Apply settings to service
    await _musicService.setVolume(volume);
    _musicService.setLoopMode(ja.LoopMode.values[loopIndex]);

    if (lastSong != null) {
      try {
        // Load the source into audio player without playing
        await _musicService.load(lastSong);
      } catch (e) {
        print("Error loading restored song: $e");
      }
    }

    // RESTORE QUEUE STATE
    await _restoreQueueState();

    // Initialize Discord
    Future.delayed(const Duration(seconds: 2), () {
      _discordService.init();

      // SYNC INITIAL SETTING
      final settings = ref.read(settingsProvider);
      _discordService.setEnabled(settings.enableDiscordRpc);

      // Initialize Taskbar Service
      _taskbarService.initialize(
        onPlay: () => _musicService.resume(),
        onPause: () => _musicService.pause(),
        onNext: () => playNext(),
        onPrevious: () => playPrevious(),
      );

      // Initialize Remote Control
      _remoteService.init().then((_) {
        _remoteService.startListening(onCommand: _handleRemoteCommand);
      });
    });

    // LISTEN FOR SETTINGS CHANGES
    ref.listen(settingsProvider, (previous, next) {
      if (previous?.enableDiscordRpc != next.enableDiscordRpc) {
        _discordService.setEnabled(next.enableDiscordRpc);
      }
    });

    // Initialize the Downloader Service
    _downloaderService.initialize().catchError((e) {
      if (kDebugMode) print("FATAL DOWNLOADER INIT ERROR: $e");
    });

    // Load settings first (Volume, Shuffle, Repeat)
    _loadSettings();

    // Extract color immediately if a song is already loaded (Persistence)
    if (state.currentSong != null) {
      _extractPalette(state.currentSong!.filePath);
    }

    _musicService.player.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(totalDuration: duration.inSeconds.toDouble());
      }
    });

    _musicService.player.positionStream.listen((position) {
      final currentSecs = position.inSeconds.toDouble();
      final duration = state.totalDuration;

      state = state.copyWith(currentPosition: currentSecs);

      // Manual Loop One Logic
      if (state.loopMode == ja.LoopMode.one && duration > 0) {
        if (currentSecs >= (duration - 0.5)) {
          _forceLoopOne();
        }
      }

      // Stats Logic
      if (DateTime.now().difference(_lastSongChangeTime).inSeconds < 2) return;

      if (state.currentSong != null && state.isPlaying) {
        double delta = currentSecs - _lastLogPosition;
        if (delta > 0 && delta < 5) {
          ref
              .read(statsProvider.notifier)
              .logTime(state.currentSong!, delta.toInt());
          _cumulativeSecondsListened += delta;
        }
        _lastLogPosition = currentSecs;
      }

      if (!_isSessionLogged && !_isThresholdMet && state.totalDuration > 0) {
        if (_cumulativeSecondsListened >=
            (state.totalDuration * _playCountThreshold)) {
          _isThresholdMet = true;
        }
      }
    });

    _musicService.player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      if (processingState == ja.ProcessingState.completed) {
        if (_isHandlingCompletion) return;
        _isHandlingCompletion = true;

        if (state.loopMode == ja.LoopMode.one) {
          _forceLoopOne();
        } else {
          _finalizePlaySession();
          playNext(autoPlay: true);
        }
        return;
      }

      if (processingState != ja.ProcessingState.completed) {
        _isHandlingCompletion = false;
      }

      if (_isSwitchingSong) {
        if (isPlaying && processingState == ja.ProcessingState.ready) {
          _isSwitchingSong = false;
        } else {
          if (!state.isPlaying) state = state.copyWith(isPlaying: true);
          return;
        }
      }

      if (state.isPlaying != isPlaying) {
        state = state.copyWith(isPlaying: isPlaying);
        _updateDiscord();
        _updateTaskbar(); // UPDATE TASKBAR STATUS
      }
    });
  }

  // --- DOWNLOAD INTEGRATION ---
  Future<bool> downloadFromSearch({
    required String youtubeUrl,
    required String artist,
    required String title,
    required Function(double progress) onProgress,
    required Function(bool success) onComplete,
  }) async {
    final tempFileName = '$artist - $title';
    final outputPath = await _downloaderService.getDownloadPath(tempFileName);

    if (outputPath == null) {
      onComplete(false);
      return false;
    }

    await _downloaderService.startDownloadFromUrl(
      youtubeUrl: youtubeUrl,
      outputFilePath: outputPath,
      onProgress: onProgress,
      onComplete: onComplete,
    );

    return true;
  }

  // --- QUEUE MANAGEMENT METHODS ---

  void reorderUserQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final newQueue = List<SongModel>.from(state.userQueue);
    final song = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, song);

    state = state.copyWith(userQueue: newQueue);
    _saveQueueState(); // SAVE STATE
  }

  void reorderMainPlaylist(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    if (oldIndex < 0 ||
        oldIndex >= state.playlist.length ||
        newIndex < 0 ||
        newIndex >= state.playlist.length) return;

    final newPlaylist = List<SongModel>.from(state.playlist);
    final song = newPlaylist.removeAt(oldIndex);
    newPlaylist.insert(newIndex, song);

    if (!state.isShuffle) {
      state = state.copyWith(
        playlist: newPlaylist,
        originalPlaylist: newPlaylist,
      );
      if (state.currentSong != null) {
        _playlistIndex = newPlaylist
            .indexWhere((s) => s.filePath == state.currentSong!.filePath);
      }
    } else {
      state = state.copyWith(playlist: newPlaylist);
      if (state.currentSong != null) {
        _playlistIndex = newPlaylist
            .indexWhere((s) => s.filePath == state.currentSong!.filePath);
      }
    }
    _saveQueueState(); // SAVE STATE
  }

  Future<void> insertSongNext(SongModel song) async {
    // Append to userQueue (FIFO for Play Next batch) instead of prepending
    final newQueue = List<SongModel>.from(state.userQueue)..add(song);
    state = state.copyWith(userQueue: newQueue);
    _saveQueueState(); // SAVE STATE

    // TRIGGER PRELOAD IMMEDIATELY
    // This ensures the song is ready when the current one finishes.
    if (!await File(song.filePath).exists()) {
      print("🚀 PLAY NEXT: Preloading ${song.title}...");
      final meta = SongMetadata(
        title: song.title,
        artist: song.artist,
        album: song.album,
        albumArtUrl: song.onlineArtUrl ?? "",
        durationSeconds: song.duration.toInt(),
        year: "",
        genre: "",
      );
      _smartService.cacheSong(meta, youtubeUrl: song.sourceUrl);
    }
  }

  void addToQueue(SongModel song) {
    final newQueue = List<SongModel>.from(state.userQueue)..add(song);
    state = state.copyWith(userQueue: newQueue);
    _saveQueueState(); // SAVE STATE
  }

  Future<void> playPrioritySong(SongModel song) async {
    _finalizePlaySession();
    _startNewSession(resetTime: true);
    _isLooping = false;

    final newQueue = List<SongModel>.from(state.userQueue);
    newQueue.remove(song);
    state = state.copyWith(userQueue: newQueue);
    _saveQueueState(); // SAVE STATE

    // Save to history
    ref.read(historyProvider.notifier).addToHistory(
          song: song,
          youtubeUrl: song.sourceUrl,
          artUrl: song.onlineArtUrl,
        );

    _extractPalette(song.filePath);

    _isSwitchingSong = true;
    state = state.copyWith(currentSong: song, isPlaying: true);

    await _musicService.play(song);
    _updateDiscord();
  }

  // --- COLOR EXTRACTION (Fixed for MP3s) ---
  Future<void> _extractPalette(String filePath) async {
    if (filePath.isEmpty) {
      state = state.copyWith(dominantColor: null);
      return;
    }

    try {
      // Read metadata from file to get image bytes first!
      final metadata = await MetadataGod.readMetadata(file: filePath);
      final bytes = metadata.picture?.data;

      if (bytes == null) {
        state = state.copyWith(dominantColor: null);
        return;
      }

      // Use MemoryImage with the bytes we just read
      final palette = await PaletteGenerator.fromImageProvider(
        MemoryImage(bytes),
        maximumColorCount: 20,
      );

      Color? color = palette.lightVibrantColor?.color ??
          palette.vibrantColor?.color ??
          palette.lightMutedColor?.color ??
          palette.dominantColor?.color;

      if (color != null) {
        final hsl = HSLColor.fromColor(color);
        final poppedColor = hsl
            .withLightness(max(hsl.lightness, 0.6))
            .withSaturation(min(hsl.saturation + 0.2, 1.0))
            .toColor();

        state = state.copyWith(dominantColor: poppedColor);
      } else {
        state = state.copyWith(dominantColor: null);
      }
    } catch (e) {
      if (kDebugMode) print("Error extracting colors: $e");
      state = state.copyWith(dominantColor: null);
    }
  }

  // --- SETTINGS LOADING ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVolume = prefs.getDouble('volume') ?? 0.5;
    await _musicService.setVolume(savedVolume);

    final savedShuffle = prefs.getBool('shuffle') ?? false;
    final savedLoopIndex = prefs.getInt('loopMode') ?? 0;
    final savedLoopMode = ja.LoopMode.values.length > savedLoopIndex
        ? ja.LoopMode.values[savedLoopIndex]
        : ja.LoopMode.off;

    if (savedLoopMode == ja.LoopMode.one) {
      await _musicService.setLoopMode(ja.LoopMode.off);
    } else {
      await _musicService.setLoopMode(savedLoopMode);
    }

    state = state.copyWith(
      volume: savedVolume,
      unmutedVolume: savedVolume,
      isShuffle: savedShuffle,
      loopMode: savedLoopMode,
    );
  }

  // --- QUEUE PERSISTENCE ---
  Future<void> _saveQueueState() async {
    final prefs = await SharedPreferences.getInstance();

    // Serialize lists
    final playlistJson =
        jsonEncode(state.playlist.map((s) => s.toJson()).toList());
    final originalPlaylistJson =
        jsonEncode(state.originalPlaylist.map((s) => s.toJson()).toList());
    final userQueueJson =
        jsonEncode(state.userQueue.map((s) => s.toJson()).toList());

    await prefs.setString('queue_playlist', playlistJson);
    await prefs.setString('queue_original_playlist', originalPlaylistJson);
    await prefs.setString('queue_user_queue', userQueueJson);
  }

  Future<void> _restoreQueueState() async {
    final prefs = await SharedPreferences.getInstance();

    final playlistJson = prefs.getString('queue_playlist');
    final originalPlaylistJson = prefs.getString('queue_original_playlist');
    final userQueueJson = prefs.getString('queue_user_queue');

    List<SongModel> playlist = [];
    List<SongModel> originalPlaylist = [];
    List<SongModel> userQueue = [];

    if (playlistJson != null) {
      playlist = (jsonDecode(playlistJson) as List)
          .map((e) => SongModel.fromJson(e))
          .toList();
    }

    if (originalPlaylistJson != null) {
      originalPlaylist = (jsonDecode(originalPlaylistJson) as List)
          .map((e) => SongModel.fromJson(e))
          .toList();
    }

    if (userQueueJson != null) {
      userQueue = (jsonDecode(userQueueJson) as List)
          .map((e) => SongModel.fromJson(e))
          .toList();
    }

    state = state.copyWith(
      playlist: playlist,
      originalPlaylist: originalPlaylist,
      userQueue: userQueue,
    );

    // Recalculate index if we have a current song
    if (state.currentSong != null && playlist.isNotEmpty) {
      _playlistIndex =
          playlist.indexWhere((s) => s.filePath == state.currentSong!.filePath);
      if (_playlistIndex == -1) _playlistIndex = 0;
    }
  }

  // --- CONTROLS ---

  Future<void> _forceLoopOne() async {
    if (_isLooping) return;
    _isLooping = true;

    _finalizePlaySession();
    _startNewSession(resetTime: false);

    state = state.copyWith(currentPosition: 0.0);
    await _musicService.seek(0);

    if (!state.isPlaying) {
      await _musicService.resume();
    }

    _updateDiscord();

    Future.delayed(const Duration(seconds: 1), () {
      _isLooping = false;
    });
  }

  void _finalizePlaySession() {
    if (_isSessionLogged) return;
    if (_isThresholdMet && state.currentSong != null) {
      ref.read(statsProvider.notifier).logPlay(state.currentSong!);

      // TRACK PLAYS IN DB & CLOUD
      // StatsProvider only tracks transient session stats.
      // This call updates Isar DB + Firebase Metrics
      // We use fire-and-forget for performance
      DBService().updateSongPlayCountByPath(state.currentSong!.filePath);

      _isSessionLogged = true;
    }
  }

  void _startNewSession({bool resetTime = true}) {
    _isThresholdMet = false;
    _isSessionLogged = false;
    _lastLogPosition = 0.0;
    _cumulativeSecondsListened = 0.0;
    if (resetTime) {
      _lastSongChangeTime = DateTime.now();
    }
  }

  // JIT CACHE HELPER
  Future<SongModel> _ensureFileExists(SongModel song) async {
    if (await File(song.filePath).exists()) return song;

    print("⚠️ File missing: ${song.filePath}. Triggering JIT Cache...");
    final meta = SongMetadata(
      title: song.title,
      artist: song.artist,
      album: song.album,
      albumArtUrl: song.onlineArtUrl ?? "",
      durationSeconds: song.duration.toInt(),
      year: "",
      genre: "",
      isrc: song.isrc,
    );

    // Attempt Cache
    await _smartService.cacheSong(meta, youtubeUrl: song.sourceUrl);

    final cachedPath = await _smartService.getPredictedCachePath(meta);
    if (await File(cachedPath).exists()) {
      print("✅ JIT Success! New path: $cachedPath");
      return song.copyWith(filePath: cachedPath);
    }

    return song;
  }

  Future<void> playRandom(List<SongModel> newQueue) async {
    if (newQueue.isEmpty) return;
    _finalizePlaySession();
    if (!state.isShuffle) {
      state = state.copyWith(isShuffle: true);
      _saveSettings();
    }
    // _saveQueueState() will be called in playSong
    final randomSong = newQueue[Random().nextInt(newQueue.length)];
    await playSong(randomSong, newQueue: newQueue, skipFinalize: true);
  }

  // PRELOAD NEXT SONG LOGIC
  Future<void> _preloadNextSong() async {
    SongModel? nextSong;

    // 1. Check User Queue
    if (state.userQueue.isNotEmpty) {
      nextSong = state.userQueue.first;
    }
    // 2. Check Playlist
    else if (state.playlist.isNotEmpty) {
      int nextIndex = _playlistIndex + 1;
      if (nextIndex < state.playlist.length) {
        nextSong = state.playlist[nextIndex];
      } else if (state.loopMode == ja.LoopMode.all) {
        nextSong = state.playlist.first;
      }
    }

    if (nextSong != null) {
      // Check if file exists
      if (await File(nextSong.filePath).exists()) return;

      print("🚀 PRELOAD: Preloading next song: ${nextSong.title}");

      // Reconstruct Metadata
      final meta = SongMetadata(
        title: nextSong.title,
        artist: nextSong.artist,
        album: nextSong.album,
        albumArtUrl: nextSong.onlineArtUrl ?? "",
        durationSeconds: nextSong.duration.toInt(),
        year: "", // Missing in SongModel, acceptable
        genre: "", // Missing
        isrc: nextSong.isrc,
      );

      // Trigger Background Cache
      _smartService.cacheSong(meta, youtubeUrl: nextSong.sourceUrl);
    }
  }

  // PRELOAD PREVIOUS SONG
  Future<void> _preloadPreviousSong() async {
    if (state.playlist.isEmpty) return;

    int prevIndex = _playlistIndex - 1;
    if (prevIndex < 0) {
      if (state.loopMode == ja.LoopMode.all) {
        prevIndex = state.playlist.length - 1;
      } else {
        return;
      }
    }

    final prevSong = state.playlist[prevIndex];
    if (await File(prevSong.filePath).exists()) return;

    print("🚀 PRELOAD PREV: ${prevSong.title}");
    final meta = SongMetadata(
      title: prevSong.title,
      artist: prevSong.artist,
      album: prevSong.album,
      albumArtUrl: prevSong.onlineArtUrl ?? "",
      durationSeconds: prevSong.duration.toInt(),
      year: "",
      genre: "",
      isrc: prevSong.isrc,
    );
    _smartService.cacheSong(meta, youtubeUrl: prevSong.sourceUrl);
  }

  Future<void> playSong(SongModel song,
      {List<SongModel>? newQueue,
      bool skipFinalize = false,
      bool forceReload = false}) async {
    if (!skipFinalize) _finalizePlaySession();
    _startNewSession(resetTime: true);
    _isLooping = false;

    // Save to history
    ref.read(historyProvider.notifier).addToHistory(
          song: song,
          youtubeUrl: song.sourceUrl,
          artUrl: song.onlineArtUrl,
        );

    // EXTRACT COLOR
    _extractPalette(song.filePath);

    if (newQueue != null) {
      if (state.isShuffle) {
        final shuffled = List<SongModel>.from(newQueue)..shuffle();
        // Use reference equality first, fallback to path/url
        // This prevents removing ALL online songs if they share empty paths
        bool removed = shuffled.remove(song);
        if (!removed) {
          shuffled.removeWhere(
              (s) => s.filePath == song.filePath && s.title == song.title);
        }
        shuffled.insert(0, song);
        state = state.copyWith(playlist: shuffled, originalPlaylist: newQueue);
        _playlistIndex = 0;
      } else {
        state = state.copyWith(playlist: newQueue, originalPlaylist: newQueue);
        // Use indexOf first
        _playlistIndex = newQueue.indexOf(song);
        if (_playlistIndex == -1) {
          _playlistIndex =
              newQueue.indexWhere((s) => s.filePath == song.filePath);
        }
      }
    } else {
      // Use indexOf first
      _playlistIndex = state.playlist.indexOf(song);
      if (_playlistIndex == -1) {
        _playlistIndex =
            state.playlist.indexWhere((s) => s.filePath == song.filePath);
      }
    }

    if (_playlistIndex == -1) _playlistIndex = 0;

    // JIT CACHING CHECK
    if (!await File(song.filePath).exists()) {
      print(
          "⚠️ Play Error: File not found at ${song.filePath}. Attempting JIT Cache...");
      final meta = SongMetadata(
        title: song.title,
        artist: song.artist,
        album: song.album,
        albumArtUrl: song.onlineArtUrl ?? "",
        durationSeconds: song.duration.toInt(),
        year: "",
        genre: "",
        isrc: song.isrc,
      );
      print("🚀 JIT Cache Triggered for: ${song.title}");
      if (song.isrc != null) print("   ✅ Using ISRC: ${song.isrc}");

      // We use cacheSong but we need to wait for it!
      await _smartService.cacheSong(meta, youtubeUrl: song.sourceUrl);

      // CHECK IF CACHED FILE EXISTS (Path might differ from song.filePath)
      final cachedPath = await _smartService.getPredictedCachePath(meta);
      if (await File(cachedPath).exists()) {
        print("✅ JIT Cache Successful! Switching path to: $cachedPath");
        // Update song object with new path
        song = song.copyWith(filePath: cachedPath);

        // Update in Playlist/Queue if possible (optional but good for consistency)
        // We won't iterate the whole list here to avoid performance hit,
        // but we ensure 'currentSong' gets the valid path.
      } else if (!await File(song.filePath).exists()) {
        print("❌ JIT Cache Failed. Skipping.");
        if (skipFinalize) {
          playNext(autoPlay: true);
          return;
        }
        if (newQueue != null || state.playlist.isNotEmpty) {
          playNext(autoPlay: true);
          return;
        }
      }
    }

    final isSameSong = state.currentSong?.filePath == song.filePath;
    if (isSameSong && !forceReload) {
      await _musicService.seek(0);
      if (!state.isPlaying) await _musicService.resume();
    } else {
      _isSwitchingSong = true;
      state = state.copyWith(currentSong: song, isPlaying: true);
      _musicService.play(song);
    }
    _updateDiscord();
    _saveSettings(); // SAVE STATE
    _saveQueueState(); // SAVE QUEUE

    _updateDiscord();
    _saveSettings(); // SAVE STATE
    _saveQueueState(); // SAVE QUEUE

    // TRIGGER PRELOAD (Next + Previous)
    _preloadNextSong();
    _preloadPreviousSong();
  }

  Future<void> playNext({bool autoPlay = false}) async {
    if (!autoPlay) _finalizePlaySession();
    _startNewSession(resetTime: true);
    _isLooping = false;

    // 1. Check User Queue (Priority)
    if (state.userQueue.isNotEmpty) {
      var nextSong = state.userQueue.first;
      // Save to history
      ref.read(historyProvider.notifier).addToHistory(
            song: nextSong,
            youtubeUrl: nextSong.sourceUrl,
            artUrl: nextSong.onlineArtUrl,
          );

      state = state.copyWith(userQueue: state.userQueue.sublist(1));
      _saveQueueState(); // SAVE QUEUE

      _isSwitchingSong = true;
      state = state.copyWith(currentSong: nextSong, isPlaying: true);

      // EXTRACT COLOR
      _extractPalette(nextSong.filePath);

      // JIT CACHING CHECK
      if (!await File(nextSong.filePath).exists()) {
        print(
            "⚠️ Play Next: File not found at ${nextSong.filePath}. Attempting JIT Cache...");
        final meta = SongMetadata(
          title: nextSong.title,
          artist: nextSong.artist,
          album: nextSong.album,
          albumArtUrl: nextSong.onlineArtUrl ?? "",
          durationSeconds: nextSong.duration.toInt(),
          year: "",
          genre: "",
        );
        await _smartService.cacheSong(meta, youtubeUrl: nextSong.sourceUrl);

        // CHECK IF CACHED FILE EXISTS (Path might differ from nextSong.filePath)
        final cachedPath = await _smartService.getPredictedCachePath(meta);
        if (await File(cachedPath).exists()) {
          print("✅ JIT Cache Successful! Switching path to: $cachedPath");
          // Update song object with new path
          nextSong = nextSong.copyWith(filePath: cachedPath);
        }
      }

      // VERIFY FILE EXISTS
      if (!await File(nextSong.filePath).exists()) {
        print("❌ Play Next Error: File missing after JIT. Skipping.");
        // Recursively try next song
        playNext(autoPlay: true);
        return;
      }

      _musicService.play(nextSong);
      _updateDiscord();

      // TRIGGER PRELOAD
      _preloadNextSong();
      return;
    }

    // 2. Check Playlist
    if (state.playlist.isEmpty) return;

    int nextIndex = _playlistIndex + 1;
    if (nextIndex >= state.playlist.length) {
      if (state.loopMode == ja.LoopMode.all) {
        nextIndex = 0;
      } else {
        // PAUSE AT END OF QUEUE
        state = state.copyWith(isPlaying: false);
        await _musicService.pause();
        return;
      }
    }

    _playlistIndex = nextIndex;
    var nextSong = state.playlist[nextIndex];
    // Save to history
    ref.read(historyProvider.notifier).addToHistory(
          song: nextSong,
          youtubeUrl: nextSong.sourceUrl,
          artUrl: nextSong.onlineArtUrl,
        );

    _isSwitchingSong = true;
    state = state.copyWith(currentSong: nextSong, isPlaying: true);

    // EXTRACT COLOR
    _extractPalette(nextSong.filePath);

    // JIT CACHING CHECK
    if (!await File(nextSong.filePath).exists()) {
      print(
          "⚠️ Play Next: File not found at ${nextSong.filePath}. Attempting JIT Cache...");
      final meta = SongMetadata(
        title: nextSong.title,
        artist: nextSong.artist,
        album: nextSong.album,
        albumArtUrl: nextSong.onlineArtUrl ?? "",
        durationSeconds: nextSong.duration.toInt(),
        year: "",
        genre: "",
      );
      await _smartService.cacheSong(meta);

      // CHECK IF CACHED FILE EXISTS
      final cachedPath = await _smartService.getPredictedCachePath(meta);
      if (await File(cachedPath).exists()) {
        print("✅ JIT Cache Successful! Switching path to: $cachedPath");
        nextSong = nextSong.copyWith(filePath: cachedPath);
      }
    }

    _musicService.play(nextSong);
    _updateDiscord();

    // TRIGGER PRELOAD
    _preloadNextSong();
  }

  Future<void> playPrevious() async {
    final pos = await _musicService.player.position;
    if (pos.inSeconds > 3) {
      await _musicService.seek(0);
      return;
    }

    _finalizePlaySession();
    _startNewSession(resetTime: true);
    _isLooping = false;

    if (_playlistIndex > 0) {
      _playlistIndex--;
    } else if (state.playlist.isNotEmpty) {
      // Only loop to end if LoopMode is ALL
      if (state.loopMode == ja.LoopMode.all) {
        _playlistIndex = state.playlist.length - 1;
      } else {
        // Otherwise just restart the current song
        await _musicService.seek(0);
        return;
      }
    }
    final prevSong = state.playlist[_playlistIndex];
    // Save to history
    ref.read(historyProvider.notifier).addToHistory(
          song: prevSong,
          youtubeUrl: prevSong.sourceUrl,
          artUrl: prevSong.onlineArtUrl,
        );

    _isSwitchingSong = true;
    state = state.copyWith(currentSong: prevSong, isPlaying: true);

    // JIT CACHE CHECK FOR PREVIOUS
    final readySong = await _ensureFileExists(prevSong);
    state = state.copyWith(currentSong: readySong);

    // EXTRACT COLOR (Safe now)
    _extractPalette(readySong.filePath);

    _musicService.play(readySong);
    _updateDiscord();

    // Trigger Preloads
    _preloadNextSong();
    _preloadPreviousSong();
  }

  Future<void> togglePlay() async {
    if (state.isPlaying) {
      await _musicService.pause();
    } else {
      await _musicService.resume();
    }
  }

  Future<void> seek(double seconds) async {
    await _musicService.seek(seconds);
    _lastLogPosition = seconds;
    _updateDiscord();
  }

  Future<void> setVolume(double value) async {
    final newUnmuted = value > 0 ? value : state.unmutedVolume;
    state = state.copyWith(volume: value, unmutedVolume: newUnmuted);
    await _musicService.setVolume(value);
    _saveSettings();
  }

  Future<void> toggleMute() async {
    if (state.volume > 0) {
      await setVolume(0);
    } else {
      double restore = state.unmutedVolume > 0 ? state.unmutedVolume : 0.5;
      await setVolume(restore);
    }
  }

  // SWAP VERSION (Select Version Feature)
  Future<void> swapCurrentSongVersion(String newUrl) async {
    final song = state.currentSong;
    if (song == null) return;

    print("🔄 Swapping version for ${song.title} to $newUrl");

    // 1. Pause Player
    await _musicService.pause();

    // 2. Delete Old File (Critical so JIT triggers)
    try {
      final file = File(song.filePath);
      if (await file.exists()) {
        await file.delete();
        print("🗑️ Deleted old file: ${song.filePath}");
      }
    } catch (e) {
      print("⚠️ Error deleting old file: $e");
    }

    // 3. Update Song Model
    // KEEP METADATA (Spotify): Only update sourceUrl. Keep Art, Title, Artist, Album.
    final updatedSong = song.copyWith(
      sourceUrl: newUrl,
      // onlineArtUrl: newThumbnail ?? song.onlineArtUrl, // ❌ REMOVED: Keep original art
    );

    // 4. Update in Queue/Playlist (Optional but good for consistency)
    // We update the current song in the state immediately
    state = state.copyWith(currentSong: updatedSong);

    // 5. Re-Play (Triggers JIT Cache with new URL)
    // We pass skipFinalize: true because we are technically continuing the same song session
    await playSong(updatedSong, skipFinalize: true, forceReload: true);
  }

  void toggleShuffle() {
    final newShuffle = !state.isShuffle;
    final baseList = state.originalPlaylist.isNotEmpty
        ? state.originalPlaylist
        : state.playlist;
    if (newShuffle) {
      final shuffled = List<SongModel>.from(baseList)..shuffle();
      if (state.currentSong != null) {
        shuffled.removeWhere((s) => s.filePath == state.currentSong!.filePath);
        shuffled.insert(0, state.currentSong!);
      }
      state = state.copyWith(
          isShuffle: true, playlist: shuffled, originalPlaylist: baseList);
      _playlistIndex = 0;
    } else {
      state = state.copyWith(
          isShuffle: false, playlist: baseList, originalPlaylist: baseList);
      if (state.currentSong != null) {
        _playlistIndex = baseList
            .indexWhere((s) => s.filePath == state.currentSong!.filePath);
      }
    }
    _saveSettings();
  }

  void cycleLoopMode() {
    final current = state.loopMode;
    ja.LoopMode nextMode;
    switch (current) {
      case ja.LoopMode.off:
        nextMode = ja.LoopMode.all;
        break;
      case ja.LoopMode.all:
        nextMode = ja.LoopMode.one;
        break;
      case ja.LoopMode.one:
        nextMode = ja.LoopMode.off;
        break;
    }

    _musicService.setLoopMode(nextMode);
    state = state.copyWith(loopMode: nextMode);
    _saveSettings();
  }

  Future<void> _updateDiscord() async {
    if (state.currentSong != null) {
      final song = state.currentSong!;

      if (song.filePath != _lastProcessedSongPath) {
        _lastProcessedSongPath = song.filePath;
        _cachedDiscordImage = null;

        _discordService.updatePresence(
          song,
          state.isPlaying,
          Duration(seconds: state.currentPosition.toInt()),
          Duration(seconds: state.totalDuration.toInt()),
          imageUrl: null,
        );

        SpotifyService.getTrackImage(song.title, song.artist).then((artUrl) {
          if (artUrl != null) {
            _cachedDiscordImage = artUrl;
            _discordService.updatePresence(
              song,
              state.isPlaying,
              Duration(seconds: state.currentPosition.toInt()),
              Duration(seconds: state.totalDuration.toInt()),
              imageUrl: artUrl,
            );
          }
        }).catchError((e) {
          print("Discord Art Error: $e");
          return null;
        });
      } else {
        _discordService.updatePresence(
          song,
          state.isPlaying,
          Duration(seconds: state.currentPosition.toInt()),
          Duration(seconds: state.totalDuration.toInt()),
          imageUrl: _cachedDiscordImage,
        );
      }
    } else {
      _discordService.clearPresence();
    }
    // SYNC REMOTE CONTROL STATE
    if (state.currentSong != null) {
      _remoteService.broadcastState(
        title: state.currentSong!.title,
        artist: state.currentSong!.artist,
        isPlaying: state.isPlaying,
        volume: state.volume,
        positionSeconds: state.currentPosition.toInt(),
        durationSeconds: state.totalDuration.toInt(),
        artUrl: state.currentSong!.onlineArtUrl,
        filePath: state.currentSong!.filePath, // PASS LOCAL PATH
      );
    }

    _updateTaskbar(); // SYNC TASKBAR
    _saveSettings(); // SAVE STATE
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('volume', state.volume);
    await prefs.setBool('shuffle', state.isShuffle);
    await prefs.setInt('loopMode', state.loopMode.index);

    // SAVE LAST PLAYED SONG
    if (state.currentSong != null) {
      final songJson = jsonEncode(state.currentSong!.toJson());
      await prefs.setString('last_played_song', songJson);
    }
  }

  Future<void> _updateTaskbar() async {
    if (state.currentSong != null) {
      final song = state.currentSong!;
      await _taskbarService.updateMetadata(
        title: song.title,
        artist: song.artist,
        album: song.album,
        thumbnailPath: song.onlineArtUrl,
      );
      await _taskbarService.updatePlaybackStatus(state.isPlaying);
    } else {
      await _taskbarService.updatePlaybackStatus(false);
    }
  }

  void setLyricsVisibility(bool visible) {
    state = state.copyWith(isLyricsVisible: visible);
  }

  // Handle Remote Commands
  void _handleRemoteCommand(String action, dynamic value) {
    print("🎮 PlayerProvider processing command: $action ($value)");
    switch (action) {
      case 'play':
        _musicService.resume();
        break;
      case 'pause':
        _musicService.pause();
        break;
      case 'next':
        playNext();
        break;
      case 'previous':
        playPrevious();
        break;
      case 'volume':
        if (value is num) {
          setVolume(value.toDouble());
        }
        break;
    }
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final musicService = NativeMusicService();
  return PlayerNotifier(musicService, ref);
});
