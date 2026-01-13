class DownloadProgress {
  final double receivedMB;
  final double totalMB;
  final double progress; // 0.0 to 1.0
  final String status;
  final String? details; // For "6 of 20 Songs"
  final double? speedMBps; // Download speed in MB/s

  DownloadProgress({
    required this.receivedMB,
    required this.totalMB,
    required this.progress,
    required this.status,
    this.details,
    this.speedMBps,
  });
}
