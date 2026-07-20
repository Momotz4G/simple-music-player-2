import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/schemas.dart';
import '../models/song_model.dart';
import 'pocketbase_service.dart';
import '../utils/stats_utils.dart';

class MetricsService {
  static final MetricsService _instance = MetricsService._internal();
  factory MetricsService() => _instance;
  MetricsService._internal();

  bool _initialized = false;
  bool get initialized => _initialized;
  String? _userId;
  String? get userId => _userId;

  // Mutex for sequential updates
  Future<void> _lastUpdateFuture = Future.value();

  // LOCAL SESSION TRACKING (for accurate quota enforcement)
  int _sessionDownloadCount = 0;
  DateTime? _sessionStartDate;
  int? _cachedDailyCountAtStart;

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 0. Load Persistent Device ID
      final hardwareId = await getDeviceIdentifier();

      // 🔗 If account is linked via Google OAuth, use the linked user ID instead
      final prefs = await SharedPreferences.getInstance();
      final linkedUserId = prefs.getString('pb_linked_user_id');
      
      // CRITICAL FIX: Update internal _userId to the synchronized identity
      _userId = linkedUserId ?? hardwareId;
      
      // 1. Initialize PocketBase (Unified for all platforms)
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
      await _updateUserIdentity();
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

  // ignore: unused_element
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
    // Global Artist Tracking
    if (song.artist.isNotEmpty) {
      await PocketBaseService().incrementArtistPlay(song.artist);
    }
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

  Future<void> trackSongPlayModel(SongModel song, {int? localTotal, int? totalMinutes}) async {
    if (PocketBaseService.isOffline) return; // 🔒 OFFLINE MODE: Skip cloud tracking
    await _incrementUserStat('play_count');
    // Global Artist Tracking
    if (song.artist.isNotEmpty) {
      await PocketBaseService().incrementArtistPlay(song.artist);
    }
    if (localTotal != null || totalMinutes != null) {
      // SERIALIZE: Chain onto the mutex to prevent race conditions
      _lastUpdateFuture = _lastUpdateFuture.whenComplete(() async {
        try {
          // CRITICAL FIX: Never overwrite cloud values with a LOWER local value.
          // On multi-device setups, each device has its own local Isar DB.
          // Without this check, a device with fewer plays would nuke the cloud total.
          final currentCloud = await PocketBaseService().getUserMetrics();
          final cloudPlayCount = currentCloud?['play_count'] ?? 0;
          final cloudMinutes = currentCloud?['total_minutes'] ?? 0;

          final safePlayCount = localTotal != null
              ? (localTotal > cloudPlayCount ? localTotal : cloudPlayCount)
              : null;
          // DELTA-BASED MINUTES SYNC: Track incremental listening time
          // instead of max(local, cloud). This ensures minutes always go up,
          // even on multi-device setups where cloud > local.
          int? safeMinutes;
          if (totalMinutes != null) {
            final prefs = await SharedPreferences.getInstance();
            final lastSyncedLocal = prefs.getInt('last_synced_local_minutes') ?? totalMinutes;
            final delta = totalMinutes - lastSyncedLocal;
            if (delta > 0) {
              safeMinutes = cloudMinutes + delta;
            } else {
              safeMinutes = cloudMinutes;
            }
            // ALWAYS persist snapshot so next call can compute the real delta
            await prefs.setInt('last_synced_local_minutes', totalMinutes);
          }

          final updates = <String, dynamic>{
            if (safePlayCount != null) 'local_total_plays': localTotal,
            if (safePlayCount != null) 'play_count': safePlayCount,
            if (safeMinutes != null) 'total_minutes': safeMinutes,
          };
          debugPrint("📊 trackSongPlayModel: cloud_plays=$cloudPlayCount local=$localTotal → safe=$safePlayCount | cloud_min=$cloudMinutes local_min=$totalMinutes → safe=$safeMinutes");
          if (updates.isNotEmpty) {
            await _pbWrite(updates);
          }
        } catch (e) {
          debugPrint("⚠️ trackSongPlayModel write error: $e");
        }
      });
      await _lastUpdateFuture;
    }
  }


