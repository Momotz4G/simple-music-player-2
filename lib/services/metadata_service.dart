import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:metadata_god/metadata_god.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:isolate';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'audio_info_service.dart';

/// A heavily supervised metadata reader.
/// Uses `MetadataGod`'s Rust core for FFI speed, but wraps every chunk in a perfectly sandboxed
/// Isolate that is forcefully terminated if the C++ thread deadlocks or infinite loops
/// on malformed unicode paths/headers, completely preventing "Not Responding" UI halts.
class MetadataService {
  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;
  MetadataService._internal();

  bool _isInitialized = false;

  // Concurrency limiter for heavy ffmpeg art extractions
  static const int _maxConcurrentArtExtractions = 3;
  static int _activeArtExtractions = 0;
  static final List<Completer<void>> _artQueue = [];

  static Future<void> _acquireArtSlot() async {
    if (_activeArtExtractions < _maxConcurrentArtExtractions) {
      _activeArtExtractions++;
      return;
    }
    final completer = Completer<void>();
    _artQueue.add(completer);
    await completer.future;
  }

  static void _releaseArtSlot() {
    if (_artQueue.isNotEmpty) {
      final next = _artQueue.removeAt(0);
      next.complete();
    } else {
      _activeArtExtractions--;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      try {
        await MetadataGod.initialize();
        _isInitialized = true;
      } catch (_) {}
    }
  }

  Metadata _cleanMetadata(Metadata meta) {
    return Metadata(
      title: meta.title != null ? fixMojibake(meta.title!) : null,
      artist: meta.artist != null ? fixMojibake(meta.artist!) : null,
      album: meta.album != null ? fixMojibake(meta.album!) : null,
      albumArtist: meta.albumArtist != null ? fixMojibake(meta.albumArtist!) : null,
      genre: meta.genre != null ? fixMojibake(meta.genre!) : null,
      durationMs: meta.durationMs,
      trackNumber: meta.trackNumber,
      trackTotal: meta.trackTotal,
      discNumber: meta.discNumber,
      discTotal: meta.discTotal,
      year: meta.year,
      fileSize: meta.fileSize,
      picture: meta.picture,
    );
  }

  static const List<int> _windows1251 = [
    0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021,
    0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F,
    0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x0098, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F,
    0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7,
    0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407,
    0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7,
    0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457
  ];

  static String _decodeWindows1251(List<int> bytes) {
    final buffer = StringBuffer();
    for (int b in bytes) {
      if (b < 128) {
        buffer.writeCharCode(b);
      } else if (b >= 192 && b <= 255) {
        buffer.writeCharCode(0x0410 + (b - 192));
      } else if (b >= 128 && b <= 191) {
        buffer.writeCharCode(_windows1251[b - 128]);
      }
    }
    return buffer.toString();
  }

  static String fixMojibake(String input) {
    if (input.isEmpty) return input;

    List<int> bytes;
    try {
      bytes = latin1.encode(input);
    } catch (_) {
      return input;
    }

    try {
      // If it's already valid UTF-8, don't mess with it
      utf8.decode(bytes);
      return input;
    } catch (_) {}

    int highCount = 0;
    for (int b in bytes) {
      if (b >= 192 || b == 168 || b == 184) {
        highCount++;
      }
    }

    // If there are at least 2 high-byte candidates, test Windows-1251 decoding
    if (highCount >= 2) {
      final decoded = _decodeWindows1251(bytes);
      int cyrillicCount = 0;
      for (int codeUnit in decoded.codeUnits) {
        if (codeUnit >= 0x0400 && codeUnit <= 0x04FF) {
          cyrillicCount++;
        }
      }

      // If at least 70% of the high bytes decoded into valid Cyrillic letters, it's Windows-1251 mojibake!
      if (cyrillicCount >= (highCount * 0.7)) {
        return decoded;
      }
    }

    return input;
  }

