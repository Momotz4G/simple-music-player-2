import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:smtc_windows/smtc_windows.dart';

// --- PROJECT IMPORTS ---
import 'providers/settings_provider.dart';
import 'providers/library_provider.dart';
// import 'providers/library_presentation_provider.dart'; // Unused
import 'core/theme/app_theme.dart';
import 'ui/screens/main_shell.dart';
import 'services/metrics_service.dart';
import 'services/db_service.dart';
import 'services/audio_handler.dart';
import 'services/native_music_service.dart';

// late final Future<void> dotEnvFuture;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Utilities
  try {
    await MetadataGod.initialize();
  } catch (e) {
    debugPrint("⚠️ MetadataGod Init Failed: $e");
  }

  // Initialize Analytics (Startup)
  // 🚀 Reduced timeout for faster offline startup
  try {
    await MetricsService().init().timeout(const Duration(seconds: 2),
        onTimeout: () {
      debugPrint("⚠️ MetricsService init timed out in main");
    });
  } catch (e) {
    debugPrint("⚠️ Critical Metrics Init Error: $e");
  }

  // SYNC LOCAL STATS (Non-blocking for faster startup)
  // 🚀 Run in background without awaiting to prevent startup delay
  () async {
    try {
      final dbService = DBService();
      final totalPlays = await dbService
          .getTotalStatsPlays()
          .timeout(const Duration(seconds: 2), onTimeout: () => 0);
      if (totalPlays > 0) {
        await MetricsService()
            .syncLocalStats(totalPlays)
            .timeout(const Duration(seconds: 2), onTimeout: () {
          debugPrint("⚠️ syncLocalStats timed out - skipping cloud sync");
        });
        debugPrint("✅ Startup: Synced $totalPlays local plays to cloud.");
      }
    } catch (e) {
      debugPrint("⚠️ Startup Sync Warning: $e");
    }
  }(); // Fire-and-forget - don't block startup

  final prefs = await SharedPreferences.getInstance();

  // 2. Initialize Window Manager (Required for Full Screen toggle or Desktop)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
  }

  // Initialize SMTC
  if (Platform.isWindows) {
    try {
      await SMTCWindows.initialize();
    } catch (e) {
      print("Failed to initialize SMTC: $e");
    }
  }

  // Initialize Audio Service for Android/iOS/macOS notification/lock screen controls
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    try {
      final musicService = NativeMusicService();
      audioHandler = await initAudioService(musicService.player);
      debugPrint(
          "✅ AudioService initialized for ${Platform.isIOS ? 'iOS' : Platform.isMacOS ? 'macOS' : 'Android'}");
    } catch (e) {
      debugPrint("⚠️ Failed to initialize AudioService: $e");
    }
  }

  // 3. Load Environment Variables
  // dotEnvFuture = dotenv.load(fileName: ".env").catchError((e) {
  //   print(
  //       "Warning: .env file not found or failed to load. Using fallback values.");
  // });

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
      appWindow.show();
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

        // Legacy Provider Bridge (for LibraryPage)
        final libInstance = ref.watch(libraryProvider);

        return p.MultiProvider(
          providers: [
            p.ChangeNotifierProvider.value(value: libInstance),
          ],
          child: MaterialApp(
            title: 'Music Player',
            debugShowCheckedModeBanner: false,
            themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: AppTheme.lightTheme(accentColor),
            darkTheme: AppTheme.darkTheme(accentColor),
            home: const MainShell(),
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
