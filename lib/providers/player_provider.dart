import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/usb_audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:palette_generator/palette_generator.dart';

import 'package:audio_session/audio_session.dart';
import '../models/song_model.dart';
import '../services/native_music_service.dart';
import '../services/discord_service.dart';
import '../services/spotify_service.dart';
import '../services/deezer_service.dart';
import '../services/youtube_downloader_service.dart';
import '../services/smart_download_service.dart';
import '../services/windows_taskbar_service.dart';
import '../services/flac_downloader_service.dart';
import '../services/debug_log_service.dart';
import '../services/metadata_service.dart'; // Safe metadata reader (ffmpeg fallback for AIFF/WAV)
import '../env/env.dart';
import '../models/song_metadata.dart';
import 'stats_provider.dart';
import 'profile_provider.dart';
import 'history_provider.dart';
import 'settings_provider.dart';
import 'data_usage_provider.dart';
import '../services/apple_music_backend_service.dart';

import '../services/db_service.dart';
import '../services/remote_control_service.dart';
import '../services/pocketbase_service.dart';
import '../services/auto_queue_service.dart';
import '../services/metrics_service.dart';
import '../services/cue_parser_service.dart';

// STATE CLASS
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
  final bool isLoadingRecommendations;

  // Buffering indicator
  final bool isBuffering;

  // Smart Sleep Timer
  final bool isSleepPending;

  // Cross-Device Sync
  final String? activeDeviceId;
  final String? activeDeviceName;

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
    this.endlessQueueEnabled = true,
    this.isLoadingRecommendations = false,
    this.isBuffering = false,
    this.isSleepPending = false,
    this.activeDeviceId,
    this.activeDeviceName,
    this.audioSessionId,
  });

  final int? audioSessionId;

  SongModel? get nextSong {
    if (userQueue.isNotEmpty) return userQueue.first;
    if (playlist.isNotEmpty && currentSong != null) {
      int idx = playlist.indexWhere((s) => s.filePath == currentSong!.filePath);
      if (idx != -1) {
        int nextIdx = idx + 1;
        if (nextIdx < playlist.length) return playlist[nextIdx];
        if (loopMode == ja.LoopMode.all) return playlist.first;
      }
    }
    if (recommendationQueue.isNotEmpty) return recommendationQueue.first;
    return null;
  }

  SongModel? get previousSong {
    if (playlist.isEmpty || currentSong == null) return null;
    int idx = playlist.indexWhere((s) => s.filePath == currentSong!.filePath);
    if (idx != -1) {
      int prevIdx = idx - 1;
      if (prevIdx >= 0) return playlist[prevIdx];
      if (loopMode == ja.LoopMode.all) return playlist.last;
    }
    return null;
  }

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
    bool? isLoadingRecommendations,
    bool? isBuffering,
    bool? isSleepPending,
    String? activeDeviceId,
    String? activeDeviceName,
    int? audioSessionId,
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
      isLoadingRecommendations:
          isLoadingRecommendations ?? this.isLoadingRecommendations,
      isBuffering: isBuffering ?? this.isBuffering,
      isSleepPending: isSleepPending ?? this.isSleepPending,
      activeDeviceId: activeDeviceId ?? this.activeDeviceId,
      activeDeviceName: activeDeviceName ?? this.activeDeviceName,
      audioSessionId: audioSessionId ?? this.audioSessionId,
    );
  }
}

// NOTIFIER CLASS
class PlayerNotifier extends StateNotifier<PlayerState> {
  final NativeMusicService _musicService;
  final DiscordService _discordService = DiscordService();
  // Uses the Singleton instance automatically
  final YoutubeDownloaderService _downloaderService =
      YoutubeDownloaderService();
  final SmartDownloadService _smartService = SmartDownloadService();
  final WindowsTaskbarService _taskbarService = WindowsTaskbarService();
  final RemoteControlService _remoteService = RemoteControlService();
  late final AutoQueueService _autoQueueService;
  final Ref ref;

  // USB Audio bypass flag (for Android <14 bit-perfect playback)
  bool _useUsbAudioBypass = false;
  UsbDacDevice? _connectedUsbDac;

  Stream<Duration> get positionStream => _musicService.positionStream;

  // CRITICAL FOR EQUALIZER: Expose Session ID
  int? get audioSessionId => _musicService.player.androidAudioSessionId;

  int _playlistIndex = 0;
  int get currentPlaylistIndex => _playlistIndex;
  // Play history stack — tracks every song played for universal "previous" button
  final List<SongModel> _playHistory = [];
  static const int _maxPlayHistorySize = 50;
  bool _isLooping = false;
  bool _isCppEnginePrepared = false;
  bool _isHandlingCompletion = false;
  bool _isRecoveringFromCrash = false;
  bool _volumeCallInProgress = false;
  double? _pendingVolume;
  final Set<int> _preloadCheckpoints = {}; // Track preload at 10%, 35%, 70%
  String? _preloadingTitle;
  Completer<void>? _preloadLock;
  int _consecutiveSkipCount = 0;
  static const int _maxConsecutiveSkips = 3;
  int _currentSongRetryCount = 0;
  static const int _maxSongRetries = 2;
  bool _isExtractingPalette = false;
  bool _isTransitioning = false;

  static bool _globalInitialized = false;

  // Stats config
  bool _isThresholdMet = false;
  bool _isSessionLogged = false;
  double _lastLogPosition = 0.0;
  double _lastSavedPosition = 0.0;
  double _cumulativeSecondsListened = 0.0;
  double _cacheClearListeningTimer = 0.0;
  double _minutesBumpAccumulator = 0.0; // Tracks seconds to bump UI minutes
  static const double _playCountThreshold = 0.60;
  DateTime _lastSongChangeTime = DateTime.now();

  // Discord Vars
  String? _cachedDiscordImage;
  String? _lastProcessedSongPath;

  // Track last notified song to auto-sync notification (by key, not reference)

  DateTime? _lastLocalShuffleTap;
  DateTime? _lastLocalLoopTap;
  static const int _syncCooldownMs = 1000; // 1 second cooldown

  int _playRequestToken = 0; // Guard against outdated async plays
  DateTime _lastPlayRequestTime = DateTime.fromMillisecondsSinceEpoch(
      0); // Guard against async spurious completed events
  int _preloadRequestToken =
      0; // Guard against outdated async preloads (e.g. queue changes)
  int _lastDiscordSyncSeconds = -1; // Discord 30s Sync Tracker
  int _lastNotificationSyncMs = 0; // Throttle for Android MediaSession sync
  DateTime?
      _lastManualSeekTime; // Sync Lock: Track manual interactions to prevent rubber-banding
  double _lastEngineSecs = -1.0; // Track native engine position for watchdog

  PlayerNotifier(this._musicService, this.ref) : super(PlayerState()) {
    _autoQueueService = AutoQueueService();
    try {
      _init();
      // Wire up stream expiration callback for auto re-resolve
      _musicService.onStreamExpired = _handleExpiredStream;
    } catch (e) {
      DebugLogService().error("[Player] CRITICAL INIT ERROR: $e");
    }
  }

  /// Callback invoked by [NativeMusicService] when a stream URL is expired
  /// or the server is unreachable. Re-resolves the URL via [_getJitStreamUrl]
  /// and reloads the player with the fresh URL.
  Future<void> _handleExpiredStream(SongModel expiredSong) async {
    try {
      DebugLogService().info(
          "🔄 Stream expired for '${expiredSong.title}', re-resolving...");
      state = state.copyWith(isBuffering: true);

      final freshUrl = await _getJitStreamUrl(expiredSong);
      if (freshUrl != null && freshUrl.isNotEmpty) {
        final refreshedSong = expiredSong.copyWith(filePath: freshUrl);
        state = state.copyWith(currentSong: refreshedSong);
        DebugLogService().info("✅ Stream re-resolved, reloading player");
        final initialPos = state.currentPosition > 0
            ? Duration(seconds: state.currentPosition.round())
            : null;
        await _musicService.load(refreshedSong, initialPosition: initialPos);
        state = state.copyWith(isBuffering: false);
      } else {
        DebugLogService()
            .error("❌ Stream re-resolve failed for '${expiredSong.title}'");
        state = state.copyWith(isBuffering: false, isPlaying: false);
      }
    } catch (e) {
      DebugLogService().error("❌ _handleExpiredStream error: $e");
      state = state.copyWith(isBuffering: false, isPlaying: false);
    }
  }

  // Device info for cross-device coordination
  String? _localDeviceId;
  String? _localDeviceName;

  // REMOTE SESSION FLAG: Controls cross-device sync behavior.
  // When false (default & after "This Device"), the device plays independently.
  // When true (after connecting to a remote device), cross-device sync is active.
  bool _isRemoteSessionActive = false;
  bool get isRemoteSessionActive => _isRemoteSessionActive;

  /// Enable remote session & broadcast current state immediately to PocketBase.
  void enableRemoteSession() {
    _isRemoteSessionActive = true;
    if (_localDeviceId != null) {
      state = state.copyWith(
        activeDeviceId: _localDeviceId,
        activeDeviceName: _localDeviceName,
      );
    }
    DebugLogService()
        .info("📲 Remote: Activated remote session / Listening Party mode");
    _broadcastRemoteState(forceActive: true);
  }

  // SAVED LOCAL STATE: Preserved when entering a remote session so we can
  // restore the user's last-played song when they disconnect.
  SongModel? _savedLocalSong;
  List<SongModel>? _savedLocalPlaylist;
  int _savedLocalPlaylistIndex = 0;
  double _savedLocalPosition = 0.0;

  // isMaster: Returns true when
  //   1. Not in a remote session (independent mode), OR
  //   2. In a remote session and this device is the active player
  bool get isMaster =>
      !_isRemoteSessionActive ||
      state.activeDeviceId == null ||
      state.activeDeviceId == _localDeviceId;

  void _init() async {
    if (_globalInitialized) {
      return;
    }
    _globalInitialized = true;

    if (Platform.isAndroid) {
      UsbAudioService.init(
        onProgress: (currentMs, totalMs) {
          if (_isLooping) return;
          if (!isMaster) return;

          final currentSecs = currentMs / 1000.0;
          final totalSecs = totalMs / 1000.0;

          if (totalSecs > 0) {
            // Reset completion handler early enough to catch next completion
            if (currentSecs < 2 && _isHandlingCompletion) {
              _isHandlingCompletion = false;
            }

            final durationChanged =
                (state.totalDuration - totalSecs).abs() > 0.5;
            final positionChanged =
                (state.currentPosition - currentSecs).abs() > 0.2;

            if (durationChanged || positionChanged) {
              state = state.copyWith(
                currentPosition: currentSecs,
                totalDuration: totalSecs,
              );
              if (durationChanged) {
                _broadcastRemoteState();
                _updateDiscord();
              }
            }

            // Throttle Android OS notification sync to once per second to prevent IPC DDOS and hanging
            if (currentMs - _lastNotificationSyncMs >= 1000 ||
                _lastNotificationSyncMs > currentMs) {
              _lastNotificationSyncMs = currentMs;
              _musicService.syncCustomEngineState(
                  isPlaying: state.isPlaying,
                  position: Duration(milliseconds: currentMs));
            }

            _processSharedPositionLogic(currentSecs, totalSecs,
                isUsbAudio: true);
          }
        },
      );
    }

    _localDeviceId = await MetricsService().getDeviceIdentifier();
    _localDeviceName = await MetricsService().getDeviceName();

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
        lastSong = SongModel.fromJson(jsonDecode(lastSongJson));

        final checkPath = CuePath.isCuePath(lastSong.filePath)
            ? CuePath.extractAudioPath(lastSong.filePath)
            : lastSong.filePath;
        final needsRebuffering = lastSong.filePath == "cloud_stream" ||
            !await File(checkPath).exists();

        state = state.copyWith(
          volume: volume,
          unmutedVolume: volume > 0 ? volume : 0.5,
          isShuffle: shuffle,
          loopMode: ja.LoopMode.values[loopIndex],
          currentSong: lastSong,
          currentPosition: lastPosition,
          totalDuration:
              lastSong.duration > 0 ? lastSong.duration : state.totalDuration,
          isBuffering: needsRebuffering,
        );

        // CRITICAL: Validate file existence.
        // If cache was cleared, this will trigger JIT caching (re-download)
        // so the player doesn't get stuck on a missing file.
        lastSong = await _ensureFileExists(lastSong);

        // Update state again with validated path and clear buffering
        state = state.copyWith(currentSong: lastSong, isBuffering: false);
      } catch (e) {
        // Silent
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
      try {
        // USE DIFFERENT FLOW BASED ON FILE AVAILABILITY
        // CUE SUPPORT: Use real audio path for existence check
        final loadCheckPath = CuePath.isCuePath(lastSong.filePath)
            ? CuePath.extractAudioPath(lastSong.filePath)
            : lastSong.filePath;
        if (lastSong.filePath != "cloud_stream" &&
            !lastSong.filePath.startsWith('http') &&
            await File(loadCheckPath).exists()) {
          // File exists locally - use simple load with initial position
          // STARTUP OPTIMIZATION: Non-blocking Eager Load
          // We do NOT await this. This allows UI to render instantly while player buffers in background.
          _musicService.load(
            lastSong,
            initialPosition: lastPosition > 0
                ? Duration(seconds: lastPosition.round())
                : null,
            lazyLoad: false,
          );
        } else if (lastSong.filePath.startsWith('http')) {
          // OPTIMIZATION: If the URL is already a valid Tidal stream URL from our server
          // (contains /stream? and id=), reuse it directly. The server handles auth refresh
          // internally, so the URL is stable. This saves ~1-2s of redundant Tidal search.
          final isTidalStreamUrl = lastSong.filePath.contains('/stream?') &&
              lastSong.filePath.contains('id=');
          if (isTidalStreamUrl) {
            debugPrint(
                "🔄 Startup: Reusing existing Tidal stream URL for '${lastSong.title}'");
            _musicService.load(
              lastSong,
              initialPosition: lastPosition > 0
                  ? Duration(seconds: lastPosition.round())
                  : null,
              lazyLoad: false,
            );
          } else {
            debugPrint(
                "🔄 Startup: Re-resolving expired stream URL for '${lastSong.title}'");
            final freshStreamUrl = await _getJitStreamUrl(lastSong);
            if (freshStreamUrl != null) {
              lastSong = lastSong.copyWith(filePath: freshStreamUrl);
              state = state.copyWith(currentSong: lastSong);
              _musicService.load(
                lastSong,
                initialPosition: lastPosition > 0
                    ? Duration(seconds: lastPosition.round())
                    : null,
                lazyLoad: false,
              );
            } else {
              // Tidal can't find it anymore — just show the song info, don't autoplay
              state = state.copyWith(isPlaying: false, isBuffering: false);
            }
          }
        } else {
          // File missing or cloud stream - use load (prepare but don't autoplay)
          _musicService.load(
            lastSong,
            initialPosition: lastPosition > 0
                ? Duration(seconds: lastPosition.round())
                : null,
            lazyLoad: false,
          );
          state = state.copyWith(isPlaying: false);
        }

        final savedThresholdPath = prefs.getString('threshold_song_path');
        if (savedThresholdPath == lastSong.filePath) {
          _isThresholdMet = prefs.getBool('threshold_met') ?? false;
          _cumulativeSecondsListened =
              prefs.getDouble('cumulative_seconds') ?? 0.0;
          _lastLogPosition = lastPosition;
        } else {
          // Different song - reset threshold state
          _startNewSession(resetTime: false);
        }

        // RESTORE CACHE CLEAR TIMER
        _cacheClearListeningTimer =
            prefs.getDouble('cache_clear_listening_timer') ?? 0.0;
      } catch (e) {
        // Silent
      }
    }

    // RESTORE QUEUE STATE
    await _restoreQueueState();

    // Initialize Discord
    Future.delayed(const Duration(seconds: 1), () {
      _discordService.init();

      // SYNC INITIAL SETTING
      final settings = ref.read(settingsProvider);
      _discordService.setEnabled(settings.enableDiscordRpc);

      // Sync Discord presence after Discord connects (~6 seconds to be safe)
      // This ensures the current song is sent to Discord even on app restart
      Future.delayed(const Duration(seconds: 6), () {
        if (state.currentSong != null) {
          _updateDiscord();
        }
      });

      // Initialize Taskbar Service
      _taskbarService.initialize(
        onPlay: () => _musicService.resume(
          lastKnownPosition: state.currentSong != null
              ? Duration(milliseconds: (state.currentPosition * 1000).toInt())
              : null,
        ),
        onPause: () => _musicService.pause(),
        onNext: () => playNext(),
        onPrevious: () => playPrevious(),
      );

      // Initialize Remote Control
      _remoteService.init().then((_) async {
        // Set initial state BEFORE listening to prevent stale server data from overwriting local settings
        final loopModeInt = state.loopMode == ja.LoopMode.off
            ? 0
            : (state.loopMode == ja.LoopMode.all ? 1 : 2);
        _remoteService.setInitialState(
          shuffle: state.isShuffle,
          loopMode: loopModeInt,
        );

        await _remoteService.startListening(onCommand: _handleRemoteCommand);
        // Automatically enable remote session mode if remote control is enabled in settings and not offline
        if (!PocketBaseService.isOffline &&
            PocketBaseService.enableRemoteControl) {
          _isRemoteSessionActive = true;
          if (isMaster) {
            _broadcastRemoteState(
                forceActive: true); // Sync Initial State to server
          }
        }
      });

      // Connect Notification Controls (Mobile)
      if (Platform.isAndroid || Platform.isIOS) {
        _musicService.setNotificationCallbacks(
          onNext: () => playNext(),
          onPrev: () => playPrevious(),
          onPlay: () => togglePlayPause(),
          onPause: () => togglePlayPause(),
        );
      }
    });

