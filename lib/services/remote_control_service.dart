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
    // Run every 1 second to catch missed events if Realtime fails
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_userId == null) return;
      final sessionData = await PocketBaseService().getSessionData();
      if (sessionData != null) {
        _checkAndProcessCommand(sessionData, onCommand);
      }
    });
  }

  void _checkAndProcessCommand(
      Map<String, dynamic> data, Function(String, dynamic) onCommand) {
    final cmd = data['last_command'] as String?;

    if (cmd != null && cmd.isNotEmpty && cmd != 'none') {
      // Robust Deduplication
      if (cmd != _lastCommandId) {
        // Parse: "action|timestamp"
        final parts = cmd.split('|');
        final action = parts[0];

        // Execute Command
        final val = data['volume']; // Optional value
        onCommand(action, val);

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
    required String? title,
    required String? artist,
    required bool isPlaying,
    required double volume,
    required int positionSeconds,
    required int durationSeconds,
    String? artUrl,
    String? filePath,
  }) {
    if (_userId == null) return;

    // Debounce this? UI calls it often.
    // PocketBaseService handles frequency? No.
    // Let's rely on the fact that PlayerProvider calls this on valid state changes.
    // Maybe throttle it slightly to avoid 100ms updates.

    PocketBaseService().updateSession({
      'device_name': 'Desktop Client', // Could be dynamic
      'current_title': title ?? 'Unknown',
      'current_artist': artist ?? 'Unknown',
      'is_playing': isPlaying,
      'volume': volume,
      'position': positionSeconds,
      'duration': durationSeconds,
      'album_art_url': artUrl,
      'last_active': DateTime.now().toIso8601String(),
    });
  }
}
