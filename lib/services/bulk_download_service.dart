import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/song_model.dart';
import '../models/song_metadata.dart';
import '../models/download_progress.dart';
import 'smart_download_service.dart';
import 'youtube_downloader_service.dart';
import 'metrics_service.dart';

class BulkDownloadService {
  static final BulkDownloadService _instance = BulkDownloadService._internal();

  factory BulkDownloadService() {
    return _instance;
  }

  BulkDownloadService._internal();

  final SmartDownloadService _smartService = SmartDownloadService();
  final YoutubeDownloaderService _ytService = YoutubeDownloaderService();

  // Notifier for UI
  final ValueNotifier<DownloadProgress?> progressNotifier = ValueNotifier(null);

  bool _isDownloading = false;

  Future<void> downloadAlbum(String albumTitle, List<SongModel> songs,
      {String? coverUrl}) async {
    if (_isDownloading) {
      print("⚠️ Bulk Download already in progress");
      return;
    }

    _isDownloading = true;
    int total = songs.length;
    int completed = 0;

    try {
      // 1. Get Base Directory: downloads/SimpleMusicDownloads/playlists/{Album Title}
      final baseDir = await _getAlbumDownloadDirectory(albumTitle);
      if (baseDir == null) {
        print("❌ Could not get download directory");
        _isDownloading = false;
        return;
      }

      print("📂 Downloading to: ${baseDir.path}");

      for (var i = 0; i < songs.length; i++) {
        final song = songs[i];

        // 🛑 CHECK QUOTA
        final canDownload = await MetricsService().canDownload();
        if (!canDownload) {
          print("⛔ Daily download limit reached. Stopping bulk download.");
          _updateProgress(completed, total, "Limit Reached");
          break;
        }

        // Update Progress: "Downloading... (x/total)"
        _updateProgress(completed, total, "Downloading...");

        // 2. Prepare Metadata
        // Use provided coverUrl if song's art is missing, or prefer coverUrl for uniformity in album dl
        final artUrl = (coverUrl != null && coverUrl.isNotEmpty)
            ? coverUrl
            : (song.onlineArtUrl ?? "");

        final metadata = SongMetadata(
            title: song.title,
            artist: song.artist,
            album: song.album,
            albumArtUrl: artUrl,
            durationSeconds: song.duration.toInt(),
            isrc: song.isrc,
            year: song.year, // Allow empty/null
            genre: song.genre, // Allow empty/null
            trackNumber:
                song.trackNumber ?? (i + 1), // Use model data or loop index
            discNumber: song.discNumber ?? 1 // Use model data or default
            );

        // 3. Search / Match
        final debugResult = await _smartService.searchYouTubeForMatch(metadata);

        if (debugResult != null && debugResult.youtubeMatches.isNotEmpty) {
          // Best match logic (simplify for now, take top result or similar duration)
          var match = debugResult.youtubeMatches.first;
          // If we have multiple, try to find closest duration
          if (debugResult.youtubeMatches.length > 1) {
            match = debugResult.youtubeMatches.firstWhere((m) {
              final parts = m.duration.split(':');
              int seconds = 0;
              if (parts.length == 2) {
                seconds = int.parse(parts[0]) * 60 + int.parse(parts[1]);
              }
              return (seconds - metadata.durationSeconds).abs() < 10;
            }, orElse: () => debugResult.youtubeMatches.first);
          }

          final videoUrl = match.url;

          // 4. Download
          // 🚀 USE GENERATED FILENAME (Configurable)
          final filename = await _smartService.generateFilename(metadata,
              patternKey: 'playlist_filename_pattern');

          final filePath = "${baseDir.path}/$filename.m4a";

          bool success = false;
          try {
            await _downloadWrapper(videoUrl, filePath);
            success = true;
          } catch (e) {
            print("❌ Failed to download ${song.title}: $e");
          }

          if (success) {
            // Wait for file handle release (Critical for Windows)
            await Future.delayed(const Duration(milliseconds: 500));

            // 5. Tag
            await _smartService.tagFile(filePath: filePath, metadata: metadata);

            // 6. 🛑 TRACK USAGE
            await MetricsService().trackDownloadMetadata(metadata);
          }
        } else {
          print("⚠️ No match found for ${song.title}");
        }

        completed++;
        _updateProgress(completed, total, "Downloading...");
      }

      _updateProgress(total, total, "Completed");
      // Clear after a delay
      await Future.delayed(const Duration(seconds: 3));
      progressNotifier.value = null;
    } catch (e) {
      print("❌ Bulk Download Error: $e");
      progressNotifier.value = null;
    } finally {
      _isDownloading = false;
    }
  }

  Future<void> _downloadWrapper(String url, String path) async {
    final completer = Completer<void>();

    await _ytService.startDownloadFromUrl(
        youtubeUrl: url,
        outputFilePath: path,
        audioFormat: 'm4a', // 🚀 FORCE ENC M4A
        onProgress: (p) {},
        onComplete: (s) {
          if (!completer.isCompleted) completer.complete();
        });

    return completer.future;
  }

  void _updateProgress(int completed, int total, String status) {
    double p = total > 0 ? completed / total : 0;
    progressNotifier.value = DownloadProgress(
        receivedMB: 0, // Not relevant
        totalMB: 0, // Not relevant
        progress: p,
        status: status,
        details: "$completed / $total Songs Downloaded");
  }

  Future<Directory?> _getAlbumDownloadDirectory(String albumTitle) async {
    // downloads/SimpleMusicDownloads/playlists/{Album Title}
    // We reuse logic from YoutubeDownloaderService to get "SimpleMusicDownloads"

    // Or just manually:
    Directory? downloadDir;
    if (Platform.isAndroid || Platform.isIOS) {
      /* Mobile logic if needed */
      // Assuming YoutubeDownloaderService handles permission, but we need it here to get path.
      if (await Permission.storage.request().isDenied) {
        return null;
      }
      downloadDir = await getDownloadsDirectory();
    } else {
      downloadDir = await getDownloadsDirectory();
    }

    if (downloadDir == null) return null;

    final base =
        Directory("${downloadDir.path}/SimpleMusicDownloads/playlists");
    if (!await base.exists()) {
      await base.create(recursive: true);
    }

    final safeAlbum = albumTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final albumDir = Directory("${base.path}/$safeAlbum");

    if (!await albumDir.exists()) {
      await albumDir.create(recursive: true);
    }

    return albumDir;
  }
}
