import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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
    final losslessCodecs = ['flac', 'alac', 'wav', 'aiff', 'ape'];
    return losslessCodecs.contains(codec.toLowerCase());
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
  Future<AudioInfo?> getAudioInfoForSong(SongModel song) async {
    // 1. Try local file if it exists
    if (!song.filePath.startsWith('http')) {
      final file = File(song.filePath);
      if (await file.exists()) {
        return await getAudioInfo(song.filePath);
      }
    }

    // 2. Try source URL if it exists
    if (song.sourceUrl != null && song.sourceUrl!.startsWith('http')) {
      return await getAudioInfo(song.sourceUrl!);
    }

    // 3. Fallback to basic info from song metadata
    return _getBasicInfo(song.filePath, 0, _getFormatFromPath(song.filePath));
  }

  /// Get audio info for a file or URL
  Future<AudioInfo?> getAudioInfo(String filePath) async {
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

      // Mobile: Use FFprobeKit from ffmpeg_kit_flutter_new_audio
      if (Platform.isAndroid || Platform.isIOS) {
        return await _getMobileInfo(filePath, fileSize, format);
      }

      // Desktop: Use ffprobe binary
      if (!Platform.isAndroid && !Platform.isIOS) {
        // 🚀 Lazy Init: Ensure initialized if called early
        if (_ffprobePath == null) {
          await initialize();
        }

        if (_ffprobePath != null) {
          return await _getDetailedInfo(filePath, fileSize, format);
        }
      }

      // Fallback
      return _getBasicInfo(filePath, fileSize, format);
    } catch (e) {
      if (kDebugMode) print('AudioInfoService error: $e');
      return null;
    }
  }

  /// Get audio info using FFprobeKit on mobile
  Future<AudioInfo?> _getMobileInfo(
      String filePath, int fileSize, String format) async {
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final mediaInfo = session.getMediaInformation();

      if (mediaInfo == null) {
        return _getBasicInfo(filePath, fileSize, format);
      }

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
      default:
        return format.toLowerCase();
    }
  }

  /// Get basic info (mobile fallback)
  AudioInfo _getBasicInfo(String filePath, int fileSize, String format) {
    final codec = _getCodecFromFormat(format);

    // Estimate bitrate from file size (very rough)
    // Assume 3-4 minutes average song
    int? estimatedBitrate;
    if (fileSize > 0) {
      // Rough estimate: fileSize / duration * 8 / 1000
      // Assume 3.5 min = 210 seconds
      estimatedBitrate = ((fileSize * 8) / 210 / 1000).round();
    }

    return AudioInfo(
      format: format,
      codec: codec,
      bitrate: estimatedBitrate,
      sampleRate: format == 'FLAC' ? 44100 : null, // Assume for FLAC
      channels: 2, // Assume stereo
      bitDepth: format == 'FLAC' ? 16 : null,
      fileSize: fileSize,
    );
  }

  /// Get detailed info using ffprobe
  Future<AudioInfo> _getDetailedInfo(
      String filePath, int fileSize, String format) async {
    try {
      final result = await Process.run(
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
      );

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
}
