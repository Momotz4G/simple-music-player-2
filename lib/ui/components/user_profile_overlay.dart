import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../services/pocketbase_service.dart';
import '../../services/metrics_service.dart';
import '../../providers/stats_provider.dart';
import '../../providers/profile_provider.dart';
import '../../utils/stats_utils.dart';
import '../../services/spotify_service.dart';
import '../../services/deezer_service.dart';
import 'widgets/supreme_title_badge.dart';
import '../../l10n/app_localizations.dart';

class UserProfileOverlay extends ConsumerWidget {
  final Map<String, dynamic> userData;

  const UserProfileOverlay({super.key, required this.userData});

  Future<String?> _getArtistImageWithFallback(String artist) async {
    try {
      return await SpotifyService.getArtistImage(artistName: artist);
    } catch (e) {
      if (e.toString().contains("rate_limit")) {
        try {
          return await SpotifyService.getArtistImage(
              artistName: artist, preferPrimary: true);
        } catch (e2) {
          if (e2.toString().contains("rate_limit")) {
            final deezerArtist = await DeezerService.getArtist(artist);
            return deezerArtist?.imageUrl;
          }
          return null;
        }
      }
      return null;
    }
  }

  Future<String?> _getTrackImageWithFallback(
      String track, String artist) async {
    try {
      return await SpotifyService.getTrackImage(track, artist);
    } catch (e) {
      if (e.toString().contains("rate_limit")) {
        try {
          return await SpotifyService.getTrackImage(track, artist,
              preferPrimary: true);
        } catch (e2) {
          if (e2.toString().contains("rate_limit")) {
            return await DeezerService.getTrackImage(track, artist);
          }
          return null;
        }
      }
      return null;
    }
  }

  bool _isCurrentUser() {
    final localUserId = MetricsService().userId;
    final remoteUserId = userData['user_id'] as String?;
    return localUserId != null &&
        remoteUserId != null &&
        localUserId == remoteUserId;
  }

  Map<String, int> _parseCloudArtistMinutes(dynamic raw) {
    final Map<String, int> result = {};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is int) {
          result[k.toString()] = v;
        } else if (v is num) {
          result[k.toString()] = v.toInt();
        }
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final nickname =
        userData['nickname'] ?? userData['hostname'] ?? 'Unknown User';

    final avatarUrl = PocketBaseService().getAvatarUrl(userData);

    // 🚀 LIVE STATS: If viewing own profile, use local calculated stats (real-time)
    final bool isSelf = _isCurrentUser();

    String topArtist;
    String topTrack;
    int totalMinutes;
    int totalPlays;
    String? selectedTitle;
    int weeklyWins;
    int weeklyPodiums;
    String? userRole;
    int dailyPlays;
    int weeklyPlays;

