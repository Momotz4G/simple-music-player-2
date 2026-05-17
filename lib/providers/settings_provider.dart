import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_music_player_2/services/android_audio_service.dart';
import 'package:simple_music_player_2/services/pocketbase_service.dart'; // 🔒 OFFLINE MODE
import 'package:simple_music_player_2/services/sync_engine.dart'; // 🔄 Cloud Stats Sync

// NEW ENUMS
enum VisualizerStyle { spectrum, wave, pulse }

enum SearchEngine { spotify, youtube, appleMusic }

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

enum SettingsSection {
  none,
  appearance,
  visualizer,
  integration,
  searchEngine,
  library,
  offlineMode,
}

final settingsNavigationProvider =
    StateProvider<SettingsSection>((ref) => SettingsSection.none);

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
  final String
      autoClearCache; // 'disabled', 'on_close', 'after_24h', 'after_7d'
  final bool gaplessPlayback; // Enable gapless transitions
  final double crossfadeDuration; // Crossfade duration in seconds (0.0-12.0)
  final bool
      enableAlphabetIndexer; // NEW: Enable side Alphabet scroll indexer on mobile
  final bool minimizeToTrayOnClose;
  final SearchEngine searchEngine; // NEW: Spotify vs YouTube
  final bool isOfflineMode; // 🔒 Offline Mode: Disables all network services
  final bool cacheStreamedSongs; // NEW: Cache streamed FLACs in background

  // Granular Service Controls
  final bool enableCloudSync;
  final bool enableLeaderboard;
  final bool enableOnlineLyrics;
  final bool enableAiLyrics;
  final bool enableOnlineSearch;
  final bool enableRemoteControl;
  final bool enableCanvas;

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
    this.isOfflineMode = false, // Default: Online
    this.cacheStreamedSongs = false, // Default: Off
    this.enableCloudSync = true,
    this.enableLeaderboard = true,
    this.enableOnlineLyrics = true,
    this.enableAiLyrics = true,
    this.enableOnlineSearch = true,
    this.enableRemoteControl = true,
    this.enableCanvas = true,
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
    bool? isOfflineMode,
    bool? cacheStreamedSongs,
    bool? enableCloudSync,
    bool? enableLeaderboard,
    bool? enableOnlineLyrics,
    bool? enableAiLyrics,
    bool? enableOnlineSearch,
    bool? enableRemoteControl,
    bool? enableCanvas,
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
      minimizeToTrayOnClose:
          minimizeToTrayOnClose ?? this.minimizeToTrayOnClose,
      searchEngine: searchEngine ?? this.searchEngine,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      cacheStreamedSongs: cacheStreamedSongs ?? this.cacheStreamedSongs,
      enableCloudSync: enableCloudSync ?? this.enableCloudSync,
      enableLeaderboard: enableLeaderboard ?? this.enableLeaderboard,
      enableOnlineLyrics: enableOnlineLyrics ?? this.enableOnlineLyrics,
      enableAiLyrics: enableAiLyrics ?? this.enableAiLyrics,
      enableOnlineSearch: enableOnlineSearch ?? this.enableOnlineSearch,
      enableRemoteControl: enableRemoteControl ?? this.enableRemoteControl,
      enableCanvas: enableCanvas ?? this.enableCanvas,
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
    final enableAlphabetIndexer =
        _prefs.getBool('enableAlphabetIndexer') ?? false;
    final minimizeToTrayOnClose =
        _prefs.getBool('minimizeToTrayOnClose') ?? true;
    final searchEngineIndex =
        _prefs.getInt('searchEngine') ?? SearchEngine.spotify.index;
    final searchEngine = SearchEngine.values[searchEngineIndex];
    final isOfflineMode = _prefs.getBool('isOfflineMode') ?? false;
    final cacheStreamedSongs =
        _prefs.getBool('cacheStreamedSongs') ?? false; // NEW
    final enableCloudSync = _prefs.getBool('enableCloudSync') ?? true;
    final enableLeaderboard = _prefs.getBool('enableLeaderboard') ?? true;
    final enableOnlineLyrics = _prefs.getBool('enableOnlineLyrics') ?? true;
    final enableAiLyrics = _prefs.getBool('enableAiLyrics') ?? true;
    final enableOnlineSearch = _prefs.getBool('enableOnlineSearch') ?? true;
    final enableRemoteControl = _prefs.getBool('enableRemoteControl') ?? true;
    final enableCanvas = _prefs.getBool('enableCanvas') ?? true;

    // Load Theme Enum
    final themeIndex =
        _prefs.getInt('atmosphereTheme') ?? AtmosphereTheme.none.index;
    final theme = AtmosphereTheme.values[themeIndex];

    // Sync static PocketBase flags
    PocketBaseService.isOffline = isOfflineMode;
    PocketBaseService.enableCloudSync = enableCloudSync;
    PocketBaseService.enableLeaderboard = enableLeaderboard;
    PocketBaseService.enableOnlineLyrics = enableOnlineLyrics;
    PocketBaseService.enableAiLyrics = enableAiLyrics;
    PocketBaseService.enableOnlineSearch = enableOnlineSearch;
    PocketBaseService.enableRemoteControl = enableRemoteControl;
    PocketBaseService.enableCanvas = enableCanvas;

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
      isOfflineMode: isOfflineMode,
      cacheStreamedSongs: cacheStreamedSongs,
      enableCloudSync: enableCloudSync,
      enableLeaderboard: enableLeaderboard,
      enableOnlineLyrics: enableOnlineLyrics,
      enableAiLyrics: enableAiLyrics,
      enableOnlineSearch: enableOnlineSearch,
      enableRemoteControl: enableRemoteControl,
      enableCanvas: enableCanvas,
    );
  }

  void toggleDarkMode(bool isDark) {
    _prefs.setBool('isDarkMode', isDark);
    state = state.copyWith(isDarkMode: isDark);
  }

  void setAccentColor(Color color) {
    _prefs.setInt('accentColor', color.toARGB32());
    state = state.copyWith(accentColor: color);
  }

  void toggleDiscordRpc(bool enabled) {
    _prefs.setBool('enableDiscordRpc', enabled);
    state = state.copyWith(enableDiscordRpc: enabled);
  }

  void toggleVisualizer(bool enabled) {
    _prefs.setBool('enableVisualizer', enabled);
    state = state.copyWith(enableVisualizer: enabled);
  }

  void setVisualizerOpacity(double opacity) {
    _prefs.setDouble('visualizerOpacity', opacity);
    state = state.copyWith(visualizerOpacity: opacity);
  }

  void toggleVisualizerRainbow(bool enabled) {
    _prefs.setBool('isVisualizerRainbow', enabled);
    state = state.copyWith(isVisualizerRainbow: enabled);
  }

  void toggleThemeSync(bool enabled) {
    _prefs.setBool('syncThemeWithAlbumArt', enabled);
    state = state.copyWith(syncThemeWithAlbumArt: enabled);
  }

  void setVisualizerStyle(VisualizerStyle style) {
    _prefs.setInt('visualizerStyle', style.index);
    state = state.copyWith(visualizerStyle: style);
  }

  void setAudioFormat(String format) {
    _prefs.setString('audioFormat', format);
    state = state.copyWith(audioFormat: format);
  }

  void setSpotifyMarket(String market) {
    _prefs.setString('spotifyMarket', market);
    state = state.copyWith(spotifyMarket: market);
  }

  void setStreamingQuality(String quality) {
    _prefs.setString('streamingQuality', quality);
    state = state.copyWith(streamingQuality: quality);
  }

  void toggleDebugButton(bool show) {
    _prefs.setBool('showDebugButton', show);
    state = state.copyWith(showDebugButton: show);
  }

  void toggleIgnoreSubfolders(bool ignore) {
    _prefs.setBool('ignoreSubfolders', ignore);
    state = state.copyWith(ignoreSubfolders: ignore);
  }

  void toggleDisableCanvas(bool disable) {
    _prefs.setBool('disableCanvas', disable);
    state = state.copyWith(disableCanvas: disable);
  }

  Future<void> addMusicFolder(String path) async {
    final folders = List<String>.from(state.additionalMusicFolders);
    if (!folders.contains(path)) {
      folders.add(path);
      await _prefs.setStringList('additionalMusicFolders', folders);
      state = state.copyWith(additionalMusicFolders: folders);
    }
  }

  Future<void> removeMusicFolder(String path) async {
    final folders = List<String>.from(state.additionalMusicFolders);
    if (folders.contains(path)) {
      folders.remove(path);
      await _prefs.setStringList('additionalMusicFolders', folders);
      state = state.copyWith(additionalMusicFolders: folders);
    }
  }

  Future<void> clearAllMusicFolders() async {
    await _prefs.setStringList('additionalMusicFolders', []);
    state = state.copyWith(additionalMusicFolders: []);
  }

  void toggleWasapiExclusive(bool enabled) {
    _prefs.setBool('wasapiExclusive', enabled);
    state = state.copyWith(wasapiExclusive: enabled);
  }

  void setAudioDeviceId(String? id) {
    if (id == null) {
      _prefs.remove('audioDeviceId');
    } else {
      _prefs.setString('audioDeviceId', id);
    }
    state = state.copyWith(audioDeviceId: id);
  }

  /// Toggle Android 14+ Bit-Perfect Mode
  Future<void> toggleAndroidBitPerfect(bool enabled) async {
    if (Platform.isAndroid) {
      // Attempt to set mode via native MethodChannel
      final success = await AndroidAudioService.setBitPerfectMode(enabled);
      if (!success) {
        // If native call failed (e.g. no USB device), do not update state to true
        // But if we were trying to disable, allow it.
        if (enabled) return;
      }
    }
    await _prefs.setBool('androidBitPerfect', enabled);
    state = state.copyWith(androidBitPerfect: enabled);
  }

  void toggleRomanization(bool disabled) {
    _prefs.setBool('disableRomanization', disabled);
    state = state.copyWith(disableRomanization: disabled);
  }

  void setTranslationLanguage(String langCode) {
    _prefs.setString('translationLanguage', langCode);
    state = state.copyWith(translationLanguage: langCode);
  }

  void setAtmosphereTheme(AtmosphereTheme theme) {
    _prefs.setInt('atmosphereTheme', theme.index);
    state = state.copyWith(atmosphereTheme: theme);
  }

  void setAppLocale(String locale) {
    _prefs.setString('appLocale', locale);
    state = state.copyWith(appLocale: locale);
  }

  void setAutoClearCache(String mode) {
    _prefs.setString('autoClearCache', mode);
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

  Future<void> toggleCacheStreamedSongs(bool enabled) async {
    await _prefs.setBool('cacheStreamedSongs', enabled);
    state = state.copyWith(cacheStreamedSongs: enabled);
  }

  /// 🔒 Toggle Offline Mode (Network Lockdown)
  Future<void> toggleOfflineMode(bool enabled) async {
    await _prefs.setBool('isOfflineMode', enabled);
    PocketBaseService.isOffline = enabled; // Sync static flag

    if (enabled) {
      // Explicitly turn off all services
      await toggleCloudSync(false);
      await toggleLeaderboard(false);
      await toggleOnlineLyrics(false);
      await toggleAiLyrics(false);
      await toggleOnlineSearch(false);
      await toggleRemoteControl(false);
      await toggleCanvas(false);
    } else {
      // Master toggle is turning off Offline Mode -> Force ENABLE all services
      await toggleCloudSync(true);
      await toggleLeaderboard(true);
      await toggleOnlineLyrics(true);
      await toggleAiLyrics(true);
      await toggleOnlineSearch(true);
      await toggleRemoteControl(true);
      await toggleCanvas(true);

      // Clean up the unused state variable just in case
      await _prefs.remove('disabledServicesBeforeOffline');
    }

    // 🔄 Notify SyncEngine of Offline Mode change (Requirement 4.6, 4.7)
    SyncEngine().onOfflineModeChanged(enabled);

    state = state.copyWith(isOfflineMode: enabled);
    debugPrint(
        "🔒 [Settings] Offline Mode: ${enabled ? 'ENABLED' : 'DISABLED'}");
  }

  Future<void> toggleCloudSync(bool enabled) async {
    await _prefs.setBool('enableCloudSync', enabled);
    PocketBaseService.enableCloudSync = enabled;
    state = state.copyWith(enableCloudSync: enabled);

    // 🔄 Notify SyncEngine of Cloud Stats Sync toggle change (Requirement 9.5, 9.6)
    SyncEngine().onSyncToggleChanged(enabled);
  }

  Future<void> toggleLeaderboard(bool enabled) async {
    await _prefs.setBool('enableLeaderboard', enabled);
    PocketBaseService.enableLeaderboard = enabled;
    state = state.copyWith(enableLeaderboard: enabled);
  }

  Future<void> toggleOnlineLyrics(bool enabled) async {
    await _prefs.setBool('enableOnlineLyrics', enabled);
    PocketBaseService.enableOnlineLyrics = enabled;
    state = state.copyWith(enableOnlineLyrics: enabled);
  }

  Future<void> toggleAiLyrics(bool enabled) async {
    await _prefs.setBool('enableAiLyrics', enabled);
    PocketBaseService.enableAiLyrics = enabled;
    state = state.copyWith(enableAiLyrics: enabled);
  }

  Future<void> toggleOnlineSearch(bool enabled) async {
    await _prefs.setBool('enableOnlineSearch', enabled);
    PocketBaseService.enableOnlineSearch = enabled;
    state = state.copyWith(enableOnlineSearch: enabled);
  }

  Future<void> toggleRemoteControl(bool enabled) async {
    await _prefs.setBool('enableRemoteControl', enabled);
    PocketBaseService.enableRemoteControl = enabled;
    state = state.copyWith(enableRemoteControl: enabled);
  }

  Future<void> toggleCanvas(bool enabled) async {
    await _prefs.setBool('enableCanvas', enabled);
    PocketBaseService.enableCanvas = enabled;
    state = state.copyWith(enableCanvas: enabled);
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
