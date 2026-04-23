import 'package:flutter/material.dart';

class WetGroundWidget extends StatelessWidget {
  const WetGroundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WetGroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _WetGroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double yBase = size.height;

    // 1. Dark Wet Pavement (Glossy)
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.1),
          Colors.black.withValues(alpha: 0.4),
        ],
      ).createShader(Rect.fromLTWH(0, yBase - 40, size.width, 40));

    final Path groundPath = Path()
      ..moveTo(0, yBase - 15)
      ..quadraticBezierTo(size.width / 2, yBase - 25, size.width, yBase - 15)
      ..lineTo(size.width, yBase)
      ..lineTo(0, yBase)
      ..close();
    canvas.drawPath(groundPath, paint);

    // 2. Highlilghts / Reflections (Puddles)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);

    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.2, yBase - 12, 100, 8), highlightPaint);
    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.7, yBase - 10, 80, 6), highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
