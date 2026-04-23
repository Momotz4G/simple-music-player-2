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
import 'l10n/app_localizations.dart';

// late final Future<void> dotEnvFuture;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Utilities
  try {
    await MetadataGod.initialize();
  } catch (e) {
    debugPrint("⚠️ MetadataGod Init Failed: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  final autoClearCache = prefs.getString('autoClearCache') ?? 'disabled';
  if (autoClearCache == 'after_24h' || autoClearCache == 'after_7d' || autoClearCache == 'on_close') {
    if (autoClearCache == 'on_close') {
      // Swipe-kills prevent code from running during AppLifecycleState.detached.
      // So if set to "on close", we just unconditionally clear it on the NEXT startup.
      debugPrint("🧹 Auto Clear Cache triggered on startup (Mode: on_close)");
      await YoutubeDownloaderService().clearCache();
    } else {
      final lastClearStr = prefs.getString('lastCacheClearTimestamp');
      if (lastClearStr != null) {
        final lastClear = DateTime.tryParse(lastClearStr);
        if (lastClear != null) {
          final now = DateTime.now();
          final hoursDiff = now.difference(lastClear).inHours;
          final shouldClear = (autoClearCache == 'after_24h' && hoursDiff >= 24) ||
              (autoClearCache == 'after_7d' && hoursDiff >= 168); // 7 * 24 = 168

          if (shouldClear) {
            debugPrint("🧹 Auto Clear Cache triggered (Mode: $autoClearCache)");
            await YoutubeDownloaderService().clearCache();
            await prefs.setString('lastCacheClearTimestamp', now.toIso8601String());
          }
        }
      } else {
        // First time running with this setting
        await prefs.setString('lastCacheClearTimestamp', DateTime.now().toIso8601String());
      }
    }
  }

  // 🎵 Initialize MediaKit audio backend for Windows/Linux
  // Read WASAPI exclusive setting from SharedPreferences (must be done before AudioPlayer is created)
  if (Platform.isWindows) {
    final wasapiExclusive = prefs.getBool('wasapiExclusive') ?? false;
    if (wasapiExclusive) {
      JustAudioMediaKit.audioExclusive = true;
      debugPrint("🎵 [Main] WASAPI Exclusive Mode ENABLED");
    } else {
      debugPrint("🎵 [Main] WASAPI Exclusive Mode DISABLED (default)");
    }

    final audioDeviceId = prefs.getString('audioDeviceId');
    if (audioDeviceId != null) {
      // 🚀 JustAudioMediaKit.audioDeviceId = audioDeviceId;
      // 🚀 SANITY CHECK: Verify the device still exists before applying it
      () async {
        try {
          final devices = await JustAudioMediaKit.listAudioDevices();
          final exists = devices.any((d) => d['name'] == audioDeviceId);

          if (exists) {
            JustAudioMediaKit.audioDeviceId = audioDeviceId;
            debugPrint("🎵 [Main] Audio Device Override: $audioDeviceId");
          } else {
            debugPrint(
                "⚠️ [Main] Saved audio device '$audioDeviceId' not found. Falling back to default.");
            await prefs.remove('audioDeviceId');
            JustAudioMediaKit.audioDeviceId = null;
          }
        } catch (e) {
          debugPrint("⚠️ [Main] Error validating audio device: $e");
        }
      }();
    }
  }
  // 🚀 OPTIMIZE FOR DSD/HI-RES (Desktop Only - media_kit backend)
  // These settings only apply when media_kit is the active backend (Windows/Linux/macOS).
  // On Android/iOS, just_audio uses the native ExoPlayer backend which handles buffering internally.
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    JustAudioMediaKit.bufferSize = 512 * 1024; // 0.5MB (Minimum to avoid lavf cache errors)
    JustAudioMediaKit.demuxerMaxBackBytes = 512 * 1024; 
    JustAudioMediaKit.demuxerReadaheadSecs = 10.0; 
    JustAudioMediaKit.audioBuffer = 1.0; 
    JustAudioMediaKit.audioPitchCorrection = false; 
    JustAudioMediaKit.audioResampleMaxOutputSampleRate = 192000; 
  }
  // 🚀 FIX: Do NOT pass android: true — this would replace the native ExoPlayer
  // backend with media_kit (FFmpeg/mpv), which causes playback hangs on Android.
  // DSD on Android is handled separately via USB Audio bypass.
  JustAudioMediaKit.ensureInitialized(macOS: true);

  // 🚀 LOGGING SYSTEM BRIDGE
  // Connect hierarchical 'logging' package (used by MediaKit fork) to our internal DebugLogService
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

  DebugLogService().info("🚀 App Lifecycle Start");

  // Initialize Analytics (Startup)
  // 🚀 Reduced timeout for faster offline startup
  try {
    await MetricsService().init().timeout(const Duration(seconds: 5),
        onTimeout: () {
      debugPrint("⚠️ MetricsService init timed out in main");
    });
  } catch (e) {
    debugPrint("⚠️ Critical Metrics Init Error: $e");
  }

  debugPrint("🚀 [Main] Metrics Init Done");

  // SYNC LOCAL STATS (Non-blocking for faster startup)
  // 🚀 Run in background without awaiting to prevent startup delay
  () async {
    try {
      final dbService = DBService();
      final totalPlays = await dbService
          .getTotalStatsPlays()
          .timeout(const Duration(seconds: 5), onTimeout: () => 0);
      if (totalPlays > 0) {
        await MetricsService()
            .syncLocalStats(totalPlays)
            .timeout(const Duration(seconds: 5), onTimeout: () {
          debugPrint("⚠️ syncLocalStats timed out - skipping cloud sync");
        });
        debugPrint("✅ Startup: Synced $totalPlays local plays to cloud.");
      }
    } catch (e) {
      debugPrint("⚠️ Startup Sync Warning: $e");
    }
  }(); // Fire-and-forget - don't block startup


  // 2. Initialize Window Manager (Required for Full Screen toggle or Desktop)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
  }

  // Initialize SMTC
  if (Platform.isWindows) {
    try {
      await SMTCWindows.initialize();
      debugPrint("🚀 [Main] SMTC Initialized");
    } catch (e) {
      debugPrint("Failed to initialize SMTC: $e");
    }
  }

  // 3. Load Environment Variables
  await dotenv.load(fileName: ".env").catchError((e) {
    debugPrint("Warning: .env file not found or failed to load. Using fallback values.");
  });

  debugPrint("🚀 [Main] FLUTTER RUNAPP STARTING");
  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );

  // 4. Configure Custom Window (BitsDojo)
  // 4. Configure Custom Window (BitsDojo)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    doWhenWindowReady(() {
      const initialSize = Size(1280, 800);
      appWindow.minSize = const Size(800, 600);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = "Simple Music Player";
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
