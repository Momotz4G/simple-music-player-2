import 'package:flutter/foundation.dart';

/// Lightweight global signal for "is the player currently doing something
/// IO-heavy" — i.e. loading, buffering, or actively playing.
///
/// Background services (e.g. [LoudnessScannerService]) read this to back off
/// and avoid contending with the audio decoder for disk + Dart event-loop
/// time during the critical first seconds of FLAC/MQA playback.
///
/// by `PlayerNotifier` from the music service player-state stream.
class PlayerActivityNotifier {
  PlayerActivityNotifier._();

  static final ValueNotifier<bool> _active = ValueNotifier<bool>(false);

  /// Listenable handle for widgets/services that want to react to changes.
  static ValueListenable<bool> get listenable => _active;

  /// True when the player is loading, buffering, or playing.
  static bool get isActive => _active.value;

  /// Set the active state. No-ops if the value hasn't changed.
  static set isActive(bool value) {
    if (_active.value != value) _active.value = value;
  }
}
