import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/schemas.dart';
import '../models/song_model.dart';
import 'pocketbase_service.dart';

class MetricsService {
  static final MetricsService _instance = MetricsService._internal();
  factory MetricsService() => _instance;
  MetricsService._internal();

  bool _initialized = false;
  bool get initialized => _initialized;
  String? _userId;
  String? get userId => _userId;

  // 🚀 LOCAL SESSION TRACKING (for accurate quota enforcement)
  int _sessionDownloadCount = 0;
  DateTime? _sessionStartDate;
  int? _cachedDailyCountAtStart;

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 0. Load Persistent Device ID
      _userId = await _getStableUserId();
      debugPrint("📊 MetricsService: Stable Device ID loaded: $_userId");

      // 1. Initialize PocketBase (Unified for all platforms)
      debugPrint("🚀 Initializing PocketBase Service...");
      await PocketBaseService().init(userId: _userId);

      _initialized = true;

      // 2. Track App Open (Session)
      _trackEvent('app_session_start', {
        'platform': defaultTargetPlatform.name,
        'timestamp': _serverTimestamp(),
      });

      // 3. Start Heartbeat (UNLIMITED ENABLED!)
      _startHeartbeat();

      // 4. Update Identity info
      debugPrint("📊 MetricsService: Updating Identity...");
      await _updateUserIdentity();
      debugPrint("📊 MetricsService: Identity Updated.");
    } catch (e) {
      debugPrint("⚠️ MetricsService Init Error: $e");
      _initialized = true; // Non-blocking failure
    }
  }

  // --- CORE WRAPPER ---

  // POCKETBASE WRITE HELPER
  Future<void> _pbWrite(Map<String, dynamic> fields) async {
    await PocketBaseService().saveData(fields);
  }

  // Legacy Redirects
  Future<void> _restWrite(
      String collectionPath, String docId, Map<String, dynamic> fields,
      {bool isUpdate = false}) async {
    await _pbWrite(fields);
  }

  Future<void> _restAdd(
      String collectionPath, Map<String, dynamic> fields) async {
    // For 'add', we just merge it into the user's record or ignore if it's an event
    // Events might ideally go to a separate 'events' collection, but for now we simplify.
    // If it's a critical event, we log it.
    // Ensure we don't overwrite main 'metrics' with random event data unless intended.
    // Actually _trackEvent calls this.
    // transforming event to log?
    // Let's just log it to console or ignore for now as users own DB.
    debugPrint("PB Log: $fields");
  }

  dynamic _serverTimestamp() {
    return DateTime.now().toUtc().toIso8601String();
  }

  Future<void> _trackEvent(String eventName, Map<String, dynamic> data) async {
    if (!_initialized || _userId == null) return;
    // Optional: Log events to PocketBase if desired
    // await _pbWrite({'last_event': eventName, ...data});
  }

  // --- SPECIFIC ACTIONS ---

  Future<void> trackSongPlay(Song song, {int? localTotal}) async {
    // Increment Total Plays
    await _incrementUserStat('play_count');
    // Sync Local Total
    if (localTotal != null) {
      await _restWrite(
          'metrics',
          _userId!,
          {
            'local_total_plays': localTotal,
            'play_count': localTotal, // Force sync
          },
          isUpdate: true);
    }
  }

  Future<void> trackSongPlayModel(SongModel song, {int? localTotal}) async {
    await _incrementUserStat('play_count');
    if (localTotal != null) {
      await _restWrite(
          'metrics',
          _userId!,
          {
            'local_total_plays': localTotal,
            'play_count': localTotal,
          },
          isUpdate: true);
    }
  }

  Future<void> trackDownload(Song song) async {
    await _incrementUserStat('download_count');
  }

  Future<void> trackDownloadMetadata(dynamic metadata) async {
    // 🚀 INCREMENT LOCAL SESSION COUNTER FIRST (instant, no race condition)
    _sessionDownloadCount++;
    debugPrint("📊 Session download count: $_sessionDownloadCount");

    // Then sync to PocketBase (async, might have delay)
    await _incrementUserStat('download_count');
  }

  // --- LIMITS & QUOTA ---

  static const int dailyDownloadLimit = 50;

  // Check if user is banned
  Future<bool> isUserBanned() async {
    try {
      final currentData = await PocketBaseService().getUserMetrics();
      if (currentData == null) return false;
      return currentData['is_banned'] == true;
    } catch (e) {
      debugPrint("⚠️ Ban Check Error: $e");
      return false; // On error, allow access
    }
  }

  Future<bool> canDownload() async {
    // Check ban status first
    final banned = await isUserBanned();
    if (banned) {
      debugPrint("⛔ User is banned - download blocked");
      return false;
    }

    // Check quota
    final remaining = await getRemainingQuota();
    return remaining > 0;
  }

  Future<int> getRemainingQuota() async {
    try {
      final now = DateTime.now().toUtc();

      // 🚀 CHECK IF LOCAL SESSION IS FROM TODAY
      if (_sessionStartDate != null) {
        final sessionDate = _sessionStartDate!;
        if (sessionDate.year != now.year ||
            sessionDate.month != now.month ||
            sessionDate.day != now.day) {
          // New day - reset local session
          _sessionDownloadCount = 0;
          _sessionStartDate = now;
          _cachedDailyCountAtStart = null;
        }
      }

      final currentData = await PocketBaseService().getUserMetrics();
      if (currentData == null)
        return dailyDownloadLimit - _sessionDownloadCount;

      // Check if user is banned - return 0 quota
      if (currentData['is_banned'] == true) {
        return 0;
      }

      // Check if it's a new day
      final lastDateStr = currentData['last_download_date'];
      int serverDailyCount = currentData['daily_download_count'] ?? 0;

      if (lastDateStr != null && lastDateStr.isNotEmpty) {
        try {
          final lastDate = DateTime.parse(lastDateStr).toUtc();

          // If it's a new day, reset server count
          if (lastDate.year != now.year ||
              lastDate.month != now.month ||
              lastDate.day != now.day) {
            serverDailyCount = 0;
          }
        } catch (e) {
          // Parse error, assume count is valid
        }
      }

      // 🚀 CACHE THE SERVER COUNT AT START OF SESSION
      if (_cachedDailyCountAtStart == null) {
        _cachedDailyCountAtStart = serverDailyCount;
        _sessionStartDate = now;
        _sessionDownloadCount = 0; // Reset session count when caching
      }

      // 🚀 USE LOCAL SESSION COUNTER FOR ACCURATE REAL-TIME QUOTA
      // Total = cached server count at start + downloads in this session
      final effectiveCount = _cachedDailyCountAtStart! + _sessionDownloadCount;

      debugPrint(
          "📊 Quota Check: server=$serverDailyCount, cached=$_cachedDailyCountAtStart, session=$_sessionDownloadCount, effective=$effectiveCount");

      return (dailyDownloadLimit - effectiveCount).clamp(0, dailyDownloadLimit);
    } catch (e) {
      debugPrint("⚠️ Get Quota Error: $e");
      // On error, use local session count as fallback
      return (dailyDownloadLimit - _sessionDownloadCount)
          .clamp(0, dailyDownloadLimit);
    }
  }

  // --- COUNTERS ---

  Future<void> _incrementUserStat(String fieldName) async {
    if (!_initialized || _userId == null) return;

    try {
      // 1. Fetch Current Data
      final currentData = await PocketBaseService().getUserMetrics();
      final Map<String, dynamic> updates = {};

      // 2. Prepare Current Values
      int currentTotal = 0;
      int currentDaily = 0;
      String? lastDateStr;

      // Determine which daily field matches the total field
      String dailyFieldName = '';
      String dateFieldName = '';

      if (fieldName == 'play_count') {
        currentTotal = currentData?['play_count'] ?? 0;
        currentDaily = currentData?['daily_play_count'] ?? 0;
        lastDateStr = currentData?['last_play_date'];
        dailyFieldName = 'daily_play_count';
        dateFieldName = 'last_play_date';
      } else if (fieldName == 'download_count') {
        currentTotal = currentData?['download_count'] ?? 0;
        currentDaily = currentData?['daily_download_count'] ?? 0;
        lastDateStr = currentData?['last_download_date'];
        dailyFieldName = 'daily_download_count';
        dateFieldName = 'last_download_date';
      }

      // 3. Logic: Daily Reset Check
      final now = DateTime.now().toUtc();
      bool isNewDay = true;

      if (lastDateStr != null && lastDateStr.isNotEmpty) {
        try {
          final lastDate = DateTime.parse(lastDateStr).toUtc();
          if (lastDate.year == now.year &&
              lastDate.month == now.month &&
              lastDate.day == now.day) {
            isNewDay = false;
          }
        } catch (e) {
          // ignore parse errors, assume new day
        }
      }

      if (isNewDay) {
        currentDaily = 0; // Reset for new day
      }

      // 4. Increment
      currentTotal += 1;
      currentDaily += 1;

      // 5. Prepare Payload
      updates[fieldName] = currentTotal;
      if (dailyFieldName.isNotEmpty) {
        updates[dailyFieldName] = currentDaily;
      }
      if (dateFieldName.isNotEmpty) {
        updates[dateFieldName] = now.toIso8601String();
      }

      // Always update last active
      updates['last_active'] = now.toIso8601String();

      // 6. Write Back
      await _restWrite('metrics', _userId!, updates, isUpdate: true);

      debugPrint(
          "📊 Verified Increment: $fieldName=$currentTotal, Daily=$currentDaily");
    } catch (e) {
      debugPrint("⚠️ Increment Error: $e");
    }
  }

  // --- HEARTBEAT ---

  void _startHeartbeat() {
    // Send immediate heartbeat on startup
    if (_initialized && _userId != null) {
      PocketBaseService().sendHeartbeat();
    }

    // Then send every 45 seconds
    Stream.periodic(const Duration(seconds: 45)).listen((_) {
      if (_initialized && _userId != null) {
        PocketBaseService().sendHeartbeat();
      }
    });
  }

  // --- IDENTITY ---

  Future<void> _updateUserIdentity() async {
    if (!_initialized || _userId == null) return;
    try {
      final hostname = Platform.localHostname;
      final os = Platform.operatingSystem;
      final osVersion = Platform.operatingSystemVersion;

      await _restWrite(
          'metrics',
          _userId!,
          {
            'hostname': hostname,
            'os': os,
            'os_version': osVersion,
            'last_active': DateTime.now().toUtc().toIso8601String(),
          },
          isUpdate: true);
    } catch (e) {
      debugPrint("⚠️ Update Identity Error: $e");
    }
  }

  Future<void> syncLocalStats(int localTotal) async {
    if (!_initialized || _userId == null) return;
    try {
      await _restWrite(
          'metrics',
          _userId!,
          {
            'local_total_plays': localTotal,
            'play_count': localTotal,
          },
          isUpdate: true);
    } catch (e) {
      debugPrint("⚠️ Sync Local Stats Error: $e");
    }
  }

  // --- HARDWARE ID ---

  Future<String> _getStableUserId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String rawId = '';

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        rawId = webInfo.userAgent ?? 'web_user';
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        rawId = winInfo.deviceId;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        rawId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        rawId = iosInfo.identifierForVendor ?? 'ios_user';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        rawId = macInfo.systemGUID ?? 'mac_user';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        rawId = linuxInfo.machineId ?? 'linux_user';
      } else {
        rawId = "fallback_${Platform.localHostname}";
      }

      final bytes = utf8.encode(rawId);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      debugPrint("⚠️ Hardware ID Error: $e");
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString('unique_device_id');
      if (id == null) {
        id = DateTime.now().millisecondsSinceEpoch.toString() +
            (1000 + (DateTime.now().microsecond % 9000)).toString();
        await prefs.setString('unique_device_id', id);
      }
      return id;
    }
  }

  // --- STUBS FOR ADMIN (Removed/Disabled) ---
  // Returns: 'admin', 'viewer', or null
  Future<String?> verifyAdminCode(String code) async {
    return await PocketBaseService().verifyAdminAccessCode(code);
  }

  // --- ADMIN FUNCTIONALITY ---

  Stream<List<AdminUserData>> getAllUserMetrics() {
    // Poll every 1 second for "Live" feel
    return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
      final data = await PocketBaseService().fetchAllMetrics();
      return data
          .map((d) => AdminUserData(id: d['user_id'] ?? 'unknown', data: d))
          .toList();
    }).asBroadcastStream();
  }

  Future<void> adminAction(String userId, String action,
      {String? recordId}) async {
    // For delete, we need the PocketBase record ID, not the user_id
    // Other actions use user_id to find and update

    final updateData = <String, dynamic>{};

    if (action == 'ban') {
      updateData['is_banned'] = true;
    } else if (action == 'unban') {
      updateData['is_banned'] = false;
    } else if (action == 'reset_quota') {
      updateData['daily_download_count'] = 0;
    } else if (action == 'delete') {
      // Delete requires the record ID
      if (recordId != null) {
        final success = await PocketBaseService().deleteMetricsRecord(recordId);
        if (success) {
          debugPrint("🗑️ Admin deleted user: $userId");
        }
      } else {
        debugPrint("⚠️ Delete failed: No record ID provided");
      }
      return;
    }

    if (updateData.isNotEmpty) {
      await _restWrite('metrics', userId, updateData, isUpdate: true);
    }
  }
}

class AdminUserData {
  final String id;
  final Map<String, dynamic> data;
  AdminUserData({required this.id, required this.data});
}
