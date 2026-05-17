import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'package:crypto/crypto.dart';

class ArtCacheService {
  static final ArtCacheService _instance = ArtCacheService._internal();
  factory ArtCacheService() => _instance;
  ArtCacheService._internal();

  Directory? _cacheDir;

  Future<void> init() async {
    if (_cacheDir != null) return;
    final baseDir = await getTemporaryDirectory();
    _cacheDir = Directory(p.join(baseDir.path, 'album_arts'));
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  String _getCachePath(String songPath) {
    // Create a unique hash for the path
    final bytes = utf8.encode(p.canonicalize(songPath));
    final digest = sha1.convert(bytes);
    return p.join(_cacheDir!.path, '${digest.toString()}.jpg');
  }

  String _getNoArtFlagPath(String songPath) {
    final bytes = utf8.encode(p.canonicalize(songPath));
    final digest = sha1.convert(bytes);
    return p.join(_cacheDir!.path, '${digest.toString()}.noart');
  }

  Future<File?> getCachedArt(String songPath) async {
    await init();
    final cachePath = _getCachePath(songPath);
    final file = File(cachePath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<void> saveArt(String songPath, Uint8List bytes) async {
    await init();
    final cachePath = _getCachePath(songPath);
    final file = File(cachePath);
    // 🚀 Always overwrite to update with newest data
    await file.writeAsBytes(bytes);
    // 🚀 Clear any stale .noart flag since we now have art
    await clearNoArtFlag(songPath);
  }

  /// 🚀 PERSISTENT NEGATIVE CACHE: Check if a song is known to have no art.
  /// Survives app restarts — prevents hundreds of FFI/disk scans on cold scroll.
  Future<bool> hasNoArtFlag(String songPath) async {
    await init();

    // 🛡️ SELF-HEALING: If the file is .m4a or .aac, clear any legacy .noart flags 
    // to force a fresh, robust FFmpeg/ffprobe tag scan (which replaces buggy MetadataGod).
    final ext = p.extension(songPath).toLowerCase();
    if (ext == '.m4a' || ext == '.aac') {
      await clearNoArtFlag(songPath);
      return false;
    }

    final flagPath = _getNoArtFlagPath(songPath);
    return File(flagPath).exists();
  }

  /// 🚀 Mark a song as having no album art (persistent across restarts).
  Future<void> setNoArtFlag(String songPath) async {
    await init();
    final flagPath = _getNoArtFlagPath(songPath);
    try {
      await File(flagPath).create();
    } catch (_) {}
  }

  /// 🚀 Remove the no-art flag (e.g. when user edits metadata and adds art).
  Future<void> clearNoArtFlag(String songPath) async {
    await init();
    final flagPath = _getNoArtFlagPath(songPath);
    try {
      final file = File(flagPath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> clearCache() async {
    await init();
    if (await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create(recursive: true);
    }
  }
}
