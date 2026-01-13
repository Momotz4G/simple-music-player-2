import '../models/song_metadata.dart';

/// Represents a personalized daily mix generated from user's listening history
class DailyMix {
  final String id;
  final String title;
  final String description;
  final List<SongMetadata> songs;
  final DateTime generatedAt;
  final List<String> seedArtists; // Artist names used for seeding

  DailyMix({
    required this.id,
    required this.title,
    required this.description,
    required this.songs,
    required this.generatedAt,
    required this.seedArtists,
  });

  /// Check if mix is stale (different calendar day)
  /// Uses Server Time (GMT+7) as reference
  bool get isStale {
    final serverNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    return serverNow.day != generatedAt.day ||
        serverNow.month != generatedAt.month ||
        serverNow.year != generatedAt.year;
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'songs': songs
          .map((s) => {
                'title': s.title,
                'artist': s.artist,
                'album': s.album,
                'albumArtUrl': s.albumArtUrl,
                'durationSeconds': s.durationSeconds,
                'year': s.year,
                'genre': s.genre,
                'spotifyId': s.spotifyId,
                'isrc': s.isrc,
              })
          .toList(),
      'generatedAt': generatedAt.toIso8601String(),
      'seedArtists': seedArtists,
    };
  }

  /// Create from cached JSON
  factory DailyMix.fromJson(Map<String, dynamic> json) {
    return DailyMix(
      id: json['id'] ?? 'daily_mix',
      title: json['title'] ?? 'You May Like',
      description: json['description'] ?? '',
      songs: (json['songs'] as List? ?? [])
          .map((s) => SongMetadata(
                title: s['title'] ?? '',
                artist: s['artist'] ?? '',
                album: s['album'] ?? '',
                albumArtUrl: s['albumArtUrl'] ?? '',
                durationSeconds: s['durationSeconds'] ?? 0,
                year: s['year'] ?? '',
                genre: s['genre'] ?? '',
                spotifyId: s['spotifyId'],
                isrc: s['isrc'],
              ))
          .toList(),
      generatedAt:
          DateTime.tryParse(json['generatedAt'] ?? '') ?? DateTime.now(),
      seedArtists: List<String>.from(json['seedArtists'] ?? []),
    );
  }
}
