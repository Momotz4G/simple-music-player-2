import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/eq_preset.dart';
import '../services/eq_engine.dart';
import 'player_provider.dart';

class EqualizerProvider extends ChangeNotifier {
  final Ref _ref;
  bool _isEnabled = false;
  EqPreset? _currentPreset;
  List<EqPreset> _savedPresets = [];
  double _preampGain = 0.0;
  int? _audioSessionId;

  // 10-band ISO standard labels (matching EqEngine)
  List<String> get freqLabels => EqEngine.bandLabels;

  bool get isEnabled => _isEnabled;
  EqPreset? get currentPreset => _currentPreset;
  List<EqPreset> get savedPresets => _savedPresets;
  double get preampGain => _preampGain;
  int get bandCount => EqEngine.bandCount;

  EqualizerProvider(this._ref) {
    _loadPresets();
    _loadState();
    
    // Listen to session ID changes from PlayerProvider
    _ref.listen<int?>(playerProvider.select((s) => s.audioSessionId), (prev, next) {
      if (next != null && next != _audioSessionId) {
        setAudioSessionId(next);
      }
    });
  }

  /// Initialize EQ — called when the player is ready.
  /// No longer needs a session ID (mpv filters are set via JustAudioMediaKit).
  Future<void> init([int? sessionId]) async {
    if (sessionId != null) {
      _audioSessionId = sessionId;
    }
    // Re-apply current EQ state to native
    if (_isEnabled && _currentPreset != null) {
      await _applyToNative(_currentPreset!.gains);
    }
  }

  void setAudioSessionId(int? id) {
    if (_audioSessionId == id) return;
    _audioSessionId = id;
    if (_isEnabled && _currentPreset != null) {
      _applyToNative(_currentPreset!.gains);
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('eq_enabled') ?? false;
    _preampGain = prefs.getDouble('eq_preamp') ?? 0.0;
    final presetId = prefs.getString('eq_active_preset');
    if (presetId != null) {
      final found = _savedPresets.where((p) => p.id == presetId);
      if (found.isNotEmpty) {
        _currentPreset = found.first;
      }
    }

    // Apply on startup if enabled
    if (_isEnabled && _currentPreset != null) {
      _applyToNative(_currentPreset!.gains);
    }

    notifyListeners();
  }

  Future<void> _loadPresets() async {
    // 10-band default presets
    _savedPresets = [
      EqPreset(id: 'flat', name: 'Flat', gains: List.filled(10, 0.0)),
      EqPreset(id: 'bass_boost', name: 'Bass Boost', gains: [8, 6, 4, 2, 0, 0, 0, 0, 0, 0]),
      EqPreset(id: 'treble_boost', name: 'Treble Boost', gains: [0, 0, 0, 0, 0, 0, 2, 4, 6, 8]),
      EqPreset(id: 'headphones', name: 'Headphones', gains: [4, 2, 0, 1, 2, 3, 4, 4, 5, 6]),
      EqPreset(id: 'laptop', name: 'Laptop', gains: [-4, -2, 0, 2, 4, 4, 3, 2, 1, 0]),
      EqPreset(id: 'portable_speakers', name: 'Portable speakers', gains: [-6, -4, -2, 0, 2, 4, 5, 5, 4, 2]),
      EqPreset(id: 'home_stereo', name: 'Home stereo', gains: [3, 2, 1, 0, 0, 0, 1, 2, 3, 4]),
      EqPreset(id: 'tv', name: 'TV', gains: [-2, 0, 2, 4, 4, 3, 2, 0, -2, -4]),
      EqPreset(id: 'car', name: 'Car', gains: [4, 3, 1, 0, -1, -1, 0, 1, 2, 3]),
    ];

    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getStringList('custom_eq_presets');
    if (savedJson != null) {
      for (String str in savedJson) {
        try {
          final preset = EqPreset.fromJson(str);
          // Migrate old 5-band presets → pad to 10 bands
          if (preset.gains.length < 10) {
            final padded = List<double>.filled(10, 0.0);
            for (int i = 0; i < preset.gains.length; i++) {
              padded[i] = preset.gains[i];
            }
            _savedPresets.add(EqPreset(
                id: preset.id, name: preset.name, gains: padded));
          } else {
            _savedPresets.add(preset);
          }
        } catch (e) {
          debugPrint('Error loading custom preset: $e');
        }
      }
    }

    _currentPreset = _savedPresets.first;
    notifyListeners();
  }

  Future<void> toggleEnabled(bool val) async {
    _isEnabled = val;
    if (val && _currentPreset != null) {
      await _applyToNative(_currentPreset!.gains);
    } else {
      await EqEngine.bypass(_audioSessionId);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eq_enabled', val);
    notifyListeners();
  }

  void loadPreset(EqPreset preset) {
    _currentPreset = preset;
    _applyToNative(preset.gains);
    _saveActivePreset();
    notifyListeners();
  }

  void updateBand(int index, double gain) {
    if (_currentPreset == null) return;

    final newGains = List<double>.from(_currentPreset!.gains);
    // Ensure list is long enough
    while (newGains.length < 10) {
      newGains.add(0.0);
    }
    newGains[index] = gain;

    _currentPreset =
        EqPreset(id: 'custom_temp', name: 'Custom', gains: newGains);

    _applyToNative(newGains);
    notifyListeners();
  }

  void setPreamp(double db) {
    _preampGain = db.clamp(-12.0, 12.0);
    if (_isEnabled && _currentPreset != null) {
      _applyToNative(_currentPreset!.gains);
    }

    SharedPreferences.getInstance()
        .then((p) => p.setDouble('eq_preamp', _preampGain));
    notifyListeners();
  }

  Future<void> _applyToNative(List<double> gains) async {
    if (!_isEnabled) return;

    try {
      await EqEngine.apply(
      gains: gains,
      preampDb: _preampGain,
      audioSessionId: _audioSessionId,
    );
    } catch (e) {
      debugPrint('EQ Apply Error: $e');
    }
  }

  Future<void> deletePreset(String id) async {
    // Protect default presets
    if ([
      'flat', 'bass_boost', 'treble_boost', 'headphones', 'laptop', 'portable_speakers', 'home_stereo', 'tv', 'car'
    ].contains(id)) {
      return;
    }

    _savedPresets.removeWhere((p) => p.id == id);
    await _saveToPrefs();

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

    await _saveToPrefs();
    await _saveActivePreset();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultIds = [
      'flat', 'bass_boost', 'treble_boost', 'headphones', 'laptop', 'portable_speakers', 'home_stereo', 'tv', 'car'
    ];
    final customPresets = _savedPresets
        .where((p) => !defaultIds.contains(p.id))
        .map((p) => p.toJson())
        .toList();
    await prefs.setStringList('custom_eq_presets', customPresets);
  }

  Future<void> _saveActivePreset() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentPreset != null) {
      await prefs.setString('eq_active_preset', _currentPreset!.id);
    }
  }
}

final equalizerProvider = ChangeNotifierProvider<EqualizerProvider>((ref) {
  return EqualizerProvider(ref);
});
