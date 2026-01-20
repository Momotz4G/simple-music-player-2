import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:simple_music_player_2/services/metrics_service.dart';
import 'package:simple_music_player_2/services/pocketbase_service.dart';

class RemoteControlService {
  static final RemoteControlService _instance =
      RemoteControlService._internal();
  factory RemoteControlService() => _instance;
  RemoteControlService._internal();

  String? _userId;
  String? _lastCommandId; // Deduplication

  // State Tracking for Deduplication (Loop Breaker Pattern)
  bool? _lastShuffle;
  int? _lastLoop;

  Future<void> init() async {
    final metrics = MetricsService();
    // Wait slightly if metrics isn't initialized
    int retries = 0;
    while (!metrics.initialized && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
    }

    _userId = metrics.userId;
    if (_userId != null) {
      debugPrint("📡 RemoteControl: Initialized for ID: $_userId");
    }
  }

  void setUserId(String id) {
    _userId = id;
  }

  /// Set initial state for loop breaker pattern.
  /// Call this BEFORE startListening to prevent stale server data from overwriting local settings.
  void setInitialState({bool? shuffle, int? loopMode}) {
    if (shuffle != null) _lastShuffle = shuffle;
    if (loopMode != null) _lastLoop = loopMode;
    debugPrint(
        "📡 RemoteControl: Initial state set - Shuffle=$shuffle, Loop=$loopMode");
  }

  String? _lastCommandTime; // Track updates by timestamp

  Timer? _pollingTimer;

