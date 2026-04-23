import '../providers/stats_provider.dart';

enum TitleCategory { time, behavior, competitive, hallOfFame, exclusive, superfan }

class TitleDefinition {
  final String name;
  final int requiredMinutes; // Used as the threshold variable (e.g. 50 repeats for Repeat Offender)
  final String icon;
  final int rarityTier; // 0: Common, 1: Uncommon, 2: Rare, 3: Supreme, 4-6: Mythic
  final int primaryColor;
  final int secondaryColor;
  final TitleCategory category;
  final String ruleDescription;
  final String? requiredRole;
  final bool isDynamic; // If true, title contains [Artist] placeholder

  const TitleDefinition({
    required this.name,
    required this.requiredMinutes,
    required this.icon,
    required this.rarityTier,
    required this.primaryColor,
    required this.secondaryColor,
    this.category = TitleCategory.time,
    this.ruleDescription = "Listen to music to earn this title.",
    this.requiredRole,
    this.isDynamic = false,
  });
}

class CalculatedStats {
  final MapEntry<String, int>? topArtist;
  final MapEntry<String, int>? topTrack;
  final int totalMinutes;
  final int totalPlays;
  final int dailyPlays;      // 🚀 NEW
  final int weeklyPlays;     // 🚀 NEW

  final List<MapEntry<String, int>> sortedArtists;
  final Map<String, int> artistMinutes;

  CalculatedStats({
    this.topArtist,
    this.topTrack,
    required this.totalMinutes,
    required this.totalPlays,
    this.dailyPlays = 0,     // 🚀 NEW
    this.weeklyPlays = 0,    // 🚀 NEW
    this.sortedArtists = const [],
    this.artistMinutes = const {},
  });
}

class StatsUtils {
  static String cleanArtistName(String raw) {
    if (raw.isEmpty) return "Unknown Artist";
    // 1. Remove common feature/collaboration prefixes
    String cleaned = raw.split(RegExp(r'\s+(?:feat|ft|with|&|,)\s+', caseSensitive: false)).first;
    // 2. Remove parenthetical features like " (feat. ...)"
    cleaned = cleaned.split(RegExp(r'\s*\(')).first;
    // 3. Remove comma/ampersand splits if they weren't caught by the first regex
    cleaned = cleaned.split(RegExp(r'[,&]')).first;
    
    return cleaned.trim();
  }

  static CalculatedStats calculate(StatsState stats, {int? dailyPlaysOverride, int? weeklyPlaysOverride}) {
    if (stats.entries.isEmpty) {
      return CalculatedStats(
        totalMinutes: 0, 
        totalPlays: 0, 
        dailyPlays: dailyPlaysOverride ?? 0, 
        weeklyPlays: weeklyPlaysOverride ?? 0
      );
    }

    int totalPlays = 0;
    int totalSeconds = 0;

    Map<String, int> artistCounts = {};
    Map<String, int> artistSeconds = {};
    Map<String, int> trackCounts = {};
    Map<String, String> trackTitles = {}; // ID to Title for lookup

    for (var entry in stats.entries.values) {
      // 🚀 LEGACY RECOVERY: If totalSeconds is 0 but we have plays, estimate 3.5 min/play
      if (entry.totalSeconds == 0 && entry.playCount > 0) {
        totalSeconds += (entry.playCount * 210);
      } else {
        totalSeconds += entry.totalSeconds;
      }
      
      totalPlays += entry.playCount;

      if (entry.playCount > 0) {
        final artist = entry.artist.isEmpty ? "Unknown" : entry.artist;
        artistCounts[artist] = (artistCounts[artist] ?? 0) + entry.playCount;
        artistSeconds[artist] =
            (artistSeconds[artist] ?? 0) + (entry.totalSeconds == 0 ? (entry.playCount * 210) : entry.totalSeconds);

        final trackId = entry.id;
        trackCounts[trackId] = (trackCounts[trackId] ?? 0) + entry.playCount;
        trackTitles[trackId] = entry.title;
      }
    }

    // Top Artist
    MapEntry<String, int>? topArtist;
    if (artistCounts.isNotEmpty) {
      final sortedArtists = artistCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topArtist = sortedArtists.first;
    }

    // Top Track
    MapEntry<String, int>? topTrack;
    if (trackCounts.isNotEmpty) {
      final sortedTracks = trackCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topTrackEntry = sortedTracks.first;
      topTrack = MapEntry(
          trackTitles[topTrackEntry.key] ?? "Unknown", topTrackEntry.value);
    }

    // Sorted artists (for UI)
    final sortedArtistList = artistCounts.entries.toList()
      ..sort((a, b) {
        final secA = artistSeconds[a.key] ?? 0;
        final secB = artistSeconds[b.key] ?? 0;
        final timeDiff = secB.compareTo(secA);
        if (timeDiff != 0) return timeDiff;
        return b.value.compareTo(a.value);
      });

    // Artist minutes map
    final Map<String, int> artistMinMap = {};
    for (final e in artistSeconds.entries) {
      artistMinMap[e.key] = (e.value / 60).floor();
    }

    return CalculatedStats(
      topArtist: topArtist,
      topTrack: topTrack,
      totalMinutes: (totalSeconds / 60).round(),
      totalPlays: totalPlays,
      dailyPlays: dailyPlaysOverride ?? 0,
      weeklyPlays: weeklyPlaysOverride ?? 0,
      sortedArtists: sortedArtistList.length > 50
          ? sortedArtistList.sublist(0, 50)
          : sortedArtistList,
      artistMinutes: artistMinMap,
    );
  }

