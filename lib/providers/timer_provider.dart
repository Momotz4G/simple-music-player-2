import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'player_provider.dart';

class TimerState {
  final bool isActive;
  final Duration remaining;
  TimerState({this.isActive = false, this.remaining = Duration.zero});
}

class TimerNotifier extends StateNotifier<TimerState> {
  // Store Ref so we can check the Player State before stopping
  final Ref _ref;
  Timer? _timer;

  TimerNotifier(this._ref) : super(TimerState());

  void startTimer(Duration duration) {
    _cancel(); // Stop any existing timer
    state = TimerState(isActive: true, remaining: duration);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final newRemaining = state.remaining - const Duration(seconds: 1);

      if (newRemaining.inSeconds <= 0) {
        // --- TIME'S UP LOGIC ---

        // 1. Get the current Player State
        final playerState = _ref.read(playerProvider);

        // 2. Only toggle if it is CURRENTLY PLAYING
        if (playerState.isPlaying) {
          _ref.read(playerProvider.notifier).togglePlay();
        }

        // 3. Reset Timer
        cancelTimer();
      } else {
        state = TimerState(isActive: true, remaining: newRemaining);
      }
    });
  }

  void cancelTimer() {
    _cancel();
    state = TimerState(isActive: false, remaining: Duration.zero);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }
}

// Pass 'ref' into the Notifier
final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier(ref);
});
