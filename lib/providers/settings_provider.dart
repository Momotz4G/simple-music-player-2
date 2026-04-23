import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:simple_music_player_2/services/android_audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_music_player_2/utils/translation_service.dart';
import 'package:path/path.dart' as p;

// NEW ENUMS
enum VisualizerStyle { spectrum, wave, pulse }

enum SearchEngine { spotify, youtube }

enum AtmosphereTheme {
  none,
  winter,
  autumn,
  rainyCity,
  sakura,
  lunarNewYear,
  cyberpunk,
  underwater,
  nordicAurora,
  galactic,
  desertMirage
}

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
  final String streamingQuality; // standard, high, lossless
  final bool showDebugButton;
  final bool ignoreSubfolders; // NEW: Default true
  final bool disableCanvas; // Disable Spotify Canvas video loading
  final List<String> additionalMusicFolders; // Additional import paths
  final bool
      wasapiExclusive; // Windows: WASAPI exclusive mode for bit-perfect audio
  final String? audioDeviceId; // Selected MPV audio device ID
  final bool androidBitPerfect; // Android 14+: Bit-perfect audio mode
  final bool disableRomanization; // Disable romanization display for lyrics
  final String translationLanguage; // Target language for lyrics translation
  final bool enableSnowEffect; // DEPRECATED: use atmosphereTheme
  final AtmosphereTheme atmosphereTheme; // Active seasonal atmosphere theme
  final String appLocale; // NEW: Application UI language (e.g., 'en', 'id')
  final String autoClearCache; // 'disabled', 'on_close', 'after_24h', 'after_7d'
  final bool gaplessPlayback; // Enable gapless transitions
  final double crossfadeDuration; // Crossfade duration in seconds (0.0-12.0)
  final bool enableAlphabetIndexer; // NEW: Enable side Alphabet scroll indexer on mobile
  final bool minimizeToTrayOnClose;
  final SearchEngine searchEngine; // NEW: Spotify vs YouTube

  SettingsState({
    this.isDarkMode = true,
    this.accentColor = const Color(0xFF6C5CE7),
    this.enableDiscordRpc = true,
    this.enableVisualizer = false,
    this.visualizerOpacity = 0.3,
    this.isVisualizerRainbow = false,
    this.syncThemeWithAlbumArt = false,
    this.visualizerStyle = VisualizerStyle.spectrum,
    this.audioFormat = 'mp3',
    this.spotifyMarket = 'KR',
    this.streamingQuality = 'high', // Default to high (M4A)
    this.showDebugButton = false,
    this.ignoreSubfolders = true,
    this.disableCanvas = true,
    this.additionalMusicFolders = const [],
    this.wasapiExclusive = false, // Default OFF - exclusive locks audio device
    this.audioDeviceId,
    this.androidBitPerfect = false,
    this.disableRomanization = false, // Default: romanization enabled
    this.translationLanguage = 'en', // Default: translate to English
    this.enableSnowEffect = false, // DEPRECATED
    this.atmosphereTheme = AtmosphereTheme.none,
    this.appLocale = 'en',
    this.autoClearCache = 'disabled',
    this.gaplessPlayback = true,
    this.crossfadeDuration = 0.0, // Default: No crossfade
    this.enableAlphabetIndexer = false, // Default: Off
    this.minimizeToTrayOnClose = true,
    this.searchEngine = SearchEngine.spotify, // Default: Spotify
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
    String? streamingQuality,
    bool? showDebugButton,
    bool? ignoreSubfolders,
    bool? disableCanvas,
    List<String>? additionalMusicFolders,
    bool? wasapiExclusive,
    String? audioDeviceId,
    bool? androidBitPerfect,
    bool? disableRomanization,
    String? translationLanguage,
    bool? enableSnowEffect,
    AtmosphereTheme? atmosphereTheme,
    String? appLocale,
    String? autoClearCache,
    bool? gaplessPlayback,
    double? crossfadeDuration,
    bool? enableAlphabetIndexer,
    bool? minimizeToTrayOnClose,
    SearchEngine? searchEngine,
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
      streamingQuality: streamingQuality ?? this.streamingQuality,
      showDebugButton: showDebugButton ?? this.showDebugButton,
      ignoreSubfolders: ignoreSubfolders ?? this.ignoreSubfolders,
      disableCanvas: disableCanvas ?? this.disableCanvas,
      additionalMusicFolders:
          additionalMusicFolders ?? this.additionalMusicFolders,
      wasapiExclusive: wasapiExclusive ?? this.wasapiExclusive,
      audioDeviceId: audioDeviceId ?? this.audioDeviceId,
      androidBitPerfect: androidBitPerfect ?? this.androidBitPerfect,
      disableRomanization: disableRomanization ?? this.disableRomanization,
      translationLanguage: translationLanguage ?? this.translationLanguage,
      enableSnowEffect: enableSnowEffect ?? this.enableSnowEffect,
      atmosphereTheme: atmosphereTheme ?? this.atmosphereTheme,
      appLocale: appLocale ?? this.appLocale,
      autoClearCache: autoClearCache ?? this.autoClearCache,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      enableAlphabetIndexer:
          enableAlphabetIndexer ?? this.enableAlphabetIndexer,
      minimizeToTrayOnClose: minimizeToTrayOnClose ?? this.minimizeToTrayOnClose,
      searchEngine: searchEngine ?? this.searchEngine,
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

    final visEnabled = _prefs.getBool('enableVisualizer') ?? false;
    final visOpacity = _prefs.getDouble('visualizerOpacity') ?? 0.3;
    final visRainbow = _prefs.getBool('isVisualizerRainbow') ?? false;
    final themeSync = _prefs.getBool('syncThemeWithAlbumArt') ?? false;

    // Load Style Enum (Save as int index)
    final styleIndex = _prefs.getInt('visualizerStyle') ?? 0;
    final style = VisualizerStyle.values[styleIndex];

    final format = _prefs.getString('audioFormat') ?? 'mp3';
    final market = _prefs.getString('spotifyMarket') ?? 'KR';
    final streaming = _prefs.getString('streamingQuality') ?? 'high';
    final showDebug = _prefs.getBool('showDebugButton') ?? false;
    final ignoreSub = _prefs.getBool('ignoreSubfolders') ?? true;
    final disableCanvas = _prefs.getBool('disableCanvas') ?? false;
    final additionalFolders =
        _prefs.getStringList('additionalMusicFolders') ?? [];
    final wasapiExclusive = _prefs.getBool('wasapiExclusive') ?? false;
    final audioDeviceId = _prefs.getString('audioDeviceId'); // Nullable
    final androidBitPerfect = _prefs.getBool('androidBitPerfect') ?? false;
    final disableRomanization = _prefs.getBool('disableRomanization') ?? false;
    final translationLanguage = _prefs.getString('translationLanguage') ?? 'en';
    final enableSnowEffect = _prefs.getBool('enableSnowEffect') ?? false;
    final appLocale = _prefs.getString('appLocale') ?? 'en';
    final autoClearCache = _prefs.getString('autoClearCache') ?? 'disabled';
    final gaplessPlayback = _prefs.getBool('gaplessPlayback') ?? true;
    final crossfadeDuration = _prefs.getDouble('crossfadeDuration') ?? 0.0;
    final enableAlphabetIndexer = _prefs.getBool('enableAlphabetIndexer') ?? false;
    final minimizeToTrayOnClose = _prefs.getBool('minimizeToTrayOnClose') ?? true;
    final searchEngineIndex = _prefs.getInt('searchEngine') ?? SearchEngine.spotify.index;
    final searchEngine = SearchEngine.values[searchEngineIndex];

    // Load Theme Enum
    final themeIndex = _prefs.getInt('atmosphereTheme') ??
        (enableSnowEffect
            ? AtmosphereTheme.winter.index
            : AtmosphereTheme.none.index);
    final theme = AtmosphereTheme.values[themeIndex];

    // Initialize Android Bit-Perfect mode if enabled
    if (androidBitPerfect) {
      AndroidAudioService.setBitPerfectMode(true);
    }

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
      streamingQuality: streaming,
      showDebugButton: showDebug,
      ignoreSubfolders: ignoreSub,
      disableCanvas: disableCanvas,
      additionalMusicFolders: additionalFolders,
      wasapiExclusive: wasapiExclusive,
      audioDeviceId: audioDeviceId,
      androidBitPerfect: androidBitPerfect,
      disableRomanization: disableRomanization,
      translationLanguage: translationLanguage,
      enableSnowEffect: enableSnowEffect,
      atmosphereTheme: theme,
      appLocale: appLocale,
      autoClearCache: autoClearCache,
      gaplessPlayback: gaplessPlayback,
      crossfadeDuration: crossfadeDuration,
      enableAlphabetIndexer: enableAlphabetIndexer,
      minimizeToTrayOnClose: minimizeToTrayOnClose,
      searchEngine: searchEngine,
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

  // Set Streaming Quality (standard, high, lossless)
  Future<void> setStreamingQuality(String quality) async {
    await _prefs.setString('streamingQuality', quality);
    state = state.copyWith(streamingQuality: quality);
  }

  Future<void> toggleShowDebugButton(bool enabled) async {
    await _prefs.setBool('showDebugButton', enabled);
    state = state.copyWith(showDebugButton: enabled);
  }

  Future<void> toggleIgnoreSubfolders(bool enabled) async {
    await _prefs.setBool('ignoreSubfolders', enabled);
    state = state.copyWith(ignoreSubfolders: enabled);
  }

  Future<void> toggleDisableCanvas(bool enabled) async {
    await _prefs.setBool('disableCanvas', enabled);
    state = state.copyWith(disableCanvas: enabled);
  }

  Future<void> toggleDisableRomanization(bool enabled) async {
    await _prefs.setBool('disableRomanization', enabled);
    state = state.copyWith(disableRomanization: enabled);
  }

  Future<void> setTranslationLanguage(String langCode) async {
    await _prefs.setString('translationLanguage', langCode);
    TranslationService.clearCache(); // Flush cache when language changes
    state = state.copyWith(translationLanguage: langCode);
  }

  /// Toggle WASAPI exclusive mode (Windows only)
  Future<void> toggleWasapiExclusive(bool enabled) async {
    if (Platform.isWindows) {
      JustAudioMediaKit.audioExclusive = enabled;
      debugPrint("🎵 [Settings] WASAPI Exclusive Mode: ${enabled ? 'ENABLED' : 'DISABLED'}");
    }
    await _prefs.setBool('wasapiExclusive', enabled);
    state = state.copyWith(wasapiExclusive: enabled);
  }

  /// Set Audio Device ID (Windows only)
  Future<void> setAudioDeviceId(String? deviceId) async {
    if (Platform.isWindows) {
      JustAudioMediaKit.audioDeviceId = deviceId;
      debugPrint("🎵 [Settings] Audio Device Override: $deviceId");
    }
    if (deviceId == null) {
      await _prefs.remove('audioDeviceId');
    } else {
      await _prefs.setString('audioDeviceId', deviceId);
    }
    state = state.copyWith(audioDeviceId: deviceId);
  }

  // Additional Music Folders
  Future<void> addMusicFolder(String path) async {
    final canonicalPath = p.canonicalize(path);
    if (state.additionalMusicFolders.contains(canonicalPath)) return;
    final newFolders = [...state.additionalMusicFolders, canonicalPath];
    await _prefs.setStringList('additionalMusicFolders', newFolders);
    state = state.copyWith(additionalMusicFolders: newFolders);
  }

  Future<void> removeMusicFolder(String path) async {
    final canonicalPath = p.canonicalize(path);
    final newFolders =
        state.additionalMusicFolders.where((f) => f != canonicalPath).toList();
    await _prefs.setStringList('additionalMusicFolders', newFolders);
    state = state.copyWith(additionalMusicFolders: newFolders);
  }

  Future<void> clearAllMusicFolders() async {
    await _prefs.remove('additionalMusicFolders');
    state = state.copyWith(additionalMusicFolders: []);
  }

  /// Toggle Android 14+ Bit-Perfect Mode
  Future<void> toggleAndroidBitPerfect(bool enabled) async {
    // Attempt to set mode via MethodChannel
    final success = await AndroidAudioService.setBitPerfectMode(enabled);
    if (!success) {
      // If native call failed (e.g. no USB device), do not update state to true
      // But if we were trying to disable, allow it.
      if (enabled) return;
    }

    await _prefs.setBool('androidBitPerfect', enabled);
    state = state.copyWith(androidBitPerfect: enabled);
  }

  /// Toggle Snow Effect (Lacy backward compatibility)
  Future<void> toggleSnowEffect(bool enabled) async {
    await setAtmosphereTheme(
        enabled ? AtmosphereTheme.winter : AtmosphereTheme.none);
  }

  /// Set Active Atmosphere Theme
  Future<void> setAtmosphereTheme(AtmosphereTheme theme) async {
    await _prefs.setInt('atmosphereTheme', theme.index);
    // Sync deprecated bool
    await _prefs.setBool('enableSnowEffect', theme == AtmosphereTheme.winter);
    state = state.copyWith(
      atmosphereTheme: theme,
      enableSnowEffect: theme == AtmosphereTheme.winter,
    );
  }

  Future<void> setAppLocale(String localeCode) async {
    await _prefs.setString('appLocale', localeCode);
    state = state.copyWith(appLocale: localeCode);
  }

  Future<void> setAutoClearCache(String mode) async {
    await _prefs.setString('autoClearCache', mode);
    state = state.copyWith(autoClearCache: mode);
  }

  Future<void> toggleGaplessPlayback(bool enabled) async {
    await _prefs.setBool('gaplessPlayback', enabled);
    state = state.copyWith(gaplessPlayback: enabled);
  }

  Future<void> setCrossfadeDuration(double duration) async {
    await _prefs.setDouble('crossfadeDuration', duration);
    state = state.copyWith(crossfadeDuration: duration);
  }

  Future<void> toggleAlphabetIndexer(bool enabled) async {
    await _prefs.setBool('enableAlphabetIndexer', enabled);
    state = state.copyWith(enableAlphabetIndexer: enabled);
  }

  Future<void> toggleMinimizeToTrayOnClose(bool enabled) async {
    await _prefs.setBool('minimizeToTrayOnClose', enabled);
    state = state.copyWith(minimizeToTrayOnClose: enabled);
  }

  Future<void> setSearchEngine(SearchEngine engine) async {
    await _prefs.setInt('searchEngine', engine.index);
    state = state.copyWith(searchEngine: engine);
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
