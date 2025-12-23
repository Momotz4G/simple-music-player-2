import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// Global audio handler instance - set during app initialization
late MyAudioHandler audioHandler;

/// Custom AudioHandler that integrates just_audio with Android MediaSession
class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;

  // Callbacks to communicate with PlayerNotifier
  Function()? onPlay;
  Function()? onPause;
  Function()? onSkipToNext;
  Function()? onSkipToPrevious;
  Function(Duration)? onSeek;

  MyAudioHandler(this._player) {
    // Listen to player state changes and update media session
    _player.playbackEventStream.listen(_broadcastState);
    _player.playerStateStream.listen((state) {
      _broadcastState(_player.playbackEvent);
    });
  }

  /// Update the currently playing media item (call this when song changes)
  Future<void> setCurrentSong({
    required String title,
    required String artist,
    String? album,
    Uri? artUri,
    Duration? duration,
  }) async {
    final item = MediaItem(
      id: title,
      title: title,
      artist: artist,
      album: album ?? '',
      artUri: artUri,
      duration: duration ?? Duration.zero,
    );
    mediaItem.add(item);
    // Broadcast current state to trigger notification update
    _broadcastState(_player.playbackEvent);
  }

  /// Update artwork from file path
  Future<void> updateArtworkFromFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;

    try {
      final file = File(filePath);
      if (await file.exists()) {
        final currentItem = mediaItem.value;
        if (currentItem != null) {
          mediaItem.add(currentItem.copyWith(artUri: Uri.file(filePath)));
        }
      }
    } catch (e) {
      debugPrint('Error updating artwork: $e');
    }
  }

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  @override
  Future<void> play() async {
    await _player.play(); // Actually start playback - triggers notification
    onPlay?.call();
  }

  @override
  Future<void> pause() async {
    await _player.pause(); // Actually pause playback
    onPause?.call();
  }

  @override
  Future<void> skipToNext() async {
    onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPrevious?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    onSeek?.call(position);
    await _player.seek(position);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }
}

/// Initialize audio service - call this in main() before runApp()
Future<MyAudioHandler> initAudioService(AudioPlayer player) async {
  return await AudioService.init(
    builder: () => MyAudioHandler(player),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.momotz4g.simplemusicplayer2.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
    ),
  );
}
