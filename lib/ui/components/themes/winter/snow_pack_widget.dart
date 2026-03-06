import 'package:flutter/material.dart';

class SnowPackWidget extends StatelessWidget {
  const SnowPackWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SnowPackPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _SnowPackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = const Color(0xFFE0F2F1).withOpacity(0.3) // Soften shadow
      ..style = PaintingStyle.fill;

    final path = Path();
    final shadowPath = Path();

    // We'll draw several overlapping mounds at the bottom
    const double moundHeight = 20.0;
    final double yBase = size.height;

    // Draw shadow layer first
    shadowPath.moveTo(0, yBase);
    _drawMounds(shadowPath, size.width, yBase, moundHeight + 5);
    shadowPath.lineTo(size.width, yBase);
    shadowPath.close();
    canvas.drawPath(shadowPath, shadowPaint);

    // Draw main snow layer
    path.moveTo(0, yBase);
    _drawMounds(path, size.width, yBase, moundHeight);
    path.lineTo(size.width, yBase);
    path.close();
    canvas.drawPath(path, paint);

    // --- SNOWMAN ---
    // Position him on the first mound peak
    _drawSnowman(canvas, Offset(size.width * 0.65, yBase - moundHeight * 1.1));
  }

  void _drawSnowman(Canvas canvas, Offset bottomCenter) {
    final bodyPaint = Paint()..color = Colors.white;
    final detailPaint = Paint()..color = Colors.black;
    final nosePaint = Paint()..color = Colors.orange;
    final armPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // 1. Body (Three circles)
    const double baseRadius = 10.0;
    const double midRadius = 7.0;
    const double headRadius = 5.0;

    final Offset basePos = bottomCenter.translate(0, -baseRadius);
    final Offset midPos = basePos.translate(0, -baseRadius - midRadius + 2);
    final Offset headPos = midPos.translate(0, -midRadius - headRadius + 2);

    canvas.drawCircle(basePos, baseRadius, bodyPaint);
    canvas.drawCircle(midPos, midRadius, bodyPaint);
    canvas.drawCircle(headPos, headRadius, bodyPaint);

    // 2. Eyes (Black dots)
    canvas.drawCircle(headPos.translate(-1.5, -1), 0.8, detailPaint);
    canvas.drawCircle(headPos.translate(1.5, -1), 0.8, detailPaint);

    // 3. Carrot Nose (Orange triangle)
    final nosePath = Path()
      ..moveTo(headPos.dx, headPos.dy + 0.5)
      ..lineTo(headPos.dx + 4, headPos.dy + 1)
      ..lineTo(headPos.dx, headPos.dy + 1.5)
      ..close();
    canvas.drawPath(nosePath, nosePaint);

    // 4. Buttons (Black dots on torso)
    canvas.drawCircle(midPos.translate(0, -2), 0.8, detailPaint);
    canvas.drawCircle(midPos.translate(0, 2), 0.8, detailPaint);

    // 5. Stick Arms
    // Left arm
    canvas.drawLine(midPos.translate(-midRadius + 1, 0),
        midPos.translate(-midRadius - 6, -4), armPaint);
    // Right arm
    canvas.drawLine(midPos.translate(midRadius - 1, 0),
        midPos.translate(midRadius + 6, -4), armPaint);

    // 6. Top Hat (Black rectangle and brim)
    final hatBaseRect = Rect.fromCenter(
        center: headPos.translate(0, -headRadius - 4), width: 7, height: 8);
    canvas.drawRect(hatBaseRect, detailPaint);
    canvas.drawRect(
        Rect.fromCenter(
            center: headPos.translate(0, -headRadius), width: 11, height: 1.5),
        detailPaint);
  }

  void _drawMounds(Path path, double width, double yBase, double maxHeight) {
    // Generate a few mounds using quadratic bezier curves
    // Mound 1
    path.quadraticBezierTo(
      width * 0.15,
      yBase - maxHeight * 1.2,
      width * 0.35,
      yBase - maxHeight * 0.6,
    );
    // Mound 2
    path.quadraticBezierTo(
      width * 0.5,
      yBase - maxHeight * 1.5,
      width * 0.7,
      yBase - maxHeight * 0.8,
    );
    // Mound 3
    path.quadraticBezierTo(
      width * 0.85,
      yBase - maxHeight * 1.3,
      width,
      yBase - maxHeight * 0.4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
