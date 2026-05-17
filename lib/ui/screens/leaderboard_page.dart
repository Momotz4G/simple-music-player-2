import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/pocketbase_service.dart';
import '../../providers/stats_provider.dart';
import '../components/user_profile_overlay.dart';
import '../../utils/stats_utils.dart';
import '../components/widgets/supreme_title_badge.dart';
import '../../services/spotify_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/search_bridge_provider.dart';
import 'dart:async';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  int _selectedTab = 2; // 0: Daily, 1: Weekly, 2: All-Time
  bool _isArtistView = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboardData = [];
  final Map<String, Future<String?>> _artistImageFutures = {};
  String _error = '';
  Timer? _countdownTimer;
  String _countdownText = '';

  @override
  void initState() {
    super.initState();
    // 🚀 Sync local stats to cloud FIRST, then fetch leaderboard
    _syncThenFetch();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _countdownText = StatsUtils.getTimeUntilNextReset(_selectedTab);
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<String?> _getArtistImageWithFallback(String artist) async {
    // 🚀 NEW: Use the unified service which handles Cache, Spotify, and VPS correctly with logs!
    return await SpotifyService.getArtistImage(
        artistName: artist, highQuality: true);
  }

  Future<void> _syncThenFetch() async {
    try {
      await ref.read(statsProvider.notifier).syncNow();
    } catch (e) {
      debugPrint("⚠️ Leaderboard: Pre-fetch sync failed: $e");
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _artistImageFutures.clear();
    });

    String sortBy = _isArtistView ? 'play_count' : 'total_minutes';
    String? filter;

    if (!_isArtistView) {
      filter = 'nickname != ""';
    }

    if (_selectedTab == 0) {
      sortBy = 'daily_play_count';
      filter = filter != null
          ? '$filter && last_play_date >= "${StatsUtils.getStartOfTodayGMT7()}"'
          : 'last_play_date >= "${StatsUtils.getStartOfTodayGMT7()}"';
    } else if (_selectedTab == 1) {
      sortBy = 'weekly_play_count';
      filter = filter != null
          ? '$filter && last_play_date >= "${StatsUtils.getStartOfWeekGMT7()}"'
          : 'last_play_date >= "${StatsUtils.getStartOfWeekGMT7()}"';
    } else if (_selectedTab == 2 && !_isArtistView) {
      // 🚀 FIX: For All-Time, filter to only users with total_minutes > 0
      // This ensures we don't waste the fetch limit on inactive/empty records
      filter = '$filter && total_minutes > 0';
    }

    try {
      List<Map<String, dynamic>> records;

      if (_isArtistView) {
        // Fetch a bit extra so we capture duplicated variations
        final int fetchLimit = _selectedTab == 2 ? 30 : 50;
        records = await PocketBaseService().fetchArtistLeaderboard(
          sortBy: sortBy,
          limit: fetchLimit,
          filter: filter,
        );

        final mergedRecords = <String, Map<String, dynamic>>{};

        for (final r in records) {
          final count = r[sortBy] ?? 0;
          if (count > 0 && r['name'] != null) {
            String rawName = r['name'] as String;

            // 1. Remove parentheses/brackets e.g. "IVE (아이브)" -> "IVE "
            String cleanName = rawName.replaceAll(RegExp(r'\(.*?\)'), '');
            cleanName = cleanName.replaceAll(RegExp(r'\[.*?\]'), '');

            // 2. Extract primary artist roughly
            if (cleanName.contains(',')) cleanName = cleanName.split(',').first;
            if (cleanName.contains('&')) cleanName = cleanName.split('&').first;
            if (cleanName.contains('/')) cleanName = cleanName.split('/').first;

            cleanName = cleanName.trim();
            if (cleanName.isEmpty) cleanName = "Unknown Artist";

            final matchKey = cleanName.toLowerCase();

            if (mergedRecords.containsKey(matchKey)) {
              // Merge play counts
              final existing = mergedRecords[matchKey]!;
              existing[sortBy] = (existing[sortBy] ?? 0) + count;

              if (r['daily_play_count'] != null)
                existing['daily_play_count'] =
                    (existing['daily_play_count'] ?? 0) + r['daily_play_count'];
              if (r['weekly_play_count'] != null)
                existing['weekly_play_count'] =
                    (existing['weekly_play_count'] ?? 0) +
                        r['weekly_play_count'];
              if (r['play_count'] != null)
                existing['play_count'] =
                    (existing['play_count'] ?? 0) + r['play_count'];
            } else {
              // New record
              final newRecord = Map<String, dynamic>.from(r);
              newRecord['name'] = cleanName; // Override with clean name
              mergedRecords[matchKey] = newRecord;
            }
          }
        }

        // Convert to list, sort by the requested metric, and apply strict UI limit
        var filteredList = mergedRecords.values.toList();
        filteredList.sort((a, b) => (b[sortBy] ?? 0).compareTo(a[sortBy] ?? 0));

        final int finalUiLimit =
            (_selectedTab == 0 || _selectedTab == 1) ? 25 : 10;
        final filtered = filteredList.take(finalUiLimit).toList();

        if (mounted) {
          setState(() {
            _leaderboardData = filtered;
            _isLoading = false;
          });
        }
      } else {
        records = await PocketBaseService().fetchLeaderboard(
          sortBy: sortBy,
          limit: _selectedTab == 2
              ? 200
              : 100, // 🚀 FIX: Fetch more for All-Time to ensure 50 unique users after dedup
          filter: filter,
        );

        // 🚀 RANK INJECTION: Fetch Top 3 All-Time if viewing Daily/Weekly to show correct badges
        List<Map<String, dynamic>> top3AllTime = [];
        if (_selectedTab != 2) {
          top3AllTime = await PocketBaseService().fetchLeaderboard(
            sortBy: 'total_minutes',
            limit: 3,
            filter: 'nickname != ""',
          );
        }

        // Deduplicate locally and filter
        // Dedup by BOTH user_id AND nickname to catch multi-device duplicates
        final seenUserIds = <String>{};
        final seenNicknames =
            <String, int>{}; // nickname -> index in filtered list
        final seenHighScores =
            <String>{}; // 🚀 Detect clones by identical high scores (minutes + plays)
        final filtered = <Map<String, dynamic>>[];
        for (final r in records) {
          // 🚀 Inject rank if they are in Top 3 All-Time
          if (_selectedTab != 2) {
            for (int i = 0; i < top3AllTime.length; i++) {
              final isMatch = (r['user_id'] != null &&
                      top3AllTime[i]['user_id'] == r['user_id']) ||
                  (r['nickname'] != null &&
                      top3AllTime[i]['nickname'] == r['nickname']);
              if (isMatch) {
                r['leaderboard_rank'] = i + 1;
                break;
              }
            }
          }

          final count = r[sortBy] ?? 0;
          if (count <= 0) continue;

          final rawNick = r['nickname'] as String?;
          if (rawNick == null || rawNick.trim().isEmpty) continue;

          // Skip if we've already seen this user_id
          final uId = r['user_id'] as String?;
          if (uId != null && uId.isNotEmpty && seenUserIds.contains(uId))
            continue;

          // 🚀 BULLETPROOF CLONE GUARD
          // If an account has exactly the same total_minutes AND play_count as an account we've already processed,
          // it is mathematically guaranteed to be a cloned duplicate (exploiting the unlink bug).
          // 🚀 FIX: Only apply clone guard for Daily/Weekly where duplicates are more likely exploits.
          // For All-Time, the nickname + user_id dedup is sufficient.
          final totalMins = (r['total_minutes'] as num?)?.toInt() ?? 0;
          final totalPlays = (r['play_count'] as num?)?.toInt() ?? 0;
          final cloneKey = "${totalMins}_$totalPlays";

          if (_selectedTab != 2 &&
              totalMins > 100 &&
              seenHighScores.contains(cloneKey)) {
            continue; // Skip clone (only for Daily/Weekly)
          }

          // Dedup by nickname (case-insensitive): keep the one with higher score
          final nickKey = rawNick.trim().toLowerCase();
          if (seenNicknames.containsKey(nickKey)) {
            final existingIdx = seenNicknames[nickKey]!;
            final existingCount = filtered[existingIdx][sortBy] ?? 0;
            if (count > existingCount) {
              // Replace the weaker duplicate with this stronger one
              filtered[existingIdx] = r;
              if (totalMins > 100) seenHighScores.add(cloneKey);
            }
            // Either way, track this user_id as seen
            if (uId != null && uId.isNotEmpty) seenUserIds.add(uId);
            continue;
          }

          if (uId != null && uId.isNotEmpty) seenUserIds.add(uId);
          if (totalMins > 100) seenHighScores.add(cloneKey);
          seenNicknames[nickKey] = filtered.length;
          filtered.add(r);
        }

        // 🚀 FIX: Cap All-Time at 50 users, Daily/Weekly at 25
        final int maxDisplay = _selectedTab == 2 ? 50 : 25;
        final cappedList = filtered.length > maxDisplay
            ? filtered.sublist(0, maxDisplay)
            : filtered;

        if (mounted) {
          setState(() {
            _leaderboardData = cappedList;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context)!.loadingError;
          _isLoading = false;
        });
      }
    }
  }

  void _onTabChanged(int index) {
    if (_selectedTab == index) return;
    setState(() {
      _selectedTab = index;
      _countdownText = StatsUtils.getTimeUntilNextReset(index);
    });
    _fetchData();
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "?";
    final names = name.trim().split(' ');
    if (names.length > 1) {
      return "${names[0][0]}${names[names.length - 1][0]}".toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  void _showUserProfile(Map<String, dynamic> userData) async {
    // 🚀 RANK INJECTION: If clicking from Daily/Weekly, check if they are a Top 3 All-Time champion
    if (userData['leaderboard_rank'] == null) {
      try {
        final top3 = await PocketBaseService().fetchLeaderboard(
            sortBy: 'total_minutes', limit: 3, filter: 'nickname != ""');
        for (int i = 0; i < top3.length; i++) {
          final isMatch = (userData['user_id'] != null &&
                  top3[i]['user_id'] == userData['user_id']) ||
              (userData['nickname'] != null &&
                  top3[i]['nickname'] == userData['nickname']);
          if (isMatch) {
            userData['leaderboard_rank'] = i + 1;
            break;
          }
        }
      } catch (e) {
        debugPrint("⚠️ Quick Rank Check Error: $e");
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserProfileOverlay(userData: userData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    final screenWidth = MediaQuery.of(context).size.width;
    // 🚀 Let it "fullfill" the screen by using small fixed padding on PC
    final double horizPadding = screenWidth > 900 ? 40.0 : 20.0;
    final double itemWidth = screenWidth > 900
        ? (screenWidth -
            250 -
            (horizPadding *
                2)) // Accurate available width after sidebar (250px)
        : (screenWidth - (horizPadding * 2));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 80,
            pinned: true,
            backgroundColor: Theme.of(context)
                .scaffoldBackgroundColor
                .withValues(alpha: 0.95),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(
                  left: screenWidth > 800 ? horizPadding : 64.0, bottom: 16),
              title: Text(
                AppLocalizations.of(context)!.globalLeaderboard,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              centerTitle: false,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accentColor.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Tabs
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: horizPadding, vertical: 16),
              child: Column(
                children: [
                  _buildMasterToggle(accentColor, isDark),
                  const SizedBox(height: 16),
                  _buildUnifiedTabs(accentColor, isDark),
                  if (_countdownText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 14,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            "${AppLocalizations.of(context)!.resetsIn} : ",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          Text(
                            _countdownText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error.isNotEmpty)
            _buildErrorState(context, accentColor, isDark)
          else if (_leaderboardData.isEmpty)
            _buildEmptyState(context, isDark)
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizPadding),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final row = _leaderboardData[index];

                    String sortBy =
                        _isArtistView ? 'play_count' : 'total_minutes';
                    if (_selectedTab == 0) sortBy = 'daily_play_count';
                    if (_selectedTab == 1) sortBy = 'weekly_play_count';

                    final scoreValue = row[sortBy] ?? 0;

                    Color? rankColor;
                    if (index == 0) rankColor = const Color(0xFFFFD700);
                    if (index == 1) rankColor = const Color(0xFFC0C0C0);
                    if (index == 2) rankColor = const Color(0xFFCD7F32);

                    if (_isArtistView) {
                      final artistName = row['name'] ?? 'Unknown Artist';
                      final isHero = index == 0;

                      _artistImageFutures[artistName] ??=
                          _getArtistImageWithFallback(artistName);

                      return ArtistLeaderboardItem(
                        artistName: artistName,
                        index: index,
                        isHero: isHero,
                        playCount: scoreValue,
                        itemWidth: itemWidth,
                        rankColor: rankColor,
                        imageFuture: _artistImageFutures[artistName]!,
                      );
                    } else {
                      final name =
                          row['nickname'] ?? row['hostname'] ?? 'Unknown User';
                      final topArtist = row['top_artist'] as String?;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Inject leaderboard rank for All-Time tab to resolve competitive titles
                              if (_selectedTab == 2) {
                                row['leaderboard_rank'] = index + 1;
                              }
                              _showUserProfile(row);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Ink(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: rankColor?.withValues(alpha: 0.3) ??
                                      (isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.black
                                              .withValues(alpha: 0.05)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Rank
                                  Container(
                                    width: 45,
                                    alignment: Alignment.center,
                                    child: Text(
                                      "#${index + 1}",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: rankColor ??
                                            (isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600]),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Avatar
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        accentColor.withValues(alpha: 0.1),
                                    backgroundImage:
                                        PocketBaseService().getAvatarUrl(row) !=
                                                null
                                            ? NetworkImage(PocketBaseService()
                                                .getAvatarUrl(row)!)
                                            : null,
                                    child: PocketBaseService()
                                                .getAvatarUrl(row) ==
                                            null
                                        ? Text(_getInitials(name),
                                            style: TextStyle(
                                                color: accentColor,
                                                fontWeight: FontWeight.bold))
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        () {
                                          final titleDef =
                                              StatsUtils.resolveTitleDefinition(
                                            row['selected_title'],
                                            row['total_minutes'] ?? 0,
                                            userRank: _selectedTab == 2
                                                ? index + 1
                                                : (row['leaderboard_rank']
                                                        as int? ??
                                                    0),
                                          );
                                          final hasWings =
                                              titleDef.rarityTier >= 3;

                                          return Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                ),
                                              ),
                                              if (row['role'] ==
                                                  'developer') ...[
                                                const SizedBox(width: 4),
                                                Icon(Icons.verified_rounded,
                                                    size: 14,
                                                    color: accentColor),
                                              ],
                                              // 🚀 Add extra spacing for titles with wings
                                              SizedBox(
                                                  width: hasWings ? 22 : 8),
                                              SupremeTitleBadge.fromDefinition(
                                                titleDef,
                                                displayName: StatsUtils
                                                    .resolveDisplayName(
                                                        titleDef,
                                                        row['selected_title']
                                                            as String?),
                                                width: screenWidth < 500
                                                    ? 100
                                                    : (screenWidth < 1200
                                                        ? 120
                                                        : 140),
                                                height: 20,
                                              ),
                                            ],
                                          );
                                        }(),
                                        if (topArtist != null &&
                                            topArtist.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: InkWell(
                                              onTap: () {
                                                ref
                                                    .read(
                                                        navigationStackProvider
                                                            .notifier)
                                                    .push(
                                                      NavigationItem(
                                                        type: NavigationType
                                                            .artist,
                                                        data: ArtistSelection(
                                                            artistName:
                                                                topArtist),
                                                      ),
                                                    );
                                              },
                                              child: Text(
                                                "${AppLocalizations.of(context)!.topArtist}: $topArtist",
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? Colors.grey[500]
                                                        : Colors.grey[600]),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Score
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                            (_selectedTab == 2 &&
                                                    !_isArtistView)
                                                ? Icons.access_time_rounded
                                                : Icons.play_arrow_rounded,
                                            size: 16,
                                            color: accentColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          _selectedTab == 2
                                              ? StatsUtils.formatMinutes(
                                                  scoreValue,
                                                  AppLocalizations.of(context)!)
                                              : scoreValue.toString(),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: accentColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  childCount: _leaderboardData.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildMasterToggle(Color accentColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption(AppLocalizations.of(context)!.topListeners,
              Icons.people_rounded, !_isArtistView, accentColor, isDark, false),
          _buildToggleOption(
              AppLocalizations.of(context)!.topArtists,
              Icons.mic_external_on_rounded,
              _isArtistView,
              accentColor,
              isDark,
              true),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String title, IconData icon, bool isSelected,
      Color accentColor, bool isDark, bool targetState) {
    return GestureDetector(
      onTap: () {
        if (targetState != _isArtistView) {
          setState(() {
            _isArtistView = targetState;
          });
          _fetchData();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedTabs(Color accentColor, bool isDark) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    Widget buildTab(int index, String label) {
      final isSelected = _selectedTab == index;
      return Expanded(
        child: InkWell(
          onTap: () => _onTabChanged(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? accentColor
                    : (isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          buildTab(0, AppLocalizations.of(context)!.daily),
          buildTab(1, AppLocalizations.of(context)!.weekly),
          buildTab(2, AppLocalizations.of(context)!.allTime),
        ],
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, Color accentColor, bool isDark) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.signal_wifi_connected_no_internet_4_rounded,
                  size: 64,
                  color: accentColor.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                AppLocalizations.of(context)!.connectionLostLeaderboard,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.connectionLostLeaderboardDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context)!.retryConnection),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 8,
                  shadowColor: accentColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.leaderboard_rounded,
                size: 80,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.noRankingsYet,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.beFirstToClaim,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(AppLocalizations.of(context)!.checkAgain),
                style: TextButton.styleFrom(
                  foregroundColor: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArtistLeaderboardItem extends ConsumerStatefulWidget {
  final String artistName;
  final int index;
  final bool isHero;
  final int playCount;
  final double itemWidth;
  final Color? rankColor;
  final Future<String?> imageFuture;

  const ArtistLeaderboardItem({
    super.key,
    required this.artistName,
    required this.index,
    required this.isHero,
    required this.playCount,
    required this.itemWidth,
    required this.rankColor,
    required this.imageFuture,
  });

  @override
  ConsumerState<ArtistLeaderboardItem> createState() =>
      _ArtistLeaderboardItemState();
}

class _ArtistLeaderboardItemState extends ConsumerState<ArtistLeaderboardItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final double cardHeight = widget.isHero ? 160.0 : 95.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: _isHovered ? 1.01 : 1.0,
        child: InkWell(
          onTap: () {
            ref.read(navigationStackProvider.notifier).push(
                  NavigationItem(
                    type: NavigationType.artist,
                    data: ArtistSelection(artistName: widget.artistName),
                  ),
                );
          },
          child: FutureBuilder<String?>(
            future: widget.imageFuture,
            builder: (context, snapshot) {
              final hasImage = snapshot.data != null;
              return Container(
                margin: EdgeInsets.only(bottom: widget.isHero ? 10 : 5),
                height: cardHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.isHero ? 18 : 12),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.isHero ? 18 : 12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Base dark background
                      Container(color: const Color(0xFF0D0D0D)),

                      // Artist image - Positions animate on hover!
                      if (hasImage)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: _isHovered
                              ? widget.itemWidth
                              : widget.itemWidth * 0.75,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.zero,
                            child: Image.network(
                              snapshot.data!,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0.0, -0.2),
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),

                      // Mask Gradient - Fades on hover!
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: _isHovered ? 0.3 : 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                const Color(0xFF0D0D0D),
                                const Color(0xFF0D0D0D),
                                const Color(0xFF0D0D0D).withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.35, 0.85],
                            ),
                          ),
                        ),
                      ),

                      // Top-1 accent
                      if (widget.isHero)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 3,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                              ),
                            ),
                          ),
                        ),

                      // Content overlay
                      Padding(
                        padding: EdgeInsets.only(
                          left: widget.isHero ? 20 : 16,
                          right: 16,
                          top: widget.isHero ? 20 : 12,
                          bottom: widget.isHero ? 20 : 12,
                        ),
                        child: Row(
                          children: [
                            // Rank
                            SizedBox(
                              width: widget.isHero ? 44 : 32,
                              child: Text(
                                "${widget.index + 1}",
                                style: TextStyle(
                                  fontSize: widget.isHero ? 44 : 28,
                                  fontWeight: FontWeight.w900,
                                  color: widget.rankColor ??
                                      Colors.white.withValues(alpha: 0.15),
                                  height: 1.0,
                                  shadows: _isHovered
                                      ? [
                                          const Shadow(
                                            blurRadius: 10,
                                            color: Colors.black,
                                          )
                                        ]
                                      : [],
                                ),
                              ),
                            ),
                            SizedBox(width: widget.isHero ? 14 : 10),

                            // Name + plays
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.artistName.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: widget.isHero ? 22 : 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: widget.isHero ? 3.0 : 1.2,
                                      shadows: _isHovered
                                          ? [
                                              const Shadow(
                                                blurRadius: 10,
                                                color: Colors.black,
                                              )
                                            ]
                                          : [],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: widget.isHero ? 6 : 3),
                                  Text(
                                    "▶  ${widget.playCount} ${AppLocalizations.of(context)!.plays}",
                                    style: TextStyle(
                                      fontSize: widget.isHero ? 12 : 10,
                                      fontWeight: FontWeight.w500,
                                      color: widget.rankColor
                                              ?.withValues(alpha: 0.8) ??
                                          Colors.white.withValues(alpha: 0.4),
                                      shadows: _isHovered
                                          ? [
                                              const Shadow(
                                                blurRadius: 8,
                                                color: Colors.black,
                                              )
                                            ]
                                          : [],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
