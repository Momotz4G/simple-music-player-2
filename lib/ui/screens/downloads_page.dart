import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:metadata_god/metadata_god.dart';

import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../components/smart_art.dart';

class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;
  String? _downloadPath;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);

    try {
      // SharedPreferences is LOCAL storage - no timeout needed
      final prefs = await SharedPreferences.getInstance();
      String? path = prefs.getString('custom_download_path');

      if (path == null) {
        if (Platform.isAndroid) {
          // 🚀 Use public Download directory on Android
          try {
            final updatePath = Directory("/storage/emulated/0/Download");
            if (await updatePath.exists()) {
              path = '${updatePath.path}/SimpleMusicDownloads';
            } else {
              // Fallback logic - path_provider is LOCAL, no timeout needed
              final externalDir = await getExternalStorageDirectory();
              if (externalDir != null) {
                final androidPath = externalDir.path;
                final androidIndex = androidPath.indexOf("/Android/");
                if (androidIndex != -1) {
                  path =
                      "${androidPath.substring(0, androidIndex)}/Download/SimpleMusicDownloads";
                }
              }
            }
          } catch (e) {
            print("Error accessing public directory: $e");
            // 🚀 Hardcoded fallback for offline mode
            path = "/storage/emulated/0/Download/SimpleMusicDownloads";
          }
        } else if (Platform.isIOS) {
          final dir = await getApplicationDocumentsDirectory();
          path = '${dir.path}/SimpleMusicDownloads';
        } else {
          // Desktop
          final dir = await getDownloadsDirectory();
          if (dir != null) {
            path = '${dir.path}/SimpleMusicDownloads';
          }
        }
      }

      _downloadPath = path;

      if (path != null) {
        final dir = Directory(path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        if (await dir.exists()) {
          final List<FileSystemEntity> entities = dir.listSync();

          final audioFiles = entities.where((e) {
            final ext = p.extension(e.path).toLowerCase();
            return ['.mp3', '.m4a', '.wav', '.flac', '.aac'].contains(ext);
          }).toList();

          audioFiles.sort(
              (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

          if (mounted) {
            setState(() {
              _files = audioFiles;
            });
          }
        }
      }
    } catch (e) {
      print("Error loading downloads: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // NEW: OPEN FOLDER LOGIC
  Future<void> _openFileLocation(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    if (Platform.isWindows) {
      // 🛠️ FIX: Windows Explorer requires Backslashes (\) for the /select command.
      // Dart often uses Forward Slashes (/) which confuses Explorer.
      final String windowsPath = filePath.replaceAll('/', '\\');

      await Process.run('explorer.exe', ['/select,', windowsPath]);
    } else if (Platform.isMacOS) {
      // macOS: Reveals in Finder
      await Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      // Linux: Opens the directory
      await Process.run('xdg-open', [file.parent.path]);
    }
  }

  Future<void> _playFile(FileSystemEntity file) async {
    final filename = p.basenameWithoutExtension(file.path);

    // 1. Smart Fallbacks from Filename (e.g. "Taylor Swift - Style")
    String title = filename;
    String artist = "Unknown Artist";

    if (filename.contains(' - ')) {
      final parts = filename.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].trim(); // "Taylor Swift"
        title = parts.sublist(1).join(' - ').trim(); // "Style"
      }
    }

    double duration = 0.0;

    // 2. Try to read real metadata (overwrites smart fallback if successful)
    try {
      final metadata = await MetadataGod.readMetadata(file: file.path);

      // Only overwrite if the metadata actually exists
      if (metadata.title != null && metadata.title!.isNotEmpty) {
        title = metadata.title!;
      }
      if (metadata.artist != null && metadata.artist!.isNotEmpty) {
        artist = metadata.artist!;
      }

      duration = (metadata.durationMs ?? 0) / 1000.0;
    } catch (e) {
      print("Error reading metadata for play: $e");
    }

    // 3. Create SongModel
    final song = SongModel(
      title: title,
      artist: artist,
      album: "Downloads",
      filePath: file.path,
      duration: duration,
      fileExtension: p.extension(file.path),
    );

    // 4. Create Queue (apply same logic to queue items)
    final queue = _files.map((f) {
      if (f.path == file.path) return song;

      final fName = p.basenameWithoutExtension(f.path);
      String qTitle = fName;
      String qArtist = "Unknown Artist";

      // Apply same smart parsing to queue items so they look good too
      if (fName.contains(' - ')) {
        final parts = fName.split(' - ');
        if (parts.length >= 2) {
          qArtist = parts[0].trim();
          qTitle = parts.sublist(1).join(' - ').trim();
        }
      }

      return SongModel(
        title: qTitle,
        artist: qArtist,
        album: "Downloads",
        filePath: f.path,
        duration: 0,
        fileExtension: p.extension(f.path),
      );
    }).toList();

    if (mounted) {
      ref.read(playerProvider.notifier).playSong(song, newQueue: queue);
    }
  }

  Future<void> _confirmDelete(FileSystemEntity file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete File?"),
        content:
            Text("Delete '${p.basename(file.path)}'?\nThis cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await file.delete();
        _loadFiles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error deleting: $e")));
        }
      }
    }
  }

  String _formatFileSize(FileSystemEntity file) {
    try {
      final bytes = file.statSync().size;
      if (bytes < 1024) return "$bytes B";
      if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            // HEADER (Shifted Mobile)
            Padding(
              padding: EdgeInsets.only(
                  left: (Platform.isAndroid || Platform.isIOS) ? 40.0 : 0.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Downloads',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                      ),
                      if (_downloadPath != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            _downloadPath!,
                            style: TextStyle(color: subTextColor, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadFiles,
                    tooltip: "Refresh List",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // LIST
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _files.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_off,
                                  size: 64,
                                  color: Colors.grey.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text("No downloads found",
                                  style: TextStyle(color: subTextColor)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _files.length,
                          padding: const EdgeInsets.only(bottom: 100),
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            final filename = p.basename(file.path);

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              leading: SmartArt(
                                path: file.path,
                                size: 50,
                                borderRadius: 6,
                              ),
                              title: Text(
                                filename,
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _formatFileSize(file),
                                style: TextStyle(
                                    color: subTextColor, fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 1. Play
                                  IconButton(
                                    icon: Icon(Icons.play_circle_fill,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    tooltip: "Play",
                                    onPressed: () => _playFile(file),
                                  ),

                                  // 2. Open Folder (NEW)
                                  IconButton(
                                    icon: const Icon(Icons.folder_open,
                                        color: Colors.blueAccent),
                                    tooltip: "Show in Folder",
                                    onPressed: () =>
                                        _openFileLocation(file.path),
                                  ),

                                  // 3. Delete
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent),
                                    tooltip: "Delete",
                                    onPressed: () => _confirmDelete(file),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
