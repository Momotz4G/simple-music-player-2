import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';

class SmartArt extends StatelessWidget {
  final String path;
  final double size;
  final double? borderRadius;
  final String? onlineArtUrl; // Fallback URL

  // 1. STATIC CACHE (Moved inside the class)
  static final Map<String, Uint8List?> _cache = {};

  // 2. HELPER TO CHECK CACHE
  static bool isCached(String path) {
    return _cache.containsKey(path) && _cache[path] != null;
  }

  // 3. INVALIDATE CACHE
  static void invalidateCache(String path) {
    _cache.remove(path);
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
          errorBuilder: (_, __, ___) => _buildFileArt(),
        ),
      );
    }

    // Check internal static cache
    if (_cache.containsKey(path)) {
      return _buildImage(_cache[path]);
    }

    return _buildFileArt();
  }

  Widget _buildFileArt() {
    return FutureBuilder<Metadata?>(
      future: MetadataGod.readMetadata(file: path),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.picture != null) {
          final bytes = snapshot.data!.picture!.data;
          // Save to static cache
          _cache[path] = bytes;
          return _buildImage(bytes);
        }
        return _buildPlaceholder();
      },
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
        gaplessPlayback: true,
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