  /// Reads metadata safely with deadlock protection.
  Future<Metadata> readMetadata(String filePath) async {
    await _ensureInitialized();
    if (!Platform.isWindows) {
      try {
        final meta = await Isolate.run(() async {
          await MetadataGod.initialize();
          return await MetadataGod.readMetadata(file: filePath);
        }).timeout(const Duration(seconds: 3));

        // Mobile fallback: If no embedded art found in M4A/AAC, extract it robustly via FFmpegKit
        if (meta.picture == null) {
          final ext = p.extension(filePath).toLowerCase();
          if (['.m4a', '.aac', '.mp4', '.m4v'].contains(ext)) {
            final pic = await _extractArtViaFFmpeg(filePath);
            if (pic != null) {
              return Metadata(
                title: meta.title,
                artist: meta.artist,
                album: meta.album,
                durationMs: meta.durationMs,
                trackNumber: meta.trackNumber,
                discNumber: meta.discNumber,
                year: meta.year,
                genre: meta.genre,
                fileSize: meta.fileSize,
                picture: pic,
              );
            }
          }
        }
        return _cleanMetadata(meta);
      } catch (_) {
        return _cleanMetadata(Metadata(title: p.basenameWithoutExtension(filePath)));
      }
    }

    // Poison Pill Protection
    final ext = p.extension(filePath).toLowerCase();
    final unsafeExtensions = [
      '.wav',
      '.dsf',
      '.dff',
      '.mp4',
      '.m4v',
      '.m4a',
      '.aac',
      '.ogg',
      '.opus',
      '.ape',
      '.aiff',
      '.aif',
      '.alac',
      '.wv'
    ];
    if (unsafeExtensions.contains(ext)) {
      final meta = await _readMetadataViaFFprobe(filePath);
      return _cleanMetadata(meta);
    }

    try {
      final meta = await Isolate.run(() async {
        await MetadataGod.initialize();
        return await MetadataGod.readMetadata(file: filePath);
      }).timeout(const Duration(seconds: 3));
      return _cleanMetadata(meta);
    } catch (_) {
      return _cleanMetadata(Metadata(title: p.basenameWithoutExtension(filePath)));
    }
  }

  /// Processes a batch of tracks sequentially to avoid burst-blocking the main thread.
  /// PERF FIX: Previously used Future.wait() which fired all 20 reads concurrently,
  /// causing ~40ms of FFI jank per chunk. Sequential processing yields to the event loop
  /// between each read, keeping the UI responsive during scan.
  Future<List<Metadata?>> readMetadataBatch(List<String> filePaths) async {
    if (filePaths.isEmpty) return [];
    await _ensureInitialized();

    final unsafeExtensions = [
      '.wav',
      '.dsf',
      '.dff',
      '.mp4',
      '.m4v',
      '.m4a',
      '.aac',
      '.ogg',
      '.opus',
      '.ape',
      '.aiff',
      '.aif',
      '.alac',
      '.wv'
    ];

    final List<Metadata?> results = [];
    for (final path in filePaths) {
      try {
        if (!Platform.isWindows) {
          final meta = await Isolate.run(() async {
            await MetadataGod.initialize();
            return await MetadataGod.readMetadata(file: path);
          }).timeout(const Duration(seconds: 3));

          // Mobile fallback: If no embedded art found in M4A/AAC, extract it robustly via FFmpegKit
          if (meta.picture == null) {
            final ext = p.extension(path).toLowerCase();
            if (['.m4a', '.aac', '.mp4', '.m4v'].contains(ext)) {
              final pic = await _extractArtViaFFmpeg(path);
              if (pic != null) {
                results.add(_cleanMetadata(Metadata(
                  title: meta.title,
                  artist: meta.artist,
                  album: meta.album,
                  durationMs: meta.durationMs,
                  trackNumber: meta.trackNumber,
                  discNumber: meta.discNumber,
                  year: meta.year,
                  genre: meta.genre,
                  fileSize: meta.fileSize,
                  picture: pic,
                )));
                continue;
              }
            }
          }
          results.add(_cleanMetadata(meta));
        } else {
          final ext = p.extension(path).toLowerCase();
          if (unsafeExtensions.contains(ext)) {
            final meta = await _readMetadataViaFFprobe(path);
            results.add(_cleanMetadata(meta));
          } else {
            final meta = await Isolate.run(() async {
              await MetadataGod.initialize();
              return await MetadataGod.readMetadata(file: path);
            }).timeout(const Duration(seconds: 3));
            results.add(_cleanMetadata(meta));
          }
        }
      } catch (e) {
        debugPrint("⚠️ [readMetadataBatch] Error reading metadata for $path: $e");
        results.add(_cleanMetadata(Metadata(title: p.basenameWithoutExtension(path))));
      }
    }

    return results;
  }

  /// Writes metadata to a file.
  Future<void> writeMetadata({
    required String filePath,
    required Metadata metadata,
  }) async {
    await MetadataGod.writeMetadata(file: filePath, metadata: metadata);
  }

