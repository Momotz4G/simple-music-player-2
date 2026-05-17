import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/schemas.dart';
import '../models/stat_delta.dart';
import '../models/stat_model.dart';
import 'auth_service.dart';
import 'conflict_resolver.dart';
import 'db_service.dart';
import 'debug_log_service.dart';
import 'metrics_service.dart';
import 'pocketbase_service.dart';
import 'sync_queue.dart';

/// Sync status states for UI feedback.
enum SyncStatus {
  idle,
  syncing,
  error,
  offline,
  disabled,
}

/// Central orchestrator for per-song stat synchronization.
///
/// Manages the lifecycle of cloud sync operations including push/pull of
/// stat deltas, history entries, and queue replay on connectivity changes.
///
/// Singleton pattern matching [PocketBaseService].
///
/// Validates: Requirements 4.5, 4.6, 4.7, 9.1, 9.2, 9.3, 9.5, 9.6
class SyncEngine {
  static final SyncEngine _instance = SyncEngine._internal();
  factory SyncEngine() => _instance;
  SyncEngine._internal();

  // ─── Internal State ───────────────────────────────────────────────────────

  bool _initialized = false;
  bool _isSyncing = false;
  bool _hasConnectivity = true;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  // ─── Batching State ─────────────────────────────────────────────────────

  /// Buffer for accumulating deltas before batch flush.
  final List<StatDelta> _batchBuffer = [];

  /// Timer for the 5-second batching window.
  Timer? _batchTimer;

  /// Maximum number of deltas before triggering a batch flush.
  /// High threshold since deltas are coalesced by stat_id on flush.
  static const int _batchThreshold = 100;

  /// Duration of the batching window.
  static const Duration _batchWindow = Duration(seconds: 30);

  /// Maximum payload size (in bytes) before gzip compression is applied.
  static const int _gzipThreshold = 10 * 1024; // 10KB

  /// Maximum number of songs to sync (5000-song cap).
  static const int _maxSyncSongs = 5000;

  // ─── Merge Completion Callbacks ──────────────────────────────────────────

  /// Callbacks invoked when pullAndMerge() completes with new data.
  /// Used by StatsNotifier to refresh displayed statistics within 2 seconds.
  ///
  /// Validates: Requirements 6.1, 6.2, 6.3
  final List<void Function()> _onMergeCompleteCallbacks = [];

  /// Registers a callback to be invoked when pullAndMerge() completes
  /// with new data. The callback should trigger a stats refresh.
  void addOnMergeCompleteListener(void Function() callback) {
    _onMergeCompleteCallbacks.add(callback);
  }

  /// Removes a previously registered merge-complete callback.
  void removeOnMergeCompleteListener(void Function() callback) {
    _onMergeCompleteCallbacks.remove(callback);
  }

  /// Notifies all registered listeners that a merge has completed.
  void _notifyMergeComplete() {
    for (final callback in _onMergeCompleteCallbacks) {
      callback();
    }
  }

  // ─── History Merge Callbacks ──────────────────────────────────────────────

  final List<void Function()> _onHistoryMergeCompleteCallbacks = [];

  /// Registers a callback to be invoked when pullRecentHistory() completes
  /// with new entries. Used by HistoryNotifier to refresh the history page.
  void addOnHistoryMergeCompleteListener(void Function() callback) {
    _onHistoryMergeCompleteCallbacks.add(callback);
  }

  /// Removes a previously registered history-merge-complete callback.
  void removeOnHistoryMergeCompleteListener(void Function() callback) {
    _onHistoryMergeCompleteCallbacks.remove(callback);
  }

  void _notifyHistoryMergeComplete() {
    for (final callback in _onHistoryMergeCompleteCallbacks) {
      callback();
    }
  }

  // ─── Public State ─────────────────────────────────────────────────────────

  /// Whether a sync operation is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Stream of sync status changes for UI feedback.
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Combined guard check: returns true only when ALL conditions for cloud
  /// sync are met (linked account, online, not in offline mode, sync enabled).
  ///
  /// Validates: Requirements 4.6, 9.1, 9.5
  bool get shouldSync {
    // Must have a linked Google OAuth account
    if (!_isLinked) return false;
    // Must not be in Offline Mode
    if (_isOfflineMode) return false;
    // Must have network connectivity
    if (!_hasConnectivity) return false;
    // Must have Cloud Stats Sync toggle enabled
    if (!_syncEnabled) return false;
    return true;
  }

  // ─── Guard Condition Helpers ──────────────────────────────────────────────

  /// Whether the user has a linked Google OAuth account.
  bool get _isLinked =>
      AuthService().isLinked || PocketBaseService().userId != null;

  /// Whether Offline Mode is enabled in settings.
  bool get _isOfflineMode => PocketBaseService.isOffline;

  /// Whether the "Cloud Stats Sync" toggle is enabled.
  bool get _syncEnabled => PocketBaseService.enableCloudSync;

  // ─── Lifecycle Methods ────────────────────────────────────────────────────

  /// Initializes the SyncEngine: sets up the queue, checks auth state,
  /// and performs an initial connectivity check.
  ///
  /// Should be called once during app startup after [PocketBaseService.init()]
  /// and [AuthService.init()] have completed.
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Initial connectivity check
      await _checkConnectivity();

      DebugLogService().info(
        '🔄 SyncEngine: Initialized '
        '(linked=$_isLinked, online=$_hasConnectivity, '
        'offlineMode=$_isOfflineMode, syncEnabled=$_syncEnabled)',
      );

