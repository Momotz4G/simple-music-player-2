import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
import '../models/song_model.dart';

/// Audio quality information model
class AudioInfo {
  final String format; // FLAC, M4A, MP3, etc.
  final String codec; // alac, aac, mp3, flac
  final int? bitrate; // kbps
  final int? sampleRate; // Hz
  final int? channels; // 1, 2, etc.
  final int? bitDepth; // 16, 24, 32
  final int? fileSize; // bytes
  final Duration? duration;

  AudioInfo({
    required this.format,
    required this.codec,
    this.bitrate,
    this.sampleRate,
    this.channels,
    this.bitDepth,
    this.fileSize,
    this.duration,
  });

  /// Get quality label (Hi-Res, Lossless, CD Quality, High, Standard)
  String get qualityLabel {
    if (isLossless) {
      // Hi-Res Lossless: sample rate > 48kHz OR bit depth > 16
      // Examples: 96kHz/24-bit, 192kHz/24-bit, 48kHz/24-bit
      if ((sampleRate != null && sampleRate! > 48000) ||
          (bitDepth != null && bitDepth! > 16)) {
        return 'Hi-Res Lossless';
      }

      // CD Quality: exactly 44.1kHz/16-bit (Red Book standard)
      if (sampleRate == 44100 && (bitDepth == 16 || bitDepth == null)) {
        return 'Lossless (CD)';
      }

      // Other lossless (e.g., 48kHz/16-bit)
      return 'Lossless';
    }

    // Special case for DSD: Even if it's not detected as lossless yet,
    // if the codec starts with DSD, it is definitely lossless.
    if (codec.toLowerCase().startsWith('dsd') ||
        format.toUpperCase() == 'DSF' ||
        format.toUpperCase() == 'DFF') {
      return 'Hi-Res Lossless (DSD)';
    }

    // Lossy quality based on bitrate
    if (bitrate != null) {
      if (bitrate! >= 256) return 'High Quality';
      if (bitrate! >= 128) return 'Standard';
      return 'Low';
    }

    return 'Unknown';
  }

  /// Check if format is lossless
  bool get isLossless {
    final lowerCodec = codec.toLowerCase().trim();
    final lowerFormat = format.toLowerCase().trim();
    final losslessCodecs = [
      'flac',
      'alac',
      'wav',
      'aiff',
      'ape',
      'wavpack',
      'wv',
      'pcm_s16le',
      'pcm_s24le',
      'pcm_s32le',
      'pcm_f32le',
      'pcm_s16be',
      'pcm_s24be',
      'pcm_s32be',
      'pcm_f32be',
      'pcm_f64le',
      'pcm_f64be',
    ];
    if (losslessCodecs.any((c) => lowerCodec.contains(c))) return true;

    // DSD variants (dsd_lsbf, dsd_msbf, dsd_lsbf_planar, etc.)
    if (lowerCodec.contains('dsd') ||
        lowerCodec == 'dsf' ||
        lowerCodec == 'dff' ||
        lowerFormat == 'dsf' ||
        lowerFormat == 'dff') {
      return true;
    }

    return false;
  }

  /// Format bitrate for display
  String get bitrateDisplay {
    if (bitrate == null) return 'Unknown';
    return '$bitrate kbps';
  }

  /// Format sample rate for display
  String get sampleRateDisplay {
    if (sampleRate == null) return 'Unknown';
    final khz = sampleRate! / 1000;
    return '${khz.toStringAsFixed(1)} kHz';
  }

  /// Format file size for display
  String get fileSizeDisplay {
    if (fileSize == null) return 'Unknown';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Format bit depth for display
  String get bitDepthDisplay {
    if (bitDepth == null) return 'Unknown';
    return '$bitDepth-bit';
  }

  /// Format channels for display
  String get channelsDisplay {
    if (channels == null) return 'Unknown';
    if (channels == 1) return 'Mono';
    if (channels == 2) return 'Stereo';
    if (channels == 6) return '5.1 Surround';
    if (channels == 8) return '7.1 Surround';
    return '$channels channels';
  }
}

/// Service to extract audio metadata using ffprobe
class AudioInfoService {
  static final AudioInfoService _instance = AudioInfoService._internal();
  factory AudioInfoService() => _instance;
  AudioInfoService._internal();

