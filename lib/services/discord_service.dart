import 'dart:io';
import 'dart:async';
import 'package:flutter_discord_rpc/flutter_discord_rpc.dart' as rpc;
import '../models/song_model.dart';
import '../env/env.dart';
import 'debug_log_service.dart';
import 'pocketbase_service.dart'; // 🔒 OFFLINE MODE

class DiscordService {
  static final DiscordService _instance = DiscordService._internal();
  factory DiscordService() => _instance;
  DiscordService._internal();

  // Use the official fallback ID only if Env is absolutely empty
  final String _applicationId =
      Env.discordAppId.isNotEmpty ? Env.discordAppId : '1439993466267369492';

  bool _isConnected = false;
  bool _isConnecting = false;

  // CRITICAL: Static flag to ensure we NEVER initialize the native library twice.
  static bool _isLibraryInitialized = false;

  // Stability Guard: Try connection as soon as Discord process is detected.
  static const int _requiredStability = 1;
  int _stabilityCount = 0;
  Timer? _monitorTimer;

  // Cache state for auto-sync
  SongModel? _lastSong;
  bool _lastIsPlaying = false;
  Duration _lastPosition = Duration.zero;
  Duration _lastTotal = Duration.zero;
  String? _lastImageUrl;
  DateTime _lastPositionTimestamp = DateTime.now();

  Timer? _pauseTimer;
  bool _isClearedDueToPause = false;
  bool _isPausedState = false;

  bool _isEnabled = true;

  // Periodic timer to re-sync seek bar every 15 seconds & auto-reconnect if disconnected
  Timer? _heartbeatTimer;

  // SONG CHANGE DETECTION: Track filePath to detect song transitions
  String? _currentSongPath;
  DateTime? _songStartTime;

  bool get isConnected => _isConnected;

  /// Entry point: Called once when app starts
  void init() {
    if (Platform.isAndroid || Platform.isIOS) return;
    DebugLogService().info("[Discord] init() called. Monitoring process...");
    _startMonitor();
  }

  Future<void> _initializeLibrary() async {
    if (_isLibraryInitialized) return;
    try {
      DebugLogService()
          .info("[Discord] Pre-Initializing with App ID: $_applicationId");
      await rpc.FlutterDiscordRPC.initialize(_applicationId);
      _isLibraryInitialized = true;
      DebugLogService().info("[Discord] ✅ RPC Library Ready");
    } catch (e) {
      DebugLogService().error("[Discord] ❌ Library Init Failed: $e");
    }
  }

  void setEnabled(bool enabled) {
    if (Platform.isAndroid || Platform.isIOS) return;
    
    _isEnabled = enabled;
    if (!enabled) {
      _stopHeartbeat();
      clearPresence(clearCache: false);
    } else {
      // Try to re-sync immediately
      if (!_isConnected) {
        _stabilityCount = _requiredStability; // bypass monitor delay
        _tryConnect(fast: true);
      } else if (_lastSong != null) {
        _performUpdate();
        _startHeartbeat();
      }
    }
  }

