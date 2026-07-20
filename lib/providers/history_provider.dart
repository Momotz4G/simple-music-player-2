import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/schemas.dart';
import '../services/db_service.dart';
import '../services/debug_log_service.dart';
import '../services/sync_engine.dart';
import 'db_provider.dart';
import '../models/song_model.dart';

// The provider returns a List of HistoryEntry objects, not Strings
final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryEntry>>((ref) {
  final db = ref.watch(dbServiceProvider);
  return HistoryNotifier(db);
});

class HistoryNotifier extends StateNotifier<List<HistoryEntry>> {
  final DBService _dbService;

  HistoryNotifier(this._dbService) : super([]) {
    DebugLogService()
        .info("📚 HISTORY: HistoryNotifier initialized, loading history...");
    _loadHistory();
    // Register for cloud history merge notifications
    SyncEngine().addOnHistoryMergeCompleteListener(_onRemoteHistoryMerged);
  }

  @override
  void dispose() {
    SyncEngine().removeOnHistoryMergeCompleteListener(_onRemoteHistoryMerged);
    super.dispose();
  }

  /// Called by SyncEngine when pullRecentHistory inserts new remote entries.
  void _onRemoteHistoryMerged() {
    _loadHistory();
  }

  /// Triggers a cloud pull and refreshes local history.
  /// Call this when the history page is opened to get fresh data from other devices.
  Future<void> refreshFromCloud() async {
    try {
      await SyncEngine().pullRecentHistory();
      // _loadHistory is triggered via the merge callback above,
      // but reload explicitly in case there were no changes
      await _loadHistory();
    } catch (e) {
      DebugLogService().error("📚 HISTORY: refreshFromCloud error: $e");
    }
  }

  bool _hasAttemptedRecovery = false;

  Future<void> _loadHistory() async {
    DebugLogService().info("📚 HISTORY: Loading history from Isar...");
    try {
      final isar = await _dbService.db;

      // LOCAL FUTURE-TIMESTAMP AUTO-RECOVERY
      try {
        final List<HistoryEntry> entriesToSync = [];
        await isar.writeTxn(() async {
          final futureEntries = await isar.historyEntrys
              .filter()
              .lastPlayedGreaterThan(
                  DateTime.now().add(const Duration(minutes: 5)))
              .findAll();

          if (futureEntries.isNotEmpty) {
            DebugLogService().warning(
                "📚 HISTORY: Found ${futureEntries.length} entries trapped in the future. Correcting...");
            final offset = DateTime.now().timeZoneOffset;
            for (final entry in futureEntries) {
              entry.lastPlayed = entry.lastPlayed.subtract(offset);
              if (entry.lastPlayed.isAfter(DateTime.now())) {
                entry.lastPlayed = DateTime.now();
              }
            }
            await isar.historyEntrys.putAll(futureEntries);
            entriesToSync.addAll(futureEntries);
          }
        });

        // Sync corrected entries outside of writeTxn to avoid deadlocks
        // Process sequentially to prevent HTTP connection exhaustion
        for (final entry in entriesToSync) {
          await SyncEngine().pushHistoryEntry(entry);
        }
      } catch (e) {
        DebugLogService()
            .error("📚 HISTORY: Auto-recovery failed, but continuing load: $e");
      }

      final history = await isar.historyEntrys
          .where()
          .sortByLastPlayedDesc()
          .limit(50)
          .findAll();
      state = history;
      DebugLogService().info("📚 HISTORY: Loaded ${history.length} entries");
      _hasAttemptedRecovery = false; // Reset on success
    } catch (e, stack) {
      DebugLogService().error("📚 HISTORY: Failed to load history: $e");

      // AUTO-RECOVERY FOR CORRUPTED DATABASE
      if (e.toString().contains("MdbxError") ||
          e.toString().contains("IsarError")) {
        if (!_hasAttemptedRecovery) {
          DebugLogService().warning(
              "💥 HISTORY: Database corruption detected! Attempting RESET...");
          _hasAttemptedRecovery = true;

          await _dbService.recoverFromCorruption();

          // Retry once
          DebugLogService().info("🔄 HISTORY: Retrying load after reset...");
          await _loadHistory();
          return;
        }
      }

      DebugLogService().error("📚 HISTORY: Stack: $stack");
    }
  }

  /// Extracts the primary artist name from a potentially multi-artist string.
  /// e.g. "Ziv Zaifman, Hugh Jackman, Michelle Williams" → "ziv zaifman"
  ///      "The Weeknd feat. Daft Punk"                   → "the weeknd"
  static String _primaryArtist(String artist) {
    String primary = artist.trim();
    // Split on common multi-artist separators and take the first
    for (final sep in [
      ',',
      ' feat.',
      ' feat ',
      ' ft.',
      ' ft ',
      ' & ',
      ' x ',
      ' X ',
      ' and '
    ]) {
      final idx = primary.toLowerCase().indexOf(sep.toLowerCase());
      if (idx > 0) {
        primary = primary.substring(0, idx).trim();
        break;
      }
    }
    return primary.toLowerCase();
  }

