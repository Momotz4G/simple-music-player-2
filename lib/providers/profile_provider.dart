import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/pocketbase_service.dart';
import '../services/metrics_service.dart';
import '../services/auth_service.dart';
import '../services/debug_log_service.dart';
import '../services/sync_engine.dart';
import '../utils/stats_utils.dart';
import 'stats_provider.dart';

class ProfileState {
  final String defaultDeviceName;
  final String? customNickname;
  final String? avatarUrl;
  final String? selectedTitle;
  final bool isLinked;
  final String? linkedEmail;
  final String? role; // "developer", "contributor", or null

  // Quota
  final bool isPremium;
  final int dailyDownloads;

  // Cloud Stats
  final int? cloudTotalPlays;
  final int? cloudTotalMinutes;
  final String? cloudTopArtist;
  final String? cloudTopTrack;
  final int? cloudRank;
  final int? cloudDailyPlays;
  final int? cloudWeeklyPlays;
  final int? cloudTopArtistPlays;
  final int? cloudMostListenedPlays;
  final int? cloudMaxRepeatStreak;
  final int? cloudCurrentRepeatStreak;
  final String? cloudLastRepeatSongId;
  final int? cloudLastRepeatTime;

  ProfileState({
    required this.defaultDeviceName,
    this.customNickname,
    this.avatarUrl,
    this.selectedTitle,
    this.isLinked = false,
    this.linkedEmail,
    this.role,
    this.isPremium = false,
    this.dailyDownloads = 0,
    this.cloudTotalPlays,
    this.cloudTotalMinutes,
    this.cloudTopArtist,
    this.cloudTopTrack,
    this.cloudRank,
    this.cloudDailyPlays,
    this.cloudWeeklyPlays,
    this.cloudTopArtistPlays,
    this.cloudMostListenedPlays,
    this.cloudMaxRepeatStreak,
    this.cloudCurrentRepeatStreak,
    this.cloudLastRepeatSongId,
    this.cloudLastRepeatTime,
  });

  String get displayName => customNickname ?? defaultDeviceName;

  ProfileState copyWith({
    String? defaultDeviceName,
    String? customNickname,
    String? avatarUrl,
    String? selectedTitle,
    bool? isLinked,
    String? linkedEmail,
    String? role,
    bool? isPremium,
    int? dailyDownloads,
    int? cloudTotalPlays,
    int? cloudTotalMinutes,
    String? cloudTopArtist,
    String? cloudTopTrack,
    int? cloudRank,
    int? cloudDailyPlays,
    int? cloudWeeklyPlays,
    int? cloudTopArtistPlays,
    int? cloudMostListenedPlays,
    int? cloudMaxRepeatStreak,
    int? cloudCurrentRepeatStreak,
    String? cloudLastRepeatSongId,
    int? cloudLastRepeatTime,
    bool clearNickname = false,
    bool clearTitle = false,
    bool clearLinkedEmail = false,
    bool clearAvatar = false,
  }) {
    return ProfileState(
      defaultDeviceName: defaultDeviceName ?? this.defaultDeviceName,
      customNickname:
          clearNickname ? null : (customNickname ?? this.customNickname),
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      selectedTitle: clearTitle ? null : (selectedTitle ?? this.selectedTitle),
      isLinked: isLinked ?? this.isLinked,
      linkedEmail: clearLinkedEmail ? null : (linkedEmail ?? this.linkedEmail),
      role: role ?? this.role,
      isPremium: isPremium ?? this.isPremium,
      dailyDownloads: dailyDownloads ?? this.dailyDownloads,
      cloudTotalPlays: cloudTotalPlays ?? this.cloudTotalPlays,
      cloudTotalMinutes: cloudTotalMinutes ?? this.cloudTotalMinutes,
      cloudTopArtist: cloudTopArtist ?? this.cloudTopArtist,
      cloudTopTrack: cloudTopTrack ?? this.cloudTopTrack,
      cloudRank: cloudRank ?? this.cloudRank,
      cloudDailyPlays: cloudDailyPlays ?? this.cloudDailyPlays,
      cloudWeeklyPlays: cloudWeeklyPlays ?? this.cloudWeeklyPlays,
      cloudTopArtistPlays: cloudTopArtistPlays ?? this.cloudTopArtistPlays,
      cloudMostListenedPlays:
          cloudMostListenedPlays ?? this.cloudMostListenedPlays,
      cloudMaxRepeatStreak: cloudMaxRepeatStreak ?? this.cloudMaxRepeatStreak,
      cloudCurrentRepeatStreak:
          cloudCurrentRepeatStreak ?? this.cloudCurrentRepeatStreak,
      cloudLastRepeatSongId:
          cloudLastRepeatSongId ?? this.cloudLastRepeatSongId,
      cloudLastRepeatTime: cloudLastRepeatTime ?? this.cloudLastRepeatTime,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final Ref ref;

  ProfileNotifier(this.ref)
      : super(ProfileState(defaultDeviceName: 'Loading...')) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final customNickname = prefs.getString('custom_nickname');
    final selectedTitle = prefs.getString('selected_title');

    String deviceName = "Unknown Device";
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = "${iosInfo.name} (${iosInfo.model})";
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        deviceName = winInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        deviceName = linuxInfo.prettyName;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        deviceName = macInfo.computerName;
      } else {
        deviceName = Platform.localHostname;
      }
    } catch (e) {
      deviceName = "Unknown Device";
    }

