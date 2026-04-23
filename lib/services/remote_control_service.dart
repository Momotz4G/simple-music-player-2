import 'dart:async';
import 'dart:convert';
import 'package:simple_music_player_2/services/metrics_service.dart';
import 'package:simple_music_player_2/services/pocketbase_service.dart';
import 'package:simple_music_player_2/services/debug_log_service.dart';

class RemoteControlService {
  static final RemoteControlService _instance =
      RemoteControlService._internal();
  factory RemoteControlService() => _instance;
  RemoteControlService._internal();

  String? _userId;
  String? _deviceId;
  String? _deviceName;
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
    _deviceId = await metrics.getDeviceIdentifier();
    _deviceName = await metrics.getDeviceName();

    if (_userId != null) {
      DebugLogService().info("📡 Remote: Active for User: $_userId, Device: $_deviceName");
      // Start Heartbeat
      registerHeartbeat();
    } else {
      DebugLogService().error("📡 Remote Error: No user ID provided. Discovery disabled.");
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
    DebugLogService().info("📡 Remote: Initial state - Shuffle=$shuffle, Loop=$loopMode");
  }

  Timer? _pollingTimer;

  // Start listening for commands
  Future<void> startListening(
      {required Function(String action, dynamic value) onCommand}) async {
    
    // 0. FETCH INITIAL STATE IMMEDIATELY
    final initialSession = await PocketBaseService().getSessionData();
    if (initialSession != null) {
      _checkAndProcessCommand(initialSession, onCommand, isInitial: true);
    }
    
    // 1. Setup Realtime Subscription (Best Effort)
    await PocketBaseService().subscribeToSession((data) {
      _checkAndProcessCommand(data, onCommand);
    });

    // 2. Setup Polling Fallback (Reliability)
    // Run every 1.5 seconds to ensure fast remote control feeling if Realtime SSE drops
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (_userId == null) return;
      final sessionData = await PocketBaseService().getSessionData();
      if (sessionData != null) {
        _checkAndProcessCommand(sessionData, onCommand);
      }
    });
  }

  final DateTime _serviceStartTime = DateTime.now();

  // 🚀 Continuous sync dedup tracking (prevents spamming identical data to slaves)
  String? _lastSyncTitle;
  double _lastSyncPosition = -1.0;
  bool? _lastSyncPlaying;

  DateTime? _lastShuffleChangeTime;
  DateTime? _lastLoopChangeTime;
  void _checkAndProcessCommand(
      Map<String, dynamic> data, Function(String, dynamic) onCommand, {bool isInitial = false}) {

    final now = DateTime.now();

    // 1. STARTUP COOLDOWN: Ignore sync events for 5 seconds after service start
    // UNLESS this is the explicit initial fetch
    final msSinceStart = now.difference(_serviceStartTime).inMilliseconds;
    final isStartupPeriod = msSinceStart < 5000 && !isInitial;

    // 2. STATE COOLDOWNS: Ignore syncs for only the specific properties we recently changed
    final msSinceShuffle = _lastShuffleChangeTime != null
        ? now.difference(_lastShuffleChangeTime!).inMilliseconds
        : 999999;
    final msSinceLoop = _lastLoopChangeTime != null
        ? now.difference(_lastLoopChangeTime!).inMilliseconds
        : 999999;

    final isShuffleCooldown = msSinceShuffle < 3000;
    final isLoopCooldown = msSinceLoop < 3000;

    // 🚀 Check if this is an empty/newly created session (no active song)
    // If it is, DO NOT adopt its default false/0 values because it will reset the local player
    final title = data['current_title'] as String?;
    final isNewEmptySession = title == null || title.isEmpty;

    // 🚀 SAFE SYNC (Loop Breaker Pattern for Shuffle/Loop)
    // Only dispatch if state DIFFERS from what we last sent AND is not in isolated cooldown.
    final newShuffle = data['is_shuffle'] as bool?;
    final newLoop = data['loop_mode'] as int?;

    bool hasNewState = false;
    bool shuffleChanged = newShuffle != null && newShuffle != _lastShuffle;
    bool loopChanged = newLoop != null && newLoop != _lastLoop;

    // Reject sync if it's an empty session
    if (!isNewEmptySession) {
        if (isStartupPeriod) {
          DebugLogService().info("📡 Remote: Sync IGNORED (startup cooldown)");
        } else {
        // Evaluate Shuffle
        if (shuffleChanged) {
          if (isShuffleCooldown) {
            DebugLogService().info("📡 Remote: Shuffle Sync IGNORED (cooldown)");
          } else {
            _lastShuffleChangeTime = DateTime.now(); // 🚀 Prevent stale data echo from polling
            _lastShuffle = newShuffle;
            hasNewState = true;
          }
        }
        
        // Evaluate Loop
        if (loopChanged) {
          if (isLoopCooldown) {
            DebugLogService().info("📡 Remote: Loop Sync IGNORED (cooldown)");
          } else {
            _lastLoopChangeTime = DateTime.now(); // 🚀 Prevent stale data echo from polling
            _lastLoop = newLoop;
            hasNewState = true;
          }
        }
      }
    }

    if (hasNewState) {
      DebugLogService().info("📡 Remote: Sync State Detected: Shuffle=$newShuffle, Loop=$newLoop");
      onCommand('sync_state', data);
    }

    // 🚀 CONTINUOUS SYNC: Always dispatch sync_state for slave UI updates
    // This ensures slaves receive position, title, art, and isPlaying changes
    // even when shuffle/loop haven't changed. Dedup prevents spamming identical data.
    if (!isStartupPeriod && !isNewEmptySession && !hasNewState) {
      final syncPos = (data['position_seconds'] as num?)?.toDouble() ?? 0.0;
      final syncPlaying = data['is_playing'] as bool?;
      final syncTitle = data['current_title'] as String?;

      final titleChanged = syncTitle != _lastSyncTitle;
      final posChanged = (syncPos - _lastSyncPosition).abs() > 0.5; // 🚀 HIGH PRECISION: 0.5s threshold
      final playChanged = syncPlaying != _lastSyncPlaying;

      if (titleChanged || posChanged || playChanged) {
        _lastSyncTitle = syncTitle;
        _lastSyncPosition = syncPos;
        _lastSyncPlaying = syncPlaying;
        onCommand('sync_state', data);
      }
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
          DebugLogService().info("📡 Remote: Ignoring stale command: ${parts[0]}");
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

  // --- DEVICE MANAGEMENT ---

  Timer? _heartbeatTimer;

  void registerHeartbeat() {
    _heartbeatTimer?.cancel();
    // Immediate heartbeat
    _updateDeviceListInSession();
    // Repeating heartbeat
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateDeviceListInSession();
    });
  }

  Future<void> _updateDeviceListInSession() async {
    if (_userId == null || _deviceId == null || _deviceName == null) return;

    try {
      final session = await PocketBaseService().getSessionData();
      if (session == null) return;

      dynamic rawDevices = session['available_devices'];
      List<dynamic> devices = [];
      if (rawDevices is List) {
        devices = List<dynamic>.from(rawDevices);
      } else if (rawDevices is String && rawDevices.isNotEmpty) {
        try {
          devices = jsonDecode(rawDevices) as List<dynamic>;
        } catch (_) {}
      }

      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      bool found = false;

      // Filter out stale devices (not seen for > 2 minutes)
      final cutoff = now.subtract(const Duration(minutes: 2));
      
      List<dynamic> activeDevices = [];
      for (var d in devices) {
        if (d is Map<String, dynamic>) {
          final lastActiveStr = d['last_active'];
          if (lastActiveStr != null) {
            try {
              final lastActive = DateTime.parse(lastActiveStr);
              if (lastActive.isAfter(cutoff) || d['id'] == _deviceId) {
                 activeDevices.add(d);
              }
            } catch (_) {
              activeDevices.add(d); 
            }
          }
        }
      }

      for (int i = 0; i < activeDevices.length; i++) {
        final d = activeDevices[i] as Map<String, dynamic>;
        if (d['id'] == _deviceId) {
          activeDevices[i] = {
            'id': _deviceId,
            'name': _deviceName,
            'last_active': nowIso,
          };
          found = true;
          break;
        }
      }

      if (!found) {
        activeDevices.add({
          'id': _deviceId,
          'name': _deviceName,
          'last_active': nowIso,
        });
      }

      await PocketBaseService().updateSession({'available_devices': activeDevices});
      
      final deviceListSummary = activeDevices.map((d) => d['id']?.toString().substring(0, 4)).join(', ');
      DebugLogService().success("📡 Remote: Heartbeat sent. Total: ${activeDevices.length} [$deviceListSummary]");
    } catch (e) {
      DebugLogService().error("⚠️ Remote Heartbeat FAILED: $e");
    }
  }

  /// Update the active device ID in the cloud session
  Future<void> setActiveDevice(String deviceId, String name) async {
    try {
      await PocketBaseService().updateSession({
        'active_device_id': deviceId,
        'active_device_name': name,
        'last_command': 'adopt_master', // Optional hint
      });
      DebugLogService().success("📡 Remote: Nominated $name as active player");
    } catch (e) {
      DebugLogService().error("⚠️ Remote: Failed to set active device: $e");
    }
  }

  void stopListening() {
    _pollingTimer?.cancel();
    _heartbeatTimer?.cancel();
    PocketBaseService().unsubscribe();
  }

  // Broadcast current player state
  void broadcastState({
    String? title,
    String? artist,
    String? album,
    bool? isPlaying,
    double? volume,
    bool? isShuffle,
    int? loopMode,
    num? positionSeconds, // 🚀 HIGH PRECISION: Accepts double
    num? durationSeconds, // 🚀 HIGH PRECISION: Accepts double
    String? artUrl,
    String? filePath,
    String? sourceUrl,
    String? spotifyId,
    List<Map<String, dynamic>>? queue,
    Map<String, dynamic>? albumDetails,
    bool forceActive = false,
  }) async {
    if (_userId == null || _deviceId == null) return;

    final data = <String, dynamic>{};
    if (title != null) data['current_title'] = title;
    if (artist != null) data['current_artist'] = artist;
    if (album != null) data['current_album'] = album;
    if (isPlaying != null) data['is_playing'] = isPlaying;
    if (volume != null) data['volume'] = volume;
    if (isShuffle != null) {
      if (_lastShuffle != isShuffle) {
        _lastShuffleChangeTime = DateTime.now();
      }
      _lastShuffle = isShuffle;
      data['is_shuffle'] = isShuffle;
    }
    if (loopMode != null) {
      if (_lastLoop != loopMode) {
        _lastLoopChangeTime = DateTime.now();
      }
      _lastLoop = loopMode;
      data['loop_mode'] = loopMode;
    }
    if (positionSeconds != null) data['position_seconds'] = positionSeconds;
    if (durationSeconds != null) data['duration_seconds'] = durationSeconds;
    
    // 🚀 STALE CACHE FIX: If artUrl is null, explicitly clear the PocketBase entry 
    // so it doesn't accidentally retain the previous song's image during a PATCH update!
    if (artUrl != null) {
      data['album_art_url'] = artUrl;
    } else if (title != null) {
      data['album_art_url'] = ''; 
    }

    if (sourceUrl != null) data['source_url'] = sourceUrl;
    if (spotifyId != null) data['spotify_id'] = spotifyId;
    if (queue != null) data['queue'] = queue;
    if (albumDetails != null) data['active_album_details'] = albumDetails;

    // 🚀 MASTER DECLARATION: If we are broadcasting state, we mark ourselves as active
    // UNLESS we are in Follower mode (handled by PlayerProvider)
    if (forceActive || (isPlaying == true)) {
      data['active_device_id'] = _deviceId;
      data['active_device_name'] = _deviceName;
    }

    data['last_active'] = DateTime.now().toIso8601String();
    data['last_command'] = '';

    await PocketBaseService().updateSession(data);
  }

  // --- COMMAND HANDLING ---

  Future<void> sendCommand(String action, {dynamic payload}) async {
    if (_userId == null) return;
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cmdId = "$action|${payload ?? ''}|$timestamp";
    
    await PocketBaseService().updateSession({
      'last_command': cmdId,
      'cmd_payload': payload,
    });
    DebugLogService().info("📡 Remote Command SENT: $action");
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
