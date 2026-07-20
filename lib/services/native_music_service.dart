import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart'; // IMPORT
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'debug_log_service.dart';
import 'dart:isolate'; // IMPORT ISOLATE
import 'dart:ui'; // IMPORT UI for IsolateNameServer
import 'package:flutter/widgets.dart'; // For WidgetsBinding

import 'package:audio_service/audio_service.dart'; // IMPORT
import 'audio_handler.dart'; // IMPORT
import 'dart:math' as math; // ADDED FOR EQ VOLUME CALCULATION
import 'eq_engine.dart'; // ADDED FOR FREQUENCY ACCESS
import 'metadata_service.dart';
import 'package:metadata_god/metadata_god.dart' show Metadata;
import '../models/song_model.dart';
import 'flac_downloader_service.dart'; // IMPORT FOR VALIDATION
import 'package:rxdart/rxdart.dart'; // IMPORT RXDART FOR STREAM SWITCHING
import 'ffi_audio_player.dart'; // IMPORT FFI PLAYER
import 'package:shared_preferences/shared_preferences.dart'; // IMPORT PREFS
import 'cue_parser_service.dart'; // IMPORT CUE PATH SUPPORT
import 'package:just_audio_media_kit/just_audio_media_kit.dart'; // IMPORT JUST_AUDIO_MEDIA_KIT
import 'package:http/http.dart' as http; // IMPORT HTTP FOR SERVER GUARD

class NativeMusicService {
  // Singleton pattern - ensures same player instance everywhere
  static final NativeMusicService _instance = NativeMusicService._internal();
  factory NativeMusicService() => _instance;
  static int _instanceCount = 0;

  /// Callback invoked when a stream URL is expired/unreachable and needs
  /// to be re-resolved. Set by [PlayerNotifier] during initialization.
  ///
  /// Signature: (SongModel expiredSong) async -> void
  /// The callback should re-resolve the stream URL and call load() again.
  Future<void> Function(SongModel song)? onStreamExpired;

  // Formats supported by the C++ FFI engine (miniaudio + WMF backend).
  // Miniaudio natively handles: MP3, FLAC, WAV
  // WMF backend adds: M4A, AAC, WMA (Windows Media Foundation built-in decoders)
  // NOT supported: DSF, DFF (DSD formats) — these fall through to just_audio (libmpv).
  static const _ffiSupportedExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.m4a',
    '.alac',
    '.aac',
    '.wma',
    '.opus',
    '.ogg',
    '.aiff',
    '.aif'
  };

  /// Returns true if the file at [path] can be decoded by the C++ FFI engine.
  static bool isFfiSupported(String path) {
    final ext = path.toLowerCase();
    final dotIndex = ext.lastIndexOf('.');
    if (dotIndex < 0) return false;
    final extension = ext.substring(dotIndex);

    if (Platform.isAndroid) {
      // Android FFI engine device-sink (Engine_PlayFile) only supports formats
      // natively decoded by miniaudio. MediaCodec/ALAC fallback is only in the
      // raw-sink (USB DAC bypass) path.
      // So we exclude formats that require WMF or MediaCodec from normal FFI playback.
      const androidSupported = {
        '.mp3',
        '.flac',
        '.wav',
        '.aiff',
        '.aif',
      };
      return androidSupported.contains(extension);
    }

    return _ffiSupportedExtensions.contains(extension);
  }

  bool _isZombie = true; // Default to Zombie until we are RESUMED
  final ReceivePort _mutexPort = ReceivePort();
  final String _mutexName = 'simple_music_player_audio_mutex';
  bool _hasClaimedMutex = false;

  // Preload tracking to avoid redundant loads during crossfade
  String? _preloadedFilePath;
  SongModel? _preloadedSong;

  // CUE SHEET SUPPORT: Track start/end offsets for virtual CUE tracks.
  // When playing a CUE track, we monitor position and fire 'completed'
  // when the position reaches the end boundary of the track segment.
  // _cueStartOffset adjusts position/duration streams so the UI shows
  // relative time (0:00 = track start) instead of absolute file time.
  Timer? _cueEndMonitor;
  Duration? _cueStartOffset;
  Duration? _cueEndOffset;

  // Subject to track the active player for dynamic stream switching
  final BehaviorSubject<AudioPlayer> _activePlayerSubject =
      BehaviorSubject<AudioPlayer>();
  final BehaviorSubject<int> _activePlayerIndexSubject =
      BehaviorSubject<int>.seeded(1);

  // Loading guard to prevent race conditions
  bool _isLoading = false;
  bool get isLoading =>
      _isLoading; // Expose to prevent false positive crash detections
  Completer<void>? _loadingCompleter;
  int _playToken =
      0; // Track current play request to prevent finally block race conditions

  NativeMusicService._internal() {
    _instanceCount++;
    _activePlayerSubject
        .add(_player1); // Initialize subject with default player

    DebugLogService().info(
        "NativeMusicService Created. Count=$_instanceCount Hash=$hashCode PID=$pid Isolate=${Isolate.current.debugName} InitialState=ZOMBIE");

    // INITIALIZE AUDIO HANDLER (Mobile Only)
    _setupListeners(1);
    _setupListeners(2);

    if (Platform.isAndroid || Platform.isIOS) {
      _initAudioHandler();
    }

    // LIFECYCLE MUTEX: Only claim the throne when we are VISIBLE (Resumed)
    // This prevents background ghosts from stealing the audio focus.

    // 1. Register Observer
    final observer = _NativeLifecycleObserver(this);
    WidgetsBinding.instance.addObserver(observer);

    // 2. Check initial state (in case we are already resumed)
    // ON DESKTOP: We don't need to wait for resumed state. Claim immediately.
    if (Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _tryClaimMutex();
    }
  }

  void _tryClaimMutex() {
    if (_hasClaimedMutex) return; // Already King

    DebugLogService()
        .info("NativeMusicService: App READY. Claiming Mutex/Audio Throne...");

    // Kill existing holder
    final existingPort = IsolateNameServer.lookupPortByName(_mutexName);
    if (existingPort != null) {
      DebugLogService().info(
          "NativeMusicService: Found existing instance. Sending DIE command.");
      existingPort.send('DIE');
      IsolateNameServer.removePortNameMapping(_mutexName);
    }

    // Register my port
    IsolateNameServer.registerPortWithName(_mutexPort.sendPort, _mutexName);

    // Enable Audio
    _isZombie = false;
    _hasClaimedMutex = true;
    DebugLogService()
        .info("NativeMusicService: Mutex Claimed. I am the AUDIO MASTER.");

    // Listen for usurpation
    _mutexPort.listen((message) {
      if (message == 'DIE') {
        DebugLogService().error(
            "NativeMusicService: Received DIE command! I have been replaced.");
        _becomeZombie();
      }
    });

    _ensureSessionInitialized();
  }

  void _becomeZombie() {
    _isZombie = true;
    _hasClaimedMutex = false;

    DebugLogService().info(
        "NativeMusicService: Downgraded to ZOMBIE. Releasing hardware...");

    // RELEASE HARDWARE: When being usurped by a new instance, we MUST release WASAPI
    // so the new instance can actually play audio.
    _releaseHardwareGracefully().then((_) {
      DebugLogService().info("NativeMusicService: ZOMBIE cleanup complete.");
    });
  }

  /// Shared helper to release WASAPI and other native locks
  Future<void> _releaseHardwareGracefully() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool wasapiOn = prefs.getBool('wasapiExclusive') ?? false;

      for (var p in [_player1, _player2]) {
        try {
          await p.stop();
          if (wasapiOn) {
            await JustAudioMediaKit.setAudioFilter("");
            await p.setAudioSource(
              AudioSource.uri(Uri.parse(
                  "data:audio/wav;base64,UklGRiQAAABXQVZFRm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=")),
            );
          }
          // We don't necessarily dispose() here because we might become master again later (though unlikely in this app's architecture)
          // But for safety, stopping and clearing source is enough for WASAPI release.
        } catch (_) {}
      }

      if (wasapiOn) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (_) {}
  }

  /// 🛑 GRACEFUL SHUTDOWN: Dispose all native audio resources before process exit.
  /// Must be called BEFORE appWindow.close() to prevent heap corruption (0xc0000374).
  /// The FFI worker isolates have a 200ms polling timer calling native C functions —
  /// if the process tears down while those timers are still alive, they access freed
  /// memory and crash ntdll.dll.
  Future<void> shutdown() async {
    DebugLogService()
        .info("[Native] shutdown() — Disposing all audio resources...");
    _isZombie = true; // Block any new play/resume calls

    // 1. Cancel any active crossfade/CUE timers
    _fadeTimer?.cancel();
    _cueEndMonitor?.cancel();

    // 2. Stop and dispose FFI worker isolates (kills their polling timers)
    try {
      await _ffiPlayer1?.dispose();
    } catch (_) {}
    try {
      await _ffiPlayer2?.dispose();
    } catch (_) {}
    _ffiPlayer1 = null;
    _ffiPlayer2 = null;

    // 3. Stop and Release just_audio players (WASAPI Exclusive Fix)
    await _releaseHardwareGracefully();
    try {
      await _player1.dispose();
    } catch (_) {}
    try {
      await _player2.dispose();
    } catch (_) {}

    // 4. Close stream subjects
    try {
      await _activePlayerSubject.close();
      await _activePlayerIndexSubject.close();
    } catch (_) {}

    // 5. Release IsolateNameServer mutex
    IsolateNameServer.removePortNameMapping(_mutexName);
    _mutexPort.close();

    DebugLogService()
        .info("[Native] shutdown() — All audio resources disposed.");
  }

  final Completer<void> _sessionReady = Completer<void>();
  bool _sessionInitialized = false;

  Future<void> _ensureSessionInitialized() async {
    if (_sessionInitialized) return;
    _sessionInitialized = true;

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
      // Ensure proper Android attributes (ignored gracefully if MediaKit is active)
      try {
        await _player.setAndroidAudioAttributes(const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ));
      } catch (e) {
        debugPrint("⚠️ setAndroidAudioAttributes skipped: $e");
      }
      DebugLogService().info("NativeMusicService: Audio Session Configured");
    } catch (e) {
      DebugLogService().error("NativeMusicService: Session Init Error: $e");
    }
    if (!_sessionReady.isCompleted) _sessionReady.complete();
  }

  // Side-Car Handler
  MusicHandler? _audioHandler;
  MusicHandler? get audioHandler => _audioHandler;
  final Completer<void> _audioHandlerReady = Completer<void>();

  Future<void> _initAudioHandler() async {
    try {
      _audioHandler = await AudioService.init(
        builder: () =>
            MusicHandler(playbackEventStream), // Dynamic stream provider
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.simplemusicplayer.channel.audio',
          androidNotificationChannelName: 'Music Playback',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: true,
        ),
      );

      // ERROR & STATE LOGGING
      // Listeners moved to _setupListeners called in constructor for all platforms

      // Listeners moved to _setupListeners called in constructor for all platforms

      // Register pending callbacks if any
      if (_onNext != null) _audioHandler!.onSkipNext = _onNext;
      if (_onPrev != null) _audioHandler!.onSkipPrevious = _onPrev;
      if (_onPlay != null) _audioHandler!.onPlay = _onPlay;
      if (_onPause != null) _audioHandler!.onPause = _onPause;

      DebugLogService().info("NativeMusicService: AudioHandler Initialized");
      _audioHandlerReady.complete();
    } catch (e) {
      DebugLogService()
          .error("NativeMusicService: Failed to init AudioHandler: $e");
      _audioHandlerReady.complete(); // Complete anyway to unblock waiters
    }
  }

  // Callbacks
  VoidCallback? _onNext;
  VoidCallback? _onPrev;
  VoidCallback? _onPlay;
  VoidCallback? _onPause;

  void setNotificationCallbacks(
      {VoidCallback? onNext,
      VoidCallback? onPrev,
      VoidCallback? onPlay,
      VoidCallback? onPause}) {
    _onNext = onNext;
    _onPrev = onPrev;
    _onPlay = onPlay;
    _onPause = onPause;
    if (_audioHandler != null) {
      _audioHandler!.onSkipNext = onNext;
      _audioHandler!.onSkipPrevious = onPrev;
      _audioHandler!.onPlay = onPlay;
      _audioHandler!.onPause = onPause;
    }
  }

  /// Expose method to update notification natively without a load (Used by Remote Control Slave)
  Future<void> updateNotificationMetadata(SongModel song) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _updateAudioServiceMetadata(song);
    }
  }

  /// Pre-activate the custom engine flag to block ExoPlayer async events
  /// from leaking "paused" state to Android MediaSession. Must be called
  /// BEFORE pausing ExoPlayer when switching to the C++ engine.
  void preActivateCustomEngineState() {
    _audioHandler?.preActivateCustomEngine();
  }

  /// Syncs the play/pause state and position of a custom C++ engine to the Android notification
  void syncCustomEngineState({required bool isPlaying, required Duration position}) {
    _audioHandler?.setCustomState(isPlaying, position);
  }

