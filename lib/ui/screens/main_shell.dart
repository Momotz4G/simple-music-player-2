import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🚀 Required for LogicalKeyboardKey
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
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
import '../../models/song_metadata.dart'; // 🚀 IMPORTED
import '../../services/update_service.dart';
import '../../services/bulk_download_service.dart';
import '../../services/smart_download_service.dart';
import '../components/download_progress_widget.dart';

import '../../providers/interface_provider.dart';
import 'mini_player.dart';
import '../../models/download_progress.dart';
import '../components/debug_panel.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
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
    });

    // 🚀 LISTEN FOR BULK DOWNLOAD ERRORS (Ban/Limit)
    BulkDownloadService().errorNotifier.addListener(_onBulkDownloadError);
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
          SnackBar(
            content: Row(
              children: const [
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

  @override
  void dispose() {
    _connectivityTimer?.cancel(); // 🚀 Cancel connectivity monitor
    BulkDownloadService().errorNotifier.removeListener(_onBulkDownloadError);
    super.dispose();
  }

  Future<void> _checkWhatsNew() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    final lastVersion = prefs.getString('last_start_version');

    if (lastVersion != currentVersion) {
      // New version detected!
      final release = await _updateService.getLatestRelease();
      if (release != null && mounted) {
        // Only show if the tag matches or contains the current version (approx)
        // or just show it anyway as "What's New in the invalid latest"
        // Better: Show it if we updated.
        _showWhatsNewDialog(release, currentVersion);
        await prefs.setString('last_start_version', currentVersion);
      }
    }
  }

  void _showWhatsNewDialog(Map<String, dynamic> release, String version) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.orange),
            const SizedBox(width: 8),
            Text("What's New in v$version"),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  release['body'] ?? "No changelog available.",
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Awesome!"),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    final release = await _updateService.checkForUpdate();
    if (release != null && mounted) {
      _showUpdateDialog(release);
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
              Builder(
                builder: (context) {
                  final assets = release['assets'] as List;
                  final exeAsset = assets.firstWhere(
                    (asset) => asset['name'].toString().endsWith('.exe'),
                    orElse: () => assets.first,
                  );
                  final sizeBytes = exeAsset['size'] as int;
                  final sizeMB = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
                  return Text(
                    "Size: $sizeMB MB",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  );
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
    final asset = _updateService.getAssetForPlatform(release);

    if (asset != null) {
      final downloadUrl = asset['downloadUrl']!;
      final fileName = asset['fileName']!;

      // 🚀 Remove SnackBar, just start download.
      // The sidebar widget will appear automatically because it listens to the notifier.
      try {
        await _updateService.downloadAndInstall(downloadUrl, fileName);
      } catch (e) {
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

    // 🚀 WATCH NAVIGATION STACK
    final navigationStack = ref.watch(navigationStackProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final glassBgColor = isDark
        ? const Color(0xFF121212).withOpacity(0.7)
        : Colors.white.withOpacity(0.7);

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
      child: Scaffold(
        key: _scaffoldKey, // 🚀 Use GlobalKey for drawer access
        endDrawer: const QueueDrawer(),
        // 🚀 MOBILE: Navigation Drawer (Hamburger Menu)
        drawer: !isDesktop
            ? _buildMobileDrawer(context, currentView, isDark)
            : null,
        body: Stack(
          children: [
            // 1. AMBIENT BACKGROUND LAYER (Bottom)
            const Positioned.fill(
              child: AmbientBackground(),
            ),

            // 2. MAIN CONTENT AREA (Sidebar + Page)
            Positioned.fill(
              top: (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                  ? 32
                  : 0, // Title bar on desktop only
              child: Row(
                children: [
                  if (isDesktop)
                    _buildSidebar(context, currentView, isDark, glassBgColor),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(navigationStack.isNotEmpty
                            ? 'stack_${navigationStack.length}_${navigationStack.last.type}'
                            : currentView),
                        padding: navigationStack.isNotEmpty
                            ? (isDesktop
                                ? EdgeInsets.zero
                                : const EdgeInsets.only(bottom: 140))
                            : EdgeInsets.only(bottom: isDesktop ? 105 : 140),
                        child: _buildMainContent(navigationStack, currentView),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. CUSTOM TITLE BAR (Top Layer - Desktop Only)
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
            const Positioned(left: 0, right: 0, bottom: 0, child: PlayerBar()),

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
                          ? Colors.black.withOpacity(0.7)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      iconSize: 28,
                      color: isDark ? Colors.white : Colors.black,
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
    );
  }

  Widget _buildSidebar(BuildContext context, LibraryView currentView,
      bool isDark, Color glassBgColor) {
    final notifier = ref.read(libraryPresentationProvider.notifier);

    // Check if we are in album mode (or any detail mode)
    final navigationStack = ref.watch(navigationStackProvider);
    final hasSelection = navigationStack.isNotEmpty;

    final separatorColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2);
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
          child: ListView(
            padding: const EdgeInsets.only(top: 0),
            children: [
              _buildNavItem(
                  context,
                  'Browse',
                  Icons.home_rounded,
                  LibraryView.browse,
                  currentView,
                  notifier,
                  isDark,
                  hasSelection),
              _buildNavItem(
                  context,
                  'Search',
                  Icons.search_rounded,
                  LibraryView.search,
                  currentView,
                  notifier,
                  isDark,
                  hasSelection),
              _buildNavItem(
                  context,
                  'History',
                  Icons.history_rounded,
                  LibraryView.history,
                  currentView,
                  notifier,
                  isDark,
                  hasSelection),
              _buildNavItem(
                  context,
                  'Stats',
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
                child: Text('LIBRARY',
                    style: TextStyle(
                        color: headerTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.0)),
              ),
              _buildNavItem(
                  context,
                  'Playlists',
                  Icons.playlist_play_rounded,
                  LibraryView.playlists,
                  currentView,
                  notifier,
                  isDark,
                  hasSelection),
              _buildNavItem(
                  context,
                  'Artists',
                  Icons.person_rounded,
                  LibraryView.artists,
                  currentView,
                  notifier,
                  isDark,
                  hasSelection),
              _buildNavItem(
                  context,
                  'Albums',
                  Icons.album_rounded,
                  LibraryView.albums,
                  currentView,
                  notifier,
                  isDark,
                  hasSelection),
              _buildNavItem(
                  context,
                  'Local Library',
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
                  'Downloads',
                  Icons.download_rounded,
                  LibraryView.downloads,
                  currentView,
                  notifier,
                  isDark,
                  hasSelection),
              _buildNavItem(
                  context,
                  'Metadata Editor',
                  Icons.build_circle_rounded,
                  LibraryView.tools,
                  currentView,
                  notifier,
                  isDark,
                  hasSelection),
              _buildNavItem(
                  context,
                  'Settings',
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
                  if (progress == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: DownloadProgressWidget(progress: progress),
                  );
                },
              ),

              // 🚀 BULK DOWNLOAD PROGRESS WIDGET
              ValueListenableBuilder<DownloadProgress?>(
                valueListenable: BulkDownloadService().progressNotifier,
                builder: (context, progress, child) {
                  if (progress == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: DownloadProgressWidget(progress: progress),
                  );
                },
              ),

              // 🚀 SINGLE SONG DOWNLOAD PROGRESS WIDGET (from context menu)
              ValueListenableBuilder<DownloadProgress?>(
                valueListenable: SmartDownloadService.progressNotifier,
                builder: (context, progress, child) {
                  if (progress == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: DownloadProgressWidget(progress: progress),
                  );
                },
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
        selectedTileColor: accentColor.withOpacity(0.1),
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
  Widget _buildMobileDrawer(
      BuildContext context, LibraryView currentView, bool isDark) {
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
                'Navigation',
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
                'Browse',
                Icons.home_rounded,
                LibraryView.browse,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                'Search',
                Icons.search_rounded,
                LibraryView.search,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                'History',
                Icons.history_rounded,
                LibraryView.history,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                'Stats',
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
              child: Text('LIBRARY',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),

            _buildMobileNavItem(
                context,
                'Playlists',
                Icons.playlist_play_rounded,
                LibraryView.playlists,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                'Artists',
                Icons.person_rounded,
                LibraryView.artists,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                'Albums',
                Icons.album_rounded,
                LibraryView.albums,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                'Local Library',
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
                'Downloads',
                Icons.download_rounded,
                LibraryView.downloads,
                currentView,
                notifier,
                isDark,
                hasSelection,
                accentColor),
            _buildMobileNavItem(
                context,
                'Settings',
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
                  child: DownloadProgressWidget(progress: progress),
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
      selectedTileColor: accentColor.withOpacity(0.1),
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
              "© 2025 Stephanus Alexander Momot. All Rights Reserved.",
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
              applicationLegalese: "© 2025 Stephanus Alexander Momot",
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
    final hoverColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);

    final buttonColors = WindowButtonColors(
        iconNormal: iconColor,
        mouseOver: hoverColor,
        mouseDown: iconColor.withOpacity(0.2),
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
                    size: 18, color: iconColor.withOpacity(0.7)),
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
