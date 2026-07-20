import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/stats_utils.dart';
import '../../providers/stats_provider.dart';
import '../../providers/profile_provider.dart';
import 'widgets/supreme_title_badge.dart';
import '../../services/pocketbase_service.dart';
import '../../l10n/app_localizations.dart';

class TitlePickerDialog extends ConsumerStatefulWidget {
  const TitlePickerDialog({super.key});

  @override
  ConsumerState<TitlePickerDialog> createState() => _TitlePickerDialogState();
}

class _TitlePickerDialogState extends ConsumerState<TitlePickerDialog> {
  int? _previewIndex;
  int _userRank = 0; // 0: None, 1: Top1, 2: Top2, 3: Top3
  bool _showUnlockedOnly = false;
  String? _selectedDynamicArtist; // The artist picked in the dynamic selector

  @override
  void initState() {
    super.initState();
    _checkGlobalRank();
  }

  Future<void> _checkGlobalRank() async {
    try {
      final myId = PocketBaseService().userId;
      if (myId == null) return;

      final topUsers = await PocketBaseService()
          .fetchLeaderboard(sortBy: 'total_minutes', limit: 3, filter: 'nickname != ""');
      
      int rank = 0;
      for (int i = 0; i < topUsers.length; i++) {
        if (topUsers[i]['user_id'] == myId) {
          rank = i + 1;
          break;
        }
      }

      if (mounted) {
        // SYNC: Update the global profile state if the rank we just found is better/different
        if (rank > 0 && rank != ref.read(profileProvider).cloudRank) {
           // We could trigger a provider update here if needed, 
           // but for now just update local UI
        }
        setState(() => _userRank = rank > 0 ? rank : ref.read(profileProvider).cloudRank ?? 0);
      }
    } catch (e) {
      debugPrint("👑 Rank Check Error: $e");
    }
  }

  int _getCategoryProgress(TitleDefinition t, int totalMin, int maxStreak,
      int currentStreak, int winsCount, int podiumsCount, int dailyPlays, int weeklyPlays, {int? dynamicMinuteOverride}) {
    if (t.category == TitleCategory.time) return totalMin;
    if (t.category == TitleCategory.behavior) {
      if (t.name == "Binge Listener") return dailyPlays;
      if (t.name == "Music Marathoner" || t.name == "Unstoppable Pulse" || t.name == "Atomic Rhythm") {
        return weeklyPlays;
      }
      return currentStreak;
    }
    if (t.category == TitleCategory.superfan) {
      return dynamicMinuteOverride ?? 0;
    }
    if (t.category == TitleCategory.competitive) {
      if (t.name == "Top 1 Global") {
        return _userRank == 1 ? t.requiredMinutes : 0;
      }
      if (t.name == "Top 2 Global") {
        return _userRank == 2 ? t.requiredMinutes : 0;
      }
      if (t.name == "Top 3 Global") {
        return _userRank == 3 ? t.requiredMinutes : 0;
      }
      return 0;
    }
    if (t.category == TitleCategory.hallOfFame) {
      if (t.name == "Weekly Veteran" || t.name == "Consistent Elite") {
        return podiumsCount;
      }
      if (t.name == "Five-Star Champion") {
        return winsCount;
      }
    }
    if (t.category == TitleCategory.superfan) {
      if (_selectedDynamicArtist != null) {
        // Find minutes for the currently selected artist in the dynamic picker
        // The calling code (build) must have passed artistMinutes to this function
        // but since this is a private helper, I'll pass it via a hack or update the signature.
      }
    }
    return 0;
  }

