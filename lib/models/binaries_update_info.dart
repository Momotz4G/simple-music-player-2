/// Model for yt-dlp binaries update information (Desktop only)
class BinariesUpdateInfo {
  final String latestVersion;
  final String? currentVersion;
  final String downloadUrl;
  final int sizeBytes;

  const BinariesUpdateInfo({
    required this.latestVersion,
    this.currentVersion,
    required this.downloadUrl,
    required this.sizeBytes,
  });

  /// File size in MB (human-readable)
  String get sizeMB => (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
}
