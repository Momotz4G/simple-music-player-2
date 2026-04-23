import 'dart:io';
import 'package:path/path.dart' as p;

/// Represents a single track parsed from a CUE sheet.
class CueTrack {
  final String title;
  final String performer;
  final String audioFileName; // The audio file referenced in the CUE FILE command
  final int trackNumber;
  final Duration startOffset;
  final Duration? endOffset; // null = play to end of file (last track in FILE block)
  final String? albumTitle;
  final String? albumPerformer;
  final String? genre;
  final String? year;
  final int? discNumber;

  CueTrack({
    required this.title,
    required this.performer,
    required this.audioFileName,
    required this.trackNumber,
    required this.startOffset,
    this.endOffset,
    this.albumTitle,
    this.albumPerformer,
    this.genre,
    this.year,
    this.discNumber,
  });

  /// Duration of this individual track segment.
  Duration? get trackDuration {
    if (endOffset == null) return null;
    return endOffset! - startOffset;
  }
}

/// The CUE path separator used to encode virtual track paths.
/// Format: `audioFilePath||cue||startMs||endMs`
/// endMs of -1 means "play to end of file".
///
/// This separator uses `||` which is INVALID in Windows, macOS, and Linux filenames,
/// so it can never collide with a real file path.
/// NOTE: Lowercase `cue` is used because `p.canonicalize()` on Windows lowercases
/// the entire path, which would break detection if we used uppercase.
class CuePath {
  static const String separator = '||cue||';

  /// Creates a virtual CUE path encoding the audio file path and track offsets.
  static String encode(String audioFilePath, Duration startOffset, Duration? endOffset) {
    final startMs = startOffset.inMilliseconds;
    final endMs = endOffset?.inMilliseconds ?? -1;
    return '$audioFilePath$separator$startMs||$endMs';
  }

  /// Returns true if the given file path is a CUE-encoded virtual path.
  /// Case-insensitive to handle path canonicalization on Windows.
  static bool isCuePath(String filePath) {
    return filePath.toLowerCase().contains(separator);
  }

  /// Extracts the real audio file path from a CUE virtual path.
  static String extractAudioPath(String cuePath) {
    final lowerPath = cuePath.toLowerCase();
    final sepIndex = lowerPath.indexOf(separator);
    if (sepIndex < 0) return cuePath;
    return cuePath.substring(0, sepIndex);
  }

  /// Extracts the start offset from a CUE virtual path.
  static Duration extractStartOffset(String cuePath) {
    final lowerPath = cuePath.toLowerCase();
    final sepIndex = lowerPath.indexOf(separator);
    if (sepIndex < 0) return Duration.zero;
    final suffix = cuePath.substring(sepIndex + separator.length);
    final parts = suffix.split('||');
    if (parts.isEmpty) return Duration.zero;
    final ms = int.tryParse(parts[0]) ?? 0;
    return Duration(milliseconds: ms);
  }

  /// Extracts the end offset from a CUE virtual path.
  /// Returns null if the track plays to the end of the file.
  static Duration? extractEndOffset(String cuePath) {
    final lowerPath = cuePath.toLowerCase();
    final sepIndex = lowerPath.indexOf(separator);
    if (sepIndex < 0) return null;
    final suffix = cuePath.substring(sepIndex + separator.length);
    final parts = suffix.split('||');
    if (parts.length < 2) return null;
    final ms = int.tryParse(parts[1]) ?? -1;
    if (ms < 0) return null;
    return Duration(milliseconds: ms);
  }
}

/// Service to parse CUE sheet files and extract track metadata.
///
/// CUE sheets are text files that describe the track layout of an audio CD
/// or a single large audio file (FLAC, WAV, APE, etc.).
///
/// Supported CUE commands:
/// - `REM GENRE`, `REM DATE`, `REM DISCNUMBER` — album-level metadata
/// - `PERFORMER` — album or track artist
/// - `TITLE` — album or track title
/// - `FILE` — the audio file name
/// - `TRACK` — track number
/// - `INDEX 01` — track start time (MM:SS:FF, where FF = 1/75th second)
class CueParserService {
  static final CueParserService _instance = CueParserService._internal();
  factory CueParserService() => _instance;
  CueParserService._internal();

  /// Parses a CUE file and returns a list of [CueTrack] entries.
  ///
  /// [cueFilePath] is the absolute path to the `.cue` file.
  /// The audio file path is resolved relative to the CUE file's directory.
  Future<List<CueTrack>> parseCueFile(String cueFilePath) async {
    try {
      final file = File(cueFilePath);
      if (!await file.exists()) return [];

      final content = await _readCueFile(file);
      if (content.isEmpty) return [];

      final cueDir = p.dirname(cueFilePath);
      return _parseCueContent(content, cueDir);
    } catch (e) {
      print('⚠️ CUE Parser Error: $e');
      return [];
    }
  }