  static const List<TitleDefinition> musicTitles = [
    // TIME OVERLORDS
    TitleDefinition(
      name: "Rookie Listener", 
      requiredMinutes: 0, 
      icon: "",
      rarityTier: 0,
      primaryColor: 0xFF9E9E9E, // Gray
      secondaryColor: 0xFF616161,
      category: TitleCategory.time,
      ruleDescription: "Default Title - Listen for 0 minutes.",
    ),
    TitleDefinition(
      name: "Growing Listener", 
      requiredMinutes: 100, 
      icon: "",
      rarityTier: 0,
      primaryColor: 0xFF4CAF50, // Green
      secondaryColor: 0xFF2E7D32,
      category: TitleCategory.time,
      ruleDescription: "Listen to music for 100 total minutes.",
    ),
    TitleDefinition(
      name: "Active Listener", 
      requiredMinutes: 1000, 
      icon: "",
      rarityTier: 1,
      primaryColor: 0xFF2196F3, // Blue
      secondaryColor: 0xFF1565C0,
      category: TitleCategory.time,
      ruleDescription: "Listen to music for 1,000 total minutes.",
    ),
    TitleDefinition(
      name: "Music Enthusiast", 
      requiredMinutes: 5000, 
      icon: "",
      rarityTier: 1,
      primaryColor: 0xFF9C27B0, // Purple
      secondaryColor: 0xFF6A1B9A,
      category: TitleCategory.time,
      ruleDescription: "Listen to music for 5,000 total minutes.",
    ),
    TitleDefinition(
      name: "Dedicated Listener", 
      requiredMinutes: 10000, 
      icon: "",
      rarityTier: 2,
      primaryColor: 0xFFE91E63, // Pink
      secondaryColor: 0xFF880E4F,
      category: TitleCategory.time,
      ruleDescription: "Listen to music for 10,000 total minutes.",
    ),
    TitleDefinition(
      name: "Audio Addict", 
      requiredMinutes: 20000, 
      icon: "",
      rarityTier: 2,
      primaryColor: 0xFFFF9800, // Orange
      secondaryColor: 0xFFE65100,
      category: TitleCategory.time,
      ruleDescription: "Listen to music for 20,000 total minutes.",
    ),
    TitleDefinition(
      name: "Music Virtuoso", 
      requiredMinutes: 50000, 
      icon: "",
      rarityTier: 3,
      primaryColor: 0xFF00BCD4, // Cyan
      secondaryColor: 0xFF006064,
      category: TitleCategory.time,
      ruleDescription: "Listen to music for 50,000 total minutes.",
    ),
    TitleDefinition(
      name: "Legendary Listener", 
      requiredMinutes: 100000, 
      icon: "",
      rarityTier: 3,
      primaryColor: 0xFFFFD700, // Gold
      secondaryColor: 0xFFFF4500, // Red-Orange
      category: TitleCategory.time,
      ruleDescription: "Listen to music for 100,000 total minutes.",
    ),
    TitleDefinition(
      name: "Resonant Soul", 
      requiredMinutes: 250000, 
      icon: "",
      rarityTier: 4,
      primaryColor: 0xFFD500F9, // Deep Purple
      secondaryColor: 0xFFB0BEC5, // Silver
      category: TitleCategory.time,
      ruleDescription: "Listen to music for 250,000 total minutes.",
    ),
    TitleDefinition(
      name: "Eternal Echo", 
      requiredMinutes: 500000, 
      icon: "",
      rarityTier: 5,
      primaryColor: 0xFFF5F5F5, // White Quartz
      secondaryColor: 0xFF00E5FF, // Cyan Shimmer
      category: TitleCategory.time,
      ruleDescription: "Listen to music for 500,000 total minutes.",
    ),
    TitleDefinition(
      name: "Melody Archon", 
      requiredMinutes: 1000000, 
      icon: "",
      rarityTier: 6,
      primaryColor: 0xFFFFEA00, // Pure Gold
      secondaryColor: 0xFF000000, // Void Black
      category: TitleCategory.time,
      ruleDescription: "Listen to music for 1,000,000 total minutes.",
    ),
    // BEHAVIORAL ACHIEVEMENTS
    TitleDefinition(
      name: "Repeat Offender", 
      requiredMinutes: 50, // Serves as the required streak count 
      icon: "",
      rarityTier: 4, 
      primaryColor: 0xFFFF1744, // Neon Red
      secondaryColor: 0xFF1A237E, // Deep Blue
      category: TitleCategory.behavior,
      ruleDescription: "Listen to the exact same song 50 times consecutively. Max gap between loops: 30 minutes.",
    ),
    TitleDefinition(
      name: "Obsessive Repeater", 
      requiredMinutes: 100, 
      icon: "",
      rarityTier: 5, 
      primaryColor: 0xFFD500F9, // Neon Purple
      secondaryColor: 0xFF00E5FF, // Neon Cyan
      category: TitleCategory.behavior,
      ruleDescription: "Listen to the exact same song 100 times consecutively. Max gap between loops: 30 minutes.",
    ),
    TitleDefinition(
      name: "Binge Listener",
      requiredMinutes: 100,
      icon: "⚡",
      rarityTier: 1,
      primaryColor: 0xFF03A9F4, // Light Blue
      secondaryColor: 0xFF01579B,
      category: TitleCategory.behavior,
      ruleDescription: "Reach 100 plays in a single day.",
    ),
    TitleDefinition(
      name: "Music Marathoner",
      requiredMinutes: 500,
      icon: "🏃",
      rarityTier: 2,
      primaryColor: 0xFF673AB7, // Deep Purple
      secondaryColor: 0xFF311B92,
      category: TitleCategory.behavior,
      ruleDescription: "Reach 500 plays in a single week.",
    ),
    TitleDefinition(
      name: "Unstoppable Pulse",
      requiredMinutes: 1500,
      icon: "🔥",
      rarityTier: 3,
      primaryColor: 0xFFFF5722, // Deep Orange
      secondaryColor: 0xFFBF360C,
      category: TitleCategory.behavior,
      ruleDescription: "Reach 1,500 plays in a single week.",
    ),
    TitleDefinition(
      name: "Atomic Rhythm",
      requiredMinutes: 3000,
      icon: "☢️",
      rarityTier: 5,
      primaryColor: 0xFF76FF03, // Neon Lime
      secondaryColor: 0xFF1B5E20,
      category: TitleCategory.behavior,
      ruleDescription: "Reach 3,000 plays in a single week.",
    ),
    TitleDefinition(
      name: "Top 1 Global", 
      requiredMinutes: 1, // Logic: Rank 1
      icon: "🥇",
      rarityTier: 6, // Mythic+
      primaryColor: 0xFFFFD700, // Gold
      secondaryColor: 0xFF000000, // Void Black
      category: TitleCategory.competitive,
      ruleDescription: "Be the #1 most active listener on the Global Leaderboard (All-Time). You will lose this title if you are overtaken.",
    ),
    TitleDefinition(
      name: "Top 2 Global", 
      requiredMinutes: 2, // Logic: Rank 2
      icon: "🥈",
      rarityTier: 6,
      primaryColor: 0xFFE0E0E0, // Platinum
      secondaryColor: 0xFF212121, 
      category: TitleCategory.competitive,
      ruleDescription: "Be the #2 most active listener on the Global Leaderboard (All-Time). You will lose this title if you are overtaken.",
    ),
    TitleDefinition(
      name: "Top 3 Global", 
      requiredMinutes: 3, // Logic: Rank 3
      icon: "🥉",
      rarityTier: 5,
      primaryColor: 0xFFCD7F32, // Bronze
      secondaryColor: 0xFF3E2723,
      category: TitleCategory.competitive,
      ruleDescription: "Be the #3 most active listener on the Global Leaderboard (All-Time). You will lose this title if you are overtaken.",
    ),
    // SUPERFAN CATEGORY (Dynamic)
    TitleDefinition(
      name: "Loyal Listener of [Artist]",
      requiredMinutes: 500,
      icon: "🎵",
      rarityTier: 2,
      primaryColor: 0xFF9C27B0, // Purple
      secondaryColor: 0xFF4A148C,
      category: TitleCategory.superfan,
      ruleDescription: "Reach 500 minutes with any specific artist to unlock this dynamic title.",
      isDynamic: true,
    ),
    TitleDefinition(
      name: "Authorized Fan of [Artist]",
      requiredMinutes: 1000,
      icon: "📜",
      rarityTier: 3,
      primaryColor: 0xFF00BCD4, // Cyan
      secondaryColor: 0xFF006064,
      category: TitleCategory.superfan,
      ruleDescription: "Reach 1,000 minutes with any specific artist to unlock this dynamic title.",
      isDynamic: true,
    ),
    TitleDefinition(
      name: "Die-Hard Follower of [Artist]",
      requiredMinutes: 2000,
      icon: "🩸",
      rarityTier: 4,
      primaryColor: 0xFFE91E63, // Pink
      secondaryColor: 0xFF880E4F,
      category: TitleCategory.superfan,
      ruleDescription: "Reach 2,000 minutes with any specific artist to unlock this dynamic title.",
      isDynamic: true,
    ),
    TitleDefinition(
      name: "True Devotee of [Artist]",
      requiredMinutes: 5000,
      icon: "💖",
      rarityTier: 5,
      primaryColor: 0xFF6200EA, // Deep Purple
      secondaryColor: 0xFF311B92,
      category: TitleCategory.superfan,
      ruleDescription: "Reach 5,000 minutes with any specific artist to unlock this dynamic title.",
      isDynamic: true,
    ),
    TitleDefinition(
      name: "Spiritual Twin of [Artist]",
      requiredMinutes: 10000,
      icon: "🌌",
      rarityTier: 5,
      primaryColor: 0xFFFFB300, // Amber/Gold
      secondaryColor: 0xFFFF6F00,
      category: TitleCategory.superfan,
      ruleDescription: "Reach 10,000 minutes with any specific artist to unlock this legendary dynamic title.",
      isDynamic: true,
    ),
    TitleDefinition(
      name: "The Ultimate Stan of [Artist]",
      requiredMinutes: 25000,
      icon: "🔱",
      rarityTier: 6,
      primaryColor: 0xFF000000, // Black
      secondaryColor: 0xFF00E5FF, // Cyan Shimmer
      category: TitleCategory.superfan,
      ruleDescription: "Reach 25,000 minutes with any specific artist to unlock the ultimate dynamic title.",
      isDynamic: true,
    ),
    // HALL OF FAME (WEEKLY & ACCUMULATED)
    TitleDefinition(
      name: "Weekly Veteran", 
      requiredMinutes: 1, 
      icon: "🏅",
      rarityTier: 4, 
      primaryColor: 0xFFB0BEC5, 
      secondaryColor: 0xFF263238, 
      category: TitleCategory.hallOfFame,
      ruleDescription: "Finish a weekly leaderboard in the Top 3 positions. This title is permanent once earned.",
    ),
    TitleDefinition(
      name: "Consistent Elite", 
      requiredMinutes: 5, 
      icon: "🎖️",
      rarityTier: 5, 
      primaryColor: 0xFFCFD8DC, 
      secondaryColor: 0xFF455A64, 
      category: TitleCategory.hallOfFame,
      ruleDescription: "Finish a weekly leaderboard in the Top 3 for 5 different weeks.",
    ),
    TitleDefinition(
      name: "Five-Star Champion", 
      requiredMinutes: 5, 
      icon: "⭐️⭐️⭐️⭐️⭐️",
      rarityTier: 6, 
      primaryColor: 0xFFFFEA00, 
      secondaryColor: 0xFFE65100, 
      category: TitleCategory.hallOfFame,
      ruleDescription: "Reach the Top 1 Global position for a total of 5 weeks. A true legend of the community.",
    ),
    // EXCLUSIVE ROLE-BASED TITLES
    TitleDefinition(
      name: "Developer",
      requiredMinutes: 0,
      icon: "🛠️",
      rarityTier: 6, // Mythic
      primaryColor: 0xFF7C4DFF, // Deep Purple
      secondaryColor: 0xFF1A0033, // Void Purple
      category: TitleCategory.exclusive,
      requiredRole: "developer",
      ruleDescription: "An exclusive title reserved for the developers of this application.",
    ),
    TitleDefinition(
      name: "Contributor",
      requiredMinutes: 0,
      icon: "🌸",
      rarityTier: 5, // Mythic-1
      primaryColor: 0xFFFF4081, // Radiant Pink
      secondaryColor: 0xFFE0E0E0, // Silver
      category: TitleCategory.exclusive,
      requiredRole: "contributor",
      ruleDescription: "An exclusive title for contributors who supported this application.",
    ),
  ];

