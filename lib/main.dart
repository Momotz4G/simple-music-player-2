import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

// --- PROJECT IMPORTS ---
import 'providers/settings_provider.dart';
import 'providers/library_provider.dart';
import 'providers/data_usage_provider.dart'; // Added for initialization
// import 'providers/library_presentation_provider.dart'; // Unused
import 'core/theme/app_theme.dart';
import 'package:logging/logging.dart';
import 'services/debug_log_service.dart';
import 'ui/screens/main_shell.dart';
import 'services/metrics_service.dart';
import 'services/db_service.dart';
import 'services/youtube_downloader_service.dart';
import 'services/pocketbase_service.dart';
import 'l10n/app_localizations.dart';

// late final Future<void> dotEnvFuture;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Load SharedPreferences FIRST
  final prefs = await SharedPreferences.getInstance();
  final isOfflineMode = prefs.getBool('isOfflineMode') ?? false;
  PocketBaseService.isOffline = isOfflineMode;

  // 1. Initialize Utilities
  try {
    await MetadataGod.initialize().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint("⚠️ MetadataGod failed: $e");
  }

  // 🎵 Initialize MediaKit audio backend
  try {
    if (Platform.isWindows) {
      final wasapiExclusive = prefs.getBool('wasapiExclusive') ?? false;
      if (wasapiExclusive) {
        JustAudioMediaKit.audioExclusive = true;
        debugPrint("🎵 [Main] WASAPI Exclusive Mode ENABLED");
      }

      // Restore saved audio device (with validation)
      final audioDeviceId = prefs.getString('audioDeviceId');
      if (audioDeviceId != null) {
        try {
          final devices = await JustAudioMediaKit.listAudioDevices();
          final exists = devices.any((d) => d['name'] == audioDeviceId);
          if (exists) {
            JustAudioMediaKit.audioDeviceId = audioDeviceId;
            debugPrint("🎵 [Main] Audio Device Override: $audioDeviceId");
          } else {
            debugPrint("⚠️ [Main] Saved audio device '$audioDeviceId' not found. Falling back to default.");
            await prefs.remove('audioDeviceId');
            JustAudioMediaKit.audioDeviceId = null;
          }
        } catch (e) {
          debugPrint("⚠️ [Main] Error validating audio device: $e");
        }
      }
    }

    // 🚀 Optimize for DSD/Hi-Res (Desktop only - media_kit backend)
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      JustAudioMediaKit.bufferSize = 512 * 1024; // 0.5MB
      JustAudioMediaKit.demuxerMaxBackBytes = 512 * 1024;
      JustAudioMediaKit.demuxerReadaheadSecs = 10.0;
      JustAudioMediaKit.audioBuffer = 1.0;
      JustAudioMediaKit.audioPitchCorrection = false;
      JustAudioMediaKit.audioResampleMaxOutputSampleRate = 192000;
    }

    // Do NOT pass android: true — native ExoPlayer handles Android playback.
    // DSD on Android is handled via USB Audio bypass separately.
    JustAudioMediaKit.ensureInitialized(macOS: true);
  } catch (e) {
    debugPrint("⚠️ Audio Backend failed: $e");
  }

  final autoClearCache = prefs.getString('autoClearCache') ?? 'disabled';
  if (autoClearCache == 'after_24h' || autoClearCache == 'after_7d' || autoClearCache == 'on_close') {
    if (autoClearCache == 'on_close') {
      await YoutubeDownloaderService().clearCache();
    } else {
      final lastClearStr = prefs.getString('lastCacheClearTimestamp');
      if (lastClearStr != null) {
        final lastClear = DateTime.tryParse(lastClearStr);
        if (lastClear != null) {
          final now = DateTime.now();
          final hoursDiff = now.difference(lastClear).inHours;
          final shouldClear = (autoClearCache == 'after_24h' && hoursDiff >= 24) ||
              (autoClearCache == 'after_7d' && hoursDiff >= 168);

          if (shouldClear) {
            await YoutubeDownloaderService().clearCache();
            await prefs.setString('lastCacheClearTimestamp', now.toIso8601String());
          }
        }
      } else {
        await prefs.setString('lastCacheClearTimestamp', DateTime.now().toIso8601String());
      }
    }
  }

  // 🚀 LOGGING SYSTEM BRIDGE
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final service = DebugLogService();
    final logMsg = "[${record.loggerName}] ${record.message}";

    if (record.level >= Level.SEVERE) {
      service.error(logMsg);
    } else if (record.level >= Level.WARNING) {
      service.warning(logMsg);
    } else if (record.level >= Level.INFO) {
      service.info(logMsg);
    }
  });

  // Initialize Analytics
  try {
    await MetricsService().init().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint("⚠️ Critical Metrics Init Error: $e");
  }

  // SYNC LOCAL STATS
  () async {
    try {
      final dbService = DBService();
      final totalPlays = await dbService
          .getTotalStatsPlays()
          .timeout(const Duration(seconds: 5), onTimeout: () => 0);
      if (totalPlays > 0) {
        await MetricsService()
            .syncLocalStats(totalPlays)
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint("⚠️ Startup Sync Warning: $e");
    }
  }();

  // 2. Initialize Window Manager
  try {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await windowManager.ensureInitialized().timeout(const Duration(seconds: 2));
      const windowOptions = WindowOptions(
        size: Size(1280, 800),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }
  } catch (e) {
    debugPrint("⚠️ WindowManager failed: $e");
  }

  // Initialize SMTC
  try {
    if (Platform.isWindows) {
      await SMTCWindows.initialize().timeout(const Duration(seconds: 3));
    }
  } catch (e) {
    debugPrint("⚠️ SMTC failed: $e");
  }

  // 3. Load Environment Variables
  try {
    await dotenv.load(fileName: ".env").timeout(const Duration(seconds: 2));
  } catch (e) {
    debugPrint("⚠️ DotEnv failed: $e");
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );

  // 4. Configure Custom Window (BitsDojo)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    doWhenWindowReady(() {
      const initialSize = Size(1280, 800);
      appWindow.minSize = const Size(800, 600);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = "Simple Music Player";
      appWindow.show();
      debugPrint("🚀 [Main] BitsDojo Window Shown");
    });
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: null, // dotEnvFuture,
      builder: (context, snapshot) {
        // if (snapshot.connectionState == ConnectionState.done) {
        final settings = ref.watch(settingsProvider);
        final accentColor = settings.accentColor;

        // Force initialize Data Usage Singleton pointers
        ref.read(dataUsageProvider);

        return MaterialApp(
          title: 'Music Player',
          debugShowCheckedModeBanner: false,
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: AppTheme.lightTheme(accentColor),
          darkTheme: AppTheme.darkTheme(accentColor),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(settings.appLocale),
          // 🚀 FIX: Use ref.read() instead of ref.watch() for the legacy provider bridge.
          // ref.watch() here was rebuilding the ENTIRE MainShell (2000+ line widget)
          // on every libraryProvider.notifyListeners() — including every search keystroke.
          // The legacy bridge only needs the instance reference; reactive updates
          // are handled by Riverpod's own ref.watch() in individual widgets.
          home: Consumer(
            builder: (context, dynamicRef, _) {
              final libInstance = dynamicRef.read(libraryProvider);
              return p.MultiProvider(
                providers: [
                  p.ChangeNotifierProvider.value(value: libInstance),
                ],
                child: const MainShell(),
              );
            },
          ),
        );
        // }

        // // Loading Screen
        // return const MaterialApp(
        //   debugShowCheckedModeBanner: false,
        //   home: Scaffold(
        //     body: Center(child: CircularProgressIndicator()),
        //   ),
        // );
      },
    );
  }
}
