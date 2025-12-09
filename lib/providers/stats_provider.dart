import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';
import '../models/stat_model.dart';
import '../models/song_model.dart';
import '../data/schemas.dart';
import 'db_provider.dart';
import 'settings_provider.dart';
import '../services/metrics_service.dart';

class StatsState {
  final Map<String, StatEntry> entries;
  StatsState({this.entries = const {}});
}

class StatsNotifier extends StateNotifier<StatsState> {
  final Ref ref;
  static const int _maxEntries = 10000;

  StatsNotifier(this.ref) : super(StatsState()) {
    _loadStats();
  }

  Future<void> _loadStats() async {
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;

    // 1. Check if migration is needed
    final prefs = ref.read(sharedPrefsProvider);
    if (prefs.containsKey('extended_stats')) {
      await _migrateFromPrefs(prefs, isar);
    }

    // 2. Load from Isar
    final savedStats = await isar.savedStats.where().findAll();
    final Map<String, StatEntry> loaded = {};

    for (var s in savedStats) {
      loaded[s.statId] = StatEntry(
        id: s.statId,
        title: s.title,
        artist: s.artist,
        album: s.album,
        playCount: s.playCount,
        totalSeconds: s.totalSeconds,
        lastKnownPath: s.lastKnownPath,
      );
    }

    state = StatsState(entries: loaded);
  }

  Future<void> _migrateFromPrefs(SharedPreferences prefs, Isar isar) async {
    print("🔄 MIGRATING STATS TO ISAR...");
    final String? data = prefs.getString('extended_stats');
    if (data != null) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(data) as Map<String, dynamic>;

        await isar.writeTxn(() async {
          for (var value in decoded.values) {
            final entry = StatEntry.fromJson(value as Map<String, dynamic>);

            // Check if already exists
            final existing = await isar.savedStats
                .filter()
                .statIdEqualTo(entry.id)
                .findFirst();

            if (existing == null) {
              final newStat = SavedStat()
                ..statId = entry.id
                ..title = entry.title
                ..artist = entry.artist
                ..album = entry.album
                ..playCount = entry.playCount
                ..totalSeconds = entry.totalSeconds
                ..lastKnownPath = entry.lastKnownPath
                ..onlineArtUrl = null // Prefs didn't have this
                ..youtubeUrl = null; // Prefs didn't have this

              await isar.savedStats.put(newStat);
            }
          }
        });

        // Clear prefs after successful migration
        await prefs.remove('extended_stats');
        print("✅ MIGRATION COMPLETE");
      } catch (e) {
        print("❌ Migration Failed: $e");
      }
    }
  }

  // --- LOGIC: ADD PLAY COUNT ---
  Future<void> logPlay(SongModel song) async {
    final id = StatEntry.generateId(
        song.title.trim(), song.artist.trim(), song.album.trim());

    // Update State (Optimistic UI)
    final currentEntries = {...state.entries};
    final current = currentEntries[id];
    StatEntry updatedEntry;

    if (current != null) {
      updatedEntry = current.copyWith(
        playCount: current.playCount + 1,
        lastKnownPath: song.filePath,
      );
    } else {
      updatedEntry = StatEntry(
        id: id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        playCount: 1,
        totalSeconds: 0,
        lastKnownPath: song.filePath,
      );
    }
    currentEntries[id] = updatedEntry;
    state = StatsState(entries: currentEntries);

    // Persist to Isar
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;

    await isar.writeTxn(() async {
      final existing =
          await isar.savedStats.filter().statIdEqualTo(id).findFirst();

      if (existing != null) {
        existing.playCount += 1;
        existing.lastKnownPath = song.filePath;
        // Update metadata if available
        if (song.onlineArtUrl != null) {
          existing.onlineArtUrl = song.onlineArtUrl;
        }
        if (song.sourceUrl != null) existing.youtubeUrl = song.sourceUrl;

        await isar.savedStats.put(existing);
      } else {
        final newStat = SavedStat()
          ..statId = id
          ..title = song.title
          ..artist = song.artist
          ..album = song.album
          ..playCount = 1
          ..totalSeconds = 0
          ..lastKnownPath = song.filePath
          ..onlineArtUrl = song.onlineArtUrl
          ..youtubeUrl = song.sourceUrl;

        await isar.savedStats.put(newStat);
      }
    });

    // Track in Cloud (Stats Page Logic)
    final totalPlays =
        state.entries.values.fold(0, (sum, e) => sum + e.playCount);
    MetricsService().trackSongPlayModel(song, localTotal: totalPlays);

    print(
        "📈 STATS SAVED (Isar): ${song.title} (Count: ${updatedEntry.playCount})");
  }

  // --- LOGIC: ADD LISTENING TIME ---
  Future<void> logTime(SongModel song, int seconds) async {
    if (seconds <= 0) return;

    final id = StatEntry.generateId(
        song.title.trim(), song.artist.trim(), song.album.trim());

    // Update State
    final currentEntries = {...state.entries};
    final liveEntry = currentEntries[id];
    StatEntry updatedEntry;

    if (liveEntry != null) {
      updatedEntry = liveEntry.copyWith(
        totalSeconds: liveEntry.totalSeconds + seconds,
      );
    } else {
      updatedEntry = StatEntry(
        id: id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        playCount: 0,
        totalSeconds: seconds,
        lastKnownPath: song.filePath,
      );
    }
    currentEntries[id] = updatedEntry;
    state = StatsState(entries: currentEntries);

    // Persist to Isar
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;

    await isar.writeTxn(() async {
      final existing =
          await isar.savedStats.filter().statIdEqualTo(id).findFirst();

      if (existing != null) {
        existing.totalSeconds += seconds;
        await isar.savedStats.put(existing);
      } else {
        final newStat = SavedStat()
          ..statId = id
          ..title = song.title
          ..artist = song.artist
          ..album = song.album
          ..playCount = 0
          ..totalSeconds = seconds
          ..lastKnownPath = song.filePath
          ..onlineArtUrl = song.onlineArtUrl
          ..youtubeUrl = song.sourceUrl;

        await isar.savedStats.put(newStat);
      }
    });
  }

  Future<void> resetStats() async {
    state = StatsState();
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;

    await isar.writeTxn(() async {
      await isar.savedStats.clear();
    });
  }

  Future<void> updateMetadata(String id,
      {String? artUrl, String? youtubeUrl}) async {
    // 1. Update Local State
    final currentEntries = {...state.entries};
    final entry = currentEntries[id];
    if (entry == null) return;

    final updatedEntry = entry.copyWith(
      onlineArtUrl: artUrl ?? entry.onlineArtUrl,
      youtubeUrl: youtubeUrl ?? entry.youtubeUrl,
    );
    currentEntries[id] = updatedEntry;
    state = StatsState(entries: currentEntries);

    // 2. Update Isar
    final dbService = ref.read(dbServiceProvider);
    final isar = await dbService.db;

    await isar.writeTxn(() async {
      final existing =
          await isar.savedStats.filter().statIdEqualTo(id).findFirst();
      if (existing != null) {
        if (artUrl != null) existing.onlineArtUrl = artUrl;
        if (youtubeUrl != null) existing.youtubeUrl = youtubeUrl;
        await isar.savedStats.put(existing);
      }
    });
  }
}

final statsProvider = StateNotifierProvider<StatsNotifier, StatsState>((ref) {
  return StatsNotifier(ref);
});
