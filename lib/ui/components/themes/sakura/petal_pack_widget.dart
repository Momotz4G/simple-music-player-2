import 'dart:math';
import 'package:flutter/material.dart';

class PetalPackWidget extends StatelessWidget {
  const PetalPackWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PetalPackPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _PetalPackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(123);
    final paint = Paint()..style = PaintingStyle.fill;

    final double yBase = size.height;

    // Draw many small pink ovals/piles at the bottom
    for (int i = 0; i < 60; i++) {
      final double x = random.nextDouble() * size.width;
      final double yShift = random.nextDouble() * 10;
      final double w = 8.0 + random.nextDouble() * 12;
      final double h = 4.0 + random.nextDouble() * 6;

      final List<Color> colors = [
        const Color(0xFFFFB7C5),
        const Color(0xFFFFC0CB),
        const Color(0xFFFFD1DC),
      ];

      paint.color = colors[random.nextInt(colors.length)]
          .withOpacity(0.6 + random.nextDouble() * 0.3);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, yBase - yShift - 5),
          width: w,
          height: h,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
