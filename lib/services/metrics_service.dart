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
import '../env/env.dart';
import '../data/schemas.dart';
import '../models/song_model.dart';

class MetricsService {
  static final MetricsService _instance = MetricsService._internal();
  factory MetricsService() => _instance;
  MetricsService._internal();

  bool _initialized = false;
  bool get initialized => _initialized; // Expose initialized state
  String? _userId;
  String? get userId => _userId; // Expose User ID for Remote Control
  Timer? _heartbeatTimer;

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 0. Load Persistent Device ID
      // This ensures the ID stays the same across restarts on the same PC.
      _userId = await _getStableUserId();
      debugPrint("📊 MetricsService: Stable Device ID loaded: $_userId");

      // 1. Initialize Firebase with Envied keys
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: Env.firebaseApiKey,
          appId: Env.firebaseAppId,
          messagingSenderId: Env.firebaseMessagingSenderId,
          projectId: Env.firebaseProjectId,
          storageBucket: Env.firebaseStorageBucket,
          measurementId: Env.firebaseMeasurementId,
          authDomain: Env.firebaseAuthDomain,
        ),
      );

      // 2. Sign in Anonymously (Required for Firestore R/W access rules)
      await FirebaseAuth.instance.signInAnonymously();

      _initialized = true;

      // 3. Track App Open (Session)
      _trackEvent('app_session_start', {
        'platform': defaultTargetPlatform.name,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Start Heartbeat
      _startHeartbeat();

      // Update Identity info
      _updateUserIdentity();
    } catch (e) {
      debugPrint("⚠️ MetricsService Init Error: $e");
      // Mark as initialized so we don't block dependent services forever
      _initialized = true;
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

  /// Generic helper to write to Firestore
  /// Structure: metrics/{userId}/events/{autoId}
  Future<void> _trackEvent(String eventName, Map<String, dynamic> data) async {
    if (!_initialized || _userId == null) return;

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
      // Fail silently, don't crash the app for stats
      debugPrint("⚠️ Failed to track event: $e");
    }
  }

  // --- Specific Events ---

  Future<void> trackSongPlay(Song song, {int? localTotal}) async {
    await _trackEvent('song_play', {
      'title': song.title,
      'artist': song.artist,
      // 'source': song.source,
      'duration': song.duration,
      'local_total_plays': localTotal,
      'timestamp': FieldValue.serverTimestamp(),
    });
    // Increment Total Plays (and Daily Plays)
    await _incrementUserStat('play_count');

    // Sync Local Total directly to User doc if provided
    if (localTotal != null) {
      FirebaseFirestore.instance.collection('metrics').doc(_userId).set({
        'local_total_plays': localTotal,
        'play_count': localTotal, // FORCE SYNC
      }, SetOptions(merge: true));
    }
  }

  // Overload for SongModel (StatsProvider / PlayerProvider)
  Future<void> trackSongPlayModel(SongModel song, {int? localTotal}) async {
    await _trackEvent('song_play', {
      'title': song.title,
      'artist': song.artist,
      'duration': song.duration,
      'local_total_plays': localTotal, // Sync Local Total
      'timestamp': FieldValue.serverTimestamp(),
    });
    // Increment Total Plays (and Daily Plays)
    await _incrementUserStat('play_count');

    // Sync Local Total directly to User doc if provided
    if (localTotal != null) {
      FirebaseFirestore.instance.collection('metrics').doc(_userId).set({
        'local_total_plays': localTotal,
        'play_count': localTotal, // FORCE SYNC
      }, SetOptions(merge: true));
    }
  }

  Future<void> trackDownload(Song song) async {
    await _trackEvent('song_download', {
      'title': song.title,
      'artist': song.artist,
      'timestamp': FieldValue.serverTimestamp(),
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
      'timestamp': FieldValue.serverTimestamp(),
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
      final doc = await FirebaseFirestore.instance
          .collection('metrics')
          .doc(_userId)
          .get();
      if (!doc.exists) return true;

      final data = doc.data()!;

      // 1. Check Global Ban
      if (data['is_banned'] == true) {
        debugPrint("⛔ User is BANNED from downloads.");
        return false;
      }

      // 2. Check Daily Limit (GMT+7 Reset)
      final lastDownloadDate =
          (data['last_download_date'] as Timestamp?)?.toDate();

      // SERVER TIME LOGIC (GMT+7)
      final serverNow = DateTime.now().toUtc().add(const Duration(hours: 7));
      int dailyCount = data['daily_download_count'] ?? 0;

      // Reset count if new day (in GMT+7)
      // We must shift 'lastDownloadDate' to GMT+7 as well to compare days correctly
      // Note: Firestore Timestamps are UTC.

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

    try {
      // final now = DateTime.now(); // Removed (Using serverNow instead)
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
        // Just updating 'last_active' by calling this generic method
        // We pass 'heartbeat' as a dummy field to increment, or we could optimize
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

      await FirebaseFirestore.instance.collection('metrics').doc(_userId).set({
        'hostname': hostname,
        'os': os,
        'os_version': osVersion,
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("⚠️ Update Identity Error: $e");
    }
  }

  // SYNC LOCAL STATS (Called on Startup)
  Future<void> syncLocalStats(int localTotal) async {
    if (!_initialized || _userId == null) return;
    try {
      await FirebaseFirestore.instance.collection('metrics').doc(_userId).set({
        'local_total_plays': localTotal,
        'play_count': localTotal, // 🚀 FORCE SYNC TO MAIN COUNTER
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("⚠️ Sync Local Stats Error: $e");
    }
  }
}
