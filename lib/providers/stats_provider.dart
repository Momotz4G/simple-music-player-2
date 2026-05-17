import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import '../models/stat_model.dart';
import '../models/stat_delta.dart';
import '../models/song_model.dart';
import '../data/schemas.dart';
import '../services/debug_log_service.dart';
import '../services/sync_engine.dart';
import 'db_provider.dart';
import 'settings_provider.dart';
import '../utils/stats_utils.dart';
import '../services/pocketbase_service.dart';
import '../services/metrics_service.dart';
import 'profile_provider.dart';
import 'dart:async';

class StatsState {
  final Map<String, StatEntry> entries;
  final int maxRepeatStreak;
  final int currentRepeatStreak;
  final int weeklyWinsCount;
  final int weeklyPodiumsCount;
  StatsState({
    this.entries = const {},
    this.maxRepeatStreak = 0,
    this.currentRepeatStreak = 0,
    this.weeklyWinsCount = 0,
    this.weeklyPodiumsCount = 0,
  });
}

class StatsNotifier extends StateNotifier<StatsState> {
  final Ref ref;

  StatsNotifier(this.ref) : super(StatsState()) {
    _loadStats();
    _checkForHistoricalRewards();
    SyncEngine().addOnMergeCompleteListener(_onRemoteMergeComplete);
  }

  Timer? _syncTimer;