  String? _ffprobePath;

  /// CONCURRENCY LIMITER: Prevents ffprobe process storm.
  /// Max 2 simultaneous ffprobe.exe processes to avoid overwhelming Windows.
  static const int _maxConcurrentProbes = 4; // Increased for faster clearing
  static int _activeProbes = 0;
  static final List<({Completer<void> completer, bool isPriority})>
      _probeQueue = [];

  /// Acquire a slot to run ffprobe. Waits if at capacity.
  static Future<void> _acquireProbeSlot(String filePath,
      {bool isPriority = false}) async {
    final fileName = filePath.split(Platform.pathSeparator).last;
    if (_activeProbes < _maxConcurrentProbes) {
      _activeProbes++;
      debugPrint(
          "🎟️ AudioInfo Slot: Acquired for '$fileName' (Active: $_activeProbes)${isPriority ? " [PRIORITY]" : ""}");
      return;
    }
    // Wait for a slot to free up
    debugPrint(
        "⏳ AudioInfo Slot: Waiting for '$fileName'... (Queue: ${_probeQueue.length + 1})${isPriority ? " [PRIORITY]" : ""}");
    final completer = Completer<void>();
    if (isPriority) {
      _probeQueue
          .insert(0, (completer: completer, isPriority: true)); // Jump to front
    } else {
      _probeQueue.add((completer: completer, isPriority: false));
    }
    await completer.future;
  }

  /// Release a ffprobe slot, unblocking the next waiter.
  static void _releaseProbeSlot() {
    if (_probeQueue.isNotEmpty) {
      final next = _probeQueue.removeAt(0);
      next.completer.complete(); // Hand the slot to the next waiter
      debugPrint(
          "🎟️ AudioInfo Slot: Passed to next (Queue: ${_probeQueue.length})${next.isPriority ? " [WAS PRIORITY]" : ""}");
    } else {
      _activeProbes--;
      debugPrint("🎟️ AudioInfo Slot: Released (Active: $_activeProbes)");
    }
  }

  /// Initialize ffprobe path (desktop only)
  Future<void> initialize() async {
    if (_ffprobePath != null) return;

    // Mobile uses FFprobeKit, no initialization needed
    if (Platform.isAndroid || Platform.isIOS) {
      return;
    }

    // Desktop: Find ffprobe in app support directory
    final appDir = await getApplicationSupportDirectory();
    final binDir = Directory('${appDir.path}/bin');

    String execName = 'ffprobe';
    if (Platform.isWindows) execName = 'ffprobe.exe';

    final ffprobeFile = File('${binDir.path}/$execName');
    if (await ffprobeFile.exists()) {
      _ffprobePath = ffprobeFile.path;
    }
  }