  /// Tries multiple encodings to read the CUE file content.
  /// CUE files from different regions may use UTF-8, Latin-1, or Shift-JIS.
  Future<String> _readCueFile(File file) async {
    try {
      // Try UTF-8 first (most common for modern CUE files)
      return await file.readAsString();
    } catch (_) {
      try {
        // Fallback: Read as raw bytes and decode as Latin-1 (ISO 8859-1)
        final bytes = await file.readAsBytes();
        return String.fromCharCodes(bytes);
      } catch (_) {
        return '';
      }
    }
  }

  /// Parses the raw CUE sheet text content into a list of [CueTrack].
  List<CueTrack> _parseCueContent(String content, String cueDir) {
    final lines = content.split(RegExp(r'\r?\n'));

    // Album-level metadata
    String? albumTitle;
    String? albumPerformer;
    String? genre;
    String? year;
    int? discNumber;

    // Current FILE block
    String? currentAudioFile;

    // Current TRACK being parsed
    int? currentTrackNumber;
    String? currentTrackTitle;
    String? currentTrackPerformer;
    Duration? currentTrackStart;

    // Collected tracks with raw offsets (we calculate end offsets after)
    final List<_RawTrack> rawTracks = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // --- Album-level commands (before any TRACK) ---
      if (line.toUpperCase().startsWith('REM GENRE ')) {
        genre = _unquote(line.substring(10).trim());
      } else if (line.toUpperCase().startsWith('REM DATE ')) {
        year = _unquote(line.substring(9).trim());
      } else if (line.toUpperCase().startsWith('REM DISCNUMBER ')) {
        discNumber = int.tryParse(line.substring(15).trim());
      } else if (line.toUpperCase().startsWith('PERFORMER ')) {
        final value = _unquote(line.substring(10).trim());
        if (currentTrackNumber != null) {
          currentTrackPerformer = value;
        } else {
          albumPerformer = value;
        }
      } else if (line.toUpperCase().startsWith('TITLE ')) {
        final value = _unquote(line.substring(6).trim());
        if (currentTrackNumber != null) {
          currentTrackTitle = value;
        } else {
          albumTitle = value;
        }
      } else if (line.toUpperCase().startsWith('FILE ')) {
        // Flush any pending track from previous FILE block
        if (currentTrackNumber != null && currentTrackStart != null) {
          rawTracks.add(_RawTrack(
            title: currentTrackTitle ?? 'Track $currentTrackNumber',
            performer: currentTrackPerformer ?? albumPerformer ?? 'Unknown Artist',
            audioFile: currentAudioFile ?? '',
            trackNumber: currentTrackNumber!,
            startOffset: currentTrackStart!,
            albumTitle: albumTitle,
            albumPerformer: albumPerformer,
            genre: genre,
            year: year,
            discNumber: discNumber,
          ));
          currentTrackNumber = null;
          currentTrackTitle = null;
          currentTrackPerformer = null;
          currentTrackStart = null;
        }

        // Parse FILE command: FILE "filename.flac" WAVE
        currentAudioFile = _parseFileCommand(line, cueDir);
      } else if (line.toUpperCase().startsWith('TRACK ')) {
        // Flush previous track
        if (currentTrackNumber != null && currentTrackStart != null) {
          rawTracks.add(_RawTrack(
            title: currentTrackTitle ?? 'Track $currentTrackNumber',
            performer: currentTrackPerformer ?? albumPerformer ?? 'Unknown Artist',
            audioFile: currentAudioFile ?? '',
            trackNumber: currentTrackNumber!,
            startOffset: currentTrackStart!,
            albumTitle: albumTitle,
            albumPerformer: albumPerformer,
            genre: genre,
            year: year,
            discNumber: discNumber,
          ));
        }

        // Parse TRACK command: TRACK 01 AUDIO
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          currentTrackNumber = int.tryParse(parts[1]);
        }
        currentTrackTitle = null;
        currentTrackPerformer = null;
        currentTrackStart = null;
      } else if (line.toUpperCase().startsWith('INDEX 01 ')) {
        // INDEX 01 MM:SS:FF — this is the actual play start
        final timestamp = line.substring(9).trim();
        currentTrackStart = _parseTimestamp(timestamp);
      }
      // INDEX 00 (pregap) is intentionally ignored — we only care about INDEX 01
    }

    // Flush the last track
    if (currentTrackNumber != null && currentTrackStart != null) {
      rawTracks.add(_RawTrack(
        title: currentTrackTitle ?? 'Track $currentTrackNumber',
        performer: currentTrackPerformer ?? albumPerformer ?? 'Unknown Artist',
        audioFile: currentAudioFile ?? '',
        trackNumber: currentTrackNumber!,
        startOffset: currentTrackStart!,
        albumTitle: albumTitle,
        albumPerformer: albumPerformer,
        genre: genre,
        year: year,
        discNumber: discNumber,
      ));
    }

    // Calculate end offsets: each track ends where the next one starts.
    // The last track of each FILE block has endOffset = null (play to EOF).
    final List<CueTrack> result = [];
    for (int i = 0; i < rawTracks.length; i++) {
      final raw = rawTracks[i];
      Duration? endOffset;

      // If there's a next track AND it references the SAME audio file, use its start as our end
      if (i + 1 < rawTracks.length && rawTracks[i + 1].audioFile == raw.audioFile) {
        endOffset = rawTracks[i + 1].startOffset;
      }

      // Skip tracks with no audio file
      if (raw.audioFile.isEmpty) continue;

      result.add(CueTrack(
        title: raw.title,
        performer: raw.performer,
        audioFileName: raw.audioFile,
        trackNumber: raw.trackNumber,
        startOffset: raw.startOffset,
        endOffset: endOffset,
        albumTitle: raw.albumTitle,
        albumPerformer: raw.albumPerformer,
        genre: raw.genre,
        year: raw.year,
        discNumber: raw.discNumber,
      ));
    }

    return result;
  }

  /// Parses a CUE FILE command and resolves the audio file path.
  /// Example: FILE "album.flac" WAVE
  String? _parseFileCommand(String line, String cueDir) {
    // Extract the filename between quotes
    final quoteStart = line.indexOf('"');
    final quoteEnd = line.lastIndexOf('"');
    
    String fileName;
    if (quoteStart >= 0 && quoteEnd > quoteStart) {
      fileName = line.substring(quoteStart + 1, quoteEnd);
    } else {
      // No quotes — take the second token (after FILE)
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) return null;
      fileName = parts[1];
    }

    // Resolve relative to CUE file directory
    final resolvedPath = p.join(cueDir, fileName);
    
    // Try the exact name first
    if (File(resolvedPath).existsSync()) {
      return p.canonicalize(resolvedPath);
    }

    // Case-insensitive fallback: search the directory for a matching filename
    try {
      final dir = Directory(cueDir);
      if (dir.existsSync()) {
        final lowerName = fileName.toLowerCase();
        for (final entity in dir.listSync()) {
          if (entity is File && p.basename(entity.path).toLowerCase() == lowerName) {
            return p.canonicalize(entity.path);
          }
        }
      }
    } catch (_) {}

    // Audio file not found — return the resolved path anyway (will be filtered out later)
    return null;
  }

  /// Parses a CUE timestamp in MM:SS:FF format.
  /// FF = frames, where 1 frame = 1/75th of a second.
  static Duration _parseTimestamp(String timestamp) {
    final parts = timestamp.split(':');
    if (parts.length < 3) return Duration.zero;

    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    final frames = int.tryParse(parts[2]) ?? 0;

    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: (frames * 1000 ~/ 75), // 75 frames per second
    );
  }

  /// Removes surrounding double quotes from a string.
  static String _unquote(String value) {
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  /// Returns all `.cue` files found in a directory.
  /// If [recursive] is true, searches subdirectories as well.
  static Future<List<String>> findCueFiles(String directoryPath, {bool recursive = false}) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    final List<String> cueFiles = [];
    await for (final entity in dir.list(recursive: recursive, followLinks: false)) {
      if (entity is File && p.extension(entity.path).toLowerCase() == '.cue') {
        cueFiles.add(entity.path);
      }
    }
    return cueFiles;
  }
}

/// Internal helper for building tracks before end-offset calculation.
class _RawTrack {
  final String title;
  final String performer;
  final String audioFile;
  final int trackNumber;
  final Duration startOffset;
  final String? albumTitle;
  final String? albumPerformer;
  final String? genre;
  final String? year;
  final int? discNumber;

  _RawTrack({
    required this.title,
    required this.performer,
    required this.audioFile,
    required this.trackNumber,
    required this.startOffset,
    this.albumTitle,
    this.albumPerformer,
    this.genre,
    this.year,
    this.discNumber,
  });
}
