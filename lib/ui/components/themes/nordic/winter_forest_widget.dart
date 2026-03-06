import 'dart:math';
import 'package:flutter/material.dart';

class WinterForestWidget extends StatelessWidget {
  const WinterForestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ForestPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _ForestPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF0A0F14) // Very dark, almost black blue
      ..style = PaintingStyle.fill;

    final Random random = Random(123);
    final double groundHeight = size.height * 0.15;

    // Draw far background hills
    final Paint hillPaint = Paint()..color = const Color(0xFF05080A);
    final Path hillPath = Path();
    hillPath.moveTo(0, size.height);
    hillPath.lineTo(0, size.height - groundHeight * 0.8);
    hillPath.quadraticBezierTo(
        size.width * 0.25,
        size.height - groundHeight * 1.5,
        size.width * 0.5,
        size.height - groundHeight * 0.8);
    hillPath.quadraticBezierTo(
        size.width * 0.75,
        size.height - groundHeight * 0.5,
        size.width,
        size.height - groundHeight * 1.2);
    hillPath.lineTo(size.width, size.height);
    hillPath.close();
    canvas.drawPath(hillPath, hillPaint);

    // Draw trees
    for (int i = 0; i < 25; i++) {
      final double x = random.nextDouble() * size.width;
      final double treeHeight = 40 + random.nextDouble() * 80;
      final double y = size.height - groundHeight + (random.nextDouble() * 20);

      _drawPineTree(canvas, Offset(x, y), treeHeight, paint);
    }

    // Bottom ground fill
    canvas.drawRect(
        Rect.fromLTWH(
            0, size.height - groundHeight + 10, size.width, groundHeight),
        paint);
  }

  void _drawPineTree(
      Canvas canvas, Offset bottomCenter, double height, Paint paint) {
    final Path path = Path();
    final double width = height * 0.4;

    path.moveTo(bottomCenter.dx, bottomCenter.dy - height); // Top
    path.lineTo(bottomCenter.dx - width * 0.5, bottomCenter.dy - height * 0.3);
    path.lineTo(bottomCenter.dx - width * 0.3, bottomCenter.dy - height * 0.35);
    path.lineTo(bottomCenter.dx - width * 0.7, bottomCenter.dy - height * 0.1);
    path.lineTo(bottomCenter.dx - width * 0.4, bottomCenter.dy - height * 0.15);
    path.lineTo(bottomCenter.dx - width * 0.9, bottomCenter.dy);
    path.lineTo(bottomCenter.dx + width * 0.9, bottomCenter.dy);
    path.lineTo(bottomCenter.dx + width * 0.4, bottomCenter.dy - height * 0.15);
    path.lineTo(bottomCenter.dx + width * 0.7, bottomCenter.dy - height * 0.1);
    path.lineTo(bottomCenter.dx + width * 0.3, bottomCenter.dy - height * 0.35);
    path.lineTo(bottomCenter.dx + width * 0.5, bottomCenter.dy - height * 0.3);
    path.close();

    canvas.drawPath(path, paint);

    // Tiny trunk
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(bottomCenter.dx, bottomCenter.dy + 2),
            width: width * 0.2,
            height: 6),
        paint);
  }

  @override
  bool shouldRepaint(covariant _ForestPainter oldDelegate) => false;
}