// ... (skipping unchanged parts)

  Future<void> resume({Duration? lastKnownPosition}) async {
    if (_isZombie) return;
    _audioHandler?.clearCustomEngineState(); // Restore ExoPlayer notification control
    // FIX: Block resume while play() is in progress (e.g. FFI isolate init).
    // Without this, an external caller (taskbar, audio session, notification)
    // can trigger _player.play() on the just_audio shell which still holds
    // the OLD stream source, causing two engines to output audio simultaneously.
    if (_isLoading) {
      DebugLogService().info("[Native] resume() BLOCKED — play() in progress.");
      return;
    }
    DebugLogService()
        .info("[Native] resume() called. ActiveIndex=$_activePlayerIndex");

    if ((Platform.isWindows || Platform.isAndroid) &&
        (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
      // FFI path: play ONLY the FFI player, do NOT touch just_audio
      final player = _activePlayerIndex == 3 ? _ffiPlayer1 : _ffiPlayer2;
      player?.play();
      DebugLogService().info("[Native] resume() FFI play sent.");
    } else {
      // Standard path: just_audio
      final isOnline = _activeSong?.filePath.startsWith('http') ?? false;
      final pState = _player.processingState;
      final isDead = !_isLoading &&
          (pState == ProcessingState.completed ||
              pState == ProcessingState.idle);

      // CRASH RECOVERY / POSITION RESUME RECOVERY:
      // If the TCP connection died during pause, OR if player was preloaded at start 0
      // while lastKnownPosition is > 0, reload/seek to the correct offset.
      if (isOnline) {
        final enginePos = position;
        final currentPos = (enginePos == Duration.zero &&
                lastKnownPosition != null &&
                lastKnownPosition > Duration.zero)
            ? lastKnownPosition
            : enginePos;

        if (isDead) {
          DebugLogService().info(
              "[Native] Dead socket detected on resume (state=$pState). Reloading stream at ${currentPos.inSeconds}s (enginePos=${enginePos.inSeconds}s, lastKnown=${lastKnownPosition?.inSeconds}s)");
          seek(currentPos);
          return;
        } else if (enginePos < const Duration(seconds: 1) &&
            lastKnownPosition != null &&
            lastKnownPosition > const Duration(seconds: 1)) {
          DebugLogService().info(
              "[Native] Resume requested with position offset (${lastKnownPosition.inSeconds}s). Triggering seek.");
          seek(lastKnownPosition);
          return;
        }
      }

      _player.play().catchError((e) {
        DebugLogService().error("[Native] play() FAILED: $e");
      });
    }

    DebugLogService().info("[Native] resume() DONE.");
  }

  bool _isSeeking = false;
  bool get isSeeking => _isSeeking;

  // Crossfade guard: prevents crash detector from misinterpreting
  // stream load failures during crossfade as fatal player crashes.
  bool _isCrossfading = false;
  bool get isCrossfading => _isCrossfading;
  // NOTE: _androidStreamSeekOffset was removed. The old server-side ?start= seek
  // hack was broken for YouTube/Tidal streams. Seeking now uses proper
  // setAudioSource(initialPosition) fallback.

  AudioPlayer _player1 = AudioPlayer();
  AudioPlayer _player2 = AudioPlayer();
  FfiAudioPlayer? _ffiPlayer1; // Windows-only FFI Player 1
  FfiAudioPlayer? _ffiPlayer2; // Windows-only FFI Player 2
  int _activePlayerIndex = 1; // 1, 2, 3 (FFI 1), or 4 (FFI 2)
  int get activePlayerIndex =>
      _activePlayerIndex; // Expose for EQ engine routing
  Timer? _fadeTimer;
  double _currentVolume = 0.5; // TRACK CURRENT VOLUME
  double _eqPreampGain = 0.0; // TRACK EQ PREAMP
  List<double>? _currentEqGains; // TRACK CURRENT EQ BANDS
  double _maxEqGain = 0.0; // TRACK MAX BAND GAIN FOR HEADROOM
  double _currentReplayGain = 0.0; // ReplayGain offset in dB (Active)
  double _currentReplayGainNext = 0.0; // ReplayGain offset in dB (Preloaded)
  bool enableReplayGain = true; // Toggle for Automatic Gain Control

  // Per-FFI-player crossfade volume multipliers.
  // Range [0.0, 1.0]. Applied on top of master volume in _updateWindowsEngineVolume().
  // During normal playback both stay at 1.0 (no attenuation).
  // During crossfade the outgoing player fades 1→0 and the incoming fades 0→1.
  double _ffiPlayer1FadeMult = 1.0;
  double _ffiPlayer2FadeMult = 1.0;

  double get currentVolume => _currentVolume;

  AudioPlayer get _player =>
      (_activePlayerIndex == 1 || _activePlayerIndex == 3)
          ? _player1
          : _player2;
  AudioPlayer get _inactivePlayer =>
      (_activePlayerIndex == 1 || _activePlayerIndex == 3)
          ? _player2
          : _player1;
  SongModel? _activeSong; // Source of truth for current song metadata

  // Interface for external listeners - we still return the dominant AudioPlayer
  // but we may need to reconsider this if we fully replace just_audio on Windows.
  AudioPlayer get player => _player;

  Duration get position {
    Duration pos;
    if ((Platform.isWindows || Platform.isAndroid) &&
        (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
      final ffi = _activePlayerIndex == 3 ? _ffiPlayer1 : _ffiPlayer2;
      pos = ffi?.position ?? Duration.zero;
    } else {
      pos = _player.position;
    }

    if (_cueStartOffset != null) {
      final adjusted = pos - _cueStartOffset!;
      return adjusted.isNegative ? Duration.zero : adjusted;
    }
    return pos;
  }

  /// ABSOLUTE DURATION: Includes server-side stream offsets and CUE segment durations
  Duration? get duration {
    Duration? dur;
    if ((Platform.isWindows || Platform.isAndroid) &&
        (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
      final ffi = _activePlayerIndex == 3 ? _ffiPlayer1 : _ffiPlayer2;
      dur = ffi?.duration;
    } else {
      dur = _player.duration;
    }

    // FALLBACK TO METADATA: If engine hasn't loaded duration yet, use song duration
    if (dur == null || dur.inSeconds == 0) {
      if (_activeSong != null) {
        dur = Duration(seconds: _activeSong!.duration.toInt());
      }
    }

    if (dur != null) {
      // Duration is now reported correctly by ExoPlayer since we no longer
      // use the server-side ?start= hack that required manual offset math.
    }

    if (dur != null && _cueStartOffset != null) {
      if (_cueEndOffset != null) {
        return _cueEndOffset! - _cueStartOffset!;
      }
      final adjusted = dur - _cueStartOffset!;
      return adjusted.isNegative ? dur : adjusted;
    }
    return dur;
  }

  // DYNAMIC STREAMS For UI Synchronization during Crossfade
  Stream<Duration> get positionStream {
    return Rx.combineLatest2<AudioPlayer, int, Stream<Duration>>(
      _activePlayerSubject.stream,
      _activePlayerIndexSubject.stream,
      (p, index) => ((Platform.isWindows || Platform.isAndroid) && (index == 3 || index == 4))
          ? (index == 3
              ? (_ffiPlayer1?.positionStream ?? Stream.value(Duration.zero))
              : (_ffiPlayer2?.positionStream ?? Stream.value(Duration.zero)))
          : p.positionStream,
    ).switchMap((s) => s).map((pos) {

      // CUE SUPPORT: Adjust position relative to track start
      if (_cueStartOffset != null) {
        final adjusted = pos - _cueStartOffset!;
        return adjusted.isNegative ? Duration.zero : adjusted;
      }
      return pos;
    });
  }

  Stream<Duration?> get durationStream {
    return Rx.combineLatest2<AudioPlayer, int, Stream<Duration?>>(
      _activePlayerSubject.stream,
      _activePlayerIndexSubject.stream,
      (p, index) => ((Platform.isWindows || Platform.isAndroid) && (index == 3 || index == 4))
          ? (index == 3
              ? (_ffiPlayer1?.durationStream ?? Stream.value(null))
              : (_ffiPlayer2?.durationStream ?? Stream.value(null)))
          : p.durationStream,
    ).switchMap((s) => s).map((dur) {
      // FALLBACK TO METADATA: If engine hasn't loaded duration yet, use song duration
      if (dur == null || dur.inSeconds == 0) {
        if (_activeSong != null) {
          dur = Duration(seconds: _activeSong!.duration.toInt());
        }
      }

      if (dur == null) return null;

      // CUE SUPPORT: Override duration with track segment duration
      if (_cueStartOffset != null) {
        if (_cueEndOffset != null) {
          return _cueEndOffset! - _cueStartOffset!;
        }
        // Last track: duration = total file duration - start offset
        final cueAdjusted = dur - _cueStartOffset!;
        return cueAdjusted.isNegative ? dur : cueAdjusted;
      }
      return dur;
    });
  }

  Stream<PlayerState> get playerStateStream {
    return Rx.combineLatest2<AudioPlayer, int, Stream<PlayerState>>(
      _activePlayerSubject.stream,
      _activePlayerIndexSubject.stream,
      (p, index) => ((Platform.isWindows || Platform.isAndroid) && (index == 3 || index == 4))
          ? (index == 3
              ? (_ffiPlayer1?.playerStateStream ??
                  Stream.value(PlayerState(false, ProcessingState.idle)))
              : (_ffiPlayer2?.playerStateStream ??
                  Stream.value(PlayerState(false, ProcessingState.idle))))
          : p.playerStateStream,
    ).switchMap((s) => s);
  }

  Stream<PlaybackEvent> get playbackEventStream =>
      _activePlayerSubject.switchMap((p) => p.playbackEventStream);
  Stream<AudioPlayer> get activePlayerStream => _activePlayerSubject.stream;

  Future<void> load(SongModel song,
      {Duration? initialPosition, bool lazyLoad = false}) async {
    // ALLOW LOAD IN ZOMBIE STATE
    // We must allow the player to prepare the source even if we aren't the primary audio focus yet.
    // This allows the UI to show the correct duration and be ready to play on user input.
    /*
    if (_isZombie) {
      DebugLogService().info("[Native] load() BLOCKED (Zombie)");
      return;
    }
    */
    _cueEndMonitor?.cancel(); // Cancel any previous CUE end-offset monitor
    _cueStartOffset = null;
    _cueEndOffset = null;
    try {
      // CUE SHEET SUPPORT: Resolve virtual CUE paths before loading.
      // CUE paths encode the real audio file path + start/end offsets.
      String actualFilePath = song.filePath;
      if (CuePath.isCuePath(song.filePath)) {
        actualFilePath = CuePath.extractAudioPath(song.filePath);
        final cueStart = CuePath.extractStartOffset(song.filePath);
        _cueStartOffset = cueStart;
        _cueEndOffset = CuePath.extractEndOffset(song.filePath);
        // Override initialPosition with the CUE track's start offset
        initialPosition = cueStart;
        debugPrint(
            "🎵 CUE Track: ${song.title} → start=${cueStart.inMilliseconds}ms, end=${_cueEndOffset?.inMilliseconds ?? 'EOF'}ms");
        DebugLogService().info(
            "[Native] CUE Track resolved: ${song.title} startMs=${cueStart.inMilliseconds} endMs=${_cueEndOffset?.inMilliseconds}");
        // Create a modified song with the real audio path for the engine
        song = song.copyWith(filePath: actualFilePath);
      }
      // UPDATE METADATA (Mobile Only) - CALL BEFORE LOADING
      // This ensures title/artist updates BEFORE the player fires 'buffering' events.
      if (Platform.isAndroid || Platform.isIOS) {
        await _updateAudioServiceMetadata(song);
      }
      DebugLogService().info(
          "[Native] load() called. ServiceHash=$hashCode, PlayerHash=${_player.hashCode}");
      DebugLogService().info("[Native] load() called for: ${song.title}");
      _activeSong = song; // TRACK CURRENT SONG
      debugPrint("🎵 Service Pre-Loading: ${song.title}");
      final isHttp = song.filePath.startsWith('http://') ||
          song.filePath.startsWith('https://');
      final maskedPath =
          isHttp ? (Uri.parse(song.filePath).host) : song.filePath;
      debugPrint("🎵 File Path: $maskedPath");

      // RELOAD GUARD: Prevent re-initializing the same song unless offset changed
      final currentSource = _player.sequenceState?.currentSource;
      if (currentSource != null) {
        final currentTag = currentSource.tag as SongModel?;
        if (currentTag == song) {
          DebugLogService().info(
              "[Native] load() SKIPPED (Song already active) - Offset synced.");
          return;
        }
      }
      if (song.filePath == "cloud_stream") {
        debugPrint(
            "☁️ Pre-Resolving Cloud Stream: ${song.title} - ${song.artist}");

        try {
          final yt = YoutubeExplode();
          String? targetId;

          // PRIORITY: Use valid sourceUrl if available (passed from JIT fallback)
          if (song.sourceUrl != null &&
              song.sourceUrl!.isNotEmpty &&
              !song.sourceUrl!.startsWith('query:')) {
            final videoId = VideoId.parseVideoId(song.sourceUrl!);
            if (videoId != null) {
              targetId = videoId;
              debugPrint("✅ Using Source URL (Load): $targetId");
            }
          }

          if (targetId == null) {
            // Fallback to Search
            final query = "${song.title} ${song.artist} audio";
            final search = await yt.search.search(query);
            if (search.isNotEmpty) {
              targetId = search.first.id.value;
              debugPrint(
                  "✅ Found Video via Search (Load): ${search.first.title} ($targetId)");
            }
          }

          if (targetId != null) {
            final manifest =
                await yt.videos.streamsClient.getManifest(targetId);
            final audioInfo = manifest.audioOnly.withHighestBitrate();

            // Switch back to just_audio if we were on FFI
            if (!lazyLoad) await _switchToJustAudio();

            try {
              await _player.setAudioSource(
                _createAudioSource(audioInfo.url, song),
                initialPosition: initialPosition,
              );
              debugPrint("🎵 Pre-Load Cloud Stream Success");
            } catch (e) {
              debugPrint("⚠️ Pre-Load Interrupted/Failed: $e");
              debugPrint("Retrying with preload=false (Lazy Load)...");
              // Fallback: Lazy load. Sets the source but postpones buffering until play() is called.
              // This ensures the player is NOT empty/stuck.
              await _player.setAudioSource(
                _createAudioSource(audioInfo.url, song),
                initialPosition: initialPosition,
                preload: false,
              );
              debugPrint("✅ Lazy Load Source Set.");
            }
            yt.close();
            return;
          }
          yt.close();
        } catch (e) {
          debugPrint("❌ Cloud Stream Pre-Load Error: $e");
        }
        return;
      }

      debugPrint(
          "🎵 [Native] load() initialPosition: ${initialPosition?.inSeconds}s, isHttp=$isHttp");

      // Check if file exists (Skip for HTTP streaming URLs)
      if (isHttp) {
        // SERVER DOWN GUARD: Prevent native crash if streaming proxy is dead (HTTP 502/503)
        try {
          final checkUri = Uri.parse(song.filePath);
          if (checkUri.host.contains('stephanus-dev') ||
              checkUri.host.contains('tidal') ||
              checkUri.host.contains('squid')) {
            debugPrint("🛡️ Guard: Pinging stream server ${checkUri.host}...");
            // Request just 1 byte to check server status quickly without downloading the whole file
            final response = await http.get(checkUri, headers: {
              'Range': 'bytes=0-1'
            }).timeout(const Duration(seconds: 12));
            if (response.statusCode >= 500) {
              debugPrint(
                  "❌ Guard: Server returned ${response.statusCode}. Aborting playback to prevent native crash.");
              DebugLogService()
                  .error("Stream Server Error: HTTP ${response.statusCode}");
              // Trigger re-resolve via callback
              if (onStreamExpired != null) {
                DebugLogService()
                    .info("🔄 Triggering stream re-resolve for expired URL");
                onStreamExpired!(song);
              }
              return;
            }
          }
        } catch (e) {
          debugPrint("❌ Guard: Server unreachable: $e. Aborting playback.");
          DebugLogService().error("Stream Server Unreachable: $e");
          // Trigger re-resolve via callback
          if (onStreamExpired != null) {
            DebugLogService()
                .info("🔄 Triggering stream re-resolve for unreachable URL");
            onStreamExpired!(song);
          }
          return;
        }
      } else {
        final file = File(song.filePath);
        if (!await file.exists()) {
          debugPrint(
              "❌ Service Load Error: File does not exist at ${song.filePath}");
          return;
        }

        // FLAC INTEGRITY CHECK (Only for local files)
        if (song.filePath.toLowerCase().endsWith('.flac')) {
          if (!await FlacDownloaderService.isFlacFileValid(song.filePath)) {
            debugPrint(
                "❌ Service Load Error: Invalid FLAC file at ${song.filePath}");
            DebugLogService()
                .error("Invalid FLAC header detected: ${song.title}");
            return;
          }
        }
      }

      // Optimization: Determine target player for preloading
      final p = lazyLoad ? _inactivePlayer : _player;

      var uri = isHttp ? Uri.parse(song.filePath) : Uri.file(song.filePath);

      final String censoredUriStr = uri.toString().replaceAll(RegExp(r'(&|\?)key=[^&]*'), r'\1key=HIDDEN');
      debugPrint("🎵 [Native] final URI: $censoredUriStr");

      // Update preloaded tracking for crossfade consumption
      if (lazyLoad) {
        _preloadedFilePath = song.filePath;
        _preloadedSong = song;
      }

      final prefs = await SharedPreferences.getInstance();
      final bool isBitPerfect = prefs.getBool('wasapiExclusive') ?? false;
      final String? audioDeviceId = prefs.getString('audioDeviceId');

      // Windows: Local file - use FFI player EXCLUSIVELY
      // This prevents just_audio_media_kit from locking the file or crashing libmpv.
      // EXCEPTION: If Bit-Perfect (wasapiExclusive) is ON, we MUST route to just_audio (MPV),
      // because MPV natively supports WASAPI Event-Driven Mode hardware clock switching.
      if (Platform.isWindows &&
          !isHttp &&
          !isBitPerfect &&
          isFfiSupported(song.filePath)) {
        debugPrint(
            "Windows Local File: Using FFI engine (${lazyLoad ? 'Inactive' : 'Active'}).");

        bool usePlayer2;
        if (lazyLoad) {
          // For preloading, we always use the opposite of current
          usePlayer2 = (_activePlayerIndex == 1 || _activePlayerIndex == 3);
        } else {
          // For manual click, we FORCE toggle to ensure clean engine swap
          usePlayer2 = (_activePlayerIndex == 1 || _activePlayerIndex == 3);

          // CRITICAL: Stop the PREVIOUS FFI player and WAIT for it to stop
          if (_activePlayerIndex == 3) {
            if (isBitPerfect) {
              await _ffiPlayer1?.releaseDevice();
            } else {
              await _ffiPlayer1?.stop();
            }
            await Future.delayed(const Duration(
                milliseconds: 100)); // 🛰️ Grace period for hardware reset
          } else if (_activePlayerIndex == 4) {
            if (isBitPerfect) {
              await _ffiPlayer2?.releaseDevice();
            } else {
              await _ffiPlayer2?.stop();
            }
            await Future.delayed(const Duration(
                milliseconds: 100)); // 🛰️ Grace period for hardware reset
          }
        }

        if (_ffiPlayer1 == null) {
          _ffiPlayer1 = FfiAudioPlayer();
          _ffiPlayer1!
              .setVolume(0); // Start silent until _updateWindowsEngineVolume
          _applyCachedEqToPlayer(_ffiPlayer1!);
        }
        if (_ffiPlayer2 == null) {
          _ffiPlayer2 = FfiAudioPlayer();
          _ffiPlayer2!
              .setVolume(0); // Start silent until _updateWindowsEngineVolume
          _applyCachedEqToPlayer(_ffiPlayer2!);
        }

        final targetFFI = usePlayer2 ? _ffiPlayer2! : _ffiPlayer1!;

        // ENSURE the target engine is stopped before reuse (even if it wasn't the active one)
        if (isBitPerfect) {
          await targetFFI.setDevice(audioDeviceId);
          await targetFFI.releaseDevice();
        } else {
          await targetFFI.stop();
        }

        if (lazyLoad) {
          _currentReplayGainNext = song.replayGain ?? 0.0;
        } else {
          _currentReplayGain = song.replayGain ?? 0.0;
        }

        DebugLogService().info(
            "[Native] Loading FFI ${usePlayer2 ? '2' : '1'} (Lazy=$lazyLoad, BitPerfect=$isBitPerfect)");
        await targetFFI.setFilePath(song.filePath, bitPerfect: isBitPerfect);
        if (initialPosition != null) await targetFFI.seek(initialPosition);

        if (!lazyLoad) {
          _activePlayerIndex = usePlayer2 ? 4 : 3;
          _activePlayerIndexSubject.add(_activePlayerIndex);

          // Metadata/SMTC Wrapper switch
          _activePlayerSubject.add(usePlayer2 ? _player2 : _player1);

          _updateWindowsEngineVolume();
        }

        // Stop just_audio only if it was actually playing (and not in FFI mode already)
        if (_activePlayerIndex <= 2 && p.playing) await p.stop();

        debugPrint(
            "🎵 Pre-Load FFI Success (${lazyLoad ? 'Inactive' : 'Active'} Player)");
        return;
      }

      // STANDARD ROUTE: Use just_audio (Mobile or Windows Cloud)
      if (!lazyLoad) {
        await _switchToJustAudio();
      }

      DebugLogService().info("[Native] load() setting audio source URI: $censoredUriStr");
      await p.setAudioSource(
        _createAudioSource(uri, song),
        initialPosition: isHttp ? null : initialPosition,
        preload: true,
      );

      if (!isHttp && initialPosition != null && initialPosition > Duration.zero) {
        await p.seek(initialPosition);
      }

      // Re-apply EQ for non-FFI players (Android/Streaming)
      if (_currentEqGains != null) {
        EqEngine.apply(
          gains: _currentEqGains!,
          preampDb: _eqPreampGain,
          audioSessionId: p.androidAudioSessionId,
        );
      }

      debugPrint(
          "🎵 Pre-Load Success (${lazyLoad ? 'Inactive' : 'Active'} Player)");
    } catch (e, stackTrace) {
      debugPrint("❌ Service Load Error: $e");
      debugPrint("❌ Stack trace: $stackTrace");
    }
  }

  Future<void> _switchToJustAudio() async {
    if (_activePlayerIndex == 3 || _activePlayerIndex == 4) {
      final prefs = await SharedPreferences.getInstance();
      final bool isBitPerfect = prefs.getBool('wasapiExclusive') ?? false;

      DebugLogService().info(
          "[Native] Switching from FFI back to just_audio (BitPerfect=$isBitPerfect)");

      if (isBitPerfect) {
        await _ffiPlayer1?.releaseDevice();
        await _ffiPlayer2?.releaseDevice();
      } else {
        await _ffiPlayer1?.stop();
        await _ffiPlayer2?.stop();
      }

      _activePlayerIndex = 1;
      _activePlayerIndexSubject.add(1);
      _activePlayerSubject.add(_player1);

      // Restore just_audio volumes (they were set to 0 during FFI mode)
      try {
        await _player1.setVolume(_currentVolume);
        await _player2.setVolume(_currentVolume);
      } catch (e) {/* ignore disposal errors */}
    }
  }

  // Cache for extracted album art to avoid re-extracting every time
  final Map<String, Uri> _cachedArtUris = {};

  Future<void> _updateAudioServiceMetadata(SongModel song) async {
    // Wait for AudioHandler to be ready before setting metadata
    await _audioHandlerReady.future;

    if (_audioHandler == null) return;

    // === FALLBACK METADATA ===
    // Ensure notification always shows something meaningful
    final displayTitle =
        (song.title.isNotEmpty && song.title != "Unknown Title")
            ? song.title
            : _extractFilename(song.filePath);
    final displayArtist =
        (song.artist.isNotEmpty && song.artist != "Unknown Artist")
            ? song.artist
            : "Unknown Artist";
    final displayAlbum =
        (song.album.isNotEmpty && song.album != "Unknown Album")
            ? song.album
            : "Unknown Album";

    // === ARTWORK RESOLUTION ===
    Uri? artUri;

    // Priority 1: Online art URL (from Spotify/streaming sources)
    if (song.onlineArtUrl != null && song.onlineArtUrl!.isNotEmpty) {
      artUri = Uri.parse(song.onlineArtUrl!);
      debugPrint(
          "🎵 [Notification] Using online art URL: ${song.onlineArtUrl}");
    }
    // Priority 2: Embedded album art bytes already in memory
    else if (song.albumArtBytes != null && song.albumArtBytes!.isNotEmpty) {
      artUri = await _getOrCacheEmbeddedArt(song);
    }
    // Priority 3: Extract embedded art from audio file (for library/downloaded songs)
    else if (song.filePath != "cloud_stream") {
      artUri = await _extractArtFromFile(song.filePath);
    }
    // Priority 4: No art - Android will use app icon as fallback

    final item = MediaItem(
      id: song.filePath,
      album: displayAlbum,
      title: displayTitle,
      artist: displayArtist,
      duration: Duration(seconds: song.duration.toInt()),
      artUri: artUri,
    );

    _audioHandler!.mediaItem.add(item);
    debugPrint(
        "🎵 [Notification] Metadata updated: $displayTitle - $displayArtist (Art: ${artUri != null ? 'Yes' : 'App Icon'})");
  }

  /// Extract filename from path as fallback title
  String _extractFilename(String filePath) {
    if (filePath == "cloud_stream") return "Streaming...";
    try {
      final file = File(filePath);
      final name = file.uri.pathSegments.last;
      // Remove extension
      final dotIndex = name.lastIndexOf('.');
      return dotIndex > 0 ? name.substring(0, dotIndex) : name;
    } catch (e) {
      return "Unknown Title";
    }
  }

  /// Get cached art URI or extract embedded art to temp file
  Future<Uri?> _getOrCacheEmbeddedArt(SongModel song) async {
    // Use filePath as cache key
    final cacheKey = song.filePath;

    // Return cached URI if available
    if (_cachedArtUris.containsKey(cacheKey)) {
      final cachedUri = _cachedArtUris[cacheKey]!;
      // Verify file still exists
      if (await File(cachedUri.toFilePath()).exists()) {
        debugPrint("🎵 [Notification] Using cached embedded art");
        return cachedUri;
      } else {
        _cachedArtUris.remove(cacheKey);
      }
    }

    // Extract and save to temp file
    try {
      final tempDir = Directory.systemTemp;
      final artFileName = 'album_art_${song.filePath.hashCode}.jpg';
      final artFile = File('${tempDir.path}/$artFileName');

      await artFile.writeAsBytes(song.albumArtBytes!);
      final artUri = artFile.uri;

      // Cache for future use
      _cachedArtUris[cacheKey] = artUri;

      debugPrint(
          "🎵 [Notification] Extracted embedded art to: ${artFile.path}");
      return artUri;
    } catch (e) {
      debugPrint("⚠️ [Notification] Failed to extract embedded art: $e");
      return null;
    }
  }

  /// Extract album art directly from audio file (for library songs without preloaded bytes)
  Future<Uri?> _extractArtFromFile(String filePath) async {
    // Check cache first
    if (_cachedArtUris.containsKey(filePath)) {
      final cachedUri = _cachedArtUris[filePath]!;
      if (await File(cachedUri.toFilePath()).exists()) {
        debugPrint("🎵 [Notification] Using cached file art");
        return cachedUri;
      } else {
        _cachedArtUris.remove(filePath);
      }
    }

    // Try to extract from file
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint("⚠️ [Notification] File doesn't exist: $filePath");
        return null;
      }

      final Metadata metadata = await MetadataService().readMetadata(filePath);
      final artBytes = metadata.picture?.data;

      if (artBytes == null || artBytes.isEmpty) {
        debugPrint("🎵 [Notification] No embedded art in file: $filePath");
        return null;
      }

      // Save to temp file
      final tempDir = Directory.systemTemp;
      final artFileName = 'album_art_${filePath.hashCode}.jpg';
      final artFile = File('${tempDir.path}/$artFileName');

      await artFile.writeAsBytes(artBytes);
      final artUri = artFile.uri;

      // Cache for future use
      _cachedArtUris[filePath] = artUri;

      debugPrint(
          "🎵 [Notification] Extracted art from file to: ${artFile.path}");
      return artUri;
    } catch (e) {
      debugPrint("⚠️ [Notification] Failed to extract art from file: $e");
      return null;
    }
  }

  Future<bool> play(SongModel song,
      {double crossfadeDuration = 0.0, Duration? initialPosition}) async {
    final currentToken = ++_playToken;
    _audioHandler?.clearCustomEngineState(); // Restore ExoPlayer notification control
    _cueEndMonitor?.cancel(); // Cancel any previous CUE end-offset monitor
    _cueStartOffset = null;
    _cueEndOffset = null;

    // CUE SHEET SUPPORT: Resolve virtual CUE paths before playing.
    if (CuePath.isCuePath(song.filePath)) {
      final actualFilePath = CuePath.extractAudioPath(song.filePath);
      final cueStart = CuePath.extractStartOffset(song.filePath);
      _cueStartOffset = cueStart;
      _cueEndOffset = CuePath.extractEndOffset(song.filePath);
      initialPosition = cueStart;
      debugPrint(
          "🎵 CUE Play: ${song.title} → start=${cueStart.inMilliseconds}ms, end=${_cueEndOffset?.inMilliseconds ?? 'EOF'}ms");
      song = song.copyWith(filePath: actualFilePath);
    }

    // FIX: Mark as loading IMMEDIATELY so the crash guard (_isLoading check)
    // sees this flag during the entire play() call, including the stop() → setAudioSource() gap.
    // Previously _isLoading was set AFTER stop(), leaving a window where idle+true
    // could slip past the guard and falsely trigger crash recovery → song skip.
    _isLoading = true;
    _loadingCompleter = Completer<void>();

    if (_isZombie) {
      DebugLogService().info(
          "[Native] play() called in Zombie state. Attempting to claim Mutex...");
      _tryClaimMutex();
      if (_isZombie) {
        DebugLogService()
            .info("[Native] play() BLOCKED (Zombie) - Claim failed");
        _isLoading = false;
        _loadingCompleter?.complete();
        _loadingCompleter = null;
        return false;
      }
    }

    // CROSSFADE LOGIC
    // If crossfade fails/unsupported (e.g. local-after-stream, cloud), fall through to normal play
    {
      // FIX: On Windows FFI the just_audio shell player is never playing;
      // we must check the actual C++ engine's playing state instead.
      final bool isCurrentlyPlaying;
      if ((Platform.isWindows || Platform.isAndroid) &&
          (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
        final activeFFI = _activePlayerIndex == 3 ? _ffiPlayer1 : _ffiPlayer2;
        isCurrentlyPlaying = activeFFI?.playing ?? false;
      } else {
        isCurrentlyPlaying = _player.playing;
      }

      if (crossfadeDuration > 0.1 && isCurrentlyPlaying) {
        final crossfadeOk = await _startCrossfade(song, crossfadeDuration);
        if (crossfadeOk) {
          // Crossfade manages its own loading state
          if (_playToken == currentToken) {
            _isLoading = false;
            _loadingCompleter?.complete();
            _loadingCompleter = null;
          }
          return true;
        }
        // Fall through to normal play — this will stop the stream and load via FFI
        DebugLogService().info(
            "[Native] Crossfade declined, falling through to normal play");
      }
    }

    // Normal play logic (stops current player)
    _fadeTimer?.cancel();
    _fadeTimer = null; // Clear timer reference
    try {
      _player.setVolume(
          _currentVolume); // FIX: Use tracked volume instead of hardcoded 1.0
      _inactivePlayer
          .stop(); // Stop the inactive player to prepare it for next use
    } catch (e) {
      DebugLogService().error("Error during normal play setup: $e");
    }

    // Loading Guard: Wait for any pending load to finish, then cancel it
    if (_loadingCompleter != null && _playToken != currentToken) {
      DebugLogService()
          .info("[Native] play() Waiting for previous load to finish...");
      // Stop previous load by stopping player
      await _player.stop();
      // _isLoading and _loadingCompleter already set above
    }

    try {
      DebugLogService().info(
          "[Native] Switching stream context: Service=$hashCode Engine=${_player.hashCode}");
      DebugLogService().info("[Native] play() called for: ${song.title}");
      _activeSong = song; // TRACK CURRENT SONG
      final isHttp = song.filePath.startsWith('http://') ||
          song.filePath.startsWith('https://');
      debugPrint("🎵 Service Loading: ${song.title}");
      final maskedPath =
          isHttp ? (Uri.parse(song.filePath).host) : song.filePath;
      debugPrint("🎵 File Path: $maskedPath");

      // initialPosition is now passed directly to setAudioSource
      // instead of using the broken server-side ?start= hack.

      // UPDATE METADATA (Mobile Only) - Also update on play(), not just load()
      if (Platform.isAndroid || Platform.isIOS) {
        await _updateAudioServiceMetadata(song);
      }

      // STOP previous playback immediately (Fixes Ghost Song)
      // FIX: Removed redundant stop() which caused buffer resets on Android.

      // 1. Check if file exists first
      // 1. CLOUD STREAM HANDLING (Party Mode)
      if (song.filePath == "cloud_stream") {
        debugPrint("☁️ Resolving Cloud Stream: ${song.title} - ${song.artist}");

        try {
          final yt = YoutubeExplode();
          // Sanitize query to remove newlines or weird chars
          final cleanTitle = song.title.replaceAll(RegExp(r'[\n\r]'), ' ');
          final cleanArtist = song.artist.replaceAll(RegExp(r'[\n\r]'), ' ');
          final query = "$cleanTitle $cleanArtist audio";

          final search = await yt.search.search(query);

          if (search.isNotEmpty) {
            final video = search.first;
            debugPrint("✅ Found Video: ${video.title} (${video.id})");

            final manifest =
                await yt.videos.streamsClient.getManifest(video.id);
            final audioInfo = manifest.audioOnly.withHighestBitrate();

            debugPrint("🎵 Stream URL: ${audioInfo.url}");

            // await _player.stop(); // FIX: Same as below, removed for smoothness.
            await _player.setAudioSource(
              _createAudioSource(audioInfo.url, song),
            );
            // NON-BLOCKING
            _player.play();
            yt.close();
            return true; // EXIT after starting stream
          } else {
            debugPrint("❌ No video found for cloud stream");
          }
          yt.close();
        } catch (e) {
          debugPrint("❌ Cloud Stream Error: $e");
          // Clear source so we don't hold onto the previous song
          try {
            await _player
                .setAudioSource(ConcatenatingAudioSource(children: []));
          } catch (_) {}
          return false;
        }
        return false; // Abort if cloud stream fails
      }

      // 2. HTTP OR FILE HANDLING (Original)
      if (!isHttp) {
        final file = File(song.filePath);
        final exists = await file.exists();
        debugPrint("🎵 File exists: $exists");

        if (!exists) {
          debugPrint(
              "❌ Service Error: File does not exist at ${song.filePath}");
          // Try to list parent directory to debug
          try {
            final parent = file.parent;
            if (await parent.exists()) {
              debugPrint("📂 Parent directory exists: ${parent.path}");
              final files = await parent.list().toList();
              debugPrint(
                  "📂 Files in directory: ${files.map((f) => f.path.split('/').last).toList()}");
            } else {
              debugPrint("❌ Parent directory does not exist: ${parent.path}");
            }
          } catch (e) {
            debugPrint("❌ Error listing parent: $e");
          }
          return false;
        }

        final fileSize = await file.length();
        debugPrint("🎵 File size: $fileSize bytes");
      }

      // 2. Stop previous playback explicitly to clear buffers
      // await _player.stop(); // FIX: Removed redundant stop() to prioritize seamless transitions and prevent UI blink.

      var uri = isHttp ? Uri.parse(song.filePath) : Uri.file(song.filePath);

      // initialPosition is now passed directly to setAudioSource
      // instead of using the broken server-side ?start= hack.

      final prefs = await SharedPreferences.getInstance();
      final bool isBitPerfect = prefs.getBool('wasapiExclusive') ?? false;

      // Windows FFI: Load + Play directly (no redirect to load())
      // EXCEPTION: Bit-Perfect mode bypasses FFI and routes to MPV (just_audio)
      // for strictly exact WASAPI Event-Driven hardware clock switching.
      if ((Platform.isWindows || Platform.isAndroid) &&
          !isHttp &&
          !isBitPerfect &&
          isFfiSupported(song.filePath)) {
        debugPrint("Windows Local File (play): Using FFI engine directly.");

        // Stop previous player (FFI or just_audio)
        // In bit-perfect: releaseDevice() to fully uninit WASAPI exclusive session.
        // Just stop() leaves the WASAPI session alive, blocking the new engine.

        try {
          if (_activePlayerIndex == 3) {
            if (isBitPerfect) {
              await _ffiPlayer1?.releaseDevice();
            } else {
              await _ffiPlayer1?.stop();
            }
          } else if (_activePlayerIndex == 4) {
            if (isBitPerfect) {
              await _ffiPlayer2?.releaseDevice();
            } else {
              await _ffiPlayer2?.stop();
            }
          } else {
            // FIX: Stop just_audio players when switching from stream to local FFI
            // Without this, the stream continues playing alongside the FFI song.
            await _player1.stop();
            await _player2.stop();
          }
        } catch (e) {
          debugPrint("⚠️ Stop (prev) error (safe to ignore): $e");
        }

        // 🛰️ Grace period for WASAPI hardware reset in exclusive mode
        if (isBitPerfect) {
          await Future.delayed(const Duration(milliseconds: 150));
        }

        // Toggle to the other engine
        final bool usePlayer2 =
            (_activePlayerIndex == 1 || _activePlayerIndex == 3);

        if (_ffiPlayer1 == null) {
          _ffiPlayer1 = FfiAudioPlayer();
          _ffiPlayer1!.setVolume(0);
          _applyCachedEqToPlayer(_ffiPlayer1!);
        }
        if (_ffiPlayer2 == null) {
          _ffiPlayer2 = FfiAudioPlayer();
          _ffiPlayer2!.setVolume(0);
          _applyCachedEqToPlayer(_ffiPlayer2!);
        }

        final targetFFI = usePlayer2 ? _ffiPlayer2! : _ffiPlayer1!;

        // Ensure target is clean (wrapped for safety)
        try {
          if (isBitPerfect) {
            await targetFFI.releaseDevice();
          } else {
            await targetFFI.stop();
          }
        } catch (e) {/* fresh handle, ok */}

        _currentReplayGain = song.replayGain ?? 0.0;

        debugPrint("FFI: Loading file: ${song.filePath}");
        await targetFFI.setFilePath(song.filePath, bitPerfect: isBitPerfect);
        if (initialPosition != null) await targetFFI.seek(initialPosition);

        _activePlayerIndex = usePlayer2 ? 4 : 3;
        _activePlayerIndexSubject.add(_activePlayerIndex);
        _activePlayerSubject.add(usePlayer2 ? _player2 : _player1);
        _updateWindowsEngineVolume();

        // ACTUALLY START PLAYBACK
        targetFFI.play();
        debugPrint("🎵 FFI Play command sent for: ${song.title}");
        _startCueEndMonitor(); // CUE: Start end-offset monitor if applicable
        return true;
      }

      // STANDARD ROUTE: just_audio (streams / mobile)
      debugPrint("🎵 Playing URI: $uri");

      // Switch back from FFI if needed
      await _switchToJustAudio();

      // Bit-Perfect Cleanup: In exclusive mode, only one instance can own the hardware.
      // We MUST stop the inactive player to release its WASAPI session before loading the next.
      if (Platform.isWindows && isBitPerfect) {
        debugPrint(
            "[Bit-Perfect] Stopping inactive player to release hardware...");
        await _inactivePlayer.stop();
        await Future.delayed(
            const Duration(milliseconds: 100)); // Hardware reset grace period
      }

      if (initialPosition != null) _isSeeking = true;
      try {
        final String censoredUriStr = uri.toString().replaceAll(RegExp(r'(&|\?)key=[^&]*'), r'\1key=HIDDEN');
        DebugLogService().info("[Native] play() setting audio source URI: $censoredUriStr");
        await _player.setAudioSource(
          _createAudioSource(uri, song),
          initialPosition: initialPosition,
        );
        if (initialPosition != null && initialPosition > Duration.zero) {
          await _player.seek(initialPosition);
        }
      } finally {
        _isSeeking = false;
      }
      debugPrint("🎵 Audio source set successfully");

      // 4. Sync volume and play
      await _player.setVolume(_currentVolume);
      _player.play();
      debugPrint("🎵 Play command sent");
      _startCueEndMonitor(); // CUE: Start end-offset monitor if applicable

      // NATIVE SEEKING HANDLED BY SERVER-SIDE ?start= PARAMETER
      // We no longer need the client-side seek retry logic here because
      // the server ensures the stream data starts exactly at the requested point.

      return true;
    } catch (e, stackTrace) {
      debugPrint("❌ Service Error: $e");
      debugPrint("❌ Stack trace: $stackTrace");
      return false;
    } finally {
      // Reset loading guard only if we are the latest request
      if (_playToken == currentToken) {
        _isLoading = false;
        _loadingCompleter?.complete();
        _loadingCompleter = null;
      }
    }
  }

  Future<void> pause() async {
    if (_isZombie) return;
    _cueEndMonitor?.cancel(); // CUE: Pause the end-offset monitor
    if ((Platform.isWindows || Platform.isAndroid) &&
        (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
      final player = _activePlayerIndex == 3 ? _ffiPlayer1 : _ffiPlayer2;
      await player?.pause();
      DebugLogService().info("[Native] pause() FFI");
      return; // Do NOT touch just_audio when FFI is active
    }
    await _player.pause();
    DebugLogService().info("[Native] pause() called");
  }

  Future<void> stop() async {
    _cueEndMonitor?.cancel(); // CUE: Cancel the end-offset monitor
    _cueStartOffset = null;
    _cueEndOffset = null;
    if ((Platform.isWindows || Platform.isAndroid) &&
        (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
      final player = _activePlayerIndex == 3 ? _ffiPlayer1 : _ffiPlayer2;
      await player?.stop();
      DebugLogService().info("[Native] stop() FFI");
      return; // Do NOT touch just_audio when FFI is active
    }
    await _player.stop();
    DebugLogService().info("[Native] stop() called");
  }

  /// CUE SHEET SUPPORT: Starts a periodic timer that monitors playback position
  /// and triggers a 'completed' state when the position reaches the CUE track's
  /// end boundary. This allows each CUE track to auto-advance to the next track.
  void _startCueEndMonitor() {
    if (_cueEndOffset == null) {
      return; // Not a CUE track, or last track (plays to EOF)
    }

    final endMs = _cueEndOffset!.inMilliseconds;
    DebugLogService().info(
        "[Native] CUE End Monitor started. Will trigger completed at ${endMs}ms");

    _cueEndMonitor = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      // Get the ABSOLUTE position (before CUE offset adjustment)
      Duration absolutePos;
      if ((Platform.isWindows || Platform.isAndroid) &&
          (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
        final ffi = _activePlayerIndex == 3 ? _ffiPlayer1 : _ffiPlayer2;
        absolutePos = ffi?.position ?? Duration.zero;
      } else {
        absolutePos = _player.position;
      }

      if (absolutePos.inMilliseconds >= endMs) {
        DebugLogService().info(
            "[Native] CUE End Monitor: Track boundary reached at ${absolutePos.inMilliseconds}ms (target: ${endMs}ms). Triggering completed.");
        timer.cancel();
        _cueEndMonitor = null;

        // Stop playback and signal completion to the player state stream
        if ((Platform.isWindows || Platform.isAndroid) &&
            (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
          final ffi = _activePlayerIndex == 3 ? _ffiPlayer1 : _ffiPlayer2;
          ffi?.pause();
          // Emit completed state through the FFI player's state subject
          // The FFI player monitors is_completed via polling, but we override here
          ffi?.stop();
        } else {
          _player.pause();
          _player.stop();
        }
      }
    });
  }

  Future<void> seek(Duration position) async {
    if (_isZombie) return;

    // CUE SUPPORT: Translate relative seek position to absolute file position
    if (_cueStartOffset != null) {
      position = position + _cueStartOffset!;
      DebugLogService().info(
          "[Native] CUE Seek: relative=${(position - _cueStartOffset!).inMilliseconds}ms → absolute=${position.inMilliseconds}ms");
    }

    DebugLogService()
        .info("[Native] Executing SEEK to ${position.inMilliseconds}ms");

    if ((Platform.isWindows || Platform.isAndroid) &&
        (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
      final player = _activePlayerIndex == 3 ? _ffiPlayer1 : _ffiPlayer2;
      DebugLogService().info(
          "[Native] Seek: Using Windows FFI Player ${_activePlayerIndex == 3 ? '1' : '2'}");
      // FFI is always local/cached, so it handles absolute position directly
      await player?.seek(position);
      return;
    }

    final currentSource = _player.sequenceState?.currentSource;
    final currentSong = currentSource?.tag as SongModel?;
    final isUrl = currentSong?.filePath.startsWith('http') ?? false;

    DebugLogService()
        .info("[Native] Seek: Executing Native Seek (MediaKit/JustAudio)");
    _isSeeking = true;
    try {
      if (currentSong != null &&
          !_isLoading &&
          (_player.processingState == ProcessingState.completed ||
              _player.processingState == ProcessingState.idle)) {
        // Player has finished or is idle — a simple seek won't work.
        // We must reload the audio source at the desired position.
        DebugLogService().info(
            "[Native] Seek: Player is completed/idle. Reloading source at ${position.inSeconds}s");
        final uri = isUrl
            ? Uri.parse(currentSong.filePath)
            : Uri.file(currentSong.filePath);

        await _player.setAudioSource(
          _createAudioSource(uri, currentSong),
          initialPosition: isUrl ? null : position,
        );
        _player.play();
      } else {
        // Normal seek — ExoPlayer handles HTTP Range requests natively.
        await _player.seek(position);
      }
    } catch (e) {
      DebugLogService().error("[Native] Seek Error: $e");

      // ROBUST FALLBACK: If native seek fails (cold cache, missing FLAC seek table,
      // or expired stream URL), reload the original audio source with initialPosition.
      // This forces ExoPlayer to re-initialize and jump directly to the requested offset.
      if (currentSong != null && !_isLoading) {
        // Avoid reload loop if already buffering at this position
        if (_player.processingState == ProcessingState.buffering) {
          DebugLogService().info(
              "[Native] Seek: Already buffering, skipping reload");
          return;
        }
        DebugLogService().info(
            "[Native] Seek: Fallback — Reloading source at ${position.inSeconds}s");
        try {
          final uri = isUrl
              ? Uri.parse(currentSong.filePath)
              : Uri.file(currentSong.filePath);

          await _player.setAudioSource(
            _createAudioSource(uri, currentSong),
            initialPosition: isUrl ? null : position,
          );
          _player.play();
        } catch (e2) {
          DebugLogService().error("[Native] Seek Reload Error: $e2");
        }
      }
    } finally {
      _isSeeking = false;
    }
  }

  Future<void> setVolume(double volume) async {
    _currentVolume = volume;

    if ((Platform.isWindows || Platform.isAndroid) &&
        (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
      _updateWindowsEngineVolume();
      // Don't zero just_audio — keep it at correct volume for smooth stream transitions
    }

    // Always sync just_audio players so they're ready when switching back from FFI
    if (_fadeTimer == null || !_fadeTimer!.isActive) {
      try {
        await _player1.setVolume(volume);
        await _player2.setVolume(volume);
      } catch (e) {
        // Silently ignore disposal errors
      }
    }
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await _player1.setLoopMode(mode);
    await _player2.setLoopMode(mode);
  }

  void _setupListeners(int index) {
    final p = index == 1 ? _player1 : _player2;
    p.playbackEventStream.listen((event) {}, onError: (e, s) {
      DebugLogService()
          .error("NativeMusicService: Playback Event Error (P$index): $e");
    });

    p.playerStateStream.listen((state) {
      if (_activePlayerIndex == index) {
        DebugLogService().info(
            "NativeMusicService: Player$index State [${state.processingState}, ${state.playing}]");
      }
    });

    p.processingStateStream.listen((processingState) {
      if (processingState == ProcessingState.completed) {
        // Auto-next logic is usually handled by PlayerNotifier,
        // but just_audio needs to be in a consistent state.
      }
    });
  }

  void recreateActivePlayer() {
    final idx = _activePlayerIndex;
    DebugLogService().info(
        "NativeMusicService: Recreating active player $idx due to fatal error.");
    try {
      if (idx == 1) {
        _player1.dispose().catchError((e) => null);
        _player1 = AudioPlayer();
        _setupListeners(1);
        _player1.setVolume(_currentVolume);
        _activePlayerSubject.add(_player1);
      } else {
        _player2.dispose().catchError((e) => null);
        _player2 = AudioPlayer();
        _setupListeners(2);
        _player2.setVolume(_currentVolume);
        _activePlayerSubject.add(_player2);
      }
    } catch (e) {
      DebugLogService().error("NativeMusicService: Recreate failed: $e");
    }
  }

  /// Cancels an in-progress crossfade, clearing the fade timer and resetting state.
  /// Called by player_provider when the incoming stream fails during crossfade.
  void cancelCrossfade() {
    if (!_isCrossfading) return;
    DebugLogService()
        .info("[Native] cancelCrossfade() — aborting active crossfade");
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _isCrossfading = false;

    // Reset fade multipliers so the next play() gets full volume
    _ffiPlayer1FadeMult = 1.0;
    _ffiPlayer2FadeMult = 1.0;

    // Stop both just_audio players to clear any half-loaded source
    try {
      _player1.stop();
      _player2.stop();
    } catch (e) {/* safe to ignore */}

    if (Platform.isWindows || Platform.isAndroid) {
      _updateWindowsEngineVolume();
    }
  }

  Future<bool> _startCrossfade(SongModel song, double duration) async {
    // FIX: Crossfade and WASAPI exclusive mode are fundamentally incompatible.
    // Two exclusive sessions cannot coexist — the second engine silently falls
    // back to shared mode, causing the DAC to receive resampled audio (e.g. 44.1 kHz).
    if (Platform.isWindows) {
      final prefs = await SharedPreferences.getInstance();
      final isBitPerfect = prefs.getBool('wasapiExclusive') ?? false;
      if (isBitPerfect) {
        DebugLogService().info(
            "[Native] Crossfade auto-disabled in Bit-Perfect mode — using gapless transition");
        return false;
      }
    }

    // RE-ENTRY GUARD: Ensure previous crossfade is fully cleared
    if (_fadeTimer != null) {
      DebugLogService().info(
          "[Native] Overlapping crossfade detected — hard cancelling previous.");
      _fadeTimer?.cancel();
      _fadeTimer = null;
    }

    final outPlayer = _player;
    final inPlayer = _inactivePlayer;

    _isCrossfading =
        true; // Guard: suppress crash-detector skip during crossfade
    DebugLogService().info("[Native] Starting Crossfade: ${duration}s");

    try {
      // Optimize: Don't await non-critical setup calls to start fade faster
      inPlayer.stop();
      inPlayer.setVolume(0.0);
      outPlayer.setVolume(_currentVolume);

      // Load source (Only if not already preloaded)
      if (song.filePath == "cloud_stream") {
        // Resolve online stream (simplified: reuse existing logic if possible, or skip crossfade for cloud for now)
        // For now, let's just return false to fallback to normal play if it's cloud
        DebugLogService()
            .info("[Native] Crossfade not supported for cloud streams yet.");
        _isCrossfading = false;
        return false;
      } else {
        // FIX: If currently on just_audio but next song is a local file on Windows,
        // we can't crossfade through mpv (EQ won't work). Fall back to normal play()
        // which correctly routes local files through FFI.
        final isHttp = song.filePath.startsWith('http://') ||
            song.filePath.startsWith('https://');
        final isFfiLocal =
            (Platform.isWindows || Platform.isAndroid) && !isHttp && isFfiSupported(song.filePath);

        if (isFfiLocal && _activePlayerIndex <= 2) {
          DebugLogService().info(
              "[Native] Crossfade: Local file after stream — falling back to FFI play()");
          _isCrossfading = false;
          return false; // Caller will use normal play() which routes to FFI
        }

        // FIX: Also decline crossfade when going FROM FFI (local) TO a stream.
        // FFI and just_audio/MediaKit are entirely separate audio engines — we cannot
        // cross-fade between them. Attempting to do so loads the stream into just_audio's
        // inPlayer but then enters FFI fade logic, causing BOTH engines to output audio.
        // Normal play() correctly handles the engine switch via _switchToJustAudio().
        if (!isFfiLocal &&
            (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
          DebugLogService().info(
              "[Native] Crossfade: Stream after FFI local — cannot cross-fade between engines. Falling back to normal play.");
          _isCrossfading = false;
          return false;
        }

        // CRITICAL OPTIMIZATION: Check if already preloaded to avoid "cropping" delay
        if (_preloadedFilePath == song.filePath &&
            _preloadedSong?.title == song.title) {
          DebugLogService().info(
              "[Native] Crossfade: Using preloaded source for ${song.title}");
        } else {
          DebugLogService().info(
              "[Native] Crossfade: Song not preloaded, loading now: ${song.title}");

          if (isFfiLocal) {
            // Windows Local File: Load directly into the incoming FFI engine.
            // We CANNOT use `inPlayer.setAudioSource` because just_audio_media_kit
            // will try to buffer it and crash (lavf file cache error).
            final usePlayer2 = (_activePlayerIndex ==
                3); // If FFI1 is active, FFI2 is incoming
            final targetFFI = usePlayer2 ? _ffiPlayer2 : _ffiPlayer1;

            if (targetFFI == null) return false; // Safety fallback

            await targetFFI.stop();
            final prefs = await SharedPreferences.getInstance();
            final bool isBitPerfect = prefs.getBool('wasapiExclusive') ?? false;
            await targetFFI.setFilePath(song.filePath,
                bitPerfect: isBitPerfect);
            _currentReplayGainNext = song.replayGain ?? 0.0;
            DebugLogService()
                .info("[Native] Crossfade: FFI engine manually prepared.");
          } else {
            // Standard Route (Android, Streams)
            final sourceUri =
                isHttp ? Uri.parse(song.filePath) : Uri.file(song.filePath);
            try {
              await inPlayer.setAudioSource(
                _createAudioSource(sourceUri, song),
                preload: true,
              );
            } catch (e) {
              // FIX: Handle "Failed to create file cache" and other stream load errors
              // gracefully by falling back to normal play instead of crashing
              DebugLogService().error(
                  "[Native] Crossfade: Stream load failed ($e) — falling back to normal play");
              _isCrossfading = false;
              return false;
            }
          }
        }
      }

      // Clear preloaded state now that we are using it
      _preloadedFilePath = null;
      _preloadedSong = null;

      // Start playing incoming
      // FFI FIX — initialise crossfade multipliers BEFORE the incoming FFI player starts
      // playing so it begins at 0 volume (silent) and fades in, rather than popping to full.
      if ((Platform.isWindows || Platform.isAndroid) &&
          (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
        if (_activePlayerIndex == 3) {
          // FFI1 is outgoing (stays full), FFI2 is incoming (starts silent)
          _ffiPlayer1FadeMult = 1.0;
          _ffiPlayer2FadeMult = 0.0;
        } else {
          // FFI2 is outgoing (stays full), FFI1 is incoming (starts silent)
          _ffiPlayer1FadeMult = 0.0;
          _ffiPlayer2FadeMult = 1.0;
        }
        _updateWindowsEngineVolume(); // Apply 0 volume to incoming FFI before it starts
      }

      // Only play the just_audio placeholder if we aren't using FFI
      // Calling play() on media_kit without an audio source causes state corruption
      final isFfiLocal = (Platform.isWindows || Platform.isAndroid) &&
          !(song.filePath.startsWith('http://') ||
              song.filePath.startsWith('https://')) &&
          isFfiSupported(song.filePath);
      if (!isFfiLocal) {
        inPlayer.play();
      }

      // Windows FFI Logic: Handle index swapping and ReplayGain swap
      if ((Platform.isWindows || Platform.isAndroid) &&
          (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
        final oldActive = _activePlayerIndex;
        _activePlayerIndex = (oldActive == 3) ? 4 : 3; // Toggle active index

        // Swap ReplayGain: Preloaded becomes Active
        _currentReplayGain = _currentReplayGainNext;

        final inFFI = _activePlayerIndex == 3 ? _ffiPlayer1 : _ffiPlayer2;
        inFFI
            ?.play(); // Start the incoming FFI engine (it starts at 0 volume thanks to above)
      } else {
        // Standard just_audio Switch
        _activePlayerIndex = _activePlayerIndex == 1 ? 2 : 1;
      }

      _activePlayerIndexSubject.add(_activePlayerIndex);
      _activePlayerSubject.add(_player);

      // Update Audio Service metadata to new song (Fire and forget)
      if (Platform.isAndroid || Platform.isIOS) {
        _updateAudioServiceMetadata(song);
      }

      // Fading logic
      const steps = 20;
      final stepDuration =
          Duration(milliseconds: (duration * 1000 / steps).round());
      int currentStep = 0;

      _fadeTimer = Timer.periodic(stepDuration, (timer) {
        currentStep++;
        // DYNAMIC SCALING: Use _currentVolume directly in each step
        // This ensures the fade remains smooth even if the user slides the volume during the crossfade.
        double outVol = _currentVolume * (1.0 - (currentStep / steps));
        double inVol = _currentVolume * (currentStep / steps);

        if (outVol < 0) outVol = 0;
        if (inVol > _currentVolume) inVol = _currentVolume;

        // Sync Master Volume updates to FFI or just_audio
        if ((Platform.isWindows || Platform.isAndroid) &&
            (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
          // FFI FIX: Update per-player fade multipliers then recompute via
          // _updateWindowsEngineVolume() which now applies them.
          // _activePlayerIndex is already toggled, so:
          //   index==3 means FFI1 is the NEW active (incoming, fades in), FFI2 fades out
          //   index==4 means FFI2 is the NEW active (incoming, fades in), FFI1 fades out
          final double outFrac =
              _currentVolume > 0 ? (outVol / _currentVolume) : 0.0;
          final double inFrac =
              _currentVolume > 0 ? (inVol / _currentVolume) : 1.0;
          if (_activePlayerIndex == 3) {
            _ffiPlayer1FadeMult = inFrac; // FFI1 = incoming, fades 0→1
            _ffiPlayer2FadeMult = outFrac; // FFI2 = outgoing, fades 1→0
          } else {
            _ffiPlayer1FadeMult = outFrac; // FFI1 = outgoing, fades 1→0
            _ffiPlayer2FadeMult = inFrac; // FFI2 = incoming, fades 0→1
          }
          _updateWindowsEngineVolume();
        } else {
          outPlayer.setVolume(outVol);
          inPlayer.setVolume(inVol);
        }

        if (currentStep >= steps) {
          timer.cancel();
          outPlayer
              .pause(); // Pause outgoing player without disposing MediaKit resources

          if ((Platform.isWindows || Platform.isAndroid) &&
              (_activePlayerIndex == 3 || _activePlayerIndex == 4)) {
            // Stop the outgoing FFI engine (opposite of the new active)
            final outFfi = _activePlayerIndex == 3 ? _ffiPlayer2 : _ffiPlayer1;
            outFfi?.stop();
            // Reset multipliers: both 1.0 so _updateWindowsEngineVolume gives full volume to active
            _ffiPlayer1FadeMult = 1.0;
            _ffiPlayer2FadeMult = 1.0;
            outPlayer.setVolume(
                1.0); // Reset just_audio fade-multiplier for next crossfade
            _updateWindowsEngineVolume();
          } else {
            outPlayer.setVolume(_currentVolume); // Reset for next use
          }
          _isCrossfading = false; // Clear guard
          DebugLogService().info("[Native] Crossfade Complete");
        }
      });

      return true;
    } catch (e) {
      _isCrossfading = false; // Clear guard on error
      DebugLogService().error("Crossfade Error: $e");
      return false;
    }
  }

  // NOTE: _cleanStreamUrl was removed. The ?start= parameter was ignored by
  // YouTube and Tidal servers, causing seeks to restart from 0:00.
  // Seeking now uses setAudioSource(initialPosition) instead.

  AudioSource _createAudioSource(Uri uri, SongModel song) {
    if (uri.isScheme('file')) {
      return AudioSource.uri(uri, tag: song, headers: null);
    }

    final bool isYouTube = uri.host.contains('googlevideo.com');

    // 🛡️ Spoof browser User-Agent for YouTube (googlevideo.com) URLs.
    // Without this, Android's ExoPlayer sends its default UA header which
    // YouTube detects and blocks with 403 / "Source error".
    final Map<String, String>? headers = isYouTube
        ? {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          }
        : null;

    // ⏱️ Pass override_duration in query params for MediaKit duration locks.
    // This informs libmpv of the exact track duration upfront, preventing
    // chunked HTTP streams from defaulting to 0:00 duration or infinite buffering.
    //
    // ⚠️ CRITICAL: Do NOT use uri.replace(queryParameters:) for YouTube URLs!
    // YouTube CDN URLs have cryptographically signed query params. The round-trip
    // through queryParameters (decode) → replace (re-encode) changes the encoding
    // (e.g. %2C→, or %3D→=) which invalidates the signature → 403/Source error.
    // override_duration is only used by MediaKit (desktop), so skip it for YouTube.
    if (song.duration > 0 && !isYouTube) {
      // Safe for non-YouTube URLs: append via string concat to preserve encoding
      final separator = uri.hasQuery ? '&' : '?';
      final durationMs = (song.duration * 1000).toInt();
      final updatedUri = Uri.parse('$uri${separator}override_duration=$durationMs');
      return AudioSource.uri(updatedUri, tag: song, headers: headers);
    }

    return AudioSource.uri(uri, tag: song, headers: headers);
  }

  /// Windows EQ/Volume Sync: Combine master volume and EQ preamp
  void setWindowsEQ({required List<double> gains, double preampDb = 0.0}) {
    if (!Platform.isWindows) return;

    _eqPreampGain = preampDb;
    _currentEqGains = List.from(gains); // Store for lazy player initialization

    // GAIN COMPENSATION: Track highest boost to prevent clipping
    _maxEqGain = 0.0;
    for (var g in gains) {
      if (g > _maxEqGain) _maxEqGain = g;
    }

    _updateWindowsEngineVolume();

    for (int i = 0; i < gains.length; i++) {
      _ffiPlayer1?.setEQBand(
          i, EqEngine.bandFrequencies[i].toDouble(), gains[i], 1.41);
      _ffiPlayer2?.setEQBand(
          i, EqEngine.bandFrequencies[i].toDouble(), gains[i], 1.41);
    }
  }

  void _updateWindowsEngineVolume() {
    if (_ffiPlayer1 == null && _ffiPlayer2 == null) return;

    // Convert EQ Preamp to linear
    final preampLinear = math.pow(10, _eqPreampGain / 20.0).toDouble();

    // Gentle EQ compensation: only attenuate half of boosts above 6dB
    // This prevents volume collapse while still protecting against extreme clipping
    final excessGain = (_maxEqGain > 6.0) ? (_maxEqGain - 6.0) * 0.5 : 0.0;
    final compensationLinear = math.pow(10, -excessGain / 20.0).toDouble();

    // Windows (mpv) uses a cubic volume curve. Android (ExoPlayer) uses a linear curve.
    final curveVol = Platform.isWindows ? math.pow(_currentVolume, 3).toDouble() : _currentVolume;

    // Apply to FFI 1
    if (_ffiPlayer1 != null) {
      final bool isCurrent = _activePlayerIndex == 3;
      final gain = enableReplayGain ? (isCurrent ? _currentReplayGain : _currentReplayGainNext) : 0.0;
      final replayGainLinear = math.pow(10, gain / 20.0).toDouble();
      // FIX: Apply per-player crossfade fade multiplier so the envelope is actually heard
      final totalGain = curveVol *
          preampLinear *
          compensationLinear *
          replayGainLinear *
          _ffiPlayer1FadeMult;

      debugPrint(
          "🔊 FFI 1 Volume updated: _currentVolume=$_currentVolume (cubic=$curveVol), RP=$gain, fade=$_ffiPlayer1FadeMult, totalGain=$totalGain");
      _ffiPlayer1!.setVolume(totalGain);
    }

    // Apply to FFI 2
    if (_ffiPlayer2 != null) {
      final bool isCurrent = _activePlayerIndex == 4;
      final gain = enableReplayGain ? (isCurrent ? _currentReplayGain : _currentReplayGainNext) : 0.0;
      final replayGainLinear = math.pow(10, gain / 20.0).toDouble();
      // FIX: Apply per-player crossfade fade multiplier
      final totalGain = curveVol *
          preampLinear *
          compensationLinear *
          replayGainLinear *
          _ffiPlayer2FadeMult;

      debugPrint(
          "🔊 FFI 2 Volume updated: fade=$_ffiPlayer2FadeMult, totalGain=$totalGain");
      _ffiPlayer2!.setVolume(totalGain);
    }
  }

  void _applyCachedEqToPlayer(FfiAudioPlayer player) {
    if (_currentEqGains == null) return;
    for (int i = 0; i < _currentEqGains!.length; i++) {
      player.setEQBand(
          i, EqEngine.bandFrequencies[i].toDouble(), _currentEqGains![i], 1.41);
    }
  }

  double getCalculatedVolumeForSong(SongModel? song, double baseVolume) {
    // Convert EQ Preamp to linear
    final preampLinear = math.pow(10, _eqPreampGain / 20.0).toDouble();

    // Gentle EQ compensation: only attenuate half of boosts above 6dB
    final excessGain = (_maxEqGain > 6.0) ? (_maxEqGain - 6.0) * 0.5 : 0.0;
    final compensationLinear = math.pow(10, -excessGain / 20.0).toDouble();

    // Windows (mpv) uses a cubic volume curve. Android (ExoPlayer) uses a linear curve.
    final curveVol = Platform.isWindows ? math.pow(baseVolume, 3).toDouble() : baseVolume;

    // ReplayGain offset
    final double rg = (enableReplayGain && song != null) ? (song.replayGain ?? 0.0) : 0.0;
    final replayGainLinear = math.pow(10, rg / 20.0).toDouble();

    final totalGain = curveVol * preampLinear * compensationLinear * replayGainLinear;
    debugPrint("🔊 Calculated UsbAudio volume for ${song?.title}: baseVolume=$baseVolume, preamp=$_eqPreampGain, maxEq=$_maxEqGain, RG=$rg, totalGain=$totalGain");
    return totalGain.clamp(0.0, 1.0);
  }
}

class _NativeLifecycleObserver extends WidgetsBindingObserver {
  final NativeMusicService _service;
  _NativeLifecycleObserver(this._service);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _service._tryClaimMutex();
    } else if (state == AppLifecycleState.detached) {
      // App is being killed - full cleanup
      debugPrint("🎵 Lifecycle: App DETACHED - Stopping Players");
      _service._player1.stop();
      _service._player2.stop();
      // DO NOT DISPOSE in singleton lifecycle observer.
      // It causes crashes if any late events (like volume sync) fire.
      // The OS will clean up process resources anyway.
      _service._audioHandler?.stop();
    }
  }
}
