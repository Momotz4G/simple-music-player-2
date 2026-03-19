import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart'; // Import for device list
import '../../l10n/app_localizations.dart';

import '../../providers/settings_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/data_usage_provider.dart'; // Added
import '../../providers/stats_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/youtube_downloader_service.dart';
import '../../services/metrics_service.dart';
import '../../services/android_audio_service.dart'; // NEW
import '../../services/usb_audio_service.dart'; // USB Audio for Android <14
import 'admin_stats_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _cacheSizeText = "";
  String _versionText = "";
  final YoutubeDownloaderService _ytService = YoutubeDownloaderService();

  final TextEditingController _formatCtrl = TextEditingController();
  final TextEditingController _playlistFormatCtrl = TextEditingController();

  String _savedPattern = "{artist} - {title}";
  String _savedPlaylistPattern = "{artist} - {title}";

  // Audio Device Handling
  List<Map<String, String>> _audioDevices = [];
  bool _loadingAudioDevices = false;
  bool _isAndroidBitPerfectSupported = false; // NEW

  // USB Audio for Android <14
  List<UsbDacDevice> _usbDacs = [];
  bool _loadingUsbDacs = false;
  UsbDacDevice? _connectedDac;
  bool _usbAudioEnabled = false;

  bool get _unsavedSingle => _formatCtrl.text != _savedPattern;
  bool get _unsavedPlaylist =>
      _playlistFormatCtrl.text != _savedPlaylistPattern;

  String _getStreamingQualityDescription(String quality) {
    switch (quality) {
      case 'standard':
        return AppLocalizations.of(context)!.standardDesc;
      case 'high':
        return AppLocalizations.of(context)!.highDesc;
      case 'lossless':
        return AppLocalizations.of(context)!.losslessDesc;
      default:
        return AppLocalizations.of(context)!.selectStreamingQuality;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
    _loadFormat();
    _loadVersion();
    if (Platform.isWindows) {
      _loadAudioDevices();
    }
    if (Platform.isAndroid) {
      _checkAndroidSupport();
    }
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
        _versionText =
            "${AppLocalizations.of(context)!.version} ${info.version}";
      });
    }
  }

  @override
  void dispose() {
    _formatCtrl.dispose();
    _playlistFormatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCacheSize() async {
    final size = await _ytService.getCacheSize();
    if (mounted) {
      setState(() {
        _cacheSizeText = size;
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
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
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
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final library = p.Provider.of<LibraryProvider>(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey : Colors.grey[600];
    final accentColor = settings.accentColor;

    final List<Color> accentColors = [
      const Color(0xFF6C5CE7),
      const Color(0xFFFF7675),
      const Color(0xFF00CEC9),
      const Color(0xFFFD79A8),
      const Color(0xFFFAB1A0),
      const Color(0xFF55EFC4),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(32),
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
          Text(AppLocalizations.of(context)!.appearance.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
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
            activeColor: accentColor,
            // Disabled when an atmosphere is on
            onChanged: settings.atmosphereTheme != AtmosphereTheme.none
                ? null
                : (val) => settingsNotifier.toggleTheme(val),
          ),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.syncThemeAlbumArt,
                style: TextStyle(color: textColor)),
            subtitle: Text(AppLocalizations.of(context)!.tintBackground,
                style: TextStyle(color: subtitleColor)),
            value: settings.syncThemeWithAlbumArt,
            activeColor: accentColor,
            onChanged: (val) =>
                settingsNotifier.toggleSyncThemeWithAlbumArt(val),
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
                final isSelected = settings.accentColor.value == color.value;
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
                              color: color.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 2)
                      ],
                    ),
                    child: isSelected
                        ? Icon(Icons.check,
                            color: isDark ? Colors.black : Colors.white,
                            size: 20)
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
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                underline: Container(),
                icon:
                    Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
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
                      child:
                          Text("🇯🇵 ${AppLocalizations.of(context)!.japan}")),
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
          Text(AppLocalizations.of(context)!.visualizer.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.enableBarVisualizer,
                style: TextStyle(color: textColor)),
            subtitle: Text(AppLocalizations.of(context)!.showAnimatedWaves,
                style: TextStyle(color: subtitleColor)),
            value: settings.enableVisualizer,
            activeColor: accentColor,
            onChanged: (val) => settingsNotifier.toggleVisualizer(val),
          ),
          if (settings.enableVisualizer) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "Opacity: ${(settings.visualizerOpacity * 100).toInt()}%",
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
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: accentColor),
                  focusColor: Colors.transparent,
                  items: [
                    DropdownMenuItem(
                        value: VisualizerStyle.spectrum,
                        child:
                            Text(AppLocalizations.of(context)!.spectrumBars)),
                    DropdownMenuItem(
                        value: VisualizerStyle.wave,
                        child: Text(AppLocalizations.of(context)!.fluidWave)),
                    DropdownMenuItem(
                        value: VisualizerStyle.pulse,
                        child:
                            Text(AppLocalizations.of(context)!.circularPulse)),
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
              activeColor: accentColor,
              onChanged: (val) => settingsNotifier.toggleVisualizerRainbow(val),
            ),
          ],
          const SizedBox(height: 30),

          // INTEGRATION
          Text(AppLocalizations.of(context)!.integration.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.discordRPC,
                style: TextStyle(color: textColor)),
            subtitle: Text(AppLocalizations.of(context)!.showStatusDiscord,
                style: TextStyle(color: subtitleColor)),
            value: settings.enableDiscordRpc,
            activeColor: accentColor,
            onChanged: (val) => settingsNotifier.toggleDiscordRpc(val),
          ),
          const SizedBox(height: 30),

          // LIBRARY
          Text(AppLocalizations.of(context)!.library.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          ListTile(
            title: Text(AppLocalizations.of(context)!.musicFolderLocation,
                style: TextStyle(color: textColor)),
            subtitle: Text(
                library.selectedFolder ??
                    AppLocalizations.of(context)!.noFolderSelected,
                style: TextStyle(color: subtitleColor)),
            trailing: TextButton(
                onPressed: library.pickFolder,
                child: Text(AppLocalizations.of(context)!.change,
                    style: TextStyle(color: accentColor))),
          ),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.ignoreSubfolderScan,
                style: TextStyle(color: textColor)),
            subtitle: Text(AppLocalizations.of(context)!.onlyScanSelected,
                style: TextStyle(color: subtitleColor)),
            value: settings.ignoreSubfolders,
            activeColor: accentColor,
            onChanged: (val) => settingsNotifier.toggleIgnoreSubfolders(val),
          ),
          if (Platform.isAndroid || Platform.isIOS)
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.enableAlphabetIndexer,
                  style: TextStyle(color: textColor)),
              subtitle: Text(AppLocalizations.of(context)!.enableAlphabetIndexerSubtitle,
                  style: TextStyle(color: subtitleColor)),
              value: settings.enableAlphabetIndexer,
              activeColor: accentColor,
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
                String? result = await FilePicker.platform.getDirectoryPath();
                if (result != null) {
                  await settingsNotifier.addMusicFolder(result);
                  // Scan the newly added folder
                  await library.scanAdditionalFolder(result);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(AppLocalizations.of(context)!
                              .addedFolder(
                                  result.split(Platform.pathSeparator).last))),
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
                children: settings.additionalMusicFolders.map((folder) {
                  final folderName = folder.split(Platform.pathSeparator).last;
                  return Tooltip(
                    message: folder, // Show full path on hover
                    child: Chip(
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.1)
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
          Text(AppLocalizations.of(context)!.downloads.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),

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
                            style: TextStyle(
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
                            style: TextStyle(
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
                value: settings.audioFormat,
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
                      value: 'mp3',
                      child:
                          Text(AppLocalizations.of(context)!.standardQuality)),
                  DropdownMenuItem(
                      value: 'm4a',
                      child: Text(AppLocalizations.of(context)!.highQuality)),
                  DropdownMenuItem(value: 'aac', child: Text("AAC (Raw)")),
                  DropdownMenuItem(
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
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
            future: SharedPreferences.getInstance(),
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
          Text(AppLocalizations.of(context)!.streaming.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),

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
                value: settings.streamingQuality,
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
                      value: 'standard',
                      child:
                          Text(AppLocalizations.of(context)!.standardQuality)),
                  DropdownMenuItem(
                      value: 'high',
                      child: Text(AppLocalizations.of(context)!.highQuality)),
                  DropdownMenuItem(
                      value: 'lossless',
                      child:
                          Text(AppLocalizations.of(context)!.losslessQuality)),
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
          if (settings.streamingQuality == 'lossless')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.high_quality, color: Colors.blue, size: 20),
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

          const SizedBox(height: 30),

          // PLAYBACK
          Text(AppLocalizations.of(context)!.playback.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
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
                    activeColor: accentColor,
                    onChanged: (_) => playerNotifier.toggleEndlessQueue(),
                  ),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.gaplessPlayback,
                        style: TextStyle(color: textColor)),
                    subtitle: Text(
                        AppLocalizations.of(context)!.gaplessPlaybackDesc,
                        style: TextStyle(color: subtitleColor)),
                    value: settings.gaplessPlayback,
                    activeColor: accentColor,
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
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: settings.crossfadeDuration,
                          min: 0,
                          max: 12,
                          divisions: 120,
                          activeColor: accentColor,
                          inactiveColor: accentColor.withOpacity(0.2),
                          onChanged: (val) =>
                              settingsNotifier.setCrossfadeDuration(val),
                        ),
                      ),
                    ),
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
            activeColor: accentColor,
            onChanged: (val) => settingsNotifier.toggleDisableRomanization(val),
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
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                underline: Container(),
                icon:
                    Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
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
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.disableCanvas,
                style: TextStyle(color: textColor)),
            subtitle: Text(AppLocalizations.of(context)!.hideCanvas,
                style: TextStyle(color: subtitleColor)),
            value: settings.disableCanvas,
            activeColor: accentColor,
            onChanged: (val) => settingsNotifier.toggleDisableCanvas(val),
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
              activeColor: accentColor,
              onChanged: (val) {
                settingsNotifier.toggleWasapiExclusive(val);
                _showRestartDialog(context);
              },
            ),

          // Android Bit-Perfect Mode (Android 14+)
          if (Platform.isAndroid)
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.androidBitPerfect,
                  style: TextStyle(color: textColor)),
              subtitle: Text(
                _isAndroidBitPerfectSupported
                    ? AppLocalizations.of(context)!.bypassSystemMixer
                    : AppLocalizations.of(context)!.requiresAndroid14,
                style: TextStyle(color: subtitleColor),
              ),
              value: settings.androidBitPerfect,
              activeColor: accentColor,
              onChanged: _isAndroidBitPerfectSupported
                  ? (val) {
                      settingsNotifier.toggleAndroidBitPerfect(val);
                      if (val) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(AppLocalizations.of(context)!
                                  .bitPerfectEnabled)),
                        );
                      }
                    }
                  : null, // Disable if not supported
            ),

          // USB Audio Bypass for Android < 14 (NEW)
          if (Platform.isAndroid && !_isAndroidBitPerfectSupported)
            _buildUsbAudioBypassSection(context, settings, settingsNotifier,
                isDark, textColor, subtitleColor, accentColor),

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
                            child: Text(
                                AppLocalizations.of(context)!.systemDefault),
                          ),
                          ..._audioDevices.map((d) {
                            return DropdownMenuItem<String?>(
                              value: d['name'],
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 200),
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
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.exclusiveModeWarning,
                        style: TextStyle(
                            color: Colors.amber.shade300, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 30),
          // SYSTEM
          Text(AppLocalizations.of(context)!.system.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
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
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                underline: Container(),
                icon:
                    Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
                focusColor: Colors.transparent,
                items: [
                  DropdownMenuItem(
                      value: 'en',
                      child: Text(
                          "🇺🇸 ${AppLocalizations.of(context)!.english}")),
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
                      child: Text(
                          "🇯🇵 ${AppLocalizations.of(context)!.japanese}")),
                  DropdownMenuItem(
                      value: 'zh',
                      child: Text(
                          "🇨🇳 ${AppLocalizations.of(context)!.chinese}")),
                  DropdownMenuItem(
                      value: 'es',
                      child: Text(
                          "🇪🇸 ${AppLocalizations.of(context)!.spanish}")),
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
                      child:
                          Text("🇹🇭 ${AppLocalizations.of(context)!.thai}")),
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
                      child: Text(
                          "🇷🇺 ${AppLocalizations.of(context)!.russian}")),
                  DropdownMenuItem(
                      value: 'hi',
                      child:
                          Text("🇮🇳 ${AppLocalizations.of(context)!.hindi}")),
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
          const SizedBox(height: 24),

          // DATA & CLEANUP
          Text(AppLocalizations.of(context)!.dataCleanup.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListTile(
            leading:
                Icon(Icons.folder_delete_rounded, color: Colors.orange[400]),
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
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.orange),
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
                Text(AppLocalizations.of(context)!.dataUsage, style: TextStyle(color: textColor)),
                const SizedBox(width: 6),
                Consumer(
                  builder: (context, ref, _) {
                    final usage = ref.watch(dataUsageProvider);
                    return Tooltip(
                      message: "${AppLocalizations.of(context)!.todayLabel(usage.todayFormatted)}\n"
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
              tooltip: "Reset Usage",
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Theme.of(context).cardColor,
                    title: Text("Reset Data Usage",
                        style: TextStyle(color: textColor)),
                    content: Text(
                        "Are you sure you want to reset data usage? This does not affect downloaded music.",
                        style: TextStyle(color: textColor)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child:
                            Text("Cancel", style: TextStyle(color: textColor)),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(dataUsageProvider.notifier).reset();
                          Navigator.pop(context);
                        },
                        child: const Text("Reset",
                            style: TextStyle(color: Colors.red)),
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
                setState(() {
                  _cacheSizeText = "0.0 MB";
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text(AppLocalizations.of(context)!.cacheCleared)),
                );
                _loadCacheSize();
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
                      child:
                          Text(AppLocalizations.of(context)!.resetEverything),
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

          // DEBUGGING
          Text(AppLocalizations.of(context)!.debugging.toUpperCase(),
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.showDebugButton,
                style: TextStyle(color: textColor)),
            subtitle: Text(AppLocalizations.of(context)!.toggleDebugConsole,
                style: TextStyle(color: subtitleColor)),
            value: settings.showDebugButton,
            activeColor: accentColor,
            onChanged: (val) => settingsNotifier.toggleShowDebugButton(val),
          ),
          const SizedBox(height: 30),

          // COMMUNITY
          LayoutBuilder(
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
                                fontSize: fontSize,
                                fontWeight: FontWeight.w600),
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
                            final url = Uri.parse(
                                'https://discord.com/invite/WkmB8kJWR');
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
                                fontSize: fontSize,
                                fontWeight: FontWeight.w600),
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
                            final url = Uri.parse(
                                'https://sociabuzz.com/momotz4g/tribe');
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
                    color: subtitleColor?.withOpacity(0.5), fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ============ USB Audio Bypass for Android <14 ============

  Widget _buildUsbAudioBypassSection(
    BuildContext context,
    dynamic settings,
    dynamic settingsNotifier,
    bool isDark,
    Color textColor,
    Color? subtitleColor,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // USB Audio Bypass Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.usb_rounded, color: accentColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.usbAudioBypassBeta,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Enable/Disable USB Audio (Temporarily Disabled - Coming Soon)
        SwitchListTile(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  AppLocalizations.of(context)!.usbAudioBypass,
                  style: TextStyle(color: textColor.withOpacity(0.5)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: Text(
                  AppLocalizations.of(context)!.comingSoon,
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            AppLocalizations.of(context)!.underDevelopment,
            style: TextStyle(color: subtitleColor?.withOpacity(0.5)),
          ),
          value: false,
          activeColor: accentColor,
          onChanged: null, // Disabled
        ),

        // DAC List (when enabled) - Temporarily hidden while feature is under development
        if (false && _usbAudioEnabled) ...[
          // Scan button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.connectedUsbDacs,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadingUsbDacs ? null : _scanForUsbDacs,
                  icon: _loadingUsbDacs
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accentColor,
                          ),
                        )
                      : Icon(Icons.refresh, color: accentColor, size: 16),
                  label: Text(
                    _loadingUsbDacs
                        ? AppLocalizations.of(context)!.scanning
                        : AppLocalizations.of(context)!.scan,
                    style: TextStyle(color: accentColor),
                  ),
                ),
              ],
            ),
          ),

          // DAC List
          if (_usbDacs.isEmpty && !_loadingUsbDacs)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: subtitleColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.noUsbDacDetected,
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_usbDacs.length, (index) {
              final dac = _usbDacs[index];
              final isConnected = _connectedDac?.vendorId == dac.vendorId &&
                  _connectedDac?.productId == dac.productId;

              return ListTile(
                leading: Icon(
                  Icons.speaker_rounded,
                  color: isConnected ? Colors.green : accentColor,
                ),
                title: Text(
                  dac.deviceName,
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  "VID:${dac.vendorId.toRadixString(16).toUpperCase()} PID:${dac.productId.toRadixString(16).toUpperCase()}",
                  style: TextStyle(color: subtitleColor, fontSize: 11),
                ),
                trailing: isConnected
                    ? Chip(
                        label: Text(AppLocalizations.of(context)!.connected),
                        backgroundColor: Colors.green.withOpacity(0.2),
                        labelStyle: const TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                        ),
                      )
                    : TextButton(
                        onPressed: () => _connectToDac(dac),
                        child: Text(AppLocalizations.of(context)!.connect,
                            style: TextStyle(color: accentColor)),
                      ),
              );
            }),
        ],

        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _scanForUsbDacs() async {
    setState(() => _loadingUsbDacs = true);
    try {
      final dacs = await UsbAudioService.getConnectedDacs();
      if (mounted) {
        setState(() {
          _usbDacs = dacs;
          _loadingUsbDacs = false;
        });
      }
    } catch (e) {
      debugPrint("Error scanning USB DACs: $e");
      if (mounted) setState(() => _loadingUsbDacs = false);
    }
  }

  Future<void> _connectToDac(UsbDacDevice dac) async {
    // Use the PlayerNotifier to enable bypass (this also opens the DAC)
    final playerNotifier = ref.read(playerProvider.notifier);
    final success = await playerNotifier.enableUsbAudioBypass(dac);
    if (success) {
      setState(() => _connectedDac = dac);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .connectedToDac(dac.deviceName))),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.failedToConnectDac)),
        );
      }
    }
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
          color: isSelected ? activeColor : Colors.grey.withOpacity(0.3),
        ),
      ),
      showCheckmark: false,
    );
  }
}
