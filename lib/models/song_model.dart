import 'dart:typed_data';

class SongModel {
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final String fileExtension;
  final double duration;
  final Uint8List? albumArtBytes; // Kept for legacy support if needed

  // NEW FIELDS FOR HYBRID HISTORY
  final String? sourceUrl; // Stores the YouTube URL (for re-streaming)
  final String?
      onlineArtUrl; // Stores the Spotify Image URL (for display when file is missing)
  final String? isrc; // Stores ISRC for accurate matching

  // NEW METADATA FIELDS
  final int? trackNumber;
  final int? discNumber;
  final String? year;
  final String? genre;

  // SPOTIFY IDS FOR ENDLESS QUEUE
  final String? spotifyId; // Spotify track ID for recommendations
  final String? spotifyArtistId; // Spotify artist ID for recommendations
  final String? deezerId; // 🚀 Deezer track ID for direct FLAC match
  final DateTime? dateAdded; // 🚀 Follows Isar 'Song' dateAdded

  SongModel({
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    required this.fileExtension,
    required this.duration,
    this.albumArtBytes,
    this.sourceUrl,
    this.onlineArtUrl,
    this.isrc,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.genre,
    this.spotifyId,
    this.spotifyArtistId,
    this.deezerId,
    this.dateAdded,
  });

  // Factory constructor for creating from file scan
  factory SongModel.fromFile(
    String path,
    String title,
    String artist,
    String album,
    double duration,
    String extension,
    Uint8List? artwork, {
    int? trackNumber,
    int? discNumber,
    String? year,
    String? genre,
    DateTime? dateAdded,
  }) {
    return SongModel(
      title: title,
      artist: artist,
      album: album,
      filePath: path,
      fileExtension: extension,
      duration: duration,
      albumArtBytes: artwork,
      sourceUrl: null,
      onlineArtUrl: null,
      isrc: null,
      trackNumber: trackNumber,
      discNumber: discNumber,
      year: year,
      genre: genre,
      dateAdded: dateAdded,
      // deezerId is naturally null for local files
    );
  }

  SongModel copyWith({
    String? title,
    String? artist,
    String? album,
    String? filePath,
    String? fileExtension,
    double? duration,
    Uint8List? albumArtBytes,
    String? sourceUrl,
    String? onlineArtUrl,
    String? isrc,
    int? trackNumber,
    int? discNumber,
    String? year,
    String? genre,
    String? spotifyId,
    String? spotifyArtistId,
    String? deezerId,
    DateTime? dateAdded,
  }) {
    return SongModel(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      filePath: filePath ?? this.filePath,
      fileExtension: fileExtension ?? this.fileExtension,
      duration: duration ?? this.duration,
      albumArtBytes: albumArtBytes ?? this.albumArtBytes,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      onlineArtUrl: onlineArtUrl ?? this.onlineArtUrl,
      isrc: isrc ?? this.isrc,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      spotifyId: spotifyId ?? this.spotifyId,
      spotifyArtistId: spotifyArtistId ?? this.spotifyArtistId,
      deezerId: deezerId ?? this.deezerId,
      dateAdded: dateAdded ?? this.dateAdded,
    );
  }

  // JSON SERIALIZATION FOR PERSISTENCE
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'filePath': filePath,
      'fileExtension': fileExtension,
      'duration': duration,
      'sourceUrl': sourceUrl,
      'onlineArtUrl': onlineArtUrl,
      'isrc': isrc,
      'trackNumber': trackNumber,
      'discNumber': discNumber,
      'year': year,
      'genre': genre,
      'spotifyId': spotifyId,
      'spotifyArtistId': spotifyArtistId,
      'deezerId': deezerId,
      'dateAdded': dateAdded?.toIso8601String(),
      // Note: We don't save albumArtBytes to JSON as it's too heavy.
      // We rely on reloading it from file or URL.
    };
  }

  factory SongModel.fromJson(Map<String, dynamic> json) {
    // Handle duration: convert 'durationSeconds' (int) or 'duration' (num) to double
    double parsedDuration = 0.0;
    if (json['duration'] != null) {
      parsedDuration = (json['duration'] as num).toDouble();
    } else if (json['durationSeconds'] != null) {
      parsedDuration = (json['durationSeconds'] as num).toDouble();
    }

    return SongModel(
      title: json['title'] ?? "Unknown Title",
      artist: json['artist'] ?? "Unknown Artist",
      album: json['album'] ?? "Unknown Album",
      filePath: json['filePath'] ??
          "cloud_stream", // Default to cloud_stream if missing (for remote adds)
      fileExtension: json['fileExtension'] ?? "mp3",
      duration: parsedDuration,
      sourceUrl: json['sourceUrl'],
      onlineArtUrl: json['onlineArtUrl'] ??
          json['albumArtUrl'], // Fallback for SongMetadata
      albumArtBytes: null, // Will be loaded lazily if needed
      isrc: json['isrc'],
      trackNumber: json['trackNumber'],
      discNumber: json['discNumber'],
      year: json['year'],
      genre: json['genre'],
      spotifyId: json['spotifyId'],
      spotifyArtistId: json['spotifyArtistId'],
      deezerId: json['deezerId'],
      dateAdded: json['dateAdded'] != null
          ? DateTime.tryParse(json['dateAdded'])
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SongModel &&
        other.title == title &&
        other.artist == artist &&
        other.album == album &&
        other.filePath == filePath;
  }

  @override
  int get hashCode {
    return title.hashCode ^
        artist.hashCode ^
        album.hashCode ^
        filePath.hashCode;
  }
}
