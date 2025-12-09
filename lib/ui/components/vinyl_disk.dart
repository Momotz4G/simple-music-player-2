import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'smart_art.dart';

class VinylDisk extends StatefulWidget {
  final String? artPath; // CHANGED from Uint8List artBytes
  final String? onlineArtUrl;
  final bool isPlaying;

  const VinylDisk({
    super.key,
    required this.artPath,
    this.onlineArtUrl,
    required this.isPlaying,
  });

  @override
  State<VinylDisk> createState() => _VinylDiskState();
}

class _VinylDiskState extends State<VinylDisk>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // Slow spin
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(VinylDisk oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: child,
        );
      },
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
          // The Vinyl Grooves (Outer Ring)
          border: Border.all(color: const Color(0xFF1E1E1E), width: 10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Album Art (Circular)
            ClipOval(
              child: widget.artPath != null
                  ? SmartArt(
                      path: widget.artPath!,
                      size: 200, // PRESERVED INNER ART SIZE
                      borderRadius: 0, // ClipOval handles the shape
                      onlineArtUrl: widget.onlineArtUrl,
                    )
                  : Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[900],
                      child: const Icon(Icons.music_note,
                          color: Colors.white24, size: 80),
                    ),
            ),

            // Center Hole (Spindle)
            Container(
              width: 15,
              height: 15,
              decoration: const BoxDecoration(
                color: Colors.white, // White spindle
                shape: BoxShape.circle,
              ),
            ),

            // Center Hole (Dark inner)
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
