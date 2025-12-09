import 'package:flutter/material.dart';
import 'smart_art.dart';

class PlaylistCollage extends StatelessWidget {
  // Now accepts file paths instead of bytes
  final List<String> imagePaths;
  final List<String?>? onlineArtUrls;
  final double size;

  const PlaylistCollage({
    super.key,
    required this.imagePaths,
    this.onlineArtUrls,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // 1. EMPTY STATE
    if (imagePaths.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: const Color(0xFF1C1C1C), // Dark grey
        child: Icon(Icons.music_note, size: size * 0.4, color: Colors.white12),
      );
    }

    final urls = onlineArtUrls ?? List<String?>.filled(imagePaths.length, null);

    // 2. SINGLE IMAGE (or duplicates)
    // Check if all images are effectively the same (e.g. same album)
    // We check if all non-empty paths/urls are identical.
    bool allSame = false;
    if (imagePaths.isNotEmpty) {
      final firstPath = imagePaths[0];
      final firstUrl = urls.isNotEmpty ? urls[0] : null;

      // Check if every other item matches the first one
      allSame = true;
      for (int i = 1; i < imagePaths.length; i++) {
        final path = imagePaths[i];
        final url = urls.length > i ? urls[i] : null;
        if (path != firstPath || url != firstUrl) {
          allSame = false;
          break;
        }
      }
    }

    if (imagePaths.length == 1 || allSame) {
      return SmartArt(
          path: imagePaths[0],
          onlineArtUrl: urls.isNotEmpty ? urls[0] : null,
          size: size,
          borderRadius: 0);
    }

    // 3. GRID (2x2)
    // We define exactly 4 slots.
    final List<String> slots = List.filled(4, "");
    final List<String?> urlSlots = List.filled(4, null);

    // Fill slots with available image paths
    for (int i = 0; i < 4; i++) {
      if (i < imagePaths.length) {
        slots[i] = imagePaths[i];
        urlSlots[i] = urls.length > i ? urls[i] : null;
      } else {
        // If we run out of images, reuse previous ones to fill the grid aesthetically
        // e.g. [A, B] -> [A, B, A, B]
        slots[i] = imagePaths[i % imagePaths.length];
        urlSlots[i] = urls.isNotEmpty ? urls[i % urls.length] : null;
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildTile(slots[0], urlSlots[0])),
                Expanded(child: _buildTile(slots[1], urlSlots[1])),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildTile(slots[2], urlSlots[2])),
                Expanded(child: _buildTile(slots[3], urlSlots[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(String path, String? url) {
    if (path.isEmpty) {
      return Container(color: const Color(0xFF1C1C1C));
    }
    // SmartArt handles the loading, caching, and display
    return SmartArt(
      path: path,
      onlineArtUrl: url, // PASS URL
      // We set a smaller size for the grid tiles to save memory on the cache
      size: size / 2,
      borderRadius: 0,
    );
  }
}