  static String getAutomaticTitle(int minutes, {int userRank = 0}) {
    // 🏆 Priority 1: Competitive Rankings (Top 1, 2, 3)
    if (userRank == 1) return "Top 1 Global";
    if (userRank == 2) return "Top 2 Global";
    if (userRank == 3) return "Top 3 Global";

    // 🚀 Priority 2: TIME-based titles
    for (final title in musicTitles.reversed) {
      if (title.category == TitleCategory.time && minutes >= title.requiredMinutes) {
        return title.name;
      }
    }
    return musicTitles.first.name;
  }

  static TitleDefinition resolveTitleDefinition(String? titleName, int minutes, {int userRank = 0}) {
    if (titleName != null && 
        titleName != "N/A" && 
        titleName.trim().isNotEmpty) {
      for (final t in musicTitles) {
        if (t.isDynamic) {
          // Dynamic matching: if Saved Name starts with Template Prefix
          // Template: "Loyal Listener of [Artist]"
          final pattern = t.name.split('[Artist]').first;
          if (titleName.startsWith(pattern)) return t;
        } else if (t.name == titleName) {
          return t;
        }
      }
    }
    
    // 🏆 Fallback to competitive first
    if (userRank == 1) return musicTitles.firstWhere((t) => t.name == "Top 1 Global");
    if (userRank == 2) return musicTitles.firstWhere((t) => t.name == "Top 2 Global");
    if (userRank == 3) return musicTitles.firstWhere((t) => t.name == "Top 3 Global");

    // 🚀 Fallback to automatic (Time-based)
    for (final t in musicTitles.reversed) {
      if (t.category == TitleCategory.time && minutes >= t.requiredMinutes) return t;
    }
    return musicTitles.first;
  }