  Future<void> addToHistory(
      {required SongModel song, String? youtubeUrl, String? artUrl}) async {
    DebugLogService()
        .info("📚 HISTORY: Adding to history: ${song.title} by ${song.artist}");
    final isar = await _dbService.db;

    try {
      // Declare entry outside the transaction so it's accessible for cloud sync
      final entry = HistoryEntry()
        ..title = song.title
        ..artist = song.artist
        ..album = song.album
        ..duration = song.duration
        ..originalFilePath = song.filePath
        ..youtubeUrl = youtubeUrl ?? ""
        ..albumArtUrl = artUrl ?? ""
        ..isStream = youtubeUrl != null && youtubeUrl.isNotEmpty
        ..lastPlayed = DateTime.now()
        ..spotifyId = song.spotifyId
        ..deezerId = song.deezerId;

      await isar.writeTxn(() async {
        // 1. Remove existing entry for this song (so it moves to top)
        // Multi-strategy dedup to handle artist name mismatches
        // across sources (e.g. "Ziv Zaifman" vs "Ziv Zaifman, Hugh Jackman, Michelle Williams")
        // Strategy A: Match by stable ID (spotifyId or deezerId) — most reliable
        if (song.spotifyId != null && song.spotifyId!.isNotEmpty) {
          await isar.historyEntrys
              .filter()
              .spotifyIdEqualTo(song.spotifyId)
              .deleteAll();
        }
        if (song.deezerId != null && song.deezerId!.isNotEmpty) {
          await isar.historyEntrys
              .filter()
              .deezerIdEqualTo(song.deezerId)
              .deleteAll();
        }

        // Strategy B: Match by title (case-insensitive) + primary artist overlap
        // This catches entries from different sources where the full artist
        // string varies but the primary artist is the same song.
        final titleMatches = await isar.historyEntrys
            .filter()
            .titleEqualTo(song.title, caseSensitive: false)
            .findAll();
        if (titleMatches.isNotEmpty) {
          final songPrimary = _primaryArtist(song.artist);
          final idsToDelete = <int>[];
          for (final existing in titleMatches) {
            final existingPrimary = _primaryArtist(existing.artist);
            if (songPrimary == existingPrimary) {
              idsToDelete.add(existing.id);
            }
          }
          if (idsToDelete.isNotEmpty) {
            await isar.historyEntrys.deleteAll(idsToDelete);
            DebugLogService().info(
                "📚 HISTORY: Fuzzy dedup removed ${idsToDelete.length} old entries for '${song.title}'");
          }
        }

        // 2. Add New Entry
        await isar.historyEntrys.put(entry);
        DebugLogService().info("📚 HISTORY: Saved entry with ID: ${entry.id}");

        // 3. Trim: Keep only top 50
        final count = await isar.historyEntrys.count();
        if (count > 50) {
          // Find the oldest ones and delete them
          final oldest = await isar.historyEntrys
              .where()
              .sortByLastPlayed() // Oldest first
              .limit(count - 50)
              .findAll();
          await isar.historyEntrys.deleteAll(oldest.map((e) => e.id).toList());
        }
      });

      // Push history entry to cloud sync after local Isar insert
      SyncEngine().pushHistoryEntry(entry);

      await _loadHistory(); // Refresh state (NOW AWAITED!)
    } catch (e) {
      DebugLogService().error("📚 HISTORY: Error saving history: $e");
    }
  }

  Future<void> updateHistoryEntry(HistoryEntry entry) async {
    final isar = await _dbService.db;
    await isar.writeTxn(() async {
      await isar.historyEntrys.put(entry);
    });
    await _loadHistory();
  }

  Future<void> clearHistory() async {
    final isar = await _dbService.db;
    await isar.writeTxn(() async {
      await isar.historyEntrys.clear();
    });
    state = [];
    // Also wipe cloud history for this user so the clear is permanent
    // and doesn't come back on next pull.
    try {
      final cleared = await SyncEngine().clearCloudHistory();
      if (!cleared) {
        // Offline / sync disabled — remember the clear so we can apply it
        // once sync resumes, preventing cloud entries from being pulled back.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pending_cloud_history_clear', true);
        DebugLogService().info(
            "📚 HISTORY: Cloud clear deferred (offline/sync off). Will apply on next sync.");
      }
    } catch (e) {
      DebugLogService().error("📚 HISTORY: Cloud clear failed: $e");
    }
  }
}
