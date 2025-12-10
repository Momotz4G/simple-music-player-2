class SongMetadata {
  final String title;
  final String artist;
  final String album;
  final String? year;
  final String? genre;
  final int? trackNumber;
  final int? discNumber;
  final int durationSeconds;
  final String albumArtUrl;
  final String? isrc; // New field

  SongMetadata({
    required this.title,
    required this.artist,
    required this.album,
    this.year,
    this.genre,
    this.trackNumber,
    this.discNumber,
    required this.durationSeconds,
    required this.albumArtUrl,
    this.isrc,
  });

  SongMetadata copyWith({
    String? title,
    String? artist,
    String? album,
    String? year,
    String? genre,
    int? trackNumber,
    int? discNumber,
    int? durationSeconds,
    String? albumArtUrl,
    String? isrc,
  }) {
    return SongMetadata(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      isrc: isrc ?? this.isrc,
    );
  }
}
