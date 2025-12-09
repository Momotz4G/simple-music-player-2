import 'dart:convert';
import 'dart:typed_data';

class StatEntry {
  final String id; // Unique ID (Hash of Title+Artist)
  final String title;
  final String artist;
  final String album;
  final int playCount;
  final int totalSeconds;
  // We DON'T save the image bytes to disk (too heavy/slow).
  // We save the path, but if the file is missing, we just show a placeholder.
  final String lastKnownPath;
  final String? onlineArtUrl;
  final String? youtubeUrl;

  StatEntry({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.playCount,
    required this.totalSeconds,
    required this.lastKnownPath,
    this.onlineArtUrl,
    this.youtubeUrl,
  });

  // Generate a unique ID based on metadata, not file path
  static String generateId(String title, String artist, String album) {
    // Simple sanitization to create a key
    final raw = "$title|$artist|$album".toLowerCase().trim();
    return base64Encode(utf8.encode(raw)); // Basic hash
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'playCount': playCount,
      'totalSeconds': totalSeconds,
      'lastKnownPath': lastKnownPath,
      'onlineArtUrl': onlineArtUrl,
      'youtubeUrl': youtubeUrl,
    };
  }

  factory StatEntry.fromJson(Map<String, dynamic> json) {
    return StatEntry(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown',
      artist: json['artist'] ?? 'Unknown',
      album: json['album'] ?? 'Unknown',
      playCount: json['playCount'] ?? 0,
      totalSeconds: json['totalSeconds'] ?? 0,
      lastKnownPath: json['lastKnownPath'] ?? '',
      onlineArtUrl: json['onlineArtUrl'],
      youtubeUrl: json['youtubeUrl'],
    );
  }

  StatEntry copyWith({
    int? playCount,
    int? totalSeconds,
    String? lastKnownPath,
    String? onlineArtUrl,
    String? youtubeUrl,
  }) {
    return StatEntry(
      id: id,
      title: title,
      artist: artist,
      album: album,
      playCount: playCount ?? this.playCount,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      lastKnownPath: lastKnownPath ?? this.lastKnownPath,
      onlineArtUrl: onlineArtUrl ?? this.onlineArtUrl,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
    );
  }
}
