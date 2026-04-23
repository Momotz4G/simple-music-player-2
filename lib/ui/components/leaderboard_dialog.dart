import 'package:flutter/material.dart';
import '../../services/pocketbase_service.dart';
import '../../utils/stats_utils.dart';

class LeaderboardDialog extends StatefulWidget {
  const LeaderboardDialog({super.key});

  @override
  State<LeaderboardDialog> createState() => _LeaderboardDialogState();
}

class _LeaderboardDialogState extends State<LeaderboardDialog> {
  int _selectedTab = 2; // 0: Daily, 1: Weekly, 2: All-Time
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboardData = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    String sortBy = 'play_count';
    String? filter = 'nickname != ""';

    if (_selectedTab == 0) {
      sortBy = 'daily_play_count';
      filter = '$filter && last_play_date >= "${StatsUtils.getStartOfTodayGMT7()}"';
    } else if (_selectedTab == 1) {
      sortBy = 'weekly_play_count';
      filter = '$filter && last_play_date >= "${StatsUtils.getStartOfWeekGMT7()}"';
    }

    try {
      final records = await PocketBaseService().fetchLeaderboard(sortBy: sortBy, limit: 150, filter: filter);
      
      // Deduplicate locally using user_id, and filter out 0 metric users
      final seenUsers = <String>{};
      final filtered = <Map<String, dynamic>>[];
      for (final r in records) {
         final count = r[sortBy] ?? 0;
         if (count <= 0) continue; 
         
         // 🚀 EXCLUDE USERS WHO HAVEN'T SET A NICKNAME
         final rawNick = r['nickname'] as String?;
         if (rawNick == null || rawNick.trim().isEmpty) continue;
         
         final uId = r['user_id'] as String?;
         if (uId != null && uId.isNotEmpty) {
            if (!seenUsers.contains(uId)) {
               seenUsers.add(uId);
               filtered.add(r);
            }
         } else {
            filtered.add(r);
         }
      }

      if (mounted) {
        setState(() {
          _leaderboardData = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load leaderboard. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onTabChanged(int index) {
    if (_selectedTab == index) return;
    setState(() {
      _selectedTab = index;
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

  Widget _buildUnifiedTabs(Color accentColor, bool isDark) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.15);
    final highlightColor = Colors.white.withValues(alpha: isDark ? 0.07 : 0.5);

    Widget buildTab(int index, String label) {
      final isSelected = _selectedTab == index;
      final radius = BorderRadius.only(
        topLeft: index == 0 ? const Radius.circular(11) : Radius.zero,
        topRight: index == 2 ? const Radius.circular(11) : Radius.zero,
      );

      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _onTabChanged(index),
          hoverColor: Colors.white.withValues(alpha: isDark ? 0.05 : 0.15),
          splashColor: Colors.white.withValues(alpha: isDark ? 0.1 : 0.2),
          borderRadius: radius,
          mouseCursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? highlightColor : Colors.transparent,
              borderRadius: radius,
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? accentColor
                    : (isDark ? Colors.grey[500]! : Colors.grey[500]!),
              ),
              child: Text(label),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1.0),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildTab(0, "Daily"),
              VerticalDivider(width: 1, thickness: 1, color: borderColor),
              buildTab(1, "Weekly"),
              VerticalDivider(width: 1, thickness: 1, color: borderColor),
              buildTab(2, "All-Time"),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return FocusScope(
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
           width: 480,
           height: 700,
           decoration: BoxDecoration(
             color: Theme.of(context).cardColor.withValues(alpha: 0.95),
             borderRadius: BorderRadius.circular(24),
             boxShadow: [
               BoxShadow(
                 color: Colors.black.withValues(alpha: 0.2),
                 blurRadius: 20,
                 spreadRadius: 2,
               ),
             ],
             border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
             ),
           ),
           child: Column(
             children: [
               // Header
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                 decoration: BoxDecoration(
                   border: Border(
                     bottom: BorderSide(
                       color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                     ),
                   ),
                 ),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Row(
                       children: [
                         const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                         const SizedBox(width: 12),
                         const Text(
                           "Global Leaderboard",
                           style: TextStyle(
                             fontSize: 20,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                       ],
                     ),
                     IconButton(
                       onPressed: () => Navigator.of(context).pop(),
                       icon: const Icon(Icons.close_rounded),
                       splashRadius: 24,
                     ),
                   ],
                 ),
               ),

               // Tabs
               Padding(
                 padding: const EdgeInsets.only(top: 20, bottom: 12),
                 child: _buildUnifiedTabs(accentColor, isDark),
               ),

               // Body List
               Expanded(
                 child: _isLoading 
                   ? const Center(child: CircularProgressIndicator())
                   : _error.isNotEmpty
                      ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                      : _leaderboardData.isEmpty
                          ? Center(
                              child: Text(
                                "No rankings yet for this timeframe.",
                                style: TextStyle(
                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _leaderboardData.length,
                              itemBuilder: (context, index) {
                                final row = _leaderboardData[index];
                                final rawNick = row['nickname'] as String?;
                                final rawHost = row['hostname'] as String?;
                                final name = (rawNick != null && rawNick.trim().isNotEmpty) 
                                    ? rawNick.trim() 
                                    : ((rawHost != null && rawHost.trim().isNotEmpty) ? rawHost.trim() : 'Unknown User');
                                
                                String sortBy = 'play_count';
                                if (_selectedTab == 0) sortBy = 'daily_play_count';
                                if (_selectedTab == 1) sortBy = 'weekly_play_count';
                                
                                final playCount = row[sortBy] ?? 0;

                                Color? rankColor;
                                if (index == 0) rankColor = const Color(0xFFFFD700); // Gold
                                if (index == 1) rankColor = const Color(0xFFC0C0C0); // Silver
                                if (index == 2) rankColor = const Color(0xFFCD7F32); // Bronze

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: (index < 3) 
                                        ? rankColor?.withValues(alpha: 0.1) 
                                        : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: (index < 3) 
                                          ? rankColor!.withValues(alpha: 0.5) 
                                          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          constraints: const BoxConstraints(minWidth: 40),
                                          child: Text(
                                            "#${index + 1}",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: rankColor ?? (isDark ? Colors.grey[400] : Colors.grey[600]),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: rankColor?.withValues(alpha: 0.3) ?? accentColor.withValues(alpha: 0.2),
                                          backgroundImage: PocketBaseService().getAvatarUrl(row) != null
                                              ? NetworkImage(PocketBaseService().getAvatarUrl(row)!)
                                              : null,
                                          child: PocketBaseService().getAvatarUrl(row) == null
                                              ? Text(
                                                  _getInitials(name),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: rankColor ?? accentColor,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                    title: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: (index == 0) ? rankColor : null,
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: rankColor?.withValues(alpha: 0.2) ?? accentColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.play_arrow_rounded, 
                                            size: 14, 
                                            color: rankColor ?? accentColor
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            playCount.toString(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: rankColor ?? accentColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
               ),
             ],
           ),
        ),
      ),
    );
  }
}
