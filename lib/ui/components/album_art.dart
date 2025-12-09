import 'dart:typed_data';
import 'package:flutter/material.dart';

class AlbumArt extends StatelessWidget {
  final double size;
  final double radius;
  final Color? color;
  final Uint8List? bytes;

  const AlbumArt({
    super.key,
    this.size = 50,
    this.radius = 8,
    this.color,
    this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    // 1. If we have real image data, show the Real Album Art
    if (bytes != null && bytes!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          // Keep the same shadow as your design for consistency
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.memory(
            bytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      );
    }

    // 2. Otherwise, show your Gradient Placeholder (Your Design)
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color ?? Theme.of(context).primaryColor.withOpacity(0.8),
            (color ?? Theme.of(context).primaryColor).withOpacity(0.4),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }
}
