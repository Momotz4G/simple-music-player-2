import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NEW ENUM
enum VisualizerStyle { spectrum, wave, pulse }

// --- STATE DEFINITION ---
class SettingsState {
  final bool isDarkMode;
  final Color accentColor;
  final bool enableDiscordRpc;

  // Visualizer Settings
  final bool enableVisualizer;
  final double visualizerOpacity;
  final bool isVisualizerRainbow;
  final bool syncThemeWithAlbumArt;
  final VisualizerStyle visualizerStyle;
  final String audioFormat;
  final String spotifyMarket;

  SettingsState({
    this.isDarkMode = true,
    this.accentColor = const Color(0xFF6C5CE7),
    this.enableDiscordRpc = true,
    this.enableVisualizer = true,
    this.visualizerOpacity = 0.3,
    this.isVisualizerRainbow = false,
    this.syncThemeWithAlbumArt = false,
    this.visualizerStyle = VisualizerStyle.spectrum,
    this.audioFormat = 'mp3',
    this.spotifyMarket = 'KR',
  });

  SettingsState copyWith({
    bool? isDarkMode,
    Color? accentColor,
    bool? enableDiscordRpc,
    bool? enableVisualizer,
    double? visualizerOpacity,
    bool? isVisualizerRainbow,
    bool? syncThemeWithAlbumArt,
    VisualizerStyle? visualizerStyle,
    String? audioFormat,
    String? spotifyMarket,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      accentColor: accentColor ?? this.accentColor,
      enableDiscordRpc: enableDiscordRpc ?? this.enableDiscordRpc,
      enableVisualizer: enableVisualizer ?? this.enableVisualizer,
      visualizerOpacity: visualizerOpacity ?? this.visualizerOpacity,
      isVisualizerRainbow: isVisualizerRainbow ?? this.isVisualizerRainbow,
      syncThemeWithAlbumArt:
          syncThemeWithAlbumArt ?? this.syncThemeWithAlbumArt,
      visualizerStyle: visualizerStyle ?? this.visualizerStyle,
      audioFormat: audioFormat ?? this.audioFormat,
      spotifyMarket: spotifyMarket ?? this.spotifyMarket,
    );
  }
}

// --- NOTIFIER CLASS ---
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final isDark = _prefs.getBool('isDarkMode') ?? true;
    final colorValue = _prefs.getInt('accentColor') ?? 0xFF6C5CE7;
    final rpcEnabled = _prefs.getBool('enableDiscordRpc') ?? true;

    final visEnabled = _prefs.getBool('enableVisualizer') ?? true;
    final visOpacity = _prefs.getDouble('visualizerOpacity') ?? 0.3;
    final visRainbow = _prefs.getBool('isVisualizerRainbow') ?? false;
    final themeSync = _prefs.getBool('syncThemeWithAlbumArt') ?? false;

    // Load Style Enum (Save as int index)
    final styleIndex = _prefs.getInt('visualizerStyle') ?? 0;
    final style = VisualizerStyle.values[styleIndex];

    final format = _prefs.getString('audioFormat') ?? 'mp3';
    final market = _prefs.getString('spotifyMarket') ?? 'KR';

    state = SettingsState(
      isDarkMode: isDark,
      accentColor: Color(colorValue),
      enableDiscordRpc: rpcEnabled,
      enableVisualizer: visEnabled,
      visualizerOpacity: visOpacity,
      isVisualizerRainbow: visRainbow,
      syncThemeWithAlbumArt: themeSync,
      visualizerStyle: style,
      audioFormat: format,
      spotifyMarket: market,
    );
  }

  Future<void> toggleTheme(bool isDark) async {
    await _prefs.setBool('isDarkMode', isDark);
    state = state.copyWith(isDarkMode: isDark);
  }

  Future<void> setAccentColor(Color color) async {
    await _prefs.setInt('accentColor', color.value);
    state = state.copyWith(accentColor: color);
  }

  Future<void> toggleDiscordRpc(bool enabled) async {
    await _prefs.setBool('enableDiscordRpc', enabled);
    state = state.copyWith(enableDiscordRpc: enabled);
  }

  Future<void> toggleVisualizer(bool enabled) async {
    await _prefs.setBool('enableVisualizer', enabled);
    state = state.copyWith(enableVisualizer: enabled);
  }

  Future<void> setVisualizerOpacity(double value) async {
    await _prefs.setDouble('visualizerOpacity', value);
    state = state.copyWith(visualizerOpacity: value);
  }

  Future<void> toggleVisualizerRainbow(bool enabled) async {
    await _prefs.setBool('isVisualizerRainbow', enabled);
    state = state.copyWith(isVisualizerRainbow: enabled);
  }

  Future<void> toggleSyncThemeWithAlbumArt(bool enabled) async {
    await _prefs.setBool('syncThemeWithAlbumArt', enabled);
    state = state.copyWith(syncThemeWithAlbumArt: enabled);
  }

  // Set Style
  Future<void> setVisualizerStyle(VisualizerStyle style) async {
    await _prefs.setInt('visualizerStyle', style.index);
    state = state.copyWith(visualizerStyle: style);
  }

  // Extension Output file
  Future<void> setAudioFormat(String format) async {
    await _prefs.setString('audioFormat', format);
    state = state.copyWith(audioFormat: format);
  }

  // Set Market Region for Spotify Recommendation Latest Released
  Future<void> setSpotifyMarket(String market) async {
    await _prefs.setString('spotifyMarket', market);
    state = state.copyWith(spotifyMarket: market);
  }
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError("SharedPreferences not initialized");
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return SettingsNotifier(prefs);
});
