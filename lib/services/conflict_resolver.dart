import 'package:simple_music_player_2/data/schemas.dart';
import 'package:simple_music_player_2/models/stat_delta.dart';
import 'package:simple_music_player_2/models/stat_model.dart';

/// Pure logic component for merging stat entries from multiple sources.
///
/// Merge rules:
/// - playCount: max(local, remote) for pull-merge
/// - totalSeconds: max(local, remote) for pull-merge
/// - lastPlayed: most recent timestamp wins
/// - Other fields (title, artist, album, spotifyId, deezerId): prefer non-null, latest wins
class ConflictResolver {
  /// Merge a remote stat entry with a local one.
  ///
  /// Uses max-merge strategy:
  /// - playCount = max(local, remote)
  /// - totalSeconds = max(local, remote)
  /// - lastPlayed = most recent timestamp
  /// - For optional fields (spotifyId, deezerId, onlineArtUrl, youtubeUrl):
  ///   prefer non-null value; if both non-null, prefer the entry with the
  ///   more recent lastPlayed timestamp.
  StatEntry mergeStats(StatEntry local, StatEntry remote) {
    final mergedPlayCount =
        local.playCount > remote.playCount ? local.playCount : remote.playCount;
    final mergedTotalSeconds = local.totalSeconds > remote.totalSeconds
        ? local.totalSeconds
        : remote.totalSeconds;

    // Determine which entry has the most recent lastPlayed
    final localLastPlayed =
        local.lastPlayed ?? DateTime.fromMillisecondsSinceEpoch(0);
    final remoteLastPlayed =
        remote.lastPlayed ?? DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime mergedLastPlayed = localLastPlayed.isAfter(remoteLastPlayed)
        ? localLastPlayed
        : remoteLastPlayed;

    // For optional fields, prefer non-null; if both non-null, prefer the latest entry
    final bool localIsLatest = localLastPlayed.isAfter(remoteLastPlayed);

    final mergedSpotifyId = _preferNonNullLatest(
      local.spotifyId,
      remote.spotifyId,
      localIsLatest,
    );
    final mergedDeezerId = _preferNonNullLatest(
      local.deezerId,
      remote.deezerId,
      localIsLatest,
    );
    final mergedOnlineArtUrl = _preferNonNullLatest(
      local.onlineArtUrl,
      remote.onlineArtUrl,
      localIsLatest,
    );
    final mergedYoutubeUrl = _preferNonNullLatest(
      local.youtubeUrl,
      remote.youtubeUrl,
      localIsLatest,
    );

    return StatEntry(
      id: local.id,
      title: local.title,
      artist: local.artist,
      album: local.album,
      playCount: mergedPlayCount,
      totalSeconds: mergedTotalSeconds,
      lastKnownPath: local.lastKnownPath,
      lastPlayed: mergedLastPlayed,
      onlineArtUrl: mergedOnlineArtUrl,
      youtubeUrl: mergedYoutubeUrl,
      spotifyId: mergedSpotifyId,
      deezerId: mergedDeezerId,
    );
  }

  /// Apply a delta to a cloud record using additive merge for concurrent devices.
  ///
  /// - cloud.play_count += delta.playCountDelta
  /// - cloud.total_seconds += delta.totalSecondsDelta
  /// - cloud.last_played = max(cloud.last_played, delta.timestamp)
  /// - Optional fields (spotify_id, deezer_id): prefer non-null from delta
  Map<String, dynamic> applyDelta(
    Map<String, dynamic> cloudRecord,
    StatDelta delta,
  ) {
    final result = Map<String, dynamic>.from(cloudRecord);

    // Additive merge for counters
    final currentPlayCount = (result['play_count'] as int?) ?? 0;
    final currentTotalSeconds = (result['total_seconds'] as int?) ?? 0;
    result['play_count'] = currentPlayCount + delta.playCountDelta;
    result['total_seconds'] = currentTotalSeconds + delta.totalSecondsDelta;

    // Last played: most recent wins
    final cloudLastPlayedStr = result['last_played'] as String?;
    final cloudLastPlayed = cloudLastPlayedStr != null
        ? DateTime.parse(cloudLastPlayedStr)
        : DateTime.fromMillisecondsSinceEpoch(0);
    final deltaTimestamp = delta.timestamp;
    result['last_played'] = (deltaTimestamp.isAfter(cloudLastPlayed)
            ? deltaTimestamp
            : cloudLastPlayed)
        .toIso8601String();

    // Prefer non-null for optional fields from delta
    if (delta.spotifyId != null && delta.spotifyId!.isNotEmpty) {
      result['spotify_id'] = delta.spotifyId;
    }
    if (delta.deezerId != null && delta.deezerId!.isNotEmpty) {
      result['deezer_id'] = delta.deezerId;
    }

    // Update device_id to the delta's device
    result['device_id'] = delta.deviceId;

    return result;
  }

  /// Deduplicate history entries from local and remote sources.
  ///
  /// Two entries are considered duplicates if they have the same title AND artist
  /// AND their lastPlayed timestamps differ by less than 1 second.
  ///
  /// Returns a merged list with duplicates removed (keeping the local entry
  /// when a duplicate is found).
  List<HistoryEntry> deduplicateHistory(
    List<HistoryEntry> local,
    List<HistoryEntry> remote,
  ) {
    final List<HistoryEntry> result = List.from(local);

    for (final remoteEntry in remote) {
      final bool isDuplicate = result.any(
        (localEntry) => _isHistoryDuplicate(localEntry, remoteEntry),
      );
      if (!isDuplicate) {
        result.add(remoteEntry);
      }
    }

    return result;
  }

  /// Check if two history entries are duplicates.
  ///
  /// Duplicates have the same title+artist and timestamps within 1 second.
  bool _isHistoryDuplicate(HistoryEntry a, HistoryEntry b) {
    if (a.title != b.title) return false;
    if (a.artist != b.artist) return false;

    final diff = a.lastPlayed.difference(b.lastPlayed).abs();
    return diff.inMilliseconds < 1000;
  }

  /// Helper: prefer non-null value; if both non-null, prefer the latest entry's value.
  String? _preferNonNullLatest(
    String? localValue,
    String? remoteValue,
    bool localIsLatest,
  ) {
    if (localValue != null && remoteValue == null) return localValue;
    if (localValue == null && remoteValue != null) return remoteValue;
    if (localValue == null && remoteValue == null) return null;
    // Both non-null: prefer the latest entry's value
    return localIsLatest ? localValue : remoteValue;
  }
}