    // Load cached avatar URL first (instant, no network needed)
    final cachedAvatarUrl = prefs.getString('cached_avatar_url');

    final cloudDaily = prefs.getInt('cached_cloud_daily_plays');
    final cloudWeekly = prefs.getInt('cached_cloud_weekly_plays');
    final cloudMaxStreak = prefs.getInt('cached_cloud_max_repeat_streak');

    final cachedIsPremium = prefs.getBool('cached_is_premium') ?? false;
    final cachedDailyDownloads = prefs.getInt('cached_daily_downloads') ?? 0;

    // Set state immediately with cached data
    state = ProfileState(
      defaultDeviceName: deviceName,
      customNickname: customNickname,
      avatarUrl: cachedAvatarUrl,
      selectedTitle: selectedTitle,
      cloudDailyPlays: cloudDaily,
      cloudWeeklyPlays: cloudWeekly,
      cloudMaxRepeatStreak: cloudMaxStreak,
      isPremium: cachedIsPremium,
      dailyDownloads: cachedDailyDownloads,
    );

    // Initialize AuthService and restore linked account state
    await AuthService().init();
    if (AuthService().isLinked) {
      state = state.copyWith(
        isLinked: true,
        linkedEmail: AuthService().linkedEmail,
      );

      // Auto-recover interrupted migration: check for crash-recovery breadcrumb
      // OR stale pb_user_id. Pass fromUserId explicitly because PocketBaseService._userId
      // was already set to linkedUserId during MetricsService.init().
      final linkedUserId = AuthService().linkedUserId;
      final pendingFrom = prefs.getString('pb_pending_migration_from');
      final currentPbUserId = prefs.getString('pb_user_id');

      // Determine the old anonymous ID from either the crash breadcrumb or stale pb_user_id
      final oldAnonymousId = (pendingFrom != null &&
              pendingFrom.isNotEmpty &&
              pendingFrom != linkedUserId)
          ? pendingFrom
          : (currentPbUserId != null && currentPbUserId != linkedUserId
              ? currentPbUserId
              : null);

      if (linkedUserId != null && oldAnonymousId != null) {
        DebugLogService().info(
            "🔗 Auto-recovering interrupted migration from $oldAnonymousId...");
        await PocketBaseService()
            .migrateAnonymousToLinked(linkedUserId, fromUserId: oldAnonymousId);
        await prefs.remove('pb_pending_migration_from');
      }
    }

