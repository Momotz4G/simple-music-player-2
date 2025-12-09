import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../data/schemas.dart';
import '../services/db_service.dart';
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
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final isar = await _dbService.db;
    // Now Dart knows 'isar' is of type 'Isar', so it searches for extensions
    // defined in schemas.dart (which includes schemas.g.dart)
    final history = await isar.historyEntrys
        .where()
        .sortByLastPlayedDesc()
        .limit(50)
        .findAll();
    state = history;
  }

  Future<void> addToHistory(
      {required SongModel song, String? youtubeUrl, String? artUrl}) async {
    final isar = await _dbService.db;

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

    _loadHistory(); // Refresh state
  }

  Future<void> updateHistoryEntry(HistoryEntry entry) async {
    final isar = await _dbService.db;
    await isar.writeTxn(() async {
      await isar.historyEntrys.put(entry);
    });
    _loadHistory();
  }

  Future<void> clearHistory() async {
    final isar = await _dbService.db;
    await isar.writeTxn(() async {
      await isar.historyEntrys.clear();
    });
    state = [];
  }
}
