import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert'; // REQUIRED for JSON

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/usb_audio_service.dart'; // USB Audio for Android <14
import 'package:shared_preferences/shared_preferences.dart'; // Just ensuring
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
import '../services/debug_log_service.dart'; // 🚀 IMPORT
import '../models/song_metadata.dart';
import 'stats_provider.dart';
import 'history_provider.dart';
import 'settings_provider.dart';

import '../services/db_service.dart';
import '../services/remote_control_service.dart';

import '../services/auto_queue_service.dart';

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
  final List<SongModel>
      recommendationQueue; // Auto-recommendations from Endless Queue

  final double volume;
  final double unmutedVolume;
  final bool isShuffle;
  final ja.LoopMode loopMode;
  final bool isLyricsVisible;

  // Visuals
  final Color? dominantColor;

  // Endless Queue
  final bool endlessQueueEnabled;

  // Buffering indicator
  final bool isBuffering;

  PlayerState({
    this.isPlaying = false,
    this.currentSong,
    this.currentPosition = 0.0,
    this.totalDuration = 0.0,
    this.userQueue = const [],
    this.playlist = const [],
    this.originalPlaylist = const [],
    this.recommendationQueue = const [],
    this.volume = 0.5,
    this.unmutedVolume = 0.5,
    this.isShuffle = false,
    this.loopMode = ja.LoopMode.off,
    this.isLyricsVisible = false,
    this.dominantColor,
    this.endlessQueueEnabled = true, // Enabled by default
    this.isBuffering = false,
  });

  PlayerState copyWith({
    bool? isPlaying,
    SongModel? currentSong,
    double? currentPosition,
    double? totalDuration,
    List<SongModel>? userQueue,
    List<SongModel>? playlist,
    List<SongModel>? originalPlaylist,
    List<SongModel>? recommendationQueue,
    double? volume,
    double? unmutedVolume,
    bool? isShuffle,
    ja.LoopMode? loopMode,
    bool? isLyricsVisible,
    Color? dominantColor,
    bool? endlessQueueEnabled,
    bool? isBuffering,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentSong: currentSong ?? this.currentSong,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      userQueue: userQueue ?? this.userQueue,
      playlist: playlist ?? this.playlist,
      originalPlaylist: originalPlaylist ?? this.originalPlaylist,
      recommendationQueue: recommendationQueue ?? this.recommendationQueue,
      volume: volume ?? this.volume,
      unmutedVolume: unmutedVolume ?? this.unmutedVolume,
      isShuffle: isShuffle ?? this.isShuffle,
      loopMode: loopMode ?? this.loopMode,
      isLyricsVisible: isLyricsVisible ?? this.isLyricsVisible,
      dominantColor: dominantColor ?? this.dominantColor,
      endlessQueueEnabled: endlessQueueEnabled ?? this.endlessQueueEnabled,
      isBuffering: isBuffering ?? this.isBuffering,
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
  late final AutoQueueService _autoQueueService; // Endless Queue Service
  final Ref ref;

  // USB Audio bypass flag (for Android <14 bit-perfect playback)
  bool _useUsbAudioBypass = false;
  UsbDacDevice? _connectedUsbDac;

  Stream<Duration> get positionStream => _musicService.player.positionStream;

  // CRITICAL FOR EQUALIZER: Expose Session ID
  int? get audioSessionId => _musicService.player.androidAudioSessionId;

  int _playlistIndex = 0;
  // _isSwitchingSong removed
  bool _isLooping = false;
  bool _isHandlingCompletion = false;
  final Set<int> _preloadCheckpoints = {}; // 🚀 Track preload at 0%, 30%, 70%
  String? _preloadingTitle; // 🚀 Guard: currently preloading song title
  int _consecutiveSkipCount = 0; // 🚀 Prevent infinite skip loops
  static const int _maxConsecutiveSkips = 3; // Max before stopping

  // 🚀 ANDROID FIX: Static guard to prevent re-initialization on lifecycle events
  // This prevents stale saved songs from overwriting the current audio source
  static bool _globalInitialized = false;

  // Stats config
  bool _isThresholdMet = false;
  bool _isSessionLogged = false;
  double _lastLogPosition = 0.0;
  double _lastSavedPosition = 0.0; // 💾 For periodic saving
  double _cumulativeSecondsListened = 0.0;
  static const double _playCountThreshold = 0.60;
  DateTime _lastSongChangeTime = DateTime.now();

  // Discord Vars
  String? _cachedDiscordImage;
  String? _lastProcessedSongPath;

  // 🚀 Track last notified song to auto-sync notification (by key, not reference)

  // 🚀 COOLDOWN: Prevent race condition when toggling from app
  DateTime? _lastLocalShuffleTap;
  DateTime? _lastLocalLoopTap;
  static const int _syncCooldownMs = 1000; // 1 second cooldown

  PlayerNotifier(this._musicService, this.ref) : super(PlayerState()) {
    _autoQueueService = AutoQueueService();
    debugPrint("🚀 [Player] Notifier Constructed. Calling Init...");
    try {
      _init();
    } catch (e) {
      debugPrint("❌ [Player] CRITICAL INIT ERROR: $e");
    }
  }

  void _init() async {
    // 🚀 ANDROID FIX: Prevent re-initialization from overwriting current audio
    if (_globalInitialized) {
      DebugLogService().info("[Init] SKIPPED - already initialized globally");
      return;
    }
    _globalInitialized = true;
    DebugLogService().info("[Init] Running FIRST time initialization");

    // Restore Settings
    final prefs = await SharedPreferences.getInstance();
    final volume = prefs.getDouble('volume') ?? 0.5;
    final shuffle = prefs.getBool('shuffle') ?? false;
    final loopIndex = prefs.getInt('loopMode') ?? 0;
    // Restore Last Position
    final lastPosition = prefs.getDouble('last_position') ?? 0.0;

    // RESTORE LAST PLAYED SONG
    SongModel? lastSong;
    final lastSongJson = prefs.getString('last_played_song');
    if (lastSongJson != null) {
      try {
        DebugLogService().info("[Init] Parsing last song JSON...");
        lastSong = SongModel.fromJson(jsonDecode(lastSongJson));

        DebugLogService().info("[Init] Last song parsed: ${lastSong.title}");

        // 🚀 SET SONG IN STATE IMMEDIATELY (so UI shows song info while rebuffering)
        // Check if file needs rebuffering
        final needsRebuffering = lastSong.filePath == "cloud_stream" ||
            !await File(lastSong.filePath).exists();

        state = state.copyWith(
          volume: volume,
          unmutedVolume: volume > 0 ? volume : 0.5,
          isShuffle: shuffle,
          loopMode: ja.LoopMode.values[loopIndex],
          currentSong: lastSong, // Show song info immediately!
          isBuffering: needsRebuffering, // Show buffering animation if needed
        );
        DebugLogService().info(
            "[Init] Player State updated with last song (isBuffering=$needsRebuffering)");

        // 🚀 CRITICAL: Validate file existence.
        // If cache was cleared, this will trigger JIT caching (re-download)
        // so the player doesn't get stuck on a missing file.
        lastSong = await _ensureFileExists(lastSong);

        // Update state again with validated path and clear buffering
        state = state.copyWith(currentSong: lastSong, isBuffering: false);
        DebugLogService()
            .info("[Init] Song file validated: ${lastSong.filePath}");
      } catch (e) {
        print("Error restoring last song: $e");
      }
    } else {
      // No song to restore, just set settings
      state = state.copyWith(
        volume: volume,
        unmutedVolume: volume > 0 ? volume : 0.5,
        isShuffle: shuffle,
        loopMode: ja.LoopMode.values[loopIndex],
      );
    }

    // Apply settings to service
    await _musicService.setVolume(volume);
    // ALWAYS set service to off so we can handle looping manually (queue/playlist)
    _musicService.setLoopMode(ja.LoopMode.off);

    if (lastSong != null) {
      DebugLogService()
          .info("[Init] Triggering native load for: ${lastSong.title}");
      try {
        final start = DateTime.now();

        // 🚀 USE DIFFERENT FLOW BASED ON FILE AVAILABILITY
        if (lastSong.filePath != "cloud_stream" &&
            await File(lastSong.filePath).exists()) {
          // File exists locally - use simple load with initial position
          // 🚀 STARTUP OPTIMIZATION: Non-blocking Eager Load
          // We do NOT await this. This allows UI to render instantly while player buffers in background.
          _musicService.load(
            lastSong,
            initialPosition: lastPosition > 0
                ? Duration(seconds: lastPosition.round())
                : null,
            lazyLoad: false, // 🚀 Eager load so it's ready in 2-3s
          );
        } else {
          // File missing or cloud stream - use playSong (full JIT rebuffering)
          // This triggers the same flow as clicking a song from home page
          DebugLogService().info(
              "[Init] File missing/cloud - triggering playSong for rebuffering...");
          await playSong(lastSong, skipFinalize: true);
          // Pause immediately since we only want to prepare, not auto-play
          await _musicService.pause();
          state = state.copyWith(isPlaying: false);
        }

        final elapsed = DateTime.now().difference(start).inMilliseconds;
        DebugLogService().info("[Init] Native load completed in ${elapsed}ms");

        // Seek removed (Handled by load initialPosition)

        // 🚀 RESTORE THRESHOLD STATE (Fixes stats not logging after app restart)
        final savedThresholdPath = prefs.getString('threshold_song_path');
        if (savedThresholdPath == lastSong.filePath) {
          _isThresholdMet = prefs.getBool('threshold_met') ?? false;
          _cumulativeSecondsListened =
              prefs.getDouble('cumulative_seconds') ?? 0.0;
          _lastLogPosition = lastPosition; // Prevent double-counting on resume
          DebugLogService().info(
              "[Init] Restored threshold state: met=$_isThresholdMet, cumulative=${_cumulativeSecondsListened.toStringAsFixed(1)}s");
        } else {
          // Different song - reset threshold state
          _startNewSession(resetTime: false);
          DebugLogService()
              .info("[Init] Different song - threshold state reset");
        }
      } catch (e) {
        DebugLogService().info("[Init] Error loading saved song: $e");
      }
    } else {
      DebugLogService().info("[Init] No saved song to load");
    }

    // RESTORE QUEUE STATE
    await _restoreQueueState();

    // Initialize Discord
    Future.delayed(const Duration(seconds: 2), () {
      _discordService.init();

      // SYNC INITIAL SETTING
      final settings = ref.read(settingsProvider);
      _discordService.setEnabled(settings.enableDiscordRpc);

      // 🚀 Sync Discord presence after Discord connects (~6 seconds to be safe)
      // This ensures the current song is sent to Discord even on app restart
      Future.delayed(const Duration(seconds: 6), () {
        if (state.currentSong != null) {
          DebugLogService().info(
              "[Discord] Delayed sync for restored song: ${state.currentSong!.title}");
          _updateDiscord();
        }
      });

      // Initialize Taskbar Service
      _taskbarService.initialize(
        onPlay: () => _musicService.resume(),
        onPause: () => _musicService.pause(),
        onNext: () => playNext(),
        onPrevious: () => playPrevious(),
      );

      // Initialize Remote Control
      _remoteService.init().then((_) {
        // 🚀 Set initial state BEFORE listening to prevent stale server data from overwriting local settings
        final loopModeInt = state.loopMode == ja.LoopMode.off
            ? 0
            : (state.loopMode == ja.LoopMode.all ? 1 : 2);
        _remoteService.setInitialState(
          shuffle: state.isShuffle,
          loopMode: loopModeInt,
        );

        _remoteService.startListening(onCommand: _handleRemoteCommand);
        _broadcastRemoteState(); // Sync Initial State to server
      });

      // Connect Notification Controls (Mobile)
      if (Platform.isAndroid || Platform.isIOS) {
        _musicService.setNotificationCallbacks(
          onNext: () => playNext(),
          onPrev: () => playPrevious(),
        );
      }
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
      _extractPalette(state.currentSong!);
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

      // 💾 Periodic Save (Every 10 seconds)
      // This ensures we save position even if app is killed while playing
      if ((currentSecs - _lastSavedPosition).abs() > 10) {
        _saveSettings();
        _lastSavedPosition = currentSecs;
      }

      // 🚀 MULTI-CHECKPOINT PRELOAD: Trigger at 0%, 30%, 70%
      if (duration > 0) {
        final progressPercent = currentSecs / duration;

        // Check each threshold
        for (final threshold in [0, 30, 70]) {
          if (!_preloadCheckpoints.contains(threshold) &&
              progressPercent >= threshold / 100) {
            _preloadCheckpoints.add(threshold);
            print("🎯 $threshold% reached - triggering preload");
            _preloadNextSong();
            break; // Only trigger one per position update
          }
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
          DebugLogService().info(
              "🎯 PLAYER: 60% threshold met for ${state.currentSong?.title}! Stats will log on finalize.");
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

      // REMOVED _isSwitchingSong logic that caused stuck UI
      // Trust the player state directly

      if (state.isPlaying != isPlaying) {
        DebugLogService().info(
            "🎮 PLAYER: isPlaying changed: ${state.isPlaying} -> $isPlaying");
        state = state.copyWith(isPlaying: isPlaying);
        _updateDiscord();
        _updateTaskbar(); // UPDATE TASKBAR STATUS
        _broadcastRemoteState(); // Sync Play/Pause
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

  void removeUserQueueItem(int index) {
    if (index < 0 || index >= state.userQueue.length) return;
    final newQueue = List<SongModel>.from(state.userQueue);
    newQueue.removeAt(index);
    state = state.copyWith(userQueue: newQueue);
    _saveQueueState();
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
        spotifyId: song.spotifyId,
        spotifyArtistId: song.spotifyArtistId,
        deezerId: song.deezerId,
      );
      _smartService.cacheSong(meta, youtubeUrl: song.sourceUrl);
    }
  }

  void addToQueue(SongModel song) async {
    DebugLogService().info("➕ Added to Queue: ${song.title}");
    final newQueue = List<SongModel>.from(state.userQueue)..add(song);
    state = state.copyWith(userQueue: newQueue);
    _saveQueueState(); // SAVE STATE
    _broadcastRemoteState(); // 📢 UPDATE REMOTE CLIENT

    // 🚀 TRIGGER PRELOAD
    if (!await File(song.filePath).exists()) {
      DebugLogService().info("🚀 QUEUE ADD: Preloading ${song.title}...");
      final meta = SongMetadata(
        title: song.title,
        artist: song.artist,
        album: song.album,
        albumArtUrl: song.onlineArtUrl ?? "",
        durationSeconds: song.duration.toInt(),
        year: "",
        genre: "",
        isrc: song.isrc,
        spotifyId: song.spotifyId,
        spotifyArtistId: song.spotifyArtistId,
        deezerId: song.deezerId,
      );
      _smartService.cacheSong(meta, youtubeUrl: song.sourceUrl);
    }
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
    DebugLogService()
        .info("🎵 PLAYER: Calling addToHistory for: ${song.title}");
    ref.read(historyProvider.notifier).addToHistory(
          song: song,
          youtubeUrl: song.sourceUrl,
          artUrl: song.onlineArtUrl,
        );

    _extractPalette(song);

    // _isSwitchingSong = true;

    // JIT / REBUFFER CHECK (Fixes "Cloud Stream Error" and Missing Files)
    final readySong = await _ensureFileExists(song);

    state = state.copyWith(currentSong: readySong, isPlaying: true);

    await _musicService.play(readySong);
    _updateDiscord();
    _broadcastRemoteState(); // Sync Song Change
  }

  // --- COLOR EXTRACTION (Fixed for MP3s and Streaming) ---
  Future<void> _extractPalette(SongModel song) async {
    final filePath = song.filePath;

    // 1. TRY LOCAL FILE FIRST (faster for offline, works without network)
    if (filePath.isNotEmpty) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          // Read metadata from file to get image bytes
          final metadata = await MetadataGod.readMetadata(file: filePath);
          final bytes = metadata.picture?.data;

          if (bytes != null) {
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
              return; // Success with local art
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print("Local art color extraction failed: $e");
        // Fall through to try online art
      }
    }

    // 2. FALLBACK TO ONLINE ART (only if local failed and URL exists)
    if (song.onlineArtUrl != null && song.onlineArtUrl!.isNotEmpty) {
      try {
        final palette = await PaletteGenerator.fromImageProvider(
          NetworkImage(song.onlineArtUrl!),
          maximumColorCount: 20,
        ).timeout(const Duration(
            seconds: 5)); // 🚀 Timeout to prevent blocking offline

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
          return; // Success with online art
        }
      } catch (e) {
        if (kDebugMode) print("Online art color extraction failed: $e");
      }
    }

    // No color extracted
    state = state.copyWith(dominantColor: null);
  }

  // --- SETTINGS LOADING ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVolume = prefs.getDouble('volume') ?? 0.5;
    await _musicService.setVolume(savedVolume);
    _broadcastRemoteState(); // Sync Volume

    final savedShuffle = prefs.getBool('shuffle') ?? false;
    final savedLoopIndex = prefs.getInt('loopMode') ?? 0;
    final savedLoopMode = ja.LoopMode.values.length > savedLoopIndex
        ? ja.LoopMode.values[savedLoopIndex]
        : ja.LoopMode.off;

    // Always force service to OFF so we handle loops manually
    await _musicService.setLoopMode(ja.LoopMode.off);

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

    try {
      if (playlistJson != null) {
        playlist = (jsonDecode(playlistJson) as List)
            .map((e) {
              try {
                return SongModel.fromJson(e);
              } catch (e) {
                print("⚠️ Error restoring playlist item: $e");
                return null;
              }
            })
            .whereType<SongModel>()
            .toList();
      }

      if (originalPlaylistJson != null) {
        originalPlaylist = (jsonDecode(originalPlaylistJson) as List)
            .map((e) {
              try {
                return SongModel.fromJson(e);
              } catch (e) {
                print("⚠️ Error restoring original playlist item: $e");
                return null;
              }
            })
            .whereType<SongModel>()
            .toList();
      }

      if (userQueueJson != null) {
        final rawQueue = (jsonDecode(userQueueJson) as List)
            .map((e) {
              try {
                return SongModel.fromJson(e);
              } catch (e) {
                print("⚠️ Error restoring queue item: $e");
                return null;
              }
            })
            .whereType<SongModel>()
            .toList();

        // Deduplicate on Restore (Fixes double entries bug)
        final seen = <String>{};
        userQueue = [];
        print("📥 Restore Queue: Processing ${rawQueue.length} items...");

        for (var song in rawQueue) {
          // AGGRESSIVE NORMALIZATION
          // Remove everything except letters and numbers.
          // This handles extra spaces, punctuation ("G-Friend" vs "GFriend"), and invisible chars.
          final rawKey = "${song.artist}|${song.title}".toLowerCase();
          final key = rawKey.replaceAll(RegExp(r'[^a-z0-9]'), '');

          if (!seen.contains(key)) {
            seen.add(key);
            userQueue.add(song);
            print("   ✅ Kept: ${song.title} (Key: $key)");
          } else {
            print("   🚫 Duplicate removed: ${song.title} (Key: $key)");
          }
        }
        print("📥 Restore Queue: Final count ${userQueue.length}");
      }
    } catch (e, stack) {
      print("🚨 CRITICAL ERROR RESTORING QUEUE: $e");
      print(stack);
      // Fallback: Clear corrupted queue to allow app to start
      playlist = [];
      originalPlaylist = [];
      userQueue = [];
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
    if (_isSessionLogged) {
      DebugLogService()
          .info("📊 PLAYER: _finalizePlaySession skipped - already logged");
      return;
    }
    if (_isThresholdMet && state.currentSong != null) {
      DebugLogService().info(
          "📊 PLAYER: _finalizePlaySession - threshold met, logging play for ${state.currentSong!.title}");
      ref.read(statsProvider.notifier).logPlay(state.currentSong!);

      // TRACK PLAYS IN DB & CLOUD
      // StatsProvider only tracks transient session stats.
      // This call updates Isar DB + Firebase Metrics
      // We use fire-and-forget for performance
      DBService().updateSongPlayCountByPath(state.currentSong!.filePath);

      _isSessionLogged = true;
    } else {
      DebugLogService().info(
          "📊 PLAYER: _finalizePlaySession - threshold NOT met (threshold=$_isThresholdMet, song=${state.currentSong?.title})");
    }
  }

  void _startNewSession({bool resetTime = true}) {
    _isThresholdMet = false;
    _isSessionLogged = false;
    _lastLogPosition = 0.0;
    _cumulativeSecondsListened = 0.0;
    _preloadCheckpoints.clear(); // 🚀 Reset preload checkpoints for new song
    if (resetTime) {
      _lastSongChangeTime = DateTime.now();
    }
  }

  // JIT CACHE HELPER
  Future<SongModel> _ensureFileExists(SongModel song) async {
    // 🚀 ONLY skip if we have a VALID local file
    if (song.filePath != "cloud_stream" && await File(song.filePath).exists()) {
      return song;
    }

    // File is missing OR was a cloud stream - attempt to cache it
    print(
        "⚠️ File missing or cloud_stream: ${song.filePath}. Triggering JIT Cache...");
    final meta = SongMetadata(
      title: song.title,
      artist: song.artist,
      album: song.album,
      albumArtUrl: song.onlineArtUrl ?? "",
      durationSeconds: song.duration.toInt(),
      year: "",
      genre: "",
      isrc: song.isrc,
      spotifyId: song.spotifyId,
      spotifyArtistId: song.spotifyArtistId,
      deezerId: song.deezerId,
    );

    // Attempt Cache (this will search YouTube if sourceUrl is missing/stale)
    await _smartService.cacheSong(meta, youtubeUrl: song.sourceUrl);

    final cachedPath = await _smartService.getPredictedCachePath(meta);
    if (await File(cachedPath).exists()) {
      print("✅ JIT Success! New path: $cachedPath");
      return song.copyWith(filePath: cachedPath);
    }

    // 🚀 FINAL FALLBACK: If caching failed, switch to direct cloud streaming.
    print("❌ JIT Failed. Attempting to resolve URL for Cloud Stream...");

    // Try to find a valid URL to pass to NativeMusicService
    if (song.sourceUrl == null ||
        song.sourceUrl!.isEmpty ||
        song.sourceUrl!.startsWith('query:')) {
      final debugResult = await _smartService.searchYouTubeForMatch(meta);
      if (debugResult != null && debugResult.youtubeMatches.isNotEmpty) {
        var bestMatch = debugResult.youtubeMatches.firstWhere(
          (match) {
            final ytSeconds =
                _smartService.parseDurationToSeconds(match.duration) ?? 0;
            return (meta.durationSeconds - ytSeconds).abs() <= 1;
          },
          orElse: () => debugResult.youtubeMatches.first,
        );
        print("✅ Cloud Stream URL Resolved: ${bestMatch.url}");
        song = song.copyWith(sourceUrl: bestMatch.url);
      }
    }

    print("⚠️ Switching to Cloud Stream: ${song.title}");
    return song.copyWith(filePath: "cloud_stream");
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

    // 1. Check User Queue (Priority)
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
    // 3. Check Recommendation Queue (Endless Queue)
    if (nextSong == null && state.recommendationQueue.isNotEmpty) {
      nextSong = state.recommendationQueue.first;
      print("🔮 PRELOAD: Next song from recommendations: ${nextSong.title}");
    }

    if (nextSong != null) {
      // Check if file exists
      if (await File(nextSong.filePath).exists()) return;

      // 🚀 Guard: Skip if already preloading this song
      if (_preloadingTitle == nextSong.title) {
        print("⏭️ PRELOAD: Already preloading ${nextSong.title}, skipping...");
        return;
      }

      _preloadingTitle = nextSong.title;
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

      // Trigger Background Cache (awaited now!)
      await _smartService.cacheSong(meta, youtubeUrl: nextSong.sourceUrl);
      _preloadingTitle = null; // Clear guard after completion
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

    // CLEAR RECOMMENDATIONS only when user switches to a NEW playlist/album context
    // Don't clear when just playing a single song (streaming)
    if (newQueue != null) {
      print("🔄 Clearing recommendation queue for new playlist context...");
      state = state.copyWith(recommendationQueue: []);
      _autoQueueService.resetCache();
    }

    // Save to history
    DebugLogService()
        .info("🎵 PLAYER: playSong calling addToHistory for: ${song.title}");
    ref.read(historyProvider.notifier).addToHistory(
          song: song,
          youtubeUrl: song.sourceUrl,
          artUrl: song.onlineArtUrl,
        );

    // EXTRACT COLOR
    _extractPalette(song);

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
      // Single song play (no newQueue provided)
      // Check if song is in current playlist
      _playlistIndex = state.playlist.indexOf(song);
      if (_playlistIndex == -1) {
        _playlistIndex =
            state.playlist.indexWhere((s) => s.filePath == song.filePath);
      }

      // If song NOT in current playlist, this is a NEW context (standalone play)
      // Clear the playlist so playback uses recommendations instead
      if (_playlistIndex == -1) {
        print("🆕 Single song play detected. Clearing previous playlist.");
        state = state.copyWith(
          playlist: [],
          originalPlaylist: [],
          recommendationQueue: [], // Reset recommendations for fresh context
        );
        _autoQueueService.resetCache();
        _playlistIndex = 0;
      }
    }

    if (_playlistIndex == -1) _playlistIndex = 0;

    // JIT CACHING CHECK
    // 🐛 FIX: If the local file exists, ALWAYS play it directly.
    // Quality upgrade should only apply when streaming (file doesn't exist).
    // This ensures local library songs are never re-downloaded with FLAC quality setting.
    final fileExists = await File(song.filePath).exists();

    if (!fileExists) {
      print(
          "⚠️ Play Error: File not found at ${song.filePath}. Attempting JIT Cache...");
      state = state.copyWith(isBuffering: true); // 🚀 BUFFER START
      final meta = SongMetadata(
        title: song.title,
        artist: song.artist,
        album: song.album,
        albumArtUrl: song.onlineArtUrl ?? "",
        durationSeconds: song.duration.toInt(),
        year: "",
        genre: "",
        isrc: song.isrc,
        spotifyId: song.spotifyId,
        spotifyArtistId: song.spotifyArtistId,
        deezerId: song.deezerId,
      );
      print("🚀 JIT Cache Triggered for: ${song.title}");
      if (song.isrc != null) print("   ✅ Using ISRC: ${song.isrc}");

      // We use cacheSong but we need to wait for it!
      await _smartService.cacheSong(meta, youtubeUrl: song.sourceUrl);
      state = state.copyWith(isBuffering: false); // 🚀 BUFFER END

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
      // USB Audio bypass for seek
      if (_useUsbAudioBypass) {
        await UsbAudioService.seek(0);
        if (!state.isPlaying) await _resumeUsbAudio();
      } else {
        await _musicService.seek(0);
        if (!state.isPlaying) await _musicService.resume();
      }
    } else {
      state = state.copyWith(currentSong: song, isPlaying: true);

      // 🎧 USB AUDIO BYPASS: Try USB playback first for Android <14 bit-perfect
      if (_useUsbAudioBypass && Platform.isAndroid) {
        final usbSuccess = await _playViaUsbAudio(song);
        if (usbSuccess) {
          print("🎧 USB Audio Bypass: Playing via USB DAC");
        } else {
          print("⚠️ USB Audio Bypass: Falling back to normal playback");
          await _musicService.play(song);
        }
      } else {
        await _musicService.play(song);
      }
    }
    _updateDiscord();
    _saveSettings(); // SAVE STATE
    _saveQueueState(); // SAVE QUEUE

    _broadcastRemoteState(); // Sync Song Change

    // TRIGGER PRELOAD (Next + Previous)
    _preloadNextSong();
    _preloadPreviousSong();

    // ENDLESS QUEUE: Check immediately when playing
    _checkEndlessQueue();
  }

  Future<void> playNext({bool autoPlay = false}) async {
    if (!autoPlay) _finalizePlaySession();
    _startNewSession(resetTime: true);
    _isLooping = false;

    // 1. Check User Queue (Priority)
    if (state.userQueue.isNotEmpty) {
      var nextSong = state.userQueue.first;
      // Save to history
      DebugLogService().info(
          "🎵 PLAYER: playNext (UserQueue) calling addToHistory for: ${nextSong.title}");
      ref.read(historyProvider.notifier).addToHistory(
            song: nextSong,
            youtubeUrl: nextSong.sourceUrl,
            artUrl: nextSong.onlineArtUrl,
          );

      state = state.copyWith(userQueue: state.userQueue.sublist(1));
      _saveQueueState(); // SAVE QUEUE

      // _isSwitchingSong = true;
      state = state.copyWith(currentSong: nextSong, isPlaying: true);

      // EXTRACT COLOR
      _extractPalette(nextSong);

      // 🚀 CHECK FOR PRELOADED/CACHED FILE FIRST
      if (nextSong.filePath == "cloud_stream") {
        final meta = SongMetadata(
          title: nextSong.title,
          artist: nextSong.artist,
          album: nextSong.album,
          albumArtUrl: nextSong.onlineArtUrl ?? "",
          durationSeconds: nextSong.duration.toInt(),
          year: "",
          genre: "",
          spotifyId: nextSong.spotifyId,
          spotifyArtistId: nextSong.spotifyArtistId,
          deezerId: nextSong.deezerId,
        );
        final cachedPath = await _smartService.getPredictedCachePath(meta);
        print("🔍 Checking cache path: $cachedPath");
        if (await File(cachedPath).exists()) {
          print("✅ Found preloaded cache! Using: $cachedPath");
          nextSong = nextSong.copyWith(filePath: cachedPath);
          // Update currentSong state with resolved path
          state = state.copyWith(currentSong: nextSong);
        } else {
          print("❌ Cache file NOT found at: $cachedPath");
        }
      }

      // ☁️ GUARD: Bypass File Checks for Cloud Streams (if still cloud_stream)
      if (nextSong.filePath == "cloud_stream") {
        final success = await _musicService.play(nextSong);
        if (!success) {
          _consecutiveSkipCount++;
          print("❌ Play Next (Cloud) Failed. Skip #$_consecutiveSkipCount...");
          if (_consecutiveSkipCount >= _maxConsecutiveSkips) {
            print("🛑 Max skips reached. Stopping playback.");
            _consecutiveSkipCount = 0;
            state = state.copyWith(isPlaying: false);
            return;
          }
          playNext(autoPlay: true);
          return;
        }
        _consecutiveSkipCount = 0; // Reset on success
        _updateDiscord();
        _broadcastRemoteState();
        _preloadNextSong(); // ✅ Enable Preload for Queue
        return;
      }

      // JIT CACHING CHECK
      // 🐛 FIX: If local file exists, play directly. No quality upgrade for local files.
      final fileExists = await File(nextSong.filePath).exists();

      if (!fileExists) {
        state = state.copyWith(isBuffering: true); // 🚀 BUFFER START
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
          spotifyId: nextSong.spotifyId,
          spotifyArtistId: nextSong.spotifyArtistId,
          deezerId: nextSong.deezerId,
        );
        await _smartService.cacheSong(meta, youtubeUrl: nextSong.sourceUrl);
        state = state.copyWith(isBuffering: false); // 🚀 BUFFER END

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

      final success = await _musicService.play(nextSong);
      if (!success) {
        _consecutiveSkipCount++;
        print("❌ Play Next (File) Failed. Skip #$_consecutiveSkipCount...");
        if (_consecutiveSkipCount >= _maxConsecutiveSkips) {
          print("🛑 Max skips reached. Stopping playback.");
          _consecutiveSkipCount = 0;
          state = state.copyWith(isPlaying: false);
          return;
        }
        playNext(autoPlay: true);
        return;
      }
      _consecutiveSkipCount = 0; // Reset on success
      _updateDiscord();
      _broadcastRemoteState(); // Sync Next Song Change

      // TRIGGER PRELOAD
      _preloadNextSong();
      return;
    }

    // 2. Check Playlist
    if (state.playlist.isNotEmpty) {
      int nextIndex = _playlistIndex + 1;
      if (nextIndex < state.playlist.length) {
        // Still have songs in playlist
        _playlistIndex = nextIndex;
        var nextSong = state.playlist[nextIndex];
        // Save to history
        ref.read(historyProvider.notifier).addToHistory(
              song: nextSong,
              youtubeUrl: nextSong.sourceUrl,
              artUrl: nextSong.onlineArtUrl,
            );

        // _isSwitchingSong = true;
        state = state.copyWith(currentSong: nextSong, isPlaying: true);

        // EXTRACT COLOR
        _extractPalette(nextSong);

        // 🚀 CHECK FOR PRELOADED/CACHED FILE FIRST
        if (nextSong.filePath == "cloud_stream") {
          final meta = SongMetadata(
            title: nextSong.title,
            artist: nextSong.artist,
            album: nextSong.album,
            albumArtUrl: nextSong.onlineArtUrl ?? "",
            durationSeconds: nextSong.duration.toInt(),
            year: "",
            genre: "",
            spotifyId: nextSong.spotifyId,
            spotifyArtistId: nextSong.spotifyArtistId,
            deezerId: nextSong.deezerId,
          );
          final cachedPath = await _smartService.getPredictedCachePath(meta);
          if (await File(cachedPath).exists()) {
            print("✅ Found preloaded cache! Using: $cachedPath");
            nextSong = nextSong.copyWith(filePath: cachedPath);
            state = state.copyWith(currentSong: nextSong);
          }
        }

        // ☁️ GUARD: Bypass File Checks for Cloud Streams (if still cloud_stream)
        if (nextSong.filePath == "cloud_stream") {
          final success = await _musicService.play(nextSong);
          if (!success) {
            print("❌ Play Playlist (Cloud) Failed. Skipping...");
            playNext(autoPlay: true);
            return;
          }
          _updateDiscord();
          _preloadNextSong();
          _checkEndlessQueue();
          return;
        }

        // JIT CACHING CHECK
        // 🐛 FIX: If local file exists, play directly. No quality upgrade for local files.
        final fileExists = await File(nextSong.filePath).exists();

        if (!fileExists) {
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
            spotifyId: nextSong.spotifyId,
            spotifyArtistId: nextSong.spotifyArtistId,
            deezerId: nextSong.deezerId,
          );
          // JIT CACHING CHECK
          state = state.copyWith(isBuffering: true); // 🚀 BUFFER START
          DebugLogService()
              .info("🔄 PLAYER: JIT Buffering Started for ${nextSong.title}");
          await _smartService.cacheSong(meta);
          state = state.copyWith(isBuffering: false); // 🚀 BUFFER END
          DebugLogService().info("✅ PLAYER: JIT Buffering Finished");

          // CHECK IF CACHED FILE EXISTS
          final cachedPath = await _smartService.getPredictedCachePath(meta);
          if (await File(cachedPath).exists()) {
            print("✅ JIT Cache Successful! Switching path to: $cachedPath");
            nextSong = nextSong.copyWith(filePath: cachedPath);
          }
        }

        final success = await _musicService.play(nextSong);
        if (!success) {
          print("❌ Play Playlist (File) Failed. Skipping...");
          playNext(autoPlay: true);
          return;
        }
        _updateDiscord();

        // TRIGGER PRELOAD
        _preloadNextSong();

        // ENDLESS QUEUE CHECK
        _checkEndlessQueue();
        return;
      } else if (state.loopMode == ja.LoopMode.all) {
        // Loop back to beginning
        _playlistIndex = 0;
        var nextSong = state.playlist[0];
        ref.read(historyProvider.notifier).addToHistory(
              song: nextSong,
              youtubeUrl: nextSong.sourceUrl,
              artUrl: nextSong.onlineArtUrl,
            );

        // _isSwitchingSong = true;
        state = state.copyWith(currentSong: nextSong, isPlaying: true);
        _extractPalette(nextSong);

        if (!await File(nextSong.filePath).exists()) {
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
          final cachedPath = await _smartService.getPredictedCachePath(meta);
          if (await File(cachedPath).exists()) {
            nextSong = nextSong.copyWith(filePath: cachedPath);
          }
        }

        final success = await _musicService.play(nextSong);
        if (!success) {
          print("❌ Play Loop (File) Failed. Skipping...");
          playNext(autoPlay: true);
          return;
        }
        _updateDiscord();
        _preloadNextSong();
        _checkEndlessQueue();
        return;
      }
      // Playlist exhausted, fall through to check recommendationQueue
    }

    // 3. Check Recommendation Queue (Endless Queue)
    if (state.recommendationQueue.isNotEmpty) {
      print("🎵 Playing from recommendation queue...");
      var nextSong = state.recommendationQueue.first;

      // Save to history
      ref.read(historyProvider.notifier).addToHistory(
            song: nextSong,
            youtubeUrl: nextSong.sourceUrl,
            artUrl: nextSong.onlineArtUrl,
          );

      // Remove from recommendation queue
      state = state.copyWith(
        recommendationQueue: state.recommendationQueue.sublist(1),
      );
      _saveQueueState();

      // _isSwitchingSong = true;
      state = state.copyWith(currentSong: nextSong, isPlaying: true);

      // EXTRACT COLOR
      _extractPalette(nextSong);

      // JIT CACHING CHECK
      if (!await File(nextSong.filePath).exists()) {
        print(
            "⚠️ Recommendation song: File not found. Attempting JIT Cache...");
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

        final cachedPath = await _smartService.getPredictedCachePath(meta);
        if (await File(cachedPath).exists()) {
          print("✅ JIT Cache Successful! Switching path to: $cachedPath");
          nextSong = nextSong.copyWith(filePath: cachedPath);
        }
      }

      // VERIFY FILE EXISTS
      if (!await File(nextSong.filePath).exists()) {
        print("❌ Recommendation song Error: File missing. Skipping.");
        playNext(autoPlay: true);
        return;
      }

      _musicService.play(nextSong);
      _updateDiscord();
      _broadcastRemoteState();

      // TRIGGER PRELOAD
      _preloadNextSong();

      // CHECK FOR MORE RECOMMENDATIONS
      _checkEndlessQueue();
      return;
    }

    // 4. No more songs - pause
    state = state.copyWith(isPlaying: false);
    await _musicService.pause();
    return;
  }

  // --- ENDLESS QUEUE ---

  /// Toggle endless queue on/off
  void toggleEndlessQueue() {
    state = state.copyWith(endlessQueueEnabled: !state.endlessQueueEnabled);
    _saveSettings();
    print(state.endlessQueueEnabled
        ? "🔄 Endless Queue: ENABLED"
        : "⏹️ Endless Queue: DISABLED");
  }

  /// Play a song from the recommendation queue by index
  Future<void> playRecommendationSong(int index) async {
    if (index < 0 || index >= state.recommendationQueue.length) return;

    final song = state.recommendationQueue[index];

    // Remove this song and all before it from recommendation queue
    final newRecQueue = state.recommendationQueue.sublist(index + 1);
    state = state.copyWith(recommendationQueue: newRecQueue);
    _saveQueueState();

    // Play the song (will clear and fetch new recommendations)
    await playSong(song, skipFinalize: true);
  }

  /// Check if we need to fetch more songs for endless queue
  Future<void> _checkEndlessQueue() async {
    print("🔍 Endless Queue: Checking...");
    print("   - Enabled: ${state.endlessQueueEnabled}");
    print("   - Current Song: ${state.currentSong?.title}");

    if (!state.endlessQueueEnabled) {
      print("⏹️ Endless Queue: DISABLED - skipping");
      return;
    }
    if (state.currentSong == null) {
      print("⚠️ Endless Queue: No current song - skipping");
      return;
    }

    // Calculate remaining songs in queue
    // Priority: userQueue -> playlist -> recommendationQueue
    final remainingInPlaylist = state.playlist.length - _playlistIndex - 1;
    final remainingInUserQueue = state.userQueue.length;
    final remainingInRecommendations = state.recommendationQueue.length;

    print("   - Remaining in userQueue (Play Next): $remainingInUserQueue");
    print("   - Remaining in playlist (Library): $remainingInPlaylist");
    print("   - Remaining in recommendationQueue: $remainingInRecommendations");

    // Always fetch if recommendation queue is low (regardless of library size)
    // This ensures recommendations show in queue even when playing from album
    if (remainingInRecommendations >= 20) {
      print(
          "✅ Endless Queue: Enough recommendations ($remainingInRecommendations >= 20), skipping");
      return;
    }

    print(
        "🔄 Endless Queue: Only $remainingInRecommendations recommendations, fetching more...");

    try {
      final recommendations = await _autoQueueService.getRecommendedSongs(
        state.currentSong!,
      );

      print("📥 Endless Queue: Got ${recommendations.length} recommendations");

      if (recommendations.isEmpty) {
        print("⚠️ Endless Queue: No recommendations available");
        return;
      }

      // Add recommendations to RECOMMENDATION queue (separate from user's Play Next)
      final newRecQueue = List<SongModel>.from(state.recommendationQueue);
      newRecQueue.addAll(recommendations);
      state = state.copyWith(recommendationQueue: newRecQueue);
      _saveQueueState();

      print(
          "✅ Endless Queue: Added ${recommendations.length} songs to recommendation queue");
      print(
          "   - New recommendation queue size: ${state.recommendationQueue.length}");

      // Pre-cache only the next song
      if (recommendations.isNotEmpty) {
        _preloadNextSong();
      }
    } catch (e, stack) {
      print("❌ Endless Queue Error: $e");
      print("   Stack: $stack");
    }
  }

  Future<void> playPrevious() async {
    final pos = await _musicService.player.position;
    if (pos.inSeconds > 3) {
      await _musicService.seek(0);
      // 🚀 Update Discord to reset timelapse when restarting song
      _updateDiscord();
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
        // 🚀 Update Discord to reset timelapse when restarting song
        _updateDiscord();
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

    // _isSwitchingSong = true;
    state = state.copyWith(currentSong: prevSong, isPlaying: true);

    // JIT CACHE CHECK FOR PREVIOUS
    final readySong = await _ensureFileExists(prevSong);
    state = state.copyWith(currentSong: readySong);

    // EXTRACT COLOR (Safe now)
    _extractPalette(readySong);

    _musicService.play(readySong);
    _updateDiscord();
    _broadcastRemoteState(); // Sync Prev Song Change

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
    _lastLocalShuffleTap = DateTime.now(); // 🚀 COOLDOWN: Mark local tap
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
    DebugLogService().info("🚀 BROADCASTING SHUFFLE: ${state.isShuffle}");
    _broadcastRemoteState(); // 🚀 SYNC: Broadcast Shuffle Change
  }

  void cycleLoopMode() {
    _lastLocalLoopTap = DateTime.now(); // 🚀 COOLDOWN: Mark local tap
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

    // Always keep service loop mode OFF
    _musicService.setLoopMode(ja.LoopMode.off);
    state = state.copyWith(loopMode: nextMode);
    _saveSettings();
    DebugLogService().info("🚀 BROADCASTING LOOP: ${state.loopMode}");
    _broadcastRemoteState(); // 🚀 SYNC: Broadcast Loop Change
  }

  Future<void> _updateDiscord() async {
    if (state.currentSong != null) {
      final song = state.currentSong!;

      if (song.filePath != _lastProcessedSongPath) {
        _lastProcessedSongPath = song.filePath;
        _cachedDiscordImage = null;

        // 🚀 Use existing onlineArtUrl if available (faster than Spotify fetch)
        final initialArt = song.onlineArtUrl;

        _discordService.updatePresence(
          song,
          state.isPlaying,
          Duration(seconds: state.currentPosition.toInt()),
          Duration(seconds: state.totalDuration.toInt()),
          imageUrl: initialArt, // Use existing art immediately if available
        );

        // Cache the initial art if available
        if (initialArt != null && initialArt.isNotEmpty) {
          _cachedDiscordImage = initialArt;
        }

        // Fetch higher quality art from Spotify (async update)
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
    // Save Current Position
    await prefs.setDouble('last_position', state.currentPosition);

    // SAVE LAST PLAYED SONG
    if (state.currentSong != null) {
      final songJson = jsonEncode(state.currentSong!.toJson());
      await prefs.setString('last_played_song', songJson);

      // 🚀 SAVE THRESHOLD STATE (Fixes stats not logging after app restart)
      // Save the threshold state keyed to the current song so it can be restored
      await prefs.setString('threshold_song_path', state.currentSong!.filePath);
      await prefs.setBool('threshold_met', _isThresholdMet);
      await prefs.setDouble('cumulative_seconds', _cumulativeSecondsListened);
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
  Future<void> _handleRemoteCommand(String action, dynamic value) async {
    // print(" [Remote] Received Command: $action Payload: $value"); // DEBUG LOG
    DebugLogService().info("[Remote] Cmd: $action, Val: $value");
    DebugLogService().info(
        "[Remote] State: Playing=${state.isPlaying}, Song=${state.currentSong?.title}"); // DEBUG LOG

    switch (action) {
      case 'play':
        // Direct resume without force-reload logic
        if (!state.isPlaying) {
          DebugLogService().info("[Remote] Executing RESUME");
          await _musicService.resume();
        }
        break;
      case 'pause':
        if (state.isPlaying) {
          DebugLogService().info("[Remote] Executing PAUSE");
          await _musicService.pause();
        }
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
      case 'shuffle':
        toggleShuffle();
        break;
      case 'repeat':
        cycleLoopMode();
        break;
      // 🚀 SAFE STATE SYNC (Shuffle/Loop Only)
      case 'sync_state':
        if (value is Map<String, dynamic>) {
          final now = DateTime.now();

          // Shuffle Sync (with Cooldown)
          if (value.containsKey('is_shuffle')) {
            // Skip if local toggle happened within cooldown period
            final shuffleCooldown = _lastLocalShuffleTap != null &&
                now.difference(_lastLocalShuffleTap!).inMilliseconds <
                    _syncCooldownMs;
            if (shuffleCooldown) {
              DebugLogService()
                  .info("🔄 [Sync] Shuffle SKIPPED (cooldown active)");
            } else {
              final target = value['is_shuffle'] as bool;
              if (state.isShuffle != target) {
                DebugLogService()
                    .info("🔄 Remote Sync: Set Shuffle to $target");
                toggleShuffle();
              }
            }
          }

          // Loop Sync (with Cooldown)
          if (value.containsKey('loop_mode')) {
            // Skip if local toggle happened within cooldown period
            final loopCooldown = _lastLocalLoopTap != null &&
                now.difference(_lastLocalLoopTap!).inMilliseconds <
                    _syncCooldownMs;
            if (loopCooldown) {
              DebugLogService()
                  .info("🔄 [Sync] Loop SKIPPED (cooldown active)");
            } else {
              final targetVal = value['loop_mode'] as int;
              ja.LoopMode targetMode;
              if (targetVal == 1)
                targetMode = ja.LoopMode.all;
              else if (targetVal == 2)
                targetMode = ja.LoopMode.one;
              else
                targetMode = ja.LoopMode.off;

              if (state.loopMode != targetMode) {
                DebugLogService()
                    .info("🔄 Remote Sync: Set Loop to $targetMode");
                _musicService.setLoopMode(targetMode);
                state = state.copyWith(loopMode: targetMode);
                _saveSettings();
                _broadcastRemoteState();
              }
            }
          }
        }
        break;
      case 'search':
        // Defensive check: If payload is missing, it might come as double (volume)
        if (value is! String) {
          break;
        }
        final query = value;
        if (query.isNotEmpty) {
          try {
            // New Grouped Search
            final results = await SpotifyService.searchAll(query);

            // Serialize each list within the map
            final serialized = {
              'songs':
                  (results['songs'] as List).map((e) => e.toJson()).toList(),
              'albums':
                  (results['albums'] as List).map((e) => e.toJson()).toList(),
              'artists':
                  (results['artists'] as List).map((e) => e.toJson()).toList(),
            };

            print(
                "DEBUG: SearchAll Results: ${serialized['songs']?.length} songs, ${serialized['albums']?.length} albums");
            _remoteService.updateSearchResults(serialized);
          } catch (e) {
            print("❌ SearchAll Error: $e");
          }
        }
        break;
      case 'add_queue':
        try {
          final songJson = value;
          if (songJson is Map<String, dynamic>) {
            final song = SongModel.fromJson(songJson);
            addToQueue(song);
          } else if (songJson is String) {
            final song = SongModel.fromJson(jsonDecode(songJson));
            addToQueue(song);
          }
        } catch (e) {
          print("☁️ Party Mode Error: Invalid song data - $e");
        }
        break;
      case 'get_album_details':
        print("📥 Received 'get_album_details' command with value: $value");
        Map<String, dynamic>? payload;

        if (value is Map<String, dynamic>) {
          payload = value;
        } else if (value is String) {
          try {
            payload = jsonDecode(value);
          } catch (e) {
            print("❌ Error decoding payload: $e");
          }
        }

        if (payload != null) {
          final albumId = payload['id'];
          if (albumId != null) {
            try {
              print("💿 Fetching tracks for Album ID: $albumId");
              final tracks = await SpotifyService.getAlbumTracks(albumId);
              print("✅ Fetched ${tracks.length} tracks from Spotify.");

              // Convert to JSON
              final tracksJson = tracks
                  .map((t) => {
                        'title': t.title,
                        'artist': t.artist,
                        'album': t.album,
                        'albumArtUrl': t.albumArtUrl,
                        'duration': t.durationSeconds,
                        'fileExtension': 'mp3',
                        'filePath': 'cloud_stream',
                        'sourceUrl': 'query: ${t.artist} - ${t.title}',
                        'onlineArtUrl': t.albumArtUrl,
                      })
                  .toList();

              print("📤 Broadcasting active_album_details...");
              _remoteService.broadcastState(albumDetails: {
                'id': albumId,
                'tracks': tracksJson,
              });
            } catch (e) {
              print("❌ Album Details Error: $e");
            }
          } else {
            print("⚠️ Album ID is null in payload.");
          }
        } else {
          print("⚠️ Payload could not be parsed.");
        }
        break;
    }
  }

  // 🚀 CACHE FOR ALBUM ART URLs (from Spotify lookup)
  // Key: "artist|title", Value: Spotify image URL or empty string if not found
  final Map<String, String> _artUrlCache = {};

  /// Get cached Spotify art URL if available
  String? _getCachedArtUrl(String artist, String title) {
    final key = "$artist|$title".toLowerCase();
    if (_artUrlCache.containsKey(key)) {
      final url = _artUrlCache[key];
      return url != null && url.isNotEmpty ? url : null;
    }
    return null; // Not cached yet
  }

  /// Fetch album art from Spotify API and cache it
  Future<void> _fetchAndCacheArtFromSpotify(String artist, String title) async {
    final key = "$artist|$title".toLowerCase();

    // Already processing or cached
    if (_artUrlCache.containsKey(key)) return;

    // Mark as processing (empty string means "checked but no art")
    _artUrlCache[key] = '';

    try {
      DebugLogService().info("🎨 Fetching Spotify art for: $title - $artist");
      final artUrl = await SpotifyService.getTrackImage(title, artist);

      if (artUrl != null && artUrl.isNotEmpty) {
        _artUrlCache[key] = artUrl;
        DebugLogService().info("🎨 Got Spotify art: $artUrl");
        // Trigger a re-broadcast to send the now-cached art
        _broadcastRemoteState();
      } else {
        DebugLogService().info("🎨 No Spotify art found for: $title - $artist");
      }
    } catch (e) {
      DebugLogService().info("⚠️ Failed to fetch Spotify art: $e");
    }
  }

  void _broadcastRemoteState() {
    // Construct "Next Up" Queue (Limit 20)
    List<Map<String, dynamic>> queueData = [];
    int limit = 20;

    // 1. Priority: User Queue (Play Next)
    for (var song in state.userQueue) {
      if (queueData.length >= limit) break;
      queueData.add({
        'title': song.title,
        'artist': song.artist,
        'albumArt': song.onlineArtUrl, // Simplified key for web
        'isCustom': true, // Flag to show "Queued" badge
      });
    }

    // 2. Remaining Playlist
    final currentIndex = state.currentSong != null
        ? state.playlist.indexOf(state.currentSong!)
        : -1;

    if (queueData.length < limit &&
        currentIndex >= 0 &&
        currentIndex < state.playlist.length) {
      // Start from next song
      for (int i = currentIndex + 1; i < state.playlist.length; i++) {
        if (queueData.length >= limit) break;
        final song = state.playlist[i];
        queueData.add({
          'title': song.title,
          'artist': song.artist,
          'albumArt': song.onlineArtUrl,
          'isCustom': false,
        });
      }
    }

    DebugLogService().info(
        "📢 Broadcasting Queue: ${queueData.length} items (User: ${state.userQueue.length}, Playlist: ${state.playlist.length})");

    DebugLogService().info(
        "📢 Broadcasting State: Shuffle=${state.isShuffle}, Loop=${state.loopMode.name} (Index: ${state.loopMode.index})");

    // 🚀 SYNC FIX: Ensure we send actual player status, not potentially stale state
    final actualPlaying = _musicService.player.playing;
    if (state.isPlaying != actualPlaying) {
      DebugLogService().info(
          "⚠️ SCARY DESYNC: State=${state.isPlaying} but Player=$actualPlaying");
    }

    // 🚀 LOCAL SONG METADATA SUPPORT
    // For local songs without online art URL, fetch from Spotify API
    String? artUrlToSend = state.currentSong?.onlineArtUrl;

    if ((artUrlToSend == null || artUrlToSend.isEmpty) &&
        state.currentSong != null &&
        state.currentSong!.filePath != "cloud_stream") {
      final artist = state.currentSong!.artist;
      final title = state.currentSong!.title;

      // Only try Spotify lookup if we have valid metadata
      if (artist.isNotEmpty &&
          artist != "Unknown Artist" &&
          title.isNotEmpty &&
          title != "Unknown Title") {
        // Check cache first
        final cachedArt = _getCachedArtUrl(artist, title);
        if (cachedArt != null) {
          artUrlToSend = cachedArt;
        } else {
          // Trigger async Spotify lookup for next broadcast
          _fetchAndCacheArtFromSpotify(artist, title);
        }
      }
    }

    // Fallback display values for local songs with missing metadata
    String? displayTitle = state.currentSong?.title;
    String? displayArtist = state.currentSong?.artist;
    if (displayTitle == null ||
        displayTitle.isEmpty ||
        displayTitle == "Unknown Title") {
      // Extract filename as fallback
      if (state.currentSong?.filePath != null &&
          state.currentSong!.filePath != "cloud_stream") {
        displayTitle =
            state.currentSong!.filePath.split('/').last.split('\\').last;
        final dotIndex = displayTitle.lastIndexOf('.');
        if (dotIndex > 0) displayTitle = displayTitle.substring(0, dotIndex);
      }
    }
    if (displayArtist == null ||
        displayArtist.isEmpty ||
        displayArtist == "Unknown Artist") {
      displayArtist = "Unknown Artist";
    }

    _remoteService.broadcastState(
      title: displayTitle,
      artist: displayArtist,
      isPlaying: actualPlaying, // 🚀 TRUTH FROM METAL
      volume: state.volume,
      isShuffle: state.isShuffle,
      loopMode: state.loopMode == ja.LoopMode.off
          ? 0
          : (state.loopMode == ja.LoopMode.all
              ? 1
              : 2), // 0: off, 1: all, 2: one (Explicit mapping for Web App)
      positionSeconds: state.currentPosition.toInt(),
      durationSeconds: state.totalDuration.toInt(),
      artUrl: artUrlToSend,
      filePath: state.currentSong?.filePath,
      queue: queueData,
    );
  }

  // ============== USB Audio Bypass (Android <14 Bit-Perfect) ==============

  /// Check if USB Audio bypass is currently active
  bool get isUsbAudioBypassActive =>
      _useUsbAudioBypass && _connectedUsbDac != null;

  /// Enable USB Audio bypass with a connected DAC
  Future<bool> enableUsbAudioBypass(UsbDacDevice dac) async {
    if (!Platform.isAndroid) return false;

    final success = await UsbAudioService.openDac(dac);
    if (success) {
      _connectedUsbDac = dac;
      _useUsbAudioBypass = true;
      print("🔊 USB Audio Bypass ENABLED: ${dac.deviceName}");
      return true;
    }
    return false;
  }

  /// Disable USB Audio bypass and return to normal playback
  Future<void> disableUsbAudioBypass() async {
    if (_useUsbAudioBypass) {
      await UsbAudioService.closeDac();
      _connectedUsbDac = null;
      _useUsbAudioBypass = false;
      print("🔇 USB Audio Bypass DISABLED");
    }
  }

  /// Play a song through USB Audio (for Android <14 bit-perfect)
  Future<bool> _playViaUsbAudio(SongModel song) async {
    if (!_useUsbAudioBypass || _connectedUsbDac == null) {
      return false;
    }

    try {
      // For USB Audio, we need a local file path
      if (song.filePath == "cloud_stream" ||
          !await File(song.filePath).exists()) {
        print("⚠️ USB Audio: Cannot play cloud streams or missing files");
        return false;
      }

      // Prepare the file for USB playback
      final prepared = await UsbAudioService.prepareFile(song.filePath);
      if (!prepared) {
        print("❌ USB Audio: Failed to prepare file");
        return false;
      }

      // Start USB playback
      final success = await UsbAudioService.play();
      if (success) {
        print("✅ USB Audio: Playing ${song.title}");
        state = state.copyWith(isPlaying: true);
        return true;
      }
      return false;
    } catch (e) {
      print("❌ USB Audio Error: $e");
      return false;
    }
  }

  /// Pause USB Audio playback
  Future<void> _pauseUsbAudio() async {
    if (_useUsbAudioBypass) {
      await UsbAudioService.pause();
    }
  }

  /// Resume USB Audio playback
  Future<void> _resumeUsbAudio() async {
    if (_useUsbAudioBypass) {
      await UsbAudioService.resume();
    }
  }

  /// Stop USB Audio playback
  Future<void> _stopUsbAudio() async {
    if (_useUsbAudioBypass) {
      await UsbAudioService.stop();
    }
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final musicService = NativeMusicService();
  return PlayerNotifier(musicService, ref);
});
