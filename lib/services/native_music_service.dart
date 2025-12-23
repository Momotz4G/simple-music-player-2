import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';

class NativeMusicService {
  // Singleton pattern - ensures same player instance everywhere
  static final NativeMusicService _instance = NativeMusicService._internal();
  factory NativeMusicService() => _instance;
  NativeMusicService._internal();

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  Future<void> load(SongModel song) async {
    try {
      debugPrint("🎵 Service Pre-Loading: ${song.title}");
      debugPrint("🎵 File Path: ${song.filePath}");

      // Check if file exists
      final file = File(song.filePath);
      if (!await file.exists()) {
        debugPrint(
            "❌ Service Load Error: File does not exist at ${song.filePath}");
        return;
      }

      await _player.stop();

      // Use Uri.parse for better cross-platform compatibility
      final uri = Uri.file(song.filePath);
      debugPrint("🎵 URI: $uri");

      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          tag: song,
        ),
      );
      debugPrint("🎵 Pre-Load Success");
    } catch (e, stackTrace) {
      debugPrint("❌ Service Load Error: $e");
      debugPrint("❌ Stack trace: $stackTrace");
    }
  }

  Future<void> play(SongModel song) async {
    try {
      debugPrint("🎵 Service Loading: ${song.title}");
      debugPrint("🎵 File Path: ${song.filePath}");

      // 1. Check if file exists first
      final file = File(song.filePath);
      final exists = await file.exists();
      debugPrint("🎵 File exists: $exists");

      if (!exists) {
        debugPrint("❌ Service Error: File does not exist at ${song.filePath}");
        // Try to list parent directory to debug
        try {
          final parent = file.parent;
          if (await parent.exists()) {
            debugPrint("📂 Parent directory exists: ${parent.path}");
            final files = await parent.list().toList();
            debugPrint(
                "📂 Files in directory: ${files.map((f) => f.path.split('/').last).toList()}");
          } else {
            debugPrint("❌ Parent directory does not exist: ${parent.path}");
          }
        } catch (e) {
          debugPrint("❌ Error listing parent: $e");
        }
        return;
      }

      final fileSize = await file.length();
      debugPrint("🎵 File size: ${fileSize} bytes");

      // 2. Stop previous playback explicitly to clear buffers
      await _player.stop();

      // 3. Load the file using Uri.file for proper path handling
      final uri = Uri.file(song.filePath);
      debugPrint("🎵 Playing URI: $uri");

      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          tag: song,
        ),
      );
      debugPrint("🎵 Audio source set successfully");

      // 4. Force Play
      await _player.play();
      debugPrint("🎵 Play command sent");
    } catch (e, stackTrace) {
      debugPrint("❌ Service Error: $e");
      debugPrint("❌ Stack trace: $stackTrace");
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
