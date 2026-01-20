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
  final String? isrc; // International Standard Recording Code
  final String? spotifyId; // Spotify track ID for FLAC matching
  final String? spotifyArtistId; // Spotify artist ID for recommendations
  final String? deezerId; // Deezer track ID for direct FLAC match

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
    this.spotifyId,
    this.spotifyArtistId,
    this.deezerId,
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
    String? spotifyId,
    String? spotifyArtistId,
    String? deezerId,
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
      spotifyId: spotifyId ?? this.spotifyId,
      spotifyArtistId: spotifyArtistId ?? this.spotifyArtistId,
      deezerId: deezerId ?? this.deezerId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'year': year,
      'genre': genre,
      'trackNumber': trackNumber,
      'discNumber': discNumber,
      'durationSeconds': durationSeconds,
      'albumArtUrl': albumArtUrl,
      'isrc': isrc,
      'spotifyId': spotifyId,
      'spotifyArtistId': spotifyArtistId,
      'deezerId': deezerId,
    };
  }
}
