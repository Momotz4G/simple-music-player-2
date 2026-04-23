import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'audio_engine_ffi.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState, PlayerState;

/// Commands sent from Main Isolate to Audio Worker Isolate
enum _EngineCmd {
  load,
  play,
  pause,
  stop,
  seek,
  volume,
  eq,
  device,
  release,
  dispose
}

/// Messages sent from Audio Worker Isolate to Main Isolate
class _EngineStatus {
  final double position;
  final double duration;
  final bool isPlaying;
  final bool isCompleted;
  final bool loadSuccess;
  final String? error;

  _EngineStatus({
    this.position = 0.0,
    this.duration = 0.0,
    this.isPlaying = false,
    this.isCompleted = false,
    this.loadSuccess = true,
    this.error,
  });
}

class FfiAudioPlayer {
  final BehaviorSubject<Duration> _positionSubject = BehaviorSubject.seeded(Duration.zero);
  final BehaviorSubject<Duration?> _durationSubject = BehaviorSubject.seeded(null);
  final BehaviorSubject<PlayerState> _playerStateSubject = BehaviorSubject.seeded(
      PlayerState(false, ProcessingState.idle));
  
  Stream<Duration> get positionStream => _positionSubject.stream;
  Stream<Duration?> get durationStream => _durationSubject.stream;
  Stream<PlayerState> get playerStateStream => _playerStateSubject.stream;
  
  Duration get position => _positionSubject.value;
  Duration? get duration => _durationSubject.value;
  bool get playing => _playerStateSubject.value.playing;
  ProcessingState get processingState => _playerStateSubject.value.processingState;

  SendPort? _commandPort;
  ReceivePort? _statusPort;
  bool _initialized = false;
  bool get isReady => _initialized;

  FfiAudioPlayer() {
    _initWorker();
  }

  Future<void> _initWorker() async {
    if (_initialized) return;

    _statusPort = ReceivePort();
    
    // 🚀 SPAWN PERSISTENT WORKER:
    // We pass the status port to the worker.
    await Isolate.spawn(_engineWorkerMain, _statusPort!.sendPort);

    // Listen for events from the worker
    _statusPort!.listen((message) {
      if (message is SendPort) {
        _commandPort = message;
        _initialized = true;
        debugPrint("🚀 FFI Player: Worker Isolate Ready (STA Protected)");
      } else if (message is _EngineStatus) {
        _handleStatusUpdate(message);
      }
    });

    // Wait for initialization
    await _ensureReady();
  }

  void _handleStatusUpdate(_EngineStatus status) {
    if (status.error != null) {
      debugPrint("❌ FFI Status Error: ${status.error}");
      return;
    }

    // Update position and duration
    final pos = Duration(milliseconds: (status.position * 1000).toInt());
    final dur = status.duration > 0 
        ? Duration(milliseconds: (status.duration * 1000).toInt()) 
        : null;

    if (_positionSubject.value != pos) _positionSubject.add(pos);
    if (_durationSubject.value != dur) _durationSubject.add(dur);

    // Update player state
    ProcessingState state = ProcessingState.ready;
    if (status.isCompleted) state = ProcessingState.completed;
    if (!status.loadSuccess) state = ProcessingState.idle;

    final currentPlaying = _playerStateSubject.value.playing;
    final currentState = _playerStateSubject.value.processingState;

    if (currentPlaying != status.isPlaying || currentState != state) {
      _playerStateSubject.add(PlayerState(status.isPlaying, state));
    }
  }