  Future<void> trackDownload(Song song) async {
    await _incrementUserStat('download_count');
  }

  Future<void> trackDownloadMetadata(dynamic metadata) async {
    // INCREMENT LOCAL SESSION COUNTER FIRST (instant, no race condition)
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

      // CHECK IF LOCAL SESSION IS FROM TODAY
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
      if (currentData == null) {
        return dailyDownloadLimit - _sessionDownloadCount;
      }

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

      // CACHE THE SERVER COUNT AT START OF SESSION
      if (_cachedDailyCountAtStart == null) {
        _cachedDailyCountAtStart = serverDailyCount;
        _sessionStartDate = now;
        _sessionDownloadCount = 0; // Reset session count when caching
      }

      // USE LOCAL SESSION COUNTER FOR ACCURATE REAL-TIME QUOTA
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

    // SERIALIZE REQUESTS (Prevents Race Condition in Bulk Downloads)
    // Chain this request to the end of the previous one
    _lastUpdateFuture = _lastUpdateFuture.whenComplete(() async {
      try {
        await _performIncrement(fieldName);
      } catch (e) {
        debugPrint("⚠️ Sequential Increment Error: $e");
      }
    });

    await _lastUpdateFuture;
  }

  Future<void> _performIncrement(String fieldName) async {
    try {
      // 1. Fetch Current Data
      final currentData = await PocketBaseService().getUserMetrics();
      final Map<String, dynamic> updates = {};

      // 2. Prepare Current Values
      int currentTotal = 0;
      int currentDaily = 0;
      int currentWeekly = 0;
      String? lastDateStr;

      // Determine which daily field matches the total field
      String dailyFieldName = '';
      String weeklyFieldName = '';
      String dateFieldName = '';

      if (fieldName == 'play_count') {
        currentTotal = currentData?['play_count'] ?? 0;
        currentDaily = currentData?['daily_play_count'] ?? 0;
        currentWeekly = currentData?['weekly_play_count'] ?? 0;
        lastDateStr = currentData?['last_play_date'];
        dailyFieldName = 'daily_play_count';
        weeklyFieldName = 'weekly_play_count';
        dateFieldName = 'last_play_date';
      } else if (fieldName == 'download_count') {
        currentTotal = currentData?['download_count'] ?? 0;
        currentDaily = currentData?['daily_download_count'] ?? 0;
        lastDateStr = currentData?['last_download_date'];
        dailyFieldName = 'daily_download_count';
        dateFieldName = 'last_download_date';
      }

      // 3. Logic: Daily & Weekly Reset Check (FOLLOWS GMT+7 SERVER TIME)
      final nowUTC = DateTime.now().toUtc();
      bool isNewDay = true;
      bool isNewWeek = true;

      if (lastDateStr != null && lastDateStr.isNotEmpty) {
        try {
          // Parse last date as UTC
          final lastDateUTC = DateTime.parse(lastDateStr).toUtc();
          
          final sameDay = StatsUtils.isSameDayGMT7(nowUTC, lastDateUTC);
          final sameWeek = StatsUtils.isSameWeekGMT7(nowUTC, lastDateUTC);
          
          if (sameDay) isNewDay = false;
          if (sameWeek) isNewWeek = false;

          debugPrint(
              "📊 Reset Check: Now=${nowUTC.toIso8601String()} Last=$lastDateStr SameDay=$sameDay SameWeek=$sameWeek");
        } catch (e) {
          debugPrint("⚠️ Date Parse Error: $e (LastDateStr: $lastDateStr)");
        }
      } else {
        debugPrint("📊 Reset Check: No lastDateStr found, assuming new day.");
      }

      if (isNewDay) {
        debugPrint("📊 Resetting daily counter (was: $currentDaily)");
        currentDaily = 0; 
      }
      if (isNewWeek) {
        debugPrint("📊 Resetting weekly counter (was: $currentWeekly)");
        currentWeekly = 0;
      }

      // 4. Increment
      debugPrint("📊 Incrementing: Total=$currentTotal -> ${currentTotal + 1}, Daily=$currentDaily -> ${currentDaily + 1}");
      currentTotal += 1;
      currentDaily += 1;
      currentWeekly += 1;

      // 5. Prepare Payload (Strict UTC ISO strings)
      final nowISO = nowUTC.toIso8601String();
      updates[fieldName] = currentTotal;
      if (dailyFieldName.isNotEmpty) {
        updates[dailyFieldName] = currentDaily;
      }
      if (weeklyFieldName.isNotEmpty) {
        updates[weeklyFieldName] = currentWeekly;
      }
      if (dateFieldName.isNotEmpty) {
        updates[dateFieldName] = nowISO;
      }

      // Always update last active in UTC
      updates['last_active'] = nowISO;

      // 6. Write Back
      await _restWrite('metrics', _userId!, updates, isUpdate: true);

      debugPrint(
          "📊 Verified Write to Cloud: $fieldName=$currentTotal, Daily=$currentDaily (isNewDay=$isNewDay)");
    } catch (e) {
      debugPrint("⚠️ Increment Error: $e");
    }
  }