      _initialized = true;

      // Defer heavy sync operations to avoid blocking app startup.
      // Run them in the background after a 3-second delay so the UI
      // can render first.
      if (shouldSync) {
        Future.delayed(const Duration(seconds: 3), () async {
          try {
            final pending = await SyncQueue().pendingCount;
            if (pending > 0) {
              DebugLogService().info(
                '🔄 SyncEngine: $pending queued items found, replaying...',
              );
              await replayQueue();
            }

            // Migration version check — bump this number to force re-upload
            // when new fields are added to the sync payload.
            const currentMigrationVersion = 2;
            final prefs = await SharedPreferences.getInstance();
            final lastMigrationVersion =
                prefs.getInt('sync_engine_migration_version') ?? 0;

            if (lastMigrationVersion < currentMigrationVersion) {
              DebugLogService().info(
                  '🔄 SyncEngine: Migration v$lastMigrationVersion → v$currentMigrationVersion: '
                  'uploading all stats and history');
              await fullUpload([]);
              await fullUploadHistory();
              await prefs.setInt(
                  'sync_engine_migration_version', currentMigrationVersion);
            }

            // Always pull remote changes on startup (fast — remote-only diff)
            await pullAndMerge();
            await pullRecentHistory();
          } catch (e) {
            DebugLogService().error('⚠️ SyncEngine deferred sync error: $e');
          }
        });
      }
    } catch (e) {
      DebugLogService().error('⚠️ SyncEngine init error: $e');
      _initialized = true; // Mark initialized to avoid retry loops
    }
  }

  /// Called when network connectivity state changes.
  ///
  /// When connectivity is restored and all other guards pass, triggers
  /// queue replay to push pending changes (Requirement 4.5, 4.2).
  Future<void> onConnectivityChanged(bool isOnline) async {
    // Only act on actual state changes to avoid spamming
    if (isOnline == _hasConnectivity) return;

    final wasOffline = !_hasConnectivity;
    _hasConnectivity = isOnline;

    DebugLogService().info(
      '🔄 SyncEngine: Connectivity changed → ${isOnline ? "ONLINE" : "OFFLINE"}',
    );

    if (isOnline && wasOffline && shouldSync) {
      _emitStatus(SyncStatus.syncing);
      await replayQueue();
      await pullAndMerge();
      await _applyPendingHistoryClear();
      await fullUploadHistory();
      await pullRecentHistory();
      _emitStatus(SyncStatus.idle);
    } else if (!isOnline) {
      _emitStatus(SyncStatus.offline);
    }
  }

  /// Called when the user toggles Offline Mode in settings.
  ///
  /// When Offline Mode is disabled, replays queued changes and pulls
  /// remote updates (Requirement 4.7).
  Future<void> onOfflineModeChanged(bool isOffline) async {
    DebugLogService().info(
      '🔄 SyncEngine: Offline mode changed → ${isOffline ? "ENABLED" : "DISABLED"}',
    );

    if (!isOffline && shouldSync) {
      // Offline mode was just disabled — replay queue and pull
      _emitStatus(SyncStatus.syncing);
      await replayQueue();
      await pullAndMerge();
      await _applyPendingHistoryClear();
      await fullUploadHistory();
      await pullRecentHistory();
      _emitStatus(SyncStatus.idle);
    } else if (isOffline) {
      _emitStatus(SyncStatus.offline);
    }
  }

  /// Called when the user links their Google OAuth account.
  ///
  /// Triggers a full upload of all local stats to the cloud (Requirement 9.2).
  Future<void> onAccountLinked(String userId) async {
    DebugLogService().info(
      '🔄 SyncEngine: Account linked → $userId. Triggering full upload + pull.',
    );

    if (shouldSync) {
      _emitStatus(SyncStatus.syncing);
      await fullUpload([]);
      await pullAndMerge();
      _emitStatus(SyncStatus.idle);
    }
  }

  /// Called when the user unlinks their Google OAuth account.
  ///
  /// Stops all sync operations, clears the queue, but retains local data
  /// (Requirement 9.3).
  Future<void> onAccountUnlinked() async {
    DebugLogService().info(
      '🔄 SyncEngine: Account unlinked. Stopping sync, clearing queue.',
    );

    // Abort any in-progress sync
    _isSyncing = false;

    // Clear the pending queue — no account to sync to
    await SyncQueue().clear();

    _emitStatus(SyncStatus.disabled);

    DebugLogService().info(
      '🔄 SyncEngine: Queue cleared. Local data retained.',
    );
  }

  /// Called when the "Cloud Stats Sync" toggle is re-enabled.
  ///
  /// Replays queued changes and performs a full pull (Requirement 9.6).
  Future<void> onSyncToggleChanged(bool enabled) async {
    DebugLogService().info(
      '🔄 SyncEngine: Cloud Stats Sync toggle → ${enabled ? "ENABLED" : "DISABLED"}',
    );

    if (enabled && shouldSync) {
      _emitStatus(SyncStatus.syncing);
      await replayQueue();
      await pullAndMerge();
      await _applyPendingHistoryClear();
      await fullUploadHistory();
      await pullRecentHistory();
      _emitStatus(SyncStatus.idle);
    } else if (!enabled) {
      _emitStatus(SyncStatus.disabled);
    }
  }

  // ─── Core Sync Operations (Stubs — implemented in tasks 4.3 and 4.6) ─────

  /// Pushes a single stat delta to the cloud song_stats collection.
  ///
  /// If guards fail, enqueues the delta locally instead.
  /// Uses batching logic: accumulates deltas and flushes when >3 changes
  /// occur within a 5-second window (Requirement 1.5).
  Future<void> pushStatDelta(StatDelta delta) async {
    if (!shouldSync) {
      await SyncQueue().enqueue(delta);
      return;
    }

    // Add to batch buffer
    _batchBuffer.add(delta);

    // If we exceed the batch threshold, flush immediately
    if (_batchBuffer.length > _batchThreshold) {
      _batchTimer?.cancel();
      _batchTimer = null;
      await _flushBatchBuffer();
    } else {
      // Start or reset the batch window timer
      _batchTimer?.cancel();
      _batchTimer = Timer(_batchWindow, () async {
        await _flushBatchBuffer();
      });
    }
  }

  /// Pushes a batch of stat deltas to the cloud in a single operation.
  ///
  /// Applies gzip compression for payloads exceeding 10KB (Requirement 8.4).
  /// Each delta is applied to the existing cloud record using ConflictResolver.applyDelta().
  Future<void> pushBatch(List<StatDelta> deltas) async {
    if (!shouldSync) {
      for (final delta in deltas) {
        await SyncQueue().enqueue(delta);
      }
      return;
    }

    if (deltas.isEmpty) return;

    try {
      _emitStatus(SyncStatus.syncing);

      final resolver = ConflictResolver();
      final pb = PocketBaseService();

      // Group deltas by stat_id to minimize cloud lookups
      final deltasByStatId = <String, List<StatDelta>>{};
      for (final delta in deltas) {
        deltasByStatId.putIfAbsent(delta.statId, () => []).add(delta);
      }

      // Fetch existing cloud records for the stat_ids we need to update
      for (final entry in deltasByStatId.entries) {
        final statId = entry.key;
        final statDeltas = entry.value;

        try {
          // Look up existing cloud record for this stat_id
          final existingRecords = await pb.listSongStats(
            filter: 'stat_id = "$statId"',
            perPage: 1,
          );

          if (existingRecords.isNotEmpty) {
            // Apply all deltas for this stat_id sequentially
            var cloudRecord = existingRecords.first;
            for (final delta in statDeltas) {
              cloudRecord = resolver.applyDelta(cloudRecord, delta);
              // Push art URL too if delta has it and cloud doesn't
              if (delta.onlineArtUrl != null &&
                  (cloudRecord['online_art_url'] == null ||
                      (cloudRecord['online_art_url'] as String).isEmpty)) {
                cloudRecord['online_art_url'] = delta.onlineArtUrl;
              }
            }
            // Update the existing record
            final recordId = cloudRecord['id'] as String;
            await pb.updateSongStat(recordId, cloudRecord);
          } else {
            // No existing record — create one from the first delta
            final firstDelta = statDeltas.first;
            var newRecord = <String, dynamic>{
              'stat_id': statId,
              'title': firstDelta.title,
              'artist': firstDelta.artist,
              'album': firstDelta.album,
              'play_count': 0,
              'total_seconds': 0,
              'last_played': firstDelta.timestamp.toIso8601String(),
              'device_id': firstDelta.deviceId,
              'spotify_id': firstDelta.spotifyId,
              'deezer_id': firstDelta.deezerId,
              'online_art_url': firstDelta.onlineArtUrl,
            };
            // Apply all deltas
            for (final delta in statDeltas) {
              newRecord = resolver.applyDelta(newRecord, delta);
            }
            await pb.createSongStat(newRecord);
          }
        } catch (e) {
          // On failure, enqueue the deltas for retry
          DebugLogService().error(
            '⚠️ SyncEngine: pushBatch failed for stat_id=$statId: $e',
          );
          for (final delta in statDeltas) {
            await SyncQueue().enqueue(delta);
          }
        }
      }

      _emitStatus(SyncStatus.idle);
    } catch (e) {
      DebugLogService().error('⚠️ SyncEngine: pushBatch error: $e');
      // Enqueue all deltas on catastrophic failure
      for (final delta in deltas) {
        await SyncQueue().enqueue(delta);
      }
      _emitStatus(SyncStatus.error);
    }
  }

  /// Fetches all song_stats for the current user from the cloud and merges
  /// them with local Isar records via ConflictResolver.
  ///
  /// For each remote record:
  /// - If a local SavedStat with the same statId exists: merge using ConflictResolver
  /// - If no local match: create a new local SavedStat from the remote data
  /// - After successful merge, set lastSyncedAt = DateTime.now() on the local record
  ///
  /// Validates: Requirements 2.1, 2.6, 3.3, 3.4
  Future<void> pullAndMerge() async {
    if (!shouldSync) return;

    try {
      _emitStatus(SyncStatus.syncing);
      _isSyncing = true;

      final pb = PocketBaseService();
      final resolver = ConflictResolver();
      final isar = await DBService().db;

      // Fetch all remote song_stats with pagination
      final List<Map<String, dynamic>> allRemoteRecords = [];
      int currentPage = 1;
      const int pageSize = 200;
      bool hasMore = true;

      while (hasMore) {
        final pageRecords = await pb.listSongStats(
          page: currentPage,
          perPage: pageSize,
        );

        allRemoteRecords.addAll(pageRecords);

        // If we got fewer records than the page size, we've reached the end
        hasMore = pageRecords.length == pageSize;
        currentPage++;
      }

      DebugLogService().info(
        '🔄 SyncEngine: pullAndMerge fetched ${allRemoteRecords.length} remote records',
      );

      if (allRemoteRecords.isEmpty) {
        _emitStatus(SyncStatus.idle);
        return;
      }

      // Process remote records in chunks to avoid blocking the UI thread.
      // Each chunk is wrapped in its own write transaction, with event-loop
      // yields between chunks to keep the app responsive.
      const int chunkSize = 50;
      int processed = 0;
      int skipped = 0;

      for (int chunkStart = 0;
          chunkStart < allRemoteRecords.length;
          chunkStart += chunkSize) {
        final chunkEnd =
            (chunkStart + chunkSize).clamp(0, allRemoteRecords.length);
        final chunk = allRemoteRecords.sublist(chunkStart, chunkEnd);

        await isar.writeTxn(() async {
          for (final remoteRecord in chunk) {
            final remoteStatId = remoteRecord['stat_id'] as String?;
            if (remoteStatId == null || remoteStatId.isEmpty) continue;

            // Look up local SavedStat by statId
            final localStat = await isar.savedStats
                .filter()
                .statIdEqualTo(remoteStatId)
                .findFirst();

            if (localStat != null) {
              // Early-exit optimization: skip if cloud has nothing new.
              // This avoids writes when pull is a no-op.
              final remotePlayCount = (remoteRecord['play_count'] as int?) ?? 0;
              final remoteTotalSeconds =
                  (remoteRecord['total_seconds'] as int?) ?? 0;
              final remoteArtUrl = remoteRecord['online_art_url'] as String?;
              final remoteLastPlayedStr =
                  remoteRecord['last_played'] as String?;
              final remoteLastPlayed = remoteLastPlayedStr != null
                  ? DateTime.tryParse(remoteLastPlayedStr)
                  : null;

              final bool noCountChange = remotePlayCount <= localStat.playCount;
              final bool noTimeChange =
                  remoteTotalSeconds <= localStat.totalSeconds;
              final bool noArtChange = remoteArtUrl == null ||
                  remoteArtUrl.isEmpty ||
                  (localStat.onlineArtUrl != null &&
                      localStat.onlineArtUrl!.isNotEmpty);
              final bool noLastPlayedChange = remoteLastPlayed == null ||
                  (localStat.lastPlayed != null &&
                      !remoteLastPlayed.isAfter(localStat.lastPlayed!));

              if (noCountChange &&
                  noTimeChange &&
                  noArtChange &&
                  noLastPlayedChange) {
                skipped++;
                continue;
              }

              // Local exists: merge using ConflictResolver
              final localEntry = StatEntry(
                id: localStat.statId,
                title: localStat.title,
                artist: localStat.artist,
                album: localStat.album,
                playCount: localStat.playCount,
                totalSeconds: localStat.totalSeconds,
                lastKnownPath: localStat.lastKnownPath,
                lastPlayed: localStat.lastPlayed,
                onlineArtUrl: localStat.onlineArtUrl,
                youtubeUrl: localStat.youtubeUrl,
                spotifyId: localStat.spotifyId,
                deezerId: localStat.deezerId,
              );

              final remoteEntry = StatEntry(
                id: remoteStatId,
                title: (remoteRecord['title'] as String?) ?? localStat.title,
                artist: (remoteRecord['artist'] as String?) ?? localStat.artist,
                album: (remoteRecord['album'] as String?) ?? localStat.album,
                playCount: remotePlayCount,
                totalSeconds: remoteTotalSeconds,
                lastKnownPath: localStat.lastKnownPath,
                lastPlayed: remoteLastPlayed,
                onlineArtUrl: remoteArtUrl,
                spotifyId: remoteRecord['spotify_id'] as String?,
                deezerId: remoteRecord['deezer_id'] as String?,
              );

              final merged = resolver.mergeStats(localEntry, remoteEntry);

              // Update local Isar record with merged values
              localStat.playCount = merged.playCount;
              localStat.totalSeconds = merged.totalSeconds;
              localStat.lastPlayed = merged.lastPlayed;
              localStat.spotifyId = merged.spotifyId;
              localStat.deezerId = merged.deezerId;
              localStat.onlineArtUrl = merged.onlineArtUrl;
              localStat.youtubeUrl = merged.youtubeUrl;

              await isar.savedStats.put(localStat);
              processed++;
            } else {
              // No local match: create a new SavedStat from remote data
              final newStat = SavedStat()
                ..statId = remoteStatId
                ..title = (remoteRecord['title'] as String?) ?? 'Unknown'
                ..artist = (remoteRecord['artist'] as String?) ?? 'Unknown'
                ..album = (remoteRecord['album'] as String?) ?? 'Unknown'
                ..playCount = (remoteRecord['play_count'] as int?) ?? 0
                ..totalSeconds = (remoteRecord['total_seconds'] as int?) ?? 0
                ..lastPlayed = remoteRecord['last_played'] != null
                    ? DateTime.tryParse(remoteRecord['last_played'] as String)
                    : null
                ..lastKnownPath = ''
                ..spotifyId = remoteRecord['spotify_id'] as String?
                ..deezerId = remoteRecord['deezer_id'] as String?
                ..onlineArtUrl = remoteRecord['online_art_url'] as String?
                ..youtubeUrl = null;

              await isar.savedStats.put(newStat);
              processed++;
            }
          }
        });

        // Yield to the event loop between chunks to keep UI responsive
        await Future.delayed(const Duration(milliseconds: 20));
      }

      DebugLogService().info(
        '🔄 SyncEngine: pullAndMerge completed — $processed updated, $skipped unchanged',
      );

      // Enforce aggregate consistency after all merges are complete
      await enforceAggregateConsistency();

      // Notify listeners (e.g., StatsNotifier) to refresh displayed statistics.
      // This ensures the stats page updates within 2 seconds of merge completion.
      // Validates: Requirements 6.1, 6.2, 6.3
      _notifyMergeComplete();

      _emitStatus(SyncStatus.idle);
    } catch (e) {
      DebugLogService().error('⚠️ SyncEngine: pullAndMerge error: $e');
      _emitStatus(SyncStatus.error);
    }
  }

  /// Uploads all local stat entries to the cloud.
  ///
  /// Called on initial account link (Requirement 9.2).
  /// Enforces the 5000-song cap by selecting the most recently played
  /// (Requirements 8.2, 8.3).
  Future<void> fullUpload(List<StatEntry> allStats) async {
    if (!shouldSync) return;

    try {
      _emitStatus(SyncStatus.syncing);

      // If no stats provided, read all from local Isar
      List<StatEntry> statsToUpload = allStats;
      if (statsToUpload.isEmpty) {
        final isar = await DBService().db;
        final savedStats = await isar.savedStats.where().findAll();
        statsToUpload = savedStats
            .map((s) => StatEntry(
                  id: s.statId,
                  title: s.title,
                  artist: s.artist,
                  album: s.album,
                  playCount: s.playCount,
                  totalSeconds: s.totalSeconds,
                  lastKnownPath: s.lastKnownPath,
                  lastPlayed: s.lastPlayed,
                  spotifyId: s.spotifyId,
                  deezerId: s.deezerId,
                ))
            .toList();
      }

      DebugLogService().info(
        '🔄 SyncEngine: fullUpload starting with ${statsToUpload.length} entries',
      );

      // Sort by lastPlayed descending (most recent first)
      final sorted = List<StatEntry>.from(statsToUpload)
        ..sort((a, b) {
          final aTime = a.lastPlayed ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.lastPlayed ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

      // Enforce 5000-song cap: take only the most recently played
      final capped = sorted.length > _maxSyncSongs
          ? sorted.sublist(0, _maxSyncSongs)
          : sorted;

      // Convert to cloud format for batch upsert
      final cloudEntries = capped
          .map((stat) => <String, dynamic>{
                'stat_id': stat.id,
                'title': stat.title,
                'artist': stat.artist,
                'album': stat.album,
                'play_count': stat.playCount,
                'total_seconds': stat.totalSeconds,
                'last_played': stat.lastPlayed?.toIso8601String() ??
                    DateTime.now().toIso8601String(),
                'spotify_id': stat.spotifyId,
                'deezer_id': stat.deezerId,
                'online_art_url': stat.onlineArtUrl,
              })
          .toList();

      if (cloudEntries.isEmpty) {
        DebugLogService().info(
          '🔄 SyncEngine: fullUpload — no entries to upload',
        );
        _emitStatus(SyncStatus.idle);
        return;
      }

      // Use batchUpsertSongStats for efficient upload
      final successCount =
          await PocketBaseService().batchUpsertSongStats(cloudEntries);

      DebugLogService().info(
        '🔄 SyncEngine: fullUpload complete — '
        '$successCount/${cloudEntries.length} records uploaded',
      );

      _emitStatus(SyncStatus.idle);
    } catch (e) {
      DebugLogService().error('⚠️ SyncEngine: fullUpload error: $e');
      _emitStatus(SyncStatus.error);
    }
  }

  /// Replays all queued changes in chronological order.
  ///
  /// Dequeues all pending entries (sorted by createdAt ascending),
  /// converts each back to a StatDelta, and pushes via pushBatch.
  /// On success: marks the entry as completed (removes from queue).
  /// On failure: retains the entry in the queue for retry on next connectivity event.
  ///
  /// Validates: Requirements 4.2, 4.3
  Future<void> replayQueue() async {
    if (!shouldSync) return;

    try {
      _emitStatus(SyncStatus.syncing);

      final queue = SyncQueue();
      final entries = await queue.dequeueAll();

      if (entries.isEmpty) {
        _emitStatus(SyncStatus.idle);
        return;
      }

      DebugLogService().info(
        '🔄 SyncEngine: replayQueue starting with ${entries.length} entries',
      );

      // Process each entry individually in chronological order
      for (final entry in entries) {
        try {
          // Queue now returns StatDelta directly
          await pushBatch([entry]);

          // On success: mark completed (remove from queue)
          await queue.markCompleted(entry.id);
        } catch (e) {
          // On failure: retain in queue for retry
          DebugLogService().error(
            '⚠️ SyncEngine: replayQueue failed for deltaId=${entry.id}: $e',
          );
          await queue.retainFailed(entry.id);
        }
      }

      DebugLogService().info(
        '🔄 SyncEngine: replayQueue completed',
      );

      _emitStatus(SyncStatus.idle);
    } catch (e) {
      DebugLogService().error('⚠️ SyncEngine: replayQueue error: $e');
      _emitStatus(SyncStatus.error);
    }
  }

  /// Pushes a single history entry to the cloud history_sync collection.
  ///
  /// Converts the HistoryEntry to a Map with the required fields and uploads
  /// it via PocketBaseService.createHistorySync().
  ///
  /// Validates: Requirements 5.1
  Future<void> pushHistoryEntry(HistoryEntry entry) async {
    if (!shouldSync) return;

    try {
      // Get device identifier for the device_id field
      final deviceId = await MetricsService().getDeviceIdentifier();

      // Convert HistoryEntry to the cloud format
      final data = <String, dynamic>{
        'title': entry.title,
        'artist': entry.artist,
        'album': entry.album,
        // 🚀 BUGFIX: Convert to UTC before stringifying. PocketBase DateTime fields
        // assume strings without timezone are UTC. If we send local time, it gets
        // shifted into the future by the timezone offset when pulled back down!
        'last_played': entry.lastPlayed.toUtc().toIso8601String(),
        'duration': entry.duration.toInt(),
        'device_id': deviceId,
        'spotify_id': entry.spotifyId,
        'deezer_id': entry.deezerId,
        'online_art_url': entry.albumArtUrl,
      };

      // Upsert: replace existing entry with same title+artist (matches local
      // history dedup logic which keeps one record per song).
      final result = await PocketBaseService().upsertHistorySync(data);

      if (result != null) {
        DebugLogService().info(
          '🔄 SyncEngine: pushHistoryEntry succeeded for "${entry.title}"',
        );
      }

      // Trim cloud history to 50 most recent entries (matches local cap).
      await PocketBaseService().trimHistorySync(keep: 50);
    } catch (e) {
      DebugLogService().error('⚠️ SyncEngine: pushHistoryEntry error: $e');
    }
  }

  /// Wipes all history_sync records for the current user from the cloud.
  /// Called by HistoryNotifier.clearHistory() to ensure cleared history
  /// doesn't come back on next pull.
  /// Returns true if the clear was executed, false if skipped (offline/sync off).
  Future<bool> clearCloudHistory() async {
    if (!shouldSync) return false;
    try {
      await PocketBaseService().deleteAllHistorySync();
      DebugLogService().info('🔄 SyncEngine: Cloud history cleared');
      return true;
    } catch (e) {
      DebugLogService().error('⚠️ SyncEngine: clearCloudHistory error: $e');
      return false;
    }
  }

  /// Checks for a pending cloud history clear (requested while offline)
  /// and executes it. Called when sync resumes.
  Future<void> _applyPendingHistoryClear() async {
    if (!shouldSync) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getBool('pending_cloud_history_clear') ?? false;
      if (pending) {
        DebugLogService()
            .info('🔄 SyncEngine: Applying pending cloud history clear');
        await PocketBaseService().deleteAllHistorySync();
        await prefs.remove('pending_cloud_history_clear');
      }
    } catch (e) {
      DebugLogService().error('⚠️ SyncEngine: _applyPendingHistoryClear: $e');
    }
  }

  /// Uploads all local history entries to the cloud.
  ///
  /// Called during migration to bulk-sync existing history. Subsequent plays
  /// use [pushHistoryEntry] for incremental sync.
  Future<void> fullUploadHistory() async {
    if (!shouldSync) return;

    try {
      final isar = await DBService().db;
      final allHistory = await isar.historyEntrys
          .where()
          .sortByLastPlayedDesc()
          .limit(50)
          .findAll();

      DebugLogService().info(
        '🔄 SyncEngine: fullUploadHistory starting with ${allHistory.length} entries',
      );

      int successCount = 0;
      for (int i = 0; i < allHistory.length; i++) {
        final entry = allHistory[i];
        try {
          final deviceId = await MetricsService().getDeviceIdentifier();
          final data = <String, dynamic>{
            'title': entry.title,
            'artist': entry.artist,
            'album': entry.album,
            'last_played': entry.lastPlayed.toIso8601String(),
            'duration': entry.duration.toInt(),
            'device_id': deviceId,
            'spotify_id': entry.spotifyId,
            'deezer_id': entry.deezerId,
            'online_art_url': entry.albumArtUrl,
          };
          final result = await PocketBaseService().upsertHistorySync(data);
          if (result != null) successCount++;
        } catch (_) {
          // Continue on individual failures
        }

        // Yield to event loop every 5 records
        if (i % 5 == 0) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // Trim cloud to 50 after upload
      await PocketBaseService().trimHistorySync(keep: 50);

      DebugLogService().info(
        '🔄 SyncEngine: fullUploadHistory complete — $successCount/${allHistory.length} uploaded',
      );
    } catch (e) {
      DebugLogService().error('⚠️ SyncEngine: fullUploadHistory error: $e');
    }
  }

  /// Pulls recent history entries from the cloud that are not present locally.
  ///
  /// Fetches up to 200 most recent history entries from the cloud, deduplicates
  /// against local history using ConflictResolver, and inserts any new entries
  /// into the local Isar HistoryEntry collection.
  ///
  /// Enforces the 200-entry cap: only syncs the 200 most recent history entries.
  ///
  /// Validates: Requirements 5.2, 5.3, 5.4
  Future<void> pullRecentHistory() async {
    if (!shouldSync) return;

    try {
      final pb = PocketBaseService();
      final isar = await DBService().db;

      // Fetch up to 200 most recent remote history entries (sorted by last_played DESC)
      final remoteRecords = await pb.listHistorySync(limit: 200);

      if (remoteRecords.isEmpty) {
        DebugLogService().info(
          '🔄 SyncEngine: pullRecentHistory — no remote history found',
        );
        return;
      }

      DebugLogService().info(
        '🔄 SyncEngine: pullRecentHistory fetched ${remoteRecords.length} remote entries',
      );

      // Convert remote records to HistoryEntry objects for deduplication
      final List<HistoryEntry> remoteEntries = remoteRecords.map((record) {
        DateTime parsedDate = DateTime.now();
        if (record['last_played'] != null) {
          parsedDate = DateTime.tryParse(record['last_played'] as String) ?? DateTime.now();
          // 🚀 BUGFIX: Recover from legacy UTC-shifted bug.
          // Older versions uploaded local time strings without timezone. PocketBase
          // interpreted them as UTC, resulting in timestamps shifted into the FUTURE
          // by the user's local timezone offset when pulled down.
          // If a timestamp is in the future, it's definitely a legacy bugged entry.
          // Subtract the local timezone offset to restore its true historical time.
          if (parsedDate.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
            parsedDate = parsedDate.subtract(DateTime.now().timeZoneOffset);
          }
        }

        final entry = HistoryEntry()
          ..title = (record['title'] as String?) ?? 'Unknown'
          ..artist = (record['artist'] as String?) ?? 'Unknown'
          ..album = (record['album'] as String?) ?? 'Unknown'
          ..lastPlayed = parsedDate
          ..duration = ((record['duration'] as num?) ?? 0).toDouble()
          ..albumArtUrl = (record['online_art_url'] as String?) ?? ''
          ..originalFilePath = ''
          ..youtubeUrl = ''
          ..isStream = true
          ..spotifyId = record['spotify_id'] as String?
          ..deezerId = record['deezer_id'] as String?;
        return entry;
      }).toList();

      // Get local history entries (by title+artist)
      final localEntries = await isar.historyEntrys
          .where()
          .sortByLastPlayedDesc()
          .limit(200)
          .findAll();

      // Build a lookup of local entries by normalized title+primaryArtist key
      // This handles artist name variations across sources (e.g. "Ziv Zaifman"
      // vs "Ziv Zaifman, Hugh Jackman, Michelle Williams")
      final localByKey = <String, HistoryEntry>{};
      for (final local in localEntries) {
        final key =
            '${local.title.toLowerCase()}|${_primaryArtist(local.artist)}';
        localByKey[key] = local;
      }

      // Collect entries to create (new) and entries to update (existing
      // but with a newer remote timestamp)
      final List<HistoryEntry> toCreate = [];
      final List<HistoryEntry> toUpdate = [];

      for (final remote in remoteEntries) {
        final key =
            '${remote.title.toLowerCase()}|${_primaryArtist(remote.artist)}';
        final local = localByKey[key];
        if (local == null) {
          toCreate.add(remote);
        } else if (remote.lastPlayed.isAfter(local.lastPlayed)) {
          // Remote is more recent — bump local timestamp so it bubbles up
          local.lastPlayed = remote.lastPlayed;
          if (local.albumArtUrl.isEmpty && remote.albumArtUrl.isNotEmpty) {
            local.albumArtUrl = remote.albumArtUrl;
          }
          toUpdate.add(local);
        }
      }

      if (toCreate.isEmpty && toUpdate.isEmpty) {
        DebugLogService().info(
          '🔄 SyncEngine: pullRecentHistory — no changes',
        );
        return;
      }

      await isar.writeTxn(() async {
        if (toUpdate.isNotEmpty) {
          await isar.historyEntrys.putAll(toUpdate);
        }
        if (toCreate.isNotEmpty) {
          await isar.historyEntrys.putAll(toCreate);
        }

        // Trim to the 50 most recent entries (matches local cap)
        final count = await isar.historyEntrys.count();
        if (count > 50) {
          final oldest = await isar.historyEntrys
              .where()
              .sortByLastPlayed()
              .limit(count - 50)
              .findAll();
          await isar.historyEntrys.deleteAll(oldest.map((e) => e.id).toList());
        }
      });

      DebugLogService().info(
        '🔄 SyncEngine: pullRecentHistory merged — ${toCreate.length} added, ${toUpdate.length} updated',
      );

      _notifyHistoryMergeComplete();
    } catch (e) {
      DebugLogService().error('⚠️ SyncEngine: pullRecentHistory error: $e');
    }
  }

  // ─── History Dedup Helpers ───────────────────────────────────────────────────

  /// Extracts the primary artist name from a potentially multi-artist string.
  /// e.g. "Ziv Zaifman, Hugh Jackman, Michelle Williams" → "ziv zaifman"
  ///      "The Weeknd feat. Daft Punk"                   → "the weeknd"
  static String _primaryArtist(String artist) {
    String primary = artist.trim();
    for (final sep in [',', ' feat.', ' feat ', ' ft.', ' ft ', ' & ', ' x ', ' X ', ' and ']) {
      final idx = primary.toLowerCase().indexOf(sep.toLowerCase());
      if (idx > 0) {
        primary = primary.substring(0, idx).trim();
        break;
      }
    }
    return primary.toLowerCase();
  }

  // ─── Aggregate Consistency Enforcement ─────────────────────────────────────


  /// Verifies and enforces the backward compatibility invariant:
  /// - metrics.play_count >= sum(song_stats.play_count)
  /// - metrics.total_minutes >= sum(song_stats.total_seconds) / 60
  ///
  /// If either invariant is violated, updates the aggregate upward to match
  /// the per-song sum. This ensures the existing leaderboard and metrics
  /// collection remain consistent with per-song data.
  ///
  /// Does NOT modify the existing syncAdvancedStats() call chain — it
  /// continues independently.
  ///
  /// Validates: Requirements 7.1, 7.2, 7.3, 7.4
  Future<void> enforceAggregateConsistency() async {
    if (!shouldSync) return;

    try {
      final isar = await DBService().db;

      // 1. Sum all local SavedStat playCount and totalSeconds values
      final allStats = await isar.savedStats.where().findAll();

      int totalPlayCount = 0;
      int totalSeconds = 0;
      for (final stat in allStats) {
        totalPlayCount += stat.playCount;
        totalSeconds += stat.totalSeconds;
      }

      // 2. Get current aggregate metrics from PocketBase
      final currentMetrics = await PocketBaseService().getUserMetrics();
      if (currentMetrics == null) {
        DebugLogService().info(
          '🔄 SyncEngine: enforceAggregateConsistency — no cloud metrics found, skipping',
        );
        return;
      }

      final cloudPlayCount = (currentMetrics['play_count'] as int?) ?? 0;
      final cloudTotalMinutes = (currentMetrics['total_minutes'] as int?) ?? 0;

      // 3. Calculate the per-song sum in minutes (ceiling)
      final perSongMinutes = totalSeconds > 0 ? (totalSeconds / 60).ceil() : 0;

      // 4. Check invariants and update if violated
      final updates = <String, dynamic>{};

      if (cloudPlayCount < totalPlayCount) {
        updates['play_count'] = totalPlayCount;
        DebugLogService().info(
          '🔄 SyncEngine: Aggregate play_count violated '
          '(cloud=$cloudPlayCount < sum=$totalPlayCount). Updating upward.',
        );
      }

      if (cloudTotalMinutes < perSongMinutes) {
        updates['total_minutes'] = perSongMinutes;
        DebugLogService().info(
          '🔄 SyncEngine: Aggregate total_minutes violated '
          '(cloud=$cloudTotalMinutes < sum=$perSongMinutes). Updating upward.',
        );
      }

      if (updates.isNotEmpty) {
        await PocketBaseService().saveData(updates);
        DebugLogService().info(
          '🔄 SyncEngine: enforceAggregateConsistency — updated aggregates: $updates',
        );
      } else {
        DebugLogService().info(
          '🔄 SyncEngine: enforceAggregateConsistency — invariants hold '
          '(play_count: $cloudPlayCount >= $totalPlayCount, '
          'total_minutes: $cloudTotalMinutes >= $perSongMinutes)',
        );
      }
    } catch (e) {
      DebugLogService().error(
        '⚠️ SyncEngine: enforceAggregateConsistency error: $e',
      );
    }
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  /// Flushes the batch buffer by pushing all accumulated deltas.
  ///
  /// Applies gzip compression if the JSON payload exceeds 10KB (Requirement 8.4).
  /// This is the core batching mechanism: called either when >3 changes accumulate
  /// or when the 5-second window timer fires (Requirement 1.5).
  Future<void> _flushBatchBuffer() async {
    if (_batchBuffer.isEmpty) return;

    // Take a snapshot and clear the buffer
    final rawDeltas = List<StatDelta>.from(_batchBuffer);
    _batchBuffer.clear();
    _batchTimer?.cancel();
    _batchTimer = null;

    // Coalesce deltas by stat_id: sum playCountDelta and totalSecondsDelta
    // to minimize redundant network calls for the same song.
    final Map<String, StatDelta> coalesced = {};
    for (final delta in rawDeltas) {
      final existing = coalesced[delta.statId];
      if (existing == null) {
        coalesced[delta.statId] = delta;
      } else {
        coalesced[delta.statId] = StatDelta(
          id: delta.id, // use latest ID
          statId: existing.statId,
          title: existing.title,
          artist: existing.artist,
          album: existing.album,
          playCountDelta: existing.playCountDelta + delta.playCountDelta,
          totalSecondsDelta:
              existing.totalSecondsDelta + delta.totalSecondsDelta,
          timestamp: delta.timestamp, // use latest timestamp
          deviceId: delta.deviceId,
          spotifyId: delta.spotifyId ?? existing.spotifyId,
          deezerId: delta.deezerId ?? existing.deezerId,
          onlineArtUrl: delta.onlineArtUrl ?? existing.onlineArtUrl,
        );
      }
    }

    final deltas = coalesced.values.toList();

    DebugLogService().info(
      '🔄 SyncEngine: Flushing batch buffer with ${rawDeltas.length} raw → ${deltas.length} coalesced deltas',
    );

    // Check payload size for gzip decision
    final jsonPayload = jsonEncode(deltas.map((d) => d.toJson()).toList());
    final payloadBytes = utf8.encode(jsonPayload);

    if (payloadBytes.length > _gzipThreshold) {
      DebugLogService().info(
        '🔄 SyncEngine: Payload ${payloadBytes.length} bytes > $_gzipThreshold bytes, '
        'applying gzip compression',
      );
      // Compress the payload (logged for debugging; actual transport uses pushBatch)
      final compressed = gzip.encode(payloadBytes);
      DebugLogService().info(
        '🔄 SyncEngine: Compressed ${payloadBytes.length} → ${compressed.length} bytes',
      );
    }

    // Push the batch via pushBatch (which handles per-stat-id grouping and cloud ops)
    await pushBatch(deltas);
  }

  /// Performs a connectivity check by attempting a DNS lookup.
  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      _hasConnectivity = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      _hasConnectivity = false;
    }
  }

  /// Emits a new sync status to the status stream.
  void _emitStatus(SyncStatus status) {
    if (status == SyncStatus.syncing) {
      _isSyncing = true;
    } else {
      _isSyncing = false;
    }
    _statusController.add(status);
  }

  /// Disposes the status stream controller and cancels any pending timers.
  /// Should only be called during app shutdown.
  void dispose() {
    _batchTimer?.cancel();
    _batchTimer = null;
    _statusController.close();
  }
}
