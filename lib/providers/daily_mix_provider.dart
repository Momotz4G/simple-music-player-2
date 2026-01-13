import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_mix_model.dart';
import '../services/daily_mix_service.dart';
import 'stats_provider.dart';

/// State for the daily mixes
class DailyMixState {
  final List<DailyMix> mixes;
  final bool isLoading;
  final String? error;

  const DailyMixState({
    this.mixes = const [],
    this.isLoading = false,
    this.error,
  });

  DailyMixState copyWith({
    List<DailyMix>? mixes,
    bool? isLoading,
    String? error,
  }) {
    return DailyMixState(
      mixes: mixes ?? this.mixes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing daily mix state
class DailyMixNotifier extends StateNotifier<DailyMixState> {
  final DailyMixService _service;
  final Ref _ref;

  DailyMixNotifier(this._ref, this._service) : super(const DailyMixState());

  /// Load the daily mixes (uses cache if fresh)
  Future<void> loadMixes() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final stats = _ref.read(statsProvider).entries;
      final mixes = await _service.getDailyMixes(stats);

      state = DailyMixState(
        mixes: mixes,
        isLoading: false,
      );
    } catch (e) {
      print("❌ DailyMixNotifier: Error loading mixes: $e");
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Force refresh the mixes (ignore cache)
  Future<void> refreshMixes() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final stats = _ref.read(statsProvider).entries;
      final mixes = await _service.refreshMixes(stats);

      state = DailyMixState(
        mixes: mixes,
        isLoading: false,
      );
    } catch (e) {
      print("❌ DailyMixNotifier: Error refreshing mixes: $e");
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Clear the cache
  Future<void> clearCache() async {
    await _service.clearCache();
    state = const DailyMixState();
  }
}

/// Provider for the daily mix service
final dailyMixServiceProvider = Provider<DailyMixService>((ref) {
  return DailyMixService();
});

/// Provider for the daily mix state
final dailyMixProvider =
    StateNotifierProvider<DailyMixNotifier, DailyMixState>((ref) {
  final service = ref.watch(dailyMixServiceProvider);
  return DailyMixNotifier(ref, service);
});
