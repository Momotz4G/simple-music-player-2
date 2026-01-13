import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// The "Side-Car" that talks to the Android Notification System
class MusicHandler extends BaseAudioHandler {
  final AudioPlayer _player;

  // Callbacks for queue navigation (since NativeMusicService doesn't know about Queue)
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;

  MusicHandler(this._player) {
    // 1. Listen to playback events (Play/Pause/Buffering)
    _player.playbackEventStream.listen(_broadcastState);

    // 2. Listen to position actions (Seekbar)
    // Note: just_audio broadcasts position in playbackEventStream mostly, but specific position stream helps
  }

  /// Broadcasts the current state of the player to the OS
  Future<void> _broadcastState(PlaybackEvent event) async {
    final playing = _player.playing;
    final processingState = const {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[_player.processingState]!;

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2], // Prev, Play/Pause, Next
      playing: playing,
      processingState: processingState,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  // --- OS COMMANDS (The "Police" telling us what to do) ---

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    debugPrint("🎵 Notification: User pressed Next");
    onSkipNext?.call();
  }

  @override
  Future<void> onTaskRemoved() async {
    debugPrint("🎵 Notification: Task Removed (App Swiped Away)");
    await stop();
    await _player.dispose();
    // Force exit the Dart process to fully stop the notification
    exit(0);
  }

  @override
  Future<void> stop() async {
    // 1. Stop the player
    await _player.stop();
    // 2. Broadcast stopped state to AudioService so notification disappears
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint("🎵 Notification: User pressed Prev");
    onSkipPrevious?.call();
  }
}
