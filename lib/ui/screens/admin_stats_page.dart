import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/metrics_service.dart';

class AdminStatsPage extends StatelessWidget {
  final String role; // 'admin' or 'viewer'

  const AdminStatsPage({super.key, required this.role});

  bool get isAdmin => role == 'admin';

  // Helper to safely parse timestamp (Handles String or generic dynamic)
  DateTime? _parseTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return null;
  }

  // Helper to format date
  String _formatDate(DateTime? date) {
    if (date == null) return "Never";
    return "${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? "Admin Dashboard" : "Dashboard (View Only)"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 24.0),
              child: _ServerClockWidget(),
            ),
          )
        ],
      ),
      body: StreamBuilder<List<AdminUserData>>(
        stream: MetricsService().getAllUserMetrics(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            // return const Center(child: CircularProgressIndicator());
            // Return empty container or loading if strict waiting, but stream might be instant empty.
          }

          final docs = snapshot.data ?? [];
          if (docs.isEmpty) {
            return const Center(
                child: Text("No user data found (PocketBase Mode)."));
          }

          // 🚀 METRICS AGGREGATION
          final totalUsers = docs.length;
          final activeUsers = docs.where((user) {
            final timestamp = _parseTimestamp(user.data['last_active']);
            if (timestamp == null) return false;
            return DateTime.now().difference(timestamp).inMinutes < 2;
          }).length;

          return Column(
            children: [
              // 🚀 SUMMARY DETAILS
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    _buildSummaryCard(context, "Total Users",
                        totalUsers.toString(), Icons.people),
                    const SizedBox(width: 16),
                    _buildSummaryCard(context, "Active Now",
                        activeUsers.toString(), Icons.circle,
                        color: Colors.green),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('#')), // NUMBER COLUMN
                        DataColumn(label: Text('User ID')),
                        DataColumn(label: Text('Total Plays')),
                        DataColumn(label: Text('Daily Plays')),
                        DataColumn(label: Text('Downloads')),
                        DataColumn(
                            label: Text('Quota Left')), //  QUOTA REMAINING
                        DataColumn(label: Text('Last Active')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: List.generate(docs.length, (index) {
                        final user = docs[index];
                        final data = user.data;
                        final isBanned = data['is_banned'] == true;

                        // QUOTA LOGIC
                        final lastDate =
                            _parseTimestamp(data['last_download_date']);
                        final now = DateTime.now();
                        final isToday = lastDate != null &&
                            lastDate.day == now.day &&
                            lastDate.month == now.month &&
                            lastDate.year == now.year;
                        final dailyUsage =
                            isToday ? (data['daily_download_count'] ?? 0) : 0;
                        final remaining = (50 - dailyUsage).clamp(0, 50);

                        // DAILY PLAYS LOGIC
                        final lastPlayDate =
                            _parseTimestamp(data['last_play_date']);
                        final isPlayToday = lastPlayDate != null &&
                            lastPlayDate.day == now.day &&
                            lastPlayDate.month == now.month &&
                            lastPlayDate.year == now.year;
                        final dailyPlays =
                            isPlayToday ? (data['daily_play_count'] ?? 0) : 0;

                        return DataRow(cells: [
                          DataCell(Text((index + 1).toString())), // ROW NUMBER
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.computer,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(data['hostname'] ?? "Unknown Device",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11)),
                                    Text(user.id.substring(0, 8),
                                        style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 10,
                                            color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text((data['play_count'] ?? 0).toString())),
                          DataCell(Text(dailyPlays.toString())), // Daily Plays
                          DataCell(
                              Text((data['download_count'] ?? 0).toString())),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "$remaining / 50",
                                  style: TextStyle(
                                      color: remaining < 5
                                          ? Colors.red
                                          : Colors.green[700],
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                // Reset Quota Button
                                // Admin: can reset anyone
                                // Viewer: can only reset their own (matching user_id)
                                Builder(builder: (context) {
                                  final currentUserId = MetricsService().userId;
                                  final isOwnDevice = user.id == currentUserId;
                                  final canReset = isAdmin || isOwnDevice;

                                  if (!canReset) return const SizedBox.shrink();

                                  return IconButton(
                                    icon: const Icon(Icons.refresh, size: 16),
                                    tooltip: isOwnDevice
                                        ? "Reset My Quota"
                                        : "Reset User Quota",
                                    splashRadius: 20,
                                    onPressed: () {
                                      MetricsService()
                                          .adminAction(user.id, 'reset_quota');
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(isOwnDevice
                                                ? "✅ Your quota has been reset!"
                                                : "Quota Reset!"),
                                            duration:
                                                const Duration(seconds: 1)),
                                      );
                                    },
                                  );
                                }),
                              ],
                            ),
                          ),
                          DataCell(
                            Builder(builder: (context) {
                              final timestamp =
                                  _parseTimestamp(data['last_active']);
                              if (timestamp == null) return const Text("Never");

                              final isOnline = DateTime.now()
                                      .difference(timestamp)
                                      .inMinutes <
                                  2;

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isOnline) ...[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(isOnline
                                      ? "Online"
                                      : _formatDate(timestamp)),
                                ],
                              );
                            }),
                          ),

                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Ban/Unban Button - Admin Only
                                if (isAdmin)
                                  IconButton(
                                    icon: Icon(
                                        isBanned
                                            ? Icons
                                                .settings_backup_restore_rounded
                                            : Icons.remove_circle_outline,
                                        color: isBanned
                                            ? Colors.green
                                            : Colors.red),
                                    tooltip:
                                        isBanned ? "Unban User" : "Ban User",
                                    onPressed: () {
                                      // Toggle Ban
                                      MetricsService().adminAction(
                                          user.id, isBanned ? 'unban' : 'ban');

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(isBanned
                                                ? "✅ User Unbanned"
                                                : "⛔ User Banned")),
                                      );
                                    },
                                  ),
                                // Delete Button - Admin Only
                                if (isAdmin)
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.grey),
                                    tooltip: "Delete User",
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Delete User?"),
                                          content: const Text(
                                              "This will remove their history and limits from the cloud. Usage stats will reset."),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx)
                                                        .pop(false),
                                                child: const Text("Cancel")),
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: const Text("Delete",
                                                    style: TextStyle(
                                                        color: Colors.red))),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        // Pass both user_id and record ID
                                        MetricsService().adminAction(
                                          user.id,
                                          'delete',
                                          recordId: data['id'],
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text("🗑️ User Deleted"),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                // Show message for viewers
                                if (!isAdmin)
                                  const Text(
                                    "View Only",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ]);
                      }),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, String title, String value, IconData icon,
      {Color? color}) {
    return Expanded(
      child: Card(
        elevation: 2,
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon,
                  size: 24, color: color ?? Theme.of(context).iconTheme.color),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

// Isolated Widget to prevent full page rebuilds every second
class _ServerClockWidget extends StatefulWidget {
  const _ServerClockWidget();

  @override
  State<_ServerClockWidget> createState() => _ServerClockWidgetState();
}

class _ServerClockWidgetState extends State<_ServerClockWidget> {
  late Timer _timer;
  DateTime _serverTime = DateTime.now().toUtc().add(const Duration(hours: 7));

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _serverTime = DateTime.now().toUtc().add(const Duration(hours: 7));
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time_rounded, size: 16),
          const SizedBox(width: 8),
          Text(
            "Server Time: ${DateFormat('yyyy-MM-dd : HH-mm-ss').format(_serverTime)}", // 🚀 GMT+7
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