    if (isSelf) {
      final statsState = ref.watch(statsProvider);
      final profile = ref.watch(profileProvider);
      final calculated = StatsUtils.calculate(statsState);

      // 🚀 MERGE CLOUD AND LOCAL: Take the higher value to handle cross-device inconsistencies
      final cloudPlays = userData['play_count'] ?? 0;
      final cloudMinutes = userData['total_minutes'] ?? 0;

      totalPlays = calculated.totalPlays > cloudPlays
          ? calculated.totalPlays
          : cloudPlays;
      totalMinutes = calculated.totalMinutes > cloudMinutes
          ? calculated.totalMinutes
          : cloudMinutes;

      // 🚀 CLOUD PRIORITIZATION: Prefer official lifetime stats from PocketBase/PC sync
      topArtist = profile.cloudTopArtist ??
          userData['top_artist'] as String? ??
          calculated.topArtist?.key ??
          "N/A";
      topTrack = profile.cloudTopTrack ??
          userData['top_track'] as String? ??
          calculated.topTrack?.key ??
          "N/A";

      selectedTitle =
          profile.selectedTitle ?? userData['selected_title'] as String?;

      final cloudWins = userData['weekly_wins_count'] ?? 0;
      final cloudPodiums = userData['weekly_podiums_count'] ?? 0;
      weeklyWins = statsState.weeklyWinsCount > cloudWins
          ? statsState.weeklyWinsCount
          : cloudWins;
      weeklyPodiums = statsState.weeklyPodiumsCount > cloudPodiums
          ? statsState.weeklyPodiumsCount
          : cloudPodiums;

      userRole = profile.role ?? userData['role'] as String?;
      dailyPlays = (calculated.dailyPlays > (profile.cloudDailyPlays ?? 0))
          ? calculated.dailyPlays
          : (profile.cloudDailyPlays ?? 0);
      weeklyPlays = (calculated.weeklyPlays > (profile.cloudWeeklyPlays ?? 0))
          ? calculated.weeklyPlays
          : (profile.cloudWeeklyPlays ?? 0);
    } else {
      topArtist = userData['top_artist'] as String? ?? "N/A";
      topTrack = userData['top_track'] as String? ?? "N/A";
      totalMinutes = userData['total_minutes'] ?? 0;
      totalPlays = userData['play_count'] ?? 0;
      selectedTitle = userData['selected_title'] as String?;
      weeklyWins = userData['weekly_wins_count'] ?? 0;
      weeklyPodiums = userData['weekly_podiums_count'] ?? 0;
      userRole = userData['role'] as String?;
      dailyPlays = userData['daily_play_count'] ?? 0;
      weeklyPlays = userData['weekly_play_count'] ?? 0;
    }

    final int maxStreak = isSelf
        ? (ref.watch(statsProvider).maxRepeatStreak > (ref.watch(profileProvider).cloudMaxRepeatStreak ?? 0)
            ? ref.watch(statsProvider).maxRepeatStreak
            : (ref.watch(profileProvider).cloudMaxRepeatStreak ?? 0))
        : (userData['max_repeat_streak'] ?? 0);

    final profileRank = ref.watch(profileProvider).cloudRank ?? 0;
    final liveRank = userData['leaderboard_rank'] as int? ?? 0;

    // Pick the "best" (lowest non-zero) rank
    int userRank = 0;
    if (profileRank > 0 && liveRank > 0) {
      userRank = profileRank < liveRank ? profileRank : liveRank;
    } else {
      userRank = profileRank > 0 ? profileRank : liveRank;
    }

    if (!isSelf) userRank = liveRank;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            height: MediaQuery.of(context).size.width > 600 
                ? 700 
                : MediaQuery.of(context).size.height * 0.85,
            margin: EdgeInsets.symmetric(
              vertical: MediaQuery.of(context).size.width > 600 ? 40 : 20,
              horizontal: MediaQuery.of(context).size.width > 600 ? 20 : 16,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E1E).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(height: 12),
                // Grab handle (Pinned outside scroll view for drag-to-close)
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Scrollable Content
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Profile Section
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(
                            nickname.isNotEmpty
                                ? nickname[0].toUpperCase()
                                : "?",
                            style: TextStyle(
                                fontSize: 40,
                                color: accentColor,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        nickname,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      if (userRole == 'developer') ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: AppLocalizations.of(context)!.verifiedDeveloper,
                          child: Icon(Icons.verified_rounded,
                              size: 20, color: accentColor),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Supreme Title Badge
                  SupremeTitleBadge.fromDefinition(
                    StatsUtils.resolveTitleDefinition(
                        selectedTitle, totalMinutes,
                        userRank: userRank),
                    displayName: StatsUtils.resolveDisplayName(
                      StatsUtils.resolveTitleDefinition(
                          selectedTitle, totalMinutes,
                          userRank: userRank),
                      selectedTitle,
                    ),
                    width: 180,
                    height: 32,
                  ),

                  const SizedBox(height: 32),

                  // Stats Grid
                  _buildStatsGrid(
                      context, totalPlays, totalMinutes, isDark, accentColor),

                  const SizedBox(height: 24),

                  // Advanced Insights
                  _buildSectionTitle(context, AppLocalizations.of(context)!.topArtistAndTrack),
                  FutureBuilder<String?>(
                      future: topArtist != "N/A"
                          ? _getArtistImageWithFallback(
                              topArtist.split(',').first.trim())
                          : Future.value(null),
                      builder: (context, snapshot) {
                        return _buildInsightCard(
                          context,
                          AppLocalizations.of(context)!.mostListenedArtist,
                          topArtist,
                          Icons.person_rounded,
                          accentColor,
                          isDark,
                          imageUrl: snapshot.data,
                          isArtist: true,
                        );
                      }),
                  const SizedBox(height: 12),
                  FutureBuilder<String?>(
                      future: (topTrack != "N/A" && topArtist != "N/A")
                          ? _getTrackImageWithFallback(topTrack, topArtist)
                          : Future.value(null),
                      builder: (context, snapshot) {
                        return _buildInsightCard(
                          context,
                          AppLocalizations.of(context)!.favoriteTrack,
                          topTrack,
                          Icons.music_note_rounded,
                          accentColor,
                          isDark,
                          imageUrl: snapshot.data,
                        );
                      }),

                  const SizedBox(height: 24),

                  // Achievements & Titles Gallery
                  _buildSectionTitle(context, AppLocalizations.of(context)!.achievementsUnlocked),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        _buildAchievementGallery(
                          context,
                          totalMinutes,
                          maxStreak,
                          userRank,
                          isDark,
                          weeklyWins,
                          weeklyPodiums,
                          userRole,
                          dailyPlays,
                          weeklyPlays,
                          isSelf
                              ? StatsUtils.calculate(ref.read(statsProvider)).artistMinutes
                              : _parseCloudArtistMinutes(userData['artist_minutes']),
                          selectedTitle,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
),
);
  }

