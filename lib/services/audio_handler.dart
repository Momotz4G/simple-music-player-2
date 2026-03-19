import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'native_music_service.dart'; // 🚀 FIXED IMPORT

/// The "Side-Car" that talks to the Android Notification System
class MusicHandler extends BaseAudioHandler {
  final Stream<PlaybackEvent> _playbackEventStream;
  bool _isPlaying = false; // 🚀 Manually track playing state

  // Callbacks for queue navigation (since NativeMusicService doesn't know about Queue)
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;

  MusicHandler(this._playbackEventStream) {
    // Only listening to the active stream provided by NativeMusicService
    _playbackEventStream.listen(_broadcastState);
    // Listen to playerStateStream to track _isPlaying reliably
    NativeMusicService().playerStateStream.listen((state) {
      _isPlaying = state.playing;
    });
  }

  /// Broadcasts the current state of the player to the OS
  Future<void> _broadcastState(PlaybackEvent event) async {
    // The player object is no longer directly accessible here.
    final playing = _isPlaying; // Use tracked playing state
    final processingState = const {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[event.processingState]!; // Use event.processingState

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
      updatePosition: event.updatePosition, // Use event.updatePosition
      bufferedPosition: event.bufferedPosition, // Use event.bufferedPosition
      speed: 1.0, // Fixed default speed since it's not in PlaybackEvent
      queueIndex: event.currentIndex,
    ));
  }

  // --- OS COMMANDS (The "Police" telling us what to do) ---

  @override
  Future<void> play() async {
    final NativeMusicService _musicService = NativeMusicService();
    await _musicService.resume();
  }

  @override
  Future<void> pause() async {
    final NativeMusicService _musicService = NativeMusicService();
    await _musicService.pause();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.ready,
      playing: false,
    ));
    await super.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    final NativeMusicService _musicService = NativeMusicService();
    await _musicService.seek(position.inSeconds.toDouble());
  }

  @override
  Future<void> skipToNext() async {
    debugPrint("🎵 Notification: User pressed Next");
    onSkipNext?.call();
  }

  @override
  Future<void> onTaskRemoved() async {
    debugPrint("🎵 Notification: Task Removed (App Swiped Away)");
    await stop();
    // 🚀 DO NOT DISPOSE here. It can cause race condition crashes if late events fire.
    // exit(0) will clean up the OS process resources.
    exit(0);
  }

  @override
  Future<void> stop() async {
    final NativeMusicService _musicService = NativeMusicService();
    await _musicService.stop();
    // 2. Broadcast stopped state to AudioService so notification disappears
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle, // Reverted to original correct state
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