  /// Get audio info for a SongModel (Resilient)
  Future<AudioInfo?> getAudioInfoForSong(SongModel song,
      {bool isPriority = false}) async {
    // 1. Try local file if it exists
    if (!song.filePath.startsWith('http')) {
      final file = File(song.filePath);
      if (await file.exists()) {
        debugPrint("🔍 AudioInfo: Probing local file: ${song.filePath}");
        return await getAudioInfo(song.filePath, isPriority: isPriority);
      }
    }

    // 2. Try filePath if it's a URL (Instant Streaming)
    if (song.filePath.startsWith('http')) {
      // NEW: Check if a local cached version exists before probing the URL
      final cachedPath = await _checkCachePath(song);
      if (cachedPath != null) {
        debugPrint(
            "🔍 AudioInfo: Found cached version for URL, probing: $cachedPath");
        return await getAudioInfo(cachedPath, isPriority: isPriority);
      }
      debugPrint("🔍 AudioInfo: Probing URL: ${song.filePath}");
      return await getAudioInfo(song.filePath, isPriority: isPriority);
    }

    // 3. Try source URL if it exists
    if (song.sourceUrl != null && song.sourceUrl!.startsWith('http')) {
      final cachedPath = await _checkCachePath(song);
      if (cachedPath != null) {
        debugPrint(
            "🔍 AudioInfo: Found cached version for sourceUrl, probing: $cachedPath");
        return await getAudioInfo(cachedPath, isPriority: isPriority);
      }
      debugPrint("🔍 AudioInfo: Probing sourceUrl: ${song.sourceUrl}");
      return await getAudioInfo(song.sourceUrl!, isPriority: isPriority);
    }

    // 4. Fallback to basic info from song metadata
    debugPrint(
        "🔍 AudioInfo: Falling back to basic info for: ${song.filePath}");
    return _getBasicInfo(song.filePath, 0, _getFormatFromPath(song.filePath));
  }

  /// Get metadata tags for a file using ffprobe (useful for DSD/DSF)
  Future<Map<String, String>> getTags(String filePath) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final session = await FFprobeKit.getMediaInformation(filePath);
        final mediaInfo = session.getMediaInformation();
        if (mediaInfo == null) return {};
        final tags = mediaInfo.getTags();
        return Map<String, String>.from(tags ?? {});
      }

      if (_ffprobePath == null) await initialize();
      if (_ffprobePath == null) return {};

