import 'dart:io';
import 'dart:async';
import 'package:flutter_discord_rpc/flutter_discord_rpc.dart' as rpc;
import '../models/song_model.dart';
import '../env/env.dart';
import 'debug_log_service.dart';

class DiscordService {
  static final DiscordService _instance = DiscordService._internal();
  factory DiscordService() => _instance;
  DiscordService._internal();

  // Use the official fallback ID only if Env is absolutely empty
  final String _applicationId = Env.discordAppId.isNotEmpty 
      ? Env.discordAppId 
      : '1439993466267369492';

  bool _isConnected = false;
  bool _isConnecting = false;

  // CRITICAL: Static flag to ensure we NEVER initialize the native library twice.
  static bool _isLibraryInitialized = false;

  // Stability Guard: Wait for 6 consecutive sightings (30 seconds)
  // before attempting to touch the native IPC pipe.
  static const int _requiredStability = 6;
  int _stabilityCount = 0; 
  Timer? _monitorTimer;

  // Cache state for auto-sync
  SongModel? _lastSong;
  bool _lastIsPlaying = false;
  Duration _lastPosition = Duration.zero;
  Duration _lastTotal = Duration.zero;
  String? _lastImageUrl;

  bool _isEnabled = true;

  /// Entry point: Called once when app starts
  void init() {
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
    _isEnabled = enabled;
    if (!enabled) {
      clearPresence();
    } else {
      // Try to re-sync immediately if we have data
      if (_lastSong != null && _isConnected) {
        _performUpdate();
      }
    }
  }

  /// Checks if Discord is running every 5 seconds and tries to connect
  void _startMonitor() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isEnabled) return;
      if (_isConnecting) return;

      // Check if Discord Process exists
      final isRunning = await _isDiscordProcessRunning();

      if (isRunning) {
        _stabilityCount++;
        
        // Ensure we don't spam the connection if we are already connected
        if (_isConnected) return;

        // --- STABILITY GUARD ---
        // Only attempt connection after 30 seconds of stable process detection.
        if (_stabilityCount >= _requiredStability) {
          DebugLogService().info(
              "[Discord] Stability achieved ($_stabilityCount). Attempting connection...");
          await _tryConnect();
        } else {
          DebugLogService().info(
              "[Discord] Found. Stability: ($_stabilityCount/$_requiredStability)");
        }
      } else {
        // Reset count if Discord is not running
        if (_stabilityCount > 0) {
          DebugLogService().info("[Discord] Discord process not found. Resetting stability count.");
          _stabilityCount = 0;
        }

        if (_isConnected) {
          DebugLogService().info(
              "[Discord] Connection lost (Process closed). Marking disconnected.");
          _isConnected = false;
        }
      }
    });
  }

  Future<void> _tryConnect() async {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      // Ensure initialized (should be already from init)
      if (!_isLibraryInitialized) {
        await _initializeLibrary();
      }

      // Final Buffer: Wait 10 more seconds after stability achieved
      await Future.delayed(const Duration(seconds: 10));

      // Connect 
      try {
        rpc.FlutterDiscordRPC.instance.connect();
        _isConnected = true;
        DebugLogService().info("[Discord] ✅ Connection Successful");
      } catch (connErr) {
        DebugLogService().error("[Discord] ❌ Handshake Failed: $connErr");
        _isConnected = false;
      }
      
      // 🚀 RESTORED SAFETY: Do NOT sync immediately.
      // Let the regular updatePresence() calls from the player handle it.
      DebugLogService().info("[Discord] Handshake successful. Waiting for next player pulse.");
    } catch (e) {
      _isConnected = false;
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

  void updatePresence(
      SongModel song, bool isPlaying, Duration position, Duration total,
      {String? imageUrl}) {
    // Cache latest state
    _lastSong = song;
    _lastIsPlaying = isPlaying;
    _lastPosition = position;
    _lastTotal = total;
    _lastImageUrl = imageUrl;

    // Only send if connected and enabled
    if (_isConnected && _isEnabled) {
      _performUpdate();
    }
  }

  void _performUpdate() {
    if (!_isEnabled || !_isConnected || _lastSong == null) return;

    try {
      final int startTimestamp =
          DateTime.now().millisecondsSinceEpoch - _lastPosition.inMilliseconds;
      final int endTimestamp = startTimestamp + _lastTotal.inMilliseconds;

      // TRUNCATION GUARD: Discord Max 128 chars
      final String title = _lastSong!.title.length > 128
          ? _lastSong!.title.substring(0, 125) + "..."
          : _lastSong!.title;
      final String artist = _lastSong!.artist.length > 128
          ? _lastSong!.artist.substring(0, 125) + "..."
          : _lastSong!.artist;
      final String album = _lastSong!.album.length > 128
          ? _lastSong!.album.substring(0, 125) + "..."
          : _lastSong!.album;

      rpc.FlutterDiscordRPC.instance.setActivity(
        activity: rpc.RPCActivity(
          details: title,
          state: "by $artist${_lastIsPlaying ? "" : " (Paused)"}",
          assets: rpc.RPCAssets(
            largeImage: _lastImageUrl ?? 'app_icon',
            largeText: album.isNotEmpty ? album : 'Simple Music Player',
          ),
          timestamps: rpc.RPCTimestamps(
            start: _lastIsPlaying ? startTimestamp : null,
            end: _lastIsPlaying ? endTimestamp : null,
          ),
        ),
      );
    } catch (e) {
      DebugLogService().error("[Discord] ⚠️ Update Failed: $e. Marking disconnected.");
      _isConnected = false;
    }
  }

  void clearPresence() {
    _lastSong = null;
    if (!_isConnected) return;
    try {
      rpc.FlutterDiscordRPC.instance.clearActivity();
    } catch (e) {
      _isConnected = false;
    }
  }
}