  Future<Metadata> _readMetadataViaFFprobe(String filePath) async {
    // Single ffprobe invocation for both tags + audio info
    final result = await AudioInfoService().getTagsAndInfo(filePath);
    
    // Normalize keys to lowercase for robust case-insensitive lookup
    final tags = result.tags.map((key, value) => MapEntry(key.toLowerCase(), value));
    final audioInfo = result.info;

    // Extract embedded album art via ffmpeg for unsafe formats
    Picture? picture;
    if (result.hasArtStream) {
      try {
        picture = await _extractArtViaFFmpeg(filePath);
      } catch (_) {
        // Silent — art extraction is best-effort
      }
    }

    return Metadata(
      title: tags['title'] ?? p.basenameWithoutExtension(filePath),
      artist: tags['artist'],
      album: tags['album'],
      durationMs: audioInfo?.duration?.inMilliseconds.toDouble(),
      trackNumber: int.tryParse(tags['track']?.split('/').first ?? ''),
      discNumber: int.tryParse(tags['disc']?.split('/').first ?? ''),
      year: int.tryParse(tags['date']?.substring(0, 4) ?? tags['year'] ?? ''),
      genre: tags['genre'],
      fileSize: audioInfo?.fileSize != null
          ? BigInt.from(audioInfo!.fileSize!)
          : null,
      picture: picture,
    );
  }

  /// Extracts embedded album art from an audio file using ffmpeg/FFmpegKit.
  /// Works for AIFF, WAV, OGG, OPUS, and other formats where MetadataGod deadlocks or fails.
  Future<Picture?> _extractArtViaFFmpeg(String filePath) async {
    await _acquireArtSlot();
    try {
      final tempDir = Directory.systemTemp;
      final tempArtFile =
          File('${tempDir.path}/art_extract_${filePath.hashCode}.jpg');

      try {
        if (Platform.isAndroid || Platform.isIOS) {
          // Mobile: Use FFmpegKit
          final session = await FFmpegKit.executeWithArguments([
            '-y',
            '-i',
            filePath,
            '-map',
            '0:v:0',
            '-c:v',
            'mjpeg',
            '-frames:v',
            '1',
            tempArtFile.path,
          ]);
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode) && tempArtFile.existsSync() && tempArtFile.lengthSync() > 0) {
            final Uint8List bytes = await tempArtFile.readAsBytes();
            debugPrint(
                '🎨 [MetadataService] Extracted ${bytes.length} bytes of art via FFmpegKit from $filePath');
            try {
              await tempArtFile.delete();
            } catch (_) {}
            return Picture(data: bytes, mimeType: 'image/jpeg');
          } else {
            debugPrint(
                '⚠️ [MetadataService] FFmpegKit art extraction failed or returned no output for $filePath');
          }
        } else {
          // Desktop: Use native Process
          final ffmpegPath = await getFFmpegPath();
          if (ffmpegPath == null) {
            debugPrint('⚠️ [MetadataService] ffmpeg not found, cannot extract art');
            return null;
          }

          final processResult = await Process.run(
            ffmpegPath,
            [
              '-y', // Overwrite output
              '-i', filePath, // Input file
              '-map', '0:v:0', // Select first video stream (embedded art)
              '-c:v', 'mjpeg', // Encode as JPEG (handles PNG/BMP art too)
              '-frames:v', '1', // Only one frame
              tempArtFile.path,
            ],
            runInShell: false,
          ).timeout(const Duration(seconds: 5), onTimeout: () {
            throw TimeoutException('ffmpeg art extraction timeout');
          });

          debugPrint(
              '🎨 [MetadataService] ffmpeg art extraction exit code: ${processResult.exitCode} for $filePath');
          if (processResult.exitCode != 0) {
            debugPrint(
                '⚠️ [MetadataService] ffmpeg stderr: ${processResult.stderr}');
          }

          if (tempArtFile.existsSync() && tempArtFile.lengthSync() > 0) {
            final Uint8List bytes = await tempArtFile.readAsBytes();
            debugPrint(
                '🎨 [MetadataService] Extracted ${bytes.length} bytes of art from $filePath');
            try {
              await tempArtFile.delete();
            } catch (_) {}
            return Picture(data: bytes, mimeType: 'image/jpeg');
          } else {
            debugPrint(
                '⚠️ [MetadataService] No art output file or empty for $filePath');
          }
        }
      } catch (e) {
        debugPrint(
            '⚠️ [MetadataService] Art extraction failed for $filePath: $e');
      }

      // Clean up temp file on failure
      try {
        if (tempArtFile.existsSync()) await tempArtFile.delete();
      } catch (_) {}
      return null;
    } finally {
      _releaseArtSlot();
    }
  }

  /// Get FFmpeg path from bin directory
  static String? _cachedFFmpegPath;
  static Future<String?> getFFmpegPath() async {
    if (_cachedFFmpegPath != null) return _cachedFFmpegPath;
    try {
      final appDir = await getApplicationSupportDirectory();
      final binDir = Directory('${appDir.path}/bin');
      final ffmpegName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
      final ffmpegFile = File('${binDir.path}/$ffmpegName');
      if (await ffmpegFile.exists()) {
        _cachedFFmpegPath = ffmpegFile.path;
        return _cachedFFmpegPath;
      }
    } catch (_) {}
    return null;
  }
}