      await _acquireProbeSlot(filePath);
      try {
        final result = await Process.run(
          _ffprobePath!,
          [
            '-v',
            'quiet',
            '-print_format',
            'json',
            '-show_format',
            filePath,
          ],
          runInShell: false,
          stdoutEncoding: utf8,
        ).timeout(const Duration(seconds: 5), onTimeout: () {
          debugPrint("⏱️ ffprobe (Tags): Timeout reached for $filePath");
          throw TimeoutException("ffprobe timeout");
        });

        if (result.exitCode != 0) return {};

        final json = jsonDecode(result.stdout as String);
        final formatInfo = json['format'] as Map?;
        final tags = formatInfo?['tags'] as Map?;

        if (tags == null) return {};
        return tags
            .map((key, value) => MapEntry(key.toString(), value.toString()));
      } finally {
        _releaseProbeSlot();
      }
    } catch (e) {
      if (kDebugMode) print('AudioInfoService getTags error: $e');
      return {};
    }
  }

  /// COMBINED: Get both tags AND audio info in a single ffprobe invocation.
  /// This halves the number of ffprobe.exe processes during library scan.
  Future<({Map<String, String> tags, AudioInfo? info, bool hasArtStream})> getTagsAndInfo(
      String filePath) async {
    try {
      final format = _getFormatFromPath(filePath);
      int fileSize = 0;

      if (!filePath.startsWith('http')) {
        final file = File(filePath);
        if (await file.exists()) {
          fileSize = await file.length();
        }
      }

      if (Platform.isAndroid || Platform.isIOS) {
        final session = await FFprobeKit.getMediaInformation(filePath);
        final mediaInfo = session.getMediaInformation();
        if (mediaInfo == null) {
          return (
            tags: <String, String>{},
            info: _getBasicInfo(filePath, fileSize, format),
            hasArtStream: false,
          );
        }
        bool hasArtStream = false;
        final mediaStreams = mediaInfo.getStreams();
        if (mediaStreams.isNotEmpty) {
          for (final stream in mediaStreams) {
            if (stream.getType() == 'video') {
              hasArtStream = true;
              break;
            }
          }
        }
        final rawTags = mediaInfo.getTags();
        final tags = rawTags != null
            ? Map<String, String>.from(rawTags)
            : <String, String>{};
        final info = await _getMobileInfo(filePath, fileSize, format);
        return (tags: tags, info: info, hasArtStream: hasArtStream);
      }

      // Desktop: single ffprobe with both -show_format and -show_streams
      if (_ffprobePath == null) await initialize();
      if (_ffprobePath == null) {
        return (
          tags: <String, String>{},
          info: _getBasicInfo(filePath, fileSize, format),
          hasArtStream: false,
        );
      }

      await _acquireProbeSlot(filePath);
      try {
        final result = await Process.run(
          _ffprobePath!,
          [
            '-v',
            'quiet',
            '-print_format',
            'json',
            '-show_format',
            '-show_streams',
            filePath,
          ],
          runInShell: false,
          stdoutEncoding: utf8,
        ).timeout(const Duration(seconds: 5), onTimeout: () {
          debugPrint("⏱️ ffprobe (TagsAndInfo): Timeout reached for $filePath");
          throw TimeoutException("ffprobe timeout");
        });

        if (result.exitCode != 0) {
          return (
            tags: <String, String>{},
            info: _getBasicInfo(filePath, fileSize, format),
            hasArtStream: false,
          );
        }

        final json = jsonDecode(result.stdout as String);
        final formatInfo = json['format'] as Map?;
        final streams = json['streams'] as List?;

        // Extract tags
        final rawTags = formatInfo?['tags'] as Map?;
        final tags = rawTags != null
            ? rawTags
                .map((key, value) => MapEntry(key.toString(), value.toString()))
            : <String, String>{};

        // Extract audio stream info
        Map? audioStream;
        bool hasArtStream = false;
        if (streams != null) {
          for (var stream in streams) {
            if (stream['codec_type'] == 'audio') {
              audioStream = stream;
            } else if (stream['codec_type'] == 'video') {
              hasArtStream = true;
            }
          }
        }

        if (audioStream == null) {
          return (tags: tags, info: _getBasicInfo(filePath, fileSize, format), hasArtStream: hasArtStream);
        }

        final codec = audioStream['codec_name'] as String? ?? 'unknown';
        final sampleRate =
            int.tryParse(audioStream['sample_rate']?.toString() ?? '');
        final channels = audioStream['channels'] as int?;
        int? bitDepth =
            int.tryParse(audioStream['bits_per_raw_sample']?.toString() ?? '');
        if (bitDepth == null || bitDepth == 0) {
          bitDepth =
              int.tryParse(audioStream['bits_per_sample']?.toString() ?? '');
        }
        if (bitDepth == 0) bitDepth = null;

        int? bitrate;
        if (audioStream['bit_rate'] != null) {
          bitrate =
              (int.tryParse(audioStream['bit_rate'].toString()) ?? 0) ~/ 1000;
        } else if (formatInfo?['bit_rate'] != null) {
          bitrate =
              (int.tryParse(formatInfo!['bit_rate'].toString()) ?? 0) ~/ 1000;
        }

        Duration? duration;
        if (formatInfo?['duration'] != null) {
          final seconds = double.tryParse(formatInfo!['duration'].toString());
          if (seconds != null) {
            duration = Duration(milliseconds: (seconds * 1000).round());
          }
        }

        final info = AudioInfo(
          format: format,
          codec: codec,
          bitrate: bitrate,
          sampleRate: sampleRate,
          channels: channels,
          bitDepth: bitDepth,
          fileSize: fileSize,
          duration: duration,
        );

        return (tags: tags, info: info, hasArtStream: hasArtStream);
      } finally {
        _releaseProbeSlot();
      }
    } catch (e) {
      if (kDebugMode) print('AudioInfoService getTagsAndInfo error: $e');
      return (tags: <String, String>{}, info: null, hasArtStream: false);
    }
  }

  /// Get audio info for a file or URL
  Future<AudioInfo?> getAudioInfo(String filePath,
      {bool isPriority = false}) async {
    try {
      final isUrl = filePath.startsWith('http');
      int fileSize = 0;

      if (!isUrl) {
        final file = File(filePath);
        if (!await file.exists()) {
          // If file doesn't exist but it's not a URL, we can't do much with ffprobe
          // Return basic info as fallback instead of null
          return _getBasicInfo(filePath, 0, _getFormatFromPath(filePath));
        }
        fileSize = await file.length();
      }

      final format = _getFormatFromPath(filePath);

      // Fast Path for Streams (All Platforms): Skip heavy probes, enrich via fast URL headers
      if (isUrl) {
        final basic = _getBasicInfo(filePath, fileSize, format);
        return await _enrichWithUrlMetadata(basic, filePath);
      }

      // Mobile: Use FFprobeKit from ffmpeg_kit_flutter_new_audio
      if (Platform.isAndroid || Platform.isIOS) {
        return await _getMobileInfo(filePath, fileSize, format);
      }

      // Desktop: Use ffprobe binary
      if (!Platform.isAndroid && !Platform.isIOS) {
        // Lazy Init: Ensure initialized if called early
        if (_ffprobePath == null) {
          await initialize();
        }

        if (_ffprobePath != null) {
          final info = await _getDetailedInfo(filePath, fileSize, format,
              isPriority: isPriority);

          return info;
        }
      }

      // Fallback
      final basic = _getBasicInfo(filePath, fileSize, format);
      if (isUrl) return await _enrichWithUrlMetadata(basic, filePath);
      return basic;
    } catch (e) {
      if (kDebugMode) print('AudioInfoService error: $e');
      return null;
    }
  }

  /// Get audio info using FFprobeKit on mobile
  Future<AudioInfo?> _getMobileInfo(
      String filePath, int fileSize, String format) async {
    try {
      debugPrint("FFprobeKit: Starting probe for $filePath");
      final session = await FFprobeKit.getMediaInformation(filePath)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint("⏱️ FFprobeKit: Timeout reached for $filePath");
        throw TimeoutException("FFprobeKit timeout");
      });
      final mediaInfo = session.getMediaInformation();

      if (mediaInfo == null) {
        debugPrint("⚠️ FFprobeKit: No media info returned for $filePath");
        return _getBasicInfo(filePath, fileSize, format);
      }
      debugPrint("✅ FFprobeKit: Info retrieved for $filePath");

      // Get streams
      final streams = mediaInfo.getStreams();
      Map<dynamic, dynamic>? audioStream;

      for (final stream in streams) {
        final props = stream.getAllProperties();
        if (props?['codec_type'] == 'audio') {
          audioStream = props;
          break;
        }
      }

      if (audioStream == null) {
        return _getBasicInfo(filePath, fileSize, format);
      }

      // Extract info
      final codec = audioStream['codec_name'] as String? ?? 'unknown';
      final sampleRate =
          int.tryParse(audioStream['sample_rate']?.toString() ?? '');
      final channels = audioStream['channels'] as int?;

      // Bit depth: Try bits_per_raw_sample first (for FLAC), then bits_per_sample
      int? bitDepth =
          int.tryParse(audioStream['bits_per_raw_sample']?.toString() ?? '');
      if (bitDepth == null || bitDepth == 0) {
        bitDepth =
            int.tryParse(audioStream['bits_per_sample']?.toString() ?? '');
      }
      if (bitDepth == 0) bitDepth = null;

      // Bitrate from media info
      int? bitrate;
      final bitrateStr = mediaInfo.getBitrate();
      if (bitrateStr != null) {
        bitrate = (int.tryParse(bitrateStr) ?? 0) ~/ 1000;
      }

      // Duration
      Duration? duration;
      final durationStr = mediaInfo.getDuration();
      if (durationStr != null) {
        final seconds = double.tryParse(durationStr);
        if (seconds != null) {
          duration = Duration(milliseconds: (seconds * 1000).round());
        }
      }

      return AudioInfo(
        format: format,
        codec: codec,
        bitrate: bitrate,
        sampleRate: sampleRate,
        channels: channels,
        bitDepth: bitDepth,
        fileSize: fileSize,
        duration: duration,
      );
    } catch (e) {
      if (kDebugMode) print('FFprobeKit error: $e');
      return _getBasicInfo(filePath, fileSize, format);
    }
  }

  /// Get format from file path
  String _getFormatFromPath(String path) {
    if (path.contains('googlevideo.com') || path.contains('youtube')) {
      if (path.contains('mime=audio%2Fwebm') || path.contains('itag=251')) {
        return 'WebM';
      }
      return 'M4A';
    }
    if (path.contains('/stream?') && path.contains('id=')) {
      if (path.contains('quality=HIGH') || path.contains('quality=LOW')) {
        return 'M4A';
      }
      return 'FLAC'; // Our VPS always pipes FLAC for Lossless/Hi-Res
    }
    // Remove query parameters if it's a URL
    final purePath = path.split('?').first;
    final ext = purePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'flac':
        return 'FLAC';
      case 'm4a':
        return 'M4A';
      case 'mp3':
        return 'MP3';
      case 'aac':
        return 'AAC';
      case 'wav':
        return 'WAV';
      case 'ogg':
        return 'OGG';
      case 'opus':
        return 'Opus';
      case 'dsf':
        return 'DSF';
      case 'dff':
        return 'DFF';
      case 'alac':
        return 'ALAC';
      default:
        return ext.toUpperCase();
    }
  }

  /// Get codec from format (estimate for mobile)
  String _getCodecFromFormat(String format) {
    switch (format) {
      case 'FLAC':
        return 'flac';
      case 'M4A':
        return 'aac';
      case 'MP3':
        return 'mp3';
      case 'AAC':
        return 'aac';
      case 'WAV':
        return 'pcm';
      case 'OGG':
        return 'vorbis';
      case 'Opus':
        return 'opus';
      case 'DSF':
        return 'dsf';
      case 'DFF':
        return 'dff';
      default:
        return format.toLowerCase();
    }
  }

  /// Get basic info (mobile fallback / fast guestimate)
  AudioInfo _getBasicInfo(String filePath, int fileSize, String format) {
    String codec = _getCodecFromFormat(format);

    // Estimate bitrate from file size (very rough)
    // Assume 3-4 minutes average song
    int? estimatedBitrate;
    if (fileSize > 0) {
      // Rough estimate: fileSize / duration * 8 / 1000
      // Assume 3.5 min = 210 seconds
      estimatedBitrate = ((fileSize * 8) / 210 / 1000).round();
    }

    // ENHANCEMENT: Smart guestimate for M4A (ALAC vs AAC)
    // AAC almost never exceeds 320-512kbps. If we see > 500kbps in an M4A, 
    // it's highly likely to be ALAC (Lossless).
    if (format == 'M4A' && estimatedBitrate != null && estimatedBitrate > 500) {
      codec = 'alac';
    }

    return AudioInfo(
      format: format,
      codec: codec,
      bitrate: estimatedBitrate,
      sampleRate: (format == 'FLAC' || codec == 'alac') ? 44100 : null,
      channels: 2, // Assume stereo
      bitDepth: (format == 'FLAC' || codec == 'alac') ? 16 : null,
      fileSize: fileSize,
    );
  }

  /// Get detailed info using ffprobe
  Future<AudioInfo> _getDetailedInfo(
      String filePath, int fileSize, String format,
      {bool isPriority = false}) async {
    try {
      await _acquireProbeSlot(filePath, isPriority: isPriority);
      late final ProcessResult result;
      try {
        result = await Process.run(
          _ffprobePath!,
          [
            '-v',
            'quiet',
            '-print_format',
            'json',
            '-show_streams',
            '-show_format',
            filePath,
          ],
          runInShell: false,
          stdoutEncoding: utf8,
        ).timeout(const Duration(seconds: 5), onTimeout: () {
          debugPrint("⏱️ ffprobe: Timeout reached for $filePath");
          throw TimeoutException("ffprobe timeout");
        });
      } finally {
        _releaseProbeSlot();
      }

      if (result.exitCode != 0) {
        return _getBasicInfo(filePath, fileSize, format);
      }

      final json = jsonDecode(result.stdout as String);
      final streams = json['streams'] as List?;
      final formatInfo = json['format'] as Map?;

      // Find audio stream
      Map? audioStream;
      if (streams != null) {
        for (var stream in streams) {
          if (stream['codec_type'] == 'audio') {
            audioStream = stream;
            break;
          }
        }
      }

      if (audioStream == null) {
        return _getBasicInfo(filePath, fileSize, format);
      }

      // Extract info
      final codec = audioStream['codec_name'] as String? ?? 'unknown';
      final sampleRate =
          int.tryParse(audioStream['sample_rate']?.toString() ?? '');
      final channels = audioStream['channels'] as int?;

      // Bit depth: Try bits_per_raw_sample first (for FLAC), then bits_per_sample
      int? bitDepth =
          int.tryParse(audioStream['bits_per_raw_sample']?.toString() ?? '');
      if (bitDepth == null || bitDepth == 0) {
        bitDepth =
            int.tryParse(audioStream['bits_per_sample']?.toString() ?? '');
      }
      // Filter out 0 values
      if (bitDepth == 0) bitDepth = null;

      // Bitrate: Try stream bitrate first, then format bitrate
      int? bitrate;
      if (audioStream['bit_rate'] != null) {
        bitrate =
            (int.tryParse(audioStream['bit_rate'].toString()) ?? 0) ~/ 1000;
      } else if (formatInfo?['bit_rate'] != null) {
        bitrate =
            (int.tryParse(formatInfo!['bit_rate'].toString()) ?? 0) ~/ 1000;
      }

      // Duration
      Duration? duration;
      if (formatInfo?['duration'] != null) {
        final seconds = double.tryParse(formatInfo!['duration'].toString());
        if (seconds != null) {
          duration = Duration(milliseconds: (seconds * 1000).round());
        }
      }

      return AudioInfo(
        format: format,
        codec: codec,
        bitrate: bitrate,
        sampleRate: sampleRate,
        channels: channels,
        bitDepth: bitDepth,
        fileSize: fileSize,
        duration: duration,
      );
    } catch (e) {
      if (kDebugMode) print('ffprobe error: $e');
      return _getBasicInfo(filePath, fileSize, format);
    }
  }

  /// NEW: Enrich AudioInfo using knowledge from the streaming URL
  /// Now performs a HEAD request to snoops X-Headers for exact specs
  Future<AudioInfo> _enrichWithUrlMetadata(AudioInfo info, String url) async {
    final uri = Uri.parse(url);

    // Fast path for YouTube streams
    if (url.contains('googlevideo.com') || url.contains('youtube')) {
      final isWebM = url.contains('mime=audio%2Fwebm') || url.contains('itag=251');
      return AudioInfo(
        format: isWebM ? 'WebM' : 'M4A',
        codec: isWebM ? 'opus' : 'aac',
        bitrate: isWebM ? 160 : 128,
        sampleRate: 44100,
        channels: 2,
        bitDepth: null,
        fileSize: null,
        duration: info.duration,
      );
    }

    final qualityParam = uri.queryParameters['quality']?.toUpperCase();

    int? headerSampleRate;
    int? headerBitDepth;
    int? headerBitrate;
    String? headerCodec;

    try {
      // 1. Snoop VPS headers for exact specs (Fast Path)
      final response = await http.head(uri).timeout(const Duration(seconds: 5));
      
      // Use lowercase for reliability
      final srate = response.headers['x-audio-sample-rate'];
      final bdepth = response.headers['x-audio-bit-depth'];
      final brate = response.headers['x-audio-bitrate'];
      final scodec = response.headers['x-audio-codec'];

      if (srate != null) headerSampleRate = int.tryParse(srate);
      if (bdepth != null) headerBitDepth = int.tryParse(bdepth);
      if (brate != null) headerBitrate = int.tryParse(brate);
      headerCodec = scodec?.toLowerCase();

      // 2. SMART FALLBACK: Parse specs from filename/URL
      // The bot often includes tags like [16B-44.1kHz - ALAC] in the path
      if (headerSampleRate == null || headerBitDepth == null || headerCodec == null) {
        final decodedUrl = Uri.decodeFull(url);
        final specRegex = RegExp(r'\[(\d+)B-(\d+\.?\d*)kHz\s*-\s*(\w+)\]');
        final match = specRegex.firstMatch(decodedUrl);

        if (match != null) {
          final bitDepthStr = match.group(1);
          final sampleRateStr = match.group(2);
          final codecStr = match.group(3)?.toLowerCase();

          headerBitDepth ??= int.tryParse(bitDepthStr ?? '');
          if (sampleRateStr != null) {
            headerSampleRate ??= ((double.tryParse(sampleRateStr) ?? 0) * 1000).round();
            if (headerSampleRate == 0) headerSampleRate = null;
          }
          headerCodec ??= codecStr;
          debugPrint("🔍 AudioInfo: Parsed specs from URL: ${bitDepthStr}bit, ${sampleRateStr}kHz, $codecStr");
        }
      }
    } catch (e) {
      debugPrint("🔍 AudioInfo: Metadata snoop/parse failed ($e)");
    }

    // 3. Apply overrides and defaults
    int? sampleRate = headerSampleRate ?? info.sampleRate;
    int? bitDepth = headerBitDepth ?? info.bitDepth;
    int? bitrate = headerBitrate;
    String codec = headerCodec ?? info.codec;

    if (qualityParam == 'HI_RES_LOSSLESS') {
      sampleRate ??= 96000;
      bitDepth ??= 24;
    } else if (qualityParam == 'LOSSLESS') {
      sampleRate ??= 44100;
      bitDepth ??= 16;
    } else if (qualityParam == 'HIGH') {
      bitrate ??= 320;
    }

    // 4. Estimate bitrate if missing
    if (bitrate == null || bitrate == 0) {
      if (sampleRate != null && bitDepth != null) {
        bitrate = (sampleRate * bitDepth * 2 * 0.6 / 1000).round();
      }
    }

    // 5. Final assembly
    final bool isLossy = (qualityParam == 'HIGH' || qualityParam == 'LOW' || codec == 'aac' || codec == 'mp3');

    return AudioInfo(
      format: info.format == 'STREAM' || info.format.contains('/')
          ? (isLossy ? 'M4A' : 'FLAC')
          : info.format,
      codec: codec,
      bitrate: bitrate ?? info.bitrate,
      sampleRate: sampleRate ?? info.sampleRate,
      channels: info.channels ?? 2,
      bitDepth: bitDepth ?? info.bitDepth,
      fileSize: info.fileSize,
      duration: info.duration,
    );
  }

  /// NEW: Helper to find the potential cache path for a song
  Future<String?> _checkCachePath(SongModel song) async {
    try {
      final tempDir = await getTemporaryDirectory();
      // Use the same logic as FlacDownloaderService/FilenameHelper
      final sanitized = '${song.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')} - ${song.artist.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}';

      final cacheDir = Directory('${tempDir.path}/SimpleMusicCache');
      if (await cacheDir.exists()) {
        final flacFile = File('${cacheDir.path}/$sanitized.flac');
        if (await flacFile.exists() && await flacFile.length() > 1024) {
          return flacFile.path;
        }

        final m4aFile = File('${cacheDir.path}/$sanitized.m4a');
        if (await m4aFile.exists() && await m4aFile.length() > 1024) {
          return m4aFile.path;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
