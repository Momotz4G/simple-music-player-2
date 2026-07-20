import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart' show Metadata;
import 'package:path/path.dart' as p;
import '../../services/metadata_service.dart';
import '../../services/art_cache_service.dart';
import '../../services/cue_parser_service.dart';

class SmartArt extends StatefulWidget {
  final String path;
  final double size;
  final double? borderRadius;
  final String? onlineArtUrl;

  // STATIC CACHES
  static final Map<String, Uint8List?> _cache = {};
  static final Map<String, File> _knownDiskCache = {};
  static final Set<String> _nonExistentPaths = {};
  static final Set<String> _noEmbeddedArtPaths = {}; // Negative Cache
  static final Set<String> _noArtPaths = {}; // Absolute Negative Cache (No embedded, no folder art)

  // GLOBAL VERSION: Incremented on invalidation to force rebuilds
  static int _globalVersion = 0;
  // Per-path version tracking
  static final Map<String, int> _pathVersions = {};

  static bool isCached(String path) {
    final k = p.canonicalize(path);
    return _cache.containsKey(k) || _knownDiskCache.containsKey(k);
  }

  // INVALIDATE: Clear all caches AND bump version so widgets rebuild
  static void invalidateCache(String path) {
    final k = p.canonicalize(path);
    _cache.remove(k);
    _knownDiskCache.remove(k);
    _nonExistentPaths.remove(k);
    _noEmbeddedArtPaths.remove(k); // Clear negative cache too
    _noArtPaths.remove(k); // Clear absolute negative cache
    _globalVersion++;
    _pathVersions[k] = _globalVersion;
    // Clear persistent negative cache flag
    ArtCacheService().clearNoArtFlag(path);
    // Also clear Flutter's image cache for this file
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  static void clearAllMemoryCaches() {
    _cache.clear();
    _knownDiskCache.clear();
    _nonExistentPaths.clear();
    _noEmbeddedArtPaths.clear();
    _noArtPaths.clear();
    _pathVersions.clear();
    _globalVersion++;
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  const SmartArt({
    super.key,
    required this.path,
    this.size = 50,
    this.borderRadius,
    this.onlineArtUrl,
  });

  @override
  State<SmartArt> createState() => _SmartArtState();
}

class _SmartArtState extends State<SmartArt> {
  int _localVersion = 0;

  @override
  void initState() {
    super.initState();
    _localVersion = SmartArt._pathVersions[p.canonicalize(widget.path)] ?? SmartArt._globalVersion;
  }

  @override
  void didUpdateWidget(covariant SmartArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _localVersion = SmartArt._pathVersions[p.canonicalize(widget.path)] ?? SmartArt._globalVersion;
    } else {
      final latestVersion = SmartArt._pathVersions[p.canonicalize(widget.path)] ?? SmartArt._globalVersion;
      if (_localVersion != latestVersion) {
        setState(() {
          _localVersion = latestVersion;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if our version is stale (another widget invalidated this path)
    final currentPathVersion = SmartArt._pathVersions[widget.path] ?? 0;
    if (currentPathVersion != _localVersion) {
      _localVersion = currentPathVersion;
    }

    // PRIORITIZE ONLINE ART
    if (widget.onlineArtUrl != null && widget.onlineArtUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
        child: Image.network(
          widget.onlineArtUrl!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          cacheWidth: (widget.size * 2).toInt(),
          errorBuilder: (_, __, ___) => _buildFileArt(),
        ),
      );
    }

    // CHECK IN-MEMORY BYTES
    final k = p.canonicalize(widget.path);
    if (SmartArt._cache.containsKey(k)) {
      return _buildImage(SmartArt._cache[k]);
    }

    // CHECK KNOWN DISK CACHE
    if (SmartArt._knownDiskCache.containsKey(k)) {
      return _buildFileImage(SmartArt._knownDiskCache[k]!);
    }

    // SKIP non-existent paths
    if (SmartArt._nonExistentPaths.contains(k)) {
      return _buildPlaceholder();
    }

    // SKIP paths proven to have no art
    if (SmartArt._noArtPaths.contains(k)) {
      return _buildPlaceholder();
    }

    return _buildFileArt();
  }

  Widget _buildFileArt() {
    return FutureBuilder<File?>(
      // KEY includes version to force new Future on invalidation
      key: ValueKey('disk_${widget.path}_$_localVersion'),
      future: ArtCacheService().getCachedArt(widget.path),
      builder: (context, cacheSnapshot) {
        final k = p.canonicalize(widget.path);
        if (cacheSnapshot.hasData && cacheSnapshot.data != null) {
          SmartArt._knownDiskCache[k] = cacheSnapshot.data!;
          return _buildFileImage(cacheSnapshot.data!);
        }

        if (cacheSnapshot.connectionState != ConnectionState.done) {
          return _buildPlaceholder();
        }

        // DISK CACHE MISS: Fallback
        return FutureBuilder<bool>(
          future: Future.wait([
            File(widget.path).exists(),
            ArtCacheService().hasNoArtFlag(widget.path),
          ]).then((results) {
            final exists = results[0];
            final hasNoArt = results[1];
            if (!exists) return false; // file doesn't exist
            if (hasNoArt) {
              // PERSISTENT NEGATIVE CACHE HIT: Skip all FFI/disk scans
              SmartArt._noArtPaths.add(widget.path);
              return false;
            }
            return true; // file exists and might have art
          }),
          builder: (context, existsSnapshot) {
            if (existsSnapshot.connectionState != ConnectionState.done) {
              return _buildPlaceholder();
            }

            final k = p.canonicalize(widget.path);
            if (existsSnapshot.data != true) {
              if (!SmartArt._noArtPaths.contains(k)) {
                SmartArt._nonExistentPaths.add(k);
              }
              return _buildPlaceholder();
            }

            // NEGATIVE CACHE CHECK: If we already scanned this file and found no art, skip ffprobe/metadata read!
            if (SmartArt._noEmbeddedArtPaths.contains(k)) {
              return FutureBuilder<File?>(
                future: _findFolderArt(widget.path),
                builder: (context, folderArtSnapshot) {
                  if (folderArtSnapshot.connectionState != ConnectionState.done) {
                    return _buildPlaceholder();
                  }
                  if (folderArtSnapshot.hasData && folderArtSnapshot.data != null) {
                    SmartArt._knownDiskCache[k] = folderArtSnapshot.data!;
                    return _buildFileImage(folderArtSnapshot.data!);
                  }
                  SmartArt._noArtPaths.add(k);
                  // Persist the negative result so it survives app restart
                  ArtCacheService().setNoArtFlag(widget.path);
                  return _buildPlaceholder();
                },
              );
            }

            return FutureBuilder<Metadata?>(
              future: MetadataService().readMetadata(widget.path),
              builder: (context, snapshot) {
                final k = p.canonicalize(widget.path);
                if (snapshot.hasData && snapshot.data?.picture != null) {
                  final bytes = snapshot.data!.picture!.data;
                  SmartArt._cache[k] = bytes;
                  ArtCacheService().saveArt(widget.path, bytes);
                  return _buildImage(bytes);
                }
                // Mark as having no embedded art to prevent future FFProbe loops
                SmartArt._noEmbeddedArtPaths.add(k);

                // FOLDER ART FALLBACK: If no embedded art, check directory for cover.jpg, folder.jpg, etc.
                return FutureBuilder<File?>(
                  future: _findFolderArt(widget.path),
                  builder: (context, folderArtSnapshot) {
                    if (folderArtSnapshot.connectionState != ConnectionState.done) {
                      return _buildPlaceholder();
                    }
                    if (folderArtSnapshot.hasData && folderArtSnapshot.data != null) {
                      SmartArt._knownDiskCache[k] = folderArtSnapshot.data!;
                      return _buildFileImage(folderArtSnapshot.data!);
                    }
                    SmartArt._noArtPaths.add(k);
                    // Persist the negative result so it survives app restart
                    ArtCacheService().setNoArtFlag(widget.path);
                    return _buildPlaceholder();
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Searches for common album art filenames in the song's directory.
  Future<File?> _findFolderArt(String songPath) async {
    try {
      // CUE SUPPORT: Resolve virtual path to real audio path for directory check
      final resolvedPath = CuePath.isCuePath(songPath) 
          ? CuePath.extractAudioPath(songPath) 
          : songPath;

      final file = File(resolvedPath);
      final directory = file.parent;
      if (!await directory.exists()) return null;

      final commonNames = [
        'cover', 'folder', 'album', 'front', 'art', 'scans'
      ];
      final extensions = ['.jpg', '.jpeg', '.png', '.webp'];

      final entities = await directory.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          final name = p.basenameWithoutExtension(entity.path).toLowerCase();
          final ext = p.extension(entity.path).toLowerCase();
          
          if (extensions.contains(ext)) {
            if (commonNames.any((cn) => name.contains(cn))) {
               return entity;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Widget _buildFileImage(File file) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
      child: Image.file(
        file,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        cacheWidth: (widget.size * 2).toInt(),
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      ),
    );
  }

  Widget _buildImage(Uint8List? bytes) {
    if (bytes == null) {
      if (widget.onlineArtUrl != null && widget.onlineArtUrl!.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
          child: Image.network(
            widget.onlineArtUrl!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            cacheWidth: (widget.size * 2).toInt(),
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        );
      }
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
      child: Image.memory(
        bytes,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        cacheWidth: (widget.size * 2).toInt(),
        gaplessPlayback: true,
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
      ),
      child: Icon(
        Icons.music_note,
        color: Colors.white24,
        size: widget.size * 0.5,
      ),
    );
  }
}