  /// Start a 15-second heartbeat to re-sync seek bar and attempt reconnection if client was opened after app
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!_isEnabled) return;

      if (!_isConnected) {
        // Heartbeat update check: if disconnected, try reconnecting if Discord is running
        if (!_isConnecting && await _isDiscordProcessRunning()) {
          DebugLogService().info(
              "[Discord] 💓 Heartbeat: Reconnecting to Discord client...");
          await _tryConnect(fast: true);
        }
      } else if (_lastIsPlaying && !_isClearedDueToPause) {
        DebugLogService().info("[Discord] 💓 Heartbeat: Re-syncing seek bar");
        await _performUpdate();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Checks if Discord is running every 3 seconds and tries to connect
  void _startMonitor() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_isEnabled) return;
      if (_isConnecting) return;

      // Check if Discord Process exists
      final isRunning = await _isDiscordProcessRunning();

      if (isRunning) {
        if (!_isConnected) {
          _stabilityCount++;
          if (_stabilityCount >= _requiredStability) {
            DebugLogService().info(
                "[Discord] Discord process detected. Attempting connection...");
            await _tryConnect(fast: true);
          }
        }
      } else {
        // Reset count if Discord is not running
        _stabilityCount = 0;
        if (_isConnected) {
          DebugLogService().info(
              "[Discord] Connection lost (Process closed). Marking disconnected.");
          _isConnected = false;
          _stopHeartbeat();
        }
      }
    });
  }

  Future<void> _tryConnect({bool fast = false}) async {
    if (_isConnecting || _isConnected) return;
    _isConnecting = true;

    try {
      // Ensure initialized (should be already from init)
      if (!_isLibraryInitialized) {
        await _initializeLibrary();
      }

      if (!fast) {
        await Future.delayed(const Duration(seconds: 2));
      }

      // Connect
      try {
        await rpc.FlutterDiscordRPC.instance.connect();
        _isConnected = true;
        DebugLogService().info("[Discord] ✅ Connection Successful");
      } catch (connErr) {
        DebugLogService().error("[Discord] ❌ Handshake Failed: $connErr");
        _isConnected = false;
        _stabilityCount = 0;
      }

      if (_isConnected) {
        _startHeartbeat();
        if (_lastSong != null && !_isClearedDueToPause) {
          DebugLogService().info(
              "[Discord] Handshake successful. Immediately syncing presence.");
          await _performUpdate();
        }
      }
    } catch (e) {
      _isConnected = false;
      _stabilityCount = 0;
      DebugLogService().error("[Discord] ⚠️ Global Handshake Error: $e");
    } finally {
      _isConnecting = false;
    }
  }

  Future<bool> _isDiscordProcessRunning() async {
    if (!Platform.isWindows) return true;
    try {
      final result = await Process.run('tasklist', []);
      final output = result.stdout.toString().toLowerCase();

      return output.contains('discord.exe') ||
          output.contains('discordcanary.exe') ||
          output.contains('discordptb.exe');
    } catch (e) {
      return false;
    }
  }

  Future<void> updatePresence(
      SongModel song, bool isPlaying, Duration position, Duration total,
      {String? imageUrl}) async {
    if (Platform.isAndroid || Platform.isIOS) return;

    // Cache latest state
    _lastSong = song;
    _lastIsPlaying = isPlaying;
    _lastPosition = position;
    _lastTotal = total;
    _lastImageUrl = imageUrl;
    _lastPositionTimestamp = DateTime.now();

    // SONG CHANGE OR MANUAL SEEK: Re-anchor stable _songStartTime
    final bool isSongChange = song.filePath != _currentSongPath;
    final now = DateTime.now();
    final bool isManualSeek = _songStartTime != null &&
        (position.inSeconds - now.difference(_songStartTime!).inSeconds).abs() > 2;

    if (isSongChange || isManualSeek || _songStartTime == null) {
      _currentSongPath = song.filePath;
      _songStartTime = now.subtract(position);
      if (isSongChange) {
        DebugLogService().info(
            "[Discord] 🎵 Song changed: ${song.title} (${total.inSeconds}s)");
      }
    }

    if (isPlaying) {
      _pauseTimer?.cancel();
      _pauseTimer = null;
      _isClearedDueToPause = false;
      _isPausedState = false;
      _startHeartbeat();
      if (!_isConnected && _isEnabled && !_isConnecting) {
        _tryConnect(fast: true);
      } else if (_isConnected && _isEnabled) {
        _performUpdate();
      }
    } else {
      _stopHeartbeat();

      // Guard: Only send paused state once, not on every repeated call
      if (!_isPausedState && !_isClearedDueToPause) {
        _isPausedState = true;

        // Immediately show paused state (no seek bar)
        if (_isConnected && _isEnabled) {
          _performUpdate();
        }

        // After 30 seconds of pause, fully clear the Discord status
        _pauseTimer?.cancel();
        _pauseTimer = Timer(const Duration(seconds: 30), () async {
          _isClearedDueToPause = true;
          _isPausedState = false;
          if (_isConnected) {
            try {
              await rpc.FlutterDiscordRPC.instance.clearActivity();
              DebugLogService().info(
                  "[Discord] ⏹️ Paused for 30s. Status cleared.");
            } catch (e) {
              _isConnected = false;
            }
          }
        });
      }
      // If already paused or cleared, do nothing — prevent endless calls
    }
  }

  Future<void> _performUpdate() async {
    if (!_isEnabled || !_isConnected || _lastSong == null) return;

    // OFFLINE MODE: Clear activity instead of updating
    if (PocketBaseService.isOffline) {
      try {
        await rpc.FlutterDiscordRPC.instance.clearActivity();
      } catch (e) {
        _isConnected = false;
        _stopHeartbeat();
      }
      return;
    }

    try {
      // Extrapolate current position: if playing, add elapsed time since last cache
      final now = DateTime.now();
      final elapsed = _lastIsPlaying
          ? now.difference(_lastPositionTimestamp)
          : Duration.zero;
      final currentPosition = _lastPosition + elapsed;
      // Clamp to total duration to prevent overshoot
      final clampedPosition = currentPosition > _lastTotal
          ? _lastTotal
          : currentPosition;

      final int startTimestamp = _songStartTime != null
          ? _songStartTime!.millisecondsSinceEpoch
          : (now.millisecondsSinceEpoch - clampedPosition.inMilliseconds);
      final int endTimestamp = startTimestamp + _lastTotal.inMilliseconds;

      // TRUNCATION GUARD: Discord Max 128 chars
      final String title = _lastSong!.title.length > 128
          ? '${_lastSong!.title.substring(0, 125)}...'
          : _lastSong!.title;
      final String artist = _lastSong!.artist.length > 128
          ? '${_lastSong!.artist.substring(0, 125)}...'
          : _lastSong!.artist;
      final String album = _lastSong!.album.length > 128
          ? '${_lastSong!.album.substring(0, 125)}...'
          : _lastSong!.album;

      await rpc.FlutterDiscordRPC.instance.setActivity(
        activity: rpc.RPCActivity(
          details: title,
          state: "by $artist${_lastIsPlaying ? "" : " (Paused)"}",
          assets: rpc.RPCAssets(
            largeImage: _lastImageUrl ?? 'app_icon',
            largeText: album.isNotEmpty ? album : 'Simple Music Player',
          ),
          timestamps: _lastIsPlaying
              ? rpc.RPCTimestamps(
                  start: startTimestamp,
                  end: endTimestamp,
                )
              : null,
          activityType: rpc.ActivityType.listening,
        ),
      );
    } catch (e) {
      DebugLogService()
          .error("[Discord] ⚠️ Update Failed: $e. Marking disconnected.");
      _isConnected = false;
      _stopHeartbeat();
    }
  }

  /// Update ONLY the cover art image without touching position or timestamps.
  /// Used by async art fetch callbacks to prevent seekbar jumps.
  Future<void> updateImage(String imageUrl) async {
    _lastImageUrl = imageUrl;
    if (_isConnected && _isEnabled && _lastSong != null && !_isClearedDueToPause) {
      await _performUpdate();
    }
  }

  Future<void> clearPresence({bool clearCache = true}) async {
    if (Platform.isAndroid || Platform.isIOS) return;
    
    if (clearCache) {
      _lastSong = null;
      _currentSongPath = null;
    }
    _pauseTimer?.cancel();
    _pauseTimer = null;
    _isClearedDueToPause = false;
    _stopHeartbeat();
    if (!_isConnected) return;
    try {
      await rpc.FlutterDiscordRPC.instance.clearActivity();
    } catch (e) {
      _isConnected = false;
    }
  }
}
