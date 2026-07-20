/// 10-Band Cross-Platform Equalizer Engine
///
/// Uses mpv's built-in `superequalizer` audio filter (via media_kit).
/// Works on all platforms where media_kit/just_audio_media_kit is active.
///
/// Band mapping: 10 ISO standard bands → mpv superequalizer's 18 bands.
library eq_engine;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'native_music_service.dart'; // ADDED

class EqEngine {
  EqEngine._(); // Static-only class

  static const _channel = MethodChannel('com.momotz4g.simple_music_player/equalizer');

  /// 10 ISO standard center frequencies (Hz)
  static const List<int> bandFrequencies = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];

  /// Human-readable labels for UI
  static const List<String> bandLabels = [
    '31', '62', '125', '250', '500', '1k', '2k', '4k', '8k', '16k',
  ];

  static const int bandCount = 10;

  /// Apply 10-band EQ gains.
  /// On Android, uses native DynamicsProcessing via MethodChannel.
  /// On Windows, uses custom C++ engine via FFI.
  static Future<void> apply({
    required List<double> gains,
    double preampDb = 0.0,
    int? audioSessionId,
  }) async {
    if (gains.length != bandCount) {
      throw ArgumentError(
          'EqEngine.apply requires exactly $bandCount gain values');
    }

    if (Platform.isAndroid) {
      if (audioSessionId == null) return;
      
      try {
        await _channel.invokeMethod('apply', {
          'sessionId': audioSessionId,
          'gains': gains,
          'preamp': preampDb,
        });
      } on PlatformException catch (e) {
        debugPrint("Failed to apply native Android EQ: ${e.message}");
      }
    } else if (Platform.isWindows) {
      // Windows: Route EQ through NativeMusicService which forwards to FFI players
      // in their worker isolates. We MUST NOT call AudioEngineFfi.initialize() here
      // because it loads audio_engine.dll on the main thread, which sets COM to MTA mode
      // and permanently breaks the FilePicker (which requires STA mode).
      NativeMusicService().setWindowsEQ(
        gains: gains,
        preampDb: preampDb,
      );
    } else {
      // Linux/macOS Streaming EQ (via mpv filters)
      final filter = getMpvFilterString(gains, preampDb);
      try {
        await JustAudioMediaKit.setAudioFilter(filter);
      } catch (e) {
        debugPrint("Failed to apply MediaKit EQ filter: $e");
      }
    }
  }

  /// Bypass (disable) the EQ.
  static Future<void> bypass(int? audioSessionId) async {
    if (Platform.isAndroid && audioSessionId != null) {
      await _channel.invokeMethod('bypass', {
        'sessionId': audioSessionId,
      });
    } else if (Platform.isWindows) {
      // Reset FFI EQ (routed through NativeMusicService worker isolates)
      NativeMusicService().setWindowsEQ(
        gains: List.filled(bandCount, 0.0),
        preampDb: 0.0,
      );
    }
    
    // Clear MediaKit filters on bypass (skip Windows — lavfi filters don't work there)
    if (!Platform.isWindows) {
      try {
        await JustAudioMediaKit.setAudioFilter("");
      } catch (e) {
        debugPrint("Failed to clear MediaKit filters: $e");
      }
    }
  }

  /// Generate mpv / FFmpeg audio filter string for 10-band EQ
  /// Uses a chain of 10 peaking 'equalizer' filters.
  /// NOTE: mpv does NOT support 'volume' as an af filter (causes "Option af: volume doesn't exist").
  /// Preamp is incorporated by adding it to each band's gain value instead.
  static String getMpvFilterString(List<double> gains, double preampDb) {
    // Check if all gains (including preamp applied) would be zero
    final hasActiveGains = gains.any((g) => (g + preampDb) != 0);
    if (!hasActiveGains && preampDb == 0) return "";

    final List<String> filters = [];

    // Apply bands with preamp baked into each band's gain
    // This avoids using the 'volume' af filter which mpv doesn't support
    for (int i = 0; i < bandCount; i++) {
        final gain = gains[i] + preampDb; // Incorporate preamp into each band
        if (gain == 0) continue; // Optimization: skip 0dB bands
        
        final freq = bandFrequencies[i];
        filters.add('equalizer=f=$freq:t=q:w=1.41:g=${gain.toStringAsFixed(2)}');
    }

    if (filters.isEmpty) return "";

    // Combine into a comma-separated chain
    return filters.join(',');
  }
}

