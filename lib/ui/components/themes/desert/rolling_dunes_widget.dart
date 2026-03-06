import 'dart:math';
import 'package:flutter/material.dart';

class RollingDunesWidget extends StatelessWidget {
  const RollingDunesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DunesPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _DunesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 3 Layers of dunes
    _drawDuneLayer(
      canvas,
      size,
      heightOffset: size.height * 0.65,
      amplitude: 60,
      phase: 0.0,
      color: const Color(0xFFD35400), // Darkest, furthest back
    );

    _drawDuneLayer(
      canvas,
      size,
      heightOffset: size.height * 0.75,
      amplitude: 80,
      phase: pi / 3,
      color: const Color(0xFFE67E22), // Midground
    );

    _drawDuneLayer(
      canvas,
      size,
      heightOffset: size.height * 0.85,
      amplitude: 100,
      phase: pi / 1.5,
      color: const Color(0xFFF39C12), // Foreground, lightest
    );
  }

  void _drawDuneLayer(
    Canvas canvas,
    Size size, {
    required double heightOffset,
    required double amplitude,
    required double phase,
    required Color color,
  }) {
    final Path path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, heightOffset);

    // Create a smooth, rolling dune curve using sine waves
    for (double x = 0; x <= size.width; x++) {
      // Wavelength based on screen width
      final double waveLength = size.width * 0.8;
      final double y =
          heightOffset + sin((x / waveLength * pi * 2) + phase) * amplitude;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    // Subtle gradient for depth and lighting (sun highlights top edges)
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color, // Highlight color at the crest
          color.withValues(alpha: 0.8), // Slightly darker at the base
          const Color(0xFF8E44AD)
              .withValues(alpha: 0.4), // Deep purple shadow near the bottom
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, heightOffset - amplitude, size.width,
          size.height - (heightOffset - amplitude)))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DunesPainter oldDelegate) => false;
}