  Widget _buildStatsGrid(BuildContext context, int plays, int minutes,
      bool isDark, Color accentColor) {
    return Row(
      children: [
        Expanded(
          child: _buildStatMiniCard(
            AppLocalizations.of(context)!.totalPlays,
            plays.toString(),
            Icons.speed_rounded,
            accentColor,
            isDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatMiniCard(
            AppLocalizations.of(context)!.totalMinutesStat,
            minutes.toString(),
            Icons.timer_rounded,
            accentColor,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatMiniCard(
      String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, String title, String value,
      IconData icon, Color color, bool isDark,
      {String? imageUrl, bool isArtist = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(isArtist ? 22 : 12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isArtist ? 22 : 12),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(icon, color: color, size: 20),
                    )
                  : Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementGallery(
      BuildContext context,
      int totalMin,
      int maxStreak,
      int userRank,
      bool isDark,
      int wins,
      int podiums,
      String? userRole,
      int dailyPlays,
      int weeklyPlays,
      Map<String, int> artistMinutes,
      String? selectedTitle) {
    return _AchievementGallery(
      totalMin: totalMin,
      maxStreak: maxStreak,
      userRank: userRank,
      isDark: isDark,
      weeklyWins: wins,
      weeklyPodiums: podiums,
      userRole: userRole,
      dailyPlays: dailyPlays,
      weeklyPlays: weeklyPlays,
      artistMinutes: artistMinutes,
      selectedTitle: selectedTitle,
    );
  }
}

class _AchievementGallery extends ConsumerStatefulWidget {
  final int totalMin;
  final int maxStreak;
  final int userRank;
  final bool isDark;
  final int weeklyWins;
  final int weeklyPodiums;
  final String? userRole;
  final int dailyPlays;
  final int weeklyPlays;
  final Map<String, int> artistMinutes;
  final String? selectedTitle;

  const _AchievementGallery({
    required this.totalMin,
    required this.maxStreak,
    required this.userRank,
    required this.isDark,
    required this.weeklyWins,
    required this.weeklyPodiums,
    required this.dailyPlays,
    required this.weeklyPlays,
    required this.artistMinutes,
    this.selectedTitle,
    this.userRole,
  });

  @override
  ConsumerState<_AchievementGallery> createState() => _AchievementGalleryState();
}

class _AchievementGalleryState extends ConsumerState<_AchievementGallery> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    // Gather all unlocked titles except Developer
    // For other users: if they have a superfan title equipped, infer their artist minutes
    Map<String, int> effectiveArtistMinutes = Map.from(widget.artistMinutes);
    if (effectiveArtistMinutes.isEmpty && widget.selectedTitle != null) {
      // Infer from their selected title if it's a superfan title
      for (final t in StatsUtils.musicTitles.where((t) => t.isDynamic)) {
        final prefix = t.name.split('[Artist]').first;
        if (widget.selectedTitle!.startsWith(prefix)) {
          // Extract artist name and set minutes high enough to unlock this tier and all below
          final artistName = widget.selectedTitle!.substring(prefix.length);
          if (artistName.isNotEmpty) {
            effectiveArtistMinutes[artistName] = t.requiredMinutes;
          }
          break;
        }
      }
    }

    final allUnlocked = StatsUtils.musicTitles
        .where((t) {
            if (t.name == "Developer") return false;
            
            // 🚀 COMPETITIVE GUARD: Never force-show "Top X Global" from selected_title
            // — must be validated by actual rank via isTitleUnlocked
            final isForceEquipped = t.name == widget.selectedTitle && 
                                    t.category != TitleCategory.competitive;
            
            return isForceEquipped || StatsUtils.isTitleUnlocked(
              t,
              widget.totalMin,
              widget.maxStreak,
              userRank: widget.userRank,
              weeklyWins: widget.weeklyWins,
              weeklyPodiums: widget.weeklyPodiums,
              userRole: widget.userRole,
              dailyPlays: widget.dailyPlays,
              weeklyPlays: widget.weeklyPlays,
              artistMinutes: effectiveArtistMinutes,
            );
        })
        .toList();

    if (allUnlocked.isEmpty) return const SizedBox.shrink();

    final showToggle = allUnlocked.length > 10;
    final titlesToDisplay =
        _showAll ? allUnlocked : allUnlocked.take(10).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titlesToDisplay.any((t) => t.category == TitleCategory.time)) ...[
            _buildCategoryGroup(
                context,
                ref,
                AppLocalizations.of(context)!.timeBasedTitles,
                titlesToDisplay
                    .where((t) => t.category == TitleCategory.time)
                    .toList()),
            const SizedBox(height: 24),
          ],
          if (titlesToDisplay
              .any((t) => t.category == TitleCategory.behavior)) ...[
            _buildCategoryGroup(
                context,
                ref,
                AppLocalizations.of(context)!.behavioralTitles,
                titlesToDisplay
                    .where((t) => t.category == TitleCategory.behavior)
                    .toList()),
            const SizedBox(height: 24),
          ],
          if (titlesToDisplay
              .any((t) => t.category == TitleCategory.competitive)) ...[
            _buildCategoryGroup(
                context,
                ref,
                AppLocalizations.of(context)!.competitiveTitles,
                titlesToDisplay
                    .where((t) => t.category == TitleCategory.competitive)
                    .toList()),
            const SizedBox(height: 24),
          ],
          if (titlesToDisplay
              .any((t) => t.category == TitleCategory.hallOfFame)) ...[
            _buildCategoryGroup(
                context,
                ref,
                AppLocalizations.of(context)!.hallOfFameTitles,
                titlesToDisplay
                    .where((t) => t.category == TitleCategory.hallOfFame)
                    .toList()),
            const SizedBox(height: 24),
          ],
          if (titlesToDisplay
              .any((t) => t.category == TitleCategory.exclusive)) ...[
            _buildCategoryGroup(
                context,
                ref,
                AppLocalizations.of(context)!.exclusiveTitles,
                titlesToDisplay
                    .where((t) => t.category == TitleCategory.exclusive)
                    .toList()),
            const SizedBox(height: 24),
          ],
          if (titlesToDisplay
              .any((t) => t.category == TitleCategory.superfan)) ...[
            _buildCategoryGroup(
                context,
                ref,
                AppLocalizations.of(context)!.superfanTitles,
                titlesToDisplay
                    .where((t) => t.category == TitleCategory.superfan)
                    .toList()),
            const SizedBox(height: 24),
          ],
          if (showToggle)
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAll = !_showAll;
                  });
                },
                icon: Icon(
                  _showAll
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  size: 18,
                ),
                label: Text(
                  _showAll
                      ? AppLocalizations.of(context)!.showLess
                      : AppLocalizations.of(context)!.showAllTitles(allUnlocked.length),
                  style: TextStyle(
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: widget.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryGroup(
      BuildContext context, WidgetRef ref, String title, List<TitleDefinition> titles) {
    if (titles.isEmpty) return const SizedBox.shrink();

    // Check if any title in this group has wings (rarityTier >= 3)
    final hasWingedTitles = titles.any((t) => t.rarityTier >= 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
              letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: hasWingedTitles ? 28 : 12,
          runSpacing: hasWingedTitles ? 20 : 12,
          children: titles.map((t) {
            String? displayName;
            if (t.isDynamic) {
              // Try to resolve the real artist name from available data
              String? resolvedArtist;

              // 1. Check if this specific tier is the equipped title
              final sel = widget.selectedTitle;
              if (sel != null && sel.startsWith(t.name.split('[Artist]').first)) {
                displayName = sel;
              } else {
                // 2. Try to find the artist from artistMinutes who qualifies for this tier
                final artistEntry = widget.artistMinutes.entries
                    .where((e) => e.value >= t.requiredMinutes)
                    .toList();
                if (artistEntry.isNotEmpty) {
                  // Pick the one with the most minutes
                  artistEntry.sort((a, b) => b.value.compareTo(a.value));
                  resolvedArtist = StatsUtils.cleanArtistName(artistEntry.first.key);
                }

                // 3. If still no artist, try to extract from the equipped title (for other users)
                if (resolvedArtist == null && sel != null) {
                  for (final dt in StatsUtils.musicTitles.where((dt) => dt.isDynamic)) {
                    final prefix = dt.name.split('[Artist]').first;
                    if (sel.startsWith(prefix)) {
                      resolvedArtist = sel.substring(prefix.length);
                      break;
                    }
                  }
                }

                displayName = t.name.replaceFirst('[Artist]', resolvedArtist ?? 'Artist');
              }
            }
            return SupremeTitleBadge.fromDefinition(
              t,
              displayName: displayName,
              isLocked: false,
              width: 120,
              height: 22,
              tooltip: _getTitleTooltip(t),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Helper to get tooltip message based on title requirement
  String _getTitleTooltip(TitleDefinition t) {
    final l10n = AppLocalizations.of(ref.context)!;
    if (t.category == TitleCategory.time) {
      return l10n.listenMinutesTooltip(t.requiredMinutes.toString());
    } else if (t.category == TitleCategory.superfan) {
      return l10n.reachSpecificArtistTooltip(t.requiredMinutes.toString());
    } else if (t.category == TitleCategory.behavior) {
      if (t.name == "Binge Listener") {
        return l10n.reachDailyPlaysTooltip(t.requiredMinutes);
      } else if (t.name == "Music Marathoner" ||
          t.name == "Unstoppable Pulse" ||
          t.name == "Atomic Rhythm") {
        return l10n.reachWeeklyPlaysTooltip(t.requiredMinutes);
      }
      return l10n.consecutivePlaysTooltip(t.requiredMinutes);
    } else if (t.category == TitleCategory.competitive) {
      return l10n.topGlobalTooltip(t.requiredMinutes);
    } else if (t.category == TitleCategory.exclusive) {
      if (t.name == "Contributor") {
        return l10n.supportDeveloperTooltip;
      }
      return l10n.developerExclusiveTooltip;
    } else if (t.category == TitleCategory.hallOfFame) {
      if (t.name == "Five-Star Champion") {
        return l10n.championChampionTooltip;
      }
      return l10n.top3GlobalTooltip(t.requiredMinutes);
    }
    return t.ruleDescription;
  }
}
