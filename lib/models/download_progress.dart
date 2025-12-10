class DownloadProgress {
  final double receivedMB;
  final double totalMB;
  final double progress; // 0.0 to 1.0
  final String status;
  final String? details; // NEW: For "6 of 20 Songs"

  DownloadProgress({
    required this.receivedMB,
    required this.totalMB,
    required this.progress,
    required this.status,
    this.details,
  });
}