    // LISTEN FOR SETTINGS CHANGES
    ref.listen(settingsProvider, (previous, next) {
      if (previous?.enableDiscordRpc != next.enableDiscordRpc) {
        _discordService.setEnabled(next.enableDiscordRpc);
      }
      if (previous?.enableReplayGain != next.enableReplayGain) {
        _musicService.enableReplayGain = next.enableReplayGain;
      }
    });

    // Initialize the Downloader Service
    _downloaderService.initialize().catchError((e) {
      // Silent
    });

    // Load settings first (Volume, Shuffle, Repeat)
    _loadSettings();

    // SEEK BAR UPDATER & SLAVE INTERPOLATOR (High-Resolution)
    // Runs at 5Hz (200ms) to provide buttery smooth movement.
    // Also acts as a watchdog to update the slider if the native positionStream freezes (e.g. Android VideoPlayer conflict).
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!state.isPlaying || _isTransitioning) return;

      if (_isRemoteSessionActive &&
          !isMaster &&
          state.totalDuration > 0) {
        final newPos = state.currentPosition + 0.2;
        if (newPos <= state.totalDuration) {
          state = state.copyWith(currentPosition: newPos);
        }
      } else if (isMaster) {
        // Watchdog: If the positionStream freezes (which can happen on Android when VideoPlayer initializes),
        // we manually fetch the position from the engine to keep the UI ticking.
        final pos = _musicService.position;
        final currentSecs = pos.inMilliseconds / 1000.0;
        
        // Ignore stale position updates from a previous song during transition/crossfade
        if (state.totalDuration > 0 && currentSecs > state.totalDuration) return;
        if (state.currentPosition < 1.0 && currentSecs > 5.0) return;
        
        // If the native engine position is completely stuck but we are still in a playing state,
        // we force the slider to interpolate forward.
        if (currentSecs == _lastEngineSecs && state.isPlaying && state.totalDuration > 0) {
          final newPos = state.currentPosition + 0.2;
          if (newPos <= state.totalDuration) {
            state = state.copyWith(currentPosition: newPos);
          } else if (newPos > state.totalDuration + 1.0) {
            // Failsafe auto-advance if the engine is completely dead and we passed the end of the song
            playNext(autoPlay: true);
          }
        } else {
          // Engine is ticking normally (or user seeked natively), sync our state
          if ((state.currentPosition - currentSecs).abs() > 0.4) {
            state = state.copyWith(currentPosition: currentSecs);
          }
        }
        
        _lastEngineSecs = currentSecs;
      }
    });

    // Extract color immediately if a song is already loaded (Persistence)
    if (state.currentSong != null) {
      _extractPalette(state.currentSong!);
    }

    _musicService.activePlayerStream.listen((player) {
      if (!isMaster) return;
      state = state.copyWith(audioSessionId: player.androidAudioSessionId);
    });

    _musicService.durationStream.listen((duration) {
      if (_isLooping) return;
      if (!isMaster) return;
      if (_musicService.isSeeking) return;

      if (duration != null) {
        final newDuration = duration.inMilliseconds / 1000.0;
        // Reject zero/near-zero duration if we already have a valid one (stream reload artifact)
        if (newDuration < 1.0 && state.totalDuration > 1.0) return;
        // Only broadcast if duration ACTUALLY changed (prevents spam during crossfade)
        final durationChanged = (state.totalDuration - newDuration).abs() > 0.5;
        // Use millisecond precision to avoid truncation artifacts
        state = state.copyWith(totalDuration: newDuration);
        _updateDiscord();
        if (durationChanged) {
          _broadcastRemoteState();
        }
      }
    });

    _musicService.positionStream.listen((position) {
      if (_isLooping) return;
      if (!isMaster) return;
      if (_musicService.isSeeking) return;

      // Ignore resets when the player goes idle due to error/disconnect
      if (_musicService.player.processingState == ja.ProcessingState.idle &&
          position == Duration.zero) {
        return;
      }

      // Use millisecond precision to prevent 2-3s early skip appearance
      final currentSecs = position.inMilliseconds / 1000.0;
      final duration = state.totalDuration;

      // Ignore stale position updates from a previous song during transition/crossfade
      if (duration > 0 && currentSecs > duration) return;
      if (state.currentPosition < 1.0 && currentSecs > 5.0) return;

      // Stale position stream protection:
      // Completely block position stream events while the engine is being swapped
      if (_isTransitioning) return;

      // FROZEN ENGINE PROTECTION:
      // If the position stream is stuck on the exact same position, but the app is in a playing state,
      // it means the native Android player event channel has frozen (e.g., due to VideoPlayer conflict).
      // We IGNORE these stale updates so the UI doesn't get snapped back, allowing the Watchdog timer to interpolate!
      if (currentSecs == _lastEngineSecs && state.isPlaying) {
        return;
      }
      
      _lastEngineSecs = currentSecs;

      if ((state.currentPosition - currentSecs).abs() > 0.2) {
        state = state.copyWith(currentPosition: currentSecs);
      }

      _processSharedPositionLogic(currentSecs, duration, isUsbAudio: false);
    });

    // HANDLE ASYNCHRONOUS PLAYBACK ERRORS (Streaming / Decoding)
    _musicService.playbackEventStream.listen((event) {
      // Normal playback events can be ignored as they are handled elsewhere
    }, onError: (error, stackTrace) {
      if (_musicService.isSeeking) {
        return; // Ignore during Android absolute seeks
      }

      if (_musicService.isCrossfading) {
        DebugLogService().info(
            "[Player] Stream error during crossfade — scheduling recovery replay for: ${state.currentSong?.title}");
        final recoverySong = state.currentSong;
        if (recoverySong != null) {
          // Cancel the active crossfade timer and recreate the dead player
          _musicService.cancelCrossfade();
          _musicService.recreateActivePlayer();
          // Retry the same song without crossfade after a short grace period
          Future.delayed(const Duration(milliseconds: 500), () {
            if (state.currentSong?.title == recoverySong.title) {
              _musicService.play(recoverySong, crossfadeDuration: 0.0);
            }
          });
        }
        return;
      }

      if (_isHandlingCompletion) {
        final timeSinceRequest = DateTime.now().difference(_lastPlayRequestTime).inMilliseconds;
        if (timeSinceRequest < 1500) {
          DebugLogService().info(
              "[Player] Ignoring spurious error during transition ($timeSinceRequest ms since request): $error");
          return;
        }
      }

      // RETRY CURRENT SONG: If we haven't exhausted retries, try to resume
      // the same song at the last known position instead of skipping.
      final retrySong = state.currentSong;
      final retryPosition = state.currentPosition;
      if (_currentSongRetryCount < _maxSongRetries && retrySong != null) {
        _currentSongRetryCount++;
        _isRecoveringFromCrash = true;
        _isHandlingCompletion = true;
        _musicService.recreateActivePlayer();
        DebugLogService().info(
            "[Player] 🔄 Stream error — retrying current song '${retrySong.title}' at ${retryPosition.toStringAsFixed(1)}s (attempt $_currentSongRetryCount/$_maxSongRetries)");

        final errorToken = _playRequestToken;
        Future.delayed(const Duration(milliseconds: 800), () async {
          if (errorToken != _playRequestToken) {
            _isRecoveringFromCrash = false;
            return;
          }
          // Re-resolve the stream URL in case the CDN link expired
          final isOnlineStream = retrySong.filePath.startsWith('http');
          SongModel songToPlay = retrySong;
          if (isOnlineStream) {
            try {
              final freshUrl = await _getJitStreamUrl(retrySong);
              if (freshUrl != null) {
                songToPlay = retrySong.copyWith(filePath: freshUrl);
                // Update state so the UI reflects the new URL
                state = state.copyWith(currentSong: songToPlay);
              }
            } catch (e) {
              DebugLogService().warning(
                  "[Player] Failed to re-resolve stream URL: $e");
            }
          }
          final resumePos = retryPosition > 1.0
              ? Duration(milliseconds: (retryPosition * 1000).toInt())
              : null;
          final success = await _executePlayRouting(songToPlay,
              crossfadeDuration: 0.0, initialPosition: resumePos);
          _isHandlingCompletion = false;
          if (success) {
            DebugLogService().info(
                "[Player] ✅ Retry succeeded for '${retrySong.title}'");
          } else {
            DebugLogService().warning(
                "[Player] ❌ Retry failed for '${retrySong.title}', skipping...");
            _currentSongRetryCount = 0;
            await playNext(autoPlay: true);
          }
          _isRecoveringFromCrash = false;
        });
        return;
      }

      // Exhausted retries — fall through to skip logic
      _currentSongRetryCount = 0;
      _consecutiveSkipCount++;
      if (_consecutiveSkipCount >= _maxConsecutiveSkips) {
        _consecutiveSkipCount = 0;
        state = state.copyWith(isPlaying: false);
      } else {
        _isHandlingCompletion = true;
        _isRecoveringFromCrash = true;
        _musicService.recreateActivePlayer();
        _finalizePlaySession();

        // Throttled Retry
        final errorToken = _playRequestToken;
        Future.delayed(const Duration(milliseconds: 1500), () async {
          if (errorToken == _playRequestToken) {
            await playNext(autoPlay: true);
          }
          _isRecoveringFromCrash = false;
        });
      }
    });

    _musicService.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      // Sync buffering state from native player engine (only for online streams)
      final isOnline = state.currentSong?.filePath.startsWith('http') ?? false;
      if (processingState == ja.ProcessingState.buffering) {
        if (isOnline && !state.isBuffering) {
          state = state.copyWith(isBuffering: true);
        }
      } else if (processingState == ja.ProcessingState.ready ||
          processingState == ja.ProcessingState.completed ||
          processingState == ja.ProcessingState.idle) {
        if (state.isBuffering) {
          state = state.copyWith(isBuffering: false);
        }
      }

      if (processingState == ja.ProcessingState.idle &&
          isPlaying &&
          state.isPlaying) {
        final timeSinceRequest = DateTime.now().difference(_lastPlayRequestTime).inMilliseconds;
        final isRecentTransition = _isHandlingCompletion && timeSinceRequest < 1500;
        if (isRecentTransition ||
            _isLooping ||
            _isRecoveringFromCrash ||
            _musicService.isSeeking ||
            _musicService.isLoading ||
            _musicService.isCrossfading) {
          if (isRecentTransition) {
            DebugLogService().info(
                "[Player] Ignoring unexpected idle during transition ($timeSinceRequest ms since request)");
          }
          return;
        }
        _isRecoveringFromCrash = true;

        // RETRY CURRENT SONG on unexpected idle (same logic as playbackEvent error)
        final retrySong = state.currentSong;
        final retryPosition = state.currentPosition;
        if (_currentSongRetryCount < _maxSongRetries && retrySong != null) {
          _currentSongRetryCount++;
          _isHandlingCompletion = true;
          _musicService.recreateActivePlayer();
          DebugLogService().info(
              "[Player] 🔄 Unexpected idle — retrying '${retrySong.title}' at ${retryPosition.toStringAsFixed(1)}s (attempt $_currentSongRetryCount/$_maxSongRetries)");

          final crashToken = _playRequestToken;
          Future.microtask(() async {
            if (crashToken != _playRequestToken) {
              _isRecoveringFromCrash = false;
              return;
            }
            final isOnlineStream = retrySong.filePath.startsWith('http');
            SongModel songToPlay = retrySong;
            if (isOnlineStream) {
              try {
                final freshUrl = await _getJitStreamUrl(retrySong);
                if (freshUrl != null) {
                  songToPlay = retrySong.copyWith(filePath: freshUrl);
                  state = state.copyWith(currentSong: songToPlay);
                }
              } catch (e) {
                DebugLogService().warning(
                    "[Player] Failed to re-resolve stream URL: $e");
              }
            }
            final resumePos = retryPosition > 1.0
                ? Duration(milliseconds: (retryPosition * 1000).toInt())
                : null;
            final success = await _executePlayRouting(songToPlay,
                crossfadeDuration: 0.0, initialPosition: resumePos);
            _isHandlingCompletion = false;
            if (success) {
              DebugLogService().info(
                  "[Player] ✅ Idle retry succeeded for '${retrySong.title}'");
            } else {
              DebugLogService().warning(
                  "[Player] ❌ Idle retry failed for '${retrySong.title}', skipping...");
              _currentSongRetryCount = 0;
              await playNext(autoPlay: true);
            }
            _isRecoveringFromCrash = false;
          });
          return;
        }

        // Exhausted retries — fall through to skip
        _currentSongRetryCount = 0;
        _consecutiveSkipCount++;
        if (_consecutiveSkipCount >= _maxConsecutiveSkips) {
          _consecutiveSkipCount = 0;
          state = state.copyWith(isPlaying: false);
          _isRecoveringFromCrash = false;
        } else {
          _musicService.recreateActivePlayer();
          _finalizePlaySession();
          // NON-BLOCKING: Use Future.microtask to avoid blocking the stream listener
          // playNext involves potentially long JIT cache downloads
          final crashToken = _playRequestToken;
          Future.microtask(() async {
            if (crashToken == _playRequestToken) {
              await playNext(autoPlay: true);
            }
            _isRecoveringFromCrash = false;
          });
        }
        return;
      }

      if (processingState == ja.ProcessingState.completed) {
        if (_isHandlingCompletion) return;
        if (_musicService.isLoading) return;

        // ADDITIONAL PROTECT: Platform channels are asynchronous. The spurious completed
        // event might arrive slightly AFTER _isLoading is flipped back to false.
        // Debounce: Ignore any 'completed' event firing within 1.5 seconds of a fresh request!
        if (DateTime.now().difference(_lastPlayRequestTime).inMilliseconds <
            1500) {
          DebugLogService().info(
              "[Player] 🛑 Spurious completed event intercepted! (Too soon after play request: ${DateTime.now().difference(_lastPlayRequestTime).inMilliseconds}ms)");
          return;
        }

        _isHandlingCompletion = true;

        // Only delay if NEITHER crossfade nor gapless is enabled.
        final settings = ref.read(settingsProvider);
        final useDelay =
            !settings.gaplessPlayback && settings.crossfadeDuration < 0.1;

        // Capture token to detect stale handlers (e.g. if user manually skips during the 1s delay)
        final completionToken = _playRequestToken;
        Future.delayed(
          (Platform.isWindows ||
                  Platform.isLinux ||
                  Platform.isMacOS ||
                  !useDelay)
              ? Duration.zero
              : const Duration(seconds: 1),
          () {
            // Abort if a new explicit play request started during the delay
            if (_playRequestToken != completionToken) {
              _isHandlingCompletion = false;
              return;
            }
            if (state.isSleepPending) {
              _finalizePlaySession();
              state = state.copyWith(isPlaying: false, isSleepPending: false);
              _musicService.pause();
              _musicService.setVolume(state.volume);
            } else if (state.loopMode == ja.LoopMode.one) {
              _forceLoopOne();
            } else {
              _finalizePlaySession();
              playNext(autoPlay: true);
            }
          },
        );
        return;
      }

      if (!isMaster) return;

      // C++ Engine Override: When C++ Engine is active, ExoPlayer is kept paused in the background.
      // Seeking ExoPlayer causes it to emit a false "paused" state stream update.
      // Do NOT let ExoPlayer's paused state override our true UI state!
      if (_isUsingCppEngine() && _isCppEnginePrepared) {
        return;
      }

      if (state.isPlaying != isPlaying) {
        if (_isLooping && !isPlaying) {
          return;
        }

        if (_isRecoveringFromCrash) {
          return;
        }

        state = state.copyWith(isPlaying: isPlaying);
        _updateDiscord();
        _updateTaskbar();
        _broadcastRemoteState();
      }
    });
  }

  // DOWNLOAD INTEGRATION
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

  // QUEUE MANAGEMENT METHODS

  void reorderUserQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    _preloadRequestToken++;
    final newQueue = List<SongModel>.from(state.userQueue);
    final song = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, song);

    state = state.copyWith(userQueue: newQueue);
    _preloadCheckpoints.clear(); // Re-trigger preload for new next song
    _preloadingTitle = null; // Allow preloading a different song
    _saveQueueState();
  }

  void removeUserQueueItem(int index) {
    if (index < 0 || index >= state.userQueue.length) return;
    _preloadRequestToken++;
    final newQueue = List<SongModel>.from(state.userQueue);
    newQueue.removeAt(index);
    state = state.copyWith(userQueue: newQueue);
    _preloadCheckpoints.clear();
    _preloadingTitle = null;
    _saveQueueState();
  }

  void removeRecommendationQueueItem(int index) {
    if (index < 0 || index >= state.recommendationQueue.length) return;
    _preloadRequestToken++;
    final newQueue = List<SongModel>.from(state.recommendationQueue);
    newQueue.removeAt(index);
    state = state.copyWith(recommendationQueue: newQueue);
    _preloadCheckpoints.clear();
    _preloadingTitle = null;
    _saveQueueState();
  }

  void reorderRecommendationQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    if (oldIndex < 0 ||
        oldIndex >= state.recommendationQueue.length ||
        newIndex < 0 ||
        newIndex >= state.recommendationQueue.length) {
      return;
    }

    _preloadRequestToken++;
    final newQueue = List<SongModel>.from(state.recommendationQueue);
    final song = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, song);
    state = state.copyWith(recommendationQueue: newQueue);
    _preloadCheckpoints.clear();
    _preloadingTitle = null;
    _saveQueueState();
  }

  void reorderMainPlaylist(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    if (oldIndex < 0 ||
        oldIndex >= state.playlist.length ||
        newIndex < 0 ||
        newIndex >= state.playlist.length) {
      return;
    }

    _preloadRequestToken++;
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
    _saveQueueState();
    _preloadCheckpoints.clear();
    _preloadingTitle = null;
  }

  // SERIALIZED DOWNLOAD HELPER
  // Ensures only 1 download happens at a time (e.g. current song + preload) to save bandwidth
  Future<void> _safeCacheSong(SongMetadata meta,
      {String? youtubeUrl, String? streamUrl, int? preloadToken}) async {
    while (_preloadLock != null) {
      await _preloadLock!.future;
    }

    // Check if this preload request was superseded while waiting for the lock
    if (preloadToken != null && preloadToken != _preloadRequestToken) {
      return;
    }

    _preloadLock = Completer<void>();
    try {
      await _smartService.cacheSong(meta,
          youtubeUrl: youtubeUrl, streamUrl: streamUrl);

      // HOT-SWAP: If the currently playing song was just cached, update its model
      if (state.currentSong != null &&
          state.currentSong!.title == meta.title &&
          state.currentSong!.artist == meta.artist) {
        final cachedPath = await _smartService.getPredictedCachePath(meta);
        if (await File(cachedPath).exists() &&
            await File(cachedPath).length() > 1024) {
          final updatedSong = state.currentSong!.copyWith(filePath: cachedPath);
          _updateSongInState(state.currentSong!, updatedSong);
        }
      }
    } finally {
      final c = _preloadLock;
      _preloadLock = null;
      c?.complete();
    }
  }

  void _scheduleStreamingCacheIfEnabled({
    required SongModel song,
    required String streamUrl,
    int? currentToken,
  }) {
    if (!ref.read(settingsProvider).cacheStreamedSongs) return;
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
    Future.delayed(const Duration(seconds: 15), () {
      // Token guard: skip if a newer play request superseded this one
      if (currentToken != null && currentToken != _playRequestToken) return;
      // Title+artist identity guard (survives filePath hot-swap by _safeCacheSong)
      if (state.currentSong?.title == song.title &&
          state.currentSong?.artist == song.artist) {
        _safeCacheSong(meta, youtubeUrl: song.sourceUrl, streamUrl: streamUrl);
      }
    });
  }

  // Synchronize a song update across the entire player state (Current, Playlist, Queue)
  void _updateSongInState(SongModel oldSong, SongModel newSong) {
    // 1. Update Currently Playing
    if (state.currentSong?.filePath == oldSong.filePath &&
        state.currentSong?.title == oldSong.title) {
      state = state.copyWith(currentSong: newSong);
    }

    // 2. Update Playlist
    final playlist = List<SongModel>.from(state.playlist);
    int pIdx = playlist.indexOf(oldSong);
    if (pIdx == -1) {
      pIdx = playlist.indexWhere(
          (s) => s.filePath == oldSong.filePath && s.title == oldSong.title);
    }
    if (pIdx != -1) {
      playlist[pIdx] = newSong;
      state = state.copyWith(playlist: playlist);
    }

    // 3. Update User Queue
    final userQueue = List<SongModel>.from(state.userQueue);
    int qIdx = userQueue.indexOf(oldSong);
    if (qIdx == -1) {
      qIdx = userQueue.indexWhere(
          (s) => s.filePath == oldSong.filePath && s.title == oldSong.title);
    }
    if (qIdx != -1) {
      userQueue[qIdx] = newSong;
      state = state.copyWith(userQueue: userQueue);
    }

    _saveQueueState();
  }

  Future<void> insertSongNext(SongModel song) async {
    // Append to userQueue (FIFO for Play Next batch) instead of prepending
    final newQueue = List<SongModel>.from(state.userQueue)..add(song);

    // Remove from recommendation section if added manually
    final newRecQueue = List<SongModel>.from(state.recommendationQueue);
    newRecQueue
        .removeWhere((s) => s.title == song.title && s.artist == song.artist);

    state =
        state.copyWith(userQueue: newQueue, recommendationQueue: newRecQueue);
    _saveQueueState();
    _preloadPlayNextSong(song);
  }

  /// Background preloader for Play Next queue items.
  /// Non-blocking: runs in background so insertSongNext returns immediately.
  void _preloadPlayNextSong(SongModel song) async {
    try {
      if (await File(song.filePath).exists()) return;

      final isYtSource =
          song.sourceUrl != null && song.sourceUrl!.contains('youtube');
      if (!isYtSource && !ref.read(settingsProvider).cacheStreamedSongs) {
        return;
      }

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
      final preReqToken = ++_preloadRequestToken;
      await _safeCacheSong(meta,
          youtubeUrl: song.sourceUrl, preloadToken: preReqToken);

      // Update the song in state with resolved cached path
      final cachedPath = await _smartService.getPredictedCachePath(meta);
      if (await File(cachedPath).exists() &&
          await File(cachedPath).length() > 1024) {
        final updatedSong = song.copyWith(filePath: cachedPath);
        _updateSongInState(song, updatedSong);
      }
    } catch (e) {
      DebugLogService()
          .error("[Player] Play Next preload failed: ${song.title}: $e");
    }
  }

  void addToQueue(SongModel song) async {
    final newQueue = List<SongModel>.from(state.userQueue)..add(song);

    // Remove from recommendation section if added manually
    final newRecQueue = List<SongModel>.from(state.recommendationQueue);
    newRecQueue
        .removeWhere((s) => s.title == song.title && s.artist == song.artist);

    state =
        state.copyWith(userQueue: newQueue, recommendationQueue: newRecQueue);
    _saveQueueState();
    _broadcastRemoteState();

    // TRIGGER PRELOAD (serialized: waits for any active preload)
    if (!await File(song.filePath).exists()) {
      final isYtSource =
          song.sourceUrl != null && song.sourceUrl!.contains('youtube');
      if (!isYtSource && !ref.read(settingsProvider).cacheStreamedSongs) {
        return;
      }

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
      final preReqToken = ++_preloadRequestToken;
      await _safeCacheSong(meta,
          youtubeUrl: song.sourceUrl, preloadToken: preReqToken);
    }
  }

  Future<void> playPrioritySong(SongModel song) async {
    _finalizePlaySession();
    _startNewSession(resetTime: true);
    _isLooping = false;

    final newQueue = List<SongModel>.from(state.userQueue);
    newQueue.remove(song);

    // Remove from recommendation section if played directly
    final newRecQueue = List<SongModel>.from(state.recommendationQueue);
    newRecQueue
        .removeWhere((s) => s.title == song.title && s.artist == song.artist);

    state =
        state.copyWith(userQueue: newQueue, recommendationQueue: newRecQueue);
    _saveQueueState();

    // Save to history
    ref.read(historyProvider.notifier).addToHistory(
          song: song,
          youtubeUrl: song.sourceUrl,
          artUrl: song.onlineArtUrl,
        );

    _extractPalette(song);

    // JIT / REBUFFER CHECK (Fixes "Cloud Stream Error" and Missing Files)
    final readySong = await _ensureFileExists(song);

    state = state.copyWith(
      currentSong: readySong,
      isPlaying: true,
      currentPosition: 0.0,
    );

    await _musicService.play(readySong);
    _updateDiscord();
    _broadcastRemoteState(); // Sync Song Change
  }

  // COLOR EXTRACTION (Fixed for MP3s and Streaming)
  Future<void> _extractPalette(SongModel song) async {
    if (_isExtractingPalette) return;
    _isExtractingPalette = true;

    // OFF-LOAD: Run in microtask to avoid blocking the current animation frame
    Future.microtask(() async {
      try {
        final filePath = song.filePath;

        // 1. TRY LOCAL FILE FIRST (faster for offline, works without network)
        if (filePath.isNotEmpty && !filePath.startsWith('http')) {
          try {
            final file = File(filePath);
            if (await file.exists()) {
              // Read metadata from file to get image bytes (uses safe ffmpeg path for AIFF/WAV/etc)
              final metadata = await MetadataService().readMetadata(filePath);
              final bytes = metadata.picture?.data;

              if (bytes != null) {
                // Use MemoryImage with the bytes we just read, wrapped in ResizeImage
                final palette = await PaletteGenerator.fromImageProvider(
                  ResizeImage(MemoryImage(bytes), width: 150, height: 150),
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
                  _isExtractingPalette = false;
                  return;
                }
              }
            }
          } catch (e) {
            // Silent
          }
        }

        // 2. FALLBACK TO ONLINE ART (only if local failed and URL exists)
        if (song.onlineArtUrl != null && song.onlineArtUrl!.isNotEmpty) {
          try {
            final palette = await PaletteGenerator.fromImageProvider(
              ResizeImage(NetworkImage(song.onlineArtUrl!),
                  width: 150, height: 150),
              maximumColorCount: 20,
            ).timeout(const Duration(
                seconds: 5)); // Timeout to prevent blocking offline

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
              _isExtractingPalette = false;
              return; // Success with online art
            }
          } catch (e) {
            // Silent
          }
        }

        // No color extracted
        state = state.copyWith(dominantColor: null);
      } finally {
        _isExtractingPalette = false;
      }
    });
  }

  // SETTINGS LOADING
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVolume = prefs.getDouble('volume') ?? 0.5;
    await _musicService.setVolume(savedVolume);
    _musicService.enableReplayGain = prefs.getBool('enableReplayGain') ?? true;
    _broadcastRemoteState();

    final savedShuffle = prefs.getBool('shuffle') ?? false;
    final savedLoopIndex = prefs.getInt('loopMode') ?? 0;
    final savedLoopMode = ja.LoopMode.values.length > savedLoopIndex
        ? ja.LoopMode.values[savedLoopIndex]
        : ja.LoopMode.off;
    final savedEndlessQueue = prefs.getBool('endlessQueue') ?? true;

    // Always force service to OFF so we handle loops manually
    await _musicService.setLoopMode(ja.LoopMode.off);

    state = state.copyWith(
      volume: savedVolume,
      unmutedVolume: savedVolume,
      isShuffle: savedShuffle,
      loopMode: savedLoopMode,
      endlessQueueEnabled: savedEndlessQueue,
    );
  }

  // QUEUE PERSISTENCE
  Future<void> _saveQueueState() async {
    final prefs = await SharedPreferences.getInstance();

    // Serialize lists
    final playlistJson =
        jsonEncode(state.playlist.map((s) => s.toJson()).toList());
    final originalPlaylistJson =
        jsonEncode(state.originalPlaylist.map((s) => s.toJson()).toList());
    final userQueueJson =
        jsonEncode(state.userQueue.map((s) => s.toJson()).toList());
    final recommendationQueueJson =
        jsonEncode(state.recommendationQueue.map((s) => s.toJson()).toList());

    await prefs.setString('queue_playlist', playlistJson);
    await prefs.setString('queue_original_playlist', originalPlaylistJson);
    await prefs.setString('queue_user_queue', userQueueJson);
    await prefs.setString('queue_recommendation', recommendationQueueJson);
  }

  void _processSharedPositionLogic(double currentSecs, double duration,
      {bool isUsbAudio = false}) {
    // Reset consecutive skips and song retry count on successful continuous playback (>2s)
    if (currentSecs >= 2.0 && _consecutiveSkipCount > 0) {
      _consecutiveSkipCount = 0;
    }
    if (currentSecs >= 2.0 && _currentSongRetryCount > 0) {
      _currentSongRetryCount = 0;
    }

    if (currentSecs >= 2.0 && currentSecs < 10.0 && _isHandlingCompletion) {
      _isHandlingCompletion = false;
    }

    // SMART SLEEP TIMER FADE & INTERCEPT (Highest Priority)
    if (state.isSleepPending && duration > 0 && !_isHandlingCompletion) {
      if (duration > 10.0 && currentSecs >= (duration - 10.0)) {
        double fraction = (duration - currentSecs) / 10.0;
        if (fraction < 0.0) fraction = 0.0;
        if (fraction > 1.0) fraction = 1.0;
        _musicService.setVolume(state.unmutedVolume * fraction);
        if (isUsbAudio) {
          UsbAudioService.setVolume(state.unmutedVolume * fraction);
        }
      }

      // Intercept the end of the track to PAUSE instead of skipping or repeating.
      // Triggers at -0.4s to beat both LoopOne (-0.3s) and Crossfade/Gapless.
      if (currentSecs >= (duration - 0.4)) {
        _isHandlingCompletion = true;
        _finalizePlaySession();
        state = state.copyWith(isPlaying: false, isSleepPending: false);
        _musicService.pause();
        _musicService.setVolume(state.volume);
        if (isUsbAudio) {
          UsbAudioService.pause();
          UsbAudioService.setVolume(state.volume);
        }
        return;
      }
    }

    // Manual Loop One Logic (Only if not sleeping)
    if (state.loopMode == ja.LoopMode.one &&
        duration > 0 &&
        !_isHandlingCompletion) {
      if (currentSecs >= (duration - 0.3)) {
        _forceLoopOne();
        return;
      }
    }

    // CROSSFADE / GAPLESS TRIGGER (Skip if Repeat One is active or Sleeping)
    final settings = ref.read(settingsProvider);
    final crossfadeLen = settings.crossfadeDuration;
    final isGapless = settings.gaplessPlayback;

    if (duration > 0 &&
        !_isHandlingCompletion &&
        state.loopMode != ja.LoopMode.one &&
        !state.isSleepPending) {
      final canCrossfade = _canCrossfadeWithNextSong();
      if (crossfadeLen > 0.1 && canCrossfade) {
        // Crossfade: Trigger early (at duration - crossfadeLen)
        if (currentSecs >= (duration - crossfadeLen)) {
          _isHandlingCompletion = true;
          _finalizePlaySession();
          playNext(autoPlay: true);
        }
      } else if (isGapless || (crossfadeLen > 0.1 && !canCrossfade)) {
        // Gapless or Crossfade fallback: Trigger slightly early to ensure smooth transition.
        // For USB/JNI audio, trigger slightly earlier (0.4s) due to scheduling/JNI overhead.
        final triggerOffset = isUsbAudio ? 0.4 : 0.2;
        if (currentSecs >= (duration - triggerOffset)) {
          _isHandlingCompletion = true;
          _finalizePlaySession();
          playNext(autoPlay: true);
        }
      } else if (isUsbAudio && currentSecs >= (duration - 0.4)) {
        // Gapless / Completion fallback for USB Audio
        _isHandlingCompletion = true;
        _finalizePlaySession();
        playNext(autoPlay: true);
      }
    }

    // Periodic Save (Every 10 seconds)
    // This ensures we save position even if app is killed while playing
    if ((currentSecs - _lastSavedPosition).abs() > 10) {
      _saveSettings();
      _lastSavedPosition = currentSecs;
    }

    // MULTI-CHECKPOINT PRELOAD: Trigger at 0%, 30%, 70%
    if (duration > 0) {
      final progressPercent = currentSecs / duration;

      // Check each threshold
      for (final threshold in [10, 35, 70]) {
        if (!_preloadCheckpoints.contains(threshold) &&
            progressPercent >= threshold / 100) {
          _preloadCheckpoints.add(threshold);
          _preloadNextSong();
          break; // Only trigger one per position update
        }
      }
    }

    // Discord Sync: Update every 30 seconds to keep rich presence accurate and check connection health
    final posInSeconds = currentSecs.toInt();
    if (posInSeconds > 0 && posInSeconds % 30 == 0 && state.isPlaying) {
      if (_lastDiscordSyncSeconds != posInSeconds) {
        _lastDiscordSyncSeconds = posInSeconds;
        _updateDiscord();
      }
    }

    // Stats Logic
    if (DateTime.now().difference(_lastSongChangeTime).inSeconds < 2) return;

    if (state.currentSong != null && state.isPlaying) {
      double delta = currentSecs - _lastLogPosition;
      if (delta >= 1.0 && delta < 5.0) {
        int secondsToLog = delta.toInt();
        ref
            .read(statsProvider.notifier)
            .logTime(state.currentSong!, secondsToLog);
        _cumulativeSecondsListened += delta;
        _cacheClearListeningTimer += delta;

        // STREAMING DATA USAGE TRACKING
        final currentPath = state.currentSong!.filePath;
        final isStreaming = currentPath.startsWith('http://') ||
            currentPath.startsWith('https://');
        if (isStreaming) {
          int bitrateKbps = 320; // safe default
          if (currentPath.contains('HI_RES_LOSSLESS') ||
              currentPath.contains('LOSSLESS')) {
            bitrateKbps = 1100;
          } else if (currentPath.contains('quality=HIGH') ||
              currentPath.contains('LOW')) {
            bitrateKbps = 320;
          }
          final bytesConsumed = ((bitrateKbps * 1000) ~/ 8) * secondsToLog;
          ref.read(dataUsageProvider.notifier).addBytes(bytesConsumed);
        }

        // AUTO CLEAR CACHE LOGIC
        final clearMode = settings.autoClearCache;
        double cacheThreshold = 0;
        if (clearMode == 'every_30min') {
          cacheThreshold = 1800;
        } else if (clearMode == 'every_hour') {
          cacheThreshold = 3600;
        } else if (clearMode == 'every_2hours') {
          cacheThreshold = 7200;
        }

        if (cacheThreshold > 0 && _cacheClearListeningTimer >= cacheThreshold) {
          _downloaderService.clearCache();
          _cacheClearListeningTimer = 0;
          SharedPreferences.getInstance()
              .then((p) => p.setDouble('cache_clear_listening_timer', 0.0));
        }

        // Advance log position only by the truncated integer so fractional left-over is preserved
        _lastLogPosition += secondsToLog;

        // REAL-TIME MINUTES BUMP: Update UI every 60 accumulated seconds
        _minutesBumpAccumulator += secondsToLog;
        if (_minutesBumpAccumulator >= 60.0) {
          final minutesToBump = (_minutesBumpAccumulator / 60.0).floor();
          _minutesBumpAccumulator -= minutesToBump * 60.0;
          ref.read(profileProvider.notifier).bumpCloudStats(
                minutesIncrement: minutesToBump,
              );
        }
      } else if (delta < -1.0 || delta >= 5.0) {
        // Seek or new song
        _lastLogPosition = currentSecs;
      }
    }

    if (!_isSessionLogged && !_isThresholdMet && duration > 0) {
      double requiredTime = duration * _playCountThreshold;

      // Anti-Farming: Force a minimum of 25 seconds of listening time
      // even if the song is extremely short (e.g. 2-second exploit file).
      if (requiredTime < 25.0) {
        requiredTime = 25.0;
      }

      if (_cumulativeSecondsListened >= requiredTime) {
        _isThresholdMet = true;
      }
    }
  }

  SongModel? _peekNextSong() {
    if (state.userQueue.isNotEmpty) {
      return state.userQueue.first;
    }
    if (state.playlist.isNotEmpty) {
      if (_playlistIndex < state.playlist.length - 1) {
        return state.playlist[_playlistIndex + 1];
      } else if (state.loopMode == ja.LoopMode.all) {
        return state.playlist.first;
      }
    }
    return null;
  }

  bool _canCrossfadeWithNextSong() {
    final current = state.currentSong;
    final next = _peekNextSong();
    if (current == null || next == null) return false;

    // 1. If either is JNI (ALAC or USB bypass), we CANNOT crossfade
    if (_isUsingCppEngine(current) || _isUsingCppEngine(next)) return false;

    // 2. Both must use the same engine (both FFI local, or both ExoPlayer stream)
    final isCurrentFfi = (Platform.isWindows || Platform.isAndroid) &&
        !current.filePath.startsWith('http') &&
        NativeMusicService.isFfiSupported(current.filePath);

    final isNextFfi = (Platform.isWindows || Platform.isAndroid) &&
        !next.filePath.startsWith('http') &&
        NativeMusicService.isFfiSupported(next.filePath);

    return isCurrentFfi == isNextFfi;
  }

  Future<void> _restoreQueueState() async {
    final prefs = await SharedPreferences.getInstance();

    final playlistJson = prefs.getString('queue_playlist');
    final originalPlaylistJson = prefs.getString('queue_original_playlist');
    final userQueueJson = prefs.getString('queue_user_queue');
    final recommendationQueueJson = prefs.getString('queue_recommendation');

    List<SongModel> playlist = [];
    List<SongModel> originalPlaylist = [];
    List<SongModel> userQueue = [];
    List<SongModel> recommendationQueue = [];

    try {
      if (playlistJson != null) {
        playlist = (jsonDecode(playlistJson) as List)
            .map((e) {
              try {
                return SongModel.fromJson(e);
              } catch (e) {
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
                return null;
              }
            })
            .whereType<SongModel>()
            .toList();

        // Deduplicate on Restore (Fixes double entries bug)
        final seen = <String>{};
        userQueue = [];

        for (var song in rawQueue) {
          final key = "${song.filePath}|${song.title}".toLowerCase();

          if (!seen.contains(key)) {
            seen.add(key);
            userQueue.add(song);
          }
        }
      }
    } catch (e) {
      // Fallback: Clear corrupted queue to allow app to start
      playlist = [];
      originalPlaylist = [];
      userQueue = [];
      recommendationQueue = [];
    }

    // Restore recommendation queue
    try {
      if (recommendationQueueJson != null) {
        recommendationQueue = (jsonDecode(recommendationQueueJson) as List)
            .map((e) {
              try {
                return SongModel.fromJson(e);
              } catch (_) {
                return null;
              }
            })
            .whereType<SongModel>()
            .toList();
      }
    } catch (_) {
      recommendationQueue = [];
    }

    state = state.copyWith(
      playlist: playlist,
      originalPlaylist: originalPlaylist,
      userQueue: userQueue,
      recommendationQueue: recommendationQueue,
    );

    // Recalculate index if we have a current song
    if (state.currentSong != null && playlist.isNotEmpty) {
      _playlistIndex =
          playlist.indexWhere((s) => s.filePath == state.currentSong!.filePath);
      if (_playlistIndex == -1) _playlistIndex = 0;
    }
  }

  // CONTROLS

  Future<void> _forceLoopOne() async {
    if (_isLooping) return;
    _isLooping = true;

    if (state.currentSong == null) {
      _isLooping = false;
      return;
    }

    await playSong(
      state.currentSong!,
      skipFinalize: false,
      forceReload: true,
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      _isLooping = false;
    });
  }

  void _finalizePlaySession() {
    if (_isSessionLogged) {
      return;
    }
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
    _preloadCheckpoints.clear();
    _preloadRequestToken++;
    if (resetTime) {
      _lastSongChangeTime = DateTime.now();
    }
  }

  // JIT CACHE HELPER
  Future<SongModel> _ensureFileExists(SongModel song) async {
    final isHttp = song.filePath.startsWith('http://') ||
        song.filePath.startsWith('https://');
    if (isHttp) return song; // ALREADY A STREAMING URL

    // CUE SUPPORT: For CUE virtual paths, check the real audio file
    if (CuePath.isCuePath(song.filePath)) {
      final realPath = CuePath.extractAudioPath(song.filePath);
      final f = File(realPath);
      if (await f.exists() && await f.length() > 1024) {
        return song; // Audio file exists, CUE track is valid
      }
      return song.copyWith(filePath: "cloud_stream"); // Audio file missing
    }

    // ONLY skip if we have a VALID local file (> 1KB)
    if (song.filePath != "cloud_stream") {
      final f = File(song.filePath);
      if (await f.exists() && await f.length() > 1024) {
        // HARDENED: Verify FLAC integrity before playback
        bool isValid = true;
        if (song.filePath.toLowerCase().endsWith('.flac')) {
          isValid = await FlacDownloaderService.isFlacFileValid(song.filePath);
        }

        if (isValid) return song;

        try {
          await f.delete();
        } catch (_) {}
      }
    }

    final streamUrl = await _getJitStreamUrl(song);
    if (streamUrl != null) {
      return song.copyWith(filePath: streamUrl);
    }

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

    // Attempt Cache (Fallback if stream fails)
    await _smartService.cacheSong(meta, youtubeUrl: song.sourceUrl);

    final cachedPath = await _smartService.getPredictedCachePath(meta);
    if (await File(cachedPath).exists()) {
      return song.copyWith(filePath: cachedPath);
    }

    // FINAL FALLBACK: If caching failed, switch to direct cloud streaming.
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
        song = song.copyWith(sourceUrl: bestMatch.url);
      }
    }

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

  // PRELOAD NEXT SONG LOGIC (serialized: 1 download at a time)
  Future<void> _preloadNextSong() async {
    // DELAY PRELOAD: Wait 3 seconds to let current song establish stream
    await Future.delayed(const Duration(seconds: 3));

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
    }

    if (nextSong != null) {
      // Check if file exists
      if (await File(nextSong.filePath).exists()) return;

      // Guard: Skip if already preloading this song
      if (_preloadingTitle == nextSong.title) {
        return;
      }

      // Guard: Check if file was already cached by a previous preload
      // (e.g. 10% checkpoint cached it, now 35% fires — no need to re-download)
      final preCheckMeta = SongMetadata(
        title: nextSong.title,
        artist: nextSong.artist,
        album: nextSong.album,
        albumArtUrl: nextSong.onlineArtUrl ?? "",
        durationSeconds: nextSong.duration.toInt(),
        year: "",
        genre: "",
      );
      final preCheckPath =
          await _smartService.getPredictedCachePath(preCheckMeta);
      if (await File(preCheckPath).exists() &&
          await File(preCheckPath).length() > 1024) {
        return;
      }

      _preloadingTitle = nextSong.title;

      final isYtSource =
          nextSong.sourceUrl != null && nextSong.sourceUrl!.contains('youtube');
      if (!isYtSource && !ref.read(settingsProvider).cacheStreamedSongs) {
        // This is a Tidal-streamable song and the user disabled background caching
        _preloadingTitle = null;
        return;
      }

      // INJECT SPOTIFY ENRICHMENT (YT MUSIC IMPORTS)
      String title = nextSong.title;
      String artist = nextSong.artist;
      String album = nextSong.album;
      String albumArtUrl = nextSong.onlineArtUrl ?? "";
      String? isrc = nextSong.isrc;
      String? year;
      String? genre;

      final isYtImport =
          nextSong.sourceUrl != null && nextSong.sourceUrl!.contains('youtube');
      if (isYtImport) {
        try {
          final query = "${nextSong.title} ${nextSong.artist}";
          List<SongMetadata> results = [];

          try {
            results = await SpotifyService.searchTracks(query);
          } catch (e) {
            // Silent
          }

          if (results.isEmpty) {
            try {
              results = await DeezerService.searchSongs(query);
            } catch (e) {
              // Silent
            }
          }

          if (results.isNotEmpty) {
            final richMeta = results.first;
            title = richMeta.title.isNotEmpty ? richMeta.title : title;
            artist = richMeta.artist.isNotEmpty ? richMeta.artist : artist;
            album = richMeta.album.isNotEmpty ? richMeta.album : album;
            albumArtUrl = richMeta.albumArtUrl.isNotEmpty
                ? richMeta.albumArtUrl
                : albumArtUrl;
            isrc = richMeta.isrc ?? isrc;
            year = (richMeta.year != null && richMeta.year!.isNotEmpty)
                ? richMeta.year
                : year;
            genre = richMeta.genre ?? genre;

            // Update the state so the queue immediately reflects the high-res art & accurate title
            // This is critical because cache path depends on the updated title
            final originalSong = nextSong;
            nextSong = originalSong.copyWith(
              title: title,
              artist: artist,
              album: album,
              onlineArtUrl: albumArtUrl,
              isrc: isrc,
            );

            _updateSongInState(originalSong, nextSong);
          }
        } catch (e) {
          // Silent
        }
      }

      // Reconstruct Metadata
      final meta = SongMetadata(
        title: title,
        artist: artist,
        album: album,
        albumArtUrl: albumArtUrl,
        durationSeconds: nextSong!.duration.toInt(),
        year: year ?? "",
        genre: genre ?? "",
        isrc: isrc,
      );

      final currentPreloadToken = _preloadRequestToken;

      // Trigger Background Cache (awaited now!)
      await _safeCacheSong(meta,
          youtubeUrl: nextSong.sourceUrl, preloadToken: currentPreloadToken);

      final resolvedPath = await _smartService.getPredictedCachePath(meta);
      if (await File(resolvedPath).exists() &&
          await File(resolvedPath).length() > 1024) {
        final updatedNext = nextSong.copyWith(filePath: resolvedPath);
        _updateSongInState(nextSong, updatedNext);
      }

      _preloadingTitle = null;
    }
  }

  // PRELOAD PREVIOUS SONG (serialized: 1 download at a time)
  // ignore: unused_element
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

    // Guard: Skip if we are currently streaming a live song (Bandwidth congestion protection)
    final isStreaming = state.currentSong?.filePath.startsWith('http') ?? false;
    if (isStreaming) {
      return;
    }

    // INJECT SPOTIFY ENRICHMENT (YT MUSIC IMPORTS)
    String title = prevSong.title;
    String artist = prevSong.artist;
    String album = prevSong.album;
    String albumArtUrl = prevSong.onlineArtUrl ?? "";
    String? isrc = prevSong.isrc;
    String? year;
    String? genre;

    final isYtImport =
        prevSong.sourceUrl != null && prevSong.sourceUrl!.contains('youtube');
    if (isYtImport) {
      try {
        final query = "${prevSong.title} ${prevSong.artist}";
        List<SongMetadata> results = [];

        try {
          results = await SpotifyService.searchTracks(query);
        } catch (e) {
          // Silent
        }

        if (results.isEmpty) {
          try {
            results = await DeezerService.searchSongs(query);
          } catch (e) {
            // Silent
          }
        }

        if (results.isNotEmpty) {
          final richMeta = results.first;
          title = richMeta.title.isNotEmpty ? richMeta.title : title;
          artist = richMeta.artist.isNotEmpty ? richMeta.artist : artist;
          album = richMeta.album.isNotEmpty ? richMeta.album : album;
          albumArtUrl = richMeta.albumArtUrl.isNotEmpty
              ? richMeta.albumArtUrl
              : albumArtUrl;
          isrc = richMeta.isrc ?? isrc;
          year = (richMeta.year != null && richMeta.year!.isNotEmpty)
              ? richMeta.year
              : year;
          genre = richMeta.genre ?? genre;

          final originalSong = prevSong;
          final updatedPrevSong = originalSong.copyWith(
            title: title,
            artist: artist,
            album: album,
            onlineArtUrl: albumArtUrl,
            isrc: isrc,
          );

          int pIdx = state.playlist.indexOf(originalSong);
          if (pIdx == -1) {
            pIdx = state.playlist.indexWhere((s) =>
                s.filePath == originalSong.filePath &&
                s.title == originalSong.title);
          }
          if (pIdx != -1) {
            final newP = List<SongModel>.from(state.playlist);
            newP[pIdx] = updatedPrevSong;
            state = state.copyWith(playlist: newP);
          }
        }
      } catch (e) {
        // Silent
      }
    }

    final meta = SongMetadata(
      title: title,
      artist: artist,
      album: album,
      albumArtUrl: albumArtUrl,
      durationSeconds: prevSong.duration.toInt(),
      year: year ?? "",
      genre: genre ?? "",
      isrc: isrc,
    );
    final currentPreloadToken = _preloadRequestToken;
    await _safeCacheSong(meta,
        youtubeUrl: prevSong.sourceUrl, preloadToken: currentPreloadToken);

    // Resolve and update resolved path
    final resolvedPath = await _smartService.getPredictedCachePath(meta);
    if (await File(resolvedPath).exists() &&
        await File(resolvedPath).length() > 1024) {
      final updatedPrev = prevSong.copyWith(filePath: resolvedPath);
      _updateSongInState(prevSong, updatedPrev);
    }
  }

  Future<bool> _executePlayRouting(SongModel song,
      {double crossfadeDuration = 0.0, Duration? initialPosition}) async {
    final bool isM4A = song.filePath.toLowerCase().endsWith('.m4a');
    final bool isALAC = song.filePath.toLowerCase().endsWith('.alac');

    // Estimate bitrate for .m4a to separate ALAC from AAC (AAC almost never exceeds 320-512kbps)
    double estimatedBitrate = 0;
    if (isM4A && song.duration > 0 && song.filePath != "cloud_stream" && !song.filePath.startsWith('http')) {
      try {
        final file = File(song.filePath);
        if (file.existsSync()) {
          final size = file.lengthSync();
          estimatedBitrate = (size * 8) / song.duration / 1000;
        }
      } catch (_) {}
    }

    final bool isLocalAlac = Platform.isAndroid &&
        song.filePath != "cloud_stream" &&
        !song.filePath.startsWith('http') &&
        (isALAC || (isM4A && estimatedBitrate > 500));

    if ((_useUsbAudioBypass ||
            ref.read(settingsProvider).androidBitPerfect ||
            isLocalAlac) &&
        Platform.isAndroid) {
      // PRE-ACTIVATE: Block ExoPlayer's async "paused" event from reaching Android MediaSession
      // BEFORE we pause ExoPlayer. Without this, ExoPlayer fires "paused" → Android downgrades
      // the foreground service → app gets suspended when minimized.
      _musicService.preActivateCustomEngineState();
      await _musicService.pause();
      await UsbAudioService.stop();
      _isCppEnginePrepared = false;

      final usbSuccess = await _playViaUsbAudio(song,
          isAlacFallback: isLocalAlac, initialPosition: initialPosition);
      if (!usbSuccess) {
        debugPrint("⚠️ C++ engine failed for ALAC, trying ExoPlayer...");
        // play() calls clearCustomEngineState() internally, restoring ExoPlayer control
        return await _musicService.play(song, initialPosition: initialPosition);
      }
      return true;
    } else {
      if (Platform.isAndroid) {
        await UsbAudioService.pause();
      }
      return await _musicService.play(song,
          crossfadeDuration: crossfadeDuration,
          initialPosition: initialPosition);
    }
  }

  Future<void> playSong(SongModel song,
      {List<SongModel>? newQueue,
      bool skipFinalize = false,
      bool forceReload = false,
      Duration? initialPosition}) async {
    final currentToken = ++_playRequestToken;
    _lastPlayRequestTime = DateTime.now();

    // SLAVE INTERCEPT
    if (!isMaster) {
      DebugLogService().info(
          "📲 Remote: Intercepting play_song request and forwarding to Master.");
      // Package up to 50 queue items to avoid PocketBase string size limits
      final payload = {
        'song': song.toJson(),
        if (newQueue != null && newQueue.isNotEmpty)
          'queue': newQueue.take(50).map((s) => s.toJson()).toList(),
      };

      _remoteService.sendCommand('play_song', payload: jsonEncode(payload));
      return;
    }

    // Reset completion guard and retry count on explicit play
    _isHandlingCompletion = false;
    _currentSongRetryCount = 0;

    if (!skipFinalize) _finalizePlaySession();
    _startNewSession(resetTime: true);
    state = state.copyWith(isBuffering: false);

    _isTransitioning = true;
    // CLEAR RECOMMENDATIONS only when user switches to a NEW playlist/album context
    // Don't clear when just playing a single song (streaming)
    if (newQueue != null) {
      state = state.copyWith(recommendationQueue: []);
      _autoQueueService.resetCache();
    }

    // Save to history
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

    // 0. PRE-EMPTIVE CACHE CHECK
    // Even if the DB says it's an HTTP URL or 'cloud_stream', check if it's already downloaded.
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
    
    final preCheckPath = await _smartService.getPredictedCachePath(meta);
    if (await File(preCheckPath).exists() && await File(preCheckPath).length() > 1024) {
      song = song.copyWith(filePath: preCheckPath);
    }

    // JIT CACHING CHECK
    final isHttp = song.filePath.startsWith('http://') ||
        song.filePath.startsWith('https://');
    bool fileExists = isHttp || await File(song.filePath).exists();

    if (!fileExists) {
      state = state.copyWith(isBuffering: true);

      // 1. TRY JIT STREAMING FIRST
      bool streamedInstantly = false;
      try {
        final streamUrl = await _getJitStreamUrl(song);
        if (streamUrl != null) {
          song = song.copyWith(filePath: streamUrl);
          streamedInstantly = true;
        }

        if (streamedInstantly) {
          _scheduleStreamingCacheIfEnabled(
            song: song,
            streamUrl: song.filePath,
            currentToken: currentToken,
          );
        }
      } catch (e) {
        // Silent
      }

      // 2. FALLBACK TO BACKGROUND CACHING
      if (!streamedInstantly) {
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

        // We use safeCacheSong to serialize downloads
        await _safeCacheSong(meta, youtubeUrl: song.sourceUrl);
        if (currentToken != _playRequestToken) {
          return;
        }

        // CHECK IF CACHED FILE EXISTS
        final cachedPath = await _smartService.getPredictedCachePath(meta);
        if (await File(cachedPath).exists()) {
          song = song.copyWith(filePath: cachedPath);
        } else {
          // Fallback to cloud_stream if everything else fails
          if (song.sourceUrl != null && song.sourceUrl!.isNotEmpty) {
            song = song.copyWith(filePath: "cloud_stream");
          } else {
            if (skipFinalize || newQueue != null || state.playlist.isNotEmpty) {
              playNext(autoPlay: true);
              return;
            }
          }
        }
      }

      state = state.copyWith(isBuffering: false);
    } else if (isHttp) {
      _scheduleStreamingCacheIfEnabled(
        song: song,
        streamUrl: song.filePath,
        currentToken: currentToken,
      );
    }

    final isSameSong = state.currentSong?.filePath == song.filePath;

    final newPos =
        initialPosition != null ? initialPosition.inMilliseconds / 1000.0 : 0.0;
    state = state.copyWith(currentPosition: newPos);

    if (isSameSong && !forceReload && initialPosition == null) {
      // USB Audio bypass / ALAC Fallback seek
      await _musicService.seek(Duration.zero);
      if (Platform.isAndroid) await UsbAudioService.seek(0);

      if (!state.isPlaying) {
        await _musicService.resume();
        await _resumeUsbAudio();
      }
      _isTransitioning = false;
    } else {
      // Push current song to play history before switching
      _pushToPlayHistory(state.currentSong);
      state = state.copyWith(
        currentSong: song,
        isPlaying: true,
        currentPosition: initialPosition?.inSeconds.toDouble() ?? 0.0,
        totalDuration: song.duration > 0 ? song.duration : state.totalDuration,
      );
      _updateDiscord();

      final success = await _executePlayRouting(song,
          crossfadeDuration: (isSameSong || skipFinalize)
              ? 0.0
              : ref.read(settingsProvider).crossfadeDuration,
          initialPosition: initialPosition);
      _isTransitioning = false;
      if (currentToken != _playRequestToken) return;
      if (!success) {
        playNext(autoPlay: true);
        return;
      }
    }
    _saveSettings();
    _saveQueueState();

    _broadcastRemoteState();

    // ENDLESS QUEUE: Check immediately when playing
    _checkEndlessQueue();
  }

  Future<void> playNext({bool autoPlay = false}) async {
    if (!isMaster) {
      _remoteService.sendCommand('next');
      return;
    }

    // REPEAT ONE: If triggered automatically, perform a repeat instead of skipping.
    // EXCEPTION: If we are recovering from a crash, ignore loop mode and skip to next
    // to prevent infinite retry loop on a dead/broken stream.
    if (autoPlay &&
        state.loopMode == ja.LoopMode.one &&
        !_isRecoveringFromCrash) {
      await _forceLoopOne();
      return;
    }

    final currentToken = ++_playRequestToken;
    _lastPlayRequestTime = DateTime.now();

    // Explicit user skip resets the guard
    if (!autoPlay) {
      _isHandlingCompletion = false;
      _finalizePlaySession();
    }

    _startNewSession(resetTime: true);
    _isLooping = false;
    state = state.copyWith(isBuffering: false);

    final settings = ref.read(settingsProvider);

    // 1. Check Play Next queue (userQueue)
    if (state.userQueue.isNotEmpty) {
      var nextSong = state.userQueue.first;
      state = state.copyWith(userQueue: state.userQueue.sublist(1));
      _saveQueueState();

      _isTransitioning = true;

      // Push current song to play history before switching
      _pushToPlayHistory(state.currentSong);
      state = state.copyWith(
        currentSong: nextSong,
        isPlaying: true,
        currentPosition: 0.0,
        totalDuration:
            nextSong.duration > 0 ? nextSong.duration : state.totalDuration,
      );
      _updateDiscord();

      // EXTRACT COLOR (Immediate for UI snappiness)
      _extractPalette(nextSong);

      // JIT CACHING CHECK FOR USER QUEUE
      final isHttpByPath = nextSong.filePath.startsWith('http') ||
          nextSong.filePath.startsWith('https');
      if (!isHttpByPath && !File(nextSong.filePath).existsSync()) {
        state = state.copyWith(isBuffering: true);

        final streamUrl = await _getJitStreamUrl(nextSong);
        if (streamUrl != null) {
          nextSong = nextSong.copyWith(filePath: streamUrl);
          state = state.copyWith(currentSong: nextSong);

          _scheduleStreamingCacheIfEnabled(
            song: nextSong,
            streamUrl: streamUrl,
            currentToken: currentToken,
          );
        } else {
          final meta = SongMetadata(
            title: nextSong.title,
            artist: nextSong.artist,
            album: nextSong.album,
            albumArtUrl: nextSong.onlineArtUrl ?? "",
            durationSeconds: nextSong.duration.toInt(),
          );
          await _safeCacheSong(meta, youtubeUrl: nextSong.sourceUrl);
          if (currentToken != _playRequestToken) return;

          final cachedPath = await _smartService.getPredictedCachePath(meta);
          if (await File(cachedPath).exists()) {
            nextSong = nextSong.copyWith(filePath: cachedPath);
            state = state.copyWith(currentSong: nextSong);
          }
        }
        state = state.copyWith(isBuffering: false);
      } else if (isHttpByPath) {
        _scheduleStreamingCacheIfEnabled(
          song: nextSong,
          streamUrl: nextSong.filePath,
          currentToken: currentToken,
        );
      }

      if (currentToken != _playRequestToken) return;
      final success = await _executePlayRouting(nextSong,
          crossfadeDuration: settings.crossfadeDuration);
      _isTransitioning = false;
      if (currentToken != _playRequestToken) return;
      if (!success) {
        final fallbackSong = await _ensureFileExists(nextSong);
        if (currentToken != _playRequestToken) return;
        final retrySuccess = await _executePlayRouting(fallbackSong,
            crossfadeDuration: settings.crossfadeDuration);
        _isTransitioning = false;
        if (currentToken != _playRequestToken) return;
        if (!retrySuccess) {
          // Only skip THIS song — try the next userQueue item or playlist song
          DebugLogService().error(
              "[Player] User queue song failed after retry: ${nextSong.title}");
          // _isHandlingCompletion will be reset by position listener at 2s mark
          playNext(autoPlay: true);
          return;
        }
        // Update state with resolved path
        nextSong = fallbackSong;
        state = state.copyWith(currentSong: nextSong);
      }
      _broadcastRemoteState();

      // _isHandlingCompletion will be reset by position listener at 2s mark
      return;
    }

    // 2. Check Playlist
    if (state.playlist.isNotEmpty) {
      if (_playlistIndex < state.playlist.length - 1) {
        _playlistIndex++;
        var nextSong = state.playlist[_playlistIndex];
        ref.read(historyProvider.notifier).addToHistory(
              song: nextSong,
              youtubeUrl: nextSong.sourceUrl,
              artUrl: nextSong.onlineArtUrl,
            );

        // Push current song to play history before switching
        _pushToPlayHistory(state.currentSong);
        state = state.copyWith(
          currentSong: nextSong,
          isPlaying: true,
          currentPosition: 0.0,
          totalDuration:
              nextSong.duration > 0 ? nextSong.duration : state.totalDuration,
        );
        _updateDiscord();

        // EXTRACT COLOR
        _extractPalette(nextSong);

        // JIT CACHING CHECK FOR PLAYLIST
        final isHttpByPath = nextSong.filePath.startsWith('http') ||
            nextSong.filePath.startsWith('https');
        if (!isHttpByPath && !File(nextSong.filePath).existsSync()) {
          state = state.copyWith(isBuffering: true);

          final streamUrl = await _getJitStreamUrl(nextSong);
          if (streamUrl != null) {
            nextSong = nextSong.copyWith(filePath: streamUrl);
            state = state.copyWith(currentSong: nextSong);

            _scheduleStreamingCacheIfEnabled(
              song: nextSong,
              streamUrl: streamUrl,
              currentToken: currentToken,
            );
          } else {
            final meta = SongMetadata(
              title: nextSong.title,
              artist: nextSong.artist,
              album: nextSong.album,
              albumArtUrl: nextSong.onlineArtUrl ?? "",
              durationSeconds: nextSong.duration.toInt(),
            );
            await _safeCacheSong(meta, youtubeUrl: nextSong.sourceUrl);
            if (currentToken != _playRequestToken) return;
            final cachedPath = await _smartService.getPredictedCachePath(meta);
            if (await File(cachedPath).exists()) {
              nextSong = nextSong.copyWith(filePath: cachedPath);
              state = state.copyWith(currentSong: nextSong);
            }
          }
          state = state.copyWith(isBuffering: false);
        } else if (isHttpByPath) {
          _scheduleStreamingCacheIfEnabled(
            song: nextSong,
            streamUrl: nextSong.filePath,
            currentToken: currentToken,
          );
        }

        if (currentToken != _playRequestToken) return;
        final success = await _executePlayRouting(nextSong,
            crossfadeDuration: settings.crossfadeDuration);
        _isTransitioning = false;
        if (currentToken != _playRequestToken) return;
        if (!success) {
          _consecutiveSkipCount++;
          if (_consecutiveSkipCount >= _maxConsecutiveSkips) {
            DebugLogService()
                .error("[Player] Max consecutive skips reached. Stopping.");
            _consecutiveSkipCount = 0;
            state = state.copyWith(isPlaying: false, isBuffering: false);
            return;
          }

          DebugLogService().warning(
              "[Player] Play failed, throttling next skip (Retry $_consecutiveSkipCount/$_maxConsecutiveSkips)");
          await Future.delayed(const Duration(milliseconds: 1500));

          if (currentToken != _playRequestToken) return;
          playNext(autoPlay: true);
          return;
        }

        // Success! Reset count
        _consecutiveSkipCount = 0;

        // ENDLESS QUEUE CHECK
        _checkEndlessQueue();
        // _isHandlingCompletion will be reset by position listener at 2s mark
        return;
      } else if (state.loopMode == ja.LoopMode.all) {
        _playlistIndex = 0;
        var nextSong = state.playlist[0];
        ref.read(historyProvider.notifier).addToHistory(
              song: nextSong,
              youtubeUrl: nextSong.sourceUrl,
              artUrl: nextSong.onlineArtUrl,
            );

        // Push current song to play history before switching
        _pushToPlayHistory(state.currentSong);
        state = state.copyWith(
          currentSong: nextSong,
          isPlaying: true,
          currentPosition: 0.0,
          totalDuration:
              nextSong.duration > 0 ? nextSong.duration : state.totalDuration,
        );
        _updateDiscord();
        _extractPalette(nextSong);

        // JIT CHECK FOR LOOP ALL
        final isHttpByPath = nextSong.filePath.startsWith('http') ||
            nextSong.filePath.startsWith('https');
        if (!isHttpByPath && !File(nextSong.filePath).existsSync()) {
          state = state.copyWith(isBuffering: true);
          final streamUrl = await _getJitStreamUrl(nextSong);
          if (streamUrl != null) {
            nextSong = nextSong.copyWith(filePath: streamUrl);
            state = state.copyWith(currentSong: nextSong);
            _scheduleStreamingCacheIfEnabled(
              song: nextSong,
              streamUrl: streamUrl,
              currentToken: currentToken,
            );
          } else {
            final meta = SongMetadata(
              title: nextSong.title,
              artist: nextSong.artist,
              album: nextSong.album,
              albumArtUrl: nextSong.onlineArtUrl ?? "",
              durationSeconds: nextSong.duration.toInt(),
            );
            await _safeCacheSong(meta, youtubeUrl: nextSong.sourceUrl);
            if (currentToken != _playRequestToken) return;
            final cachedPath = await _smartService.getPredictedCachePath(meta);
            if (await File(cachedPath).exists()) {
              nextSong = nextSong.copyWith(filePath: cachedPath);
              state = state.copyWith(currentSong: nextSong);
            }
          }
          state = state.copyWith(isBuffering: false);
        } else if (isHttpByPath) {
          _scheduleStreamingCacheIfEnabled(
            song: nextSong,
            streamUrl: nextSong.filePath,
            currentToken: currentToken,
          );
        }

        if (currentToken != _playRequestToken) return;
        final success = await _executePlayRouting(nextSong,
            crossfadeDuration: settings.crossfadeDuration);
        _isTransitioning = false;
        if (currentToken != _playRequestToken) return;
        if (!success) {
          playNext(autoPlay: true);
          return;
        }
        _preloadNextSong();
        _checkEndlessQueue();
        // _isHandlingCompletion will be reset by position listener at 2s mark
        return;
      }
    }

    // 3. Check Recommendation Queue (Endless Queue)
    if (state.recommendationQueue.isNotEmpty) {
      var nextSong = state.recommendationQueue.first;

      ref.read(historyProvider.notifier).addToHistory(
            song: nextSong,
            youtubeUrl: nextSong.sourceUrl,
            artUrl: nextSong.onlineArtUrl,
          );

      state = state.copyWith(
        recommendationQueue: state.recommendationQueue.sublist(1),
      );
      _saveQueueState();

      // Push current song to play history before switching
      _pushToPlayHistory(state.currentSong);
      state = state.copyWith(
        currentSong: nextSong,
        isPlaying: true,
        currentPosition: 0.0,
        totalDuration:
            nextSong.duration > 0 ? nextSong.duration : state.totalDuration,
      );
      _updateDiscord();
      _extractPalette(nextSong);

      // JIT CACHING CHECK FOR RECOMMENDATIONS
      final isHttpByPath = nextSong.filePath.startsWith('http') ||
          nextSong.filePath.startsWith('https');
      debugPrint(
          "🎵 Rec AutoAdvance: filePath='${nextSong.filePath}', isHttp=$isHttpByPath, exists=${!isHttpByPath ? File(nextSong.filePath).existsSync() : 'N/A'}");
      if (!isHttpByPath && !File(nextSong.filePath).existsSync()) {
        state = state.copyWith(isBuffering: true);
        debugPrint(
            "🎵 Rec AutoAdvance: Calling _getJitStreamUrl for '${nextSong.title}'...");
        final streamUrl = await _getJitStreamUrl(nextSong);
        if (streamUrl != null) {
          nextSong = nextSong.copyWith(filePath: streamUrl);
          state = state.copyWith(currentSong: nextSong);
          _scheduleStreamingCacheIfEnabled(
            song: nextSong,
            streamUrl: streamUrl,
            currentToken: currentToken,
          );
        } else {
          state = state.copyWith(isBuffering: false);
          if (currentToken != _playRequestToken) return;
          await playSong(nextSong, skipFinalize: true);
          _checkEndlessQueue();
          return;
        }
        state = state.copyWith(isBuffering: false);
      } else if (isHttpByPath) {
        _scheduleStreamingCacheIfEnabled(
          song: nextSong,
          streamUrl: nextSong.filePath,
          currentToken: currentToken,
        );
      }

      if (currentToken != _playRequestToken) return;
      final success = await _executePlayRouting(nextSong,
          crossfadeDuration: settings.crossfadeDuration);
      _isTransitioning = false;
      if (currentToken != _playRequestToken) return;
      if (!success) {
        playNext(autoPlay: true);
        return;
      }
      _broadcastRemoteState();
      _checkEndlessQueue();
      // _isHandlingCompletion will be reset by position listener at 2s mark
      return;
    }

    // 4. No more songs - pause
    state = state.copyWith(isPlaying: false);
    await _musicService.pause();
    _isHandlingCompletion = false;
  }

  // ENDLESS QUEUE

  /// Toggle endless queue on/off
  void toggleEndlessQueue() {
    state = state.copyWith(endlessQueueEnabled: !state.endlessQueueEnabled);
    _saveSettings();
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
    // Delay recommendations fetch by 3 seconds to prioritize initial audio buffering
    await Future.delayed(const Duration(seconds: 3));

    if (!state.endlessQueueEnabled) {
      return;
    }
    if (state.currentSong == null) {
      return;
    }

    // Calculate remaining songs in queue
    // Priority: userQueue -> playlist -> recommendationQueue
    final remainingInRecommendations = state.recommendationQueue.length;

    // Only fetch when queue is getting low (< 5 remaining)
    // This prevents constant refetching and duplicates
    if (remainingInRecommendations >= 5) {
      return;
    }

    try {
      state = state.copyWith(isLoadingRecommendations: true);

      final recommendations = await _autoQueueService.getRecommendedSongs(
        state.currentSong!,
      );

      if (recommendations.isEmpty) {
        state = state.copyWith(isLoadingRecommendations: false);
        return;
      }

      // Filter out duplicates: current song, songs in playlist, songs already in rec queue
      final currentTitle = state.currentSong?.title.toLowerCase() ?? '';
      final currentArtist = state.currentSong?.artist.toLowerCase() ?? '';
      final existingPlaylistKeys = state.playlist
          .map((s) => '${s.title.toLowerCase()}_${s.artist.toLowerCase()}')
          .toSet();
      final existingRecKeys = state.recommendationQueue
          .map((s) => '${s.title.toLowerCase()}_${s.artist.toLowerCase()}')
          .toSet();

      final filtered = recommendations.where((song) {
        final key = '${song.title.toLowerCase()}_${song.artist.toLowerCase()}';
        // Skip current song
        if (song.title.toLowerCase() == currentTitle &&
            song.artist.toLowerCase() == currentArtist) {
          return false;
        }
        // Skip songs already in playlist
        if (existingPlaylistKeys.contains(key)) return false;
        // Skip songs already in recommendation queue
        if (existingRecKeys.contains(key)) return false;
        return true;
      }).toList();

      if (filtered.isEmpty) {
        state = state.copyWith(isLoadingRecommendations: false);
        return;
      }

      // Add filtered recommendations to queue
      final newRecQueue = List<SongModel>.from(state.recommendationQueue);
      newRecQueue.addAll(filtered);
      state = state.copyWith(
        recommendationQueue: newRecQueue,
        isLoadingRecommendations: false,
      );
      _saveQueueState();

      // Pre-cache only the next song
      if (recommendations.isNotEmpty) {
        _preloadNextSong();
      }
    } catch (e) {
      state = state.copyWith(isLoadingRecommendations: false);
    }
  }

  Future<void> playPrevious() async {
    if (!isMaster) {
      _remoteService.sendCommand('previous');
      return;
    }

    final pos = await _musicService.positionStream.first;
    if (pos.inSeconds > 3) {
      await _musicService.seek(Duration.zero);
      if (Platform.isAndroid) await UsbAudioService.seek(0);
      _updateDiscord();
      return;
    }

    // HYBRID PREVIOUS: Use play history stack (works for local, streaming, recommendations)
    if (_playHistory.isNotEmpty) {
      final prevSong = _playHistory.removeLast();

      final currentToken = ++_playRequestToken;
      _lastPlayRequestTime = DateTime.now();
      _isHandlingCompletion = false;
      _finalizePlaySession();
      _startNewSession(resetTime: true);
      _isLooping = false;
      state = state.copyWith(isBuffering: false);

      // Save to history
      _isTransitioning = true;
      ref.read(historyProvider.notifier).addToHistory(
            song: prevSong,
            youtubeUrl: prevSong.sourceUrl,
            artUrl: prevSong.onlineArtUrl,
          );

      state = state.copyWith(
        currentSong: prevSong,
        isPlaying: true,
        currentPosition: 0.0,
        totalDuration:
            prevSong.duration > 0 ? prevSong.duration : state.totalDuration,
      );
      _updateDiscord();

      // Update playlist index if song is in current playlist
      final idx = state.playlist.indexWhere((s) =>
          s.title.toLowerCase() == prevSong.title.toLowerCase() &&
          s.artist.toLowerCase() == prevSong.artist.toLowerCase());
      if (idx != -1) _playlistIndex = idx;

      // JIT CACHE CHECK FOR PREVIOUS
      final readySong = await _ensureFileExists(prevSong);
      if (currentToken != _playRequestToken) return;
      state = state.copyWith(currentSong: readySong);

      // EXTRACT COLOR
      _extractPalette(readySong);

      if (currentToken != _playRequestToken) return;
      await _executePlayRouting(readySong);
      _isTransitioning = false;
      _broadcastRemoteState();
      return;
    }

    // FALLBACK: If no history, try playlist-based previous
    if (state.playlist.isEmpty) {
      await _musicService.seek(Duration.zero);
      if (Platform.isAndroid) await UsbAudioService.seek(0);
      _updateDiscord();
      return;
    }

    final currentToken = ++_playRequestToken;
    _lastPlayRequestTime = DateTime.now();

    _isHandlingCompletion = false;
    _finalizePlaySession();
    _startNewSession(resetTime: true);
    _isLooping = false;

    if (_playlistIndex > 0) {
      _playlistIndex--;
    } else if (state.playlist.isNotEmpty) {
      if (state.loopMode == ja.LoopMode.all) {
        _playlistIndex = state.playlist.length - 1;
      } else {
        await _musicService.seek(Duration.zero);
        if (Platform.isAndroid) await UsbAudioService.seek(0);
        _updateDiscord();
        return;
      }
    }

    final prevSong = state.playlist[_playlistIndex];
    _isTransitioning = true;
    ref.read(historyProvider.notifier).addToHistory(
          song: prevSong,
          youtubeUrl: prevSong.sourceUrl,
          artUrl: prevSong.onlineArtUrl,
        );

    state = state.copyWith(
      currentSong: prevSong,
      isPlaying: true,
      currentPosition: 0.0,
      totalDuration:
          prevSong.duration > 0 ? prevSong.duration : state.totalDuration,
    );
    _updateDiscord();

    final readySong = await _ensureFileExists(prevSong);
    if (currentToken != _playRequestToken) return;
    state = state.copyWith(currentSong: readySong);

    _extractPalette(readySong);

    if (currentToken != _playRequestToken) return;
    await _executePlayRouting(readySong);
    _isTransitioning = false;
    _broadcastRemoteState();
  }

  /// Push a song to the play history stack (for universal previous button)
  void _pushToPlayHistory(SongModel? song) {
    if (song == null) return;
    _playHistory.add(song);
    // Cap history size to prevent memory bloat
    if (_playHistory.length > _maxPlayHistorySize) {
      _playHistory.removeAt(0);
    }
  }

  Future<void> togglePlay() async {
    await togglePlayPause();
  }

  Future<void> seek(double seconds) async {
    if (!isMaster) {
      _lastManualSeekTime =
          DateTime.now(); // ACTIVATED: Start the 2-second sync lock
      _remoteService.sendCommand('seek', payload: seconds);
      // Optimistic UI update
      state = state.copyWith(currentPosition: seconds);
      return;
    }

    // Optimistically update position state so _updateDiscord() and UI use new position immediately
    state = state.copyWith(currentPosition: seconds);

    final ms = (seconds * 1000).toInt();
    if (_isUsingCppEngine() && _isCppEnginePrepared) {
      if (Platform.isAndroid) {
        await UsbAudioService.seek(ms);
      }
      // Keep Android OS media notification synced without triggering false ExoPlayer events
      _musicService.syncCustomEngineState(
          isPlaying: state.isPlaying, position: Duration(milliseconds: ms));
    } else {
      await _musicService.seek(Duration(milliseconds: ms));
      if (Platform.isAndroid) {
        await UsbAudioService.seek(ms);
      }
    }
    _lastLogPosition = seconds;
    _updateDiscord();
  }

  Future<void> _sendVolumeToEngine(double value) async {
    if (_volumeCallInProgress) {
      _pendingVolume = value;
      return;
    }

    _volumeCallInProgress = true;
    try {
      // Always sync _musicService's volume so FFI volume state remains in sync
      await _musicService.setVolume(value);

      if (_isUsingCppEngine() && _isCppEnginePrepared) {
        final calculatedVol =
            _musicService.getCalculatedVolumeForSong(state.currentSong, value);
        await UsbAudioService.setVolume(calculatedVol);
      }
    } finally {
      _volumeCallInProgress = false;
      if (_pendingVolume != null) {
        final nextVol = _pendingVolume!;
        _pendingVolume = null;
        // Run next volume update
        _sendVolumeToEngine(nextVol);
      }
    }
  }

  Future<void> setVolume(double value) async {
    if (!isMaster) {
      _remoteService.sendCommand('volume', payload: value);
      // Optimistic locally
      final newUnmuted = value > 0 ? value : state.unmutedVolume;
      state = state.copyWith(volume: value, unmutedVolume: newUnmuted);
      return;
    }

    final newUnmuted = value > 0 ? value : state.unmutedVolume;
    state = state.copyWith(volume: value, unmutedVolume: newUnmuted);

    // Asynchronously update volume with concurrency locking
    _sendVolumeToEngine(value);

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

  // SMART SLEEP TIMER
  void setSleepPending(bool isPending) {
    state = state.copyWith(isSleepPending: isPending);
  }

  // SWAP VERSION (Select Version Feature)
  Future<void> swapCurrentSongVersion(String newUrl) async {
    final song = state.currentSong;
    if (song == null) return;

    // 1. Pause Player
    await _musicService.pause();

    // 2. Delete Old File (Critical so JIT triggers)
    try {
      final file = File(song.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Silent
    }

    // 3. Update Song Model
    // KEEP METADATA (Spotify): Only update sourceUrl. Keep Art, Title, Artist, Album.
    final updatedSong = song.copyWith(
      sourceUrl: newUrl,
    );

    // 4. Update in Queue/Playlist (Optional but good for consistency)
    // We update the current song in the state immediately
    state = state.copyWith(currentSong: updatedSong);

    // 5. Re-Play (Triggers JIT Cache with new URL)
    // We pass skipFinalize: true because we are technically continuing the same song session
    await playSong(updatedSong, skipFinalize: true, forceReload: true);
  }

  void toggleShuffle() {
    _lastLocalShuffleTap = DateTime.now(); // COOLDOWN: Mark local tap
    if (!isMaster) {
      _remoteService.sendCommand('shuffle');
      state = state.copyWith(isShuffle: !state.isShuffle);
      return;
    }

    final newShuffle = !state.isShuffle;
    _preloadRequestToken++;
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
    _preloadCheckpoints.clear();
    _preloadingTitle = null;
    _saveSettings();
    _broadcastRemoteState();
  }

  void cycleLoopMode() {
    _lastLocalLoopTap = DateTime.now();
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

    if (!isMaster) {
      _remoteService.sendCommand('repeat');
      state = state.copyWith(loopMode: nextMode);
      return;
    }

    // Always keep service loop mode OFF
    _musicService.setLoopMode(ja.LoopMode.off);
    state = state.copyWith(loopMode: nextMode);
    _saveSettings();
    _broadcastRemoteState();
  }

  Future<void> _updateDiscord() async {
    if (state.currentSong != null) {
      final song = state.currentSong!;

      // Fallback for duration if player hasn't loaded metadata yet
      final effectiveDuration =
          state.totalDuration > 0 ? state.totalDuration : song.duration;

      if (song.filePath != _lastProcessedSongPath ||
          (state.totalDuration == 0 && song.duration > 0)) {
        _lastProcessedSongPath = song.filePath;
        _cachedDiscordImage = null;

        // Use existing onlineArtUrl if available (faster than Spotify fetch)
        String? initialArt = song.onlineArtUrl;

        // --- Discord YouTube Thumbnail Fix ---
        // Discord Rich Presence drops .webp images and complex URLs. 
        // Forcefully construct a clean .jpg URL for YouTube sources.
        final bool isYtSource = song.sourceUrl != null && song.sourceUrl!.contains('youtube');
        if (isYtSource) {
          final RegExp regExp = RegExp(r'(?:v=|/)([0-9A-Za-z_-]{11}).*');
          final match = regExp.firstMatch(song.sourceUrl!);
          if (match != null && match.groupCount >= 1) {
            final videoId = match.group(1);
            initialArt = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
          }
        }

        _discordService.updatePresence(
          song,
          state.isPlaying,
          Duration(milliseconds: (state.currentPosition * 1000).toInt()),
          Duration(seconds: effectiveDuration.toInt()),
          imageUrl: initialArt,
        );

        if (initialArt != null && initialArt.isNotEmpty) {
          _cachedDiscordImage = initialArt;
        }

        // Fetch higher quality art from APIs (with timeout + fallback chain)
        // Skip for YouTube sources to preserve the thumbnail and prevent 404s
        if (!isYtSource) {
          SpotifyService.getTrackImage(song.title, song.artist,
                  fallbackToProxy: true)
              .timeout(const Duration(seconds: 8), onTimeout: () => null)
              .then((artUrl) async {
            if (artUrl != null && artUrl.isNotEmpty) {
              _cachedDiscordImage = artUrl;
              _discordService.updateImage(artUrl);
            } else {
              // Fallback 1: Deezer
              final deezerUrl =
                  await DeezerService.getTrackImage(song.title, song.artist)
                      .timeout(const Duration(seconds: 6), onTimeout: () => null);
              if (deezerUrl != null && deezerUrl.isNotEmpty) {
                _cachedDiscordImage = deezerUrl;
                _discordService.updateImage(deezerUrl);
              }
            }
          }).catchError((e) {
            // Spotify rate-limited or failed — try Deezer as fallback
            DebugLogService()
                .info("[Discord] Spotify art failed: $e, trying Deezer...");
            DeezerService.getTrackImage(song.title, song.artist)
                .timeout(const Duration(seconds: 6), onTimeout: () => null)
                .then((deezerUrl) {
              if (deezerUrl != null && deezerUrl.isNotEmpty) {
                _cachedDiscordImage = deezerUrl;
                _discordService.updateImage(deezerUrl);
              }
            }).catchError((_) => null);
            return null;
          });
        }
      } else {
        _discordService.updatePresence(
          song,
          state.isPlaying,
          Duration(milliseconds: (state.currentPosition * 1000).toInt()),
          Duration(seconds: effectiveDuration.toInt()),
          imageUrl: _cachedDiscordImage,
        );
      }
    } else {
      _discordService.clearPresence();
    }

    _broadcastRemoteState();
    _updateTaskbar();
    _saveSettings();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('volume', state.volume);
    await prefs.setBool('shuffle', state.isShuffle);
    await prefs.setInt('loopMode', state.loopMode.index);
    await prefs.setBool('endlessQueue', state.endlessQueueEnabled);
    // Save Current Position
    await prefs.setDouble('last_position', state.currentPosition);

    // SAVE LAST PLAYED SONG
    if (state.currentSong != null) {
      final songJson = jsonEncode(state.currentSong!.toJson());
      await prefs.setString('last_played_song', songJson);

      // Save the threshold state keyed to the current song so it can be restored
      await prefs.setString('threshold_song_path', state.currentSong!.filePath);
      await prefs.setBool('threshold_met', _isThresholdMet);
      await prefs.setDouble('cumulative_seconds', _cumulativeSecondsListened);
    }

    // SAVE GLOBAL CACHE CLEAR TIMER
    await prefs.setDouble(
        'cache_clear_listening_timer', _cacheClearListeningTimer);
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

  Future<void> togglePlayPause() async {
    if (!isMaster) {
      _remoteService.sendCommand(state.isPlaying ? 'pause' : 'play');
      return;
    }

    final currentlyPlaying = state.isPlaying;

    if (currentlyPlaying) {
      await _musicService.pause();
      if (_isUsingCppEngine()) await _pauseUsbAudio(); // USB AUDIO SYNC
      state = state.copyWith(isPlaying: false);
      _broadcastRemoteState();
      _updateDiscord();
    } else {
      _isHandlingCompletion = false;

      if ((Platform.isAndroid || Platform.isIOS)) {
        if (state.currentSong != null) {
          final savedPosition = state.currentPosition;
          _playRequestToken++;
          state = state.copyWith(isBuffering: false);

          if (_isUsingCppEngine()) {
            // PRE-ACTIVATE: Block ExoPlayer's async "paused" event from downgrading foreground service
            _musicService.preActivateCustomEngineState();
            await _musicService.pause(); // Ensure ExoPlayer is stopped
            if (!_isCppEnginePrepared) {
              final isLocalAlac =
                  state.currentSong!.filePath.toLowerCase().endsWith('.m4a') &&
                      !state.currentSong!.filePath.startsWith('http');
              await _playViaUsbAudio(state.currentSong!,
                  isAlacFallback: isLocalAlac,
                  initialPosition:
                      Duration(milliseconds: (savedPosition * 1000).toInt()));
            } else {
              await _resumeUsbAudio();
            }
          } else {
            await _musicService.resume(
              lastKnownPosition: Duration(
                  milliseconds: (state.currentPosition * 1000).toInt()),
            );
          }
        } else {
          await _musicService.resume();
          if (_isUsingCppEngine()) await _resumeUsbAudio();
        }
      } else {
        await _musicService.resume(
          lastKnownPosition: state.currentSong != null
              ? Duration(milliseconds: (state.currentPosition * 1000).toInt())
              : null,
        );
        if (_isUsingCppEngine()) await _resumeUsbAudio();
      }
      state = state.copyWith(isPlaying: true);
      _broadcastRemoteState();
      _updateDiscord();
    }
  }

  // Handle Remote Commands
  Future<void> _handleRemoteCommand(String action, dynamic value) async {
    // AUTO-ACTIVATE: Only activate remote session via explicit adopt_master command.
    // We do NOT auto-activate from sync_state because the cloud may contain stale
    // active_device_id from a previous session, which would cause a rogue broadcast loop.
    if (!_isRemoteSessionActive) {
      if (action == 'adopt_master' && value == _localDeviceId) {
        _isRemoteSessionActive = true;
        if (_localDeviceId != null) {
          state = state.copyWith(
            activeDeviceId: _localDeviceId,
            activeDeviceName: _localDeviceName,
          );
        }
        DebugLogService().info(
            "📲 Remote: Auto-activated remote session (adopted as master)");
      } else if (!PocketBaseService.isOffline &&
          PocketBaseService.enableRemoteControl) {
        _isRemoteSessionActive = true;
        if (_localDeviceId != null) {
          state = state.copyWith(
            activeDeviceId: _localDeviceId,
            activeDeviceName: _localDeviceName,
          );
        }
        DebugLogService().info(
            "📲 Remote: Auto-activated remote session from command '$action'");
      } else {
        return; // Not in remote session, ignore all remote commands
      }
    }

    if (action != 'sync_state') {
      DebugLogService().info("[Remote] Cmd: $action, Val: $value");
      DebugLogService().info(
          "[Remote] State: Playing=${state.isPlaying}, Song=${state.currentSong?.title}"); // DEBUG LOG
    }

    switch (action) {
      case 'play_song':
        if (!isMaster) return;
        try {
          final Map<String, dynamic> data =
              value is String ? jsonDecode(value) : value;
          final remoteSong = SongModel.fromJson(data['song']);
          List<SongModel>? newQueue;
          if (data['queue'] != null) {
            newQueue = (data['queue'] as List)
                .map((e) =>
                    SongModel.fromJson((e as Map).cast<String, dynamic>()))
                .toList();
          }
          DebugLogService().info(
              "💻 Master: Executing remote play_song for ${remoteSong.title}");

          // Execute on the master device
          playSong(remoteSong, newQueue: newQueue);
        } catch (e) {
          DebugLogService().error("⚠️ Master play_song error: $e");
        }
        break;
      case 'play':
        if (!isMaster) return;
        DebugLogService().info("[Remote] Executing RESUME");
        _isHandlingCompletion = false;
        await _musicService.resume(
          lastKnownPosition: state.currentSong != null
              ? Duration(milliseconds: (state.currentPosition * 1000).toInt())
              : null,
        );
        if (_isUsingCppEngine()) await _resumeUsbAudio();
        state = state.copyWith(isPlaying: true);
        _broadcastRemoteState();
        break;
      case 'pause':
        if (!isMaster) return;
        DebugLogService().info("[Remote] Executing PAUSE");
        await _musicService.pause();
        if (_isUsingCppEngine()) await _pauseUsbAudio();
        state = state.copyWith(isPlaying: false);
        _broadcastRemoteState();
        break;
      case 'next':
        if (!isMaster) return;
        playNext();
        break;
      case 'previous':
        if (!isMaster) return;
        playPrevious();
        break;
      case 'seek':
        DebugLogService().info(
            "[Remote] Processing SEEK command. isMaster=$isMaster, val=$value");
        if (!isMaster) {
          DebugLogService().warning("[Remote] SEEK REJECTED: Not master.");
          return;
        }
        double? seekVal;
        if (value is num) seekVal = value.toDouble();
        if (value is String) seekVal = double.tryParse(value);
        if (seekVal != null) {
          DebugLogService().info("[Remote] Executing SEEK to $seekVal");
          seek(seekVal);

          // IMMEDIATE SYNC: Blast the new position back to the cloud immediately!
          // This "squashes" any stale position broadcasts already in flight.
          _broadcastRemoteState();
        } else {
          DebugLogService().error(
              "[Remote] SEEK FAILED: Invalid value type ${value.runtimeType}");
        }
        break;
      case 'volume':
        DebugLogService().info(
            "[Remote] Processing VOLUME command. isMaster=$isMaster, val=$value");
        if (!isMaster) return;
        double? volVal;
        if (value is num) volVal = value.toDouble();
        if (value is String) volVal = double.tryParse(value);
        if (volVal != null) {
          setVolume(volVal);
        }
        break;
      case 'shuffle':
        if (!isMaster) return;
        toggleShuffle();
        break;
      case 'repeat':
        if (!isMaster) return;
        cycleLoopMode();
        break;
      case 'adopt_master':
        if (value == _localDeviceId) {
          if (!isMaster) {
            DebugLogService()
                .info("📲 Remote: Adopted as MASTER by EXPLICIT command.");
            Future.microtask(() => switchToThisDevice());
          } else {
            // Already master! We MUST resend our true state so the newly joined slave instantly updates its UI.
            _broadcastRemoteState(forceActive: true);
          }
        }
        break;
      // SAFE STATE SYNC (Artist, Title, Position, Logic)
      case 'sync_state':
        if (value is Map<String, dynamic>) {
          final now = DateTime.now();

          // MASTER ECHO GUARD: When the master broadcasts, polling reads it back.
          // Skip processing our own echo to prevent wasted state churn and excessive UI rebuilds.
          final cloudActiveId = value['active_device_id'] as String?;
          if (isMaster && cloudActiveId == _localDeviceId) {
            break;
          }

          final cloudActiveName = value['active_device_name'] as String?;

          final wasMaster = isMaster;

          state = state.copyWith(
            activeDeviceId: cloudActiveId,
            activeDeviceName: cloudActiveName,
          );

          final isNowMaster = isMaster;

          // AUTO-ADOPT MASTER: If we were a follower but the cloud just told us
          // we are the active device (nominated by a remote device), we take over.
          if (!wasMaster && isNowMaster && cloudActiveId != null) {
            DebugLogService()
                .info("📲 Remote: Adopted as MASTER by cloud nomination.");
            Future.microtask(() => switchToThisDevice());
          } else if (wasMaster &&
              isNowMaster &&
              value['last_command'] == 'adopt_master') {
            // If we were already master, but a slave just requested us via active_device update, resend state!
            _broadcastRemoteState(forceActive: true);
          }

          // 2. POSITION & PLAYBACK SYNC
          if (!isNowMaster) {
            // we are a SLAVE: Follow the master's song information
            // SILENCE LOCAL PLAYER: Slaves MUST NOT make sound
            if (state.isPlaying) {
              _musicService.pause();
            }

            final cloudTitle = value['current_title'] as String?;
            final cloudArtist = value['current_artist'] as String?;
            final cloudPlaying = value['is_playing'] as bool? ?? false;
            final cloudPos =
                (value['position_seconds'] as num? ?? 0).toDouble();
            final cloudDuration =
                (value['duration_seconds'] as num? ?? 0).toDouble();

            // SYNC LOCK: Check if we recently performed a manual seek (Cooldown: 2s)
            bool isSeekLocked = false;
            if (_lastManualSeekTime != null) {
              final diff = now.difference(_lastManualSeekTime!).inSeconds;
              if (diff < 2) {
                isSeekLocked = true;
                DebugLogService().info(
                    "📲 Remote Sync: Position update IGNORED (Seek Lock Active)");
              }
            }

            final cloudSourceUrl = value['source_url'] as String?;
            final cloudSpotifyId = value['spotify_id'] as String?;
            final cloudAlbum = value['current_album'] as String?;

            // If song changed remotely
            if (cloudTitle != null &&
                (state.currentSong == null ||
                    state.currentSong!.title != cloudTitle)) {
              // FAST LOCAL MATCH: Avoid Spotify limits and get Instant 4K Native Art if we have the file!
              SongModel? localMatch;
              try {
                localMatch = state.playlist.firstWhere(
                    (s) => s.title == cloudTitle && s.artist == cloudArtist);
              } catch (_) {}

              final dummySong = localMatch?.copyWith(
                    sourceUrl: cloudSourceUrl,
                    spotifyId: cloudSpotifyId,
                    duration: cloudDuration,
                  ) ??
                  SongModel(
                    title: cloudTitle,
                    artist: cloudArtist ?? "Unknown",
                    album: cloudAlbum ?? "Remote",
                    filePath: "remote",
                    fileExtension: "mp3",
                    duration: cloudDuration,
                    onlineArtUrl: value['album_art_url'],
                    sourceUrl: cloudSourceUrl,
                    spotifyId: cloudSpotifyId,
                  );

              state = state.copyWith(
                currentSong: dummySong,
                isPlaying: cloudPlaying,
                currentPosition: cloudPos,
                totalDuration: cloudDuration,
              );

              // Push remote metadata to Native Notifications!
              _musicService.updateNotificationMetadata(dummySong);
              _updateTaskbar();

              // FETCH ARTWORK FOR LOCAL FILES: If PC is playing a local file, it won't send an art url.
              if (dummySong.onlineArtUrl == null ||
                  dummySong.onlineArtUrl!.isEmpty) {
                _fetchRemoteArtLazily(dummySong);
              }
            } else {
              // Same song, just sync progress/playback state
              state = state.copyWith(
                isPlaying: cloudPlaying,
                currentPosition:
                    isSeekLocked ? state.currentPosition : cloudPos,
                totalDuration: cloudDuration,
              );
            }

            // Queue Sync (Followers quietly inherit the Master's queue)
            if (value.containsKey('queue') && value['queue'] != null) {
              try {
                final queuePayload = value['queue'];
                final List<dynamic> rawQueue = queuePayload is String
                    ? jsonDecode(queuePayload) as List
                    : queuePayload as List;

                final List<SongModel> playNextItems =
                    []; // isCustom: true  → "Play Next"
                final List<SongModel> playlistItems =
                    []; // isCustom: false → regular queue

                for (final e in rawQueue) {
                  final eTitle = e['title'] ?? 'Unknown';
                  final eArtist = e['artist'] ?? 'Unknown';
                  final eAlbum = e['album'] as String? ?? 'Unknown';
                  final eDuration = (e['duration'] as num?)?.toDouble() ?? 0.0;
                  final isCustom = e['isCustom'] == true;

                  // FAST LOCAL MATCH: Prevent art placeholder flickers!
                  SongModel? localMatch;
                  try {
                    localMatch = state.playlist.firstWhere(
                        (s) => s.title == eTitle && s.artist == eArtist);
                  } catch (_) {}

                  SongModel song;
                  if (localMatch != null) {
                    // Found locally — clone it natively with rich metadata
                    song = localMatch.copyWith(
                      sourceUrl: e['sourceUrl'],
                      spotifyId: e['spotifyId'],
                    );
                  } else {
                    song = SongModel(
                      title: eTitle,
                      artist: eArtist,
                      album: eAlbum,
                      onlineArtUrl: e['albumArt'],
                      sourceUrl: e['sourceUrl'],
                      spotifyId: e['spotifyId'],
                      filePath: 'cloud_stream',
                      fileExtension: 'mp3',
                      duration: eDuration,
                    );

                    // MOBILE-SIDE ART FETCH: If no art URL, trigger lookup from mobile
                    if ((e['albumArt'] == null ||
                            (e['albumArt'] as String).isEmpty) &&
                        eArtist.isNotEmpty &&
                        eTitle.isNotEmpty) {
                      _fetchAndCacheArt(eArtist, eTitle);
                    }
                  }

                  if (isCustom) {
                    playNextItems.add(song);
                  } else {
                    playlistItems.add(song);
                  }
                }

                // If we are a follower, seamlessly mirror the master's queue
                if (!isMaster) {
                  final fullPlaylist = <SongModel>[];
                  if (state.currentSong != null) {
                    fullPlaylist.add(state.currentSong!);
                  }
                  fullPlaylist.addAll(playlistItems);
                  _playlistIndex = 0; // Current song is at index 0

                  state = state.copyWith(
                    userQueue: playNextItems,
                    playlist: fullPlaylist,
                  );
                }
              } catch (e) {
                DebugLogService().error("⚠️ Error parsing remote queue: $e");
              }
            }
          }

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
                if (isMaster) {
                  toggleShuffle();
                } else {
                  state = state.copyWith(isShuffle: target);
                }
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
              if (targetVal == 1) {
                targetMode = ja.LoopMode.all;
              } else if (targetVal == 2) {
                targetMode = ja.LoopMode.one;
              } else {
                targetMode = ja.LoopMode.off;
              }

              if (state.loopMode != targetMode) {
                DebugLogService()
                    .info("🔄 Remote Sync: Set Loop to $targetMode");
                if (isMaster) {
                  _musicService.setLoopMode(targetMode);
                  state = state.copyWith(loopMode: targetMode);
                  _saveSettings();
                  _broadcastRemoteState();
                } else {
                  state = state.copyWith(loopMode: targetMode);
                }
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

            debugPrint(
                "DEBUG: SearchAll Results: ${serialized['songs']?.length} songs, ${serialized['albums']?.length} albums");
            _remoteService.updateSearchResults(serialized);
          } catch (e) {
            debugPrint("❌ SearchAll Error: $e");
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
          debugPrint("☁️ Party Mode Error: Invalid song data - $e");
        }
        break;
      case 'get_album_details':
        debugPrint(
            "📥 Received 'get_album_details' command with value: $value");
        Map<String, dynamic>? payload;

        if (value is Map<String, dynamic>) {
          payload = value;
        } else if (value is String) {
          try {
            payload = jsonDecode(value);
          } catch (e) {
            debugPrint("❌ Error decoding payload: $e");
          }
        }

        if (payload != null) {
          final albumId = payload['id'];
          if (albumId != null) {
            try {
              debugPrint("💿 Fetching tracks for Album ID: $albumId");
              final tracks = await SpotifyService.getAlbumTracks(albumId);
              debugPrint("✅ Fetched ${tracks.length} tracks from Spotify.");

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

              debugPrint("📤 Broadcasting active_album_details...");
              _remoteService.broadcastState(albumDetails: {
                'id': albumId,
                'tracks': tracksJson,
              });
            } catch (e) {
              debugPrint("❌ Album Details Error: $e");
            }
          } else {
            debugPrint("⚠️ Album ID is null in payload.");
          }
        } else {
          debugPrint("⚠️ Payload could not be parsed.");
        }
        break;
    }
  }

  // CACHE FOR ALBUM ART URLs (from Spotify lookup)
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

  /// Fetch album art from Spotify/Deezer API and cache it
  Future<void> _fetchAndCacheArt(String artist, String title) async {
    final key = "$artist|$title".toLowerCase();

    // Already processing or cached
    if (_artUrlCache.containsKey(key)) return;

    // Mark as processing (empty string means "checked but no art")
    _artUrlCache[key] = '';

    try {
      String? artUrl = await SpotifyService.getTrackImage(title, artist);

      if (artUrl == null || artUrl.isEmpty) {
        artUrl = await DeezerService.getTrackImage(title, artist);
      }

      if (artUrl != null && artUrl.isNotEmpty) {
        _artUrlCache[key] = artUrl;

        // MASTER: Trigger a re-broadcast to send the now-cached art
        _broadcastRemoteState();

        // SLAVE: Update local state directly (broadcast is a no-op for followers)
        if (!isMaster) {
          // Update current song if it matches
          if (state.currentSong != null &&
              state.currentSong!.artist.toLowerCase() == artist.toLowerCase() &&
              state.currentSong!.title.toLowerCase() == title.toLowerCase() &&
              (state.currentSong!.onlineArtUrl == null ||
                  state.currentSong!.onlineArtUrl!.isEmpty)) {
            final updated = state.currentSong!.copyWith(onlineArtUrl: artUrl);
            state = state.copyWith(currentSong: updated);
            _musicService.updateNotificationMetadata(updated);
            _updateTaskbar();
          }

          // Update playlist items
          final updatedPlaylist = state.playlist.map((s) {
            if (s.artist.toLowerCase() == artist.toLowerCase() &&
                s.title.toLowerCase() == title.toLowerCase() &&
                (s.onlineArtUrl == null || s.onlineArtUrl!.isEmpty)) {
              return s.copyWith(onlineArtUrl: artUrl);
            }
            return s;
          }).toList();

          // Update userQueue items
          final updatedQueue = state.userQueue.map((s) {
            if (s.artist.toLowerCase() == artist.toLowerCase() &&
                s.title.toLowerCase() == title.toLowerCase() &&
                (s.onlineArtUrl == null || s.onlineArtUrl!.isEmpty)) {
              return s.copyWith(onlineArtUrl: artUrl);
            }
            return s;
          }).toList();

          state = state.copyWith(
              playlist: updatedPlaylist, userQueue: updatedQueue);
        }
      } else {
        DebugLogService().info("🎨 No art found for: $title - $artist");
      }
    } catch (e) {
      DebugLogService().info("⚠️ Failed to fetch art: $e");
    }
  }

  void _broadcastRemoteState({bool forceActive = false}) {
    if (!_isRemoteSessionActive) {
      return; // Don't broadcast when playing independently
    }
    if (!isMaster && !forceActive) {
      return; // Followers don't broadcast state unless claiming master
    }

    // Construct "Next Up" Queue (Limit 20)
    List<Map<String, dynamic>> queueData = [];
    int limit = 20;

    // 1. Priority: User Queue (Play Next)
    for (var song in state.userQueue) {
      if (queueData.length >= limit) break;
      // SMART ART FALLBACK: If local file has no onlineArtUrl, check the art cache
      final artUrl =
          song.onlineArtUrl ?? _getCachedArtUrl(song.artist, song.title);
      // LAZY ART FETCH: If we still have no art, trigger a background fetch
      if (artUrl == null && song.artist.isNotEmpty && song.title.isNotEmpty) {
        _fetchAndCacheArt(song.artist, song.title);
      }
      queueData.add({
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'albumArt': artUrl,
        'sourceUrl': song.sourceUrl,
        'spotifyId': song.spotifyId,
        'duration': song.duration,
        'isCustom': true,
      });
    }

    // 2. Priority: Playlist/Recommendation fallback
    if (queueData.length < limit) {
      final startIndex = _playlistIndex + 1;
      for (int i = startIndex; i < state.playlist.length; i++) {
        if (queueData.length >= limit) break;
        final song = state.playlist[i];
        // SMART ART FALLBACK: Check art cache for local files
        final artUrl =
            song.onlineArtUrl ?? _getCachedArtUrl(song.artist, song.title);
        if (artUrl == null && song.artist.isNotEmpty && song.title.isNotEmpty) {
          _fetchAndCacheArt(song.artist, song.title);
        }
        queueData.add({
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'albumArt': artUrl,
          'sourceUrl': song.sourceUrl,
          'spotifyId': song.spotifyId,
          'duration': song.duration,
          'isCustom': false,
        });
      }
    }

    // SMART ART for current song: ensure we send art even for local files
    String? currentArtUrl = state.currentSong?.onlineArtUrl;
    if ((currentArtUrl == null || currentArtUrl.isEmpty) &&
        state.currentSong != null) {
      currentArtUrl =
          _getCachedArtUrl(state.currentSong!.artist, state.currentSong!.title);
      if (currentArtUrl == null) {
        _fetchAndCacheArt(state.currentSong!.artist, state.currentSong!.title);
      }
    }

    _remoteService.broadcastState(
      title: state.currentSong?.title,
      artist: state.currentSong?.artist,
      album: state.currentSong?.album,
      isPlaying: state.isPlaying,
      volume: state.volume,
      isShuffle: state.isShuffle,
      loopMode: state.loopMode == ja.LoopMode.all
          ? 1
          : (state.loopMode == ja.LoopMode.one ? 2 : 0),
      positionSeconds: state.currentPosition, // HIGH PRECISION: Send raw Double
      durationSeconds: state.totalDuration, // HIGH PRECISION: Send raw Double
      artUrl: currentArtUrl,
      sourceUrl: state.currentSong?.sourceUrl,
      spotifyId: state.currentSong?.spotifyId,
      queue: queueData,
      forceActive: forceActive || isMaster,
    );
  }

  // CROSS DEVICE HANDOFF

  Future<void> switchToThisDevice() async {
    if (_localDeviceId == null) return;
    DebugLogService().info(
        "📲 Remote: Disconnecting from remote session → Independent mode...");

    // 1. DEACTIVATE REMOTE SESSION
    _isRemoteSessionActive = false;

    // 2. Set local state to independent master
    state = state.copyWith(
        activeDeviceId: _localDeviceId, activeDeviceName: _localDeviceName);

    // 3. Resolve Song & Resume
    final current = state.currentSong;
    final isRemoteSong = current != null &&
        (current.filePath == "remote" || current.filePath == "cloud_stream");

    if (isRemoteSong && _savedLocalSong != null) {
      // RESTORE SAVED LOCAL STATE: Go back to the song we were playing before connecting
      DebugLogService().info(
          "📲 Remote: Restoring saved local song: ${_savedLocalSong!.title}");
      state = state.copyWith(
        currentSong: _savedLocalSong,
        playlist: _savedLocalPlaylist ?? state.playlist,
        currentPosition: _savedLocalPosition,
        totalDuration: _savedLocalSong!.duration,
        isPlaying: false,
      );
      _playlistIndex = _savedLocalPlaylistIndex;
      _extractPalette(_savedLocalSong!);

      // Reload the song into the audio engine (paused)
      try {
        await _musicService.load(
          _savedLocalSong!,
          initialPosition: Duration(seconds: _savedLocalPosition.toInt()),
        );
      } catch (e) {
        DebugLogService().error("⚠️ Remote: Failed to reload saved song: $e");
      }

      // Clear saved state
      _savedLocalSong = null;
      _savedLocalPlaylist = null;
    } else if (current != null && !isRemoteSong) {
      // Local file exists, just resume at current position
      final ms = state.currentPosition.toInt() * 1000;
      await _musicService.seek(Duration(milliseconds: ms));
      if (Platform.isAndroid) await UsbAudioService.seek(ms);
      await _musicService.resume();
    } else if (_savedLocalSong != null) {
      // No current song at all but we have a saved one
      DebugLogService().info(
          "📲 Remote: No current song, restoring saved: ${_savedLocalSong!.title}");
      state = state.copyWith(
        currentSong: _savedLocalSong,
        playlist: _savedLocalPlaylist ?? [],
        currentPosition: _savedLocalPosition,
        totalDuration: _savedLocalSong!.duration,
        isPlaying: false,
      );
      _playlistIndex = _savedLocalPlaylistIndex;
      _extractPalette(_savedLocalSong!);
      try {
        await _musicService.load(
          _savedLocalSong!,
          initialPosition: Duration(seconds: _savedLocalPosition.toInt()),
        );
      } catch (e) {
        DebugLogService().error("⚠️ Remote: Failed to reload saved song: $e");
      }
      _savedLocalSong = null;
      _savedLocalPlaylist = null;
    }
  }

  /// Nominate a remote device to become the master player
  Future<void> switchToRemoteDevice(String deviceId, String deviceName) async {
    DebugLogService().info("📲 Remote: Switching playback to $deviceName...");

    // SAVE LOCAL STATE before entering remote session
    // This allows us to restore the last-played song when disconnecting
    if (state.currentSong != null &&
        state.currentSong!.filePath != "remote" &&
        state.currentSong!.filePath != "cloud_stream") {
      _savedLocalSong = state.currentSong;
      _savedLocalPlaylist = List<SongModel>.from(state.playlist);
      _savedLocalPlaylistIndex = _playlistIndex;
      _savedLocalPosition = state.currentPosition;
      DebugLogService().info(
          "📲 Remote: Saved local state: ${_savedLocalSong!.title} @ ${_savedLocalPosition.toInt()}s");
    }

    // ACTIVATE REMOTE SESSION — enables cross-device sync
    _isRemoteSessionActive = true;

    // 1. We become a follower IMMEDIATELY
    state =
        state.copyWith(activeDeviceId: deviceId, activeDeviceName: deviceName);

    // 2. Silence local engine securely
    await _musicService.pause();
    state = state.copyWith(isPlaying: false);

    // 3. Command the remote device to adopt master role
    await _remoteService.setActiveDevice(deviceId, deviceName);

    // 4. Send an explicit command so it replies with its current true state
    _remoteService.sendCommand('adopt_master', payload: deviceId);
  }

  // ignore: unused_element
  Future<void> _handleHandoffResume(SongModel remoteSong) async {
    DebugLogService().info("🔄 Remote: Resolving metadata for handoff...");

    // We try to find a playable local copy or stream for this device
    // Since we don't have a library search here, we use the sourceUrl (YouTube)
    if (remoteSong.sourceUrl != null || remoteSong.spotifyId != null) {
      // Re-initialize playback with the same song (Triggers JIT or local find)
      // Pass initial position so it resumes exactly where left off
      await playSong(remoteSong,
          initialPosition: Duration(seconds: state.currentPosition.toInt()));
    } else {
      DebugLogService().error(
          "❌ Remote: Cannot resume handoff - No source URL. Resetting player.");
      // PROPER RESET: Create a fresh PlayerState to truly clear currentSong.
      // copyWith(currentSong: null) doesn't work because Dart's ?? pattern
      // treats null as "not provided" and keeps the old value.
      state = PlayerState(
        volume: state.volume,
        unmutedVolume: state.unmutedVolume,
        isShuffle: state.isShuffle,
        loopMode: state.loopMode,
        endlessQueueEnabled: state.endlessQueueEnabled,
        activeDeviceId: _localDeviceId,
        activeDeviceName: _localDeviceName,
      );
    }
  }
  // ============== USB Audio Bypass (Android <14 Bit-Perfect) ==============

  /// Check if USB Audio bypass is currently active
  bool get isUsbAudioBypassActive =>
      _useUsbAudioBypass && _connectedUsbDac != null;

  /// Enable USB Audio bypass with a connected DAC
  Future<bool> enableUsbAudioBypass(UsbDacDevice dac) async {
    if (!Platform.isAndroid) return false;

    debugPrint(
        "🔊 Attempting to ENABLE USB Audio Bypass for: ${dac.deviceName}");
    final success = await UsbAudioService.openDac(dac);
    if (success) {
      _connectedUsbDac = dac;
      _useUsbAudioBypass = true;
      debugPrint("✅ USB Audio Bypass ENABLED: ${dac.deviceName}");
      return true;
    }
    debugPrint("❌ USB Audio Bypass FAILED to enable for: ${dac.deviceName}");
    return false;
  }

  /// Disable USB Audio bypass and return to normal playback
  Future<void> disableUsbAudioBypass() async {
    if (_useUsbAudioBypass) {
      debugPrint("🔇 Disabling USB Audio Bypass...");
      await UsbAudioService.closeDac();
      _connectedUsbDac = null;
      _useUsbAudioBypass = false;
      debugPrint("🔇 USB Audio Bypass DISABLED");
    }
  }

  /// Play a song through USB Audio (C++ engine → AudioTrack).
  /// Used for bit-perfect mode AND as ALAC fallback on Android < 12.
  Future<bool> _playViaUsbAudio(SongModel song,
      {bool isAlacFallback = false, Duration? initialPosition}) async {
    final settings = ref.read(settingsProvider);
    if (!settings.androidBitPerfect && !_useUsbAudioBypass && !isAlacFallback) {
      return false;
    }

    try {
      // For USB Audio, we need a local file path
      if (song.filePath == "cloud_stream" ||
          !await File(song.filePath).exists()) {
        debugPrint("⚠️ USB Audio: Cannot play cloud streams or missing files");
        return false;
      }

      // If we don't have a physical DAC, use built-in AudioTrack
      if (_connectedUsbDac == null &&
          (settings.androidBitPerfect || isAlacFallback)) {
        debugPrint(
            "⚠️ Routing to C++ Engine → Built-in AudioTrack (${isAlacFallback ? 'ALAC fallback' : 'bit-perfect'})...");
        await UsbAudioService.openBuiltInDac();
      }

      // Prepare the file for USB playback
      final prepared = await UsbAudioService.prepareFile(song.filePath);
      if (!prepared) {
        debugPrint("❌ USB Audio: Failed to prepare file");
        return false;
      }

      // Sync volume BEFORE playing/priming to prevent loud volume blasts
      final calculatedVol =
          _musicService.getCalculatedVolumeForSong(song, state.volume);
      await UsbAudioService.setVolume(calculatedVol);

      // Pre-seek the engine BEFORE starting playback to prevent UI flicker ("blinging")
      if (initialPosition != null && initialPosition.inMilliseconds > 0) {
        await UsbAudioService.seek(initialPosition.inMilliseconds);
      }

      // Start USB playback
      final success = await UsbAudioService.play();
      if (success) {
        _isCppEnginePrepared = true;

        // Ensure Android OS notification gets the ALAC track metadata
        await _musicService.updateNotificationMetadata(song);
        _lastNotificationSyncMs = 0; // Reset throttle for new track
        _musicService.syncCustomEngineState(
            isPlaying: true, position: initialPosition ?? Duration.zero);

        // CLAIM AUDIO FOCUS FOR C++ ENGINE
        // ExoPlayer abandons focus when paused. Playing audio in the background without Focus
        // causes Android to strictly throttle and freeze the C++ thread when minimized.
        if (Platform.isAndroid || Platform.isIOS) {
          final session = await AudioSession.instance;
          await session.setActive(true);
        }

        debugPrint("✅ USB Audio: Playing ${song.title}");
        state = state.copyWith(isPlaying: true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ USB Audio Error: $e");
      return false;
    }
  }

  /// Pause USB Audio playback
  Future<void> _pauseUsbAudio() async {
    if (_isUsingCppEngine() && _isCppEnginePrepared) {
      await UsbAudioService.pause();
      state = state.copyWith(isPlaying: false);
      _musicService.syncCustomEngineState(
          isPlaying: false,
          position:
              Duration(milliseconds: (state.currentPosition * 1000).toInt()));
    }
  }

  /// Resume USB Audio playback
  Future<void> _resumeUsbAudio() async {
    if (_isUsingCppEngine() && _isCppEnginePrepared) {
      // Re-claim Audio Focus when resuming
      if (Platform.isAndroid || Platform.isIOS) {
        final session = await AudioSession.instance;
        await session.setActive(true);
      }

      await UsbAudioService.resume();
      state = state.copyWith(isPlaying: true);
      _musicService.syncCustomEngineState(
          isPlaying: true,
          position:
              Duration(milliseconds: (state.currentPosition * 1000).toInt()));
    }
  }

  bool _isUsingCppEngine([SongModel? song]) {
    song ??= state.currentSong;
    if (song == null || !Platform.isAndroid) return false;
    final bool isLocalAlac = song.filePath != "cloud_stream" &&
        !song.filePath.startsWith('http') &&
        song.filePath.toLowerCase().endsWith('.m4a');
    return _useUsbAudioBypass ||
        ref.read(settingsProvider).androidBitPerfect ||
        isLocalAlac;
  }

  /// Stop USB Audio playback
  // ignore: unused_element
  Future<void> _stopUsbAudio() async {
    if (_useUsbAudioBypass) {
      await UsbAudioService.stop();
    }
  }

  //JIT STREAMING HELPER

  /// Resolves a Tidal Stream URL based on user quality settings.
  /// Returns null if no match found or error occurs.
  Future<String?> _getJitStreamUrl(SongModel song) async {
    try {
      // APPLE MUSIC FAST-PATH
      final isAppleMusic =
          song.sourceUrl != null && song.sourceUrl!.contains('music.apple.com');
      if (isAppleMusic) {
        debugPrint(
            "🍎 Apple Music JIT: Requesting sequential stream from VPS...");
        return await AppleMusicBackendService.requestDownload(
          song.sourceUrl!,
          title: song.title,
          artist: song.artist,
          onQueueUpdate: (pos) {
            if (pos > 0) {
              debugPrint("🍎 Apple Music Queue: Position $pos");
            }
          },
        );
      }

      // FEATURE GATE: YouTube sources never support lossless streaming
      final isYtSource =
          song.sourceUrl != null && song.sourceUrl!.contains('youtube');
      if (isYtSource) {
        debugPrint("▶️ YouTube source: Requesting instant JIT stream...");
        return await YoutubeDownloaderService().getStreamUrl(song.sourceUrl!);
      }

      debugPrint(
          "🔍 JIT Stream: Searching Tidal for '${song.title}' by '${song.artist}'");

      final flacService = FlacDownloaderService();
      String? tidalId;

      // 1. Try to resolve via Spotify ID using song.link (most accurate for complex/foreign titles)
      if (song.spotifyId != null && song.spotifyId!.isNotEmpty) {
        debugPrint("🔍 JIT Stream: Attempting to resolve Tidal ID via Spotify ID...");
        final urls = await flacService.getStreamingUrls(song.spotifyId!);
        if (urls != null && urls.tidalUrl != null) {
          final regex = RegExp(r'/track/(\d+)');
          final match = regex.firstMatch(urls.tidalUrl!);
          if (match != null) {
            tidalId = match.group(1);
            if (tidalId != null) {
              debugPrint("✅ JIT Stream: Resolved Tidal ID via Spotify ID: $tidalId");
            }
          }
        }
      }

      // 2. Fallback to direct search if song.link failed
      if (tidalId == null) {
        debugPrint(
            "🔍 JIT Stream: Searching Tidal for '${song.title}' by '${song.artist}'");
        tidalId =
            await flacService.getTidalTrackIdBySearch(song.title, song.artist);
      }

      if (tidalId != null) {
        final settings = ref.read(settingsProvider);
        String tidalQuality = 'HIGH';

        if (settings.streamingQuality == 'lossless') {
          tidalQuality = 'HI_RES_LOSSLESS';
        } else if (settings.streamingQuality == 'high' ||
            settings.streamingQuality == 'standard') {
          tidalQuality = 'HIGH';
        }

        final streamUrl =
            '${Env.tidalApiUrl}/stream?id=$tidalId&quality=$tidalQuality&key=${Env.tidalApiKey}';
        debugPrint(
            "🔗 JIT Stream URL resolved: $streamUrl (Quality: $tidalQuality)");
        return streamUrl;
      } else {
        debugPrint(
            "⚠️ JIT Stream: Tidal ID not found for '${song.title}' by '${song.artist}'");
        // FALLBACK: Try with simplified title (remove parentheses content)
        final cleanTitle =
            song.title.replaceAll(RegExp(r'\s*\(.*?\)\s*'), '').trim();
        if (cleanTitle != song.title && cleanTitle.isNotEmpty) {
          debugPrint(
              "🔍 JIT Stream: Retrying Tidal with clean title: '$cleanTitle'");
          final retryId = await flacService.getTidalTrackIdBySearch(
              cleanTitle, song.artist);
          if (retryId != null) {
            final settings = ref.read(settingsProvider);
            String tidalQuality = 'HIGH';
            if (settings.streamingQuality == 'lossless') {
              tidalQuality = 'HI_RES_LOSSLESS';
            } else if (settings.streamingQuality == 'high' ||
                settings.streamingQuality == 'standard') {
              tidalQuality = 'HIGH';
            }
            final streamUrl =
                '${Env.tidalApiUrl}/stream?id=$retryId&quality=$tidalQuality&key=${Env.tidalApiKey}';
            debugPrint(
                "🔗 JIT Stream URL resolved (retry): $streamUrl (Quality: $tidalQuality)");
            return streamUrl;
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ JIT Stream Resolution Failed: $e");
    }
    return null;
  }

  // REMOTE ART LAZY FETCH
  Future<void> _fetchRemoteArtLazily(SongModel dummySong) async {
    try {
      final imgUrl =
          await SpotifyService.getTrackImage(dummySong.title, dummySong.artist);
      if (imgUrl != null && imgUrl.isNotEmpty) {
        final updatedSong = dummySong.copyWith(onlineArtUrl: imgUrl);

        // Ensure the current song hasn't changed while we were fetching
        if (state.currentSong?.title == updatedSong.title) {
          state = state.copyWith(currentSong: updatedSong);
          // Push to Lockscreen
          _musicService.updateNotificationMetadata(updatedSong);
          _updateTaskbar();
          DebugLogService().info(
              "🖼️ Remote: Fetched missing art for local track: ${dummySong.title}");
        }
      }
    } catch (e) {
      DebugLogService().error("⚠️ Remote: Failed to lazily fetch art: $e");
    }
  }
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final musicService = NativeMusicService();
  return PlayerNotifier(musicService, ref);
});
