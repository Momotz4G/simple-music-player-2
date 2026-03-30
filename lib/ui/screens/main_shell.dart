import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../../l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart'; // 🚀 IMPORT
import 'package:shared_preferences/shared_preferences.dart';

// --- PROVIDER IMPORTS ---
import '../../providers/player_provider.dart';
import '../../providers/library_presentation_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../models/album_model.dart';
import '../../providers/library_provider.dart'; // 🚀 IMPORT (For refresh)
import '../../providers/settings_provider.dart'; // 🚀 DEBUG BUTTON SETTING
import 'package:permission_handler/permission_handler.dart'; // 🚀 IMPORT

// --- COMPONENT IMPORTS ---
import '../components/player_bar.dart';
import '../components/queue_drawer.dart';
import '../components/ambient_background.dart';
import '../components/top_search_bar.dart';
import '../components/themes/winter/snow_fall_widget.dart';
import '../components/themes/winter/santa_sleigh_widget.dart';
import '../components/themes/winter/animated_tree_widget.dart';
import '../components/themes/winter/hanging_lights_widget.dart';
import '../components/themes/winter/snow_pack_widget.dart';

import '../components/themes/autumn/falling_leaves_widget.dart';
import '../components/themes/autumn/autumn_tree_widget.dart';
import '../components/themes/autumn/pumpkin_pack_widget.dart';
import '../components/themes/autumn/autumn_lights_widget.dart';

import '../components/themes/rainy_city/rain_fall_widget.dart';
import '../components/themes/rainy_city/city_skyline_widget.dart';
import '../components/themes/rainy_city/wet_ground_widget.dart';
import '../components/themes/rainy_city/neon_signs_widget.dart';
import '../components/themes/rainy_city/lightning_widget.dart';

import '../components/themes/sakura/sakura_petals_widget.dart';
import '../components/themes/sakura/sakura_tree_widget.dart';
import '../components/themes/sakura/petal_pack_widget.dart';
import '../components/themes/sakura/sakura_lanterns_widget.dart';
import '../components/themes/sakura/sakura_pagoda_widget.dart';
import '../components/themes/sakura/mount_fuji_widget.dart';

import '../components/themes/lunar/falling_hongbao_widget.dart';
import '../components/themes/lunar/firecrackers_widget.dart';
import '../components/themes/lunar/lunar_lanterns_widget.dart';
import '../components/themes/lunar/hongbao_pack_widget.dart';
import '../components/themes/lunar/lunar_gateway_widget.dart';
import '../components/themes/lunar/fireworks_widget.dart';

import '../components/themes/cyberpunk/retro_sun_widget.dart';
import '../components/themes/cyberpunk/cyber_grid_widget.dart';
import '../components/themes/cyberpunk/neon_skyscrapers_widget.dart';
import '../components/themes/cyberpunk/flying_vehicles_widget.dart';
import '../components/themes/cyberpunk/digital_glitch_widget.dart';

import '../components/themes/underwater/ocean_rays_widget.dart';
import '../components/themes/underwater/bubbles_widget.dart';
import '../components/themes/underwater/seaweed_widget.dart';
import '../components/themes/underwater/realistic_whale_widget.dart';
import '../components/themes/underwater/fish_swarm_widget.dart';
import '../components/themes/nordic/aurora_borealis_widget.dart';
import '../components/themes/nordic/starry_sky_widget.dart';
import '../components/themes/nordic/winter_forest_widget.dart';
import '../components/themes/nordic/cozy_cabin_widget.dart';
import '../components/themes/nordic/milky_way_effect_widget.dart';
import '../components/themes/nordic/boreal_lodge_widget.dart';
import '../components/themes/galactic/deep_space_nebula_widget.dart';
import '../components/themes/galactic/cosmic_stars_widget.dart';
import '../components/themes/galactic/earth_view_widget.dart';
import '../components/themes/galactic/satellite_widget.dart';
import '../components/themes/galactic/rocket_widget.dart';

import '../components/themes/desert/desert_sun_widget.dart';
import '../components/themes/desert/rolling_dunes_widget.dart';
import '../components/themes/desert/camel_caravan_widget.dart';
import '../components/themes/desert/heat_distortion_widget.dart';

// --- SCREEN IMPORTS ---
import 'library_page.dart';
import 'settings_page.dart';
import 'lyrics_panel.dart';
import 'artists_page.dart';
import 'albums_page.dart';
import 'playlists_page.dart';
import 'history_page.dart';
import 'stats_page.dart';
import 'home_page.dart';
import 'tools_page.dart';
import 'downloads_page.dart';
import 'search_page.dart';
import 'album_detail_page.dart';
import 'playlist_detail_page.dart';
import 'artist_detail_page.dart';
import 'track_detail_page.dart'; // 🚀 IMPORTED
import 'daily_mix_detail_page.dart'; // 🎵 Daily Mix
import '../../models/song_metadata.dart'; // 🚀 IMPORTED
import '../../models/daily_mix_model.dart'; // 🎵 Daily Mix model
import '../../services/update_service.dart';
import '../../services/bulk_download_service.dart';
import '../../services/smart_download_service.dart';
import '../../services/youtube_downloader_service.dart'; // 🚀 Binaries update
import '../../models/binaries_update_info.dart'; // 🚀 Binaries update
import '../components/download_progress_widget.dart';

