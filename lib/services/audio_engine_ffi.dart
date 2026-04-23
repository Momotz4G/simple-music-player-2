import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';

typedef EngineCreateFunc = ffi.Pointer<ffi.Void> Function();
typedef EngineCreate = ffi.Pointer<ffi.Void> Function();

typedef EngineDisposeFunc = ffi.Void Function(ffi.Pointer<ffi.Void> handle);
typedef EngineDispose = void Function(ffi.Pointer<ffi.Void> handle);

typedef EngineReleaseDeviceFunc = ffi.Void Function(ffi.Pointer<ffi.Void> handle);
typedef EngineReleaseDevice = void Function(ffi.Pointer<ffi.Void> handle);

typedef EngineSetOutputDeviceFunc = ffi.Void Function(ffi.Pointer<ffi.Void> handle, ffi.Pointer<Utf8> deviceId);
typedef EngineSetOutputDevice = void Function(ffi.Pointer<ffi.Void> handle, ffi.Pointer<Utf8> deviceId);

typedef EnginePlayFileFunc = ffi.Bool Function(ffi.Pointer<ffi.Void> handle, ffi.Pointer<Utf8> filepath, ffi.Bool bitPerfect);
typedef EnginePlayFile = bool Function(ffi.Pointer<ffi.Void> handle, ffi.Pointer<Utf8> filepath, bool bitPerfect);

typedef EnginePlayFunc = ffi.Void Function(ffi.Pointer<ffi.Void> handle);
typedef EnginePlay = void Function(ffi.Pointer<ffi.Void> handle);

typedef EnginePauseFunc = ffi.Void Function(ffi.Pointer<ffi.Void> handle);
typedef EnginePause = void Function(ffi.Pointer<ffi.Void> handle);

typedef EngineStopFunc = ffi.Void Function(ffi.Pointer<ffi.Void> handle);
typedef EngineStop = void Function(ffi.Pointer<ffi.Void> handle);

typedef EngineSetVolumeFunc = ffi.Void Function(ffi.Pointer<ffi.Void> handle, ffi.Float volume);
typedef EngineSetVolume = void Function(ffi.Pointer<ffi.Void> handle, double volume);

typedef EngineSetEQBandFunc = ffi.Void Function(ffi.Pointer<ffi.Void> handle, ffi.Int32 bandIndex, ffi.Float frequency, ffi.Float gain, ffi.Float qFactor);
typedef EngineSetEQBand = void Function(ffi.Pointer<ffi.Void> handle, int bandIndex, double frequency, double gain, double qFactor);

typedef EngineGetPositionFunc = ffi.Float Function(ffi.Pointer<ffi.Void> handle);
typedef EngineGetPosition = double Function(ffi.Pointer<ffi.Void> handle);

typedef EngineSetPositionFunc = ffi.Void Function(ffi.Pointer<ffi.Void> handle, ffi.Float position);
typedef EngineSetPosition = void Function(ffi.Pointer<ffi.Void> handle, double position);

typedef EngineGetDurationFunc = ffi.Float Function(ffi.Pointer<ffi.Void> handle);
typedef EngineGetDuration = double Function(ffi.Pointer<ffi.Void> handle);

typedef EngineIsPlayingFunc = ffi.Bool Function(ffi.Pointer<ffi.Void> handle);
typedef EngineIsPlaying = bool Function(ffi.Pointer<ffi.Void> handle);

typedef EngineIsCompletedFunc = ffi.Bool Function(ffi.Pointer<ffi.Void> handle);
typedef EngineIsCompleted = bool Function(ffi.Pointer<ffi.Void> handle);

class AudioEngineFfi {
  static late final ffi.DynamicLibrary _lib;
  static bool _initialized = false;
  static bool isInitialized() => _initialized;

  static late final EngineCreate create;
  static late final EngineDispose dispose;
  static late final EngineReleaseDevice releaseDevice;
  static late final EngineSetOutputDevice setOutputDeviceNative;
  static late final EnginePlayFile playFileNative;
  static late final EnginePlay play;
  static late final EnginePause pause;
  static late final EngineStop stop;
  static late final EngineSetVolume setVolume;
  static late final EngineSetEQBand setEQBand;
  static late final EngineGetPosition getPosition;
  static late final EngineSetPosition setPosition;
  static late final EngineGetDuration getDuration;
  static late final EngineIsPlaying isPlaying;
  static late final EngineIsCompleted isCompleted;

  static void initialize() {
    if (_initialized) return;

    if (Platform.isWindows) {
      _lib = ffi.DynamicLibrary.open('audio_engine.dll');
    } else {
      throw UnsupportedError('AudioEngineFfi is currently Windows-only fallback');
    }

    create = _lib.lookupFunction<EngineCreateFunc, EngineCreate>('Engine_Create');
    dispose = _lib.lookupFunction<EngineDisposeFunc, EngineDispose>('Engine_Dispose');
    releaseDevice = _lib.lookupFunction<EngineReleaseDeviceFunc, EngineReleaseDevice>('Engine_ReleaseDevice');
    setOutputDeviceNative = _lib.lookupFunction<EngineSetOutputDeviceFunc, EngineSetOutputDevice>('Engine_SetOutputDevice');
    playFileNative = _lib.lookupFunction<EnginePlayFileFunc, EnginePlayFile>('Engine_PlayFile');
    play = _lib.lookupFunction<EnginePlayFunc, EnginePlay>('Engine_Play');
    pause = _lib.lookupFunction<EnginePauseFunc, EnginePause>('Engine_Pause');
    stop = _lib.lookupFunction<EngineStopFunc, EngineStop>('Engine_Stop');
    setVolume = _lib.lookupFunction<EngineSetVolumeFunc, EngineSetVolume>('Engine_SetVolume');
    setEQBand = _lib.lookupFunction<EngineSetEQBandFunc, EngineSetEQBand>('Engine_SetEQBand');
    getPosition = _lib.lookupFunction<EngineGetPositionFunc, EngineGetPosition>('Engine_GetPosition');
    setPosition = _lib.lookupFunction<EngineSetPositionFunc, EngineSetPosition>('Engine_SetPosition');
    getDuration = _lib.lookupFunction<EngineGetDurationFunc, EngineGetDuration>('Engine_GetDuration');
    isPlaying = _lib.lookupFunction<EngineIsPlayingFunc, EngineIsPlaying>('Engine_IsPlaying');
    isCompleted = _lib.lookupFunction<EngineIsCompletedFunc, EngineIsCompleted>('Engine_IsCompleted');

    _initialized = true;
  }

  static bool playFile(ffi.Pointer<ffi.Void> handle, String filepath, bool bitPerfect) {
    if (!_initialized) initialize();
    final ptr = filepath.toNativeUtf8();
    final result = playFileNative(handle, ptr, bitPerfect);
    malloc.free(ptr);
    return result;
  }

  static void setOutputDevice(ffi.Pointer<ffi.Void> handle, String? deviceId) {
    if (!_initialized) initialize();
    if (deviceId == null) {
      setOutputDeviceNative(handle, ffi.Pointer.fromAddress(0));
    } else {
      final ptr = deviceId.toNativeUtf8();
      setOutputDeviceNative(handle, ptr);
      malloc.free(ptr);
    }
  }
}
