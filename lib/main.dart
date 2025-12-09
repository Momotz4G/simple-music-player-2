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

// late final Future<void> dotEnvFuture;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Utilities
  await MetadataGod.initialize();

  // Initialize Analytics (Startup)
  // Don't let analytics block the app start for more than 2 seconds
  await MetricsService().init().timeout(const Duration(seconds: 2),
      onTimeout: () {
    debugPrint("⚠️ MetricsService init timed out in main");
  });

  // SYNC LOCAL STATS IMMEDIATELY
  try {
    final dbService = DBService();
    // Use timeout to prevent startup hang if DB is slow
    final totalPlays = await dbService
        .getTotalStatsPlays()
        .timeout(const Duration(seconds: 3), onTimeout: () => 0);
    if (totalPlays > 0) {
      await MetricsService().syncLocalStats(totalPlays);
      debugPrint("✅ Startup: Synced $totalPlays local plays to cloud.");
    }
  } catch (e) {
    debugPrint("⚠️ Startup Sync Warning: $e");
  }

  final prefs = await SharedPreferences.getInstance();

  // 2. Initialize Window Manager (Required for Full Screen toggle)
  await windowManager.ensureInitialized();

  // Initialize SMTC
  if (Platform.isWindows) {
    try {
      await SMTCWindows.initialize();
    } catch (e) {
      print("Failed to initialize SMTC: $e");
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
  doWhenWindowReady(() {
    const initialSize = Size(1280, 800);
    appWindow.minSize = const Size(800, 600);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = "Simple Music Player";
    appWindow.show();
  });
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
