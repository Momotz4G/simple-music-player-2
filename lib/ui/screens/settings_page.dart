import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../providers/settings_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/stats_provider.dart';
import '../../services/youtube_downloader_service.dart';
import 'admin_stats_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _cacheSizeText = "Calculating...";
  String _versionText = "Version ...";
  final YoutubeDownloaderService _ytService = YoutubeDownloaderService();

  final TextEditingController _formatCtrl = TextEditingController();
  String _savedPattern = "{artist} - {title}";
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
    _loadFormat();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _versionText = "Version ${info.version}";
      });
    }
  }

  @override
  void dispose() {
    _formatCtrl.dispose();
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
    setState(() {
      _savedPattern = pattern;
      _formatCtrl.text = pattern;
      _hasUnsavedChanges = false;
    });
  }

  void _onFormatChanged(String value) {
    setState(() {
      _hasUnsavedChanges = value != _savedPattern;
    });
  }

  Future<void> _saveFormat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('filename_pattern', _formatCtrl.text);
    if (mounted) {
      setState(() {
        _savedPattern = _formatCtrl.text;
        _hasUnsavedChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Format saved!")),
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
          SnackBar(content: Text("Download path updated: $selectedDirectory")),
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
        const SnackBar(content: Text("Download path reset to default.")),
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
            padding: const EdgeInsets.only(bottom: 30, top: 20),
            child: Text('Settings',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
          ),

          // APPEARANCE
          Text("APPEARANCE",
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SwitchListTile(
            title: Text("Dark Mode", style: TextStyle(color: textColor)),
            subtitle:
                Text("Use dark theme", style: TextStyle(color: subtitleColor)),
            value: settings.isDarkMode,
            activeColor: accentColor,
            onChanged: (val) => settingsNotifier.toggleTheme(val),
          ),
          SwitchListTile(
            title: Text("Sync Theme with Album Art",
                style: TextStyle(color: textColor)),
            subtitle: Text("Tint background and visualizer with song color",
                style: TextStyle(color: subtitleColor)),
            value: settings.syncThemeWithAlbumArt,
            activeColor: accentColor,
            onChanged: (val) =>
                settingsNotifier.toggleSyncThemeWithAlbumArt(val),
          ),
          ListTile(
            title: Text("Accent Color", style: TextStyle(color: textColor)),
            subtitle: Text("Choose your preferred static color",
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
            title: Text("Content Region", style: TextStyle(color: textColor)),
            subtitle: Text("Set country for new releases & charts",
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
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                underline: Container(),
                icon:
                    Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
                focusColor: Colors.transparent,
                items: const [
                  DropdownMenuItem(
                      value: 'US', child: Text("🇺🇸 United States")),
                  DropdownMenuItem(value: 'ID', child: Text("🇮🇩 Indonesia")),
                  DropdownMenuItem(
                      value: 'KR', child: Text("🇰🇷 South Korea")),
                  DropdownMenuItem(value: 'JP', child: Text("🇯🇵 Japan")),
                  DropdownMenuItem(
                      value: 'GB', child: Text("🇬🇧 United Kingdom")),
                  DropdownMenuItem(value: 'BR', child: Text("🇧🇷 Brazil")),
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
          Text("VISUALIZER",
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: Text("Enable Bar Visualizer",
                style: TextStyle(color: textColor)),
            subtitle: Text("Show animated waves in player bar",
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
              title:
                  Text("Visualizer Style", style: TextStyle(color: textColor)),
              subtitle: Text("Choose animation type",
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
                  style:
                      TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  underline: Container(),
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: accentColor),
                  focusColor: Colors.transparent,
                  items: const [
                    DropdownMenuItem(
                        value: VisualizerStyle.spectrum,
                        child: Text("Spectrum Bars")),
                    DropdownMenuItem(
                        value: VisualizerStyle.wave, child: Text("Fluid Wave")),
                    DropdownMenuItem(
                        value: VisualizerStyle.pulse,
                        child: Text("Circular Pulse")),
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
              title: Text("Rainbow Mode", style: TextStyle(color: textColor)),
              subtitle: Text("Use mixed colors (Overrides sync)",
                  style: TextStyle(color: subtitleColor)),
              value: settings.isVisualizerRainbow,
              activeColor: accentColor,
              onChanged: (val) => settingsNotifier.toggleVisualizerRainbow(val),
            ),
          ],
          const SizedBox(height: 30),

          // INTEGRATION
          Text("INTEGRATION",
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: Text("Discord Rich Presence",
                style: TextStyle(color: textColor)),
            subtitle: Text("Show status on Discord",
                style: TextStyle(color: subtitleColor)),
            value: settings.enableDiscordRpc,
            activeColor: accentColor,
            onChanged: (val) => settingsNotifier.toggleDiscordRpc(val),
          ),
          const SizedBox(height: 30),

          // LIBRARY
          Text("LIBRARY",
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          ListTile(
            title: Text("Music Folder Location",
                style: TextStyle(color: textColor)),
            subtitle: Text(library.selectedFolder ?? "No folder selected",
                style: TextStyle(color: subtitleColor)),
            trailing: TextButton(
                onPressed: library.pickFolder,
                child: Text("Change", style: TextStyle(color: accentColor))),
          ),
          const SizedBox(height: 30),

          // DOWNLOADS
          Text("DOWNLOADS",
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),

          // Filename Format
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Filename Format", style: TextStyle(color: textColor)),
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
                      tooltip: "Save Format",
                      onPressed: _saveFormat,
                    ),
                  ),
                ),
                if (_hasUnsavedChanges)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text("You have unsaved changes",
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
                    _buildTagChip("{date}", Colors.grey),
                  ],
                ),
              ],
            ),
          ),

          // Audio Format Selector (NEW)
          ListTile(
            title: Text("Audio Format", style: TextStyle(color: textColor)),
            subtitle: Text("Preferred output format for downloads",
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
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                underline: Container(),
                icon:
                    Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
                focusColor: Colors.transparent,
                items: const [
                  DropdownMenuItem(value: 'mp3', child: Text("MP3 (Standard)")),
                  DropdownMenuItem(value: 'm4a', child: Text("M4A (Better)")),
                  DropdownMenuItem(value: 'aac', child: Text("AAC (Raw)")),
                ],
                onChanged: (String? newFormat) {
                  if (newFormat != null) {
                    settingsNotifier.setAudioFormat(newFormat);
                  }
                },
              ),
            ),
          ),

          // Download Location
          FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, snapshot) {
              String currentPath = "Default (Downloads/SimpleMusicDownloads)";
              bool hasCustomPath = false;
              if (snapshot.hasData) {
                final path = snapshot.data!.getString('custom_download_path');
                if (path != null) {
                  currentPath = path;
                  hasCustomPath = true;
                }
              }
              return ListTile(
                title: Text("Download Location",
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
                        tooltip: "Reset to Default",
                        onPressed: () => _resetDownloadPath(context),
                      ),
                    IconButton(
                      icon: Icon(Icons.folder_open, color: accentColor),
                      tooltip: "Change Folder",
                      onPressed: () => _pickDownloadPath(context),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 30),

          // DATA & CLEANUP
          Text("DATA & CLEANUP",
              style:
                  TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          ListTile(
            leading:
                Icon(Icons.folder_delete_rounded, color: Colors.orange[400]),
            title:
                Text("Reset Library Path", style: TextStyle(color: textColor)),
            subtitle: Text("Unlink folder and clear song list",
                style: TextStyle(color: subtitleColor)),
            onTap: () {
              if (library.selectedFolder == null) return;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).cardColor,
                  title: const Text("Reset Library?"),
                  content: const Text(
                    "This will remove the current folder from the player. Your actual files will NOT be deleted.",
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
                          const SnackBar(content: Text("Library path reset.")),
                        );
                      },
                      child: const Text("Reset Path"),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading:
                Icon(Icons.cleaning_services_rounded, color: Colors.blue[400]),
            title: Text("Clear Streaming Cache",
                style: TextStyle(color: textColor)),
            subtitle: Text("Free up space (Current: $_cacheSizeText)",
                style: TextStyle(color: subtitleColor)),
            onTap: () async {
              await _ytService.clearCache();
              if (context.mounted) {
                setState(() {
                  _cacheSizeText = "0.0 MB";
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cache cleared successfully!")),
                );
                _loadCacheSize();
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_rounded, color: Colors.red[400]),
            title: Text("Reset Statistics", style: TextStyle(color: textColor)),
            subtitle: Text("Clear play history and listening time",
                style: TextStyle(color: subtitleColor)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Theme.of(context).cardColor,
                  title: const Text("Reset Stats?"),
                  content: const Text(
                    "This action cannot be undone.\nAll play counts and listening time will be lost forever.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text("Cancel", style: TextStyle(color: textColor)),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Reset Everything"),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(statsProvider.notifier).resetStats();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Statistics have been reset."),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 50),

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
          const SizedBox(height: 50),
        ],
      ),
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

  Future<void> _showAdminLoginDialog(BuildContext context) async {
    final controller = TextEditingController();
    final bool? success = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text("Enter Admin Access Code"),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Access Code",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Cancel
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true), // Submit
            child: const Text("Access"),
          ),
        ],
      ),
    );

    if (success == true && controller.text.isNotEmpty) {
      // Verify Code with Firestore
      // We check 'settings/admin' document
      try {
        final doc = await FirebaseFirestore.instance
            .collection('settings')
            .doc('admin')
            .get();
        if (doc.exists && doc.data()?['access_code'] == controller.text) {
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminStatsPage()),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("❌ Invalid Access Code"),
                  backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
