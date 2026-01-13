import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../data/schemas.dart';
import '../services/db_service.dart';
import '../services/debug_log_service.dart';
import 'db_provider.dart';
import '../models/song_model.dart';

// The provider now returns a List of HistoryEntry objects, not Strings
final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryEntry>>((ref) {
  final db = ref.watch(dbServiceProvider);
  return HistoryNotifier(db);
});

class HistoryNotifier extends StateNotifier<List<HistoryEntry>> {
  final DBService
      _dbService; // Using dynamic to avoid circular dep issues for now

  HistoryNotifier(this._dbService) : super([]) {
    DebugLogService()
        .info("📚 HISTORY: HistoryNotifier initialized, loading history...");
    _loadHistory();
  }

  bool _hasAttemptedRecovery = false;

  Future<void> _loadHistory() async {
    DebugLogService().info("📚 HISTORY: Loading history from Isar...");
    try {
      final isar = await _dbService.db;
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

      // 🚀 AUTO-RECOVERY FOR CORRUPTED DATABASE
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

  Future<void> addToHistory(
      {required SongModel song, String? youtubeUrl, String? artUrl}) async {
    DebugLogService()
        .info("📚 HISTORY: Adding to history: ${song.title} by ${song.artist}");
    final isar = await _dbService.db;

    try {
      await isar.writeTxn(() async {
        // 1. Remove existing entry for this song (so it moves to top)
        // We match by Title + Artist because path might change (temp files)
        await isar.historyEntrys
            .filter()
            .titleEqualTo(song.title)
            .and()
            .artistEqualTo(song.artist)
            .deleteAll();

        // 2. Add New Entry
        final entry = HistoryEntry()
          ..title = song.title
          ..artist = song.artist
          ..album = song.album
          ..duration = song.duration
          ..originalFilePath = song.filePath
          ..youtubeUrl = youtubeUrl ?? "" // Important for re-streaming
          ..albumArtUrl = artUrl ?? "" // Important for UI
          ..isStream = youtubeUrl != null && youtubeUrl.isNotEmpty
          ..lastPlayed = DateTime.now();

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
  }
}