  /// Called by SyncEngine when pullAndMerge() completes with new data.
  void _onRemoteMergeComplete() {
    // Defer reload to next frame so UI doesn't hitch during merge
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _loadStats(triggerSync: false);
    });
  }

  /// Public method to refresh stats from Isar (e.g., after a remote merge).
  Future<void> refreshStats() async {
    await _loadStats(triggerSync: false);
  }

  @override
  void dispose() {
    SyncEngine().removeOnMergeCompleteListener(_onRemoteMergeComplete);
    _syncTimer?.cancel();
    super.dispose();
  }

  void _triggerSync() {
    // 🔒 OFFLINE MODE: Skip cloud sync, stats are saved locally in Isar
    if (ref.read(settingsProvider).isOfflineMode) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2),
        () => syncNow()); // Reduced to 2s for faster sync
  }

  Future<Map<String, int>> _getAccurateHistoryCounts() async {
    try {
      final dbService = ref.read(dbServiceProvider);
      final isar = await dbService.db;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Week start (Monday GMT+7)
      final weekStartDay = StatsUtils.getStartOfWeekGMT7();
      // Parse back to local for Isar query
      final weekStartParsed =
          DateTime.parse(weekStartDay.replaceFirst(' ', 'T')).toLocal();

      final dailyCount = await isar.historyEntrys
          .filter()
          .lastPlayedGreaterThan(todayStart)
          .count();

      final weeklyCount = await isar.historyEntrys
          .filter()
          .lastPlayedGreaterThan(weekStartParsed)
          .count();

      return {'daily': dailyCount, 'weekly': weeklyCount};
    } catch (e) {
      DebugLogService()
          .error("📊 Error calculating accurate history counts: $e");
      return {'daily': 0, 'weekly': 0};
    }
  }

  Future<void> syncNow() async {
    final history = await _getAccurateHistoryCounts();
    final calculated = StatsUtils.calculate(state,
        dailyPlaysOverride: history['daily'],
        weeklyPlaysOverride: history['weekly']);
    final profile = ref.read(profileProvider);
    final automaticTitle =
        StatsUtils.getAutomaticTitle(calculated.totalMinutes);

    // 👑 RANK VERIFICATION (Maintainable Competitive Titles)
    String? activeSelectedTitle = profile.selectedTitle;
    if (activeSelectedTitle == "Top 1 Global") {
      try {
        final topUsers = await PocketBaseService().fetchLeaderboard(
            sortBy: 'play_count', limit: 1, filter: 'nickname != ""');
        if (topUsers.isNotEmpty) {
          final topId = topUsers.first['user_id'];
          final myId = PocketBaseService().userId;
          if (topId != myId) {
            // ❌ LOST TOP 1! Revert immediately
            DebugLogService()
                .warning("👑 LOST GLOBAL TOP 1! Reverting title...");
            Future.microtask(
                () => ref.read(profileProvider.notifier).updateTitle(null));
            activeSelectedTitle = null;
          }
        }
      } catch (e) {
        // Ignore fetch errors during background sync
      }
    }

    await MetricsService().syncAdvancedStats(
      topArtist: calculated.topArtist?.key,
      topTrack: calculated.topTrack?.key,
      totalMinutes: calculated.totalMinutes,
      playCount: calculated.totalPlays,
      dailyPlayCount: calculated.dailyPlays,
      weeklyPlayCount: calculated.weeklyPlays,
      maxRepeatStreak: state.maxRepeatStreak,
      currentRepeatStreak: state.currentRepeatStreak,
      lastRepeatSongId:
          ref.read(sharedPrefsProvider).getString('last_played_track_id'),
      lastRepeatTime:
          ref.read(sharedPrefsProvider).getInt('last_track_play_time'),
      selectedTitle: activeSelectedTitle ?? automaticTitle,
      weeklyWinsCount: state.weeklyWinsCount,
      weeklyPodiumsCount: state.weeklyPodiumsCount,
      topArtistPlays: calculated.topArtist?.value,
      mostListenedPlays: calculated.topTrack?.value,
      artistMinutes: calculated.artistMinutes,
    );

    // 🚀 REFRESH LOCAL: Ensure local counters (wins, podiums, streak)
    // are updated if the cloud has higher values.
    await pullAndSyncRemoteData();
  }

  Future<void> _checkForHistoricalRewards() async {
    try {
      final prefs = ref.read(sharedPrefsProvider);
      final myId = PocketBaseService().userId;
      if (myId == null) return;

      final currentWeekStart = StatsUtils.getStartOfWeekGMT7();
      final lastRewardedWeekInput = prefs.getString('last_rewarded_week_start');

      if (lastRewardedWeekInput == currentWeekStart) {
        // Already processed this week
        return;
      }

      DebugLogService().info(
          "🏆 [Hall of Fame] Detecting new week... checking last week's results.");

      // 1. Fetch leaderboard from LAST week
      final lastWeekStart = StatsUtils.getStartOfLastWeekGMT7();
      final lastWeekEnd = currentWeekStart; // Exclusive

      // We filter by last_play_date in that window
      final results = await PocketBaseService().fetchLeaderboard(
        sortBy: 'weekly_play_count',
        limit: 10,
        filter:
            'last_play_date >= "$lastWeekStart" && last_play_date < "$lastWeekEnd"',
      );

      if (results.isEmpty) {
        // No plays recorded last week? Or no sync.
        await prefs.setString('last_rewarded_week_start', currentWeekStart);
        return;
      }

      // 2. Determine Rank
      int myRank = -1;
      for (int i = 0; i < results.length; i++) {
        if (results[i]['user_id'] == myId) {
          myRank = i + 1;
          break;
        }
      }

      if (myRank != -1 && myRank <= 3) {
        DebugLogService()
            .success("🏆 CONGRATS! You finished Rank #$myRank last week!");

        int newWins = state.weeklyWinsCount;
        int newPodiums = state.weeklyPodiumsCount;

        if (myRank == 1) newWins++;
        if (myRank <= 3) newPodiums++;

        // Update DB & Local
        await prefs.setInt('weekly_wins_count', newWins);
        await prefs.setInt('weekly_podiums_count', newPodiums);

        state = StatsState(
          entries: state.entries,
          maxRepeatStreak: state.maxRepeatStreak,
          currentRepeatStreak: state.currentRepeatStreak,
          weeklyWinsCount: newWins,
          weeklyPodiumsCount: newPodiums,
        );

        syncNow(); // PUSH THE NEW GLORY
      } else {
        DebugLogService().info(
            "👟 [Hall of Fame] Finished Rank #$myRank last week. Better luck next time!");
      }

      // 3. Mark as processed
      await prefs.setString('last_rewarded_week_start', currentWeekStart);
    } catch (e) {
      DebugLogService().error("🏆 Reward Check Error: $e");
    }
  }

  /// 📊 PULL & SYNC (Remote -> Local)
  /// Used to restore stats on a new device or merge stats when linking.
  Future<void> pullAndSyncRemoteData({bool isInitialLink = false}) async {
    try {
      final metrics = await PocketBaseService().getUserMetrics();
      if (metrics == null) return;

      final prefs = ref.read(sharedPrefsProvider);

      // 1. Minutes Sync (Cheat-Proof Merge)
      final cloudMinutes = metrics['total_minutes'] as int? ?? 0;
      final history = await _getAccurateHistoryCounts();
      final localCalculated = StatsUtils.calculate(state,
          dailyPlaysOverride: history['daily'],
          weeklyPlaysOverride: history['weekly']);
      final localMinutes = localCalculated.totalMinutes;

      // 🛡️ RE-LINK PROTECTION: Only use 'Additive' merge if this device has NEVER migrated before.
      // This prevents the user from adding the same 500 local minutes over and over by unlinking/relinking.
      final bool alreadyMigrated =
          prefs.getBool('has_migrated_stats_to_cloud') ?? false;

      int finalMinutes = localMinutes;

      if (isInitialLink && !alreadyMigrated) {
        // 🚀 ONE-TIME SAFE MERGE: First time this device joins a cloud account.
        // We take the MAX of key metrics to ensure the leaderboard reflects the best effort without doubling.
        final cloudPlayCount = metrics['play_count'] as int? ?? 0;
        final cloudDaily = metrics['daily_play_count'] as int? ?? 0;
        final cloudWeekly = metrics['weekly_play_count'] as int? ?? 0;

        final finalTotalPlays = (localCalculated.totalPlays > cloudPlayCount)
            ? localCalculated.totalPlays
            : cloudPlayCount;
        final finalDaily = (localCalculated.dailyPlays > cloudDaily)
            ? localCalculated.dailyPlays
            : cloudDaily;
        final finalWeekly = (localCalculated.weeklyPlays > cloudWeekly)
            ? localCalculated.weeklyPlays
            : cloudWeekly;
        finalMinutes =
            (localMinutes > cloudMinutes) ? localMinutes : cloudMinutes;

        // Push the merged totals to the cloud immediately!
        await MetricsService().syncAdvancedStats(
          totalMinutes: finalMinutes,
          playCount: finalTotalPlays,
          dailyPlayCount: finalDaily,
          weeklyPlayCount: finalWeekly,
        );

        await prefs.setBool('has_migrated_stats_to_cloud', true);
        DebugLogService().success(
            "📊 STATS: Safe Max-Merge Migration Success. New Minutes: $finalMinutes, Total Plays: $finalTotalPlays");
      } else {
        // 🚀 SYNC/RESTORE MODE: Device has already migrated or is just syncing.
        if (cloudMinutes > localMinutes) {
          finalMinutes = cloudMinutes;
          DebugLogService().info(
              "📊 STATS: Cloud higher ($cloudMinutes > $localMinutes). Restoring...");
        } else {
          finalMinutes = localMinutes;
        }
      }

      // 2. Multi-Field Restore (Streak, Wins, Podium)
      final cloudStreak = metrics['max_repeat_streak'] as int? ?? 0;
      final cloudWins = metrics['weekly_wins_count'] as int? ?? 0;
      final cloudPodiums = metrics['weekly_podiums_count'] as int? ?? 0;

      // Update local storage: Scale up Isar entries to match cloud minutes
      if (finalMinutes > localMinutes && localMinutes > 0) {
        final ratio = finalMinutes / localMinutes;
        DebugLogService().info(
            "📊 STATS: Scaling local entries by ${ratio.toStringAsFixed(2)}x to match cloud ($finalMinutes mins)");
        final dbService = ref.read(dbServiceProvider);
        final isar = await dbService.db;
        await isar.writeTxn(() async {
          final allStats = await isar.savedStats.where().findAll();
          for (var s in allStats) {
            s.totalSeconds = (s.totalSeconds * ratio).round();
            await isar.savedStats.put(s);
          }
        });
      }

      if (cloudStreak > state.maxRepeatStreak) {
        await prefs.setInt('max_repeat_streak', cloudStreak);
      }
      if (cloudWins > state.weeklyWinsCount) {
        await prefs.setInt('weekly_wins_count', cloudWins);
      }
      if (cloudPodiums > state.weeklyPodiumsCount) {
        await prefs.setInt('weekly_podiums_count', cloudPodiums);
      }

      // If anything changed, reload stats to refresh state (without re-syncing to avoid infinite loop)
      if (finalMinutes > localMinutes || cloudStreak > state.maxRepeatStreak) {
        await _loadStats(triggerSync: false);
      }
    } catch (e) {
      DebugLogService().error("📊 Sync Stats Error: $e");
    }
  }

  Future<void> _loadStats({bool triggerSync = true}) async {
    DebugLogService().info("📈 STATS: Loading stats from Isar...");
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;

    // 1. Check if migration is needed
    final prefs = ref.read(sharedPrefsProvider);
    if (prefs.containsKey('extended_stats')) {
      await _migrateFromPrefs(prefs, isar);
    }

    // 2. Load from Isar
    final savedStats = await isar.savedStats.where().findAll();
    final Map<String, StatEntry> loaded = {};

    for (var s in savedStats) {
      loaded[s.statId] = StatEntry(
        id: s.statId,
        title: s.title,
        artist: s.artist,
        album: s.album,
        playCount: s.playCount,
        totalSeconds: s.totalSeconds,
        lastKnownPath: s.lastKnownPath,
        lastPlayed: s.lastPlayed, // 📅 NEW
      );
    }

    final maxRepeatStreak = prefs.getInt('max_repeat_streak') ?? 0;
    final currentStreak = prefs.getInt('current_repeat_streak') ?? 0;
    final wins = prefs.getInt('weekly_wins_count') ?? 0;
    final podiums = prefs.getInt('weekly_podiums_count') ?? 0;

    state = StatsState(
      entries: loaded,
      maxRepeatStreak: maxRepeatStreak,
      currentRepeatStreak: currentStreak,
      weeklyWinsCount: wins,
      weeklyPodiumsCount: podiums,
    );
    DebugLogService().info("📈 STATS: Loaded ${loaded.length} stat entries");

    final history = await _getAccurateHistoryCounts();
    final calculated = StatsUtils.calculate(state,
        dailyPlaysOverride: history['daily'],
        weeklyPlaysOverride: history['weekly']);

    // 🛡️ ANTI-CORRUPTION AUTO-REPAIR (v1.1 Mathematical Clamp)
    // The previous bug ONLY scaled totalSeconds, leaving playCount perfectly intact!
    // We mathematically clamp totalSeconds to a max of 5 mins (300s) per genuine play.
    final hasRunRepair = prefs.getBool('has_run_v1_1_stats_repair') ?? false;
    if (!hasRunRepair) {
      bool neededRepair = false;
      await isar.writeTxn(() async {
        final allStats = await isar.savedStats.where().findAll();
        for (var s in allStats) {
          if (s.playCount > 0) {
            // If the seconds-per-play exceeds 5 minutes (300 seconds), it was inflated!
            if ((s.totalSeconds / s.playCount) > 300) {
              // Clamp it back to an average of 3.5 minutes (210 seconds) per genuine play
              s.totalSeconds = s.playCount * 210;
              await isar.savedStats.put(s);
              neededRepair = true;
            }
          } else if (s.totalSeconds > 600) {
            // If playCount is 0 (partial listening), cap the orphaned seconds to 10 mins
            s.totalSeconds = 600;
            await isar.savedStats.put(s);
            neededRepair = true;
          }
        }
      });
      await prefs.setBool('has_run_v1_1_stats_repair', true);

      if (neededRepair) {
        DebugLogService().success("🔥 Auto-repaired corrupted local minutes mathematically based on genuine play counts.");
        // Reload stats with the clamped seconds so syncNow() pushes the corrected total
        await _loadStats(triggerSync: true);
        return; 
      }
    }

    if (triggerSync) {
      syncNow();
    }
  }

  Future<void> _migrateFromPrefs(SharedPreferences prefs, Isar isar) async {
    // DebugLogService().info("🔄 MIGRATING STATS TO ISAR...");
    final String? data = prefs.getString('extended_stats');
    if (data != null) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(data) as Map<String, dynamic>;

        await isar.writeTxn(() async {
          for (var value in decoded.values) {
            final entry = StatEntry.fromJson(value as Map<String, dynamic>);

            // Check if already exists
            final existing = await isar.savedStats
                .filter()
                .statIdEqualTo(entry.id)
                .findFirst();

            if (existing == null) {
              final newStat = SavedStat()
                ..statId = entry.id
                ..title = entry.title
                ..artist = entry.artist
                ..album = entry.album
                ..playCount = entry.playCount
                ..totalSeconds = entry.totalSeconds
                ..lastKnownPath = entry.lastKnownPath
                ..onlineArtUrl = null // Prefs didn't have this
                ..youtubeUrl = null; // Prefs didn't have this

              await isar.savedStats.put(newStat);
            }
          }
        });

        // Clear prefs after successful migration
        await prefs.remove('extended_stats');
        DebugLogService().success("✅ MIGRATION COMPLETE");
      } catch (e) {
        DebugLogService().error("❌ Migration Failed: $e");
      }
    }
  }

  // --- LOGIC: ADD PLAY COUNT ---
  Future<void> logPlay(SongModel song) async {
    DebugLogService().info("📈 STATS: logPlay called for: ${song.title}");
    final id = StatEntry.generateId(
        song.title.trim(), song.artist.trim(), song.album.trim());

    // Update State (Optimistic UI)
    final currentEntries = {...state.entries};
    final current = currentEntries[id];
    StatEntry updatedEntry;

    if (current != null) {
      updatedEntry = current.copyWith(
        playCount: current.playCount + 1,
        lastKnownPath: song.filePath,
      );
    } else {
      updatedEntry = StatEntry(
          id: id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          playCount: 1,
          totalSeconds: 0,
          lastKnownPath: song.filePath,
          spotifyId: song.spotifyId,
          deezerId: song.deezerId);
    }
    currentEntries[id] = updatedEntry;
    // state = StatsState(entries: currentEntries, maxRepeatStreak: state.maxRepeatStreak); // REMOVED redundant intermediate state set

    // Persist to Isar
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;

    await isar.writeTxn(() async {
      final existing =
          await isar.savedStats.filter().statIdEqualTo(id).findFirst();

      if (existing != null) {
        existing.playCount += 1;
        existing.lastKnownPath = song.filePath;
        existing.lastPlayed = DateTime.now(); // 📅 NEW

        // Update metadata if available
        if (song.onlineArtUrl != null) {
          existing.onlineArtUrl = song.onlineArtUrl;
        }
        if (song.sourceUrl != null) existing.youtubeUrl = song.sourceUrl;
        if (song.spotifyId != null) existing.spotifyId = song.spotifyId;
        if (song.deezerId != null) existing.deezerId = song.deezerId;

        await isar.savedStats.put(existing);
      } else {
        final newStat = SavedStat()
          ..statId = id
          ..title = song.title
          ..artist = song.artist
          ..album = song.album
          ..playCount = 1
          ..totalSeconds = 0
          ..lastKnownPath = song.filePath
          ..lastPlayed = DateTime.now() // 📅 NEW
          ..onlineArtUrl = song.onlineArtUrl
          ..youtubeUrl = song.sourceUrl
          ..spotifyId = song.spotifyId
          ..deezerId = song.deezerId;

        await isar.savedStats.put(newStat);
      }
    });

    // 🔄 CLOUD SYNC: Push per-song stat delta to SyncEngine
    final deviceId = await MetricsService().getDeviceIdentifier();
    final playDelta = StatDelta(
      id: const Uuid().v4(),
      statId: id,
      title: song.title.trim(),
      artist: song.artist.trim(),
      album: song.album.trim(),
      playCountDelta: 1,
      totalSecondsDelta: 0,
      timestamp: DateTime.now(),
      deviceId: deviceId,
      spotifyId: song.spotifyId,
      deezerId: song.deezerId,
      onlineArtUrl: song.onlineArtUrl,
    );
    SyncEngine().pushStatDelta(playDelta);

    // Track in Cloud (Stats Page Logic)
    final history = await _getAccurateHistoryCounts();
    final statsResult = StatsUtils.calculate(state,
        dailyPlaysOverride: history['daily'],
        weeklyPlaysOverride: history['weekly']);

    MetricsService().trackSongPlayModel(song,
        localTotal: statsResult.totalPlays,
        totalMinutes: statsResult.totalMinutes);

    // 🚀 BUMP PROFILE CLOUD STATS: Triggers reactive UI update for 'Total Plays'
    ref.read(profileProvider.notifier).bumpCloudStats(
          playIncrement: 1,
          dailyIncrement: 1,
          weeklyIncrement: 1,
        );

    // --- REPEAT OFFENDER TRACKING ---
    final prefs = ref.read(sharedPrefsProvider);
    String? lastTrackId = prefs.getString('last_played_track_id');
    int lastTrackTime = prefs.getInt('last_track_play_time') ?? 0;
    int currentStreak = prefs.getInt('current_repeat_streak') ?? 0;
    int maxStreak = prefs.getInt('max_repeat_streak') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // ☁️ CLOUD HANDSHAKE: Check if we should inherit an active session from another device
    final profile = ref.read(profileProvider);
    final cloudStreak = profile.cloudCurrentRepeatStreak ?? 0;
    final cloudSongId = profile.cloudLastRepeatSongId;
    final cloudTime = profile.cloudLastRepeatTime ?? 0;

    if (cloudSongId == id &&
        cloudStreak > 0 &&
        (nowMs - cloudTime <= 30 * 60 * 1000)) {
      if (lastTrackId != id || cloudStreak >= currentStreak) {
        currentStreak = cloudStreak;
        lastTrackId = id;
        lastTrackTime = nowMs;
        DebugLogService().success(
            "☁️ STREAK HANDSHAKE: Inherited streak of $currentStreak from cloud for $id");
      }
    }

    if (lastTrackId == id) {
      if (nowMs - lastTrackTime <= 30 * 60 * 1000) {
        currentStreak++;
        DebugLogService().info(
            "📈 STREAK: Consecutive play detected! Current: $currentStreak");
      } else {
        currentStreak = 1;
        DebugLogService().info(
            "📈 STREAK: Same song but too much time passed (>30m). Resetting to 1.");
      }
    } else {
      currentStreak = 1;
      DebugLogService()
          .info("📈 STREAK: New song detected. Resetting streak to 1.");
    }

    if (currentStreak > maxStreak) {
      maxStreak = currentStreak;
      await prefs.setInt('max_repeat_streak', maxStreak);
    }

    await prefs.setString('last_played_track_id', id);
    await prefs.setInt('last_track_play_time', nowMs);
    await prefs.setInt('current_repeat_streak', currentStreak);

    // Update state once with all changes
    state = StatsState(
      entries: currentEntries,
      maxRepeatStreak: maxStreak,
      currentRepeatStreak: currentStreak,
      weeklyWinsCount: state.weeklyWinsCount,
      weeklyPodiumsCount: state.weeklyPodiumsCount,
    );

    DebugLogService().info(
        "📈 STREAK DEBUG: Song=${song.title}, Current=$currentStreak, Max=$maxStreak");
    DebugLogService().info(
        "📈 STATS: Processed ${song.title}. Streak: $currentStreak, Max: $maxStreak");

    DebugLogService().info(
        "📈 STATS SAVED (Isar): ${song.title} (Count: ${updatedEntry.playCount}) | Streak: $currentStreak (Max: $maxStreak)");

    _triggerSync();
  }

  // --- LOGIC: ADD LISTENING TIME ---
  Future<void> logTime(SongModel song, int seconds) async {
    if (seconds <= 0) return;
    /* DebugLogService()
        .info("📈 STATS: logTime called - ${song.title}: +${seconds}s"); */

    final id = StatEntry.generateId(
        song.title.trim(), song.artist.trim(), song.album.trim());

    // Update State
    final currentEntries = {...state.entries};
    final liveEntry = currentEntries[id];
    StatEntry updatedEntry;

    if (liveEntry != null) {
      updatedEntry = liveEntry.copyWith(
        totalSeconds: liveEntry.totalSeconds + seconds,
      );
    } else {
      updatedEntry = StatEntry(
          id: id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          playCount: 0,
          totalSeconds: seconds,
          lastKnownPath: song.filePath,
          spotifyId: song.spotifyId,
          deezerId: song.deezerId);
    }
    currentEntries[id] = updatedEntry;
    state = StatsState(
      entries: currentEntries,
      maxRepeatStreak: state.maxRepeatStreak,
      currentRepeatStreak: state.currentRepeatStreak,
      weeklyWinsCount: state.weeklyWinsCount, // 🚀 RESTORED
      weeklyPodiumsCount: state.weeklyPodiumsCount, // 🚀 RESTORED
    );

    // Persist to Isar
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;

    await isar.writeTxn(() async {
      final existing =
          await isar.savedStats.filter().statIdEqualTo(id).findFirst();

      if (existing != null) {
        existing.totalSeconds += seconds;
        existing.lastPlayed = DateTime.now(); // 📅 NEW

        // Also update IDs on time log just in case
        if (song.spotifyId != null) existing.spotifyId = song.spotifyId;
        if (song.deezerId != null) existing.deezerId = song.deezerId;
        await isar.savedStats.put(existing);
      } else {
        final newStat = SavedStat()
          ..statId = id
          ..title = song.title
          ..artist = song.artist
          ..album = song.album
          ..playCount = 0
          ..totalSeconds = seconds
          ..lastKnownPath = song.filePath
          ..onlineArtUrl = song.onlineArtUrl
          ..youtubeUrl = song.sourceUrl
          ..spotifyId = song.spotifyId
          ..deezerId = song.deezerId;

        await isar.savedStats.put(newStat);
      }
    });

    // 🔄 CLOUD SYNC: Push per-song time delta to SyncEngine
    final deviceId = await MetricsService().getDeviceIdentifier();
    final timeDelta = StatDelta(
      id: const Uuid().v4(),
      statId: id,
      title: song.title.trim(),
      artist: song.artist.trim(),
      album: song.album.trim(),
      playCountDelta: 0,
      totalSecondsDelta: seconds,
      timestamp: DateTime.now(),
      deviceId: deviceId,
      spotifyId: song.spotifyId,
      deezerId: song.deezerId,
      onlineArtUrl: song.onlineArtUrl,
    );
    SyncEngine().pushStatDelta(timeDelta);

    _triggerSync();
  }

  /// 🛠️ SMART REPAIR: Adjust local stats to match cloud totals via ratio scaling.
  /// This restores accurate totals while preserving the relative ranking of your top tracks.
  Future<void> repairLocalFromCloud() async {
    try {
      final metrics = await PocketBaseService().getUserMetrics();
      if (metrics == null) {
        DebugLogService().error("📊 REPAIR: Could not fetch cloud metrics.");
        return;
      }

      final cloudMinutes = metrics['total_minutes'] as int? ?? 0;
      final history = await _getAccurateHistoryCounts();
      final calculated = StatsUtils.calculate(state,
          dailyPlaysOverride: history['daily'],
          weeklyPlaysOverride: history['weekly']);
      final localMinutes = calculated.totalMinutes;

      if (localMinutes > 0) {
        // Calculate the ratio needed to bring local back to cloud level
        // e.g. 25769 / 51512 = 0.5
        final ratio = cloudMinutes / localMinutes;

        DebugLogService().info(
            "📊 REPAIR: Applying ratio scaling ($ratio) to match cloud ($cloudMinutes mins)...");
        await applyGlobalAdjustment(ratio);
        DebugLogService()
            .success("✅ REPAIR: Local stats adjusted successfully.");
      } else if (cloudMinutes > 0 && localMinutes == 0) {
        // Pure restore mode
        await pullAndSyncRemoteData();
      }
    } catch (e) {
      DebugLogService().error("📊 REPAIR ERROR: $e");
    }
  }

  /// 📉 PROPORTIONAL SCALING: Scales all local Isar entries by the given ratio.
  Future<void> applyGlobalAdjustment(double ratio) async {
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;

    await isar.writeTxn(() async {
      final allStats = await isar.savedStats.where().findAll();
      for (var s in allStats) {
        // Proportional reduction of counts and time
        s.playCount = (s.playCount * ratio).round();
        s.totalSeconds = (s.totalSeconds * ratio).round();

        await isar.savedStats.put(s);
      }
    });

    // Reload state and verify with cloud
    await _loadStats();
    await syncNow();
  }

  Future<void> resetStats() async {
    state = StatsState();
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;

    await isar.writeTxn(() async {
      await isar.savedStats.clear();
    });
  }

  Future<void> updateMetadata(String id,
      {String? artUrl, String? youtubeUrl}) async {
    // 1. Update Local State
    final currentEntries = {...state.entries};
    final entry = currentEntries[id];
    if (entry == null) return;

    final updatedEntry = entry.copyWith(
      onlineArtUrl: artUrl ?? entry.onlineArtUrl,
      youtubeUrl: youtubeUrl ?? entry.youtubeUrl,
    );
    currentEntries[id] = updatedEntry;
    state = StatsState(
      entries: currentEntries,
      maxRepeatStreak: state.maxRepeatStreak,
      currentRepeatStreak: state.currentRepeatStreak,
      weeklyWinsCount: state.weeklyWinsCount,
      weeklyPodiumsCount: state.weeklyPodiumsCount,
    );

    // 2. Update Isar
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;

    await isar.writeTxn(() async {
      final existing =
          await isar.savedStats.filter().statIdEqualTo(id).findFirst();
      if (existing != null) {
        if (artUrl != null) existing.onlineArtUrl = artUrl;
        if (youtubeUrl != null) existing.youtubeUrl = youtubeUrl;
        await isar.savedStats.put(existing);
      }
    });
  }
}

final statsProvider = StateNotifierProvider<StatsNotifier, StatsState>((ref) {
  return StatsNotifier(ref);
});