  String _getLocalizedDescription(BuildContext context, TitleDefinition t) {
    final l10n = AppLocalizations.of(context)!;
    
    if (t.category == TitleCategory.time) {
      if (t.name == "Rookie Listener") return l10n.listenMinutesTooltip("0");
      return l10n.listenMinutesTooltip(t.requiredMinutes.toString());
    }
    
    if (t.category == TitleCategory.superfan) {
      return l10n.reachSpecificArtistTooltip(t.requiredMinutes.toString());
    }
    
    if (t.category == TitleCategory.behavior) {
      if (t.name == "Binge Listener") return l10n.reachDailyPlaysTooltip(t.requiredMinutes);
      if (t.name == "Music Marathoner" || t.name == "Unstoppable Pulse" || t.name == "Atomic Rhythm") {
        return l10n.reachWeeklyPlaysTooltip(t.requiredMinutes);
      }
      return l10n.consecutivePlaysTooltip(t.requiredMinutes);
    }
    
    if (t.category == TitleCategory.competitive) {
      if (t.name == "Top 1 Global") return l10n.topGlobalTooltip(1);
      if (t.name == "Top 2 Global") return l10n.topGlobalTooltip(2);
      if (t.name == "Top 3 Global") return l10n.topGlobalTooltip(3);
    }
    
    if (t.category == TitleCategory.hallOfFame) {
      if (t.name == "Weekly Veteran") return l10n.top3GlobalTooltip(1);
      if (t.name == "Consistent Elite") return l10n.top3GlobalTooltip(5);
      if (t.name == "Five-Star Champion") return l10n.championChampionTooltip;
    }
    
    if (t.category == TitleCategory.exclusive) {
      if (t.name == "Developer") return l10n.developerExclusiveTooltip;
      if (t.name == "Contributor") return l10n.supportDeveloperTooltip;
    }

    return t.ruleDescription;
  }

  String _getProgressLabel(TitleDefinition t, int current, int required) {
    if (t.category == TitleCategory.competitive) {
      if (t.name == "Top 1 Global") return _userRank == 1 ? AppLocalizations.of(context)!.rankActive(1) : AppLocalizations.of(context)!.notRank(1);
      if (t.name == "Top 2 Global") return _userRank == 2 ? AppLocalizations.of(context)!.rankActive(2) : AppLocalizations.of(context)!.notRank(2);
      if (t.name == "Top 3 Global") return _userRank == 3 ? AppLocalizations.of(context)!.rankActive(3) : AppLocalizations.of(context)!.notRank(3);
      return AppLocalizations.of(context)!.notRanked;
    }
    if (t.category == TitleCategory.hallOfFame) {
      final unit = t.name == "Five-Star Champion" ? AppLocalizations.of(context)!.weeks : AppLocalizations.of(context)!.finishes;
      return "$current / $required $unit";
    }
    if (t.category == TitleCategory.behavior) {
      final unit = (t.name == "Binge Listener" || t.name == "Music Marathoner" || t.name == "Unstoppable Pulse" || t.name == "Atomic Rhythm") 
          ? AppLocalizations.of(context)!.plays 
          : AppLocalizations.of(context)!.repeats;
      return "$current / $required $unit";
    }
    return "$current / $required ${AppLocalizations.of(context)!.minsShortLabel}";
  }

