import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import '../../services/art_cache_service.dart';

class SmartArt extends StatefulWidget {
  final String path;
  final double size;
  final double? borderRadius;
  final String? onlineArtUrl;

  // 🚀 STATIC CACHES
  static final Map<String, Uint8List?> _cache = {};
  static final Map<String, File> _knownDiskCache = {};
  static final Set<String> _nonExistentPaths = {};

  // 🚀 GLOBAL VERSION: Incremented on invalidation to force rebuilds
  static int _globalVersion = 0;
  // Per-path version tracking
  static final Map<String, int> _pathVersions = {};

  static bool isCached(String path) {
    return _cache.containsKey(path) || _knownDiskCache.containsKey(path);
  }

  // 🚀 INVALIDATE: Clear all caches AND bump version so widgets rebuild
  static void invalidateCache(String path) {
    _cache.remove(path);
    _knownDiskCache.remove(path);
    _nonExistentPaths.remove(path);
    _globalVersion++;
    _pathVersions[path] = _globalVersion;
    // Also clear Flutter's image cache for this file
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
    _localVersion = SmartArt._pathVersions[widget.path] ?? 0;
  }

  @override
  void didUpdateWidget(covariant SmartArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentPathVersion = SmartArt._pathVersions[widget.path] ?? 0;
    if (currentPathVersion != _localVersion || widget.path != oldWidget.path) {
      _localVersion = currentPathVersion;
      // Force state change to trigger rebuild with new FutureBuilder
      setState(() {});
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
    if (SmartArt._cache.containsKey(widget.path)) {
      return _buildImage(SmartArt._cache[widget.path]);
    }

    // CHECK KNOWN DISK CACHE
    if (SmartArt._knownDiskCache.containsKey(widget.path)) {
      return _buildFileImage(SmartArt._knownDiskCache[widget.path]!);
    }

    // SKIP non-existent paths
    if (SmartArt._nonExistentPaths.contains(widget.path)) {
      return _buildPlaceholder();
    }

    return _buildFileArt();
  }

  Widget _buildFileArt() {
    return FutureBuilder<File?>(
      // 🚀 KEY includes version to force new Future on invalidation
      key: ValueKey('disk_${widget.path}_$_localVersion'),
      future: ArtCacheService().getCachedArt(widget.path),
      builder: (context, cacheSnapshot) {
        if (cacheSnapshot.hasData && cacheSnapshot.data != null) {
          SmartArt._knownDiskCache[widget.path] = cacheSnapshot.data!;
          return _buildFileImage(cacheSnapshot.data!);
        }

        if (cacheSnapshot.connectionState != ConnectionState.done) {
          return _buildPlaceholder();
        }

        // DISK CACHE MISS: Fallback
        return FutureBuilder<bool>(
          future: File(widget.path).exists(),
          builder: (context, existsSnapshot) {
            if (existsSnapshot.connectionState != ConnectionState.done) {
              return _buildPlaceholder();
            }

            if (existsSnapshot.data != true) {
              SmartArt._nonExistentPaths.add(widget.path);
              return _buildPlaceholder();
            }

            return FutureBuilder<Metadata?>(
              future: MetadataGod.readMetadata(file: widget.path),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data?.picture != null) {
                  final bytes = snapshot.data!.picture!.data;
                  SmartArt._cache[widget.path] = bytes;
                  ArtCacheService().saveArt(widget.path, bytes);
                  return _buildImage(bytes);
                }
                return _buildPlaceholder();
              },
            );
          },
        );
      },
    );
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
