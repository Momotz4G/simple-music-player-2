import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env/env.dart';
import 'debug_log_service.dart';
import 'auth_service.dart';

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  factory PocketBaseService() => _instance;
  PocketBaseService._internal();

  // 🚀 YOUR SERVER URL (Cloudflare Tunnel - Permanent Public Access)
  final pb = PocketBase(Env.pocketbaseUrl);

  bool _initialized = false;
  String? _userId;

  /// 🔒 OFFLINE MODE: Static flags to block network operations
  static bool isOffline = false;
  static bool enableCloudSync = true;
  static bool enableLeaderboard = true;
  static bool enableOnlineLyrics = true;
  static bool enableAiLyrics = true;
  static bool enableOnlineSearch = true;
  static bool enableRemoteControl = true;
  static bool enableCanvas = true;

  String? get userId => _userId; // 🚀 Exposed for rank verification logic

  Future<void> init({String? userId}) async {
    if (isOffline) {
      _initialized = true;
      return;
    }
    if (_initialized && userId == _userId) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // 🚀 FIX: Compare against PERSISTED user ID, not just in-memory _userId.
      // _userId is always null on first cold start, which previously caused
      // "Identity Changed" to fire every single startup (false positive).
      final persistedUserId = _userId ?? prefs.getString('pb_user_id');
      if (userId != null && persistedUserId != null && userId != persistedUserId) {
        DebugLogService().info("📡 Session: Identity Changed ($persistedUserId → $userId). Clearing stale session token.");
        _userId = userId;
        // 🚀 CRITICAL: Force clear local storage so ensureUniqueSession performs a fresh search
        await prefs.remove('pb_session_id');
        await prefs.remove('pb_metrics_id'); // Clear cached metrics ID for old identity
      }

      if (userId != null) {
        _userId = userId;
        // 🛡️ ALWAYS persist to prefs so crash recovery can find the old anonymous hash
        final prefs = await SharedPreferences.getInstance();
        final existingPbUserId = prefs.getString('pb_user_id');
        if (existingPbUserId == null) {
          await prefs.setString('pb_user_id', userId);
        }
      } else {
        // Load or Create Stable ID (Fallback)
        final prefs = await SharedPreferences.getInstance();

        // 🔗 If account is linked, ALWAYS use the linked user ID
        // This prevents the race condition where saveData() fires with
        // the old anonymous hash before migration recovery can run.
        final linkedUserId = prefs.getString('pb_linked_user_id');
        if (linkedUserId != null) {
          _userId = linkedUserId;
          // Also fix pb_user_id if it's stale
          final currentPbUserId = prefs.getString('pb_user_id');
          if (currentPbUserId != linkedUserId) {
            await prefs.setString('pb_user_id', linkedUserId);
            DebugLogService().info("🔗 PB Init: Corrected stale pb_user_id from $currentPbUserId to $linkedUserId");
          }
        } else {
          _userId = prefs.getString('pb_user_id');
          if (_userId == null) {
            _userId = "user_${DateTime.now().millisecondsSinceEpoch}";
            await prefs.setString('pb_user_id', _userId!);
          }
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
  Future<void> saveData(Map<String, dynamic> data, {File? avatarFile, bool clearAvatar = false}) async {
    if (isOffline || !enableCloudSync) return; // 🔒 OFFLINE or Cloud Sync Disabled
    if (!_initialized || _userId == null) return;

    // 🚀 Inject Real Hostname & Nickname
    final hostname = await _getDeviceName();
    final prefs = await SharedPreferences.getInstance();
    final customNickname = prefs.getString('custom_nickname');
    final selectedTitle = prefs.getString('selected_title');
    
    // 🚀 COMPETITIVE GUARD: Never auto-inject "Top X Global" from local prefs
    // These titles must be validated against actual rank before writing.
    // Without this, old clients re-push stale competitive titles on every heartbeat.
    final _competitiveTitles = {'Top 1 Global', 'Top 2 Global', 'Top 3 Global'};
    final isCompetitiveTitle = selectedTitle != null && _competitiveTitles.contains(selectedTitle);
    
    final dataWithHost = {
      ...data, 
      'hostname': hostname,
      'nickname': customNickname ?? '',
      if (!data.containsKey('selected_title') && selectedTitle != null && selectedTitle.isNotEmpty && !isCompetitiveTitle)
        'selected_title': selectedTitle,
      if (clearAvatar) 'avatar': null,
    };

    // 🔍 DEBUG: Log what's being sent to PocketBase
    if (data.containsKey('total_minutes') || data.containsKey('top_artist')) {
      debugPrint("📊 PB saveData: ADVANCED STATS payload = $dataWithHost");
    }

    // 1. Try to use cached metrics record ID
    if (_cachedMetricsId != null) {
      try {
        await pb
            .collection('metrics')
            .update(_cachedMetricsId!, 
                body: dataWithHost,
                files: avatarFile != null ? [await http.MultipartFile.fromPath('avatar', avatarFile.path)] : []
            )
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
              .update(storedId, 
                  body: dataWithHost,
                  files: avatarFile != null ? [await http.MultipartFile.fromPath('avatar', avatarFile.path)] : []
              )
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
              .update(existingId, 
                  body: dataWithHost,
                  files: avatarFile != null ? [await http.MultipartFile.fromPath('avatar', avatarFile.path)] : []
              )
              .timeout(_networkTimeout);
          _cachedMetricsId = existingId;

          // Save to local storage
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pb_metrics_id', existingId);

          debugPrint("📊 Found and updated existing metrics record: $existingId");
          return;
        } catch (e) {
          debugPrint("⚠️ Failed to update metrics record: $e");
          // 🚀 SELF-HEALING: If the found record can't be updated (400 = corrupted/wiped),
          // clear cache so we fall through to create a new record.
          _cachedMetricsId = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pb_metrics_id');
          // Fall through to create new record below
        }
      }
    } catch (e) {
      debugPrint("⚠️ Search existing record error: $e");
      // 🚀 CRITICAL FIX: If search fails for ANY reason (403, network, etc.),
      // DO NOT fall through to create a new record — that causes duplicates!
      // Instead, return and retry next time when we might have a valid cache.
      debugPrint("📊 Search failed. Skipping write to prevent duplicate creation.");
      return;
    }

    // 4. Create new record (only if no existing record found and search succeeded)
    try {
      final rec = await pb.collection('metrics').create(
        body: {
          'user_id': _userId,
          'os': Platform.operatingSystem,
          ...dataWithHost,
        },
        files: avatarFile != null ? [await http.MultipartFile.fromPath('avatar', avatarFile.path)] : []
      ).timeout(_networkTimeout);
      _cachedMetricsId = rec.id;

      // Store for future use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pb_metrics_id', rec.id);

      debugPrint("📊 Created new metrics record: ${rec.id} for $hostname");
    } catch (e) {
      debugPrint("⚠️ PB Write Error: $e");
    }
  }

  // GET DATA (Read metrics for a specific user ID - used for restoration)
  Future<Map<String, dynamic>?> getRemoteMetricsForUser(String targetUserId) async {
    // 🚀 CRASH GUARD: Use isolated admin instance for this sensitive post-auth read
    final adminPb = PocketBase(Env.pocketbaseUrl);
    try {
      await adminPb.collection('_superusers').authWithPassword(
        Env.pocketbaseAdminEmail,
        Env.pocketbaseAdminPassword,
      );

      final records = await adminPb.collection('metrics').getList(
        page: 1,
        perPage: 1,
        filter: 'user_id = "$targetUserId"',
      ).timeout(_networkTimeout);

      if (records.items.isNotEmpty) {
        return records.items.first.data;
      }
    } catch (e) {
      debugPrint("⚠️ Remote Metrics Fetch Error for $targetUserId: $e");
    }
    return null;
  }

  // GET DATA (Read Current Metrics) - No List permission needed
  Future<Map<String, dynamic>?> getUserMetrics() async {
    if (isOffline || !enableCloudSync) return null; // 🔒 OFFLINE or Cloud Sync Disabled
    if (!_initialized || _userId == null) return null;

    // 1. Try cached ID
    if (_cachedMetricsId != null) {
      try {
        final record = await pb.collection('metrics').getOne(
          _cachedMetricsId!,
          query: {'nc': DateTime.now().millisecondsSinceEpoch.toString()},
        );
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
          final record = await pb.collection('metrics').getOne(
            storedId,
            query: {'nc': DateTime.now().millisecondsSinceEpoch.toString()},
          );
          _cachedMetricsId = storedId;
          return record.data;
        } catch (e) {
          await prefs.remove('pb_metrics_id');
        }
      }
    } catch (e) {
      debugPrint("⚠️ Metrics read storage error: $e");
    }

    // 3. 🚀 CRITICAL FIX: Search by user_id as final fallback
    // Without this, losing the cached ID means getUserMetrics returns null,
    // which causes _performIncrement to start counters from 0 (losing daily_play_count).
    try {
      final existingRecords = await pb
          .collection('metrics')
          .getList(
            page: 1,
            perPage: 1,
            filter: 'user_id = "$_userId"',
            query: {'nc': DateTime.now().millisecondsSinceEpoch.toString()},
          )
          .timeout(_networkTimeout);

      if (existingRecords.items.isNotEmpty) {
        final record = existingRecords.items.first;
        _cachedMetricsId = record.id;

        // Persist to local storage so we don't need to search again
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pb_metrics_id', record.id);

        debugPrint("📊 getUserMetrics: Recovered record by user_id search: ${record.id}");
        return record.data;
      }
    } catch (e) {
      debugPrint("⚠️ getUserMetrics: user_id search fallback failed: $e");
      // 🚀 CRITICAL: We MUST rethrow the error. If we return null on a network timeout,
      // the caller (syncAdvancedStats) will assume the cloud stats are 0 and overwrite them!
      throw Exception("Network or API error while fetching user metrics: $e");
    }

    // No existing record found
    return null;
  }

  // --- RANKING ---
  
  /// Determines the user's global rank by counting how many users have strictly more total minutes.
  /// Rank = (Count of users with > minutes) + 1
  Future<int> calculateUserRank(int minutes) async {
    if (isOffline || !enableLeaderboard) return 0; // 🔒 OFFLINE or Leaderboard Disabled
    if (!_initialized) return 0;
    try {
      final records = await pb.collection('metrics').getList(
        page: 1,
        perPage: 1,
        filter: 'total_minutes > $minutes',
      ).timeout(_networkTimeout);
      
      return records.totalItems + 1;
    } catch (e) {
      DebugLogService().error("⚠️ PB Rank Calculation Error: $e");
      return 0;
    }
  }

  // HELPER: BUILD AVATAR URL
  String? getAvatarUrl(Map<String, dynamic> recordData) {
    final fileName = recordData['avatar'] as String?;
    if (fileName == null || fileName.isEmpty) return null;
    
    // PocketBase file URL format: api/files/COLLECTION_ID_OR_NAME/RECORD_ID/FILENAME
    final recordId = recordData['id'] as String?;
    if (recordId == null) return null;
    
    return "${Env.pocketbaseUrl}/api/files/metrics/$recordId/$fileName";
  }

  // HEARTBEAT - Updates last_active for online status in admin dashboard
  Future<void> sendHeartbeat() async {
    await saveData({'last_active': DateTime.now().toUtc().toIso8601String()});
  }

  /// Whether PocketBase has a valid authenticated session (linked Google account)
  bool get isAuthenticated => pb.authStore.isValid;

  /// The email of the linked Google account, if any
  String? get linkedEmail {
    if (!pb.authStore.isValid) return null;
    try {
      final model = pb.authStore.record;
      return model?.data['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// The name of the linked Google account, if any
  String? get linkedName {
    if (!pb.authStore.isValid) return null;
    try {
      final model = pb.authStore.record;
      return model?.data['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// The Google or PocketBase avatar URL of the linked account, if any
  String? get linkedAvatarUrl {
    if (!pb.authStore.isValid) return null;
    try {
      final model = pb.authStore.record;
      // 1. Try uploaded PocketBase avatar first
      final pbAvatar = model?.data['avatar'] as String?;
      if (pbAvatar != null && pbAvatar.isNotEmpty && model != null) {
        return "${Env.pocketbaseUrl}/api/files/users/${model.id}/$pbAvatar";
      }
      // 2. Fallback to Google OAuth provided string URL
      return model?.data['avatarUrl'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 🔗 Migrate anonymous metrics to a linked Google account
  /// Takes the old anonymous user_id's metrics row and reassigns it to the new authenticated user_id.
  /// If the new user_id already has a metrics row (cross-device), merges the data.
  Future<bool> migrateAnonymousToLinked(String newUserId, {String? fromUserId}) async {
    if (isOffline) return false; // 🔒 OFFLINE MODE
    if (!_initialized) return false;
    
    // Use explicit fromUserId (crash recovery) or fallback to internal _userId
    final oldUserId = fromUserId ?? _userId;
    if (oldUserId == null || oldUserId.isEmpty || oldUserId == newUserId) return true; // Already migrated
    DebugLogService().info("🔗 Migration: $oldUserId → $newUserId");

    // 🚀 CRASH GUARD (Exit -1 Fix):
    // Perform all Admin migration tasks in a completely ISOLATED PocketBase instance.
    // Dart on Windows has a native IOCP crash bug when closing an HTTP stream (OAuth SSE)
    // and immediately firing new REST calls on the exact same http.Client.
    // Making a dedicated admin instance with its own client avoids this race condition!
    final adminPb = PocketBase(Env.pocketbaseUrl);

    try {
      // Authenticate the ISOLATED admin instance
      try {
        await adminPb.collection('_superusers').authWithPassword(
          Env.pocketbaseAdminEmail,
          Env.pocketbaseAdminPassword,
        );
      } catch (e) {
        DebugLogService().error("⚠️ Migration: Admin auth failed: $e");
        return false;
      }

      // 1. Find the OLD anonymous metrics row
      RecordModel? oldRecord;
      try {
        final oldRecords = await adminPb.collection('metrics').getList(
          page: 1, perPage: 1,
          filter: 'user_id = "$oldUserId"',
        ).timeout(_networkTimeout);
        if (oldRecords.items.isNotEmpty) {
          oldRecord = oldRecords.items.first;
        }
      } catch (e) {
        DebugLogService().error("⚠️ Migration: Failed to find old record: $e");
      }

      // 2. Check if the new user_id already has a metrics row (from another device)
      RecordModel? existingNewRecord;
      try {
        final newRecords = await adminPb.collection('metrics').getList(
          page: 1, perPage: 1,
          filter: 'user_id = "$newUserId"',
        ).timeout(_networkTimeout);
        if (newRecords.items.isNotEmpty) {
          existingNewRecord = newRecords.items.first;
        }
      } catch (e) {
        DebugLogService().error("⚠️ Migration: Failed to find new record: $e");
      }

      if (oldRecord != null && existingNewRecord != null) {
        // MERGE: Both old anonymous and new linked records exist
        // Take MAX of play counts, SUM of total minutes
        final oldData = oldRecord.data;
        final newData = existingNewRecord.data;

        final mergedPlayCount = _maxInt(
          oldData['play_count'] as int? ?? 0,
          newData['play_count'] as int? ?? 0,
        );
        final mergedTotalMinutes = _maxInt(
          oldData['total_minutes'] as int? ?? 0,
          newData['total_minutes'] as int? ?? 0,
        );
        final mergedDailyPlayCount = _maxInt(
          oldData['daily_play_count'] as int? ?? 0,
          newData['daily_play_count'] as int? ?? 0,
        );

        // Use the nickname from whichever has one set
        final nickname = (newData['nickname'] as String?)?.isNotEmpty == true
            ? newData['nickname']
            : (oldData['nickname'] as String? ?? '');

        await adminPb.collection('metrics').update(existingNewRecord.id, body: {
          'play_count': mergedPlayCount,
          'total_minutes': mergedTotalMinutes,
          'daily_play_count': mergedDailyPlayCount,
          'nickname': nickname,
          'top_artist': newData['top_artist'] ?? oldData['top_artist'] ?? '',
        }).timeout(_networkTimeout);

        // Delete the old anonymous record to prevent duplication
        try {
          await adminPb.collection('metrics').delete(oldRecord.id).timeout(_networkTimeout);
          DebugLogService().success("🗑 Migration: Deleted old anonymous record ${oldRecord.id}");
        } catch (deleteErr) {
          DebugLogService().error("⚠️ Migration: Failed to delete old record ${oldRecord.id}: $deleteErr");
          // Retry once
          try {
            await Future.delayed(const Duration(seconds: 1));
            await adminPb.collection('metrics').delete(oldRecord.id).timeout(_networkTimeout);
            DebugLogService().success("🗑 Migration: Deleted old record on retry");
          } catch (retryErr) {
            DebugLogService().error("⚠️ Migration: Retry delete also failed: $retryErr");
          }
        }

        _cachedMetricsId = existingNewRecord.id;
        DebugLogService().success("✅ Migration: Merged old data into existing linked record");

      } else if (oldRecord != null) {
        // REASSIGN: Just update the user_id on the old record
        await adminPb.collection('metrics').update(oldRecord.id, body: {
          'user_id': newUserId,
        }).timeout(_networkTimeout);
        _cachedMetricsId = oldRecord.id;
        DebugLogService().success("✅ Migration: Reassigned old record to $newUserId");

      } else {
        // No old record — user is fresh, nothing to migrate
        DebugLogService().info("🔗 Migration: No old anonymous data found, nothing to migrate");
      }

      // 3. Update local state
      _userId = newUserId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pb_user_id', newUserId);
      if (_cachedMetricsId != null) {
        await prefs.setString('pb_metrics_id', _cachedMetricsId!);
      }

      // 4. Push local nickname to the linked users table
      await syncUserAccountProfile(nickname: prefs.getString('custom_nickname'));

      DebugLogService().success("✅ Migration complete: Now using $newUserId");
      return true;
    } catch (e) {
      DebugLogService().error("⚠️ Migration error: $e");
      debugPrint("⚠️ Migration error: $e");
      return false;
    }
  }

  /// Sync app profile (name and avatar) into the PocketBase `users` collection row
  Future<void> syncUserAccountProfile({
    String? nickname,
    File? avatarFile,
    bool clearAvatar = false,
  }) async {
    if (isOffline) return; // 🔒 OFFLINE MODE
    // Requires a linked account
    final linkedUserId = AuthService().linkedUserId;
    if (linkedUserId == null) return;

    // ISOLATED ADMIN INSTANCE: Avoid active SSE socket crashes on Windows
    final adminPb = PocketBase(Env.pocketbaseUrl);

    try {
      // Ensure we have admin rights to update the users collection securely
      await adminPb.collection('_superusers').authWithPassword(
        Env.pocketbaseAdminEmail,
        Env.pocketbaseAdminPassword,
      );

      final body = <String, dynamic>{};

      // 1. Set Name
      if (nickname != null && nickname.isNotEmpty) {
        body['name'] = nickname;
        
        // 2. Generate a valid Username (for the Friends system)
        // PocketBase username rules: only alphanumeric, dot, underscore, hyphen. Length 3-150.
        String cleanUsername = nickname.replaceAll(RegExp(r'[^a-zA-Z0-9_\.\-]'), '').toLowerCase();
        if (cleanUsername.isEmpty || !RegExp(r'^[a-zA-Z0-9]').hasMatch(cleanUsername)) {
          cleanUsername = 'user_$cleanUsername';
        }
        if (cleanUsername.length < 3) cleanUsername = cleanUsername.padRight(3, '0');
        if (cleanUsername.length > 150) cleanUsername = cleanUsername.substring(0, 150);

        // Verify if username is unique before setting it
        try {
          final existing = await adminPb.collection('users').getList(
             page: 1, perPage: 1, 
             filter: 'username = "$cleanUsername" && id != "$linkedUserId"'
          );
          if (existing.items.isEmpty) {
             body['username'] = cleanUsername;
          }
        } catch (_) {}
      }

      if (clearAvatar) {
        body['avatar'] = null;
      }

      // No updates needed if empty and no avatar attached
      if (body.isEmpty && avatarFile == null && !clearAvatar) return;

      await adminPb.collection('users').update(
        linkedUserId,
        body: body,
        files: avatarFile != null ? [await http.MultipartFile.fromPath('avatar', avatarFile.path)] : []
      ).timeout(_networkTimeout);
      
      DebugLogService().success("✅ Synced profile to users collection successfully.");
    } catch (e) {
      DebugLogService().error("⚠️ Failed to sync users profile: $e");
    }
  }

  /// Revert to anonymous mode after unlinking
  Future<void> revertToAnonymous() async {
    final prefs = await SharedPreferences.getInstance();
    // Generate a new anonymous ID
    _userId = "user_${DateTime.now().millisecondsSinceEpoch}";
    await prefs.setString('pb_user_id', _userId!);
    
    // Clear cached metrics so it searches fresh
    _cachedMetricsId = null;
    await prefs.remove('pb_metrics_id');
    
    DebugLogService().info("🔗 Reverted to anonymous: $_userId");
  }

  int _maxInt(int a, int b) => a > b ? a : b;

  PocketBase? _adminPb;
  // 🚀 ISOLATED ADMIN CLIENT: Prevents overwriting the user's Google OAuth session
  Future<PocketBase> _getAdminClient() async {
    if (_adminPb != null && _adminPb!.authStore.isValid) return _adminPb!;
    
    _adminPb = PocketBase(Env.pocketbaseUrl);
    try {
      await _adminPb!.collection('_superusers').authWithPassword(
        Env.pocketbaseAdminEmail,
        Env.pocketbaseAdminPassword,
      );
      debugPrint("🔐 Secure Admin client authenticated");
    } catch (e) {
      debugPrint("⚠️ Admin Auth Error: $e");
    }
    return _adminPb!;
  }

  // VERIFY ADMIN/VIEWER CODE (Requires Admin Auth to read settings)
  // Returns: 'admin', 'viewer', or null if invalid
  Future<String?> verifyAdminAccessCode(String inputCode) async {
    if (isOffline) return null; // 🔒 OFFLINE MODE
    try {
      // Authenticate as admin first to access locked settings
      // Authenticate using isolated admin client so we don't drop the user's active session
      final adminPb = await _getAdminClient();

      // Now we can access settings safely
      final records = await adminPb.collection('settings').getList(
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
    if (isOffline) return {'items': [], 'totalCount': 0}; // 🔒 OFFLINE MODE
    try {
      // Authenticate as admin if not already
      // Authenticate using isolated admin client
      final adminPb = await _getAdminClient();

      final records = await adminPb.collection('metrics').getList(
            page: 1,
            perPage: 500, // Must be high enough to capture all active users even with duplicates
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

  // FETCH LEADERBOARD (Available to users)
  Future<List<Map<String, dynamic>>> fetchLeaderboard({required String sortBy, int limit = 50, String? filter}) async {
    if (isOffline || !enableLeaderboard) return []; // 🔒 OFFLINE MODE or Leaderboard Disabled
    try {
      // Authenticate as admin since metrics list might be restricted
      final adminPb = await _getAdminClient();

      final records = await adminPb.collection('metrics').getList(
            page: 1,
            perPage: limit,
            sort: '-$sortBy',
            filter: filter,
          );
          
      return records.items.map((r) => r.data..['id'] = r.id).toList();
    } catch (e) {
      debugPrint("⚠️ Leaderboard Fetch Error: $e");
      return [];
    }
  }

  // FETCH ARTIST LEADERBOARD
  Future<List<Map<String, dynamic>>> fetchArtistLeaderboard({required String sortBy, int limit = 50, String? filter}) async {
    if (isOffline || !enableLeaderboard) return []; // 🔒 OFFLINE MODE or Leaderboard Disabled
    try {
      final adminPb = await _getAdminClient();

      final records = await adminPb.collection('artist_metrics').getList(
            page: 1,
            perPage: limit,
            sort: '-$sortBy',
            filter: filter,
          );
          
      return records.items.map((r) => r.data..['id'] = r.id).toList();
    } catch (e) {
      debugPrint("⚠️ Artist Leaderboard Fetch Error: $e");
      return [];
    }
  }

  // INCREMENT ARTIST PLAY
  Future<void> incrementArtistPlay(String artistName) async {
    if (isOffline) return; // 🔒 OFFLINE MODE
    if (artistName.isEmpty || artistName == "Unknown" || artistName == "N/A") return;
    
    try {
      final adminPb = await _getAdminClient();

      // 1. Search for existing artist
      final existingRecords = await adminPb.collection('artist_metrics').getList(
        page: 1,
        perPage: 1,
        filter: 'name = "${artistName.replaceAll('"', '\\"')}"',
      );

      final nowString = DateTime.now().toUtc().toIso8601String().replaceFirst('T', ' ');

      if (existingRecords.items.isNotEmpty) {
        // Increment
        final record = existingRecords.items.first;
        final id = record.id;
        final currentPlayCount = record.data['play_count'] ?? 0;
        int currentDailyPlayCount = record.data['daily_play_count'] ?? 0;
        int currentWeeklyPlayCount = record.data['weekly_play_count'] ?? 0;
        final lastPlayDateStr = record.data['last_play_date'];
        
        if (lastPlayDateStr != null && lastPlayDateStr.isNotEmpty) {
           try {
              // Parse last date 
              final lastDate = DateTime.parse(lastPlayDateStr).toUtc().add(const Duration(hours: 7));
              final nowLocal = DateTime.now().toUtc().add(const Duration(hours: 7));
              
              // Daily reset
              if (lastDate.day != nowLocal.day || lastDate.month != nowLocal.month || lastDate.year != nowLocal.year) {
                 currentDailyPlayCount = 0;
              }
              
              // Weekly reset (Monday baseline)
              final lastMonday = DateTime.utc(lastDate.year, lastDate.month, lastDate.day - (lastDate.weekday - 1));
              final nowMonday = DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day - (nowLocal.weekday - 1));
              if (lastMonday != nowMonday) {
                 currentWeeklyPlayCount = 0;
              }
           } catch (e) {}
        }
        
        await adminPb.collection('artist_metrics').update(id, body: {
          'play_count': currentPlayCount + 1,
          'daily_play_count': currentDailyPlayCount + 1,
          'weekly_play_count': currentWeeklyPlayCount + 1,
          'last_play_date': nowString,
        });
      } else {
        // Create new
        await adminPb.collection('artist_metrics').create(body: {
          'name': artistName,
          'play_count': 1,
          'daily_play_count': 1,
          'weekly_play_count': 1,
          'last_play_date': nowString,
        });
      }
    } catch (e) {
      debugPrint("⚠️ Increment Artist Play Error: $e");
    }
  }

  // CHECK NICKNAME UNIQUENESS
  Future<bool> isNicknameTaken(String nickname) async {
    if (isOffline) return false; // 🔒 OFFLINE MODE
    try {
      final adminPb = await _getAdminClient();
      
      final records = await adminPb.collection('metrics').getList(
        page: 1,
        perPage: 1,
        filter: 'nickname = "$nickname" && user_id != "$_userId"',
      );
      
      return records.items.isNotEmpty;
    } catch (e) {
      debugPrint("⚠️ Nickname Check Error: $e");
      return false; // Safely allow if servers flutter or offline
    }
  }

  // ADMIN: DELETE USER METRICS RECORD
  Future<bool> deleteMetricsRecord(String recordId) async {
    if (isOffline) return false; // 🔒 OFFLINE MODE
    try {
      // Authenticate as admin using isolated client
      final adminPb = await _getAdminClient();

      await adminPb.collection('metrics').delete(recordId);
      debugPrint("🗑️ Deleted metrics record: $recordId");
      return true;
    } catch (e) {
      debugPrint("⚠️ Admin Delete Error: $e");
      return false;
    }
  }

  // --- GLOBAL BROADCASTS ---
  
  Future<void> sendGlobalBroadcast(String message) async {
    if (isOffline) return; // 🔒 OFFLINE MODE
    try {
      // Authenticate using isolated admin client
      final adminPb = await _getAdminClient();

      await adminPb.collection('broadcasts').create(body: {
        'message': message,
      });
      DebugLogService().success("📢 Broadcast sent: $message");
    } catch (e) {
      DebugLogService().error("⚠️ Broadcast Error: $e");
      throw Exception("Failed to send broadcast: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentBroadcasts() async {
    if (isOffline) return []; // 🔒 OFFLINE MODE
    try {
      await _ensureInitialized();
      final records = await pb.collection('broadcasts').getList(
            page: 1,
            perPage: 50,
            sort: '-created',
          );
      return records.items
          .map((r) => {
                'id': r.id,
                'message': r.data['message'],
                'created': r.created,
              })
          .toList();
    } catch (e) {
      debugPrint("⚠️ Quick Fetch Broadcasts Error: $e");
      return [];
    }
  }

  Future<void> listenForBroadcasts(Function(String, String) onMessage) async {
    if (isOffline) return; // 🔒 OFFLINE MODE
    try {
      await _ensureInitialized();

      // Unsubscribe first to avoid duplicate listeners
      pb.collection('broadcasts').unsubscribe();
      
      pb.collection('broadcasts').subscribe('*', (e) {
        if (e.action == 'create') {
          final msg = e.record?.data['message'] as String?;
          final id = e.record?.id;
          if (msg != null && msg.isNotEmpty && id != null) {
            onMessage(msg, id);
          }
        }
      });
      debugPrint("📡 Listening for global broadcasts...");
    } catch (e) {
      debugPrint("⚠️ Broadcast Listen Error: $e");
    }
  }

  // --- REMOTE CONTROL (SESSIONS) ---

  String? _cachedSessionId; // Cache session ID in memory

  // HELPER: ENSURE SINGLE SESSION (No List permission needed)
  Future<String?> getUniqueSessionId({bool forceRegenerate = false}) async {
    return _ensureUniqueSession(forceRegenerate: forceRegenerate);
  }

  Future<String?> _ensureUniqueSession({bool forceRegenerate = false}) async {
    if (isOffline) return null; // 🔒 OFFLINE MODE
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
        DebugLogService().info("📡 Session: Force Regenerated for $_userId");
      } catch (e) {
        if (e.toString().contains('403')) {
          _cachedSessionId = null;
          DebugLogService().error("⚠️ PocketBase: Session cleanup DENIED (403). Check API Rules.");
        } else {
          DebugLogService().error("⚠️ Session cleanup error: $e");
        }
      }
    }

    // 2. Try cached session ID FIRST to avoid spamming the backend
    if (!forceRegenerate && _cachedSessionId != null) {
      return _cachedSessionId;
    }

    // 3. 🚀 SEARCH for existing session by user_id
    // This ensures all devices on the same account converge on the same cloud record.
    try {
      final existingRecords = await pb.collection('sessions').getList(
            page: 1,
            perPage: 1,
            filter: 'user_id = "$_userId"',
            sort: '-created', // Join the newest one if multiple exist
            query: {'cache_bust': DateTime.now().millisecondsSinceEpoch.toString()},
          );

      if (existingRecords.items.isNotEmpty) {
        final newest = existingRecords.items.first;
        _cachedSessionId = newest.id;

        // Save to local storage for quick lookup in this app session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pb_session_id', newest.id);

        return newest.id; // Silent return, prevent spam
      }
    } catch (e) {
      if (e.toString().contains('403')) {
        DebugLogService().error("⚠️ PocketBase: Session SEARCH DENIED (403). Discovery will fail.");
      } else {
        DebugLogService().error("⚠️ Session Search Error: $e");
      }
      // If search fails due to network, we can try falling back to local cache
    }

    // 3. Try cached session ID / Local Storage as Fallback
    // 4. Try Local Storage as Fallback
    if (!forceRegenerate) {
      try {

        final prefs = await SharedPreferences.getInstance();
        final storedId = prefs.getString('pb_session_id');
        if (storedId != null) {
          await pb.collection('sessions').getOne(storedId, query: {'cache_bust': DateTime.now().millisecondsSinceEpoch.toString()});
          _cachedSessionId = storedId;
          return storedId;
        }
      } catch (e) {
        // Fallback failed (e.g. session deleted), proceed to creation
        _cachedSessionId = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pb_session_id');
      }
    }

    // 4. Create new session (No existing session found)
    try {
      final rec =
          await pb.collection('sessions').create(body: {'user_id': _userId});
      _cachedSessionId = rec.id;

      // Store for future use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pb_session_id', rec.id);

      DebugLogService().success("📡 Session: Created new record ${rec.id}");
      return rec.id;
    } catch (e) {
      if (e.toString().contains('403')) {
        DebugLogService().error("⚠️ PocketBase: Session CREATE DENIED (403). Check API Rules.");
        return null;
      }
      DebugLogService().error("⚠️ Session Create Error: $e");
      return null;
    }
  }

  // UPDATE SESSION (Broadcast State)
  Future<void> updateSession(Map<String, dynamic> data) async {
    if (isOffline) return; // 🔒 OFFLINE MODE
    final recordId = await _ensureUniqueSession();
    if (recordId == null) return;

    try {
      await pb.collection('sessions').update(recordId, body: data);
    } catch (e) {
      if (e is ClientException) {
        // 🚀 SELF-HEALING: If 400 or 404, the session is stale/corrupted.
        // Force regenerate a fresh session and retry ONCE.
        if (e.statusCode == 400 || e.statusCode == 404) {
          DebugLogService().warning("⚠️ PB: Session $recordId is stale. Force regenerating...");
          _cachedSessionId = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pb_session_id');
          
          // Force create a brand new session
          try {
            final newId = await _ensureUniqueSession(forceRegenerate: true);
            if (newId != null) {
              await pb.collection('sessions').update(newId, body: data);
              DebugLogService().success("✅ PB: Session self-healed! New ID: $newId");
              return;
            }
          } catch (retryErr) {
            DebugLogService().error("⚠️ PB: Session self-heal retry also failed: $retryErr");
          }
        }
        DebugLogService().error("⚠️ PB: Update 400 Detail: ${e.response}");
      }
      DebugLogService().error("⚠️ PB: Session Update FAILED: $e");
    }
  }

  // GET SESSION DATA (Polling)
  Future<Map<String, dynamic>?> getSessionData() async {
    if (isOffline) return null; // 🔒 OFFLINE MODE
    final recordId = await _ensureUniqueSession();
    if (recordId == null) return null;

    try {
      final record = await pb.collection('sessions').getOne(recordId, query: {'cache_bust': DateTime.now().millisecondsSinceEpoch.toString()});
      final data = record.data;
      data['updated'] = record.updated; // Manual inject
      return data;
    } catch (e) {
      if (e is ClientException) {
        // 🚀 SELF-HEALING: Clear stale session on 400/404
        if (e.statusCode == 400 || e.statusCode == 404) {
          DebugLogService().warning("⚠️ PB: Polling Session $recordId is stale. Clearing.");
          _cachedSessionId = null;
          SharedPreferences.getInstance().then((p) => p.remove('pb_session_id'));
        }
        DebugLogService().error("⚠️ Session Polling 400 Detail: ${e.response}");
      }
      DebugLogService().error("⚠️ Session Polling Error: $e");
      return null;
    }
  }

  // SUBSCRIBE (Listen for Commands)
  Future<void> subscribeToSession(
      Function(Map<String, dynamic>) onUpdate) async {
    if (isOffline) return; // 🔒 OFFLINE MODE
    final recordId = await _ensureUniqueSession();
    if (recordId == null) return;

    try {
      pb.collection('sessions').subscribe(recordId, (e) {
        if (e.action == 'update') {
          final data = e.record?.data ?? {};
          // Ensure 'updated' is available
          data['updated'] = e.record?.updated;
          // Data received, push to listener
          onUpdate(data);
        } else {
          // Event ignored (not update)
        }
      });
      debugPrint("📡 Subscribed to Session: $recordId");
    } catch (e) {
      debugPrint("⚠️ Session Subscribe Error: $e");
    }
  }

  void unsubscribe() {
    if (isOffline) return; // 🔒 OFFLINE MODE
    pb.collection('sessions').unsubscribe();
  }

  // --- SHAREABLE PLAYLISTS ---

  /// Shares a playlist and returns a 6-digit share code
  Future<String?> sharePlaylist(String playlistId, Map<String, dynamic> playlistData) async {
    if (isOffline) return null; // 🔒 OFFLINE MODE
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
    if (isOffline) return false; // 🔒 OFFLINE MODE
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
    if (isOffline) return null; // 🔒 OFFLINE MODE
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
    if (isOffline) return null; // 🔒 OFFLINE MODE
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
