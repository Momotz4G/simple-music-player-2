import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import '../../services/art_cache_service.dart';

class SmartArt extends StatelessWidget {
  final String path;
  final double size;
  final double? borderRadius;
  final String? onlineArtUrl; // Fallback URL

  // 1. STATIC CACHE (Moved inside the class)
  static final Map<String, Uint8List?> _cache = {};

  // 🚀 DISK CACHE MAP: Track which paths we ALREADY know have cache files
  // This avoids calling ArtCacheService().getCachedArt() every rebuild.
  static final Map<String, File> _knownDiskCache = {};

  // Track paths that don't exist to avoid repeated file checks
  static final Set<String> _nonExistentPaths = {};

  // 2. HELPER TO CHECK CACHE
  static bool isCached(String path) {
    return _cache.containsKey(path) || _knownDiskCache.containsKey(path);
  }

  // 3. INVALIDATE CACHE
  static void invalidateCache(String path) {
    _cache.remove(path);
    _knownDiskCache.remove(path);
    _nonExistentPaths.remove(path);
  }

  const SmartArt({
    super.key,
    required this.path,
    this.size = 50,
    this.borderRadius,
    this.onlineArtUrl,
  });

  @override
  Widget build(BuildContext context) {
    // PRIORITIZE ONLINE ART (Fixes YouTube Thumbnail issue)
    if (onlineArtUrl != null && onlineArtUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? 8),
        child: Image.network(
          onlineArtUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * 2).toInt(),
          errorBuilder: (_, __, ___) => _buildFileArt(),
        ),
      );
    }

    // 🚀 CHECK IN-MEMORY BYTES FIRST
    if (_cache.containsKey(path)) {
      return _buildImage(_cache[path]);
    }

    // 🚀 CHECK KNOWN DISK CACHE NEXT (Zero-Latency Rendering)
    if (_knownDiskCache.containsKey(path)) {
      return _buildFileImage(_knownDiskCache[path]!);
    }

    // 🚀 SKIP: If path is known to not exist (e.g., Spotify imports)
    if (_nonExistentPaths.contains(path)) {
      return _buildPlaceholder();
    }

    return _buildFileArt();
  }

  Widget _buildFileArt() {
    return FutureBuilder<File?>(
      future: ArtCacheService().getCachedArt(path),
      builder: (context, cacheSnapshot) {
        // If we just found it in this builder, save it to the known map for next time
        if (cacheSnapshot.hasData && cacheSnapshot.data != null) {
          _knownDiskCache[path] = cacheSnapshot.data!;
          return _buildFileImage(cacheSnapshot.data!);
        }

        if (cacheSnapshot.connectionState != ConnectionState.done) {
          return _buildPlaceholder();
        }

        // 🚀 DISK CACHE MISS: Original fallback logic
        return FutureBuilder<bool>(
          future: File(path).exists(),
          builder: (context, existsSnapshot) {
            if (existsSnapshot.connectionState != ConnectionState.done) {
              return _buildPlaceholder();
            }

            if (existsSnapshot.data != true) {
              _nonExistentPaths.add(path);
              return _buildPlaceholder();
            }

            // Still read metadata if no cache exists (e.g. first scan)
            return FutureBuilder<Metadata?>(
              future: MetadataGod.readMetadata(file: path),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data?.picture != null) {
                  final bytes = snapshot.data!.picture!.data;
                  _cache[path] = bytes;
                  // Save to disk cache for NEXT time
                  ArtCacheService().saveArt(path, bytes);
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

  // 🚀 Helper for Rendering from Disk Cache File
  Widget _buildFileImage(File file) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? 8),
      child: Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(), // Optimize memory usage
        gaplessPlayback: true, // 🚀 PREVENTS FLICKERING on rebuild
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      ),
    );
  }

  Widget _buildImage(Uint8List? bytes) {
    if (bytes == null) {
      // FALLBACK TO ONLINE URL (For Cached Nulls)
      if (onlineArtUrl != null && onlineArtUrl!.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius ?? 8),
          child: Image.network(
            onlineArtUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 2).toInt(),
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        );
      }
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? 8),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(),
        gaplessPlayback: true, // 🚀 PREVENTS FLICKERING
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(borderRadius ?? 8),
      ),
      child: Icon(
        Icons.music_note,
        color: Colors.white24,
        size: size * 0.5,
      ),
    );
  }
}