  static bool isTitleUnlocked(TitleDefinition t, int totalMinutes, int maxStreak,
      {int userRank = 0, int weeklyWins = 0, int weeklyPodiums = 0, String? userRole, 
       int dailyPlays = 0, int weeklyPlays = 0, Map<String, int>? artistMinutes}) {
    if (t.category == TitleCategory.time) {
      return totalMinutes >= t.requiredMinutes;
    }
    if (t.category == TitleCategory.behavior) {
      // Intensity checks
      if (t.name == "Binge Listener") return dailyPlays >= t.requiredMinutes;
      if (t.name == "Music Marathoner" || t.name == "Unstoppable Pulse" || t.name == "Atomic Rhythm") 
        return weeklyPlays >= t.requiredMinutes;
      
      // Default behavior: Consecutive loops (Repeat Offender, etc.)
      return maxStreak >= t.requiredMinutes;
    }
    if (t.category == TitleCategory.superfan) {
      // Return true if any one artist in the map meets the threshold
      return artistMinutes?.values.any((m) => m >= t.requiredMinutes) ?? false;
    }
    if (t.category == TitleCategory.competitive) {
      if (t.name == "Top 1 Global") return userRank == 1;
      if (t.name == "Top 2 Global") return userRank == 2;
      if (t.name == "Top 3 Global") return userRank == 3;
      return false;
    }
    if (t.category == TitleCategory.hallOfFame) {
      if (t.name == "Weekly Veteran" || t.name == "Consistent Elite")
        return weeklyPodiums >= t.requiredMinutes;
      if (t.name == "Five-Star Champion")
        return weeklyWins >= t.requiredMinutes;
      return false;
    }
    if (t.category == TitleCategory.exclusive) {
      // Role-based unlocking
      if (t.name == "Contributor" && userRole == "developer") return true;
      return userRole != null && t.requiredRole == userRole;
    }
    return false;
  }

