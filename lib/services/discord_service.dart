import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_discord_rpc/flutter_discord_rpc.dart' as rpc;
import '../models/song_model.dart';
import '../env/env.dart';

class DiscordService {
  static final DiscordService _instance = DiscordService._internal();
  factory DiscordService() => _instance;
  DiscordService._internal();

  // Use the official "Simple Music Player" ID by default, or override with Env
  static const String _defaultAppId = '1439993466267369492';
  final String _applicationId =
      Env.discordAppId.isNotEmpty ? Env.discordAppId : _defaultAppId;

  bool _isConnected = false;
  bool _isConnecting = false;

  // CRITICAL: Static flag to ensure we NEVER initialize the native library twice.
  static bool _isLibraryInitialized = false;

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
    // Start the infinite monitoring loop
    _startMonitor();
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      clearPresence();
    } else {
      // Try to re-sync immediately if we have data
      if (_lastSong != null) {
        _performUpdate();
      }
    }
  }

  /// Checks if Discord is running every 5 seconds and tries to connect
  void _startMonitor() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isEnabled) return;

      // If already connected, do nothing
      if (_isConnected) return;

      // If currently trying to connect, wait
      if (_isConnecting) return;

      // Check if Discord Process exists
      final isRunning = await _isDiscordProcessRunning();

      if (isRunning) {
        if (kDebugMode) {
          print("Found Discord process. Attempting connection...");
        }
        await _tryConnect();
      }
    });
  }

  Future<void> _tryConnect() async {
    _isConnecting = true;

    try {
      // 1. Initialize Library (ONLY ONCE PER APP LIFETIME)
      if (!_isLibraryInitialized) {
        await rpc.FlutterDiscordRPC.initialize(_applicationId);
        _isLibraryInitialized = true;
        if (kDebugMode) print("✅ Discord RPC Library Initialized");
      }

      // 2. Wait a moment for Discord's IPC pipe to be ready (prevents native crash)
      // If you just opened Discord, the pipe takes ~2-3 seconds to appear.
      await Future.delayed(const Duration(seconds: 3));

      // 3. Connect
      rpc.FlutterDiscordRPC.instance.connect();

      _isConnected = true;
      if (kDebugMode) print("✅ Discord Connected Successfully");

      // 4. Sync immediately if music is playing
      if (_lastSong != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        _performUpdate();
      }
    } catch (e) {
      _isConnected = false;
      // It's okay if this fails (e.g. pipe not ready yet).
      // The timer will try again in 5 seconds.
      if (kDebugMode) print("⚠️ Connect attempt failed: $e");
    } finally {
      _isConnecting = false;
    }
  }

  Future<bool> _isDiscordProcessRunning() async {
    if (!Platform.isWindows) return true;
    try {
      final result =
          await Process.run('tasklist', ['/FI', 'IMAGENAME eq Discord.exe']);
      final output = result.stdout.toString();
      return output.contains('Discord.exe') ||
          output.contains('DiscordCanary.exe') ||
          output.contains('DiscordPTB.exe');
    } catch (e) {
      return false;
    }
  }

  void updatePresence(
      SongModel song, bool isPlaying, Duration position, Duration total,
      {String? imageUrl}) {
    // Always cache the latest state
    _lastSong = song;
    _lastIsPlaying = isPlaying;
    _lastPosition = position;
    _lastTotal = total;
    _lastImageUrl = imageUrl;

    // Only send if actually connected
    if (_isConnected) {
      _performUpdate();
    }
  }

  void _performUpdate() {
    if (!_isEnabled) return;
    if (_lastSong == null) return;

    try {
      final int startTimestamp =
          DateTime.now().millisecondsSinceEpoch - _lastPosition.inMilliseconds;
      final int endTimestamp = startTimestamp + _lastTotal.inMilliseconds;

      rpc.FlutterDiscordRPC.instance.setActivity(
        activity: rpc.RPCActivity(
          details: "${_lastSong!.title}",
          state:
              "by ${_lastSong!.artist}" + (_lastIsPlaying ? "" : " (Paused)"),
          assets: rpc.RPCAssets(
            largeImage: _lastImageUrl ?? 'app_icon',
            largeText: _lastSong!.album.isNotEmpty
                ? _lastSong!.album
                : 'Simple Music Player',
            smallImage: _lastIsPlaying ? 'play' : 'pause',
            smallText: _lastIsPlaying ? 'Playing' : 'Paused',
          ),
          timestamps: rpc.RPCTimestamps(
            start: _lastIsPlaying ? startTimestamp : null,
            end: _lastIsPlaying ? endTimestamp : null,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Discord Connection Lost. Restarting monitor...");
      }
      _isConnected = false;
      // If the update fails, we assume connection lost. The timer loop will pick it up again.
    }
  }

  void clearPresence() {
    _lastSong = null;
    if (!_isConnected) return;
    try {
      rpc.FlutterDiscordRPC.instance.clearActivity();
    } catch (_) {
      _isConnected = false;
    }
  }
}
