import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_provider.dart';
import '../services/flac_downloader_service.dart'; // Added
import '../services/youtube_downloader_service.dart'; // Added
import '../services/canvas_service.dart'; // Added
import '../services/apple_music_backend_service.dart'; // Added

import 'dart:convert'; // Added for JSON encoding

class DataUsageState {
  final int totalBytes;
  final Map<String, int> dailyBytes; // {'2026-03-15': 12345}

  DataUsageState({this.totalBytes = 0, this.dailyBytes = const {}});

  String get formattedSize => _format(totalBytes);

  String _format(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  // Breakdown Getters
  int get todayBytes {
    final now = DateTime.now();
    return dailyBytes[_getKey(now)] ?? 0;
  }

  int get weekBytes {
    final now = DateTime.now();
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      sum += dailyBytes[_getKey(day)] ?? 0;
    }
    return sum;
  }

  int get monthBytes {
    final now = DateTime.now();
    int sum = 0;
    for (int i = 0; i < 30; i++) {
      final day = now.subtract(Duration(days: i));
      sum += dailyBytes[_getKey(day)] ?? 0;
    }
    return sum;
  }

  String get todayFormatted => _format(todayBytes);
  String get weekFormatted => _format(weekBytes);
  String get monthFormatted => _format(monthBytes);

  String _getKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}

class DataUsageNotifier extends StateNotifier<DataUsageState> {
  final SharedPreferences _prefs;
  static const String _prefKeyTotal = 'total_data_usage_bytes';
  static const String _prefKeyDaily = 'daily_data_usage_map';

  DataUsageNotifier(this._prefs) : super(DataUsageState()) {
    _load();
  }

  void _load() {
    final bytes = _prefs.getInt(_prefKeyTotal) ?? 0;
    final dailyJson = _prefs.getString(_prefKeyDaily);
    Map<String, int> daily = {};
    
    if (dailyJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(dailyJson);
        daily = decoded.map((key, value) => MapEntry(key, value as int));
      } catch (_) {}
    }
    
    state = DataUsageState(totalBytes: bytes, dailyBytes: daily);
  }

  Future<void> addBytes(int bytes) async {
    if (bytes <= 0) return;

    final now = DateTime.now();
    final todayKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final newTotal = state.totalBytes + bytes;
    final Map<String, int> newDaily = Map.from(state.dailyBytes);
    newDaily[todayKey] = (newDaily[todayKey] ?? 0) + bytes;

    // Prune entries older than 35 days to prevent JSON bloating
    final cutoff = now.subtract(const Duration(days: 35));
    newDaily.removeWhere((key, value) {
      final date = DateTime.tryParse(key);
      if (date == null) return true;
      return date.isBefore(cutoff);
    });

    state = DataUsageState(totalBytes: newTotal, dailyBytes: newDaily);

    await _prefs.setInt(_prefKeyTotal, newTotal);
    await _prefs.setString(_prefKeyDaily, jsonEncode(newDaily));
  }

  Future<void> reset() async {
    state = DataUsageState(totalBytes: 0, dailyBytes: const {});
    await _prefs.remove(_prefKeyTotal);
    await _prefs.remove(_prefKeyDaily);
  }
}

final dataUsageProvider = StateNotifierProvider<DataUsageNotifier, DataUsageState>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  
  // Wire up singletons for background data usage tracking
  FlacDownloaderService.globalRef = ref;
  YoutubeDownloaderService.globalRef = ref;
  CanvasService.globalRef = ref; // Added
  AppleMusicBackendService.globalRef = ref; // Added

  return DataUsageNotifier(prefs);
});
