import 'dart:math';
import 'package:flutter/material.dart';

class NeonSkyscrapersWidget extends StatelessWidget {
  const NeonSkyscrapersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SkyscraperPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _SkyscraperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(123);
    final double horizonY = size.height * 0.45;

    final Paint skyPaint = Paint()
      ..color = const Color(0xFF0A0A0A); // Dark base

    // Draw Skyscraper Silhouettes
    const int buildingCount = 8;
    for (int i = 0; i < buildingCount; i++) {
      final double width = 60.0 + random.nextDouble() * 100.0;
      final double height = 180.0 + random.nextDouble() * 250.0;
      final double x = (i * (size.width / buildingCount)) - 20;

      final buildingRect = Rect.fromLTWH(x, horizonY - height, width, height);

      // Base Silhouette
      canvas.drawRect(buildingRect, skyPaint);

      // Neon Windows/Signs
      _drawNeonWindows(canvas, buildingRect, random);
    }
  }

  void _drawNeonWindows(Canvas canvas, Rect rect, Random random) {
    final cyanPaint = Paint()..color = const Color(0xFF00FFFF).withOpacity(0.4);
    final magentaPaint = Paint()
      ..color = const Color(0xFFFF00FF).withOpacity(0.4);

    final int cols = 3 + random.nextInt(4);
    final int rows = 10 + random.nextInt(15);
    final double wWidth = rect.width / (cols * 2);
    final double wHeight = rect.height / (rows * 2);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (random.nextDouble() > 0.3) {
          final double wx = rect.left + (c * wWidth * 2) + wWidth / 2;
          final double wy = rect.top + (r * wHeight * 2) + wHeight / 2;
          final paint = random.nextBool() ? cyanPaint : magentaPaint;

          canvas.drawRect(Rect.fromLTWH(wx, wy, wWidth, wHeight), paint);

          // Occasional Glow
          if (random.nextDouble() > 0.8) {
            final glowPaint = Paint()
              ..color = paint.color.withOpacity(0.2)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
            canvas.drawRect(
                Rect.fromLTWH(wx - 2, wy - 2, wWidth + 4, wHeight + 4),
                glowPaint);
          }
        }
      }
    }

    // Antennas/Lights
    if (random.nextBool()) {
      final Paint skyPaint = Paint()..color = const Color(0xFF0A0A0A);
      canvas.drawRect(
          Rect.fromLTWH(rect.left + rect.width / 2 - 2, rect.top - 20, 4, 20),
          skyPaint);
      canvas.drawCircle(
          Offset(rect.left + rect.width / 2, rect.top - 20), 2, magentaPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
