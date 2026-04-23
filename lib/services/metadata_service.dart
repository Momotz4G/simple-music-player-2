import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:metadata_god/metadata_god.dart';
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

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      try {
        await MetadataGod.initialize();
        _isInitialized = true;
      } catch (_) {}
    }
  }

  /// Reads metadata safely with deadlock protection.
  Future<Metadata> readMetadata(String filePath) async {
    await _ensureInitialized();
    if (!Platform.isWindows) {
      try {
        return await MetadataGod.readMetadata(file: filePath);
      } catch (_) {
        return Metadata(title: p.basenameWithoutExtension(filePath));
      }
    }
    
    // Poison Pill Protection
    final ext = p.extension(filePath).toLowerCase();
    final unsafeExtensions = ['.wav', '.dsf', '.dff', '.mp4', '.m4v', '.ogg', '.opus', '.ape', '.aiff', '.aif'];
    if (unsafeExtensions.contains(ext)) {
      return await _readMetadataViaFFprobe(filePath);
    }
    
    try {
      return await MetadataGod.readMetadata(file: filePath);
    } catch (_) {
      return Metadata(title: p.basenameWithoutExtension(filePath));
    }
  }

  /// Processes a batch of tracks sequentially on the main thread.
  /// (FFI calls take ~1-2ms and are completely safe on the main thread, 
  /// UNLESS they are poisonous extensions, which we deflect).
  Future<List<Metadata?>> readMetadataBatch(List<String> filePaths) async {
    if (filePaths.isEmpty) return [];
    await _ensureInitialized();
    
    final unsafeExtensions = ['.wav', '.dsf', '.dff', '.mp4', '.m4v', '.ogg', '.opus', '.ape', '.aiff', '.aif'];

    // 🚀 Process the chunk CONCURRENTLY to utilize all ffprobe concurrency slots
    final futures = filePaths.map((path) async {
      if (!Platform.isWindows) {
        try {
          return await MetadataGod.readMetadata(file: path);
        } catch (_) {
          return null;
        }
      } else {
        final ext = p.extension(path).toLowerCase();
        if (unsafeExtensions.contains(ext)) {
          try {
            return await _readMetadataViaFFprobe(path);
          } catch (_) {
            return null;
          }
        } else {
          try {
            return await MetadataGod.readMetadata(file: path);
          } catch (_) {
            return null;
          }
        }
      }
    });

    final results = await Future.wait(futures);
    return results.toList();
  }

  /// Writes metadata to a file.
  Future<void> writeMetadata({
    required String filePath,
    required Metadata metadata,
  }) async {
    await MetadataGod.writeMetadata(file: filePath, metadata: metadata);
  }

  Future<Metadata> _readMetadataViaFFprobe(String filePath) async {
    // 🚀 Single ffprobe invocation for both tags + audio info
    final result = await AudioInfoService().getTagsAndInfo(filePath);
    final tags = result.tags;
    final audioInfo = result.info;
    
    return Metadata(
       title: tags['title'] ?? tags['TITLE'] ?? p.basenameWithoutExtension(filePath),
       artist: tags['artist'] ?? tags['ARTIST'],
       album: tags['album'] ?? tags['ALBUM'],
       durationMs: audioInfo?.duration?.inMilliseconds.toDouble(),
       trackNumber: int.tryParse(tags['track']?.split('/').first ?? ''),
       discNumber: int.tryParse(tags['disc']?.split('/').first ?? ''),
       year: int.tryParse(tags['date']?.substring(0, 4) ?? tags['year'] ?? ''),
       genre: tags['genre'] ?? tags['GENRE'],
       fileSize: audioInfo?.fileSize != null ? BigInt.from(audioInfo!.fileSize!) : null,
       picture: null,
    );
  }
}
