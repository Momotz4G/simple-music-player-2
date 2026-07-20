import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pocketbase_service.dart';
import '../models/download_progress.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  // REPLACE WITH YOUR GITHUB USERNAME AND REPO NAME
  static const String _owner = "Momotz4G";
  static const String _repo = "simple-music-player-2";

  static const String _releasesUrl =
      "https://api.github.com/repos/$_owner/$_repo/releases";

  // Progress Notifier
  final ValueNotifier<DownloadProgress?> progressNotifier = ValueNotifier(null);

  /// Checks if a new version is available.
  /// Returns the release data if an update is available, null otherwise.
  Future<Map<String, dynamic>?> checkForUpdate() async {
    if (PocketBaseService.isOffline) return null;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      debugPrint("Checking for updates... Current version: $currentVersion");

      final response = await http.get(Uri.parse(_releasesUrl));

      if (response.statusCode == 200) {
        final List releases = json.decode(response.body);
        if (releases.isEmpty) {
          debugPrint("No releases found.");
          return null;
        }

        // Get the most recent release (first in list)
        // This includes Pre-releases if they are the most recent!
        final releaseData = releases.first as Map<String, dynamic>;

        final String tagName = releaseData['tag_name'];
        // Remove 'v' prefix if present
        final latestVersion = tagName.replaceAll('v', '');

        if (_isNewer(latestVersion, currentVersion)) {
          debugPrint("Update available: $latestVersion");
          return releaseData;
        } else {
          debugPrint("App is up to date.");
        }
      } else {
        debugPrint("Failed to check for updates: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error checking for updates: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> getLatestRelease() async {
    if (PocketBaseService.isOffline) return null;
    try {
      final response = await http.get(Uri.parse(_releasesUrl));
      if (response.statusCode == 200) {
        final List releases = json.decode(response.body);
        if (releases.isNotEmpty) {
          return releases.first as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint("Error fetching latest release: $e");
    }
    return null;
  }

  /// Compares two version strings (e.g., "1.0.1" vs "1.0.0").
  static bool _isNewer(String latest, String current) {
    try {
      final cleanLatest = latest.split('+').first.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');
      final cleanCurrent = current.split('+').first.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');

      List<int> l = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> c = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < l.length && i < c.length; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
      return l.length > c.length;
    } catch (_) {
      return false;
    }
  }

  /// Gets the correct asset for the current platform from the release
  /// Returns {downloadUrl, fileName} or null if no matching asset found
  Future<Map<String, String>?> getAssetForPlatform(
      Map<String, dynamic> release) async {
    final assets = release['assets'] as List?;
    if (assets == null || assets.isEmpty) return null;

    String extension;
    List<String> fallbackExtensions = [];

    if (Platform.isAndroid) {
      // Android ABI-specific APK selection
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      final List<String> supportedAbis = androidInfo.supportedAbis;

      debugPrint("Device supported ABIs: $supportedAbis");

      // Naming convention:
      // Universal: Simple.Music.Player.apk
      // ABI-specific: Simple.Music.Player-[ABI].apk

      Map<String, dynamic>? bestAsset;

      // 1. Try to find an exact ABI match (e.g. Simple.Music.Player-arm64-v8a.apk)
      for (final abi in supportedAbis) {
        final targetName = "simple.music.player-$abi.apk".toLowerCase();
        bestAsset = assets.firstWhere(
          (a) => a['name'].toString().toLowerCase() == targetName,
          orElse: () => null,
        );
        if (bestAsset != null) {
          debugPrint("Found exact ABI match: ${bestAsset['name']}");
          break;
        }
      }

      // 2. Try universal APK (Simple.Music.Player.apk)
      if (bestAsset == null) {
        bestAsset = assets.firstWhere(
          (a) =>
              a['name'].toString().toLowerCase() == "simple.music.player.apk",
          orElse: () => null,
        );
        if (bestAsset != null) debugPrint("Using universal APK");
      }

      // 3. Fallback to any .apk if still no match
      if (bestAsset == null) {
        bestAsset = assets.firstWhere(
          (a) => a['name'].toString().toLowerCase().endsWith(".apk"),
          orElse: () => null,
        );
        if (bestAsset != null) debugPrint("Falling back to first available APK");
      }

      if (bestAsset != null) {
        return {
          'downloadUrl': bestAsset['browser_download_url'] as String,
          'fileName': bestAsset['name'] as String,
          'size': (bestAsset['size'] ?? 0).toString(),
        };
      }

      return null;
    } else if (Platform.isWindows) {
      extension = '.exe';
    } else if (Platform.isMacOS) {
      extension = '.dmg';
      fallbackExtensions = ['.zip', '.app.zip'];
    } else if (Platform.isLinux) {
      extension = '.AppImage';
      fallbackExtensions = ['.tar.gz', '.deb'];
    } else if (Platform.isIOS) {
      extension = '.ipa';
    } else {
      return null;
    }

    // Try primary extension first
    var asset = assets.firstWhere(
      (a) =>
          a['name'].toString().toLowerCase().endsWith(extension.toLowerCase()),
      orElse: () => null,
    );

    // Try fallback extensions
    if (asset == null) {
      for (final fallback in fallbackExtensions) {
        asset = assets.firstWhere(
          (a) => a['name']
              .toString()
              .toLowerCase()
              .endsWith(fallback.toLowerCase()),
          orElse: () => null,
        );
        if (asset != null) break;
      }
    }

    if (asset != null) {
      return {
        'downloadUrl': asset['browser_download_url'] as String,
        'fileName': asset['name'] as String,
        'size': (asset['size'] ?? 0).toString(),
      };
    }

    return null;
  }

  /// Get platform name for UI display
  String get platformName {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  /// Downloads the installer asset and executes it.
  Future<void> downloadAndInstall(String downloadUrl, String fileName, String version) async {
    try {
      debugPrint("Downloading update from: $downloadUrl");

      final tempDir = await getTemporaryDirectory();
      final filePath = "${tempDir.path}/$fileName";
      final file = File(filePath);

      // Streamed Download for Progress
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode == 200) {
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;

        // SPEED CALCULATION
        DateTime lastSpeedUpdate = DateTime.now();
        int lastReceivedBytes = 0;
        double currentSpeedMBps = 0;

        final sink = file.openWrite();
        bool isFinished = false;

        // Use explicit subscription to allow manual cancellation
        // ignore: cancel_subscriptions
        final subscription = response.stream.listen(
          (chunk) {
            receivedBytes += chunk.length;
            sink.add(chunk);

            if (totalBytes > 0) {
              final progress = receivedBytes / totalBytes;
              final receivedMB = receivedBytes / (1024 * 1024);
              final totalMB = totalBytes / (1024 * 1024);

              // Calculate speed every 500ms to smooth out fluctuations
              final now = DateTime.now();
              final elapsed = now.difference(lastSpeedUpdate).inMilliseconds;
              if (elapsed >= 500) {
                final bytesInPeriod = receivedBytes - lastReceivedBytes;
                final secondsElapsed = elapsed / 1000.0;
                currentSpeedMBps =
                    (bytesInPeriod / (1024 * 1024)) / secondsElapsed;
                lastSpeedUpdate = now;
                lastReceivedBytes = receivedBytes;
              }

              // If finished, show Installing immediately
              final status =
                  progress >= 1.0 ? "Installing..." : "Downloading Update...";

              progressNotifier.value = DownloadProgress(
                receivedMB: receivedMB,
                totalMB: totalMB,
                progress: progress,
                status: status,
                speedMBps: currentSpeedMBps,
              );

              // Manual check for completion
              if (receivedBytes >= totalBytes && !isFinished) {
                isFinished = true;
                _finishInstallation(sink, client, filePath);
              }
            }
          },
          onDone: () async {
            if (!isFinished) {
              isFinished = true;
              await _finishInstallation(sink, client, filePath);
            }
          },
          onError: (e) {
            sink.close();
            client.close();
            progressNotifier.value = null;
            throw e;
          },
          cancelOnError: true,
        );

        await subscription.asFuture();

        // MARK AS PENDING Update before attempting install
        await _markPendingUpdate(filePath, version);
      } else {
        debugPrint("Failed to download update: ${response.statusCode}");
        throw Exception("Failed to download update");
      }
    } catch (e) {
      debugPrint("Error downloading/installing update: $e");
      progressNotifier.value = null;
      rethrow;
    }
  }

  Future<void> _finishInstallation(
      IOSink sink, http.Client client, String filePath) async {
    await sink.flush();
    await sink.close();
    client.close();

    debugPrint("Download complete. Executing installer: $filePath");

    // Give UI a moment to show "Installing..." if it hasn't yet
    await Future.delayed(const Duration(milliseconds: 500));

    if (Platform.isAndroid) {
      // Android: Open APK with package installer using open_filex
      progressNotifier.value = DownloadProgress(
        receivedMB: 0,
        totalMB: 0,
        progress: 1.0,
        status: "Opening installer...",
      );

      try {
        // Import open_filex dynamically to avoid issues on other platforms
        final result = await _openApkForInstall(filePath);

        if (result) {
          debugPrint("APK installer opened successfully");

          // CLEAR pending update once opened
          await _clearPendingUpdate();

          // Mark this file for cleanup after restart
          await _markFileForCleanup(filePath);

          // Reset progress after a delay
          await Future.delayed(const Duration(seconds: 1));
          progressNotifier.value = null;
        } else {
          debugPrint("Failed to open APK installer");
          
          // DO NOT clear progress if we failed, user might be in settings
          progressNotifier.value = DownloadProgress(
            receivedMB: 0,
            totalMB: 0,
            progress: 1.0,
            status: "Installer failed to open. Check permissions.",
          );
          
          // Keep it for a bit then clear UI but keep the pending file
          await Future.delayed(const Duration(seconds: 3));
          progressNotifier.value = null;
        }
      } catch (e) {
        debugPrint("Error opening APK: $e");
        progressNotifier.value = null;
      }

      return;
    } else if (Platform.isWindows) {
      // Inno Setup flags:
      // /VERYSILENT = No progress window (Invisible)
      // /SUPPRESSMSGBOXES = No error/info boxes
      // /NORESTART = Don't restart system automatically
      await Process.start(
        filePath,
        ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
        mode: ProcessStartMode.detached,
      );
    } else if (Platform.isMacOS) {
      // macOS: Open DMG or ZIP
      if (filePath.endsWith('.dmg')) {
        await Process.start('open', [filePath],
            mode: ProcessStartMode.detached);
      } else if (filePath.endsWith('.zip')) {
        // Unzip and open
        await Process.start('open', [filePath],
            mode: ProcessStartMode.detached);
      }
    } else if (Platform.isIOS) {
      // iOS: User needs to install via AltStore/Sideloadly
      progressNotifier.value = DownloadProgress(
        receivedMB: 0,
        totalMB: 0,
        progress: 1.0,
        status: "IPA downloaded! Open in AltStore to install.",
      );

      debugPrint("IPA downloaded to: $filePath");
      debugPrint("iOS: User must install via AltStore, Sideloadly, or similar tool");

      // Keep message visible for a few seconds
      await Future.delayed(const Duration(seconds: 3));
      progressNotifier.value = null;

      // Don't exit app on iOS
      return;
    } else {
      // Linux: Open AppImage or other
      await Process.start(
        filePath,
        [],
        mode: ProcessStartMode.detached,
      );
    }

    // CLEANUP & EXIT for Desktop
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Clear markers before exiting so they don't block future update checks
      await _clearPendingUpdate();
      await _markFileForCleanup(filePath);
      
      debugPrint("Update process handed off to system. Exiting app.");
      await Future.delayed(const Duration(milliseconds: 200));
      exit(0);
    }
  }

  /// Opens the APK file with the system package installer
  Future<bool> _openApkForInstall(String filePath) async {
    if (!Platform.isAndroid) return false;

    try {
      // Explicitly check for Install Unknown Apps permission (Android 8+)
      // This gives a better heads-up if the user is about to be sent to Settings.
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        debugPrint("⚠️ Install Unknown Apps permission not granted.");
        // We still call OpenFilex because it triggers the Android Intent to the settings page!
      }

      // Use open_filex to open the APK
      // This triggers the Android package installer dialog
      final result = await OpenFilex.open(filePath);
      debugPrint("OpenFilex result: ${result.type} - ${result.message}");
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint("Error opening APK: $e");
      return false;
    }
  }

  /// Marks a file path for cleanup after the app restarts
  Future<void> _markFileForCleanup(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_cleanup_file', filePath);
      debugPrint("Marked for cleanup: $filePath");
    } catch (e) {
      debugPrint("Error marking for cleanup: $e");
    }
  }

  // PENDING UPDATE PERSISTENCE
  Future<void> _markPendingUpdate(String filePath, String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_update_apk', filePath);
    await prefs.setString('pending_update_version', version);
    debugPrint("Marked pending update APK: $filePath, version: $version");
  }

  Future<void> _clearPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_update_apk');
    await prefs.remove('pending_update_version');
    debugPrint("Cleared pending update APK and version markers.");
  }

  Future<void> clearPendingUpdate() async {
    await _clearPendingUpdate();
  }

  Future<String?> getPendingUpdatePath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('pending_update_apk');
    if (path != null && File(path).existsSync()) {
      return path;
    }
    return null;
  }

  /// Triggers the external installer for an existing file
  Future<void> installExistingApk(String filePath) async {
    debugPrint("Resuming installation of: $filePath");
    await _finishInstallation(
      // Mocked components
      _DummyIOSink(),
      http.Client(),
      filePath, 
    );
  }

  /// Call this on app startup to clean up old update files
  /// This frees up space after a successful update
  static Future<void> cleanupOldUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Clean up explicitly marked files
      final pendingFile = prefs.getString('pending_cleanup_file');
      if (pendingFile != null && pendingFile.isNotEmpty) {
        final file = File(pendingFile);
        if (await file.exists()) {
          try {
            await file.delete();
            debugPrint("🗑️ Cleaned up old update file: $pendingFile");
          } catch (e) {
            debugPrint("⚠️ Could not delete old update file (might be in use): $e");
          }
        }
        await prefs.remove('pending_cleanup_file');
      }

      // 2. Check if we have a pending update and compare version
      final pendingVersion = prefs.getString('pending_update_version');
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (pendingVersion != null) {
        // If current version is equal or newer, the update was successful!
        if (!_isNewer(pendingVersion, currentVersion)) {
          final pendingUpdate = prefs.getString('pending_update_apk');
          if (pendingUpdate != null && pendingUpdate.isNotEmpty) {
            final file = File(pendingUpdate);
            if (await file.exists()) {
              try {
                await file.delete();
                debugPrint("🗑️ Cleaned up successful update installer: $pendingUpdate");
              } catch (e) {
                debugPrint("⚠️ Could not delete installer: $e");
              }
            }
            await prefs.remove('pending_update_apk');
          }
          await prefs.remove('pending_update_version');
        }
      }

      // 3. Desktop fallback: If we are starting up on desktop, always clear pending update apk
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final pendingUpdate = prefs.getString('pending_update_apk');
        if (pendingUpdate != null && pendingUpdate.isNotEmpty) {
          final file = File(pendingUpdate);
          if (await file.exists()) {
            try {
              await file.delete();
              debugPrint("🗑️ Cleaned up stale desktop installer: $pendingUpdate");
            } catch (e) {
               debugPrint("⚠️ Could not delete stale installer (might be in use): $e");
            }
          }
          await prefs.remove('pending_update_apk');
          await prefs.remove('pending_update_version');
        }
      }
    } catch (e) {
      debugPrint("Error cleaning up old updates: $e");
    }
  }
}

// Helper to call _finishInstallation with existing file
class _DummyIOSink implements IOSink {
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream<List<int>> stream) async {}
  @override
  Future close() async {}
  @override
  get done => Future.value();
  @override
  Future flush() async {}
  @override
  void write(Object? object) {}
  @override
  void writeAll(Iterable objects, [String separator = ""]) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? object = ""]) {}
  @override
  set encoding(Encoding encoding) {}
  @override
  Encoding get encoding => utf8;
}

// DownloadProgress class moved to models/download_progress.dart
