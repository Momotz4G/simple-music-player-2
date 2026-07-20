class DownloadProgress {
  final double receivedMB;
  final double totalMB;
  final double progress;
  final String status;
  final String? details;
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
