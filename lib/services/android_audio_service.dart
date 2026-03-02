import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AndroidAudioService {
  static const MethodChannel _channel =
      MethodChannel('com.momotz4g.simplemusicplayer2/audio_settings');

  /// Check if the device is running Android 14 (API 34) or higher
  static Future<bool> isBitPerfectSupported() async {
    if (!Platform.isAndroid) return false;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt >= 34;
    } catch (e) {
      debugPrint("Error checking Android version: $e");
      return false;
    }
  }

  /// Enable or disable Bit-Perfect mode (Android 14+)
  static Future<bool> setBitPerfectMode(bool enable) async {
    if (!Platform.isAndroid) return false;

    try {
      final success = await _channel
          .invokeMethod<bool>('setBitPerfectMode', {'enable': enable});
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint("Failed to set bit-perfect mode: ${e.message}");
      return false;
    }
  }

  /// Get native audio output info (sample rate, device, bit-perfect status)
  static Future<Map<String, dynamic>?> getNativeOutputInfo() async {
    if (!Platform.isAndroid) return null;

    try {
      final result =
          await _channel.invokeMethod<Map>('getNativeOutputSampleRate');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint("Failed to get native output info: ${e.message}");
      return null;
    }
  }
}
