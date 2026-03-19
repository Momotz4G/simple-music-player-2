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
  }

  Future<void> clearCache() async {
    await init();
    if (await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create(recursive: true);
    }
  }
}
