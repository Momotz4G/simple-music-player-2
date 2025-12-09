class YoutubeSearchResult {
  final String title;
  final String artist;
  final String duration;
  final String url; // The confirmed YouTube URL for download
  final String thumbnailUrl; // URL for the thumbnail image

  YoutubeSearchResult({
    required this.title,
    required this.artist,
    required this.duration,
    required this.url,
    required this.thumbnailUrl,
  });
}
