import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../env/env.dart';
import '../data/schemas.dart';
import '../models/song_model.dart';

class MetricsService {
  static final MetricsService _instance = MetricsService._internal();
  factory MetricsService() => _instance;
  MetricsService._internal();

  bool _initialized = false;
  bool get initialized => _initialized;
  String? _userId;
  String? get userId => _userId;
  Timer? _heartbeatTimer;

  // REST API Config (For Windows)
  static final String _firestoreBaseUrl =
      'https://firestore.googleapis.com/v1/projects/${Env.firebaseProjectId}/databases/(default)/documents';

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 0. Load Persistent Device ID
      _userId = await _getStableUserId();
      debugPrint("📊 MetricsService: Stable Device ID loaded: $_userId");
      debugPrint("📊 MetricsService: Check Windows: ${Platform.isWindows}");

      // 1. Initialize Firebase (Native only for Non-Windows)
      // On Windows, we skip native init to avoid DLL crashes, and use REST instead.
      if (!Platform.isWindows) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: Env.firebaseApiKey,
            appId: Platform.isAndroid
                ? Env.firebaseAppIdAndroid
                : Platform.isIOS
                    ? Env.firebaseAppIdIos
                    : Platform.isMacOS
                        ? Env.firebaseAppIdMacos
                        : Env.firebaseAppIdWindows,
            messagingSenderId: Env.firebaseMessagingSenderId,
            projectId: Env.firebaseProjectId,
            storageBucket: Env.firebaseStorageBucket,
            measurementId: Env.firebaseMeasurementId,
            authDomain: Env.firebaseAuthDomain,
          ),
        );

        // 2. Sign in Anonymously (Native only)
        await FirebaseAuth.instance.signInAnonymously();
      } else {
        debugPrint("🪟 Windows: Utilizing REST API for Metrics (Stable Mode).");
        debugPrint("🪟 Windows: REST URL: $_firestoreBaseUrl");
      }

      _initialized = true;

      // 3. Track App Open (Session)
      _trackEvent('app_session_start', {
        'platform': defaultTargetPlatform.name,
        'timestamp': _serverTimestamp(),
      });

      // Start Heartbeat
      _startHeartbeat();

      // Update Identity info
      debugPrint("📊 MetricsService: Updating Identity...");
      await _updateUserIdentity();
      debugPrint("📊 MetricsService: Identity Updated.");
    } catch (e) {
      debugPrint("⚠️ MetricsService Init Error: $e");
      _initialized = true; // Non-blocking failure
    }
  }

  // --- REST API HELPER (Windows Only) ---
  Future<void> _restWrite(
      String collectionPath, String docId, Map<String, dynamic> fields,
      {bool isUpdate = false}) async {
    // Convert generic map to Firestore JSON syntax
    final firestoreFields = <String, dynamic>{};
    fields.forEach((key, value) {
      firestoreFields[key] = _toFirestoreValue(value);
    });

    final url = Uri.parse(
        '$_firestoreBaseUrl/$collectionPath/$docId${isUpdate ? '?updateMask.fieldPaths=${fields.keys.join('&updateMask.fieldPaths=')}' : ''}');
    debugPrint("🌐 REST WRITE: $url");

    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': firestoreFields}),
      );
      if (response.statusCode >= 400) {
        debugPrint("⚠️ REST Error [${response.statusCode}]: ${response.body}");
      }
    } catch (e) {
      debugPrint("⚠️ REST Exception: $e");
    }
  }

  Future<void> _restAdd(
      String collectionPath, Map<String, dynamic> fields) async {
    // Convert generic map to Firestore JSON syntax
    final firestoreFields = <String, dynamic>{};
    fields.forEach((key, value) {
      firestoreFields[key] = _toFirestoreValue(value);
    });

    final url = Uri.parse('$_firestoreBaseUrl/$collectionPath');
    debugPrint("🌐 REST ADD: $url");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fields': firestoreFields}),
      );
      if (response.statusCode >= 400) {
        debugPrint(
            "⚠️ REST Add Error [${response.statusCode}]: ${response.body}");
      }
    } catch (e) {
      debugPrint("⚠️ REST Add Exception: $e");
    }
  }

  dynamic _toFirestoreValue(dynamic value) {
    if (value is String) return {'stringValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is bool) return {'booleanValue': value};
    // Timestamp handling for REST (ISO string)
    if (value is String && value == "SERVER_TIMESTAMP") {
      return {'timestampValue': DateTime.now().toUtc().toIso8601String()};
    }
    return {'stringValue': value.toString()};
  }

  dynamic _serverTimestamp() {
    if (Platform.isWindows) return "SERVER_TIMESTAMP";
    return FieldValue.serverTimestamp();
  }

  // --- CORE METHODS ---

  Future<void> _trackEvent(String eventName, Map<String, dynamic> data) async {
    if (!_initialized || _userId == null) return;

    if (Platform.isWindows) {
      await _restAdd('metrics/$_userId/events', {'name': eventName, ...data});
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('metrics')
          .doc(_userId)
          .collection('events')
          .add({
        'name': eventName,
        ...data,
      });
    } catch (e) {
      debugPrint("⚠️ Failed to track event: $e");
    }
  }

  // --- Specific Events ---

  Future<void> trackSongPlay(Song song, {int? localTotal}) async {
    await _trackEvent('song_play', {
      'title': song.title,
      'artist': song.artist,
      'duration': song.duration,
      'local_total_plays': localTotal,
      'timestamp': _serverTimestamp(),
    });
    // Increment Total Plays (and Daily Plays)
    await _incrementUserStat('play_count');

    // Sync Local Total directly to User doc if provided
    if (localTotal != null) {
      if (Platform.isWindows) {
        await _restWrite(
            'metrics',
            _userId!,
            {
              'local_total_plays': localTotal,
              'play_count': localTotal, // FORCE SYNC
            },
            isUpdate: true);
      } else {
        FirebaseFirestore.instance.collection('metrics').doc(_userId).set({
          'local_total_plays': localTotal,
          'play_count': localTotal, // FORCE SYNC
        }, SetOptions(merge: true));
      }
    }
  }

  // Overload for SongModel (StatsProvider / PlayerProvider)
  Future<void> trackSongPlayModel(SongModel song, {int? localTotal}) async {
    await _trackEvent('song_play', {
      'title': song.title,
      'artist': song.artist,
      'duration': song.duration,
      'local_total_plays': localTotal, // Sync Local Total
      'timestamp': _serverTimestamp(),
    });
    // Increment Total Plays (and Daily Plays)
    await _incrementUserStat('play_count');

    // Sync Local Total directly to User doc if provided
    if (localTotal != null) {
      if (Platform.isWindows) {
        await _restWrite(
            'metrics',
            _userId!,
            {
              'local_total_plays': localTotal,
              'play_count': localTotal, // FORCE SYNC
            },
            isUpdate: true);
      } else {
        FirebaseFirestore.instance.collection('metrics').doc(_userId).set({
          'local_total_plays': localTotal,
          'play_count': localTotal, // FORCE SYNC
        }, SetOptions(merge: true));
      }
    }
  }

  Future<void> trackDownload(Song song) async {
    await _trackEvent('song_download', {
      'title': song.title,
      'artist': song.artist,
      'timestamp': _serverTimestamp(),
    });
    // Increment Total Downloads
    await _incrementUserStat('download_count');
  }

  // Helper for Search Page (where we only have metadata)
  Future<void> trackDownloadMetadata(dynamic metadata) async {
    await _trackEvent('song_download', {
      'title': metadata.title,
      'artist': metadata.artist,
      'source': 'youtube_search',
      'timestamp': _serverTimestamp(),
    });
    // Increment Total Downloads
    await _incrementUserStat('download_count');
  }

  // BAN & LIMIT CHECK
  Future<bool> canDownload() async {
    if (!_initialized || _userId == null) {
      return true; // Fail open if offline/error
    }

    try {
      Map<String, dynamic>? data;

      if (Platform.isWindows) {
        // Windows REST Read
        final url = Uri.parse('$_firestoreBaseUrl/metrics/$_userId');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          data = _convertFirestoreFields(json['fields'] ?? {});
        } else if (response.statusCode == 404) {
          return true; // New user
        }
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('metrics')
            .doc(_userId)
            .get();
        if (doc.exists) data = doc.data();
      }

      if (data == null) return true;

      // 1. Check Global Ban
      if (data['is_banned'] == true) {
        debugPrint("⛔ User is BANNED from downloads.");
        return false;
      }

      // 2. Check Daily Limit (GMT+7 Reset)
      // Timestamp handling differs slightly between Native and REST helper result
      final dynamic rawDate = data['last_download_date'];
      DateTime? lastDownloadDate;
      if (rawDate is Timestamp) {
        lastDownloadDate = rawDate.toDate();
      } else if (rawDate is String) {
        lastDownloadDate = DateTime.tryParse(rawDate);
      } else if (rawDate is DateTime) {
        lastDownloadDate = rawDate;
      }

      // SERVER TIME LOGIC (GMT+7)
      final serverNow = DateTime.now().toUtc().add(const Duration(hours: 7));
      int dailyCount = data['daily_download_count'] is int
          ? data['daily_download_count']
          : 0;

      bool isNewDay = true;
      if (lastDownloadDate != null) {
        final lastDownloadGmt7 =
            lastDownloadDate.toUtc().add(const Duration(hours: 7));
        if (lastDownloadGmt7.day == serverNow.day &&
            lastDownloadGmt7.month == serverNow.month &&
            lastDownloadGmt7.year == serverNow.year) {
          isNewDay = false;
        }
      }

      if (isNewDay) {
        dailyCount = 0;
      }

      if (dailyCount >= 50) {
        debugPrint("⏳ Daily Download Limit Reached ($dailyCount/50).");
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("⚠️ CanDownload Check Error: $e");
      return true; // Fail open
    }
  }

  // Counter Logic (Updated for Daily Limit)
  Future<void> _incrementUserStat(String fieldName) async {
    if (!_initialized || _userId == null) return;

    if (Platform.isWindows &&
        fieldName != 'download_count' &&
        fieldName != 'play_count') {
      // Windows: Use client-side UTC time for simple stats
      await _restWrite('metrics', _userId!,
          {'last_active': DateTime.now().toUtc().toIso8601String()},
          isUpdate: true);
      return;
    }

    try {
      // For Windows complex logic (Read-Modify-Write)
      if (Platform.isWindows) {
        // 1. READ
        final url = Uri.parse('$_firestoreBaseUrl/metrics/$_userId');
        final response = await http.get(url);
        Map<String, dynamic> data = {};
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          data = _convertFirestoreFields(json['fields'] ?? {});
        }

        final Map<String, dynamic> updates = {};
        updates['last_active'] = DateTime.now().toUtc().toIso8601String();

        // Increment Simple Stat
        int currentVal = (data[fieldName] is int) ? data[fieldName] : 0;
        updates[fieldName] = currentVal + 1;

        // Daily Logic
        if (fieldName == 'download_count' || fieldName == 'play_count') {
          String lastDateKey = fieldName == 'download_count'
              ? 'last_download_date'
              : 'last_play_date';
          String dailyCountKey = fieldName == 'download_count'
              ? 'daily_download_count'
              : 'daily_play_count';

          updates[lastDateKey] = DateTime.now().toUtc().toIso8601String();

          final dynamic rawDate = data[lastDateKey];
          DateTime? lastDate;
          if (rawDate is String) lastDate = DateTime.tryParse(rawDate);
          if (rawDate is DateTime) lastDate = rawDate;

          final serverNow =
              DateTime.now().toUtc().add(const Duration(hours: 7));
          bool isNewDay = true;
          if (lastDate != null) {
            final lastDateGmt7 = lastDate.toUtc().add(const Duration(hours: 7));
            if (lastDateGmt7.day == serverNow.day &&
                lastDateGmt7.month == serverNow.month &&
                lastDateGmt7.year == serverNow.year) {
              isNewDay = false;
            }
          }

          int dailyVal = (data[dailyCountKey] is int) ? data[dailyCountKey] : 0;
          if (isNewDay) {
            updates[dailyCountKey] = 1;
          } else {
            updates[dailyCountKey] = dailyVal + 1;
          }
        }

        // 2. WRITE
        await _restWrite('metrics', _userId!, updates, isUpdate: true);
        return;
      }

      // NATIVE LOGIC
      final Map<String, dynamic> updates = {
        fieldName: FieldValue.increment(1),
        'last_active': FieldValue.serverTimestamp(),
      };

      // Specifically for daily counters (downloads & plays)
      if (fieldName == 'download_count' || fieldName == 'play_count') {
        String lastDateKey = fieldName == 'download_count'
            ? 'last_download_date'
            : 'last_play_date';
        String dailyCountKey = fieldName == 'download_count'
            ? 'daily_download_count'
            : 'daily_play_count';

        updates[lastDateKey] = FieldValue.serverTimestamp();

        // ⚠️ REFACTORED: Removed Transaction to prevent Windows Native Crash
        final docRef =
            FirebaseFirestore.instance.collection('metrics').doc(_userId);
        final snapshot = await docRef.get();

        if (!snapshot.exists) {
          await docRef
              .set({...updates, dailyCountKey: 1}, SetOptions(merge: true));
        } else {
          final data = snapshot.data()!;
          final lastDate = (data[lastDateKey] as Timestamp?)?.toDate();

          // SERVER TIME LOGIC (GMT+7)
          final serverNow =
              DateTime.now().toUtc().add(const Duration(hours: 7));

          bool isNewDay = true;
          if (lastDate != null) {
            final lastDateGmt7 = lastDate.toUtc().add(const Duration(hours: 7));
            if (lastDateGmt7.day == serverNow.day &&
                lastDateGmt7.month == serverNow.month &&
                lastDateGmt7.year == serverNow.year) {
              isNewDay = false;
            }
          }

          if (isNewDay) {
            updates[dailyCountKey] = 1; // Reset to 1 (New Day)
          } else {
            updates[dailyCountKey] = FieldValue.increment(1); // Increment
          }
          await docRef.set(updates, SetOptions(merge: true));
        }
        return;
      }

      await FirebaseFirestore.instance
          .collection('metrics')
          .doc(_userId)
          .set(updates, SetOptions(merge: true));
    } catch (e) {
      debugPrint("⚠️ Update Stat Error: $e");
    }
  }

  // HEARTBEAT LOGIC
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (_userId != null) {
        _incrementUserStat('heartbeat_ticks');
      }
    });
  }

  // UPDATE IDENTITY (Hostname etc)
  Future<void> _updateUserIdentity() async {
    if (!_initialized || _userId == null) return;
    try {
      final hostname = Platform.localHostname;
      final os = Platform.operatingSystem;
      final osVersion = Platform.operatingSystemVersion;

      if (Platform.isWindows) {
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
      } else {
        await FirebaseFirestore.instance
            .collection('metrics')
            .doc(_userId)
            .set({
          'hostname': hostname,
          'os': os,
          'os_version': osVersion,
          'last_active': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("⚠️ Update Identity Error: $e");
    }
  }

  // SYNC LOCAL STATS (Called on Startup)
  Future<void> syncLocalStats(int localTotal) async {
    if (!_initialized || _userId == null) return;
    try {
      if (Platform.isWindows) {
        await _restWrite(
            'metrics',
            _userId!,
            {
              'local_total_plays': localTotal,
              'play_count': localTotal, // FORCE SYNC TO MAIN COUNTER
            },
            isUpdate: true);
      } else {
        await FirebaseFirestore.instance
            .collection('metrics')
            .doc(_userId)
            .set({
          'local_total_plays': localTotal,
          'play_count': localTotal, // FORCE SYNC TO MAIN COUNTER
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("⚠️ Sync Local Stats Error: $e");
    }
  }

  // Helper to get or generate a stable ID (Hashed Hardware ID)
  Future<String> _getStableUserId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String rawId = '';

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        rawId = webInfo.userAgent ?? 'web_user';
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        rawId = winInfo.deviceId; // Machine GUID
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        rawId = androidInfo.id; // SSAID
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
        // Fallback for unknown platforms
        rawId = "fallback_${Platform.localHostname}";
      }

      // HASH THE ID (Privacy)
      // SHA-256(RawID) -> Unique Anonymous ID
      final bytes = utf8.encode(rawId);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      debugPrint("⚠️ Hardware ID Error: $e");
      // Fallback to Prefs logic if Hardware check completely fails
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

  // --- ADMIN METHODS ---

  // Verify Admin Access Code
  Future<bool> verifyAdminCode(String code) async {
    if (Platform.isWindows) {
      try {
        final url = Uri.parse('$_firestoreBaseUrl/settings/admin');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final fields = json['fields'];
          final serverCode = fields['access_code']?['stringValue'];
          return serverCode == code;
        }
      } catch (e) {
        debugPrint("⚠️ Admin Verify Error: $e");
      }
      return false;
    } else {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('settings')
            .doc('admin')
            .get();
        return doc.exists && doc.data()?['access_code'] == code;
      } catch (e) {
        return false;
      }
    }
  }

  // Admin Data Model
  // Simple wrapper to unify Native Snapshot and REST JSON
  Stream<List<AdminUserData>> getAllUserMetrics() {
    if (Platform.isWindows) {
      // POLLING STREAM (Every 15 seconds)
      return Stream.periodic(const Duration(seconds: 15), (_) async {
        return await _fetchAllMetricsRest();
      }).asyncMap((event) async => await event);
    } else {
      // NATIVE STREAM
      return FirebaseFirestore.instance
          .collection('metrics')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return AdminUserData(id: doc.id, data: doc.data());
        }).toList();
      });
    }
  }

  Future<List<AdminUserData>> _fetchAllMetricsRest() async {
    try {
      final url = Uri.parse('$_firestoreBaseUrl/metrics?pageSize=100');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final documents = json['documents'] as List?;
        if (documents == null) return [];

        return documents.map((doc) {
          final name = doc['name'] as String; // .../metrics/USER_ID
          final id = name.split('/').last;
          final fields = doc['fields'] as Map<String, dynamic>? ?? {};
          final data = _convertFirestoreFields(fields);
          return AdminUserData(id: id, data: data);
        }).toList();
      }
    } catch (e) {
      // Silent error for polling
    }
    return [];
  }

  // Helper to convert Firestore REST JSON to standard Map
  Map<String, dynamic> _convertFirestoreFields(Map<String, dynamic> fields) {
    final Map<String, dynamic> data = {};
    fields.forEach((key, value) {
      if (value['stringValue'] != null) {
        data[key] = value['stringValue'];
      } else if (value['integerValue'] != null) {
        data[key] = int.tryParse(value['integerValue']);
      } else if (value['doubleValue'] != null) {
        data[key] = value['doubleValue'];
      } else if (value['booleanValue'] != null) {
        data[key] = value['booleanValue'];
      } else if (value['timestampValue'] != null) {
        data[key] = Timestamp.fromDate(DateTime.parse(value['timestampValue']));
      }
    });
    return data;
  }

  // Admin Actions
  Future<void> adminAction(String userId, String action) async {
    // action: 'ban', 'unban', 'reset_quota', 'delete'
    if (Platform.isWindows) {
      if (action == 'delete') {
        await _restDelete('metrics/$userId');
      } else {
        Map<String, dynamic> update = {};
        if (action == 'ban') update = {'is_banned': true};
        if (action == 'unban') update = {'is_banned': false};
        if (action == 'reset_quota') update = {'daily_download_count': 0};

        if (update.isNotEmpty) {
          await _restWrite('metrics', userId, update, isUpdate: true);
        }
      }
    } else {
      final ref = FirebaseFirestore.instance.collection('metrics').doc(userId);
      if (action == 'delete') {
        await ref.delete();
      } else if (action == 'ban') {
        await ref.set({'is_banned': true}, SetOptions(merge: true));
      } else if (action == 'unban') {
        await ref.set({'is_banned': false}, SetOptions(merge: true));
      } else if (action == 'reset_quota') {
        await ref.set({'daily_download_count': 0}, SetOptions(merge: true));
      }
    }
  }

  Future<void> _restDelete(String docPath) async {
    final url = Uri.parse('$_firestoreBaseUrl/$docPath');
    try {
      await http.delete(url);
    } catch (e) {
      debugPrint("⚠️ REST Delete Error: $e");
    }
  }
}

class AdminUserData {
  final String id;
  final Map<String, dynamic> data;
  AdminUserData({required this.id, required this.data});
}
