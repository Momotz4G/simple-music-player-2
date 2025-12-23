import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../env/env.dart';

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  factory PocketBaseService() => _instance;
  PocketBaseService._internal();

  // 🚀 YOUR SERVER URL (Cloudflare Tunnel - Permanent Public Access)
  final pb = PocketBase(Env.pocketbaseUrl);

  bool _initialized = false;
  String? _userId;

  Future<void> init({String? userId}) async {
    if (_initialized) return;
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

      debugPrint("🚀 PocketBaseService: Initialized for User: $_userId");
      _initialized = true;
    } catch (e) {
      debugPrint("⚠️ PB Init Error: $e");
    }
  }

  String? _cachedMetricsId; // Cache metrics record ID
  static const _networkTimeout =
      Duration(seconds: 5); // 🚀 Timeout for network calls

  // SAVE DATA (Upsert: Create or Update) - No List permission needed
  Future<void> saveData(Map<String, dynamic> data) async {
    if (!_initialized || _userId == null) return;

    // 1. Try to use cached metrics record ID
    if (_cachedMetricsId != null) {
      try {
        await pb
            .collection('metrics')
            .update(_cachedMetricsId!, body: data)
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
              .update(storedId, body: data)
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
        await pb
            .collection('metrics')
            .update(existingId, body: data)
            .timeout(_networkTimeout);
        _cachedMetricsId = existingId;

        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pb_metrics_id', existingId);

        debugPrint("📊 Found and updated existing metrics record: $existingId");
        return;
      }
    } catch (e) {
      debugPrint("⚠️ Search existing record error: $e");
      // Continue to create new record if search fails
    }

    // 4. Create new record (only if no existing record found)
    try {
      // 🚀 Include hostname in initial record creation
      String hostname = 'Unknown';
      try {
        hostname = Platform.localHostname;
      } catch (_) {}

      final rec = await pb.collection('metrics').create(body: {
        'user_id': _userId,
        'hostname': hostname,
        'os': Platform.operatingSystem,
        ...data,
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
  Future<List<Map<String, dynamic>>> fetchAllMetrics() async {
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
            perPage: 100, // Reasonable limit for now
            sort: '-last_active',
          );
      return records.items.map((r) => r.data..['id'] = r.id).toList();
    } catch (e) {
      debugPrint("⚠️ Admin Fetch Error: $e");
      return [];
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
  Future<String?> getUniqueSessionId() async {
    return _ensureUniqueSession();
  }

  Future<String?> _ensureUniqueSession() async {
    if (!_initialized || _userId == null) return null;

    // 1. Try cached session ID first
    if (_cachedSessionId != null) {
      try {
        // Verify it still exists (only needs View permission)
        await pb.collection('sessions').getOne(_cachedSessionId!);
        return _cachedSessionId;
      } catch (e) {
        // Session was deleted, clear cache
        _cachedSessionId = null;
      }
    }

    // 2. Try to load from local storage
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

    // 3. Create new session (only needs Create permission)
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
      await pb.collection('sessions').update(recordId, body: data);
    } catch (e) {
      debugPrint("⚠️ Session Update Error: $e");
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
          debugPrint("📡 Pushing update to listener: $data");
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
}