  @override
  Widget build(BuildContext context) {
    final statsState = ref.watch(statsProvider);
    final profile = ref.watch(profileProvider);
    final calculatedLocal = StatsUtils.calculate(statsState);
    final totalMinutes = calculatedLocal.totalMinutes > (profile.cloudTotalMinutes ?? 0)
        ? calculatedLocal.totalMinutes
        : (profile.cloudTotalMinutes ?? 0);
    final dailyPlays = (calculatedLocal.dailyPlays > (profile.cloudDailyPlays ?? 0))
        ? calculatedLocal.dailyPlays
        : (profile.cloudDailyPlays ?? 0);
    final weeklyPlays = (calculatedLocal.weeklyPlays > (profile.cloudWeeklyPlays ?? 0))
        ? calculatedLocal.weeklyPlays
        : (profile.cloudWeeklyPlays ?? 0);
    final maxRepeatStreak = statsState.maxRepeatStreak > (profile.cloudMaxRepeatStreak ?? 0)
        ? statsState.maxRepeatStreak
        : (profile.cloudMaxRepeatStreak ?? 0);
    final userRole = profile.role;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final currentAuto = StatsUtils.getAutomaticTitle(totalMinutes, userRank: _userRank);

    int unlockedCount = 0;
    for (final t in StatsUtils.musicTitles) {
      if (StatsUtils.isTitleUnlocked(
        t,
        totalMinutes,
        maxRepeatStreak,
        userRank: _userRank,
        weeklyWins: statsState.weeklyWinsCount,
        weeklyPodiums: statsState.weeklyPodiumsCount,
        userRole: userRole,
        dailyPlays: dailyPlays,
        weeklyPlays: weeklyPlays,
        artistMinutes: calculatedLocal.artistMinutes,
      )) {
        unlockedCount++;
      }
    }
    final totalTitles = StatsUtils.musicTitles.length;

    // Group titles
    final Map<TitleCategory, List<TitleDefinition>> groupedTitles = {
      TitleCategory.time: [],
      TitleCategory.behavior: [],
      TitleCategory.competitive: [],
      TitleCategory.hallOfFame: [],
      TitleCategory.exclusive: [],
      TitleCategory.superfan: [],
    };
    for (final t in StatsUtils.musicTitles) {
      if (t.category == TitleCategory.exclusive) {
        if (t.name == "Developer") {
          // Developer title is strictly hidden unless you are a developer
          if (userRole == "developer") {
            groupedTitles[t.category]?.add(t);
          }
        } else if (t.name == "Contributor") {
          // Contributor appears for everyone (acts as a locked showcase for non-contributors)
          groupedTitles[t.category]?.add(t);
        } else {
          // Fallback parsing for the future
          groupedTitles[t.category]?.add(t);
        }
      } else {
        groupedTitles[t.category]?.add(t);
      }
    }

    // Determine which title to show in the info panel (preview)
    // 1. Determine which title to show in the info panel (preview)
    final TitleDefinition previewTitle = _previewIndex != null
        ? StatsUtils.musicTitles[_previewIndex!]
        : _findActiveDefinition(
            profile.selectedTitle, totalMinutes, maxRepeatStreak);

    // 2. Dynamic Artist Logic
    final List<String> eligibleArtists = [];
    if (previewTitle.isDynamic) {
        calculatedLocal.artistMinutes.forEach((artist, mins) {
            if (mins >= previewTitle.requiredMinutes) {
                eligibleArtists.add(artist);
            }
        });
        eligibleArtists.sort((a,b) => (calculatedLocal.artistMinutes[b] ?? 0).compareTo(calculatedLocal.artistMinutes[a] ?? 0));
        
        if (_selectedDynamicArtist == null && eligibleArtists.isNotEmpty) {
            _selectedDynamicArtist = eligibleArtists.first;
        }
    }
    
    final int? selectedDynamicArtistMinutes = _selectedDynamicArtist != null 
        ? calculatedLocal.artistMinutes[_selectedDynamicArtist] 
        : null;

    final String displayPreviewName = previewTitle.isDynamic && _selectedDynamicArtist != null 
        ? previewTitle.name.replaceFirst('[Artist]', StatsUtils.cleanArtistName(_selectedDynamicArtist!))
        : previewTitle.name;

    final bool previewUnlocked = StatsUtils.isTitleUnlocked(
      previewTitle,
      totalMinutes,
      maxRepeatStreak,
      userRank: _userRank,
      weeklyWins: statsState.weeklyWinsCount,
      weeklyPodiums: statsState.weeklyPodiumsCount,
      userRole: userRole,
      dailyPlays: dailyPlays,
      weeklyPlays: weeklyPlays,
      artistMinutes: calculatedLocal.artistMinutes,
    );

    final bool previewIsCurrentlyActive =
        profile.selectedTitle == displayPreviewName ||
            (profile.selectedTitle == null && currentAuto == displayPreviewName);

    final rawProgress = _getCategoryProgress(
      previewTitle,
      totalMinutes,
      maxRepeatStreak,
      statsState.currentRepeatStreak,
      statsState.weeklyWinsCount,
      statsState.weeklyPodiumsCount,
      dailyPlays,
      weeklyPlays,
      dynamicMinuteOverride: selectedDynamicArtistMinutes,
    );

    // NEW: If the title is already unlocked, always show it as completed (maxed out progress)
    // This ensures that "Repeat Offender" shows 50/50 once earned, even if the current song streak is 1.
    final currentProgress = previewUnlocked 
        ? previewTitle.requiredMinutes 
        : rawProgress;

    return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 800,
            height: 600,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.4),
        blurRadius: 40,
        spreadRadius: 10,
      ),
    ],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(32),
    child: Column(
      children: [
        // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.chooseYourTitle,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              AppLocalizations.of(context)!.unlockedCountLabel(unlockedCount, totalTitles),
                            style: TextStyle(
                              fontSize: 12,
                              color: accentColor.withValues(alpha: 0.7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                     ],
                   ),
                 ),
                 // Filter toggle row
                 Padding(
                   padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
                   child: Row(
                     children: [
                       SizedBox(
                         height: 24,
                         width: 24,
                         child: Checkbox(
                           value: _showUnlockedOnly,
                           onChanged: (v) => setState(() => _showUnlockedOnly = v ?? false),
                           activeColor: accentColor,
                           materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                           visualDensity: VisualDensity.compact,
                         ),
                       ),
                       const SizedBox(width: 6),
                       GestureDetector(
                         onTap: () => setState(() => _showUnlockedOnly = !_showUnlockedOnly),
                         child: Text(
                           AppLocalizations.of(context)!.showUnlockedOnly,
                           style: TextStyle(
                             fontSize: 11,
                             color: isDark ? Colors.grey[400] : Colors.grey[600],
                           ),
                         ),
                       ),
                     ],
                   ),
                 ),
                 const SizedBox(height: 8),

                // Two-panel body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT: Title List (Categorized)
                        Expanded(
                          flex: 4,
                          child: ListView(
                            // Shifted list to center with balanced padding
                            padding: const EdgeInsets.only(bottom: 80, top: 20, left: 8, right: 8),
                            children: [
                              if (groupedTitles[TitleCategory.exclusive]!.isNotEmpty)
                                _buildCategorySection(
                                  AppLocalizations.of(context)!.exclusiveTitlesHeader,
                                  groupedTitles[TitleCategory.exclusive]!,
                                  totalMinutes,
                                  maxRepeatStreak,
                                  statsState.weeklyWinsCount,
                                  statsState.weeklyPodiumsCount,
                                  profile,
                                  currentAuto,
                                  accentColor,
                                  TitleCategory.exclusive,
                                  dailyPlays,
                                  weeklyPlays,
                                  userRole: userRole,
                                  artistMinutes: calculatedLocal.artistMinutes,
                                ),
                              if (groupedTitles[TitleCategory.competitive]!.isNotEmpty)
                                _buildCategorySection(
                                  AppLocalizations.of(context)!.crownedChampionTitlesHeader,
                                  groupedTitles[TitleCategory.competitive]!,
                                  totalMinutes,
                                  maxRepeatStreak,
                                  statsState.weeklyWinsCount,
                                  statsState.weeklyPodiumsCount,
                                  profile,
                                  currentAuto,
                                  accentColor,
                                  TitleCategory.competitive,
                                  dailyPlays,
                                  weeklyPlays,
                                  artistMinutes: calculatedLocal.artistMinutes,
                                ),
                              if (groupedTitles[TitleCategory.hallOfFame]!.isNotEmpty)
                                _buildCategorySection(
                                  AppLocalizations.of(context)!.hallOfFameHeader,
                                  groupedTitles[TitleCategory.hallOfFame]!,
                                  totalMinutes,
                                  maxRepeatStreak,
                                  statsState.weeklyWinsCount,
                                  statsState.weeklyPodiumsCount,
                                  profile,
                                  currentAuto,
                                  accentColor,
                                  TitleCategory.hallOfFame,
                                  dailyPlays,
                                  weeklyPlays,
                                  artistMinutes: calculatedLocal.artistMinutes,
                                ),
                              if (groupedTitles[TitleCategory.time]!.isNotEmpty)
                                _buildCategorySection(
                                  AppLocalizations.of(context)!.timeOverlordsHeader,
                                  groupedTitles[TitleCategory.time]!,
                                  totalMinutes,
                                  maxRepeatStreak,
                                  statsState.weeklyWinsCount,
                                  statsState.weeklyPodiumsCount,
                                  profile,
                                  currentAuto,
                                  accentColor,
                                  TitleCategory.time,
                                  dailyPlays,
                                  weeklyPlays,
                                  artistMinutes: calculatedLocal.artistMinutes,
                                ),
                              if (groupedTitles[TitleCategory.behavior]!.isNotEmpty)
                                _buildCategorySection(
                                  AppLocalizations.of(context)!.behavioralHeader,
                                  groupedTitles[TitleCategory.behavior]!,
                                  totalMinutes,
                                  maxRepeatStreak,
                                  statsState.weeklyWinsCount,
                                  statsState.weeklyPodiumsCount,
                                  profile,
                                  currentAuto,
                                  accentColor,
                                  TitleCategory.behavior,
                                  dailyPlays,
                                  weeklyPlays,
                                  artistMinutes: calculatedLocal.artistMinutes,
                                ),
                              if (groupedTitles[TitleCategory.superfan]!.isNotEmpty)
                                _buildCategorySection(
                                  AppLocalizations.of(context)!.superfanHeader,
                                  groupedTitles[TitleCategory.superfan]!,
                                  totalMinutes,
                                  maxRepeatStreak,
                                  statsState.weeklyWinsCount,
                                  statsState.weeklyPodiumsCount,
                                  profile,
                                  currentAuto,
                                  accentColor,
                                  TitleCategory.superfan,
                                  dailyPlays,
                                  weeklyPlays,
                                  userRole: userRole,
                                  artistMinutes: calculatedLocal.artistMinutes,
                                ),
                            ],
                          ),
                        ),

                        // RIGHT: Info Panel
                        Expanded(
                          flex: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.05)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)!.preview,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                          letterSpacing: 2),
                                    ),
                                    const SizedBox(height: 32),
                                    SupremeTitleBadge.fromDefinition(
                                      previewTitle,
                                      displayName: displayPreviewName,
                                      isLocked: false,
                                      width: 200,
                                      height: 36,
                                    ),
                                    if (previewTitle.isDynamic && eligibleArtists.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Text(AppLocalizations.of(context)!.chooseArtist, 
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                                        const SizedBox(height: 8),
                                        Container(
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            decoration: BoxDecoration(
                                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                    value: _selectedDynamicArtist,
                                                    dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                                                    borderRadius: BorderRadius.circular(16),
                                                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
                                                    isExpanded: true,
                                                    style: TextStyle(
                                                        color: isDark ? Colors.white : Colors.black,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                    ),
                                                    items: eligibleArtists.map((artist) {
                                                        return DropdownMenuItem<String>(
                                                            value: artist,
                                                            child: Text(StatsUtils.cleanArtistName(artist)),
                                                        );
                                                    }).toList(),
                                                    onChanged: (val) {
                                                        if (val != null) setState(() => _selectedDynamicArtist = val);
                                                    },
                                                ),
                                            ),
                                        ),
                                    ],
                                    const SizedBox(height: 24),
                                    Text(
                                      _getLocalizedDescription(context, previewTitle),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _buildProgressRow(
                                        AppLocalizations.of(context)!.progress,
                                        () {
                                          if (previewTitle.category == TitleCategory.competitive) {
                                            if (_userRank == 1) return AppLocalizations.of(context)!.rankLabel(1);
                                            if (_userRank == 2) return AppLocalizations.of(context)!.rankLabel(2);
                                            if (_userRank == 3) return AppLocalizations.of(context)!.rankLabel(3);
                                            return AppLocalizations.of(context)!.notRankedTop3;
                                          }

                                          final cappedValue = currentProgress > previewTitle.requiredMinutes 
                                              ? previewTitle.requiredMinutes 
                                              : currentProgress;
                                          
                                          final String unit;
                                          if (previewTitle.category == TitleCategory.time || previewTitle.category == TitleCategory.superfan) {
                                            unit = AppLocalizations.of(context)!.minShortLabel;
                                          } else if (previewTitle.name == 'Binge Listener' || 
                                                     previewTitle.name == 'Music Marathoner' || 
                                                     previewTitle.name == 'Unstoppable Pulse' || 
                                                     previewTitle.name == 'Atomic Rhythm') {
                                            unit = AppLocalizations.of(context)!.plays;
                                          } else {
                                            unit = AppLocalizations.of(context)!.repeats;
                                          }

                                          return "$cappedValue / ${previewTitle.requiredMinutes} $unit";
                                        }(),
                                        isDark),
                                    const SizedBox(height: 12),
                                    _buildProgressBar(
                                        currentProgress, previewTitle.requiredMinutes, accentColor, isDark, previewTitle),
                                    const Spacer(),
                                    if (previewUnlocked && !previewIsCurrentlyActive)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            final finalTitle = previewTitle.isDynamic && _selectedDynamicArtist != null
                                                ? previewTitle.name.replaceFirst('[Artist]', StatsUtils.cleanArtistName(_selectedDynamicArtist!))
                                                : previewTitle.name;
                                            ref.read(profileProvider.notifier).updateTitle(finalTitle);
                                            Navigator.of(context).pop();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: accentColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                          ),
                                          child: Text(AppLocalizations.of(context)!.equipTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      )
                                    else if (previewIsCurrentlyActive)
                                      Center(
                                          child: Text(AppLocalizations.of(context)!.equipped,
                                              style: TextStyle(
                                                  color: accentColor, fontWeight: FontWeight.bold, letterSpacing: 2))),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: () {
                                        ref.read(profileProvider.notifier).updateTitle(null);
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(AppLocalizations.of(context)!.resetToAutomatic,
                                          style: TextStyle(
                                              color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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

  Widget _buildCategorySection(
    String header,
    List<TitleDefinition> titles,
    int totalMinutes,
    int maxRepeatStreak,
    int weeklyWins,
    int weeklyPodiums,
    dynamic profile,
    String currentAuto,
    Color accentColor,
    TitleCategory category,
    int dailyPlays,
    int weeklyPlays, {
    String? userRole,
    Map<String, int>? artistMinutes,
  }) {
    if (titles.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isElite = category == TitleCategory.competitive;
    final isExclusive = category == TitleCategory.exclusive;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;
    final double badgeWidth = screenWidth < 380 ? 120 : (screenWidth < 450 ? 130 : 140);

    final sectionContent = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
         Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               if ((isElite || isExclusive) && !Platform.isAndroid && !Platform.isIOS) ...[
                const CrownWidget(size: 14, color: Colors.amber),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  header,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isExclusive
                        ? const Color(0xFF7C4DFF)
                        : (isElite
                            ? Colors.amber
                            : (isDark ? Colors.grey[500] : Colors.grey[700])),
                    letterSpacing: (isElite || isExclusive) ? 2.5 : 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: isDesktop ? 34 : 16, // Give wide wings ample room on Desktop
          runSpacing: isDesktop ? 24 : 16,
          alignment: WrapAlignment.center,
          children: titles.where((title) {
            if (!_showUnlockedOnly) return true;
            return StatsUtils.isTitleUnlocked(
              title,
              totalMinutes,
              maxRepeatStreak,
              userRank: _userRank,
              weeklyWins: weeklyWins,
              weeklyPodiums: weeklyPodiums,
              userRole: userRole,
              dailyPlays: dailyPlays,
              weeklyPlays: weeklyPlays,
              artistMinutes: artistMinutes,
            );
          }).map((title) {
            final isUnlocked = StatsUtils.isTitleUnlocked(
              title,
              totalMinutes,
              maxRepeatStreak,
              userRank: _userRank,
              weeklyWins: weeklyWins,
              weeklyPodiums: weeklyPodiums,
              userRole: userRole,
              dailyPlays: dailyPlays,
              weeklyPlays: weeklyPlays,
              artistMinutes: artistMinutes,
            );
            final index = StatsUtils.musicTitles.indexOf(title);
            final isPreviewing = _previewIndex == index;
            final isActive = profile.selectedTitle == title.name ||
                (profile.selectedTitle == null && currentAuto == title.name);

            return InkWell(
              onTap: () => setState(() => _previewIndex = index),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPreviewing
                        ? accentColor
                        : (isActive
                            ? accentColor.withValues(alpha: 0.3)
                            : Colors.transparent),
                    width: 2,
                  ),
                ),
                child: SupremeTitleBadge.fromDefinition(
                  title,
                  displayName: title.isDynamic ? title.name.replaceFirst('[Artist]', AppLocalizations.of(context)!.artist) : null,
                  isLocked: !isUnlocked,
                  width: badgeWidth,
                  height: badgeWidth * (24/140), // Maintain aspect ratio
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );

    if (isElite || isExclusive) {
      final borderColor = isExclusive ? const Color(0xFF7C4DFF) : Colors.amber;
      final bgColor = isExclusive
          ? const Color(0xFF7C4DFF).withValues(alpha: isDark ? 0.08 : 0.04)
          : Colors.amber.withValues(alpha: isDark ? 0.08 : 0.04);
      final glowColor = isExclusive
          ? const Color(0xFF7C4DFF).withValues(alpha: 0.15)
          : Colors.amber.withValues(alpha: 0.15);

      return Container(
        margin: const EdgeInsets.fromLTRB(4, 12, 4, 32),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
              color: borderColor.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: glowColor,
              blurRadius: 30,
              spreadRadius: -10,
            ),
          ],
        ),
        child: sectionContent,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
      child: sectionContent,
    );
  }

  Widget _buildProgressRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black)),
      ],
    );
  }

  Widget _buildProgressBar(int current, int required, Color accentColor,
      bool isDark, TitleDefinition t) {
    final progress = required == 0 ? 1.0 : (current / required).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor:
                isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(_getProgressLabel(t, current, required),
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  TitleDefinition _findActiveDefinition(
      String? activeTitle, int totalMinutes, int maxRepeatStreak) {
    if (activeTitle != null) {
      for (final t in StatsUtils.musicTitles) {
        if (t.name == activeTitle) return t;
      }
    }
    // Fall back to automatic time overlord titles
    for (final t in StatsUtils.musicTitles.reversed) {
      if (t.category == TitleCategory.time && totalMinutes >= t.requiredMinutes)
      {
        return t;
      }
    }
    return StatsUtils.musicTitles.first;
  }
}
