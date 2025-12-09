import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminStatsPage extends StatelessWidget {
  const AdminStatsPage({super.key});

  // Helper to format date
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Never";
    final date = timestamp.toDate();
    return "${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('metrics').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No user data found."));
          }

          // 🚀 METRICS AGGREGATION
          final totalUsers = docs.length;
          final activeUsers = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['last_active'] as Timestamp?;
            if (timestamp == null) return false;
            return DateTime.now().difference(timestamp.toDate()).inMinutes < 2;
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
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final isBanned = data['is_banned'] == true;

                        // QUOTA LOGIC
                        final lastDate =
                            (data['last_download_date'] as Timestamp?)
                                ?.toDate();
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
                            (data['last_play_date'] as Timestamp?)?.toDate();
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
                                    Text(doc.id.substring(0, 8),
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
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 16),
                                  tooltip: "Reset Daily Quota",
                                  splashRadius: 20,
                                  onPressed: () {
                                    FirebaseFirestore.instance
                                        .collection('metrics')
                                        .doc(doc.id)
                                        .set({'daily_download_count': 0},
                                            SetOptions(merge: true));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text("Quota Reset!"),
                                          duration: Duration(seconds: 1)),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Builder(builder: (context) {
                              final timestamp =
                                  data['last_active'] as Timestamp?;
                              if (timestamp == null) return const Text("Never");

                              final lastActive = timestamp.toDate();
                              final isOnline = DateTime.now()
                                      .difference(lastActive)
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
                                IconButton(
                                  icon: Icon(
                                      isBanned
                                          ? Icons
                                              .settings_backup_restore_rounded // Restore (Unban)
                                          : Icons
                                              .remove_circle_outline, // Ban Action
                                      color:
                                          isBanned ? Colors.green : Colors.red),
                                  tooltip: isBanned ? "Unban User" : "Ban User",
                                  onPressed: () {
                                    // Toggle Ban
                                    FirebaseFirestore.instance
                                        .collection('metrics')
                                        .doc(doc.id)
                                        .set({'is_banned': !isBanned},
                                            SetOptions(merge: true));

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(isBanned
                                              ? "✅ User Unbanned"
                                              : "⛔ User Banned")),
                                    );
                                  },
                                ),
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
                                                  Navigator.of(ctx).pop(false),
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
                                      await FirebaseFirestore.instance
                                          .collection('metrics')
                                          .doc(doc.id)
                                          .delete();
                                    }
                                  },
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
