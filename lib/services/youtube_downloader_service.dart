import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Full import for MethodChannel
import 'package:path_provider/path_provider.dart';

import '../models/youtube_search_result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;
import 'debug_log_service.dart';

class YoutubeDownloaderService {
  static final YoutubeDownloaderService _instance =
      YoutubeDownloaderService._internal();

  factory YoutubeDownloaderService() {
    return _instance;
  }

  YoutubeDownloaderService._internal();

  // We need paths for all 3 binaries
  late String _ytDlpPath;
  late String _ffmpegPath;
  late String _ffprobePath;

  bool _isInitialized = false;

  // 🚀 Native yt-dlp for Android (via MethodChannel)
  static const _nativeChannel =
      MethodChannel('com.momotz4g.simplemusicplayer2/ytdlp');
  static bool _nativeInitialized = false;

  // --- Utility ---
  String _formatDuration(dynamic seconds) {
    if (seconds == null || seconds is! int) return '0:00';
    final d = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return d.inHours > 0
        ? "${d.inHours}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigitSeconds}"
        : "${d.inMinutes}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  // --- CROSS-PLATFORM INITIALIZATION ---
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 🚀 Mobile: Initialize native yt-dlp
    if (Platform.isAndroid || Platform.isIOS) {
      await _initializeNative();
      _isInitialized = true;
      print(
          "✅ Downloader Initialized for ${Platform.operatingSystem} (Native yt-dlp)");
      return;
    }

    // Desktop: Initialize bundled binaries
    final appDir = await getApplicationSupportDirectory();
    final binDir = Directory('${appDir.path}/bin');

    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }

    // 1. Define the files we need to copy
    final binaries = ['yt-dlp', 'ffmpeg', 'ffprobe'];

    for (var binary in binaries) {
      // Get the platform-specific asset name (e.g. "ffmpeg_macos")
      final assetName = _getAssetName(binary);

      // Get the destination name (e.g. "ffmpeg" or "ffmpeg.exe")
      final fileName = _getExecutableName(binary);
      final file = File('${binDir.path}/$fileName');

      // Copy from assets to app directory if not exists
      if (!await file.exists()) {
        try {
          final byteData = await rootBundle.load('assets/binaries/$assetName');
          await file.writeAsBytes(byteData.buffer
              .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

          // CRITICAL FOR MAC/LINUX: Make executable
          if (!Platform.isWindows) {
            await Process.run('chmod', ['+x', file.path]);
          }

          if (kDebugMode) print('Copied $assetName to ${file.path}');
        } catch (e) {
          print("Error copying binary $binary: $e");
        }
      }
    }

    // Set paths for later use
    _ytDlpPath = '${binDir.path}/${_getExecutableName('yt-dlp')}';
    _ffmpegPath = '${binDir.path}/${_getExecutableName('ffmpeg')}';
    _ffprobePath = '${binDir.path}/${_getExecutableName('ffprobe')}';

    _isInitialized = true;
    print("✅ Downloader Initialized for ${Platform.operatingSystem}");
  }

  // 🚀 Initialize native yt-dlp on Android/iOS
  Future<void> _initializeNative() async {
    if (_nativeInitialized) return;
    final debug = DebugLogService();
    try {
      debug.info("📱 Initializing native yt-dlp...");
      await _nativeChannel.invokeMethod('initialize');
      _nativeInitialized = true;
      debug.success("📱 Native yt-dlp initialized successfully!");
    } catch (e) {
      debug.error("📱 Native yt-dlp init failed: $e");
      // Don't throw - allow fallback to youtube_explode
    }
  }

  // Helper: Get the name of the file inside assets/binaries/
  String _getAssetName(String base) {
    if (Platform.isWindows) return '$base.exe';
    if (Platform.isMacOS) return '${base}_macos';
    if (Platform.isLinux) return '${base}_linux';
    return base;
  }

  // Helper: Get the name of the file on the disk
  String _getExecutableName(String base) {
    if (Platform.isWindows) return '$base.exe';
    return base; // Mac/Linux don't use .exe
  }

