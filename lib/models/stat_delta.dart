import 'package:simple_music_player_2/models/stat_model.dart';

/// Represents an incremental change to a per-song stat record,
/// to be synced to the cloud via the SyncEngine.
class StatDelta {
  /// UUID for this delta
  final String id;

  /// base64 hash of title|artist|album (matches StatEntry.generateId)
  final String statId;

  final String title;
  final String artist;
  final String album;

  /// Incremental play count change (+1 per play)
  final int playCountDelta;

  /// Incremental seconds added since last sync
  final int totalSecondsDelta;

  /// When the change occurred
  final DateTime timestamp;

  /// Hardware-derived device ID
  final String deviceId;

  /// Optional Spotify track ID
  final String? spotifyId;

  /// Optional Deezer track ID
  final String? deezerId;

  /// Optional album art URL (for cross-device sharing)
  final String? onlineArtUrl;

  StatDelta({
    required this.id,
    required this.statId,
    required this.title,
    required this.artist,
    required this.album,
    required this.playCountDelta,
    required this.totalSecondsDelta,
    required this.timestamp,
    required this.deviceId,
    this.spotifyId,
    this.deezerId,
    this.onlineArtUrl,
  });

  /// Generates a stat ID using the same logic as [StatEntry.generateId].
  /// Base64 encoding of `title|artist|album` (lowercased and trimmed).
  static String generateStatId(String title, String artist, String album) {
    return StatEntry.generateId(title, artist, album);
  }

  /// Computes the delta between a current [StatEntry] and its last-synced state.
  ///
  /// The delta represents the incremental changes since the last successful sync:
  /// - playCountDelta = current.playCount - lastSynced.playCount
  /// - totalSecondsDelta = current.totalSeconds - lastSynced.totalSeconds
  ///
  /// Both deltas are guaranteed non-negative when current >= lastSynced.
  static StatDelta computeDelta({
    required StatEntry current,
    required StatEntry lastSynced,
    required String deltaId,
    required String deviceId,
  }) {
    return StatDelta(
      id: deltaId,
      statId: current.id,
      title: current.title,
      artist: current.artist,
      album: current.album,
      playCountDelta: current.playCount - lastSynced.playCount,
      totalSecondsDelta: current.totalSeconds - lastSynced.totalSeconds,
      timestamp: DateTime.now(),
      deviceId: deviceId,
      spotifyId: current.spotifyId,
      deezerId: current.deezerId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stat_id': statId,
      'title': title,
      'artist': artist,
      'album': album,
      'play_count_delta': playCountDelta,
      'total_seconds_delta': totalSecondsDelta,
      'timestamp': timestamp.toIso8601String(),
      'device_id': deviceId,
      'spotify_id': spotifyId,
      'deezer_id': deezerId,
      'online_art_url': onlineArtUrl,
    };
  }

  factory StatDelta.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null || (json['id'] as String).isEmpty) {
      throw ArgumentError(
          'StatDelta.fromJson: "id" is required and must be non-empty');
    }
    if (json['stat_id'] == null || (json['stat_id'] as String).isEmpty) {
      throw ArgumentError(
          'StatDelta.fromJson: "stat_id" is required and must be non-empty');
    }
    if (json['title'] == null) {
      throw ArgumentError('StatDelta.fromJson: "title" is required');
    }
    if (json['artist'] == null) {
      throw ArgumentError('StatDelta.fromJson: "artist" is required');
    }
    if (json['album'] == null) {
      throw ArgumentError('StatDelta.fromJson: "album" is required');
    }
    if (json['play_count_delta'] == null) {
      throw ArgumentError('StatDelta.fromJson: "play_count_delta" is required');
    }
    if (json['total_seconds_delta'] == null) {
      throw ArgumentError(
          'StatDelta.fromJson: "total_seconds_delta" is required');
    }
    if (json['timestamp'] == null) {
      throw ArgumentError('StatDelta.fromJson: "timestamp" is required');
    }
    if (json['device_id'] == null || (json['device_id'] as String).isEmpty) {
      throw ArgumentError(
          'StatDelta.fromJson: "device_id" is required and must be non-empty');
    }

    return StatDelta(
      id: json['id'] as String,
      statId: json['stat_id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      playCountDelta: json['play_count_delta'] as int,
      totalSecondsDelta: json['total_seconds_delta'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceId: json['device_id'] as String,
      spotifyId: json['spotify_id'] as String?,
      deezerId: json['deezer_id'] as String?,
      onlineArtUrl: json['online_art_url'] as String?,
    );
  }
}