  static DateTime getNowUTC() {
    return DateTime.now().toUtc();
  }

  static DateTime toGMT7(DateTime utc) {
    return utc.add(const Duration(hours: 7));
  }

  static DateTime getGMT7Now() {
    return toGMT7(getNowUTC());
  }

  static bool isSameDayGMT7(DateTime utc1, DateTime utc2) {
    final t1 = toGMT7(utc1);
    final t2 = toGMT7(utc2);
    return t1.year == t2.year && t1.month == t2.month && t1.day == t2.day;
  }

  static bool isSameWeekGMT7(DateTime utc1, DateTime utc2) {
    final t1 = toGMT7(utc1);
    final t2 = toGMT7(utc2);
    // Move both to the Monday of their respective weeks (GMT+7 basis)
    final aMonday = DateTime.utc(t1.year, t1.month, t1.day - (t1.weekday - 1));
    final bMonday = DateTime.utc(t2.year, t2.month, t2.day - (t2.weekday - 1));
    return aMonday.year == bMonday.year &&
        aMonday.month == bMonday.month &&
        aMonday.day == bMonday.day;
  }

  static String getTimeUntilNextReset(int tabIndex) {
    if (tabIndex == 2) return ""; // All-time: No countdown

    final nowGMT7 = getGMT7Now();
    DateTime targetGMT7;

    if (tabIndex == 0) {
      // Daily Reset (Midnight GMT+7)
      targetGMT7 = DateTime.utc(nowGMT7.year, nowGMT7.month, nowGMT7.day + 1);
    } else {
      // Weekly Reset (Monday Midnight GMT+7)
      int daysUntilMonday = (8 - nowGMT7.weekday) % 7;
      if (daysUntilMonday <= 0) daysUntilMonday = 7;
      targetGMT7 = DateTime.utc(nowGMT7.year, nowGMT7.month, nowGMT7.day + daysUntilMonday);
    }

    final diff = targetGMT7.difference(nowGMT7);
    if (diff.isNegative) return "00:00:00";

    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;

    List<String> parts = [];
    if (d > 0) parts.add("$d days");
    if (h > 0) parts.add("$h hours");
    if (m > 0) parts.add("$m minutes");
    parts.add("$s seconds");

    return parts.join(" ");
  }

