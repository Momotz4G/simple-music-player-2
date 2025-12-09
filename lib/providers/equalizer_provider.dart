import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equalizer_flutter/equalizer_flutter.dart';
import '../models/eq_preset.dart';

class EqualizerProvider extends ChangeNotifier {
  bool _isEnabled = false;
  EqPreset? _currentPreset;
  List<EqPreset> _savedPresets = [];

  // Initialize with Default Labels so they ALWAYS show up
  List<String> _freqLabels = ["60Hz", "230Hz", "910Hz", "3kHz", "14kHz"];

  bool get isEnabled => _isEnabled;
  EqPreset? get currentPreset => _currentPreset;
  List<EqPreset> get savedPresets => _savedPresets;
  List<String> get freqLabels => _freqLabels;

  int? _activeSessionId;

  EqualizerProvider() {
    _loadPresets();
  }

  Future<void> init(int sessionId) async {
    // ⚠️ Check Platform: Only run native logic on Android
    if (!Platform.isAndroid) return;

    if (_activeSessionId == sessionId) return;

    try {
      _activeSessionId = sessionId;
      await EqualizerFlutter.init(sessionId);
      // Determine if it was already enabled in the system
      // Note: we can't read 'getEnabled', so we rely on our state
      await EqualizerFlutter.setEnabled(_isEnabled);

      await _fetchDeviceBands();

      if (_currentPreset != null) {
        _applyToNative(_currentPreset!.gains);
      }
    } catch (e) {
      print("EQ Init Error: $e");
    }
  }

  Future<void> _fetchDeviceBands() async {
    if (!Platform.isAndroid) return;

    try {
      final centerFreqs = await EqualizerFlutter.getCenterBandFreqs();
      if (centerFreqs.isNotEmpty) {
        _freqLabels = centerFreqs.map((freq) {
          if (freq < 1000) return "${freq}Hz";
          return "${(freq / 1000).toStringAsFixed(1)}kHz";
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching bands: $e");
    }
  }

  Future<void> _loadPresets() async {
    _savedPresets = [
      EqPreset(id: 'flat', name: 'Flat', gains: [0, 0, 0, 0, 0]),
      EqPreset(id: 'bass', name: 'Bass Boost', gains: [8, 6, 0, 0, 0]),
      EqPreset(id: 'rock', name: 'Rock', gains: [5, 3, -1, 3, 5]),
      EqPreset(id: 'pop', name: 'Pop', gains: [-1, 2, 5, 1, -2]),
      EqPreset(id: 'vocal', name: 'Vocal', gains: [-3, -1, 4, 3, 1]),
    ];

    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getStringList('custom_eq_presets');
    if (savedJson != null) {
      for (String str in savedJson) {
        _savedPresets.add(EqPreset.fromJson(str));
      }
    }

    _currentPreset = _savedPresets.first;
    notifyListeners();
  }

  Future<void> toggleEnabled(bool val) async {
    _isEnabled = val;
    if (Platform.isAndroid && _activeSessionId != null) {
      try {
        await EqualizerFlutter.setEnabled(val);
      } catch (e) {
        print("EQ Enable Error: $e");
      }
    }
    notifyListeners();
  }

  void loadPreset(EqPreset preset) {
    _currentPreset = preset;
    _applyToNative(preset.gains);
    notifyListeners();
  }

  void updateBand(int index, double gain) {
    if (_currentPreset == null) return;

    final newGains = List<double>.from(_currentPreset!.gains);
    newGains[index] = gain;

    _currentPreset =
        EqPreset(id: 'custom_temp', name: 'Custom', gains: newGains);

    _applyToNative(newGains);
    notifyListeners();
  }

  void _applyToNative(List<double> gains) {
    if (Platform.isAndroid && _isEnabled && _activeSessionId != null) {
      try {
        for (int i = 0; i < gains.length; i++) {
          // Native EQ expects millibels (mB). 1 dB = 100 mB.
          EqualizerFlutter.setBandLevel(i, (gains[i] * 100).toInt());
        }
      } catch (e) {
        print("EQ Apply Error: $e");
      }
    }
  }

  Future<void> deletePreset(String id) async {
    // 1. Protect default presets
    if (['flat', 'bass', 'rock', 'pop', 'vocal'].contains(id)) return;

    // 2. Remove from memory
    _savedPresets.removeWhere((p) => p.id == id);

    // 3. CRITICAL : Save to storage IMMEDIATELY
    await _saveToPrefs();

    // 4. Update Selection
    // If we deleted the one currently playing, switch back to Flat
    if (_currentPreset?.id == id) {
      loadPreset(_savedPresets.first);
    } else {
      notifyListeners();
    }
  }

  Future<void> saveCurrentAsNew(String name) async {
    if (_currentPreset == null) return;

    final newPreset = EqPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      gains: List.from(_currentPreset!.gains),
    );

    _savedPresets.add(newPreset);
    _currentPreset = newPreset;

    _saveToPrefs();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final customPresets = _savedPresets
        .where((p) => !['flat', 'bass', 'rock', 'pop', 'vocal'].contains(p.id))
        .map((p) => p.toJson())
        .toList();
    await prefs.setStringList('custom_eq_presets', customPresets);
  }
}

final equalizerProvider = ChangeNotifierProvider<EqualizerProvider>((ref) {
  return EqualizerProvider();
});
