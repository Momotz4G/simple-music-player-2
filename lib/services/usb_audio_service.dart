import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// USB Audio Service - Flutter interface for USB Audio DAC playback.
/// Provides bit-perfect audio bypass for Android < 14.
class UsbAudioService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.momotz4g.simplemusicplayer2/usb_audio');
  static const EventChannel _eventChannel =
      EventChannel('com.momotz4g.simplemusicplayer2/usb_audio_events');

  static StreamSubscription? _eventSubscription;

  // Callbacks
  static Function(UsbAudioState)? _onStateChange;
  static Function(int current, int total)? _onProgress;
  static Function(String error)? _onError;

  // ============ Setup ============

  /// Initialize event stream listeners
  static void init({
    Function(UsbAudioState)? onStateChange,
    Function(int current, int total)? onProgress,
    Function(String error)? onError,
  }) {
    _onStateChange = onStateChange;
    _onProgress = onProgress;
    _onError = onError;

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (error) {
        debugPrint("UsbAudioService event error: $error");
      },
    );
  }

  /// Handle events from native code
  static void _handleEvent(dynamic event) {
    if (event is Map) {
      final type = event['type'] as String?;
      final data = event['data'] as Map?;

      switch (type) {
        case 'stateChange':
          final stateName = data?['state'] as String?;
          if (stateName != null && _onStateChange != null) {
            _onStateChange!(UsbAudioState.fromString(stateName));
          }
          break;
        case 'progress':
          final current = data?['current'] as int?;
          final total = data?['total'] as int?;
          if (current != null && total != null && _onProgress != null) {
            _onProgress!(current, total);
          }
          break;
        case 'error':
          final message = data?['message'] as String?;
          if (message != null && _onError != null) {
            _onError!(message);
          }
          break;
      }
    }
  }

  /// Cleanup resources
  static void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _invokeMethod('dispose');
  }

  // ============ Device Discovery ============

  /// Check if USB audio is supported on this device
  static Future<bool> isUsbAudioSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _invokeMethod<bool>('isUsbAudioSupported') ?? false;
    } catch (e) {
      debugPrint("isUsbAudioSupported error: $e");
      return false;
    }
  }

  /// Check if any USB DAC is connected
  static Future<bool> isDacAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _invokeMethod<bool>('isDacAvailable') ?? false;
    } catch (e) {
      debugPrint("isDacAvailable error: $e");
      return false;
    }
  }

  /// Get list of connected USB DACs
  static Future<List<UsbDacDevice>> getConnectedDacs() async {
    if (!Platform.isAndroid) return [];

    try {
      final result = await _invokeMethod<List>('getConnectedDacs');
      if (result == null) return [];

      return result.map((dac) {
        final dacMap = Map<String, dynamic>.from(dac as Map);
        return UsbDacDevice(
          deviceName: dacMap['deviceName'] as String? ?? 'Unknown DAC',
          vendorId: dacMap['vendorId'] as int? ?? 0,
          productId: dacMap['productId'] as int? ?? 0,
          maxPacketSize: dacMap['maxPacketSize'] as int? ?? 0,
          supportedSampleRates: (dacMap['supportedSampleRates'] as List?)
                  ?.map((e) => e as int)
                  .toList() ??
              [],
        );
      }).toList();
    } catch (e) {
      debugPrint("getConnectedDacs error: $e");
      return [];
    }
  }

  // ============ Connection ============

  /// Open connection to a specific DAC
  static Future<bool> openDac(UsbDacDevice dac) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _invokeMethod<bool>('openDac', {
        'vendorId': dac.vendorId,
        'productId': dac.productId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint("openDac error: ${e.message}");
      return false;
    }
  }

  /// Open connection to the built-in Android AudioTrack (Bypass OS mixer)
  static Future<bool> openBuiltInDac() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _invokeMethod<bool>('openBuiltInDac');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint("openBuiltInDac error: ${e.message}");
      return false;
    }
  }

  /// Close current DAC connection
  static Future<void> closeDac() async {
    if (!Platform.isAndroid) return;
    await _invokeMethod('closeDac');
  }

  /// Get info about the currently active DAC
  static Future<UsbDacDevice?> getActiveDacInfo() async {
    if (!Platform.isAndroid) return null;

    try {
      final result = await _invokeMethod<Map>('getActiveDacInfo');
      if (result == null) return null;

      final dacMap = Map<String, dynamic>.from(result);
      return UsbDacDevice(
        deviceName: dacMap['deviceName'] as String? ?? 'Unknown DAC',
        vendorId: dacMap['vendorId'] as int? ?? 0,
        productId: dacMap['productId'] as int? ?? 0,
        maxPacketSize: dacMap['maxPacketSize'] as int? ?? 0,
        supportedSampleRates: [],
      );
    } catch (e) {
      debugPrint("getActiveDacInfo error: $e");
      return null;
    }
  }

  // ============ Playback ============

  /// Prepare a file for playback
  static Future<bool> prepareFile(String path) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _invokeMethod<bool>('prepareFile', {'path': path});
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint("prepareFile error: ${e.message}");
      return false;
    }
  }

  /// Start playback
  static Future<bool> play() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _invokeMethod<bool>('play');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint("play error: ${e.message}");
      return false;
    }
  }

  /// Pause playback
  static Future<void> pause() async {
    if (!Platform.isAndroid) return;
    await _invokeMethod('pause');
  }

  /// Resume playback
  static Future<bool> resume() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _invokeMethod<bool>('resume');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint("resume error: ${e.message}");
      return false;
    }
  }

  /// Stop playback
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _invokeMethod('stop');
  }

  /// Seek to position in milliseconds
  static Future<void> seek(int positionMs) async {
    if (!Platform.isAndroid) return;
    await _invokeMethod('seek', {'positionMs': positionMs});
  }

  /// Set the engine volume (0.0 to 1.0)
  static Future<void> setVolume(double volume) async {
    if (!Platform.isAndroid) return;
    await _invokeMethod('setVolume', {'volume': volume});
  }

  // ============ Status & Info ============

  /// Get current player state
  static Future<UsbAudioState> getState() async {
    if (!Platform.isAndroid) return UsbAudioState.idle;

    try {
      final result = await _invokeMethod<String>('getState');
      return UsbAudioState.fromString(result ?? 'IDLE');
    } catch (e) {
      return UsbAudioState.idle;
    }
  }

  /// Get current audio format
  static Future<UsbAudioFormat?> getAudioFormat() async {
    if (!Platform.isAndroid) return null;

    try {
      final result = await _invokeMethod<Map>('getAudioFormat');
      if (result == null) return null;

      return UsbAudioFormat(
        sampleRate: result['sampleRate'] as int? ?? 44100,
        bitDepth: result['bitDepth'] as int? ?? 16,
        channels: result['channels'] as int? ?? 2,
      );
    } catch (e) {
      return null;
    }
  }

  // ============ Helper ============

  static Future<T?> _invokeMethod<T>(String method,
      [Map<String, dynamic>? arguments]) async {
    try {
      return await _methodChannel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      debugPrint("UsbAudioService.$method error: ${e.message}");
      rethrow;
    }
  }
}

