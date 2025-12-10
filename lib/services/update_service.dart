import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/download_progress.dart';

class UpdateService {
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
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      print("Checking for updates... Current version: $currentVersion");

      final response = await http.get(Uri.parse(_releasesUrl));

      if (response.statusCode == 200) {
        final List releases = json.decode(response.body);
        if (releases.isEmpty) {
          print("No releases found.");
          return null;
        }

        // Get the most recent release (first in list)
        // This includes Pre-releases if they are the most recent!
        final releaseData = releases.first as Map<String, dynamic>;

        final String tagName = releaseData['tag_name'];
        // Remove 'v' prefix if present
        final latestVersion = tagName.replaceAll('v', '');

        if (_isNewer(latestVersion, currentVersion)) {
          print("Update available: $latestVersion");
          return releaseData;
        } else {
          print("App is up to date.");
        }
      } else {
        print("Failed to check for updates: ${response.statusCode}");
      }
    } catch (e) {
      print("Error checking for updates: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> getLatestRelease() async {
    try {
      final response = await http.get(Uri.parse(_releasesUrl));
      if (response.statusCode == 200) {
        final List releases = json.decode(response.body);
        if (releases.isNotEmpty) {
          return releases.first as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print("Error fetching latest release: $e");
    }
    return null;
  }

  /// Compares two version strings (e.g., "1.0.1" vs "1.0.0").
  bool _isNewer(String latest, String current) {
    List<int> l = latest.split('.').map(int.parse).toList();
    List<int> c = current.split('.').map(int.parse).toList();

    for (int i = 0; i < l.length && i < c.length; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    // If we are here, versions are equal so far.
    // If latest has more parts (e.g. 1.0.1 vs 1.0), it's newer.
    return l.length > c.length;
  }

  /// Downloads the installer asset and executes it.
  Future<void> downloadAndInstall(String downloadUrl, String fileName) async {
    try {
      print("Downloading update from: $downloadUrl");

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

              // If finished, show Installing immediately
              final status =
                  progress >= 1.0 ? "Installing..." : "Downloading Update...";

              progressNotifier.value = DownloadProgress(
                receivedMB: receivedMB,
                totalMB: totalMB,
                progress: progress,
                status: status,
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
      } else {
        print("Failed to download update: ${response.statusCode}");
        throw Exception("Failed to download update");
      }
    } catch (e) {
      print("Error downloading/installing update: $e");
      progressNotifier.value = null;
      rethrow;
    }
  }

  Future<void> _finishInstallation(
      IOSink sink, http.Client client, String filePath) async {
    await sink.flush();
    await sink.close();
    client.close();

    print("Download complete. Executing installer: $filePath");

    // Give UI a moment to show "Installing..." if it hasn't yet
    await Future.delayed(const Duration(milliseconds: 500));

    // Run the installer (Silent if Windows)
    if (Platform.isWindows) {
      // Inno Setup flags:
      // /VERYSILENT = No progress window (Invisible)
      // /SUPPRESSMSGBOXES = No error/info boxes
      // /NORESTART = Don't restart system automatically
      await Process.start(
        filePath,
        ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
        mode: ProcessStartMode.detached,
      );
    } else {
      // macOS/Linux: Just open it
      await Process.start(
        filePath,
        [],
        mode: ProcessStartMode.detached,
      );
    }

    // Exit the app so the installer can replace files
    exit(0);
  }
}

// DownloadProgress class moved to models/download_progress.dart