    // Then attempt to refresh from PocketBase in background
    if (AuthService().isLinked) {
      refreshQuotaFromCloud();
    }
    refreshAvatarFromCloud();
  }

  Future<void> refreshAvatarFromCloud({int retries = 2}) async {
    final prefs = await SharedPreferences.getInstance();
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        final metrics = await PocketBaseService().getUserMetrics();
        if (metrics != null) {
          final freshUrl = PocketBaseService().getAvatarUrl(metrics);
          final role = metrics['role'] as String?;
          final cloudPlays = (metrics['play_count'] as num?)?.toInt();
          final cloudMinutes = (metrics['total_minutes'] as num?)?.toInt();
          final cloudArtist = metrics['top_artist'] as String?;
          final cloudTrack = metrics['top_track'] as String?;
          final cloudNickname = metrics['nickname'] as String?;
          final cloudTitle = metrics['selected_title'] as String?;
          final cloudArtistPlays =
              (metrics['top_artist_plays'] as num?)?.toInt();
          final cloudMostListenedPlays =
              (metrics['most_listened_plays'] as num?)?.toInt();
          final cloudDailyPlays =
              (metrics['daily_play_count'] as num?)?.toInt();
          final cloudWeeklyPlays =
              (metrics['weekly_play_count'] as num?)?.toInt();
          final cloudMaxRepeatStreak =
              (metrics['max_repeat_streak'] as num?)?.toInt();
          final cloudCurrentRepeatStreak =
              (metrics['current_repeat_streak'] as num?)?.toInt();
          final cloudLastRepeatSongId =
              metrics['last_repeat_song_id'] as String?;
          final cloudLastRepeatTime =
              (metrics['last_repeat_time'] as num?)?.toInt();

          final quota = await PocketBaseService().getUserQuota();
          final isPremium = quota != null ? (quota['is_premium'] as bool? ?? false) : false;
          final dailyDownloads = quota != null ? ((quota['daily_downloads'] as num?)?.toInt() ?? 0) : 0;

          // LIVE RANK VERIFICATION: Standard sync might miss dynamic ranking.
          // We force-calculate it here to ensure "Top 1 Global" works immediately.
          final verifiedRank =
              await MetricsService().getCurrentUserRank(cloudMinutes ?? 0);
          DebugLogService().info(
              "📊 Rank Sync: verified rank #$verifiedRank (cloudMinutes: $cloudMinutes)");

          final pbService = PocketBaseService();
          final effectiveNickname =
              (cloudNickname != null && cloudNickname.isNotEmpty)
                  ? cloudNickname
                  : pbService.linkedName;
          final effectiveUrl = freshUrl ?? pbService.linkedAvatarUrl;

          if (effectiveNickname != null &&
              effectiveNickname.isNotEmpty &&
              effectiveNickname != state.customNickname) {
            // ANTI-EXPLOIT: Validate uniqueness before accepting cloud nickname.
            // Prevents orphaned records from hijacking a nickname after unlink/relink.
            final isNickTaken =
                await PocketBaseService().isNicknameTaken(effectiveNickname);
            if (!isNickTaken) {
              state = state.copyWith(customNickname: effectiveNickname);
              await prefs.setString('custom_nickname', effectiveNickname);
            }
          }
          if (cloudTitle != null &&
              cloudTitle.isNotEmpty &&
              cloudTitle != state.selectedTitle) {
            state = state.copyWith(selectedTitle: cloudTitle);
            await prefs.setString('selected_title', cloudTitle);
          }

          if (effectiveUrl != null && effectiveUrl != state.avatarUrl) {
            state = state.copyWith(
              avatarUrl: effectiveUrl,
              role: role,
              cloudTotalPlays: cloudPlays,
              cloudTotalMinutes: cloudMinutes,
              cloudTopArtist: cloudArtist,
              cloudTopTrack: cloudTrack,
              cloudRank: verifiedRank,
              cloudDailyPlays: cloudDailyPlays,
              cloudWeeklyPlays: cloudWeeklyPlays,
              cloudTopArtistPlays: cloudArtistPlays,
              cloudMostListenedPlays: cloudMostListenedPlays,
              cloudMaxRepeatStreak: cloudMaxRepeatStreak,
              cloudCurrentRepeatStreak: cloudCurrentRepeatStreak,
              cloudLastRepeatSongId: cloudLastRepeatSongId,
              cloudLastRepeatTime: cloudLastRepeatTime,
              isPremium: isPremium,
              dailyDownloads: dailyDownloads,
            );
            await prefs.setString('cached_avatar_url', effectiveUrl);
            await prefs.setBool('cached_is_premium', isPremium);
            await prefs.setInt('cached_daily_downloads', dailyDownloads);
            if (cloudDailyPlays != null) {
              await prefs.setInt('cached_cloud_daily_plays', cloudDailyPlays);
            }
            if (cloudWeeklyPlays != null) {
              await prefs.setInt('cached_cloud_weekly_plays', cloudWeeklyPlays);
            }
          } else if (effectiveUrl == null && state.avatarUrl != null) {
            // Avatar was removed on server
            state = state.copyWith(
              clearAvatar: true,
              role: role,
              cloudTotalPlays: cloudPlays,
              cloudTotalMinutes: cloudMinutes,
              cloudTopArtist: cloudArtist,
              cloudTopTrack: cloudTrack,
              cloudRank: verifiedRank,
              cloudDailyPlays: cloudDailyPlays,
              cloudWeeklyPlays: cloudWeeklyPlays,
              cloudTopArtistPlays: cloudArtistPlays,
              cloudMostListenedPlays: cloudMostListenedPlays,
              cloudMaxRepeatStreak: cloudMaxRepeatStreak,
              cloudCurrentRepeatStreak: cloudCurrentRepeatStreak,
              cloudLastRepeatSongId: cloudLastRepeatSongId,
              cloudLastRepeatTime: cloudLastRepeatTime,
              isPremium: isPremium,
              dailyDownloads: dailyDownloads,
            );
            await prefs.remove('cached_avatar_url');
            await prefs.setBool('cached_is_premium', isPremium);
            await prefs.setInt('cached_daily_downloads', dailyDownloads);
          } else {
            // Avatar unchanged, but still update role and cloud stats
            state = state.copyWith(
              role: role,
              cloudTotalPlays: cloudPlays,
              cloudTotalMinutes: cloudMinutes,
              cloudTopArtist: cloudArtist,
              cloudTopTrack: cloudTrack,
              cloudRank: verifiedRank,
              cloudDailyPlays: cloudDailyPlays,
              cloudWeeklyPlays: cloudWeeklyPlays,
              cloudTopArtistPlays: cloudArtistPlays,
              cloudMostListenedPlays: cloudMostListenedPlays,
              cloudMaxRepeatStreak: cloudMaxRepeatStreak,
              cloudCurrentRepeatStreak: cloudCurrentRepeatStreak,
              cloudLastRepeatSongId: cloudLastRepeatSongId,
              cloudLastRepeatTime: cloudLastRepeatTime,
              isPremium: isPremium,
              dailyDownloads: dailyDownloads,
            );
            await prefs.setBool('cached_is_premium', isPremium);
            await prefs.setInt('cached_daily_downloads', dailyDownloads);
            if (cloudDailyPlays != null) {
              await prefs.setInt('cached_cloud_daily_plays', cloudDailyPlays);
            }
            if (cloudWeeklyPlays != null) {
              await prefs.setInt('cached_cloud_weekly_plays', cloudWeeklyPlays);
            }
          }
        }
        return; // Success, exit retry loop
      } catch (e) {
        if (attempt < retries) {
          await Future.delayed(Duration(seconds: 3 * (attempt + 1)));
        }
      }
    }
  }

  /// BUMP STATS LOCALLY: Instantly update cloud metrics locally to provide
  /// reactive UI feedback before the next actual PocketBase sync fetch occurs.
  void bumpCloudStats(
      {int playIncrement = 0,
      int minutesIncrement = 0,
      int dailyIncrement = 0,
      int weeklyIncrement = 0}) {
    if (state.cloudTotalPlays == null && state.cloudTotalMinutes == null) {
      return;
    }

    state = state.copyWith(
      cloudTotalPlays: (state.cloudTotalPlays ?? 0) + playIncrement,
      cloudTotalMinutes: (state.cloudTotalMinutes ?? 0) + minutesIncrement,
      cloudDailyPlays: (state.cloudDailyPlays ?? 0) + dailyIncrement,
      cloudWeeklyPlays: (state.cloudWeeklyPlays ?? 0) + weeklyIncrement,
    );
  }

  void bumpQuota() {
    state = state.copyWith(dailyDownloads: state.dailyDownloads + 1);
  }

  /// Refreshes ONLY the quota and premium status from the cloud silently.
  Future<String> refreshQuotaFromCloud() async {
    try {
      final quota = await PocketBaseService().getUserQuota();
      if (quota != null) {
        // Use == true to safely handle any type mismatches without crashing
        final isPremium = quota['is_premium'] == true;
        final dailyDownloads = (quota['daily_downloads'] as num?)?.toInt() ?? 0;
        
        state = state.copyWith(
          isPremium: isPremium,
          dailyDownloads: dailyDownloads,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('cached_is_premium', isPremium);
        await prefs.setInt('cached_daily_downloads', dailyDownloads);
        
        return isPremium ? "Premium Status Active! 🌟" : "You don't have Premium yet. Tap 'Continue to Sociabuzz' to upgrade!";
      } else {
        return "You need to link your account first to check your status.";
      }
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains('statusCode: 502') || errMsg.contains('statusCode: 503')) {
         return "Server Error: Our database is currently restarting or down. Please try again later.";
      } else if (errMsg.contains('statusCode: 404') || errMsg.contains('statusCode: 403')) {
         return "Account not found or access denied. Try linking your account again.";
      } else if (errMsg.contains('SocketException') || errMsg.contains('Failed host lookup') || errMsg.contains('ClientException')) {
         return "Network Error: Could not connect to the server. Please check your connection.";
      }
      return "Could not fetch status at this time. Please try again later.";
    }
  }

  // Returns an error message if failed, or null if successful
  Future<String?> updateNickname(String newNickname) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanedName = newNickname.trim();

    if (cleanedName.isEmpty) {
      // Revert to default
      await prefs.remove('custom_nickname');
      state = state.copyWith(clearNickname: true);
      return null;
    } else {
      // VERIFY UNIQUENESS BEFORE SAVING
      final isTaken = await PocketBaseService().isNicknameTaken(cleanedName);
      if (isTaken) {
        return "Nickname '$cleanedName' is already taken by another user.";
      }

      await prefs.setString('custom_nickname', cleanedName);
      state = state.copyWith(customNickname: cleanedName);

      // Force immediate sync to ensure Leaderboard sees newest nickname AND current earned title!
      try {
        final stats = ref.read(statsProvider);
        final calculated = StatsUtils.calculate(stats);

        await MetricsService().syncAdvancedStats(
          selectedTitle: state.selectedTitle ??
              StatsUtils.getAutomaticTitle(calculated.totalMinutes),
          totalMinutes: calculated.totalMinutes,
          topArtist: calculated.topArtist?.key,
          topTrack: calculated.topTrack?.key,
        );

        await PocketBaseService().syncUserAccountProfile(nickname: cleanedName);
        PocketBaseService().sendHeartbeat();
      } catch (e) {
        // Log silently
      }
      return null; // Success
    }
  }

  Future<void> updateAvatar(File file) async {
    try {
      // 1. Send to PocketBase
      await PocketBaseService().saveData({}, avatarFile: file);
      await PocketBaseService().syncUserAccountProfile(avatarFile: file);

      // 2. Refresh local state
      final metrics = await PocketBaseService().getUserMetrics();
      if (metrics != null) {
        final newUrl = PocketBaseService().getAvatarUrl(metrics);
        state = state.copyWith(avatarUrl: newUrl);
        // Cache locally
        if (newUrl != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_avatar_url', newUrl);
        }
      }
    } catch (e) {
      // Log silently
    }
  }

  Future<void> removeAvatar() async {
    try {
      // 1. Tell PocketBase to clear the avatar
      await PocketBaseService().saveData({}, clearAvatar: true);
      await PocketBaseService().syncUserAccountProfile(clearAvatar: true);

      // 2. Clear local state
      state = ProfileState(
        defaultDeviceName: state.defaultDeviceName,
        customNickname: state.customNickname,
        avatarUrl: null,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_avatar_url');
    } catch (e) {
      // Log silently
    }
  }

  Future<void> updateTitle(String? title) async {
    final prefs = await SharedPreferences.getInstance();
    if (title == null) {
      await prefs.remove('selected_title');
    } else {
      await prefs.setString('selected_title', title);
    }
    if (title == null) {
      state = state.copyWith(clearTitle: true);
    } else {
      state = state.copyWith(selectedTitle: title);
    }

    // Force immediate sync with calculated title
    try {
      final stats = ref.read(statsProvider);
      final calculated = StatsUtils.calculate(stats);
      final activeTitle =
          title ?? StatsUtils.getAutomaticTitle(calculated.totalMinutes);

      await MetricsService().syncAdvancedStats(
        selectedTitle: activeTitle,
        totalMinutes: calculated.totalMinutes,
        topArtist: calculated.topArtist?.key,
        topTrack: calculated.topTrack?.key,
      );
    } catch (e) {
      // Log silently
    }
  }

  /// Link Google account via OAuth
  /// Returns error message or null on success
  /// Special return format "CONFLICT:CloudNickname" if a profile exists on the account
  Future<String?> linkAccount({bool force = false}) async {
    try {
      final newUserId = await AuthService().signInWithGoogle();
      if (newUserId == null) {
        return "Google sign-in was cancelled or failed.";
      }

      // CRASH GUARD: The PocketBase SDK's authWithOAuth2 uses an SSE realtime
      // connection. After auth completes, it asynchronously disconnects the SSE.
      // On Windows, this native socket teardown can race with the event loop
      // and cause a native crash (exit code -1).
      //
      // STRATEGY: Persist ALL critical auth state IMMEDIATELY so that even if
      // the app crashes during migration, the next startup auto-recovers.
      final prefs = await SharedPreferences.getInstance();
      // Get the current anonymous user ID from the live service (always set)
      // SharedPreferences is the fallback only
      final oldPbUserId =
          PocketBaseService().userId ?? prefs.getString('pb_user_id');

      // Save the linked state FIRST — this is the crash recovery checkpoint
      await prefs.setString('pb_linked_user_id', newUserId);
      await prefs.setString('pb_linked_email', AuthService().linkedEmail ?? '');
      // Save old anonymous ID for crash recovery (so migration can find the orphaned record)
      if (oldPbUserId != null && oldPbUserId != newUserId) {
        await prefs.setString('pb_pending_migration_from', oldPbUserId);
      }
      DebugLogService()
          .info("🛡️ Auth state persisted. Old=$oldPbUserId, new=$newUserId");

      // NATIVE WINDOWS TEARDOWN BUFFER:
      // The PocketBase SDK is currently unsubscribing from the @oauth2 SSE stream.
      // On Windows, dart:io uses an IOCP socket pool. If we immediately fire REST
      // requests while the SSE socket is tearing down or submitting new subscriptions,
      // the native threadpool throws Exit Code -1 and kills the app.
      // We wait a generous 2.5 seconds. (If the user closes the app right now,
      // the auto-recovery breadcrumb we just saved will handle migration next time!).
      DebugLogService().info(
          "⏳ Stabilizing network context (avoiding native IOCP crash)...");
      await Future.delayed(const Duration(milliseconds: 500));

      // SAVVY SYNC: Fetch current cloud data BEFORE migration
      final cloudMetrics =
          await PocketBaseService().getRemoteMetricsForUser(newUserId);

      // CONFLICT CHECK: Does cloud have a nickname different from local?
      if (cloudMetrics != null && !force) {
        final cloudNickname = cloudMetrics['nickname'] as String?;
        final localNickname = state.customNickname;

        if (cloudNickname != null &&
            cloudNickname.isNotEmpty &&
            localNickname != null &&
            localNickname.isNotEmpty &&
            cloudNickname != localNickname) {
          // Return special code for UI to handle
          return "CONFLICT:$cloudNickname";
        }
      }

      // Migrate anonymous data to the new linked user ID
      // Pass fromUserId explicitly so it works even if PocketBaseService._userId
      // was already updated during this session
      final migrated = await PocketBaseService().migrateAnonymousToLinked(
        newUserId,
        fromUserId: oldPbUserId,
      );
      if (!migrated) {
        return "Failed to migrate your data. Please try again.";
      }

      state = state.copyWith(
        isLinked: true,
        linkedEmail: AuthService().linkedEmail,
      );

      // RESTORE CLOUD IDENTITY (The Pull-First Safeguard)
      if (cloudMetrics != null) {
        await _restoreCloudIdentity(cloudMetrics);
      }

      // ADDITIVE STATS SYNC (The Merge)
      await ref
          .read(statsProvider.notifier)
          .pullAndSyncRemoteData(isInitialLink: true);

      // Notify SyncEngine of account link (Requirement 9.2)
      SyncEngine().onAccountLinked(newUserId);

      return null; // Success
    } catch (e) {
      DebugLogService().error("⚠️ linkAccount error: $e");
      return "Account linking failed: $e";
    }
  }

  Future<void> _restoreCloudIdentity(Map<String, dynamic> cloudMetrics) async {
    final prefs = await SharedPreferences.getInstance();

    final cloudNickname = cloudMetrics['nickname'] as String?;
    final cloudTitle = cloudMetrics['selected_title'] as String?;
    final cloudRole = cloudMetrics['role'] as String?;
    final freshUrl = PocketBaseService().getAvatarUrl(cloudMetrics);

    final pbService = PocketBaseService();
    final effectiveNickname =
        (cloudNickname != null && cloudNickname.isNotEmpty)
            ? cloudNickname
            : pbService.linkedName;
    final effectiveUrl = freshUrl ?? pbService.linkedAvatarUrl;

    // Update local prefs and state with cloud identity
    if (effectiveNickname != null && effectiveNickname.isNotEmpty) {
      // ANTI-EXPLOIT: Validate uniqueness before restoring cloud nickname
      final isNickTaken =
          await PocketBaseService().isNicknameTaken(effectiveNickname);
      if (!isNickTaken) {
        await prefs.setString('custom_nickname', effectiveNickname);
        state = state.copyWith(customNickname: effectiveNickname);
      }
    }

    if (cloudTitle != null && cloudTitle.isNotEmpty) {
      await prefs.setString('selected_title', cloudTitle);
      state = state.copyWith(selectedTitle: cloudTitle);
    }

    if (effectiveUrl != null) {
      await prefs.setString('cached_avatar_url', effectiveUrl);
      state = state.copyWith(avatarUrl: effectiveUrl);
    }

    if (cloudRole != null) {
      state = state.copyWith(role: cloudRole);
    }

    DebugLogService()
        .success("📥 Account Identity Restored: $effectiveNickname");
  }

  /// Unlink Google account and revert to anonymous
  Future<void> unlinkAccount() async {
    try {
      // ANTI-EXPLOIT: Clear nickname from the metrics record about to be orphaned.
      // Prevents "multi-account nickname squatting" where unlink/relink cycles
      // leave orphaned records with the same nickname, inflating leaderboard stats.
      try {
        await PocketBaseService().saveData({'nickname': ''});
      } catch (_) {}

      // 1. Log out from Google and transition back to a fresh anonymous ID
      await AuthService().signOut();
      await PocketBaseService().revertToAnonymous();

      // 2. Clear local identity & STATS (The Clean Unlink)
      // This ensures the device doesn't keep the cloud name/avatar after log out.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_nickname');
      await prefs.remove('selected_title');
      await prefs.remove('cached_avatar_url');

      // CRITICAL: Wipe local stats so the new anonymous user starts fresh!
      // This prevents the "2000 minutes cloned to new ID" bug.
      await ref.read(statsProvider.notifier).resetStats();

      // 3. Reset local state
      state = state.copyWith(
        isLinked: false,
        clearNickname: true,
        clearTitle: true,
        clearLinkedEmail: true,
      );

      // Notify SyncEngine of account unlink (Requirement 9.3)
      SyncEngine().onAccountUnlinked();

      DebugLogService()
          .info("🔐 Account unlinked. Identity & local stats cleared.");
    } catch (e) {
      // Log silently
    }
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref);
});