  // --- HEARTBEAT ---

  void _startHeartbeat() {
    // Send immediate heartbeat on startup
    if (_initialized && _userId != null && !PocketBaseService.isOffline) {
      PocketBaseService().sendHeartbeat();
    }

    // Then send every 45 seconds
    Stream.periodic(const Duration(seconds: 45)).listen((_) {
      if (_initialized && _userId != null && !PocketBaseService.isOffline) {
        PocketBaseService().sendHeartbeat();
      }
    });
  }

  // --- IDENTITY ---

  Future<void> _updateUserIdentity() async {
    debugPrint("📊 [MetricsService] _updateUserIdentity started");
    if (PocketBaseService.isOffline) {
      debugPrint("📊 [MetricsService] _updateUserIdentity skipped (OFFLINE)");
      return; // 🔒 OFFLINE MODE
    }
    if (!_initialized) {
      debugPrint("📊 [MetricsService] _updateUserIdentity skipped (NOT INITIALIZED)");
      return;
    }
    if (_userId == null) return;
    try {
      final hostname = Platform.localHostname;
      final os = Platform.operatingSystem;
      final osVersion = Platform.operatingSystemVersion;
      
      String clientVersion = "Unknown";
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        clientVersion = "${packageInfo.version} (${packageInfo.buildNumber})";
      } catch (_) {}

      await _restWrite(
          'metrics',
          _userId!,
          {
            'hostname': hostname,
            'os': os,
            'os_version': osVersion,
            'client_version': clientVersion, // NEW
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
      // CRITICAL FIX: Never overwrite cloud with lower local value
      final currentCloud = await PocketBaseService().getUserMetrics();
      final cloudPlayCount = currentCloud?['play_count'] ?? 0;
      final safePlayCount =
          localTotal > cloudPlayCount ? localTotal : cloudPlayCount;

      await _restWrite(
          'metrics',
          _userId!,
          {
            'local_total_plays': localTotal,
            'play_count': safePlayCount,
          },
          isUpdate: true);
    } catch (e) {
      debugPrint("⚠️ Sync Local Stats Error: $e");
    }
  }

  Future<void> syncAdvancedStats({
    String? topArtist,
    String? topTrack,
    int? totalMinutes,
    int? playCount,
    int? dailyPlayCount,
    int? weeklyPlayCount,
    String? selectedTitle,
    int? maxRepeatStreak,
    int? currentRepeatStreak,
    String? lastRepeatSongId,
    int? lastRepeatTime,
    int? weeklyWinsCount,
    int? weeklyPodiumsCount,
    int? topArtistPlays,
    int? mostListenedPlays,
    Map<String, int>? artistMinutes,
  }) async {
    if (!_initialized || _userId == null) {
      debugPrint("⚠️ syncAdvancedStats: SKIPPED - initialized=$_initialized, userId=$_userId");
      return;
    }
    if (PocketBaseService.isOffline) return; // 🔒 OFFLINE MODE: Skip cloud sync
    try {
      // CRITICAL FIX: Never overwrite cloud with lower local values (Multi-device protection)
      final currentCloud = await PocketBaseService().getUserMetrics();

      final cloudMinutes = currentCloud?['total_minutes'] ?? 0;
      final cloudPlayCount = currentCloud?['play_count'] ?? 0;
      final cloudDaily = currentCloud?['daily_play_count'] ?? 0;
      final cloudWeekly = currentCloud?['weekly_play_count'] ?? 0;
      final cloudTopArtistPlays = currentCloud?['top_artist_plays'] ?? 0;
      final cloudMostListenedPlays = currentCloud?['most_listened_plays'] ?? 0;

      // DELTA-BASED MINUTES SYNC: Track incremental listening time
      // instead of max(local, cloud). This ensures minutes always go up,
      // even on multi-device setups where cloud > local.
      int? safeMinutes;
      if (totalMinutes != null) {
        final prefs = await SharedPreferences.getInstance();
        final lastSyncedLocal = prefs.getInt('last_synced_local_minutes') ?? totalMinutes;
        final delta = totalMinutes - lastSyncedLocal;
        if (delta > 0) {
          safeMinutes = cloudMinutes + delta;
        } else {
          safeMinutes = cloudMinutes;
        }
        // ALWAYS persist snapshot so next call can compute the real delta
        await prefs.setInt('last_synced_local_minutes', totalMinutes);
      }
      final safePlayCount = (playCount != null && playCount > cloudPlayCount)
          ? playCount
          : (playCount != null ? cloudPlayCount : null);
      final safeDaily =
          (dailyPlayCount != null && dailyPlayCount > cloudDaily)
              ? dailyPlayCount
              : (dailyPlayCount != null ? cloudDaily : null);
      final safeWeekly =
          (weeklyPlayCount != null && weeklyPlayCount > cloudWeekly)
              ? weeklyPlayCount
              : (weeklyPlayCount != null ? cloudWeekly : null);
      final safeTopArtistPlays =
          (topArtistPlays != null && topArtistPlays > cloudTopArtistPlays)
              ? topArtistPlays
              : (topArtistPlays != null ? cloudTopArtistPlays : null);
      final safeMostListenedPlays =
          (mostListenedPlays != null && mostListenedPlays > cloudMostListenedPlays)
              ? mostListenedPlays
              : (mostListenedPlays != null ? cloudMostListenedPlays : null);

      final cloudMaxRepeatStreak = currentCloud?['max_repeat_streak'] ?? 0;
      final safeMaxRepeatStreak = (maxRepeatStreak != null && maxRepeatStreak > cloudMaxRepeatStreak)
          ? maxRepeatStreak
          : (maxRepeatStreak != null ? cloudMaxRepeatStreak : null);

      final cloudWins = currentCloud?['weekly_wins_count'] ?? 0;
      final cloudPodiums = currentCloud?['weekly_podiums_count'] ?? 0;
      final safeWins = (weeklyWinsCount != null && weeklyWinsCount > cloudWins)
          ? weeklyWinsCount
          : (weeklyWinsCount != null ? cloudWins : null);
      final safePodiums = (weeklyPodiumsCount != null && weeklyPodiumsCount > cloudPodiums)
          ? weeklyPodiumsCount
          : (weeklyPodiumsCount != null ? cloudPodiums : null);

      final cloudTitle = currentCloud?['selected_title'] as String?;
      
      // TITLE PROTECTION: Never let a low-rarity title from another device overwrite a prestige cloud title.
      // Note: Competitive titles ("Top X Global") CAN be saved here when intentionally equipped.
      // The DISPLAY side validates them against actual rank — if rank doesn't match, it shows the fallback title.
      bool shouldUpdateTitle = true;
      if (selectedTitle != null && cloudTitle != null && selectedTitle != cloudTitle) {
        final newDef = StatsUtils.resolveTitleDefinition(selectedTitle, safeMinutes ?? totalMinutes ?? 0);
        final cloudDef = StatsUtils.resolveTitleDefinition(cloudTitle, cloudMinutes);
        
        // If current cloud title is higher rarity, don't downgrade it.
        if (cloudDef.rarityTier > newDef.rarityTier) {
          shouldUpdateTitle = false;
          debugPrint("🛡️ Title Protection: Blocked downgrading cloud title '$cloudTitle' (Tier ${cloudDef.rarityTier}) to '$selectedTitle' (Tier ${newDef.rarityTier})");
        }
      }

      final cloudTopArtist = currentCloud?['top_artist'] as String?;
      final cloudTopTrack = currentCloud?['top_track'] as String?;

      final updates = <String, dynamic>{
        // STATS PROTECTION: Only update Top Artist/Track if cloud is empty or "N/A"
        if (topArtist != null && (cloudTopArtist == null || cloudTopArtist.isEmpty || cloudTopArtist == "N/A")) 
          'top_artist': topArtist,
        if (topTrack != null && (cloudTopTrack == null || cloudTopTrack.isEmpty || cloudTopTrack == "N/A")) 
          'top_track': topTrack,
        if (safeMinutes != null) 'total_minutes': safeMinutes,
        if (safePlayCount != null) 'play_count': safePlayCount,
        if (safeDaily != null) 'daily_play_count': safeDaily,
        if (safeWeekly != null) 'weekly_play_count': safeWeekly,
        if (safeMaxRepeatStreak != null) 'max_repeat_streak': safeMaxRepeatStreak,
        if (currentRepeatStreak != null) 'current_repeat_streak': currentRepeatStreak,
        if (lastRepeatSongId != null) 'last_repeat_song_id': lastRepeatSongId,
        if (lastRepeatTime != null) 'last_repeat_time': lastRepeatTime,
        if (safeWins != null) 'weekly_wins_count': safeWins,
        if (safePodiums != null) 'weekly_podiums_count': safePodiums,
        if (selectedTitle != null && shouldUpdateTitle) 'selected_title': selectedTitle,
        if (safeTopArtistPlays != null) 'top_artist_plays': safeTopArtistPlays,
        if (safeMostListenedPlays != null) 'most_listened_plays': safeMostListenedPlays,
        'last_active': DateTime.now().toUtc().toIso8601String(),
      };

      // 🎵 ARTIST MINUTES SYNC: Merge local with cloud, keeping the highest per artist
      if (artistMinutes != null && artistMinutes.isNotEmpty) {
        final cloudArtistMinutesRaw = currentCloud?['artist_minutes'];
        final Map<String, int> cloudArtistMinutes = {};
        if (cloudArtistMinutesRaw is Map) {
          cloudArtistMinutesRaw.forEach((k, v) {
            if (v is int) {
              cloudArtistMinutes[k.toString()] = v;
            } else if (v is num) {
              cloudArtistMinutes[k.toString()] = v.toInt();
            }
          });
        }
        // Merge: take the higher value for each artist
        final mergedArtistMinutes = Map<String, int>.from(cloudArtistMinutes);
        artistMinutes.forEach((artist, mins) {
          final existing = mergedArtistMinutes[artist] ?? 0;
          if (mins > existing) mergedArtistMinutes[artist] = mins;
        });
        updates['artist_minutes'] = mergedArtistMinutes;
      }

      if (updates.length > 1) {
        // More than just last_active
        debugPrint(
            "📊 syncAdvancedStats: WRITING total_minutes=$totalMinutes (safe=$safeMinutes), topArtist=$topArtist, topTrack=$topTrack, maxRepeatStreak=$maxRepeatStreak");
        // SERIALIZE through mutex
        _lastUpdateFuture = _lastUpdateFuture.whenComplete(() async {
          await _pbWrite(updates);
        });
        await _lastUpdateFuture;
        debugPrint("📊 syncAdvancedStats: SUCCESS");
      } else {
        debugPrint(
            "⚠️ syncAdvancedStats: No meaningful data to sync (only last_active)");
      }
    } catch (e) {
      debugPrint("⚠️ Sync Advanced Stats Error: $e");
    }
  }

  Future<void> forceSyncAdvancedStats({
    String? topArtist,
    String? topTrack,
    int? totalMinutes,
    int? playCount,
    int? dailyPlayCount,
    int? weeklyPlayCount,
    String? selectedTitle,
    int? maxRepeatStreak,
    int? weeklyWinsCount,
    int? weeklyPodiumsCount,
  }) async {
    if (!_initialized || _userId == null) return;
    try {
      final updates = <String, dynamic>{
        if (topArtist != null) 'top_artist': topArtist,
        if (topTrack != null) 'top_track': topTrack,
        if (totalMinutes != null) 'total_minutes': totalMinutes,
        if (playCount != null) 'play_count': playCount,
        if (dailyPlayCount != null) 'daily_play_count': dailyPlayCount,
        if (weeklyPlayCount != null) 'weekly_play_count': weeklyPlayCount,
        if (maxRepeatStreak != null) 'max_repeat_streak': maxRepeatStreak,
        if (weeklyWinsCount != null) 'weekly_wins_count': weeklyWinsCount,
        if (weeklyPodiumsCount != null) 'weekly_podiums_count': weeklyPodiumsCount,
        if (selectedTitle != null) 'selected_title': selectedTitle,
        'last_active': DateTime.now().toUtc().toIso8601String(),
      };

      debugPrint("🚨 FORCE SYNC: Overwriting cloud with local data...");
      _lastUpdateFuture = _lastUpdateFuture.whenComplete(() async {
        await _pbWrite(updates);
      });
      await _lastUpdateFuture;
      debugPrint("✅ FORCE SYNC: SUCCESS");
    } catch (e) {
      debugPrint("⚠️ Force Sync Error: $e");
    }
  }

  Future<int> getCurrentUserRank(int currentMinutes) async {
    return await PocketBaseService().calculateUserRank(currentMinutes);
  }

  // --- HARDWARE ID ---

  Future<String> getDeviceIdentifier() async {
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
        final prefs = await SharedPreferences.getInstance();
        var stableId = prefs.getString('stable_android_device_id');
        if (stableId == null) {
          final androidInfo = await deviceInfo.androidInfo;
          stableId = androidInfo.id;
          await prefs.setString('stable_android_device_id', stableId);
        }
        rawId = stableId;
      } else if (Platform.isIOS) {
        final prefs = await SharedPreferences.getInstance();
        var stableId = prefs.getString('stable_ios_device_id');
        if (stableId == null) {
          final iosInfo = await deviceInfo.iosInfo;
          stableId = iosInfo.identifierForVendor ?? 'ios_user';
          await prefs.setString('stable_ios_device_id', stableId);
        }
        rawId = stableId;
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

  Future<String> getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) return "Web Browser";
      if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        return winInfo.computerName;
      }
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return "${androidInfo.manufacturer} ${androidInfo.model}";
      }
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name;
      }
      if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return macInfo.computerName;
      }
      if (Platform.isLinux) {
        return Platform.localHostname;
      }
      return "Generic Device";
    } catch (e) {
      return "Unknown Device";
    }
  }

  // --- STUBS FOR ADMIN (Removed/Disabled) ---
  // Returns: 'admin', 'viewer', or null
  Future<String?> verifyAdminCode(String code) async {
    return await PocketBaseService().verifyAdminAccessCode(code);
  }

  // --- ADMIN FUNCTIONALITY ---

  Stream<AdminMetricsResult> getAllUserMetrics() {
    // Poll every 5 seconds for "Live" feel
    return Stream.periodic(const Duration(seconds: 5)).asyncMap((_) async {
      final result = await PocketBaseService().fetchAllMetrics();
      final items = (result['items'] as List<dynamic>?) ?? [];
      final totalCount = (result['totalCount'] as int?) ?? 0;
      return AdminMetricsResult(
        items: items
            .map((d) => AdminUserData(
                id: (d as Map<String, dynamic>)['user_id'] ?? 'unknown',
                data: d))
            .toList(),
        totalCount: totalCount,
      );
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

class AdminMetricsResult {
  final List<AdminUserData> items;
  final int totalCount;
  AdminMetricsResult({required this.items, required this.totalCount});
}