/// USB DAC device information
class UsbDacDevice {
  final String deviceName;
  final int vendorId;
  final int productId;
  final int maxPacketSize;
  final List<int> supportedSampleRates;

  const UsbDacDevice({
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    required this.maxPacketSize,
    this.supportedSampleRates = const [],
  });

  @override
  String toString() =>
      'UsbDacDevice($deviceName, VID:$vendorId, PID:$productId)';
}

/// Audio format information
class UsbAudioFormat {
  final int sampleRate;
  final int bitDepth;
  final int channels;

  const UsbAudioFormat({
    required this.sampleRate,
    required this.bitDepth,
    required this.channels,
  });

  @override
  String toString() => '${sampleRate}Hz/${bitDepth}bit/${channels}ch';
}

/// USB Audio player state enum
enum UsbAudioState {
  idle,
  preparing,
  playing,
  paused,
  stopped,
  error;

  static UsbAudioState fromString(String name) {
    switch (name.toUpperCase()) {
      case 'IDLE':
        return UsbAudioState.idle;
      case 'PREPARING':
        return UsbAudioState.preparing;
      case 'PLAYING':
        return UsbAudioState.playing;
      case 'PAUSED':
        return UsbAudioState.paused;
      case 'STOPPED':
        return UsbAudioState.stopped;
      case 'ERROR':
        return UsbAudioState.error;
      default:
        return UsbAudioState.idle;
    }
  }
}
