import 'dart:ffi' as ffi;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'audio_engine_ffi.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState, PlayerState;

class FfiAudioPlayer {
  late final ffi.Pointer<ffi.Void> _handle;
  
  final BehaviorSubject<Duration> _positionSubject = BehaviorSubject.seeded(Duration.zero);
  final BehaviorSubject<Duration?> _durationSubject = BehaviorSubject.seeded(null);
  final BehaviorSubject<PlayerState> _playerStateSubject = BehaviorSubject.seeded(
      PlayerState(false, ProcessingState.idle));
  
  Timer? _pollingTimer;

  Stream<Duration> get positionStream => _positionSubject.stream;
  Stream<Duration?> get durationStream => _durationSubject.stream;
  Stream<PlayerState> get playerStateStream => _playerStateSubject.stream;
  
  Duration get position => _positionSubject.value;
  Duration? get duration => _durationSubject.value;
  bool get playing => _playerStateSubject.value.playing;
  ProcessingState get processingState => _playerStateSubject.value.processingState;

  FfiAudioPlayer() {
    AudioEngineFfi.initialize();
    _handle = AudioEngineFfi.create();
  }

  void _updateState() {
    if (!AudioEngineFfi.isInitialized()) return;
    
    final posSec = AudioEngineFfi.getPosition(_handle);
    final durSec = AudioEngineFfi.getDuration(_handle);
    final isPlaying = AudioEngineFfi.isPlaying(_handle);
    final isCompleted = AudioEngineFfi.isCompleted(_handle);

    // 🚀 SAFETY GUARD: Prevent crash if engine returns NaN/Infinity
    final safePos = posSec.isFinite ? posSec : 0.0;
    final safeDur = durSec.isFinite ? durSec : 0.0;

    _positionSubject.add(Duration(milliseconds: (safePos * 1000).toInt()));
    _durationSubject.add(Duration(milliseconds: (safeDur * 1000).toInt()));

    ProcessingState state = ProcessingState.ready;
    if (isCompleted) state = ProcessingState.completed;
    
    final currentState = _playerStateSubject.value;
    if (currentState.playing != isPlaying || currentState.processingState != state) {
      _playerStateSubject.add(PlayerState(isPlaying, state));
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      _updateState();
    });
  }

  Future<void> setFilePath(String path) async {
    _playerStateSubject.add(PlayerState(false, ProcessingState.loading));
    final success = AudioEngineFfi.playFile(_handle, path);
    if (!success) {
      debugPrint("❌ FFI Engine: Failed to load file: $path");
      _playerStateSubject.add(PlayerState(false, ProcessingState.idle));
      return;
    }
    debugPrint("✅ FFI Engine: File loaded successfully");
    _playerStateSubject.add(PlayerState(false, ProcessingState.ready));
    _startPolling();
  }

  Future<void> play() async {
    AudioEngineFfi.play(_handle);
    _playerStateSubject.add(PlayerState(true, processingState));
  }

  Future<void> pause() async {
    AudioEngineFfi.pause(_handle);
    _playerStateSubject.add(PlayerState(false, processingState));
  }

  Future<void> stop() async {
    AudioEngineFfi.stop(_handle);
    _playerStateSubject.add(PlayerState(false, ProcessingState.idle));
    _pollingTimer?.cancel();
    _positionSubject.add(Duration.zero);
  }

  Future<void> seek(Duration position) async {
    AudioEngineFfi.setPosition(_handle, position.inMilliseconds / 1000.0);
    _positionSubject.add(position);
  }

  Future<void> setVolume(double volume) async {
    AudioEngineFfi.setVolume(_handle, volume);
  }

  /// 🚀 Specific for EQ engine routing
  void setEQBand(int index, double freq, double gain, double q) {
    AudioEngineFfi.setEQBand(_handle, index, freq, gain, q);
  }

  Future<void> dispose() async {
    _pollingTimer?.cancel();
    AudioEngineFfi.dispose(_handle);
  }
}
