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
  });

  // Factory constructor for creating from file scan
  factory SongModel.fromFile(
    String path,
    String title,
    String artist,
    String album,
    double duration,
    String extension,
    Uint8List? artwork,
  ) {
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
      // Note: We don't save albumArtBytes to JSON as it's too heavy.
      // We rely on reloading it from file or URL.
    };
  }

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      title: json['title'] ?? "Unknown Title",
      artist: json['artist'] ?? "Unknown Artist",
      album: json['album'] ?? "Unknown Album",
      filePath: json['filePath'] ?? "",
      fileExtension: json['fileExtension'] ?? "",
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      sourceUrl: json['sourceUrl'],
      onlineArtUrl: json['onlineArtUrl'],
      albumArtBytes: null, // Will be loaded lazily if needed
    );
  }
}