  static String getStartOfTodayGMT7() {
    final nowGMT7 = getGMT7Now();
    // Midnight GMT+7 baseline
    final startGMT7 = DateTime.utc(nowGMT7.year, nowGMT7.month, nowGMT7.day);
    // Subtract 7h to get the actual UTC stored in PocketBase
    return startGMT7.subtract(const Duration(hours: 7)).toIso8601String().replaceFirst('T', ' ');
  }

  static String getStartOfWeekGMT7() {
    final nowGMT7 = getGMT7Now();
    // Monday of this week GMT+7 baseline
    int daysToSubtract = nowGMT7.weekday - 1;
    final mondayGMT7 = DateTime.utc(nowGMT7.year, nowGMT7.month, nowGMT7.day - daysToSubtract);
    // Subtract 7h to get the actual UTC stored in PocketBase
    return mondayGMT7.subtract(const Duration(hours: 7)).toIso8601String().replaceFirst('T', ' ');
  }

  static String getStartOfLastWeekGMT7() {
    final nowGMT7 = getGMT7Now();
    // Monday of last week GMT+7 baseline
    int daysToSubtract = (nowGMT7.weekday - 1) + 7;
    final lastMondayGMT7 = DateTime.utc(nowGMT7.year, nowGMT7.month, nowGMT7.day - daysToSubtract);
    // Subtract 7h
    return lastMondayGMT7.subtract(const Duration(hours: 7)).toIso8601String().replaceFirst('T', ' ');
  }
}
