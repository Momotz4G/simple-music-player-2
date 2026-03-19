import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';
import '../env/env.dart';
import 'debug_log_service.dart';

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  factory PocketBaseService() => _instance;
  PocketBaseService._internal();

  // 🚀 YOUR SERVER URL (Cloudflare Tunnel - Permanent Public Access)
  final pb = PocketBase(Env.pocketbaseUrl);

  bool _initialized = false;
  String? _userId;

  Future<void> init({String? userId}) async {
    if (_initialized && _userId != null) return;
    try {
      if (userId != null) {
        _userId = userId;
      } else {
        // Load or Create Stable ID (Fallback)
        final prefs = await SharedPreferences.getInstance();
        _userId = prefs.getString('pb_user_id');
        if (_userId == null) {
          _userId = "user_${DateTime.now().millisecondsSinceEpoch}";
          await prefs.setString('pb_user_id', _userId!);
        }
      }

      DebugLogService().info("🚀 PocketBaseService: Initialized for User: $_userId");
      _initialized = true;
    } catch (e) {
      DebugLogService().error("⚠️ PB Init Error: $e");
      debugPrint("⚠️ PB Init Error: $e");
    }
  }

  /// 🚀 Wait for initialization to complete if it hasn't already
  Future<void> _ensureInitialized() async {
    if (_initialized && _userId != null) return;
    
    // If not initialized, try one more quick local init or wait
    int retries = 0;
    while (!_initialized && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      retries++;
    }
    
    if (!_initialized) {
      DebugLogService().error("⚠️ PocketBaseService: Failed to initialize after waiting.");
      throw Exception("PocketBase not initialized");
    }
  }

  String? _cachedMetricsId; // Cache metrics record ID
  String? _cachedHostname; // Cache device name
  static const _networkTimeout =
      Duration(seconds: 5); // 🚀 Timeout for network calls

  Future<String> _getDeviceName() async {
    if (_cachedHostname != null) return _cachedHostname!;

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _cachedHostname = "${androidInfo.manufacturer} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _cachedHostname = "${iosInfo.name} (${iosInfo.model})";
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        _cachedHostname = winInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _cachedHostname = linuxInfo.prettyName;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        _cachedHostname = macInfo.computerName;
      } else {
        _cachedHostname = Platform.localHostname;
      }
    } catch (e) {
      _cachedHostname = "Unknown Device";
    }
    return _cachedHostname!;
  }

  // SAVE DATA (Upsert: Create or Update) - No List permission needed
  Future<void> saveData(Map<String, dynamic> data) async {
    if (!_initialized || _userId == null) return;

    // 🚀 Inject Real Hostname
    final hostname = await _getDeviceName();
    final dataWithHost = {...data, 'hostname': hostname};

    // 1. Try to use cached metrics record ID
    if (_cachedMetricsId != null) {
      try {
        await pb
            .collection('metrics')
            .update(_cachedMetricsId!, body: dataWithHost)
            .timeout(_networkTimeout);
        return;
      } catch (e) {
        // Record might be deleted or timeout, clear cache
        _cachedMetricsId = null;
      }
    }

    // 2. Try to load from local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getString('pb_metrics_id');
      if (storedId != null) {
        try {
          await pb
              .collection('metrics')
              .update(storedId, body: dataWithHost)
              .timeout(_networkTimeout);
          _cachedMetricsId = storedId;
          return;
        } catch (e) {
          // Stored record no longer exists or timeout
          await prefs.remove('pb_metrics_id');
        }
      }
    } catch (e) {
      debugPrint("⚠️ Metrics storage error: $e");
    }

    // 3. 🚀 SEARCH for existing record by user_id BEFORE creating new one
    try {
      final existingRecords = await pb
          .collection('metrics')
          .getList(
            page: 1,
            perPage: 1,
            filter: 'user_id = "$_userId"',
          )
          .timeout(_networkTimeout);

      if (existingRecords.items.isNotEmpty) {
        // Found existing record - update it
        final existingId = existingRecords.items.first.id;
        try {
          await pb
              .collection('metrics')
              .update(existingId, body: dataWithHost)
              .timeout(_networkTimeout);
          _cachedMetricsId = existingId;

          // Save to local storage
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pb_metrics_id', existingId);

          debugPrint("📊 Found and updated existing metrics record: $existingId");
        } catch (e) {
          debugPrint("⚠️ Failed to update metrics record: $e");
        }
        return;
      }
    } catch (e) {
      debugPrint("⚠️ Search existing record error: $e");
      // 🚀 IF SEARCH FAILS DUE TO NETWORK ERROR, DO NOT CREATE NEW ONES!
      // ONLY create a new record if the network call successfully returned 0 items.
      return; 
    }

    // 4. Create new record (only if no existing record found and search succeeded)
    try {
      final rec = await pb.collection('metrics').create(body: {
        'user_id': _userId,
        'os': Platform.operatingSystem,
        ...dataWithHost,
      }).timeout(_networkTimeout);
      _cachedMetricsId = rec.id;

      // Store for future use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pb_metrics_id', rec.id);

      debugPrint("📊 Created new metrics record: ${rec.id} for $hostname");
    } catch (e) {
      debugPrint("⚠️ PB Write Error: $e");
    }
  }

  // GET DATA (Read Current Metrics) - No List permission needed
  Future<Map<String, dynamic>?> getUserMetrics() async {
    if (!_initialized || _userId == null) return null;

    // 1. Try cached ID
    if (_cachedMetricsId != null) {
      try {
        final record = await pb.collection('metrics').getOne(_cachedMetricsId!);
        return record.data;
      } catch (e) {
        _cachedMetricsId = null;
      }
    }

    // 2. Try to load from local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getString('pb_metrics_id');
      if (storedId != null) {
        try {
          final record = await pb.collection('metrics').getOne(storedId);
          _cachedMetricsId = storedId;
          return record.data;
        } catch (e) {
          await prefs.remove('pb_metrics_id');
        }
      }
    } catch (e) {
      debugPrint("⚠️ Metrics read storage error: $e");
    }

    // No existing record found
    return null;
  }

  // HEARTBEAT - Updates last_active for online status in admin dashboard
  Future<void> sendHeartbeat() async {
    await saveData({'last_active': DateTime.now().toUtc().toIso8601String()});
  }

  // VERIFY ADMIN/VIEWER CODE (Requires Admin Auth to read settings)
  // Returns: 'admin', 'viewer', or null if invalid
  Future<String?> verifyAdminAccessCode(String inputCode) async {
    try {
      // Authenticate as admin first to access locked settings
      // PocketBase v0.23+ uses _superusers collection
      if (!pb.authStore.isValid) {
        await pb.collection('_superusers').authWithPassword(
              Env.pocketbaseAdminEmail,
              Env.pocketbaseAdminPassword,
            );
        debugPrint("🔐 Admin authenticated successfully");
      }

      // Now we can access settings
      final records = await pb.collection('settings').getList(
            page: 1,
            perPage: 1,
          );

      if (records.items.isEmpty) return null;

      final data = records.items.first.data;
      final adminCode = data['access_code'];
      final viewerCode = data['viewer_code'];

      // Check admin code first
      if (adminCode != null && adminCode == inputCode) {
        debugPrint("🔓 Admin access granted");
        return 'admin';
      }

      // Check viewer code
      if (viewerCode != null && viewerCode == inputCode) {
        debugPrint("👁️ Viewer access granted");
        return 'viewer';
      }

      return null; // Invalid code
    } catch (e) {
      debugPrint("⚠️ Admin Verify Error: $e");
      return null;
    }
  }

  // ADMIN: FETCH ALL USERS (Requires Admin Auth)
  // Returns: { 'items': List<Map>, 'totalCount': int }
  Future<Map<String, dynamic>> fetchAllMetrics() async {
    try {
      // Authenticate as admin if not already
      // PocketBase v0.23+ uses _superusers collection
      if (!pb.authStore.isValid) {
        await pb.collection('_superusers').authWithPassword(
              Env.pocketbaseAdminEmail,
              Env.pocketbaseAdminPassword,
            );
        debugPrint("🔐 Admin authenticated successfully");
      }

      final records = await pb.collection('metrics').getList(
            page: 1,
            perPage: 100, // Preview limit
            sort: '-last_active',
          );
      return {
        'items': records.items.map((r) => r.data..['id'] = r.id).toList(),
        'totalCount': records.totalItems, // Real total from database
      };
    } catch (e) {
      debugPrint("⚠️ Admin Fetch Error: $e");
      return {'items': [], 'totalCount': 0};
    }
  }

  // ADMIN: DELETE USER METRICS RECORD
  Future<bool> deleteMetricsRecord(String recordId) async {
    try {
      // Authenticate as admin if not already
      if (!pb.authStore.isValid) {
        await pb.collection('_superusers').authWithPassword(
              Env.pocketbaseAdminEmail,
              Env.pocketbaseAdminPassword,
            );
        debugPrint("🔐 Admin authenticated for delete");
      }

      await pb.collection('metrics').delete(recordId);
      debugPrint("🗑️ Deleted metrics record: $recordId");
      return true;
    } catch (e) {
      debugPrint("⚠️ Admin Delete Error: $e");
      return false;
    }
  }

  // --- REMOTE CONTROL (SESSIONS) ---

  String? _cachedSessionId; // Cache session ID in memory

  // HELPER: ENSURE SINGLE SESSION (No List permission needed)
  Future<String?> getUniqueSessionId({bool forceRegenerate = false}) async {
    return _ensureUniqueSession(forceRegenerate: forceRegenerate);
  }

  Future<String?> _ensureUniqueSession({bool forceRegenerate = false}) async {
    if (!_initialized || _userId == null) return null;

    // 1. Force Regenerate: Delete existing records and start fresh
    if (forceRegenerate) {
      try {
        final existingRecords = await pb.collection('sessions').getList(
              page: 1,
              perPage: 50,
              filter: 'user_id = "$_userId"',
            );
        for (final item in existingRecords.items) {
          await pb.collection('sessions').delete(item.id);
        }
        _cachedSessionId = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pb_session_id');
        debugPrint("📡 Force Regenerated: Deleted old sessions for $_userId");
      } catch (e) {
        debugPrint("⚠️ Force Regenerate Error: $e");
      }
    }

    // 2. Try cached session ID first
    if (!forceRegenerate && _cachedSessionId != null) {
      try {
        // Verify it still exists (only needs View permission)
        await pb.collection('sessions').getOne(_cachedSessionId!);
        return _cachedSessionId;
      } catch (e) {
        // Session was deleted, clear cache
        _cachedSessionId = null;
      }
    }

    // 3. Try to load from local storage
    if (!forceRegenerate) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedId = prefs.getString('pb_session_id');
        if (storedId != null) {
          try {
            await pb.collection('sessions').getOne(storedId);
            _cachedSessionId = storedId;
            return storedId;
          } catch (e) {
            // Stored session no longer exists
            await prefs.remove('pb_session_id');
          }
        }
      } catch (e) {
        debugPrint("⚠️ Session storage error: $e");
      }
    }

    // 4. 🚀 SEARCH for existing session by user_id BEFORE creating new one
    try {
      final existingRecords = await pb.collection('sessions').getList(
            page: 1,
            perPage: 1,
            filter: 'user_id = "$_userId"',
          );

      if (existingRecords.items.isNotEmpty) {
        // Found existing session(s)
        final newest = existingRecords.items.first;

        _cachedSessionId = newest.id;

        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pb_session_id', newest.id);

        debugPrint("📡 Found and merged into existing session: ${newest.id}");
        return newest.id;
      }
    } catch (e) {
      debugPrint("⚠️ Search existing session error: $e");
      // IF SEARCH FAILS DUE TO NETWORK ERROR, DO NOT BLINDLY CREATE NEW ONE
      return null;
    }

    // 5. Create new session (only if no existing session found and search succeeded)
    try {
      final rec =
          await pb.collection('sessions').create(body: {'user_id': _userId});
      _cachedSessionId = rec.id;

      // Store for future use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pb_session_id', rec.id);

      debugPrint("📡 Created new session: ${rec.id}");
      return rec.id;
    } catch (e) {
      debugPrint("⚠️ Session Create Error: $e");
      return null;
    }
  }

  // UPDATE SESSION (Broadcast State)
  Future<void> updateSession(Map<String, dynamic> data) async {
    final recordId = await _ensureUniqueSession();
    if (recordId == null) return;

    try {
      DebugLogService().info(
          "📡 PB: Updating Session $recordId with keys: ${data.keys.toList()}");
      await pb.collection('sessions').update(recordId, body: data);
      DebugLogService().info("✅ PB: Update Success");
    } catch (e) {
      DebugLogService().error("⚠️ PB: Update FAILED: $e");
      // debugPrint("⚠️ Session Update Error: $e");
    }
  }

  // GET SESSION DATA (Polling)
  Future<Map<String, dynamic>?> getSessionData() async {
    final recordId = await _ensureUniqueSession();
    if (recordId == null) return null;

    try {
      final record = await pb.collection('sessions').getOne(recordId);
      final data = record.data;
      data['updated'] = record.updated; // Manual inject
      return data;
    } catch (e) {
      debugPrint("⚠️ Session Polling Error: $e");
      return null;
    }
  }

  // SUBSCRIBE (Listen for Commands)
  Future<void> subscribeToSession(
      Function(Map<String, dynamic>) onUpdate) async {
    final recordId = await _ensureUniqueSession();
    if (recordId == null) return;

    try {
      pb.collection('sessions').subscribe(recordId, (e) {
        debugPrint("📡 EVENT RECEIVED: ${e.action} | ${e.record?.data}");
        if (e.action == 'update') {
          final data = e.record?.data ?? {};
          // Ensure 'updated' is available
          data['updated'] = e.record?.updated;
          // Data received, push to listener
          onUpdate(data);
        } else {
          debugPrint("📡 Event ignored (not update): ${e.action}");
        }
      });
      debugPrint("📡 Subscribed to Session: $recordId");
    } catch (e) {
      debugPrint("⚠️ Session Subscribe Error: $e");
    }
  }

  void unsubscribe() {
    pb.collection('sessions').unsubscribe();
  }

  // --- SHAREABLE PLAYLISTS ---

  /// Shares a playlist and returns a 6-digit share code
  Future<String?> sharePlaylist(String playlistId, Map<String, dynamic> playlistData) async {
    try {
      await _ensureInitialized();

      // 1. Check if already shared
      final existing = await pb.collection('shared_playlists').getList(
        page: 1,
        perPage: 1,
        filter: 'playlist_id = "$playlistId" && user_id = "$_userId"',
      ).timeout(_networkTimeout);

      // 2. Prepare the data
      final data = Map<String, dynamic>.from(playlistData);
      if (data['entries'] != null) {
        for (var entry in data['entries']) {
          entry.remove('path');
        }
      }

      final jsonBody = json.encode(data);
      final List<int> processedData;
      bool isCompressed = false;

      final entriesCount = (data['entries'] as List?)?.length ?? 0;
      if (entriesCount > 50 || jsonBody.length > 3000) {
        processedData = gzip.encode(utf8.encode(jsonBody));
        isCompressed = true;
      } else {
        processedData = utf8.encode(jsonBody);
      }

      final payload = {
        'user_id': _userId,
        'playlist_id': playlistId,
        'data': base64.encode(processedData),
        'is_compressed': isCompressed,
      };

      if (existing.items.isNotEmpty) {
        // Update existing record
        await pb.collection('shared_playlists').update(
          existing.items.first.id,
          body: payload,
        ).timeout(_networkTimeout);
        
        final code = existing.items.first.data['share_code'];
        DebugLogService().success("✅ Updated shared playlist: $code");
        return code;
      } else {
        // Create new record
        final shareCode = _generateShareCode();
        payload['share_code'] = shareCode;
        
        await pb.collection('shared_playlists').create(
          body: payload,
        ).timeout(_networkTimeout);

        DebugLogService().success("📦 Playlist shared with code: $shareCode");
        return shareCode;
      }
    } catch (e) {
      DebugLogService().error("⚠️ Share Playlist Error: $e");
      return null;
    }
  }

  /// Deletes a shared playlist from the database
  Future<bool> unsharePlaylist(String playlistId) async {
    try {
      await _ensureInitialized();
      
      final existing = await pb.collection('shared_playlists').getList(
        page: 1,
        perPage: 1,
        filter: 'playlist_id = "$playlistId" && user_id = "$_userId"',
      ).timeout(_networkTimeout);

      if (existing.items.isEmpty) return true;

      await pb.collection('shared_playlists').delete(existing.items.first.id).timeout(_networkTimeout);
      DebugLogService().success("🗑️ Unshared playlist: $playlistId");
      return true;
    } catch (e) {
      DebugLogService().error("⚠️ Unshare Error: $e");
      return false;
    }
  }

  /// Checks if a playlist is currently shared and returns its code
  Future<String?> getShareCode(String playlistId) async {
    try {
      await _ensureInitialized();
      
      final records = await pb.collection('shared_playlists').getList(
        page: 1,
        perPage: 1,
        filter: 'playlist_id = "$playlistId" && user_id = "$_userId"',
      ).timeout(_networkTimeout);

      if (records.items.isEmpty) return null;
      return records.items.first.data['share_code'];
    } catch (e) {
      // Don't log error here to avoid noise during idle checks
      return null;
    }
  }

  /// Fetches a shared playlist by its 6-digit code
  Future<Map<String, dynamic>?> fetchSharedPlaylist(String shareCode) async {
    if (!_initialized) return null;

    try {
      final records = await pb.collection('shared_playlists').getList(
            page: 1,
            perPage: 1,
            filter: 'share_code = "$shareCode"',
          ).timeout(_networkTimeout);

      if (records.items.isEmpty) {
        debugPrint("⚠️ No shared playlist found for code: $shareCode");
        return null;
      }

      // Return only the 'data' field, hiding the 'user_id' and other internal fields
      final record = records.items.first;
      final rawData = record.data['data'];
      final bool isCompressed = record.data['is_compressed'] ?? false;

      if (rawData == null) return null;

      String jsonStr;
      
      // 🚀 NORMALIZE DATA (Handles raw JSON, List<int>, or Base64 String)
      final List<int> bytes;
      if (rawData is String) {
        // Try to see if it's Base64. Shareable playlists now use Base64.
        try {
          bytes = base64.decode(rawData);
          // If decoding succeeded, we use the bytes
        } catch (_) {
          // If it failed, it might be raw JSON string (compatibility)
          jsonStr = rawData;
          return json.decode(jsonStr) as Map<String, dynamic>?;
        }
      } else if (rawData is List) {
        bytes = List<int>.from(rawData);
      } else if (rawData is Map) {
         // Compatibility: if it's already a map
         return rawData as Map<String, dynamic>;
      } else {
        return null;
      }

      // Handle decompression if needed
      if (isCompressed) {
        jsonStr = utf8.decode(gzip.decode(bytes));
      } else {
        jsonStr = utf8.decode(bytes);
      }

      DebugLogService().success("✅ Fetched and decoded shared playlist: $shareCode");
      return json.decode(jsonStr) as Map<String, dynamic>?;
    } catch (e) {
      DebugLogService().error("⚠️ Fetch Shared Playlist Error: $e");
      debugPrint("⚠️ Fetch Shared Playlist Error: $e");
      return null;
    }
  }

  String _generateShareCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I, O, 0, 1 to avoid confusion
    final rnd = DateTime.now().microsecondsSinceEpoch;
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[(rnd >> (i * 5)) % chars.length];
    }
    return code;
  }
}