  // --- Cache Path ---
  Future<String?> getCachePath(String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/SimpleMusicCache');

      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final truncatedName =
          safeName.length > 50 ? safeName.substring(0, 50) : safeName;

      // 🚀 FIX: Mobile downloads M4A/AAC audio (no ffmpeg conversion)
      // Desktop uses MP3 (converted by ffmpeg via yt-dlp)
      final ext = (Platform.isAndroid || Platform.isIOS) ? 'm4a' : 'mp3';
      return '${cacheDir.path}/$truncatedName.$ext';
    } catch (e) {
      if (kDebugMode) print("Error getting cache path: $e");
      return null;
    }
  }

  // --- Download Path ---
  Future<String?> getDownloadPath(String fileName, {String ext = 'mp3'}) async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('custom_download_path');

    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    if (customPath != null) {
      final dir = Directory(customPath);
      if (await dir.exists()) {
        return '${dir.path}/$safeName.$ext';
      }
    }

    String? basePath;

    if (Platform.isAndroid) {
      // 🚀 FIX: Use public Download directory on Android
      // /storage/emulated/0/Download/SimpleMusicDownloads
      print("📱 Android: Getting download path...");

      try {
        // This usually returns /storage/emulated/0/Android/data/.../files
        // We want /storage/emulated/0/Download
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navigate up to root /storage/emulated/0/
          // Typical path: /storage/emulated/0/Android/data/com.example.../files
          // We want to construct: /storage/emulated/0/Download

          // Simple heuristic: Use the standard path directly if possible, or derive from externalDir
          final updatePath = Directory("/storage/emulated/0/Download");
          if (await updatePath.exists()) {
            basePath = updatePath.path;
            print("📱 Android: Using public Download directory: $basePath");
          } else {
            // Fallback logic if hardcoded path fails (unlikely on standard Android)
            // Try to find "Android" segment and slice
            final path = externalDir.path;
            final androidIndex = path.indexOf("/Android/");
            if (androidIndex != -1) {
              basePath = "${path.substring(0, androidIndex)}/Download";
              print("📱 Android: Derived public Download directory: $basePath");
            } else {
              basePath = externalDir.path; // Fallback to app-specific
              print(
                  "📱 Android: Could not derive public path, using app storage: $basePath");
            }
          }
        } else {
          print("📱 Android: getExternalStorageDirectory returned null");
        }
      } catch (e) {
        print("⛔ Android: Error getting external storage: $e");
      }

      // Fallback to app documents directory if all else fails
      if (basePath == null) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          basePath = appDocDir.path;
        } catch (e) {
          print("⛔ Android: Error getting app documents: $e");
        }
      }
    } else if (Platform.isIOS) {
      // iOS uses app documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      basePath = appDocDir.path;
    } else {
      // Desktop: Use Downloads directory
      Directory? dir = await getDownloadsDirectory();
      if (dir != null) {
        basePath = dir.path;
      }
    }

    if (basePath == null) {
      print("⛔ Could not resolve downloads directory.");
      return null;
    }

    final outputDir = Directory('$basePath/SimpleMusicDownloads');
    try {
      if (!await outputDir.exists()) {
        print("📂 Creating directory: ${outputDir.path}");
        await outputDir.create(recursive: true);
      }
      return '${outputDir.path}/$safeName.$ext';
    } catch (e) {
      print("⛔ Error creating directory: $e");
      // Fallback: Just use the base folder if subfolder creation fails
      return '$basePath/$safeName.$ext';
    }
  }

  // --- Search Function ---
  Future<List<YoutubeSearchResult>> searchVideo(String query) async {
    if (!_isInitialized) return [];

    // 🚀 Mobile Fallback: Use YoutubeExplode
    if (Platform.isAndroid || Platform.isIOS) {
      return await _searchMobile(query);
    }

    // Desktop: Use yt-dlp
    final args = [
      '--print',
      '%(title)s:::%(id)s:::%(uploader)s:::%(duration)s:::%(thumbnail)s',
      '--flat-playlist',
      'ytsearch10:$query',
    ];

    try {
      final result = await Process.run(_ytDlpPath, args, runInShell: true);

      if (result.exitCode != 0) {
        if (kDebugMode) print("Search Error: ${result.stderr}");
        return [];
      }

      final List<YoutubeSearchResult> searchResults = [];
      final lines = LineSplitter.split(result.stdout.toString());

      for (var line in lines) {
        final parts = line.split(':::');
        if (parts.length >= 5) {
          String durationStr = "0:00";
          try {
            double seconds = double.parse(parts[3]);
            durationStr = _formatDuration(seconds.toInt());
          } catch (e) {
            durationStr = parts[3];
          }

          searchResults.add(YoutubeSearchResult(
            title: parts[0],
            url: "https://www.youtube.com/watch?v=${parts[1]}",
            artist: parts[2],
            duration: durationStr,
            thumbnailUrl: parts[4],
          ));
        }
      }
      return searchResults;
    } catch (e) {
      if (kDebugMode) print("Search Exception: $e");
      return [];
    }
  }

  // 🚀 Mobile Search Implementation (YoutubeExplode)
  Future<List<YoutubeSearchResult>> _searchMobile(String query) async {
    try {
      final yt = yt_explode.YoutubeExplode();
      final results = await yt.search.search(query);
      yt.close();

      return results.map((video) {
        return YoutubeSearchResult(
          title: video.title,
          url: "https://www.youtube.com/watch?v=${video.id}",
          artist: video.author,
          duration: _formatDuration(video.duration?.inSeconds ?? 0),
          thumbnailUrl: video.thumbnails.highResUrl,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) print("📱 Mobile Search Error: $e");
      return [];
    }
  }

  // --- Download Function ---
  // --- Hybrid Download Function ---
  Future<void> startDownloadFromUrl({
    required String youtubeUrl,
    required String outputFilePath,
    required Function(double progress) onProgress,
    required Function(bool success) onComplete,
    String audioFormat = 'mp3',
  }) async {
    // 1. MOBILE (Android/iOS): Native Dart Download (YoutubeExplode)
    if (Platform.isAndroid || Platform.isIOS) {
      await _downloadMobile(
          youtubeUrl, outputFilePath, onProgress, onComplete, audioFormat);
      return;
    }

    // 2. DESKTOP (Win/Mac/Linux): yt-dlp + ffmpeg
    if (!_isInitialized) {
      onComplete(false);
      return;
    }
    await _downloadDesktop(
        youtubeUrl, outputFilePath, onProgress, onComplete, audioFormat);
  }

  // --- Mobile Implementation (Native yt-dlp via MethodChannel) ---
  // Uses youtubedl-android for reliable YouTube audio extraction
  Future<void> _downloadMobile(
    String videoUrl,
    String savePath,
    Function(double) onProgress,
    Function(bool) onComplete,
    String expectedFormat,
  ) async {
    final debug = DebugLogService();
    debug.info("📱 Starting download via Native yt-dlp...");
    debug.info("📱 URL: $videoUrl");
    debug.info("📱 Save Path: $savePath");

    try {
      // 1. Ensure native yt-dlp is initialized
      if (!_nativeInitialized) {
        debug.info("📱 Initializing native yt-dlp...");
        await _initializeNative();
      }

      if (!_nativeInitialized) {
        debug.error(
            "📱 Native yt-dlp not available, falling back to youtube_explode");
        await _downloadMobileFallback(
            videoUrl, savePath, onProgress, onComplete, expectedFormat);
        return;
      }

      // 2. Create parent directory if needed
      debug.info("📱 Preparing output directory...");
      var file = File(savePath);
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
        debug.info("📱 Created directory: ${parentDir.path}");
      }

      if (await file.exists()) {
        await file.delete();
        debug.info("📱 Deleted existing file");
      }

      // 3. Download via native yt-dlp
      debug.info("📱 Calling native yt-dlp download...");
      onProgress(0.1); // Show some initial progress

      final result = await _nativeChannel.invokeMethod('download', {
        'url': videoUrl,
        'filePath': savePath,
      });

      debug.info("📱 Native download result: $result");
      onProgress(1.0);

      // 4. Verify file was created
      // yt-dlp may add extension, so check for either exact path or with extension
      File? downloadedFile;
      if (await file.exists()) {
        downloadedFile = file;
      } else {
        // Check for common audio extensions yt-dlp might use
        for (var ext in ['m4a', 'mp3', 'webm', 'opus']) {
          final altPath = savePath.replaceAll(RegExp(r'\.[^.]+$'), '.$ext');
          final altFile = File(altPath);
          if (await altFile.exists()) {
            downloadedFile = altFile;
            break;
          }
        }
        // Also check if yt-dlp added an extension to a path without one
        for (var ext in ['m4a', 'mp3', 'webm', 'opus']) {
          final altFile = File('$savePath.$ext');
          if (await altFile.exists()) {
            downloadedFile = altFile;
            break;
          }
        }
      }

      if (downloadedFile != null && await downloadedFile.exists()) {
        final fileSize = await downloadedFile.length();
        debug.info(
            "📱 File created: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB at ${downloadedFile.path}");

        if (fileSize < 1000) {
          debug.error(
              "📱 ❌ File too small ($fileSize bytes), download likely failed!");
          await downloadedFile.delete();
          onComplete(false);
        } else {
          // Rename to expected path if different
          if (downloadedFile.path != savePath) {
            debug.info("📱 Renaming ${downloadedFile.path} to $savePath");
            await downloadedFile.rename(savePath);
          }
          debug.success("📱 ✅ Native yt-dlp Download Success!");
          onComplete(true);
        }
      } else {
        debug.error("📱 ❌ File was not created!");
        onComplete(false);
      }
    } on PlatformException catch (e) {
      debug.error("📱 Native yt-dlp error: ${e.message}");
      debug.warning("📱 Falling back to youtube_explode...");

      // Fallback to youtube_explode on native error
      await _downloadMobileFallback(
          videoUrl, savePath, onProgress, onComplete, expectedFormat);
    } catch (e, stackTrace) {
      debug.error("📱 Mobile DL Error: $e");
      debug.error(
          "📱 Stack: ${stackTrace.toString().split('\n').take(3).join(' | ')}");

      // Clean up partial file
      try {
        var file = File(savePath);
        if (await file.exists()) {
          final size = await file.length();
          debug.warning("📱 Cleaning up partial file ($size bytes)");
          await file.delete();
        }
      } catch (_) {}

      onComplete(false);
    }
  }

  // --- Fallback: youtube_explode (if native yt-dlp fails) ---
  Future<void> _downloadMobileFallback(
    String videoUrl,
    String savePath,
    Function(double) onProgress,
    Function(bool) onComplete,
    String expectedFormat,
  ) async {
    final debug = DebugLogService();
    debug.info("📱 [Fallback] Starting download via YoutubeExplode...");

    var yt = yt_explode.YoutubeExplode();
    IOSink? output;

    try {
      var videoId = yt_explode.VideoId(videoUrl);
      debug.info("📱 [Fallback] Video ID: ${videoId.value}");

      yt_explode.StreamManifest manifest;
      try {
        manifest = await yt.videos.streamsClient.getManifest(videoId).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception(
                "Timeout: Failed to get stream manifest after 30 seconds");
          },
        );
      } catch (e) {
        debug.error("📱 [Fallback] Manifest Error: $e");
        rethrow;
      }

      var audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) {
        throw Exception("No audio streams available for this video");
      }

      var m4aStreams = audioStreams
          .where((s) => s.container.toString().toLowerCase().contains('mp4'));
      var streamInfo = m4aStreams.isNotEmpty
          ? m4aStreams.withHighestBitrate()
          : audioStreams.withHighestBitrate();

      debug.info(
          "📱 [Fallback] Selected: ${streamInfo.container} @ ${streamInfo.bitrate.kiloBitsPerSecond}kbps");

      var file = File(savePath);
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      if (await file.exists()) {
        await file.delete();
      }
      output = file.openWrite();

      var len = streamInfo.size.totalBytes;
      var count = 0;

      var stream = yt.videos.streamsClient.get(streamInfo);
      bool firstChunkReceived = false;

      await for (var chunk in stream.timeout(
        const Duration(seconds: 30),
        onTimeout: (sink) {
          if (!firstChunkReceived) {
            throw Exception(
                "Stream timeout: YouTube CDN blocked or unreachable");
          } else {
            sink.close();
          }
        },
      )) {
        firstChunkReceived = true;
        count += chunk.length;
        output.add(chunk);
        onProgress((count / len).clamp(0.0, 1.0));
      }

      if (!firstChunkReceived) {
        throw Exception("No data received from YouTube stream");
      }

      await output.flush();
      await output.close();
      output = null;

      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize < 1000) {
          await file.delete();
          onComplete(false);
        } else {
          debug.success("📱 [Fallback] ✅ Download Success!");
          onComplete(true);
        }
      } else {
        onComplete(false);
      }
    } catch (e) {
      debug.error("📱 [Fallback] Error: $e");
      if (output != null) {
        try {
          await output.close();
        } catch (_) {}
      }
      try {
        var file = File(savePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      onComplete(false);
    } finally {
      yt.close();
    }
  }

  // --- Desktop Implementation (yt-dlp) ---
  Future<void> _downloadDesktop(
    String youtubeUrl,
    String outputFilePath,
    Function(double) onProgress,
    Function(bool) onComplete,
    String audioFormat,
  ) async {
    // SINGLE SHOT COMPLETION: Ensure we only call onComplete once
    bool hasCompleted = false;
    void safeComplete(bool success) {
      if (!hasCompleted) {
        hasCompleted = true;
        onComplete(success);
      }
    }

    final args = [
      '-x',
      '--no-playlist',
      '--extractor-args', 'youtube:player_client=default',
      '--audio-format', audioFormat,
      '--audio-quality', '0',
      '--force-overwrites',

      // TELL YTDLP WHERE FFMPEG IS
      '--ffmpeg-location', File(_ffmpegPath).parent.path,

      '--output', outputFilePath,
      '--no-part', // Write directly to file (easier for file watcher)
      youtubeUrl,
    ];

    try {
      final process = await Process.start(_ytDlpPath, args, runInShell: true);

      // Handle Stdout (Progress) safely
      process.stdout.transform(utf8.decoder).listen(
        (data) {
          try {
            final progressMatch =
                RegExp(r'\[download\]\s+(\d+\.\d+)%').firstMatch(data);
            if (progressMatch != null) {
              double progress = double.parse(progressMatch.group(1)!) / 100.0;
              onProgress(progress.clamp(0.0, 1.0));
            }
          } catch (_) {
            // Ignore parsing errors
          }
        },
        onError: (e) {
          if (kDebugMode) print("Stdout stream error: $e");
        },
        cancelOnError: false,
      );

      // Handle Stderr (Errors) safely
      process.stderr.transform(utf8.decoder).listen(
        (data) {
          if (!data.contains('[download]') &&
              !data.contains('[ExtractAudio]')) {
            print('❌ YTDLP ERR: $data'); // ALWAYS PRINT
          }
        },
        onError: (e) {
          if (kDebugMode) print("Stderr stream error: $e");
        },
        cancelOnError: false,
      );

      // Wait for process exit
      int exitCode = -1;
      try {
        exitCode = await process.exitCode;
      } catch (e) {
        if (kDebugMode) print("Process exitCode error: $e");
        safeComplete(false);
        return;
      }

      if (exitCode == 0) {
        final file = File(outputFilePath);
        if (await file.exists()) {
          safeComplete(true);
        } else {
          safeComplete(false);
        }
      } else {
        safeComplete(false);
      }
    } catch (e) {
      if (kDebugMode) print('FATAL YTDLP Process Error: $e');
      safeComplete(false);
    }
  }

  // --- Cache Management ---
  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/SimpleMusicCache');
      if (await cacheDir.exists()) {
        final List<FileSystemEntity> files = cacheDir.listSync();
        for (var file in files) {
          if (file is File) {
            try {
              await file.delete();
            } catch (e) {
              if (kDebugMode) print("Skipping locked file: ${file.path}");
            }
          }
        }
        if (kDebugMode) print("🗑️ Cache Cleared!");
      }
    } catch (e) {
      if (kDebugMode) print("Error clearing cache: $e");
    }
  }

  Future<String> getCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/SimpleMusicCache');
      if (!await cacheDir.exists()) return "0 MB";

      int totalSize = 0;
      await for (var file
          in cacheDir.list(recursive: true, followLinks: false)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return "${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB";
    } catch (e) {
      return "0 MB";
    }
  }
}
