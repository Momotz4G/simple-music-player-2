import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';

class NativeMusicService {
  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  Future<void> load(SongModel song) async {
    try {
      debugPrint("🎵 Service Pre-Loading: ${song.title}");
      await _player.stop();
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.file(song.filePath),
          tag: song,
        ),
      );
    } catch (e) {
      debugPrint("❌ Service Load Error: $e");
    }
  }

  Future<void> play(SongModel song) async {
    try {
      debugPrint("🎵 Service Loading: ${song.title}");

      // 1. Stop previous playback explicitly to clear buffers
      await _player.stop();

      // 2. Load the file
      // We pass the SongModel as a tag, which might be useful for some implementations,
      // but primarily we rely on the file path.
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.file(song.filePath),
          tag: song, // Pass model as tag (generic object)
        ),
      );

      // 3. Force Play
      _player.play();
    } catch (e) {
      debugPrint("❌ Service Error: $e");
    }
  }

  Future<void> pause() async => await _player.pause();
  Future<void> resume() async => await _player.play();

  Future<void> seek(double seconds) async =>
      await _player.seek(Duration(seconds: seconds.toInt()));

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await _player.setLoopMode(mode);
  }

  void dispose() {
    _player.dispose();
  }
}