  // Start listening for commands
  Future<void> startListening(
      {required Function(String action, dynamic value) onCommand}) async {
    // 1. Setup Realtime Subscription (Best Effort)
    await PocketBaseService().subscribeToSession((data) {
      _checkAndProcessCommand(data, onCommand);
    });

    // 2. Setup Polling Fallback (Reliability)
    // Run every 5 seconds to catch missed events if Realtime fails
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_userId == null) return;
      final sessionData = await PocketBaseService().getSessionData();
      if (sessionData != null) {
        _checkAndProcessCommand(sessionData, onCommand);
      }
    });
  }

  final DateTime _serviceStartTime = DateTime.now();

  DateTime? _lastBroadcastTime; // 🚀 Track last broadcast to ignore echoes

  void _checkAndProcessCommand(
      Map<String, dynamic> data, Function(String, dynamic) onCommand) {
    debugPrint("📡 [Remote] Raw Data: $data");

    final now = DateTime.now();

    // 1. STARTUP COOLDOWN: Ignore sync events for 5 seconds after service start
    final msSinceStart = now.difference(_serviceStartTime).inMilliseconds;
    final isStartupPeriod = msSinceStart < 5000;

    // 2. BROADCAST COOLDOWN: Ignore sync for 3 seconds after we sent an update
    // This prevents the "Echo Effect" where the server sends back old data before processing our update
    final msSinceBroadcast = _lastBroadcastTime != null
        ? now.difference(_lastBroadcastTime!).inMilliseconds
        : 999999;
    final isBroadcastCooldown = msSinceBroadcast < 3000;

    // 🚀 SAFE SYNC (Loop Breaker Pattern for Shuffle/Loop)
    // Only dispatch if state DIFFERS from what we last sent (ignores echoes).
    final newShuffle = data['is_shuffle'] as bool?;
    final newLoop = data['loop_mode'] as int?;

    bool hasNewState = false;
    bool shuffleChanged = newShuffle != null && newShuffle != _lastShuffle;
    bool loopChanged = newLoop != null && newLoop != _lastLoop;

    if (shuffleChanged || loopChanged) {
      if (isStartupPeriod) {
        debugPrint(
            "📡 [Remote] Sync IGNORED (startup cooldown): Shuffle=$newShuffle, Loop=$newLoop");
      } else if (isBroadcastCooldown) {
        debugPrint(
            "📡 [Remote] Sync IGNORED (broadcast cooldown): Shuffle=$newShuffle, Loop=$newLoop");
      } else {
        // After startup and cooldown, accept server sync commands
        if (shuffleChanged) _lastShuffle = newShuffle;
        if (loopChanged) _lastLoop = newLoop;
        hasNewState = true;
      }
    }

    if (hasNewState) {
      debugPrint(
          "📡 [Remote] Sync State Detected: Shuffle=$newShuffle, Loop=$newLoop");
      onCommand('sync_state', data);
    }

    final cmd = data['last_command'] as String?;

    if (cmd != null && cmd.isNotEmpty && cmd != 'none') {
      // Robust Deduplication
      if (cmd != _lastCommandId) {
        // 1. Parse Timestamp first to validate Age
        final parts = cmd.split('|');
        if (parts.length < 2) return; // Invalid format

        final timestampStr = parts.last;
        final timestampMs = int.tryParse(timestampStr) ?? 0;

        // 2. CHECK: Is command OLDER than Service Start? (Stale command on startup)
        final serviceStartMs = _serviceStartTime.millisecondsSinceEpoch;

        if (timestampMs < (serviceStartMs - 5000)) {
          _lastCommandId = cmd;
          debugPrint("📡 Ignoring stale command (Startup): ${parts[0]}");
          return;
        }

        final action = parts[0];

        // Extract packed payload if present
        String? packedPayload;
        if (parts.length > 2) {
          packedPayload = parts.sublist(1, parts.length - 1).join('|');
        }

        // Execute Command
        final val = data['volume']; // Optional value
        final payload = packedPayload ?? data['cmd_payload'];

        onCommand(action, payload ?? val);

        _lastCommandId = cmd; // Update ID
      }
    }
  }

  void stopListening() {
    _pollingTimer?.cancel();
    PocketBaseService().unsubscribe();
  }

  // Broadcast current player state
  void broadcastState({
    String? title,
    String? artist,
    bool? isPlaying,
    double? volume,
    bool? isShuffle,
    int? loopMode,
    int? positionSeconds,
    int? durationSeconds,
    String? artUrl,
    String? filePath, // Keep filePath as it was in the original signature
    List<Map<String, dynamic>>? queue,
    Map<String, dynamic>? albumDetails,
  }) {
    if (_userId == null) return;

    _lastBroadcastTime = DateTime.now(); // 🚀 Record Broadcast Time

    final data = <String, dynamic>{};
    if (title != null) data['current_title'] = title;
    if (artist != null) data['current_artist'] = artist;
    if (isPlaying != null) data['is_playing'] = isPlaying;
    if (volume != null) data['volume'] = volume;
    if (isShuffle != null) {
      _lastShuffle = isShuffle; // Loop Breaker: Update local state
      data['is_shuffle'] = isShuffle;
    }
    if (loopMode != null) {
      _lastLoop = loopMode; // Loop Breaker: Update local state
      data['loop_mode'] = loopMode;
    }
    if (positionSeconds != null) data['position_seconds'] = positionSeconds;
    if (durationSeconds != null) data['duration_seconds'] = durationSeconds;
    if (artUrl != null)
      data['album_art_url'] = artUrl; // Use album_art_url consistent with web
    if (queue != null) data['queue'] = queue;
    if (albumDetails != null)
      data['active_album_details'] = albumDetails; // NEW

    // Always update last active
    data['last_active'] = DateTime.now().toIso8601String();

    // 🚀 CONSUME COMMAND: Clear it so we don't process it again (Echo Loop Fix)
    data['last_command'] = '';

    PocketBaseService().updateSession(data);
  }

  // Broadcast Search Results (Party Mode)
  void updateSearchResults(dynamic results) {
    if (_userId == null) return;

    PocketBaseService().updateSession({
      'search_results': results,
      'last_update': DateTime.now().toIso8601String(),
    });
  }
}