import '../../providers/interface_provider.dart';
import 'mini_player.dart';
import '../../models/download_progress.dart';
import '../components/debug_panel.dart';
import '../components/whats_new_dialog.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
  final UpdateService _updateService = UpdateService();
  // 🚀 GlobalKey for drawer control on mobile
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 🚀 CONNECTIVITY MONITORING
  bool _wasOffline = false;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    // 🚀 CHECK FOR UPDATES ON STARTUP
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions(); // 🚀 Request Permissions
      _checkForUpdates();
      _checkWhatsNew();
      _startConnectivityMonitor(); // 🚀 Start monitoring

      // 🚀 CLEANUP OLD UPDATE APKs (Free ~300MB after successful update)
      UpdateService.cleanupOldUpdates();

      // 🚀 CHECK FOR INTERRUPTED UPDATES (Android)
      _checkPendingUpdate();
    });

    // 🚀 LISTEN FOR APP LIFECYCLE (To resume update after permission grant)
    WidgetsBinding.instance.addObserver(this);

    // 🚀 LISTEN FOR BULK DOWNLOAD ERRORS (Ban/Limit)
    BulkDownloadService().errorNotifier.addListener(_onBulkDownloadError);

    // 🚀 LISTEN FOR BINARIES UPDATE (Desktop only - mandatory update)
    YoutubeDownloaderService()
        .binariesUpdateNotifier
        .addListener(_onBinariesUpdate);
  }

  // 🚀 CONNECTIVITY MONITOR
  void _startConnectivityMonitor() {
    _checkConnectivity(); // Initial check
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkConnectivity(),
    );
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      final isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      // 🚀 Show toast when transitioning from offline to online
      if (_wasOffline && isOnline && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi, color: Colors.white),
                SizedBox(width: 12),
                Text('Connected to Internet'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 150, left: 16, right: 16),
          ),
        );
      }

      _wasOffline = !isOnline;
    } catch (_) {
      // Offline
      _wasOffline = true;
    }
  }

  // 🚀 REQUEST RUNTIME PERMISSIONS (Fix for Android 13+ / 10+)
  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;

    bool granted = false;

    // 1. Try Audio (Android 13+)
    if (await Permission.audio.request().isGranted) {
      granted = true;
    }
    // 2. Try Legacy Storage (Android < 13)
    else if (await Permission.storage.request().isGranted) {
      granted = true;
    }

    // 🚀 3. Request Notification Permission (Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // 3. If granted, ensure Library scans
    if (granted) {
      // Refresh library to ensure files are picked up
      ref.read(libraryProvider).refreshLibrary();
    }
  }

  void _onBulkDownloadError() {
    final error = BulkDownloadService().errorNotifier.value;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor:
              error.contains("suspended") ? Colors.red : Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      // Clear the error after showing
      BulkDownloadService().errorNotifier.value = null;
    }
  }

  // 🚀 BINARIES UPDATE (Desktop only - mandatory)
  void _onBinariesUpdate() {
    final updateInfo = YoutubeDownloaderService().binariesUpdateNotifier.value;
    if (updateInfo != null && mounted) {
      // Show mandatory update dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBinariesUpdateDialog(updateInfo);
      });
    }
  }

  void _showBinariesUpdateDialog(BinariesUpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false, // Mandatory - cannot dismiss
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text("Binaries Update Required"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("A new version of yt-dlp is available."),
            const SizedBox(height: 8),
            Text(
              "${updateInfo.currentVersion ?? 'Bundled'} → ${updateInfo.latestVersion}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Size: ${updateInfo.sizeMB} MB",
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "This update is required for YouTube downloads to work correctly.",
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          // No "Later" button - update is mandatory
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadBinariesUpdate();
            },
            child: const Text("Update Now"),
          ),
        ],
      ),
    );
  }

  void _downloadBinariesUpdate() {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ValueListenableBuilder<DownloadProgress?>(
        valueListenable: YoutubeDownloaderService().binariesProgressNotifier,
        builder: (context, progress, child) {
          // Close dialog when download completes
          if (progress == null &&
              YoutubeDownloaderService().binariesUpdateNotifier.value == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(dialogContext)) {
                Navigator.pop(dialogContext);
              }
            });
          }

          final percentage = ((progress?.progress ?? 0) * 100).toInt();
          final receivedMB = progress?.receivedMB.toStringAsFixed(1) ?? '0';
          final totalMB = progress?.totalMB.toStringAsFixed(1) ?? '0';
          final status = progress?.status ?? 'Preparing...';

          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Row(
              children: [
                Icon(Icons.download_rounded, color: Colors.blue),
                SizedBox(width: 8),
                Text("Updating yt-dlp"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress?.progress,
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$receivedMB MB / $totalMB MB",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    Text(
                      "$percentage%",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    // Start the download
    YoutubeDownloaderService().downloadBinariesUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivityTimer?.cancel(); // 🚀 Cancel connectivity monitor
    BulkDownloadService().errorNotifier.removeListener(_onBulkDownloadError);
    YoutubeDownloaderService()
        .binariesUpdateNotifier
        .removeListener(_onBinariesUpdate);
    super.dispose();
  }

  Future<void> _checkWhatsNew() async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;

    final prefs = await SharedPreferences.getInstance();
    final lastVersion = prefs.getString('last_seen_whats_new_version');

    if (lastVersion != currentVersion) {
      // New version detected or first time!
      final release = await _updateService.getLatestRelease();
      if (mounted && release != null) {
        _showWhatsNewDialog(
            release['tag_name'] ?? currentVersion, release['body'] ?? "");
        await prefs.setString('last_seen_whats_new_version', currentVersion);
      }
    }
  }

  void _showWhatsNewDialog(String version, String changelog) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => WhatsNewDialog(
        version: version,
        changelog: changelog,
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    final release = await _updateService.checkForUpdate();
    if (release != null && mounted) {
      // 🚀 Only show update dialog if we DON'T have a pending APK already
      final pendingApk = await _updateService.getPendingUpdatePath();
      if (pendingApk == null) {
        _showUpdateDialog(release);
      }
    }
  }

  // 🚀 RESUME PENDING UPDATE (Android)
  Future<void> _checkPendingUpdate() async {
    if (!Platform.isAndroid) return;

    final pendingPath = await _updateService.getPendingUpdatePath();
    if (pendingPath != null && mounted) {
      print("🚀 Pending update found: $pendingPath");
      _showResumeUpdateDialog(pendingPath);
    }
  }

  void _showResumeUpdateDialog(String filePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text("Finish Update"),
        content: const Text(
          "An update was already downloaded. Would you like to install it now?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateService.installExistingApk(filePath);
            },
            child: const Text("Install Now"),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 🚀 When returning to app (e.g. from Permission Settings), 
    // check if we have a pending update to resume!
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      _checkPendingUpdateAuto();
    }
  }

  Future<void> _checkPendingUpdateAuto() async {
    final pendingPath = await _updateService.getPendingUpdatePath();
    if (pendingPath != null) {
      // If we are resumed, just try to open installer again silently
      // This is helpful if the user just clicked "Allow" in Settings and hit Back.
      _updateService.installExistingApk(pendingPath);
    }
  }

  void _showUpdateDialog(Map<String, dynamic> release) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text("Update Available"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("A new version (${release['tag_name']}) is available."),
            const SizedBox(height: 4),
            // 🚀 Show Size if available
            if (release['assets'] != null &&
                (release['assets'] as List).isNotEmpty)
              FutureBuilder<Map<String, String>?>(
                future: _updateService.getAssetForPlatform(release),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final asset = snapshot.data!;
                    final sizeBytes = int.tryParse(asset['size'] ?? '0') ?? 0;
                    if (sizeBytes == 0) return const SizedBox.shrink();

                    final sizeMB =
                        (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
                    return Text(
                      "Size: $sizeMB MB",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            const SizedBox(height: 12),
            const Text("Do you want to download and install it now?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadAndInstall(release);
            },
            child: const Text("Update Now"),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(Map<String, dynamic> release) async {
    // 🚀 Platform-aware asset selection
    final asset = await _updateService.getAssetForPlatform(release);

    if (asset != null) {
      final downloadUrl = asset['downloadUrl']!;
      final fileName = asset['fileName']!;

      // 🚀 Show download progress dialog ONLY on Android
      // On desktop (Windows/Mac/Linux), sidebar widget shows progress
      if (Platform.isAndroid) {
        _showDownloadProgressDialog();
      }

      try {
        await _updateService.downloadAndInstall(downloadUrl, fileName);
        // Dialog will close automatically when progress reaches 100%
      } catch (e) {
        // Close dialog on error (Android only)
        if (Platform.isAndroid && mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Update failed: $e"),
                backgroundColor: Colors.red),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "No ${_updateService.platformName} installer found in release.")),
      );
    }
  }

  // 🚀 Track if download has started (to avoid closing dialog immediately)
  bool _downloadHasStarted = false;

  void _showDownloadProgressDialog() {
    _downloadHasStarted = false; // Reset flag

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ValueListenableBuilder<DownloadProgress?>(
        valueListenable: _updateService.progressNotifier,
        builder: (context, progress, child) {
          // Track when download actually starts
          if (progress != null) {
            _downloadHasStarted = true;
          }

          // Only close dialog when download has STARTED and then becomes null (finished)
          if (_downloadHasStarted && progress == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(dialogContext)) {
                Navigator.pop(dialogContext);
              }
            });
          }

          final percentage = ((progress?.progress ?? 0) * 100).toInt();
          final receivedMB = progress?.receivedMB.toStringAsFixed(1) ?? '0';
          final totalMB = progress?.totalMB.toStringAsFixed(1) ?? '0';
          final status = progress?.status ?? 'Preparing download...';

          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Row(
              children: [
                const Icon(Icons.download_rounded, color: Colors.blue),
                const SizedBox(width: 8),
                const Text("Downloading Update"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status),
                const SizedBox(height: 16),
                // Progress bar
                LinearProgressIndicator(
                  value: progress?.progress,
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$receivedMB MB / $totalMB MB",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    // 🚀 Speed display
                    if (progress?.speedMBps != null && progress!.speedMBps! > 0)
                      Text(
                        "${progress.speedMBps!.toStringAsFixed(1)} MB/s",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    Text(
                      "$percentage%",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ROUTER
  Widget _getCurrentPage(LibraryView view) {
    switch (view) {
      case LibraryView.browse:
        return const HomePage();
      case LibraryView.localLibrary:
        return const LibraryPage();
      case LibraryView.settings:
        return const SettingsPage();
      case LibraryView.playlists:
        return const PlaylistsPage();
      case LibraryView.artists:
        return const ArtistsPage();
      case LibraryView.albums:
        return const AlbumsPage();
      case LibraryView.history:
        return const HistoryPage();
      case LibraryView.stats:
        return const StatsPage();
      case LibraryView.search:
        return const SearchPage();
      case LibraryView.downloads:
        return const DownloadsPage();
      case LibraryView.tools:
        return const ToolsPage();
      default:
        return const HomePage();
    }
  }

  Widget _buildMainContent(
      List<NavigationItem> stack, LibraryView currentView) {
    if (stack.isNotEmpty) {
      final item = stack.last;
      switch (item.type) {
        case NavigationType.artist:
          final selection = item.data as ArtistSelection;
          return ArtistDetailPage(
            artistName: selection.artistName,
            songs: selection.songs ?? [],
          );
        case NavigationType.album:
          return AlbumDetailPage(album: item.data as AlbumModel);
        case NavigationType.playlist:
          return PlaylistDetailPage(playlistId: item.data as String);
        case NavigationType.track:
          return TrackDetailPage(songMetadata: item.data as SongMetadata);
        case NavigationType.dailyMix:
          return DailyMixDetailPage(mix: item.data as DailyMix);
        default:
          return _getCurrentPage(currentView);
      }
    }
    return _getCurrentPage(currentView);
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 MINI PLAYER SWITCH
    final interfaceState = ref.watch(interfaceProvider);
    if (interfaceState.isMiniPlayer) {
      return const MiniPlayer();
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;
    final screenHeight = MediaQuery.of(context).size.height;

    final presentationState = ref.watch(libraryPresentationProvider);
    final currentView = presentationState.currentView;

    final playerState = ref.watch(playerProvider);
    final isLyricsVisible = playerState.isLyricsVisible;

    final navigationStack = ref.watch(navigationStackProvider);

    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final glassBgColor = settings.atmosphereTheme == AtmosphereTheme.winter
        ? const Color(0xFF0F172A).withValues(alpha: 0.7) // Snowy night color
        : settings.atmosphereTheme == AtmosphereTheme.autumn
            ? const Color(0xFF2D1B0D).withValues(alpha: 0.7) // Autumn sunset
            : isDark
                ? const Color(0xFF121212).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.7);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.space) {
          // Check if we are editing text
          bool isEditing = false;
          final focus = FocusManager.instance.primaryFocus;
          if (focus != null && focus.context != null) {
            focus.context!.visitAncestorElements((element) {
              if (element.widget is EditableText) {
                isEditing = true;
                return false;
              }
              return true;
            });
          }

          if (!isEditing) {
            ref.read(playerProvider.notifier).togglePlay();
            return KeyEventResult.handled;
          }
          // If editing, let the event propagate (return ignored) so TextField gets the space
          return KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: PopScope(
        canPop: false, // We handle all back navigation ourselves
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return; // Already popped, nothing to do

          // 0. If any drawer is open (sidebar menu or queue), close it first
          final scaffoldState = _scaffoldKey.currentState;
          if (scaffoldState != null) {
            if (scaffoldState.isDrawerOpen) {
              scaffoldState.closeDrawer();
              return;
            }
            if (scaffoldState.isEndDrawerOpen) {
              scaffoldState.closeEndDrawer();
              return;
            }
          }

          // 1. If navigation stack has items, pop the last one
          if (navigationStack.isNotEmpty) {
            ref.read(navigationStackProvider.notifier).pop();
            return;
          }

          // 2. If not on Home, go back to Home
          if (currentView != LibraryView.browse) {
            ref
                .read(libraryPresentationProvider.notifier)
                .setView(LibraryView.browse);
            return;
          }

          // 3. Already on Home with empty stack — show exit confirmation
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                'Keluar Aplikasi?',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              content: Text(
                'Apakah Anda yakin ingin keluar?',
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Batal',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text(
                    'Keluar',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          );
        },
        child: Scaffold(
          key: _scaffoldKey, // 🚀 Use GlobalKey for drawer access
          endDrawer: const QueueDrawer(),
          // 🚀 MOBILE: Navigation Drawer (Hamburger Menu)
          drawer: !isDesktop
              ? _buildMobileDrawer(context, currentView, isDark, settings)
              : null,
          body: Stack(
            children: [
              // 1. AMBIENT BACKGROUND LAYER (Bottom)
              const Positioned.fill(
                child: AmbientBackground(),
              ),
              // --- BACKGROUND ATMOSPHERE LAYERS ---
              if (settings.atmosphereTheme == AtmosphereTheme.winter) ...[
                const Positioned.fill(child: SnowFallWidget()),
                const Positioned.fill(child: SantaSleighWidget()),
              ] else if (settings.atmosphereTheme ==
                  AtmosphereTheme.autumn) ...[
                const Positioned.fill(child: FallingLeavesWidget()),
              ] else if (settings.atmosphereTheme ==
                  AtmosphereTheme.rainyCity) ...[
                const Positioned.fill(child: LightningWidget()),
                const Positioned.fill(child: RainFallWidget()),
              ] else if (settings.atmosphereTheme ==
                  AtmosphereTheme.sakura) ...[
                const Positioned.fill(child: SakuraPetalsWidget()),
              ] else if (settings.atmosphereTheme ==
                  AtmosphereTheme.lunarNewYear) ...[
                const Positioned.fill(child: FireworksWidget()),
                const Positioned.fill(child: FallingHongbaoWidget()),
              ] else if (settings.atmosphereTheme ==
                  AtmosphereTheme.cyberpunk) ...[
                const Positioned.fill(child: RetroSunWidget()),
                const Positioned.fill(child: NeonSkyscrapersWidget()),
                const Positioned.fill(child: CyberGridWidget()),
                const Positioned.fill(child: FlyingVehiclesWidget()),
              ] else if (settings.atmosphereTheme ==
                  AtmosphereTheme.underwater) ...[
                const Positioned.fill(child: OceanRaysWidget()),
                const Positioned.fill(child: RealisticWhaleWidget()),
                const Positioned.fill(child: FishSwarmWidget()),
                const Positioned.fill(child: BubblesWidget()),
              ] else if (settings.atmosphereTheme ==
                  AtmosphereTheme.nordicAurora) ...[
                const Positioned.fill(child: StarrySkyWidget()),
                const Positioned.fill(child: MilkyWayEffectWidget()),
                const Positioned.fill(child: AuroraBorealisWidget()),
                const Positioned.fill(child: BorealLodgeWidget()),
                const Positioned.fill(child: WinterForestWidget()),
              ] else if (settings.atmosphereTheme ==
                  AtmosphereTheme.galactic) ...[
                const Positioned.fill(child: CosmicStarsWidget()),
                const Positioned.fill(child: DeepSpaceNebulaWidget()),
                const Positioned.fill(child: EarthViewWidget()),
                const Positioned.fill(child: SatelliteWidget()),
                const Positioned.fill(child: RocketWidget()),
              ] else if (settings.atmosphereTheme ==
                  AtmosphereTheme.desertMirage) ...[
                const Positioned.fill(child: DesertSunWidget()),
                const Positioned.fill(child: HeatDistortionWidget()),
                const Positioned.fill(child: RollingDunesWidget()),
                const Positioned.fill(child: CamelCaravanWidget()),
              ],

              // 2. MAIN CONTENT AREA (Sidebar + Page)
              Positioned.fill(
                top:
                    (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                        ? 32
                        : 0, // Title bar on desktop only
                child: Row(
                  children: [
                    if (isDesktop)
                      _buildSidebar(context, currentView, isDark, glassBgColor),
                    Expanded(
                      child: Stack(
                        children: [
                          if (settings.atmosphereTheme ==
                              AtmosphereTheme.winter)
                            const Positioned(
                              bottom: 83, // Just above player bar
                              left: 0,
                              right: 0,
                              height: 40,
                              child: IgnorePointer(child: SnowPackWidget()),
                            )
                          else if (settings.atmosphereTheme ==
                              AtmosphereTheme.autumn)
                            const Positioned(
                              bottom: 83,
                              left: 0,
                              right: 0,
                              height: 40,
                              child: IgnorePointer(child: PumpkinPackWidget()),
                            )
                          else if (settings.atmosphereTheme ==
                              AtmosphereTheme.rainyCity) ...[
                            Positioned(
                              bottom: 83,
                              left: 0,
                              right: 0,
                              height: 300, // 2x taller than sidebar
                              child: IgnorePointer(
                                child: LayoutBuilder(
                                  builder: (context, constraints) =>
                                      CitySkylineWidget(
                                    height: 300,
                                    width: constraints.maxWidth,
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(
                              bottom: 83,
                              left: 0,
                              right: 0,
                              height: 40,
                              child: IgnorePointer(child: WetGroundWidget()),
                            ),
                          ] else if (settings.atmosphereTheme ==
                              AtmosphereTheme.sakura) ...[
                            const Positioned(
                              bottom: 83,
                              left: 0,
                              right: 0,
                              height: 400, // Grand distant mountain
                              child: IgnorePointer(child: MountFujiWidget()),
                            ),
                            Positioned(
                              bottom: 83,
                              right: 120, // More center
                              height: 350, // Much bigger
                              width: 220, // Much bigger
                              child: const IgnorePointer(
                                child:
                                    SakuraPagodaWidget(height: 350, width: 220),
                              ),
                            ),
                            const Positioned(
                              bottom: 83,
                              left: 0,
                              right: 0,
                              height: 40,
                              child: IgnorePointer(child: PetalPackWidget()),
                            ),
                          ] else if (settings.atmosphereTheme ==
                              AtmosphereTheme.lunarNewYear) ...[
                            const Positioned(
                              bottom: 83,
                              left: 0,
                              right: 0,
                              height: 300,
                              child: IgnorePointer(
                                  child: LunarGatewayWidget(
                                      height: 300, width: 400)),
                            ),
                            const Positioned(
                              bottom: 83,
                              left: 0,
                              right: 0,
                              height: 40,
                              child: IgnorePointer(child: HongbaoPackWidget()),
                            ),
                          ],
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              key: ValueKey(navigationStack.isNotEmpty
                                  ? 'stack_${navigationStack.length}_${navigationStack.last.type}'
                                  : currentView),
                              padding: navigationStack.isNotEmpty
                                  ? (isDesktop
                                      ? const EdgeInsets.only(bottom: 90)
                                      : const EdgeInsets.only(bottom: 140))
                                  : EdgeInsets.only(
                                      bottom: isDesktop ? 90 : 140),
                              child: _buildMainContent(
                                  navigationStack, currentView),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. CUSTOM TITLE BAR (Top Layer - Desktop Only)
              if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 40,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        color: glassBgColor,
                        child: WindowTitleBarBox(
                          child: Row(
                            children: [
                              Expanded(child: MoveWindow()),
                              const TopSearchBar(),
                              Expanded(child: MoveWindow()),
                              const WindowButtons(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 4. LYRICS PANEL OVERLAY
              // 4. LYRICS PANEL OVERLAY (Desktop Only)

              // 5. HANGING OVERLAYS (pinned at top, above content)
              if (settings.atmosphereTheme != AtmosphereTheme.none &&
                  settings.atmosphereTheme != AtmosphereTheme.underwater &&
                  settings.atmosphereTheme != AtmosphereTheme.cyberpunk &&
                  settings.atmosphereTheme != AtmosphereTheme.nordicAurora &&
                  settings.atmosphereTheme != AtmosphereTheme.galactic &&
                  settings.atmosphereTheme != AtmosphereTheme.desertMirage)
                Positioned(
                  top: (Platform.isWindows ||
                          Platform.isLinux ||
                          Platform.isMacOS)
                      ? 33
                      : 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: IgnorePointer(
                    child: settings.atmosphereTheme == AtmosphereTheme.winter
                        ? const HangingLightsWidget()
                        : settings.atmosphereTheme == AtmosphereTheme.autumn
                            ? const AutumnLightsWidget()
                            : settings.atmosphereTheme == AtmosphereTheme.sakura
                                ? const SakuraLanternsWidget()
                                : settings.atmosphereTheme ==
                                        AtmosphereTheme.lunarNewYear
                                    ? const LunarLanternsWidget()
                                    : const NeonSignsWidget(),
                  ),
                ),
              if (isDesktop)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  left: 0,
                  right: 0,
                  top: isLyricsVisible ? 32 : screenHeight,
                  height: screenHeight - 32,
                  child: const LyricsPanel(),
                ),

              // 5. PLAYER BAR (Fixed Bottom)
              const Positioned(
                  left: 0, right: 0, bottom: 0, child: PlayerBar()),

              // 6. MOBILE: Hamburger Menu Button (Overlay)
              // 🚀 Only show on main pages (empty stack), otherwise rely on Back button
              if (!isDesktop && navigationStack.isEmpty)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: Builder(
                    // Use Builder to get the Scaffold's context
                    builder: (scaffoldContext) => Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        iconSize: 28,
                        color: isDark ? Colors.white : Colors.black,
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      ),
                    ),
                  ),
                ),

              // 7. DEBUG FLOATING BUTTON (Conditional - All Platforms)
              if (ref.watch(settingsProvider).showDebugButton)
                const DebugFloatingButton(child: SizedBox.shrink()),
            ],
          ),
          // 🚀 Removed NavigationBar - replaced with drawer
        ),
      ), // Close PopScope
    );
  }

  Widget _buildSidebar(BuildContext context, LibraryView currentView,
      bool isDark, Color glassBgColor) {
    final notifier = ref.read(libraryPresentationProvider.notifier);
    final settings = ref.watch(settingsProvider);

    // Check if we are in album mode (or any detail mode)
    final navigationStack = ref.watch(navigationStackProvider);
    final hasSelection = navigationStack.isNotEmpty;

    final separatorColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.2);
    final headerTextColor = isDark ? Colors.grey[400] : Colors.grey[700];

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 250,
          decoration: BoxDecoration(
            color: glassBgColor,
            border: Border(
              right: BorderSide(color: separatorColor, width: 1.0),
            ),
          ),
          child: Stack(
            children: [
              if (settings.atmosphereTheme == AtmosphereTheme.cyberpunk)
                const Positioned.fill(child: DigitalGlitchWidget()),
              if (settings.atmosphereTheme == AtmosphereTheme.underwater)
                const Positioned(
                  bottom: -10,
                  left: 0,
                  right: 0,
                  child: SeaweedWidget(height: 200, width: 250),
                ),
              if (settings.atmosphereTheme == AtmosphereTheme.nordicAurora)
                const Positioned(
                  bottom: -10,
                  left: 0,
                  right: 0,
                  height: 100,
                  child: CozyCabinWidget(),
                ),
              // Add underlying tree widgets directly in stack before Column
              if (settings.atmosphereTheme == AtmosphereTheme.winter)
                const Positioned(
                  bottom: 83,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedTreeWidget(height: 150, width: 250),
                  ),
                )
              else if (settings.atmosphereTheme == AtmosphereTheme.autumn)
                const Positioned(
                  bottom: 83,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AutumnTreeWidget(height: 150, width: 250),
                  ),
                )
              else if (settings.atmosphereTheme == AtmosphereTheme.rainyCity)
                const Positioned(
                  bottom: 83,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: CitySkylineWidget(height: 150, width: 250),
                  ),
                )
              else if (settings.atmosphereTheme == AtmosphereTheme.sakura)
                const Positioned(
                  bottom: 83,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SakuraTreeWidget(height: 100, width: 250),
                  ),
                )
              else if (settings.atmosphereTheme == AtmosphereTheme.lunarNewYear)
                const Positioned(
                  bottom: 83,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FirecrackersWidget(height: 140, width: 60),
                  ),
                ),
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(top: 0),
                      physics: const ClampingScrollPhysics(),
                      children: [
                        _buildNavItem(
                            context,
                            AppLocalizations.of(context)!.browse,
                            Icons.home_rounded,
                            LibraryView.browse,
                            currentView,
                            notifier,
                            isDark,
                            hasSelection),
                        _buildNavItem(
                            context,
                            AppLocalizations.of(context)!.search,
                            Icons.search_rounded,
                            LibraryView.search,
                            currentView,
                            notifier,
                            isDark,
                            hasSelection),
                        _buildNavItem(
                            context,
                            AppLocalizations.of(context)!.history,
                            Icons.history_rounded,
                            LibraryView.history,
                            currentView,
                            notifier,
                            isDark,
                            hasSelection),
                        _buildNavItem(
                            context,
                            AppLocalizations.of(context)!.stats,
                            Icons.bar_chart_rounded,
                            LibraryView.stats,
                            currentView,
                            notifier,
                            isDark,
                            hasSelection),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Divider(
                              height: 1,
                              indent: 24,
                              endIndent: 24,
                              color: separatorColor),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 24, bottom: 12),
                          child: Text(AppLocalizations.of(context)!.library,
                              style: TextStyle(
                                  color: headerTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.0)),
                        ),
                        _buildNavItem(
                            context,
                            AppLocalizations.of(context)!.playlists,
                            Icons.playlist_play_rounded,
                            LibraryView.playlists,
                            currentView,
                            notifier,
                            isDark,
                            hasSelection),
                        _buildNavItem(
                            context,
                            AppLocalizations.of(context)!.artists,
                            Icons.person_rounded,
                            LibraryView.artists,
                            currentView,
                            notifier,
                            isDark,
                            hasSelection),
                        _buildNavItem(
                            context,
                            AppLocalizations.of(context)!.albums,
                            Icons.album_rounded,
                            LibraryView.albums,
                            currentView,
                            notifier,
                            isDark,
                            hasSelection),
                        _buildNavItem(
                            context,
                            AppLocalizations.of(context)!.local_library,
                            Icons.folder_rounded,
                            LibraryView.localLibrary,
                            currentView,
                            notifier,
                            isDark,
                            hasSelection),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Divider(
                              height: 1,
                              indent: 24,
                              endIndent: 24,
                              color: separatorColor),
                        ),
                        _buildNavItem(
                            context,
                            AppLocalizations.of(context)!.downloads,
                            Icons.download_rounded,
                            LibraryView.downloads,
                            currentView,
                            notifier,
                            isDark,
                            hasSelection),
                        _buildNavItem(
                            context,
                            AppLocalizations.of(context)!.metadata_editor,
                            Icons.build_circle_rounded,
                            LibraryView.tools,
                            currentView,
                            notifier,
                            isDark,
                            hasSelection),
                        _buildNavItem(
                            context,
                            AppLocalizations.of(context)!.settings,
                            Icons.settings_rounded,
                            LibraryView.settings,
                            currentView,
                            notifier,
                            isDark,
                            hasSelection),

                        // 🚀 DOWNLOAD PROGRESS WIDGET
                        ValueListenableBuilder<DownloadProgress?>(
                          valueListenable: _updateService.progressNotifier,
                          builder: (context, progress, child) {
                            if (progress == null) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: DownloadProgressWidget(progress: progress),
                            );
                          },
                        ),

                        // 🚀 BULK DOWNLOAD PROGRESS WIDGET
                        ValueListenableBuilder<DownloadProgress?>(
                          valueListenable:
                              BulkDownloadService().progressNotifier,
                          builder: (context, progress, child) {
                            if (progress == null) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: DownloadProgressWidget(
                                progress: progress,
                                onCancel: () {
                                  BulkDownloadService().cancelDownload();
                                },
                              ),
                            );
                          },
                        ),

                        // 🚀 SINGLE SONG DOWNLOAD PROGRESS WIDGET (from context menu)
                        ValueListenableBuilder<DownloadProgress?>(
                          valueListenable:
                              SmartDownloadService.progressNotifier,
                          builder: (context, progress, child) {
                            if (progress == null) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: DownloadProgressWidget(progress: progress),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 83),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context,
      String title,
      IconData icon,
      LibraryView targetView,
      LibraryView currentView,
      LibraryPresentationNotifier notifier,
      bool isDark,
      bool hasSelection) {
    // Only show active if view matches AND no detail page is selected
    final isSelected = (targetView == currentView) && !hasSelection;

    final accentColor = Theme.of(context).colorScheme.primary;
    final defaultColor = isDark ? Colors.grey[400] : Colors.grey[800];
    final selectedTextColor = isDark ? accentColor : accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListTile(
        title: Text(title,
            style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
                color: isSelected ? selectedTextColor : defaultColor)),
        leading: Icon(icon,
            size: 22, color: isSelected ? selectedTextColor : defaultColor),
        selected: isSelected,
        selectedTileColor: accentColor.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        dense: true,
        onTap: () {
          // Clear navigation stack when navigating main tabs
          ref.read(navigationStackProvider.notifier).clear();
          notifier.setView(targetView);
        },
      ),
    );
  }

  // 🚀 MOBILE NAVIGATION DRAWER
  Widget _buildMobileDrawer(BuildContext context, LibraryView currentView,
      bool isDark, SettingsState settings) {
    final notifier = ref.read(libraryPresentationProvider.notifier);
    final navigationStack = ref.watch(navigationStackProvider);
    final hasSelection = navigationStack.isNotEmpty;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Text(
                AppLocalizations.of(context)!.navigation,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            const Divider(height: 1),

            // Navigation Items
            _buildMobileNavItem(
                context,
                AppLocalizations.of(context)!.browse,
                Icons.home_rounded,
                LibraryView.browse,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                AppLocalizations.of(context)!.search,
                Icons.search_rounded,
                LibraryView.search,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                AppLocalizations.of(context)!.history,
                Icons.history_rounded,
                LibraryView.history,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                AppLocalizations.of(context)!.stats,
                Icons.bar_chart_rounded,
                LibraryView.stats,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),

            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Text(AppLocalizations.of(context)!.library,
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),

            _buildMobileNavItem(
                context,
                AppLocalizations.of(context)!.playlists,
                Icons.playlist_play_rounded,
                LibraryView.playlists,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                AppLocalizations.of(context)!.artists,
                Icons.person_rounded,
                LibraryView.artists,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                AppLocalizations.of(context)!.albums,
                Icons.album_rounded,
                LibraryView.albums,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                AppLocalizations.of(context)!.local_library,
                Icons.folder_rounded,
                LibraryView.localLibrary,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),

            const Divider(height: 16),

            _buildMobileNavItem(
                context,
                AppLocalizations.of(context)!.downloads,
                Icons.download_rounded,
                LibraryView.downloads,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                AppLocalizations.of(context)!.metadata_editor,
                Icons.build_circle_rounded,
                LibraryView.tools,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                AppLocalizations.of(context)!.settings,
                Icons.settings_rounded,
                LibraryView.settings,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),

            // 🚀 DOWNLOAD PROGRESS WIDGETS
            const Divider(height: 16),
            ValueListenableBuilder<DownloadProgress?>(
              valueListenable: UpdateService().progressNotifier,
              builder: (context, progress, child) {
                if (progress == null) return const SizedBox.shrink();
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DownloadProgressWidget(progress: progress),
                );
              },
            ),
            ValueListenableBuilder<DownloadProgress?>(
              valueListenable: BulkDownloadService().progressNotifier,
              builder: (context, progress, child) {
                if (progress == null) return const SizedBox.shrink();
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DownloadProgressWidget(
                    progress: progress,
                    onCancel: () => BulkDownloadService().cancelDownload(),
                  ),
                );
              },
            ),
            ValueListenableBuilder<DownloadProgress?>(
              valueListenable: SmartDownloadService.progressNotifier,
              builder: (context, progress, child) {
                if (progress == null) return const SizedBox.shrink();
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DownloadProgressWidget(progress: progress),
                );
              },
            ),

            // 🎄 MOBILE SEASONAL TREE
            if (settings.atmosphereTheme == AtmosphereTheme.winter) ...[
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, constraints) {
                return AnimatedTreeWidget(
                  height: 150,
                  width: constraints.maxWidth,
                );
              }),
            ] else if (settings.atmosphereTheme == AtmosphereTheme.autumn) ...[
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, constraints) {
                return AutumnTreeWidget(
                  height: 150,
                  width: constraints.maxWidth,
                );
              }),
            ] else if (settings.atmosphereTheme ==
                AtmosphereTheme.rainyCity) ...[
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, constraints) {
                return CitySkylineWidget(
                  height: 150,
                  width: constraints.maxWidth,
                );
              }),
            ] else if (settings.atmosphereTheme == AtmosphereTheme.sakura) ...[
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, constraints) {
                return SakuraTreeWidget(
                  height: 150,
                  width: constraints.maxWidth,
                );
              }),
            ] else if (settings.atmosphereTheme ==
                AtmosphereTheme.lunarNewYear) ...[
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, constraints) {
                return FirecrackersWidget(
                  height: 180,
                  width: constraints.maxWidth,
                );
              }),
            ],

            const SizedBox(height: 30), // Padding at the very bottom
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavItem(
      BuildContext context,
      String title,
      IconData icon,
      LibraryView targetView,
      LibraryView currentView,
      LibraryPresentationNotifier notifier,
      bool isDark,
      bool hasSelection,
      Color accentColor) {
    final isSelected = (targetView == currentView) && !hasSelection;
    final defaultColor = isDark ? Colors.grey[400] : Colors.grey[800];
    final selectedColor = accentColor;

    return ListTile(
      leading: Icon(icon, color: isSelected ? selectedColor : defaultColor),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? selectedColor
              : (isDark ? Colors.white : Colors.black),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: accentColor.withValues(alpha: 0.1),
      onTap: () {
        // Close drawer first
        Navigator.of(context).pop();
        // Navigate
        ref.read(navigationStackProvider.notifier).clear();
        notifier.setView(targetView);
      },
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  void _showAboutDialog(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Image.asset(
              'assets/app_icon.ico',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 12),
            const Text("Simple Music Player New Gen"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Version $version",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              "This application is developed for individual and educational purposes only.",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              "Not for commercial use.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              "© 2026 Stephanus Alexander Momot. All Rights Reserved.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: "Simple Music Player",
              applicationVersion: version,
              applicationLegalese: "© 2026 Stephanus Alexander Momot",
            ),
            child: const Text("Open Source Licenses"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);

    final buttonColors = WindowButtonColors(
        iconNormal: iconColor,
        mouseOver: hoverColor,
        mouseDown: iconColor.withValues(alpha: 0.2),
        iconMouseOver: iconColor,
        iconMouseDown: iconColor);

    final closeButtonColors = WindowButtonColors(
        mouseOver: const Color(0xFFD32F2F),
        mouseDown: const Color(0xFFB71C1C),
        iconNormal: iconColor,
        iconMouseOver: Colors.white);

    return Row(
      children: [
        Tooltip(
          message: "About & Licenses",
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showAboutDialog(context),
              hoverColor: hoverColor,
              child: SizedBox(
                width: 46, // Standard Windows button width
                height: 32,
                child: Icon(Icons.info_outline_rounded,
                    size: 18, color: iconColor.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ),
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(colors: closeButtonColors),
      ],
    );
  }
}
