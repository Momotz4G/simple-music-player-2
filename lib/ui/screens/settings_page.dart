// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import '../../utils/folder_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart'; // Import for device list
import 'package:simple_music_player_2/l10n/app_localizations.dart';

import '../../providers/settings_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/data_usage_provider.dart'; // Added
import '../../providers/stats_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/youtube_downloader_service.dart';
import '../../services/metrics_service.dart';
import '../../services/android_audio_service.dart'; // NEW
import '../../services/usb_audio_service.dart'; // USB Audio for Android <14
import '../../services/db_service.dart'; // ADDED
import '../../services/canvas_service.dart';
import '../../utils/layout_engine.dart';
import '../components/smart_art.dart';
import 'admin_stats_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _cacheSizeText = "";
  int _metadataCacheCount = 0;
  String _metadataCacheSize = "0.0 KB";
  String _versionText = "";
  final YoutubeDownloaderService _ytService = YoutubeDownloaderService();

  final TextEditingController _formatCtrl = TextEditingController();
  final TextEditingController _playlistFormatCtrl = TextEditingController();

  String _savedPattern = "{artist} - {title}";
  String _savedPlaylistPattern = "{artist} - {title}";

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _offlineModeKey = GlobalKey();

  // Tablet master-detail: selected settings category index
  int _selectedCategoryIndex = 0;

  // GlobalKeys for each settings category section (used for scroll-to in master-detail)
  final List<GlobalKey> _categoryKeys = List.generate(12, (_) => GlobalKey());

  // Separate scroll controller for the detail panel in master-detail mode
  final ScrollController _detailScrollController = ScrollController();

  // Pre-cached future for SharedPreferences (avoids re-creating on every build)
  late final Future<SharedPreferences> _prefsFuture;

  // Audio Device Handling
  List<Map<String, String>> _audioDevices = [];
  bool _loadingAudioDevices = false;
  bool _isAndroidBitPerfectSupported = false; // NEW

  // USB Audio for Android <14 (Temporarily placeholders to avoid compilation errors)
  final List<UsbDacDevice> _usbDacs = [];
  final bool _loadingUsbDacs = false;

  bool get _unsavedSingle => _formatCtrl.text != _savedPattern;
  bool get _unsavedPlaylist =>
      _playlistFormatCtrl.text != _savedPlaylistPattern;

  late AppLocalizations _l10n;

  String _getStreamingQualityDescription(String quality) {
    switch (quality) {
      case 'standard':
        return _l10n.standardDesc;
      case 'high':
        return _l10n.highDesc;
      case 'lossless':
        return _l10n.losslessDesc;
      default:
        return _l10n.selectStreamingQuality;
    }
  }

  @override
  void initState() {
    super.initState();
    _prefsFuture = SharedPreferences.getInstance();
    _loadCacheSize();
    _loadFormat();
    if (Platform.isWindows) {
      _loadAudioDevices();
    }
    if (Platform.isAndroid) {
      _checkAndroidSupport();
    }

    // Check for initial navigation signals
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final section = ref.read(settingsNavigationProvider);
      if (section == SettingsSection.offlineMode) {
        _scrollToOffline();
        ref.read(settingsNavigationProvider.notifier).state =
            SettingsSection.none;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context)!;
    _loadVersion();
  }

  Future<void> _checkAndroidSupport() async {
    final supported = await AndroidAudioService.isBitPerfectSupported();
    if (mounted) {
      setState(() {
        _isAndroidBitPerfectSupported = supported;
      });
    }
  }

  Future<void> _loadAudioDevices() async {
    setState(() => _loadingAudioDevices = true);
    try {
      final devices = await JustAudioMediaKit.listAudioDevices();
      if (mounted) {
        setState(() {
          _audioDevices = devices;
          _loadingAudioDevices = false;
        });
      }
    } catch (e) {
      debugPrint("Error listing devices: $e");
      if (mounted) setState(() => _loadingAudioDevices = false);
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _versionText = "${_l10n.version} ${info.version}";
      });
    }
  }

  @override
  void dispose() {
    _formatCtrl.dispose();
    _playlistFormatCtrl.dispose();
    _scrollController.dispose();
    _detailScrollController.dispose();
    super.dispose();
  }

  void _scrollToOffline() {
    // Increased delay to ensure the ListView has fully rendered the target child
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final targetContext = _offlineModeKey.currentContext;
      if (targetContext != null && targetContext.mounted) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
          alignment: 0.1, // Scroll to near the top of the viewport
        );
      }
    });
  }

  Future<void> _loadCacheSize() async {
    final size = await _ytService.getCacheSize();
    final count = await DBService().getMetadataCacheCount();
    final metadataSize = await DBService().getMetadataCacheSize();
    if (mounted) {
      setState(() {
        _cacheSizeText = size;
        _metadataCacheCount = count;
        _metadataCacheSize = metadataSize;
      });
    }
  }

  Future<void> _loadFormat() async {
    final prefs = await SharedPreferences.getInstance();
    final pattern = prefs.getString('filename_pattern') ?? "{artist} - {title}";
    final playlistPattern =
        prefs.getString('playlist_filename_pattern') ?? "{artist} - {title}";

    if (mounted) {
      setState(() {
        _savedPattern = pattern;
        _savedPlaylistPattern = playlistPattern;

        _formatCtrl.text = pattern;
        _playlistFormatCtrl.text = playlistPattern;
      });
    }
  }

  void _onFormatChanged(String value) {
    setState(() {});
  }

  void _onPlaylistFormatChanged(String value) {
    setState(() {});
  }

  Future<void> _saveFormat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('filename_pattern', _formatCtrl.text);
    await prefs.setString(
        'playlist_filename_pattern', _playlistFormatCtrl.text);

    if (mounted) {
      setState(() {
        _savedPattern = _formatCtrl.text;
        _savedPlaylistPattern = _playlistFormatCtrl.text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.formatSaved)),
      );
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _pickDownloadPath(BuildContext context) async {
    String? selectedDirectory = await FolderPicker.pickDirectory();
    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_download_path', selectedDirectory);
      if (context.mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "${AppLocalizations.of(context)!.downloadPathUpdated} $selectedDirectory")),
        );
      }
    }
  }

  Future<void> _resetDownloadPath(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_download_path');
    if (context.mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.downloadPathReset)),
      );
    }
  }

  Widget _buildTagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  void _showGranularServicesDialog(
      BuildContext context, Color textColor, Color subtitleColor, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(AppLocalizations.of(context)!.disableServicesTitle,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, child) {
                  final settings = ref.watch(settingsProvider);
                  final settingsNotifier = ref.read(settingsProvider.notifier);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildGranularToggle(
                        title: AppLocalizations.of(context)!.featureCloudSync,
                        subtitle: AppLocalizations.of(context)!
                            .featureCloudSyncLongDesc,
                        icon: Icons.cloud_sync_rounded,
                        value: settings.enableCloudSync,
                        isOfflineMode: settings.isOfflineMode,
                        activeColor: Colors.red[400]!,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onChanged: (val) =>
                            settingsNotifier.toggleCloudSync(val),
                      ),
                      _buildGranularToggle(
                        title: AppLocalizations.of(context)!.featureLeaderboard,
                        subtitle: AppLocalizations.of(context)!
                            .featureLeaderboardLongDesc,
                        icon: Icons.leaderboard_rounded,
                        value: settings.enableLeaderboard,
                        isOfflineMode: settings.isOfflineMode,
                        activeColor: Colors.amber[400]!,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onChanged: (val) =>
                            settingsNotifier.toggleLeaderboard(val),
                      ),
                      _buildGranularToggle(
                        title:
                            AppLocalizations.of(context)!.featureOnlineLyrics,
                        subtitle: AppLocalizations.of(context)!
                            .featureOnlineLyricsLongDesc,
                        icon: Icons.lyrics_rounded,
                        value: settings.enableOnlineLyrics,
                        isOfflineMode: settings.isOfflineMode,
                        activeColor: Colors.blue[400]!,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onChanged: (val) =>
                            settingsNotifier.toggleOnlineLyrics(val),
                      ),
                      _buildGranularToggle(
                        title: AppLocalizations.of(context)!.featureAiLyrics,
                        subtitle: AppLocalizations.of(context)!
                            .featureAiLyricsLongDesc,
                        icon: Icons.auto_awesome_rounded,
                        value: settings.enableAiLyrics,
                        isOfflineMode: settings.isOfflineMode,
                        activeColor: Colors.purple[400]!,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onChanged: (val) =>
                            settingsNotifier.toggleAiLyrics(val),
                      ),
                      _buildGranularToggle(
                        title:
                            AppLocalizations.of(context)!.featureSpotifyCanvas,
                        subtitle: AppLocalizations.of(context)!
                            .featureSpotifyCanvasLongDesc,
                        icon: Icons.video_library_rounded,
                        value: settings.enableCanvas,
                        isOfflineMode: settings.isOfflineMode,
                        activeColor: Colors.green[400]!,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onChanged: (val) => settingsNotifier.toggleCanvas(val),
                      ),
                      _buildGranularToggle(
                        title:
                            AppLocalizations.of(context)!.featureOnlineSearch,
                        subtitle: AppLocalizations.of(context)!
                            .featureOnlineSearchLongDesc,
                        icon: Icons.search_rounded,
                        value: settings.enableOnlineSearch,
                        isOfflineMode: settings.isOfflineMode,
                        activeColor: Colors.teal[400]!,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onChanged: (val) =>
                            settingsNotifier.toggleOnlineSearch(val),
                      ),
                      _buildGranularToggle(
                        title:
                            AppLocalizations.of(context)!.featureConnectDevice,
                        subtitle: AppLocalizations.of(context)!
                            .featureConnectDeviceLongDesc,
                        icon: Icons.devices_rounded,
                        value: settings.enableRemoteControl,
                        isOfflineMode: settings.isOfflineMode,
                        activeColor: Colors.orange[400]!,
                        textColor: textColor,
                        subtitleColor: subtitleColor,
                        onChanged: (val) =>
                            settingsNotifier.toggleRemoteControl(val),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.close),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final library = p.Provider.of<LibraryProvider>(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final Color subtitleColor = (isDark ? Colors.grey : Colors.grey[600])!;
    final accentColor = settings.accentColor;

    final List<Color> accentColors = [
      const Color(0xFF6C5CE7),
      const Color(0xFFFF7675),
      const Color(0xFF00CEC9),
      const Color(0xFFFD79A8),
      const Color(0xFFFAB1A0),
      const Color(0xFF55EFC4),
    ];

    int disabledCount = 0;
    if (!settings.enableCloudSync) disabledCount++;
    if (!settings.enableLeaderboard) disabledCount++;
    if (!settings.enableOnlineLyrics) disabledCount++;
    if (!settings.enableAiLyrics) disabledCount++;
    if (!settings.enableCanvas) disabledCount++;
    if (!settings.enableOnlineSearch) disabledCount++;
    if (!settings.enableRemoteControl) disabledCount++;

    // LISTEN FOR NAVIGATION SIGNALS (e.g. from MainShell reminder)
    ref.listen<SettingsSection>(settingsNavigationProvider, (prev, next) {
      if (next == SettingsSection.offlineMode) {
        _scrollToOffline();
        // Reset the signal so it doesn't re-trigger on rebuild
        Future.microtask(() {
          ref.read(settingsNavigationProvider.notifier).state =
              SettingsSection.none;
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildBody(context, settings, settingsNotifier, library, isDark,
          textColor, subtitleColor, accentColor, accentColors, disabledCount),
    );
  }

  /// Builds the settings body, choosing between tablet master-detail (landscape),
  /// tablet single-column (portrait), or the default phone layout.
  Widget _buildBody(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier settingsNotifier,
    LibraryProvider library,
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color accentColor,
    List<Color> accentColors,
    int disabledCount,
  ) {
    final isTablet = LayoutEngine.isTablet(context);
    final isLandscape = LayoutEngine.isLandscape(context);

    if (isTablet && isLandscape) {
      // Tablet landscape: master-detail layout
      return _buildTabletMasterDetail(
        context,
        settings,
        settingsNotifier,
        library,
        isDark,
        textColor,
        subtitleColor,
        accentColor,
        accentColors,
        disabledCount,
      );
    }

    // Tablet portrait or phone: single-column scrollable list
    final horizontalPadding = isTablet
        ? 24.0
        : (MediaQuery.of(context).size.width > 600 ? 32.0 : 16.0);

    return _buildSettingsListView(
      context,
      settings,
      settingsNotifier,
      library,
      isDark,
      textColor,
      subtitleColor,
      accentColor,
      accentColors,
      disabledCount,
      horizontalPadding: horizontalPadding,
    );
  }

  /// The list of settings category definitions for the master panel.
  List<_SettingsCategory> _getCategories(
      BuildContext context, Color accentColor) {
    final l10n = AppLocalizations.of(context)!;
    return [
      _SettingsCategory(title: l10n.appearance, icon: Icons.palette_outlined),
      _SettingsCategory(title: l10n.visualizer, icon: Icons.equalizer_rounded),
      _SettingsCategory(
          title: l10n.integration, icon: Icons.extension_outlined),
      _SettingsCategory(title: l10n.searchEngine, icon: Icons.search_rounded),
      _SettingsCategory(
          title: l10n.library, icon: Icons.library_music_outlined),
      _SettingsCategory(title: l10n.downloads, icon: Icons.download_outlined),
      _SettingsCategory(title: l10n.streaming, icon: Icons.stream_rounded),
      _SettingsCategory(title: l10n.playback, icon: Icons.play_circle_outline),
      _SettingsCategory(title: l10n.system, icon: Icons.settings_outlined),
      _SettingsCategory(
          title: l10n.dataCleanup, icon: Icons.cleaning_services_outlined),
      _SettingsCategory(title: l10n.debugging, icon: Icons.bug_report_outlined),
      _SettingsCategory(title: l10n.community, icon: Icons.people_outline),
    ];
  }

  /// Builds the tablet landscape master-detail layout.
  /// Left panel: 240dp wide category list.
  /// Right panel: settings list scrolled to the selected category.
  Widget _buildTabletMasterDetail(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier settingsNotifier,
    LibraryProvider library,
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color accentColor,
    List<Color> accentColors,
    int disabledCount,
  ) {
    final categories = _getCategories(context, accentColor);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master panel: categories list (240dp wide)
        SizedBox(
          width: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 24, bottom: 16),
                child: Text(
                  AppLocalizations.of(context)!.settings,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = index == _selectedCategoryIndex;
                    return ListTile(
                      leading: Icon(
                        category.icon,
                        color: isSelected ? accentColor : subtitleColor,
                        size: 20,
                      ),
                      title: Text(
                        category.title,
                        style: TextStyle(
                          color: isSelected ? accentColor : textColor,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: accentColor.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      dense: true,
                      onTap: () {
                        setState(() => _selectedCategoryIndex = index);
                        _scrollToCategory(index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Vertical divider
        VerticalDivider(
          thickness: 1,
          width: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        // Detail panel: settings list scrolled to selected category
        Expanded(
          child: _buildDetailListView(
            context,
            settings,
            settingsNotifier,
            library,
            isDark,
            textColor,
            subtitleColor,
            accentColor,
            accentColors,
            disabledCount,
          ),
        ),
      ],
    );
  }

  /// Scrolls the detail panel to the selected category section.
  void _scrollToCategory(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _categoryKeys[index];
      final keyContext = key.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.0,
        );
      }
    });
  }

  /// Builds the detail panel ListView with category keys for scroll-to support.
  /// This reuses the same settings content as the full list but with GlobalKeys
  /// on each category header to enable scroll-to-category from the master panel.
  Widget _buildDetailListView(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier settingsNotifier,
    LibraryProvider library,
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color accentColor,
    List<Color> accentColors,
    int disabledCount,
  ) {
    return _buildSettingsListView(
      context,
      settings,
      settingsNotifier,
      library,
      isDark,
      textColor,
      subtitleColor,
      accentColor,
      accentColors,
      disabledCount,
      horizontalPadding: 24.0,
      scrollController: _detailScrollController,
      useDetailKeys: true,
    );
  }

  /// Builds the original full settings ListView (used for phone and tablet portrait).
  /// When [useDetailKeys] is true, category headers get GlobalKeys for scroll-to support.
  Widget _buildSettingsListView(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier settingsNotifier,
    LibraryProvider library,
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color accentColor,
    List<Color> accentColors,
    int disabledCount, {
    double horizontalPadding = 16.0,
    ScrollController? scrollController,
    bool useDetailKeys = false,
  }) {
    return ListView(
      controller: scrollController ?? _scrollController,
      cacheExtent: 2000,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 24,
      ),
      children: [
        Padding(
          padding: EdgeInsets.only(
              bottom: 30,
              top: 20,
              left: (Platform.isAndroid || Platform.isIOS) ? 40.0 : 0.0),
          child: Text(AppLocalizations.of(context)!.settings,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
        ),

        // APPEARANCE
        Container(
          key: useDetailKeys ? _categoryKeys[0] : null,
          child: Text(AppLocalizations.of(context)!.appearance.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),

        // --- THEMES Subcategory ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            AppLocalizations.of(context)!.atmospheres.toUpperCase(),
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAtmosphereChip(
                context,
                title: AppLocalizations.of(context)!.none,
                icon: Icons.block_flipped,
                theme: AtmosphereTheme.none,
                currentTheme: settings.atmosphereTheme,
                settingsNotifier: settingsNotifier,
                activeColor: Colors.grey,
              ),
              _buildAtmosphereChip(
                context,
                title: AppLocalizations.of(context)!.winter,
                icon: Icons.ac_unit,
                theme: AtmosphereTheme.winter,
                currentTheme: settings.atmosphereTheme,
                settingsNotifier: settingsNotifier,
                activeColor: const Color(0xFF82CFFF),
              ),
              _buildAtmosphereChip(
                context,
                title: AppLocalizations.of(context)!.autumn,
                icon: null,
                theme: AtmosphereTheme.autumn,
                currentTheme: settings.atmosphereTheme,
                settingsNotifier: settingsNotifier,
                activeColor: Colors.orangeAccent,
                customIcon: const Text("🍂", style: TextStyle(fontSize: 16)),
              ),
              _buildAtmosphereChip(
                context,
                title: AppLocalizations.of(context)!.rainyCity,
                icon: Icons.umbrella,
                theme: AtmosphereTheme.rainyCity,
                currentTheme: settings.atmosphereTheme,
                settingsNotifier: settingsNotifier,
                activeColor: const Color(0xFF9B59B6), // Amethyst Purple
              ),
              _buildAtmosphereChip(
                context,
                title: AppLocalizations.of(context)!.sakura,
                icon: Icons.local_florist,
                theme: AtmosphereTheme.sakura,
                currentTheme: settings.atmosphereTheme,
                settingsNotifier: settingsNotifier,
                activeColor: const Color(0xFFFFB7C5), // Sakura Pink
              ),
              _buildAtmosphereChip(
                context,
                title: AppLocalizations.of(context)!.lunarNewYear,
                icon: Icons.festival_rounded,
                theme: AtmosphereTheme.lunarNewYear,
                currentTheme: settings.atmosphereTheme,
                settingsNotifier: settingsNotifier,
                activeColor: const Color(0xFFE63946), // Festive Red
              ),
              _buildAtmosphereChip(
                context,
                title: AppLocalizations.of(context)!.cyberpunk,
                icon: Icons.precision_manufacturing,
                theme: AtmosphereTheme.cyberpunk,
                currentTheme: settings.atmosphereTheme,
                settingsNotifier: settingsNotifier,
                activeColor: const Color(0xFFBD00FF), // Neon Purple
              ),
              _buildAtmosphereChip(
                context,
                title: AppLocalizations.of(context)!.underwater,
                icon: Icons.waves_rounded,
                theme: AtmosphereTheme.underwater,
                currentTheme: settings.atmosphereTheme,
                settingsNotifier: settingsNotifier,
                activeColor: const Color(0xFF00B2FF), // Ocean Blue
              ),
              _buildAtmosphereChip(
                context,
                title: AppLocalizations.of(context)!.nordicAurora,
                icon: Icons.auto_awesome,
                theme: AtmosphereTheme.nordicAurora,
                currentTheme: settings.atmosphereTheme,
                settingsNotifier: settingsNotifier,
                activeColor: const Color(0xFF2ECC71), // Aurora Green
              ),
              _buildAtmosphereChip(
                context,
                title: AppLocalizations.of(context)!.galacticSpace,
                icon: Icons.public_rounded,
                theme: AtmosphereTheme.galactic,
                currentTheme: settings.atmosphereTheme,
                settingsNotifier: settingsNotifier,
                activeColor: const Color(0xFFA55EEA), // Nebula Violet
              ),
              _buildAtmosphereChip(
                context,
                title: AppLocalizations.of(context)!.desertMirage,
                icon: Icons.wb_sunny_rounded,
                theme: AtmosphereTheme.desertMirage,
                currentTheme: settings.atmosphereTheme,
                settingsNotifier: settingsNotifier,
                activeColor: const Color(0xFFE67E22), // Terracotta Orange
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- GENERAL Appearance options ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            AppLocalizations.of(context)!.general.toUpperCase(),
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.0,
            ),
          ),
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.darkMode,
              style: TextStyle(
                color: settings.atmosphereTheme != AtmosphereTheme.none
                    ? (isDark ? Colors.grey[600] : Colors.grey[400])
                    : textColor,
              )),
          subtitle: Text(
              settings.atmosphereTheme != AtmosphereTheme.none
                  ? AppLocalizations.of(context)!.lockedAtmosphere
                  : AppLocalizations.of(context)!.useDarkTheme,
              style: TextStyle(color: subtitleColor)),
          value: settings.isDarkMode,
          activeThumbColor: accentColor,
          // Disabled when an atmosphere is on
          onChanged: settings.atmosphereTheme != AtmosphereTheme.none
              ? null
              : (val) => settingsNotifier.toggleDarkMode(val),
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.syncThemeAlbumArt,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.tintBackground,
              style: TextStyle(color: subtitleColor)),
          value: settings.syncThemeWithAlbumArt,
          activeThumbColor: accentColor,
          onChanged: (val) => settingsNotifier.toggleThemeSync(val),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context)!.accentColor,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.chooseAccentColor,
              style: TextStyle(color: subtitleColor)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Wrap(
            spacing: 12,
            children: accentColors.map((color) {
              final isSelected = settings.accentColor == color;
              return GestureDetector(
                onTap: () => settingsNotifier.setAccentColor(color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: isDark ? Colors.white : Colors.black,
                            width: 3)
                        : null,
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 2)
                    ],
                  ),
                  child: isSelected
                      ? Icon(Icons.check,
                          color: isDark ? Colors.black : Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 30),

        ListTile(
          title: Text(AppLocalizations.of(context)!.contentRegion,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.setCountryReleases,
              style: TextStyle(color: subtitleColor)),
          trailing: Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: DropdownButton<String>(
              value: settings.spotifyMarket,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              underline: Container(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
              focusColor: Colors.transparent,
              items: [
                DropdownMenuItem(
                    value: 'US',
                    child: Text(
                        "🇺🇸 ${AppLocalizations.of(context)!.unitedStates}")),
                DropdownMenuItem(
                    value: 'ID',
                    child: Text(
                        "🇮🇩 ${AppLocalizations.of(context)!.indonesia}")),
                DropdownMenuItem(
                    value: 'KR',
                    child: Text(
                        "🇰🇷 ${AppLocalizations.of(context)!.southKorea}")),
                DropdownMenuItem(
                    value: 'JP',
                    child: Text("🇯🇵 ${AppLocalizations.of(context)!.japan}")),
                DropdownMenuItem(
                    value: 'GB',
                    child: Text(
                        "🇬🇧 ${AppLocalizations.of(context)!.unitedKingdom}")),
                DropdownMenuItem(
                    value: 'BR',
                    child:
                        Text("🇧🇷 ${AppLocalizations.of(context)!.brazil}")),
              ],
              onChanged: (String? newMarket) {
                if (newMarket != null) {
                  settingsNotifier.setSpotifyMarket(newMarket);
                }
              },
            ),
          ),
        ),

        // VISUALIZER
        Container(
          key: useDetailKeys ? _categoryKeys[1] : null,
          child: Text(AppLocalizations.of(context)!.visualizer.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.enableBarVisualizer,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.showAnimatedWaves,
              style: TextStyle(color: subtitleColor)),
          value: settings.enableVisualizer,
          activeThumbColor: accentColor,
          onChanged: (val) => settingsNotifier.toggleVisualizer(val),
        ),
        if (settings.enableVisualizer) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Opacity: ${(settings.visualizerOpacity * 100).toInt()}%",
                    style: TextStyle(color: textColor, fontSize: 13)),
                Slider(
                  value: settings.visualizerOpacity,
                  min: 0.1,
                  max: 1.0,
                  activeColor: accentColor,
                  inactiveColor: isDark ? Colors.white12 : Colors.black12,
                  onChanged: (val) =>
                      settingsNotifier.setVisualizerOpacity(val),
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.visualizerStyle,
                style: TextStyle(color: textColor)),
            subtitle: Text(AppLocalizations.of(context)!.chooseAnimationType,
                style: TextStyle(color: subtitleColor)),
            trailing: Theme(
              data: Theme.of(context).copyWith(
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: DropdownButton<VisualizerStyle>(
                value: settings.visualizerStyle,
                dropdownColor: Theme.of(context).cardColor,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                underline: Container(),
                icon:
                    Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
                focusColor: Colors.transparent,
                items: [
                  DropdownMenuItem(
                      value: VisualizerStyle.spectrum,
                      child: Text(AppLocalizations.of(context)!.spectrumBars)),
                  DropdownMenuItem(
                      value: VisualizerStyle.wave,
                      child: Text(AppLocalizations.of(context)!.fluidWave)),
                  DropdownMenuItem(
                      value: VisualizerStyle.pulse,
                      child: Text(AppLocalizations.of(context)!.circularPulse)),
                ],
                onChanged: (VisualizerStyle? newStyle) {
                  if (newStyle != null) {
                    settingsNotifier.setVisualizerStyle(newStyle);
                  }
                },
              ),
            ),
          ),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.rainbowMode,
                style: TextStyle(color: textColor)),
            subtitle: Text(AppLocalizations.of(context)!.useMixedColors,
                style: TextStyle(color: subtitleColor)),
            value: settings.isVisualizerRainbow,
            activeThumbColor: accentColor,
            onChanged: (val) => settingsNotifier.toggleVisualizerRainbow(val),
          ),
        ],
        const SizedBox(height: 30),

        // INTEGRATION
        Container(
          key: useDetailKeys ? _categoryKeys[2] : null,
          child: Text(AppLocalizations.of(context)!.integration.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.discordRPC,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.showStatusDiscord,
              style: TextStyle(color: subtitleColor)),
          value: settings.enableDiscordRpc,
          activeThumbColor: accentColor,
          onChanged: (val) => settingsNotifier.toggleDiscordRpc(val),
        ),
        const SizedBox(height: 30),

        // SEARCH ENGINE
        Container(
          key: useDetailKeys ? _categoryKeys[3] : null,
          child: Text(AppLocalizations.of(context)!.searchEngine.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              _buildSearchEngineChip(
                context,
                title: AppLocalizations.of(context)!.spotify,
                icon: Icons.music_note_rounded,
                engine: SearchEngine.spotify,
                currentEngine: settings.searchEngine,
                settingsNotifier: settingsNotifier,
                activeColor: const Color(0xFF1DB954), // Spotify Green
              ),
              _buildSearchEngineChip(
                context,
                title: AppLocalizations.of(context)!.youtube,
                icon: Icons.play_circle_fill_rounded,
                engine: SearchEngine.youtube,
                currentEngine: settings.searchEngine,
                settingsNotifier: settingsNotifier,
                activeColor: const Color(0xFFFF0000), // YouTube Red
              ),
              _buildSearchEngineChip(
                context,
                title: "Apple Music",
                icon: Icons.apple,
                engine: SearchEngine.appleMusic,
                currentEngine: settings.searchEngine,
                settingsNotifier: settingsNotifier,
                activeColor: const Color(0xFFFA243C), // Apple Music Red/Pink
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // LIBRARY
        Container(
          key: useDetailKeys ? _categoryKeys[4] : null,
          child: Text(AppLocalizations.of(context)!.library.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context)!.musicFolderLocation,
              style: TextStyle(color: textColor)),
          subtitle: Text(
              library.selectedFolder ??
                  AppLocalizations.of(context)!.noFolderSelected,
              style: TextStyle(color: subtitleColor)),
          trailing: TextButton(
              onPressed: () async {
                try {
                  String? result = await FolderPicker.pickDirectory();
                  if (result != null) {
                    // Fire-and-forget: don't await so settings UI stays responsive
                    library.setFolder(result);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                "${AppLocalizations.of(context)!.musicFolderLocation}: $result")),
                      );
                    }
                  }
                } catch (e) {
                  debugPrint("⚠️ FilePicker Error: $e");
                }
              },
              child: Text(AppLocalizations.of(context)!.change,
                  style: TextStyle(color: accentColor))),
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.ignoreSubfolderScan,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.onlyScanSelected,
              style: TextStyle(color: subtitleColor)),
          value: settings.ignoreSubfolders,
          activeThumbColor: accentColor,
          onChanged: (val) => settingsNotifier.toggleIgnoreSubfolders(val),
        ),
        if (Platform.isAndroid || Platform.isIOS)
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.enableAlphabetIndexer,
                style: TextStyle(color: textColor)),
            subtitle: Text(
                AppLocalizations.of(context)!.enableAlphabetIndexerSubtitle,
                style: TextStyle(color: subtitleColor)),
            value: settings.enableAlphabetIndexer,
            activeThumbColor: accentColor,
            onChanged: (val) => settingsNotifier.toggleAlphabetIndexer(val),
          ),

        // Import Additional Paths Section
        ListTile(
          leading: Icon(Icons.create_new_folder_rounded, color: accentColor),
          title: Text(AppLocalizations.of(context)!.importAdditionalPaths,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.addFoldersScan,
              style: TextStyle(color: subtitleColor)),
          trailing: TextButton.icon(
            icon: Icon(Icons.add, color: accentColor, size: 18),
            label: Text(AppLocalizations.of(context)!.add,
                style: TextStyle(color: accentColor)),
            onPressed: () async {
              try {
                String? result = await FolderPicker.pickDirectory();
                if (result != null) {
                  await settingsNotifier.addMusicFolder(result);
                  // Scan the newly added folder
                  library.scanAdditionalFolder(
                      result); // Fire and forget so we don't freeze the UI
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(AppLocalizations.of(context)!
                              .addedFolder(
                                  result.split(Platform.pathSeparator).last))),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error picking folder: $e")),
                  );
                }
              }
            },
          ),
        ),

        // Display list of additional folders as removable chips
        if (settings.additionalMusicFolders.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: settings.additionalMusicFolders.map<Widget>((folder) {
                final folderName = folder.split(Platform.pathSeparator).last;
                return Tooltip(
                  message: folder, // Show full path on hover
                  child: Chip(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey[200],
                    avatar: Icon(Icons.folder, size: 18, color: accentColor),
                    label: Text(
                      folderName,
                      style: TextStyle(color: textColor, fontSize: 12),
                    ),
                    deleteIcon: Icon(Icons.close,
                        size: 16,
                        color: isDark ? Colors.white54 : Colors.black54),
                    onDeleted: () async {
                      await ref.read(libraryProvider.notifier).removeFolderByPath(folder);
                      await settingsNotifier.removeMusicFolder(folder);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(AppLocalizations.of(context)!
                                  .removedFolder(folderName))),
                        );
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 30),

        // DOWNLOADS
        Container(
          key: useDetailKeys ? _categoryKeys[5] : null,
          child: Text(AppLocalizations.of(context)!.downloads.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        ),

        // Filename Format
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.singleTracks,
                  style: TextStyle(color: textColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _formatCtrl,
                style: TextStyle(color: textColor),
                onChanged: _onFormatChanged,
                onSubmitted: (_) => _saveFormat(),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey[100],
                  hintText: "{artist} - {title}",
                  hintStyle: TextStyle(color: subtitleColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save),
                    color: accentColor,
                    tooltip: AppLocalizations.of(context)!.formatSaved,
                    onPressed: _saveFormat,
                  ),
                ),
              ),
              if (_unsavedSingle)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(AppLocalizations.of(context)!.unsavedChanges,
                          style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Playlist / Album Header
              Text(AppLocalizations.of(context)!.playlistAlbumTracks,
                  style: TextStyle(color: textColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _playlistFormatCtrl,
                style: TextStyle(color: textColor),
                onChanged: _onPlaylistFormatChanged,
                onSubmitted: (_) => _saveFormat(),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey[100],
                  hintText: "{artist} - {title}",
                  hintStyle: TextStyle(color: subtitleColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save),
                    color: accentColor,
                    tooltip: AppLocalizations.of(context)!.formatSaved,
                    onPressed: _saveFormat,
                  ),
                ),
              ),
              if (_unsavedPlaylist)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(AppLocalizations.of(context)!.unsavedChanges,
                          style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildTagChip("{artist}", accentColor),
                  _buildTagChip("{title}", accentColor),
                  _buildTagChip("{album}", accentColor),
                  _buildTagChip("{number}", Colors.orange),
                  _buildTagChip("{year}", Colors.grey),
                  _buildTagChip("{track}", Colors.grey),
                  _buildTagChip("{playlist_index}", Colors.orange),
                ],
              ),
            ],
          ),
        ),

        // Audio Format Selector (NEW)
        ListTile(
          title: Text(AppLocalizations.of(context)!.audioFormat,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.preferredOutputFormat,
              style: TextStyle(color: subtitleColor)),
          trailing: Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: DropdownButton<String>(
              value: settings.searchEngine == SearchEngine.appleMusic
                  ? (['alac', 'm4a', 'flac'].contains(settings.audioFormat)
                      ? settings.audioFormat
                      : 'alac')
                  : settings.searchEngine == SearchEngine.youtube
                      ? (['mp3', 'm4a', 'aac', 'opus']
                              .contains(settings.audioFormat)
                          ? settings.audioFormat
                          : 'mp3')
                      : (['mp3', 'm4a', 'aac', 'flac']
                              .contains(settings.audioFormat)
                          ? settings.audioFormat
                          : 'mp3'),
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              underline: Container(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
              focusColor: Colors.transparent,
              items: settings.searchEngine == SearchEngine.appleMusic
                  ? const [
                      DropdownMenuItem(
                          value: 'alac', child: Text("ALAC (Apple Lossless)")),
                      DropdownMenuItem(
                          value: 'm4a', child: Text("AAC (Standard Quality)")),
                      DropdownMenuItem(
                          value: 'flac', child: Text("FLAC (Lossless)")),
                    ]
                  : settings.searchEngine == SearchEngine.youtube
                      ? const [
                          DropdownMenuItem(
                              value: 'mp3', child: Text("MP3 (128kbps)")),
                          DropdownMenuItem(
                              value: 'm4a', child: Text("M4A/AAC (128kbps)")),
                          DropdownMenuItem(
                              value: 'aac', child: Text("AAC (Raw)")),
                          DropdownMenuItem(
                              value: 'opus', child: Text("Opus (160kbps, Best)")),
                        ]
                      : [
                          DropdownMenuItem(
                              value: 'mp3',
                              child: Text(AppLocalizations.of(context)!.standardQuality)),
                          DropdownMenuItem(
                              value: 'm4a',
                              child: Text(AppLocalizations.of(context)!.highQuality)),
                          const DropdownMenuItem(value: 'aac', child: Text("AAC (Raw)")),
                          const DropdownMenuItem(
                              value: 'flac', child: Text("FLAC (Lossless)")),
                        ],
              onChanged: (String? newFormat) {
                if (newFormat != null) {
                  settingsNotifier.setAudioFormat(newFormat);
                }
              },
            ),
          ),
        ),

        // FLAC Note (only shown when FLAC is selected)
        if (settings.audioFormat == 'flac')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.flacNote,
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Download Location
        FutureBuilder<SharedPreferences>(
          future: _prefsFuture,
          builder: (context, snapshot) {
            String currentPath = (Platform.isAndroid)
                ? "Default (/storage/emulated/0/Download/SimpleMusicDownloads)"
                : "Default (Downloads/SimpleMusicDownloads)";
            bool hasCustomPath = false;
            if (snapshot.hasData) {
              final path = snapshot.data!.getString('custom_download_path');
              if (path != null) {
                currentPath = path;
                hasCustomPath = true;
              }
            }
            return ListTile(
              title: Text(AppLocalizations.of(context)!.downloadLocation,
                  style: TextStyle(color: textColor)),
              subtitle:
                  Text(currentPath, style: TextStyle(color: subtitleColor)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasCustomPath)
                    IconButton(
                      icon: const Icon(Icons.restore),
                      color: Colors.orange,
                      tooltip: AppLocalizations.of(context)!.resetToDefault,
                      onPressed: () => _resetDownloadPath(context),
                    ),
                  IconButton(
                    icon: Icon(Icons.folder_open, color: accentColor),
                    tooltip: AppLocalizations.of(context)!.changeFolder,
                    onPressed: () => _pickDownloadPath(context),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 30),

        // STREAMING
        Container(
          key: useDetailKeys ? _categoryKeys[6] : null,
          child: Text(AppLocalizations.of(context)!.streaming.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        ),

        const SizedBox(height: 8),

        // Streaming Quality Selector
        ListTile(
          title: Text(AppLocalizations.of(context)!.streamingQuality,
              style: TextStyle(color: textColor)),
          subtitle: Text(
            _getStreamingQualityDescription(settings.streamingQuality),
            style: TextStyle(color: subtitleColor),
          ),
          trailing: Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: DropdownButton<String>(
              value: (settings.searchEngine == SearchEngine.youtube &&
                      settings.streamingQuality == 'lossless')
                  ? 'high'
                  : settings.streamingQuality,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              underline: Container(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
              focusColor: Colors.transparent,
              items: [
                DropdownMenuItem(
                    value: 'standard',
                    child: Text(AppLocalizations.of(context)!.standardQuality)),
                DropdownMenuItem(
                    value: 'high',
                    child: Text(AppLocalizations.of(context)!.highQuality)),
                if (settings.searchEngine != SearchEngine.youtube)
                  DropdownMenuItem(
                      value: 'lossless',
                      child: Text(AppLocalizations.of(context)!.losslessQuality)),
              ],
              onChanged: (String? newQuality) {
                if (newQuality != null) {
                  settingsNotifier.setStreamingQuality(newQuality);
                }
              },
            ),
          ),
        ),

        // Lossless Note (only shown when lossless is selected)
        if (settings.streamingQuality == 'lossless' && settings.searchEngine != SearchEngine.youtube) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.high_quality, color: Colors.blue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.losslessNote,
                      style: TextStyle(
                        color: Colors.blue.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SwitchListTile(
            title: Text(
                AppLocalizations.of(context)!.backgroundCacheFlacStreams,
                style: TextStyle(color: textColor)),
            subtitle: Text(
                AppLocalizations.of(context)!
                    .backgroundCacheFlacStreamsSubtitle,
                style: TextStyle(color: subtitleColor)),
            value: settings.cacheStreamedSongs,
            activeThumbColor: accentColor,
            onChanged: (val) => settingsNotifier.toggleCacheStreamedSongs(val),
          ),
        ],

        const SizedBox(height: 30),

        // PLAYBACK
        Container(
          key: useDetailKeys ? _categoryKeys[7] : null,
          child: Text(AppLocalizations.of(context)!.playback.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        ),
        Consumer(
          builder: (context, ref, _) {
            final playerState = ref.watch(playerProvider);
            final playerNotifier = ref.read(playerProvider.notifier);
            return Column(
              children: [
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.endlessQueue,
                      style: TextStyle(color: textColor)),
                  subtitle: Text(AppLocalizations.of(context)!.autoAddSimilar,
                      style: TextStyle(color: subtitleColor)),
                  value: playerState.endlessQueueEnabled,
                  activeThumbColor: accentColor,
                  onChanged: (_) => playerNotifier.toggleEndlessQueue(),
                ),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.gaplessPlayback,
                      style: TextStyle(color: textColor)),
                  subtitle: Text(
                      AppLocalizations.of(context)!.gaplessPlaybackDesc,
                      style: TextStyle(color: subtitleColor)),
                  value: settings.gaplessPlayback,
                  activeThumbColor: accentColor,
                  onChanged: (val) =>
                      settingsNotifier.toggleGaplessPlayback(val),
                ),
                ListTile(
                  title: Text(AppLocalizations.of(context)!.crossfade,
                      style: TextStyle(color: textColor)),
                  subtitle: Text(
                      AppLocalizations.of(context)!.crossfadeDesc(
                          settings.crossfadeDuration.toStringAsFixed(1)),
                      style: TextStyle(color: subtitleColor)),
                  trailing: SizedBox(
                    width: 150,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: settings.crossfadeDuration,
                        min: 0,
                        max: 12,
                        divisions: 120,
                        activeColor: accentColor,
                        inactiveColor: accentColor.withValues(alpha: 0.2),
                        onChanged: (val) =>
                            settingsNotifier.setCrossfadeDuration(val),
                      ),
                    ),
                  ),
                ),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.automaticGainControl,
                      style: TextStyle(color: textColor)),
                  subtitle: Text(
                      AppLocalizations.of(context)!.automaticGainControlDesc,
                      style: TextStyle(color: subtitleColor)),
                  value: settings.enableReplayGain,
                  activeThumbColor: accentColor,
                  onChanged: (val) =>
                      settingsNotifier.toggleReplayGain(val),
                ),
              ],
            );
          },
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.disableRomanization,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.hideRomajiPinyin,
              style: TextStyle(color: subtitleColor)),
          value: settings.disableRomanization,
          activeThumbColor: accentColor,
          onChanged: (val) => settingsNotifier.toggleRomanization(val),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context)!.translationLanguage,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.targetLanguageLyrics,
              style: TextStyle(color: subtitleColor)),
          trailing: Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: DropdownButton<String>(
              value: settings.translationLanguage,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              underline: Container(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
              focusColor: Colors.transparent,
              onChanged: (value) {
                if (value != null) {
                  settingsNotifier.setTranslationLanguage(value);
                }
              },
              items: [
                DropdownMenuItem(
                    value: 'en',
                    child: Text(AppLocalizations.of(context)!.english)),
                DropdownMenuItem(
                    value: 'id',
                    child: Text(AppLocalizations.of(context)!.indonesian)),
                DropdownMenuItem(
                    value: 'ko',
                    child: Text(AppLocalizations.of(context)!.korean)),
                DropdownMenuItem(
                    value: 'ja',
                    child: Text(AppLocalizations.of(context)!.japanese)),
                DropdownMenuItem(
                    value: 'zh-CN',
                    child: Text(AppLocalizations.of(context)!.chinese)),
                DropdownMenuItem(
                    value: 'es',
                    child: Text(AppLocalizations.of(context)!.spanish)),
                DropdownMenuItem(
                    value: 'fr',
                    child: Text(AppLocalizations.of(context)!.french)),
                DropdownMenuItem(
                    value: 'de',
                    child: Text(AppLocalizations.of(context)!.german)),
                DropdownMenuItem(
                    value: 'pt',
                    child: Text(AppLocalizations.of(context)!.portuguese)),
                DropdownMenuItem(
                    value: 'th',
                    child: Text(AppLocalizations.of(context)!.thai)),
                DropdownMenuItem(
                    value: 'vi',
                    child: Text(AppLocalizations.of(context)!.vietnamese)),
                DropdownMenuItem(
                    value: 'ar',
                    child: Text(AppLocalizations.of(context)!.arabic)),
                DropdownMenuItem(
                    value: 'ru',
                    child: Text(AppLocalizations.of(context)!.russian)),
                DropdownMenuItem(
                    value: 'hi',
                    child: Text(AppLocalizations.of(context)!.hindi)),
              ],
            ),
          ),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context)!.canvasSourcePreferenceTitle,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.canvasSourcePreferenceSubtitle,
              style: TextStyle(color: subtitleColor)),
          trailing: Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: DropdownButton<String>(
              value: settings.canvasSourcePreference,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              underline: Container(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
              focusColor: Colors.transparent,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  settingsNotifier.updateCanvasSourcePreference(newValue);
                }
              },
              items: [
                DropdownMenuItem(
                  value: 'apple_first',
                  child: Text(AppLocalizations.of(context)!.preferAppleMusic),
                ),
                DropdownMenuItem(
                  value: 'spotify_first',
                  child: Text(AppLocalizations.of(context)!.preferSpotify),
                ),
                DropdownMenuItem(
                  value: 'apple_only',
                  child: Text(AppLocalizations.of(context)!.onlyAppleMusic),
                ),
                DropdownMenuItem(
                  value: 'spotify_only',
                  child: Text(AppLocalizations.of(context)!.onlySpotify),
                ),
                DropdownMenuItem(
                  value: 'disabled',
                  child: Text(AppLocalizations.of(context)!.disabled),
                ),
              ],
            ),
          ),
        ),

        // WASAPI Exclusive Mode (Windows Only)
        if (Platform.isWindows)
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.wasapiExclusive,
                style: TextStyle(color: textColor)),
            subtitle: Text(
              settings.wasapiExclusive
                  ? AppLocalizations.of(context)!.bitPerfectWindows
                  : AppLocalizations.of(context)!.audiophileDAC,
              style: TextStyle(color: subtitleColor),
            ),
            value: settings.wasapiExclusive,
            activeThumbColor: accentColor,
            onChanged: (val) {
              settingsNotifier.toggleWasapiExclusive(val);
              _showRestartDialog(context);
            },
          ),

        // Android Bit-Perfect Mode / Custom C++ Bypass
        if (Platform.isAndroid)
          Consumer(
            builder: (context, ref, _) {
              final titleText = AppLocalizations.of(context)!.bitPerfectBypassTitle;
              final subtitleText = _isAndroidBitPerfectSupported
                  ? AppLocalizations.of(context)!.bitPerfectBypassSub14
                  : AppLocalizations.of(context)!.bitPerfectBypassSubLegacy;
              
              return SwitchListTile(
                title: Text(titleText, style: TextStyle(color: textColor)),
                subtitle: Text(
                  subtitleText,
                  style: TextStyle(color: subtitleColor),
                ),
                value: settings.androidBitPerfect,
                activeThumbColor: accentColor,
                onChanged: (val) async {
                  final success = await settingsNotifier.toggleAndroidBitPerfect(val);
                  if (val) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.bitPerfectBypassSuccess),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.bitPerfectBypassWarning),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),

        if (Platform.isWindows) ...[
          // Audio Device Selector
          ListTile(
            title: Text(AppLocalizations.of(context)!.audioOutputDevice,
                style: TextStyle(color: textColor)),
            subtitle: _loadingAudioDevices
                ? Text(AppLocalizations.of(context)!.loadingDevices,
                    style: TextStyle(color: subtitleColor, fontSize: 12))
                : Text(
                    settings.audioDeviceId == null
                        ? AppLocalizations.of(context)!.systemDefault
                        : (_audioDevices.firstWhere(
                                (d) => d['name'] == settings.audioDeviceId,
                                orElse: () => {})['description'] ??
                            AppLocalizations.of(context)!.customDevice),
                    style: TextStyle(color: subtitleColor),
                  ),
            trailing: _loadingAudioDevices
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accentColor),
                  )
                : Theme(
                    data: Theme.of(context).copyWith(
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: DropdownButton<String?>(
                      value: settings.audioDeviceId != null &&
                              _audioDevices.any(
                                  (d) => d['name'] == settings.audioDeviceId)
                          ? settings.audioDeviceId
                          : null, // Default to null if not found
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.bold),
                      underline: Container(),
                      icon: Icon(Icons.keyboard_arrow_down_rounded,
                          color: accentColor),
                      alignment: Alignment.centerRight,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child:
                              Text(AppLocalizations.of(context)!.systemDefault),
                        ),
                        ..._audioDevices.map((d) {
                          return DropdownMenuItem<String?>(
                            value: d['name'],
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(
                                d['description'] ?? "Unknown",
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }),
                      ],
                      onChanged: (String? newId) {
                        settingsNotifier.setAudioDeviceId(newId);
                        _showRestartDialog(context);
                      },
                    ),
                  ),
          ),

          // Exclusive Mode Warning
          if (settings.wasapiExclusive && settings.audioDeviceId == null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.exclusiveModeWarning,
                      style:
                          TextStyle(color: Colors.amber.shade300, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],

        const SizedBox(height: 30),
        // SYSTEM
        Container(
          key: useDetailKeys ? _categoryKeys[8] : null,
          child: Text(AppLocalizations.of(context)!.system.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        ListTile(
          title: Text(AppLocalizations.of(context)!.language,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.changeLanguage,
              style: TextStyle(color: subtitleColor)),
          trailing: Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: DropdownButton<String>(
              value: settings.appLocale,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              underline: Container(),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
              focusColor: Colors.transparent,
              items: [
                DropdownMenuItem(
                    value: 'en',
                    child:
                        Text("🇺🇸 ${AppLocalizations.of(context)!.english}")),
                DropdownMenuItem(
                    value: 'id',
                    child: Text(
                        "🇮🇩 ${AppLocalizations.of(context)!.indonesian}")),
                DropdownMenuItem(
                    value: 'ko',
                    child:
                        Text("🇰🇷 ${AppLocalizations.of(context)!.korean}")),
                DropdownMenuItem(
                    value: 'ja',
                    child:
                        Text("🇯🇵 ${AppLocalizations.of(context)!.japanese}")),
                DropdownMenuItem(
                    value: 'zh',
                    child:
                        Text("🇨🇳 ${AppLocalizations.of(context)!.chinese}")),
                DropdownMenuItem(
                    value: 'es',
                    child:
                        Text("🇪🇸 ${AppLocalizations.of(context)!.spanish}")),
                DropdownMenuItem(
                    value: 'fr',
                    child:
                        Text("🇫🇷 ${AppLocalizations.of(context)!.french}")),
                DropdownMenuItem(
                    value: 'de',
                    child:
                        Text("🇩🇪 ${AppLocalizations.of(context)!.german}")),
                DropdownMenuItem(
                    value: 'pt',
                    child: Text(
                        "🇧🇷 ${AppLocalizations.of(context)!.portuguese}")),
                DropdownMenuItem(
                    value: 'th',
                    child: Text("🇹🇭 ${AppLocalizations.of(context)!.thai}")),
                DropdownMenuItem(
                    value: 'vi',
                    child: Text(
                        "🇻🇳 ${AppLocalizations.of(context)!.vietnamese}")),
                DropdownMenuItem(
                    value: 'ar',
                    child:
                        Text("🇸🇦 ${AppLocalizations.of(context)!.arabic}")),
                DropdownMenuItem(
                    value: 'ru',
                    child:
                        Text("🇷🇺 ${AppLocalizations.of(context)!.russian}")),
                DropdownMenuItem(
                    value: 'hi',
                    child: Text("🇮🇳 ${AppLocalizations.of(context)!.hindi}")),
              ],
              onChanged: (String? newLocale) {
                if (newLocale != null) {
                  settingsNotifier.setAppLocale(newLocale);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            AppLocalizations.of(context)!.autoClearCache,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        RadioListTile<String>(
          title: Text(AppLocalizations.of(context)!.autoClearDisabled,
              style: TextStyle(color: textColor, fontSize: 13)),
          value: 'disabled',
          groupValue: settings.autoClearCache,
          activeColor: accentColor,
          onChanged: (val) {
            if (val != null) settingsNotifier.setAutoClearCache(val);
          },
          dense: true,
        ),
        RadioListTile<String>(
          title: Text(AppLocalizations.of(context)!.autoClearEvery30m,
              style: TextStyle(color: textColor, fontSize: 13)),
          value: 'every_30min',
          groupValue: settings.autoClearCache,
          activeColor: accentColor,
          onChanged: (val) {
            if (val != null) settingsNotifier.setAutoClearCache(val);
          },
          dense: true,
        ),
        RadioListTile<String>(
          title: Text(AppLocalizations.of(context)!.autoClearOnClose,
              style: TextStyle(color: textColor, fontSize: 13)),
          value: 'on_close',
          groupValue: settings.autoClearCache,
          activeColor: accentColor,
          onChanged: (val) {
            if (val != null) settingsNotifier.setAutoClearCache(val);
          },
          dense: true,
        ),
        RadioListTile<String>(
          title: Text(AppLocalizations.of(context)!.autoClearAfter24h,
              style: TextStyle(color: textColor, fontSize: 13)),
          value: 'after_24h',
          groupValue: settings.autoClearCache,
          activeColor: accentColor,
          onChanged: (val) {
            if (val != null) settingsNotifier.setAutoClearCache(val);
          },
          dense: true,
        ),
        RadioListTile<String>(
          title: Text(AppLocalizations.of(context)!.autoClearAfter7d,
              style: TextStyle(color: textColor, fontSize: 13)),
          value: 'after_7d',
          groupValue: settings.autoClearCache,
          activeColor: accentColor,
          onChanged: (val) {
            if (val != null) settingsNotifier.setAutoClearCache(val);
          },
          dense: true,
        ),
        if (Platform.isWindows ||
            Platform.isMacOS ||
            Platform.isLinux) // Desktop only
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.minimizeToTray,
                style: TextStyle(color: textColor)),
            subtitle: Text(
                AppLocalizations.of(context)!.minimizeToTrayDescription,
                style: TextStyle(color: subtitleColor)),
            value: settings.minimizeToTrayOnClose,
            activeThumbColor: accentColor,
            onChanged: (val) =>
                settingsNotifier.toggleMinimizeToTrayOnClose(val),
          ),
        const SizedBox(height: 24),

        // DATA & CLEANUP
        Container(
          key: useDetailKeys ? _categoryKeys[9] : null,
          child: Text(AppLocalizations.of(context)!.dataCleanup.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        ListTile(
          leading: Icon(Icons.folder_delete_rounded, color: Colors.orange[400]),
          title: Text(AppLocalizations.of(context)!.resetLibraryPath,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.unlinkFolderClear,
              style: TextStyle(color: subtitleColor)),
          onTap: () {
            if (library.selectedFolder == null) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Theme.of(context).cardColor,
                title: Text(AppLocalizations.of(context)!.resetLibraryTitle),
                content: Text(
                  AppLocalizations.of(context)!.resetLibraryContent,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel", style: TextStyle(color: textColor)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                    onPressed: () {
                      library.resetLibrary();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(AppLocalizations.of(context)!
                                .libraryPathReset)),
                      );
                    },
                    child: Text(AppLocalizations.of(context)!.resetPath),
                  ),
                ],
              ),
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.data_usage_rounded, color: Colors.teal[400]),
          title: Row(
            children: [
              Text(AppLocalizations.of(context)!.dataUsage,
                  style: TextStyle(color: textColor)),
              const SizedBox(width: 6),
              Consumer(
                builder: (context, ref, _) {
                  final usage = ref.watch(dataUsageProvider);
                  return Tooltip(
                    message:
                        "${AppLocalizations.of(context)!.todayLabel(usage.todayFormatted)}\n"
                        "${AppLocalizations.of(context)!.last7DaysLabel(usage.weekFormatted)}\n"
                        "${AppLocalizations.of(context)!.last30DaysLabel(usage.monthFormatted)}",
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[850]?.withValues(alpha: 1) ??
                          Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10, width: 1),
                    ),
                    textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(Icons.info_outline_rounded,
                        size: 16, color: Colors.grey[400]),
                  );
                },
              ),
            ],
          ),
          subtitle: Consumer(
            builder: (context, ref, _) {
              final usage = ref.watch(dataUsageProvider);
              return Text(
                usage.formattedSize,
                style: TextStyle(color: subtitleColor),
              );
            },
          ),
          trailing: IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
            tooltip: AppLocalizations.of(context)!.resetUsage,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).cardColor,
                  title: Text(AppLocalizations.of(context)!.resetDataUsage,
                      style: TextStyle(color: textColor)),
                  content: Text(
                      AppLocalizations.of(context)!.resetDataUsageContent,
                      style: TextStyle(color: textColor)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)!.cancel,
                          style: TextStyle(color: textColor)),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(dataUsageProvider.notifier).reset();
                        Navigator.pop(context);
                      },
                      child: Text(AppLocalizations.of(context)!.reset,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        ListTile(
          leading:
              Icon(Icons.cleaning_services_rounded, color: Colors.blue[400]),
          title: Text(AppLocalizations.of(context)!.clearStreamingCache,
              style: TextStyle(color: textColor)),
          subtitle: Text(
              AppLocalizations.of(context)!.freeUpSpace(_cacheSizeText),
              style: TextStyle(color: subtitleColor)),
          onTap: () async {
            await _ytService.clearCache();
            if (context.mounted) {
              _loadCacheSize();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(AppLocalizations.of(context)!.cacheCleared)),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.auto_awesome_motion_rounded,
              color: Colors.purple[400]),
          title: Text(AppLocalizations.of(context)!.clearMetadataCache,
              style: TextStyle(color: textColor)),
          subtitle: Text("$_metadataCacheCount items • $_metadataCacheSize",
              style: TextStyle(color: subtitleColor)),
          onTap: () async {
            ref.read(canvasCacheInvalidationProvider.notifier).state++;
            await Future.delayed(const Duration(milliseconds: 100));

            await DBService().clearMetadataCache();
            SmartArt.clearAllMemoryCaches();

            // Trigger full library rescan
            ref.read(libraryProvider.notifier).refreshLibrary();

            if (context.mounted) {
              _loadCacheSize();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        AppLocalizations.of(context)!.metadataCacheCleared)),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.delete_forever_rounded, color: Colors.red[400]),
          title: Text(AppLocalizations.of(context)!.resetStatistics,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.clearPlayHistory,
              style: TextStyle(color: subtitleColor)),
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Theme.of(context).cardColor,
                title: Text(AppLocalizations.of(context)!.resetStatsTitle),
                content: Text(
                  AppLocalizations.of(context)!.resetStatsContent,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text("Cancel", style: TextStyle(color: textColor)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(AppLocalizations.of(context)!.resetEverything),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await ref.read(statsProvider.notifier).resetStats();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(AppLocalizations.of(context)!.statisticsReset),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        ),
        const SizedBox(height: 30),
        Text(AppLocalizations.of(context)!.offlineModeHeader,
            key: _offlineModeKey,
            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: settings.isOfflineMode
                  ? Colors.orange.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
            color: settings.isOfflineMode
                ? Colors.orange.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: SwitchListTile(
            title: Row(
              children: [
                Icon(
                  settings.isOfflineMode
                      ? Icons.wifi_off_rounded
                      : Icons.wifi_rounded,
                  color: settings.isOfflineMode ? Colors.orange : textColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.offlineModeTitle,
                    style: TextStyle(
                      color: settings.isOfflineMode ? Colors.orange : textColor,
                      fontWeight: FontWeight.bold,
                    )),
                if (settings.isOfflineMode) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: Text(AppLocalizations.of(context)!.offlineModeActive,
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              settings.isOfflineMode
                  ? AppLocalizations.of(context)!.offlineModeLockdownDesc
                  : AppLocalizations.of(context)!.offlineModeMainDesc,
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            value: settings.isOfflineMode,
            activeThumbColor: Colors.orange,
            activeTrackColor: Colors.orange.withValues(alpha: 0.3),
            onChanged: (val) async {
              if (val) {
                // Show confirmation dialog when ENABLING
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor:
                        isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            color: Colors.orange, size: 24),
                        const SizedBox(width: 10),
                        Text(
                            AppLocalizations.of(context)!
                                .enableOfflineModeQuestion,
                            style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ],
                    ),
                    content: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!
                                .offlineModeConfirmationDesc,
                            style:
                                TextStyle(color: subtitleColor, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          _buildOfflineFeatureItem(
                              Icons.cloud_off_rounded,
                              AppLocalizations.of(context)!.featureCloudSync,
                              AppLocalizations.of(context)!
                                  .featureCloudSyncDesc,
                              Colors.red),
                          _buildOfflineFeatureItem(
                              Icons.leaderboard_rounded,
                              AppLocalizations.of(context)!.featureLeaderboard,
                              AppLocalizations.of(context)!
                                  .featureLeaderboardDesc,
                              Colors.amber),
                          _buildOfflineFeatureItem(
                              Icons.lyrics_rounded,
                              AppLocalizations.of(context)!.featureOnlineLyrics,
                              AppLocalizations.of(context)!
                                  .featureOnlineLyricsDesc,
                              Colors.blue),
                          _buildOfflineFeatureItem(
                              Icons.auto_awesome_rounded,
                              AppLocalizations.of(context)!.featureAiLyrics,
                              AppLocalizations.of(context)!.featureAiLyricsDesc,
                              Colors.purple),
                          _buildOfflineFeatureItem(
                              Icons.video_library_rounded,
                              AppLocalizations.of(context)!
                                  .featureSpotifyCanvas,
                              AppLocalizations.of(context)!
                                  .featureSpotifyCanvasDesc,
                              Colors.green),
                          _buildOfflineFeatureItem(
                              Icons.search_off_rounded,
                              AppLocalizations.of(context)!.featureOnlineSearch,
                              AppLocalizations.of(context)!
                                  .featureOnlineSearchDesc,
                              Colors.teal),
                          _buildOfflineFeatureItem(
                              Icons.devices_rounded,
                              AppLocalizations.of(context)!
                                  .featureConnectDevice,
                              AppLocalizations.of(context)!
                                  .featureConnectDeviceDesc,
                              Colors.orange),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    color: Colors.blue, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(context)!
                                        .offlineModeSyncRestoreNote,
                                    style: TextStyle(
                                        color: Colors.blue[300], fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text("Cancel",
                            style: TextStyle(color: subtitleColor)),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.wifi_off_rounded, size: 16),
                        label: Text(
                            AppLocalizations.of(context)!.enableOfflineModeBtn),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  settingsNotifier.toggleOfflineMode(true);
                }
              } else {
                // Disabling: trigger catch-up sync
                settingsNotifier.toggleOfflineMode(false);
                // Trigger a full sync to push accumulated offline stats
                Future.microtask(() {
                  ref.read(statsProvider.notifier).syncNow();
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.cloud_sync_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                              AppLocalizations.of(context)!.onlineModeRestored),
                        ],
                      ),
                      backgroundColor: Colors.green[700],
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
        ),

        // --- GRANULAR SERVICE CONTROLS ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: settings.isOfflineMode
                  ? null
                  : () => _showGranularServicesDialog(
                      context, textColor, subtitleColor, isDark),
              child: Opacity(
                opacity: settings.isOfflineMode ? 0.5 : 1.0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[400]!.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.miscellaneous_services_rounded,
                            color: Colors.blue[400], size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                AppLocalizations.of(context)!
                                    .disableServicesTitle,
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(
                                AppLocalizations.of(context)!
                                    .manageIndividualFeatures,
                                style: TextStyle(
                                    color: subtitleColor, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: settings.isOfflineMode
                              ? Colors.grey[500]!.withValues(alpha: 0.2)
                              : (disabledCount > 0
                                  ? Colors.red[400]!.withValues(alpha: 0.2)
                                  : Colors.green[400]!.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          settings.isOfflineMode
                              ? AppLocalizations.of(context)!
                                  .offlineModeEnabledStatus
                              : (disabledCount > 0
                                  ? AppLocalizations.of(context)!
                                      .offlineModeDisabledStatus(disabledCount)
                                  : AppLocalizations.of(context)!
                                      .offlineModeAllEnabledStatus),
                          style: TextStyle(
                            color: settings.isOfflineMode
                                ? Colors.grey[400]
                                : (disabledCount > 0
                                    ? Colors.red[400]
                                    : Colors.green[400]),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded, color: subtitleColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),

        // DEBUGGING
        Container(
          key: useDetailKeys ? _categoryKeys[10] : null,
          child: Text(AppLocalizations.of(context)!.debugging.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.showDebugButton,
              style: TextStyle(color: textColor)),
          subtitle: Text(AppLocalizations.of(context)!.toggleDebugConsole,
              style: TextStyle(color: subtitleColor)),
          value: settings.showDebugButton,
          activeThumbColor: accentColor,
          onChanged: (val) => settingsNotifier.toggleDebugButton(val),
        ),
        const SizedBox(height: 30),

        // COMMUNITY
        LayoutBuilder(
          key: useDetailKeys ? _categoryKeys[11] : null,
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            // Narrow screens (most phones) vs wider screens
            final isSmallScreen = screenWidth < 450;
            final buttonPadding = isSmallScreen ? 12.0 : 16.0;
            final fontSize = isSmallScreen ? 13.0 : 15.0;
            final iconSize = isSmallScreen ? 18.0 : 22.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.community.toUpperCase(),
                    style: TextStyle(
                        color: accentColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.discord, size: iconSize),
                        label: Text(
                          AppLocalizations.of(context)!.joinUs,
                          style: TextStyle(
                              fontSize: fontSize, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5865F2),
                          foregroundColor: Colors.white,
                          padding:
                              EdgeInsets.symmetric(vertical: buttonPadding),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final url =
                              Uri.parse('https://discord.gg/9uwUaAdXtC');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.favorite, size: iconSize),
                        label: Text(
                          AppLocalizations.of(context)!.donate,
                          style: TextStyle(
                              fontSize: fontSize, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                          padding:
                              EdgeInsets.symmetric(vertical: buttonPadding),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final url =
                              Uri.parse('https://sociabuzz.com/momotz4g/tribe');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 40),
        // VERSION & ADMIN ACCESS (Hidden)
        Center(
          child: GestureDetector(
            onTap: () {
              // Secret Admin Access (5 taps)
              // We use a static variable or state to count taps
              // But for simplicity in this stateless widget logic:
              _handleAdminTap(context);
            },
            child: Text(
              _versionText,
              style: TextStyle(
                  color: subtitleColor.withValues(alpha: 0.5), fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }



  // Admin Tap Logic
  int _adminTapCount = 0;
  DateTime? _lastTapTime;

  void _handleAdminTap(BuildContext context) {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 1)) {
      _adminTapCount = 0; // Reset if too slow
    }

    _lastTapTime = now;
    _adminTapCount++;

    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      _showAdminLoginDialog(context);
    }
  }

  Future<void> _showRestartDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false, // Force choice
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(AppLocalizations.of(context)!.restartRequired),
        content: Text(
          AppLocalizations.of(context)!.changingAudioDeviceRestart,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          AppLocalizations.of(context)!.changesApplyRestart)),
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.later),
          ),
          FilledButton(
            onPressed: () async {
              // Restart Logic
              if (Platform.isWindows) {
                // Launch new instance
                await Process.start(Platform.resolvedExecutable, []);
                exit(0);
              } else {
                Navigator.pop(context);
                // Fallback for other platforms
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(AppLocalizations.of(context)!
                          .autoRestartNotSupported)),
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.restartNow),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdminLoginDialog(BuildContext context) async {
    final controller = TextEditingController();
    final bool? success = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(AppLocalizations.of(context)!.enterAdminAccessCode),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.accessCode,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Cancel
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true), // Submit
            child: Text(AppLocalizations.of(context)!.access),
          ),
        ],
      ),
    );

    if (success == true && controller.text.isNotEmpty) {
      // Verify Code - returns 'admin', 'viewer', or null
      final role = await MetricsService().verifyAdminCode(controller.text);

      if (role != null) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminStatsPage(role: role),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(AppLocalizations.of(context)!.invalidAccessCode),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildAtmosphereChip(
    BuildContext context, {
    required String title,
    required IconData? icon,
    required AtmosphereTheme theme,
    required AtmosphereTheme currentTheme,
    required SettingsNotifier settingsNotifier,
    required Color activeColor,
    Widget? customIcon,
  }) {
    final bool isSelected = theme == currentTheme;
    final Color textColor = isSelected ? Colors.white : Colors.grey;
    final Color iconColor = isSelected ? Colors.white : activeColor;

    return ChoiceChip(
      label: Text(title,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          settingsNotifier.setAtmosphereTheme(theme);
        }
      },
      avatar: customIcon ??
          (icon != null ? Icon(icon, color: iconColor, size: 18) : null),
      selectedColor: activeColor,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildSearchEngineChip(
    BuildContext context, {
    required String title,
    required IconData icon,
    required SearchEngine engine,
    required SearchEngine currentEngine,
    required SettingsNotifier settingsNotifier,
    required Color activeColor,
  }) {
    final bool isSelected = engine == currentEngine;
    final Color textColor = isSelected ? Colors.white : Colors.grey;
    final Color iconColor = isSelected ? Colors.white : activeColor;

    return ChoiceChip(
      label: Text(title,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          settingsNotifier.setSearchEngine(engine);
        }
      },
      avatar: Icon(icon, color: iconColor, size: 18),
      selectedColor: activeColor,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildOfflineFeatureItem(
      IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGranularToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required bool isOfflineMode,
    required Color activeColor,
    required Color textColor,
    required Color subtitleColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Opacity(
      opacity: isOfflineMode ? 0.4 : 1.0,
      child: IgnorePointer(
        ignoring: isOfflineMode,
        child: SwitchListTile(
          secondary: Icon(icon,
              color: value && !isOfflineMode ? activeColor : Colors.grey,
              size: 18),
          title: Text(title,
              style: TextStyle(
                  color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle,
              style: TextStyle(color: subtitleColor, fontSize: 11)),
          value: isOfflineMode ? false : value,
          onChanged: onChanged,
          activeThumbColor: activeColor,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

/// A simple data class representing a settings category for the master panel.
class _SettingsCategory {
  final String title;
  final IconData icon;

  const _SettingsCategory({required this.title, required this.icon});
}