  Future<void> _ensureReady() async {
    while (!_initialized || _commandPort == null) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void _sendCommand(_EngineCmd cmd, [dynamic args]) {
    if (_commandPort == null) return;
    _commandPort!.send({'cmd': cmd, 'args': args});
  }

  Future<void> setDevice(String? deviceId) async {
    await _ensureReady();
    _sendCommand(_EngineCmd.device, deviceId);
  }

  Future<void> setFilePath(String path, {bool bitPerfect = false}) async {
    await _ensureReady();
    _playerStateSubject.add(PlayerState(false, ProcessingState.loading));
    _sendCommand(_EngineCmd.load, {'path': path, 'bitPerfect': bitPerfect});
  }

  Future<void> play() async {
    await _ensureReady();
    _sendCommand(_EngineCmd.play);
    _playerStateSubject.add(PlayerState(true, processingState));
  }

  Future<void> pause() async {
    await _ensureReady();
    _sendCommand(_EngineCmd.pause);
    _playerStateSubject.add(PlayerState(false, processingState));
  }

  Future<void> stop() async {
    await _ensureReady();
    _sendCommand(_EngineCmd.stop);
    _playerStateSubject.add(PlayerState(false, ProcessingState.idle));
    _positionSubject.add(Duration.zero);
  }

  Future<void> releaseDevice() async {
    await _ensureReady();
    _sendCommand(_EngineCmd.release);
    _playerStateSubject.add(PlayerState(false, ProcessingState.idle));
    _positionSubject.add(Duration.zero);
    _durationSubject.add(null);
  }

  Future<void> seek(Duration position) async {
    await _ensureReady();
    _sendCommand(_EngineCmd.seek, position.inMilliseconds / 1000.0);
    _positionSubject.add(position);
  }

  Future<void> setVolume(double volume) async {
    await _ensureReady();
    _sendCommand(_EngineCmd.volume, volume);
  }

  void setEQBand(int index, double freq, double gain, double q) {
    _sendCommand(_EngineCmd.eq, {
      'index': index,
      'freq': freq,
      'gain': gain,
      'q': q,
    });
  }

  Future<void> dispose() async {
    _sendCommand(_EngineCmd.dispose);
    _statusPort?.close();
  }

  // ---------------------------------------------------------------------------
  // 🚀 WORKER ISOLATE ENTRY POINT
  // ---------------------------------------------------------------------------
  static void _engineWorkerMain(SendPort mainSendPort) {
    // 1. Initialize FFI in this isolate
    AudioEngineFfi.initialize();
    final handle = AudioEngineFfi.create();
    
    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort);

    Timer? pollingTimer;

    void sendStatus({bool loadSuccess = true, String? error}) {
      final pos = AudioEngineFfi.getPosition(handle);
      final dur = AudioEngineFfi.getDuration(handle);
      
      mainSendPort.send(_EngineStatus(
        position: pos.isFinite ? pos : 0.0,
        duration: dur.isFinite ? dur : 0.0,
        isPlaying: AudioEngineFfi.isPlaying(handle),
        isCompleted: AudioEngineFfi.isCompleted(handle),
        loadSuccess: loadSuccess,
        error: error,
      ));
    }

    commandPort.listen((message) {
      if (message is! Map) return;
      final cmd = message['cmd'] as _EngineCmd;
      final args = message['args'];

      try {
        switch (cmd) {
          case _EngineCmd.load:
            final path = args['path'] as String;
            final bp = args['bitPerfect'] as bool;
            final success = AudioEngineFfi.playFile(handle, path, bp);
            sendStatus(loadSuccess: success);
            
            // Start polling when a file is loaded
            pollingTimer?.cancel();
            pollingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => sendStatus());
            break;
            
          case _EngineCmd.play:
            AudioEngineFfi.play(handle);
            sendStatus();
            break;
            
          case _EngineCmd.pause:
            AudioEngineFfi.pause(handle);
            sendStatus();
            break;
            
          case _EngineCmd.stop:
            AudioEngineFfi.stop(handle);
            pollingTimer?.cancel();
            sendStatus();
            break;
            
          case _EngineCmd.seek:
            AudioEngineFfi.setPosition(handle, args as double);
            sendStatus();
            break;
            
          case _EngineCmd.volume:
            AudioEngineFfi.setVolume(handle, args as double);
            break;
            
          case _EngineCmd.eq:
            AudioEngineFfi.setEQBand(
              handle, 
              args['index'] as int, 
              args['freq'] as double, 
              args['gain'] as double, 
              args['q'] as double
            );
            break;
            
          case _EngineCmd.device:
            AudioEngineFfi.setOutputDevice(handle, args as String?);
            break;
            
          case _EngineCmd.release:
            AudioEngineFfi.releaseDevice(handle);
            pollingTimer?.cancel();
            sendStatus();
            break;
            
          case _EngineCmd.dispose:
            pollingTimer?.cancel();
            AudioEngineFfi.dispose(handle);
            Isolate.current.kill();
            break;
        }
      } catch (e) {
        sendStatus(error: e.toString());
      }
    });
  }
}
