import 'package:flutter/material.dart';

class PumpkinPackWidget extends StatelessWidget {
  const PumpkinPackWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PumpkinPackPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _PumpkinPackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double yBase = size.height;

    final leafColors = [
      const Color(0xFFD35400),
      const Color(0xFF7E5109),
      const Color(0xFF6E2C00),
    ];

    // 1. Draw Piles of Leaves (Mounds)
    for (int i = 0; i < 5; i++) {
      final double moundX = size.width * (0.1 + i * 0.2);
      final paint = Paint()
        ..color = leafColors[i % leafColors.length].withValues(alpha: 0.6);

      final Path moundPath = Path()
        ..moveTo(moundX - 60, yBase)
        ..quadraticBezierTo(moundX, yBase - 15, moundX + 60, yBase)
        ..close();
      canvas.drawPath(moundPath, paint);
    }

    // 2. Draw a Pumpkin at 0.65 (same as snowman position)
    _drawPumpkin(canvas, Offset(size.width * 0.65, yBase - 5));
  }

  void _drawPumpkin(Canvas canvas, Offset bottomCenter) {
    final orangePaint = Paint()
      ..color = const Color(0xFFE67E22)
      ..style = PaintingStyle.fill;
    final stemPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Pumpkin body (3 overlapping ovals)
    const double width = 30.0;
    const double height = 24.0;

    // Stem
    canvas.drawRect(
        Rect.fromLTWH(bottomCenter.dx - 3, bottomCenter.dy - height - 8, 6, 10),
        stemPaint);

    // Left segment
    canvas.drawOval(
        Rect.fromCenter(
            center: bottomCenter.translate(-8, -height / 2),
            width: width * 0.6,
            height: height),
        orangePaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: bottomCenter.translate(-8, -height / 2),
            width: width * 0.6,
            height: height),
        shadowPaint);

    // Right segment
    canvas.drawOval(
        Rect.fromCenter(
            center: bottomCenter.translate(8, -height / 2),
            width: width * 0.6,
            height: height),
        orangePaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: bottomCenter.translate(8, -height / 2),
            width: width * 0.6,
            height: height),
        shadowPaint);

    // Center segment
    canvas.drawOval(
        Rect.fromCenter(
            center: bottomCenter.translate(0, -height / 2),
            width: width * 0.6,
            height: height),
        orangePaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: bottomCenter.translate(0, -height / 2),
            width: width * 0.6,
            height: height),
        shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
