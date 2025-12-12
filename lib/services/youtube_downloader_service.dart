import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/youtube_search_result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;

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

      return '${cacheDir.path}/$truncatedName.mp3';
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

    if (Platform.isAndroid || Platform.isIOS) {
      if (await Permission.storage.request().isDenied) {
        return null;
      }
    }

    Directory? dir = await getDownloadsDirectory();
    if (dir == null) return null;

    final outputDir = Directory('${dir.path}/SimpleMusicDownloads');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    return '${outputDir.path}/$safeName.$ext';
  }

  // --- Search Function ---
  Future<List<YoutubeSearchResult>> searchVideo(String query) async {
    if (!_isInitialized) return [];

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

  // --- Mobile Implementation (Dart Only) ---
  Future<void> _downloadMobile(
    String videoUrl,
    String savePath,
    Function(double) onProgress,
    Function(bool) onComplete,
    String expectedFormat,
  ) async {
    final yt = yt_explode.YoutubeExplode();
    try {
      // 1. Get ID
      var videoId = yt_explode.VideoId.parseVideoId(videoUrl);
      if (videoId == null) throw "Invalid Video URL";

      // 2. Get Manifest
      var manifest = await yt.videos.streamsClient.getManifest(videoId);

      // 3. Get Audio Stream (M4A/AAC preferred for mobile native play)
      var streamInfo = manifest.audioOnly.withHighestBitrate();

      // Note: We ignore 'expectedFormat' (mp3) on mobile because we can't convert.
      // We just download the best audio available (usually m4a/webm).
      // The player handles m4a fine.

      var stream = yt.videos.streamsClient.get(streamInfo);

      // 4. Download File
      var file = File(savePath);
      var fileSink = file.openWrite();

      var len = streamInfo.size.totalBytes;
      var count = 0;

      await stream.listen((data) {
        count += data.length;
        fileSink.add(data);
        if (len > 0) {
          onProgress((count / len).clamp(0.0, 1.0));
        }
      }).asFuture();

      await fileSink.flush();
      await fileSink.close();

      onComplete(true);
    } catch (e) {
      print("📱 Mobile DL Error: $e"); // ALWAYS PRINT
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
