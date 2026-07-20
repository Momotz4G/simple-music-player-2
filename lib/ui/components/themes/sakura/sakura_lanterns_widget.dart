import 'dart:math';
import 'package:flutter/material.dart';

class SakuraLanternsWidget extends StatefulWidget {
  const SakuraLanternsWidget({super.key});

  @override
  State<SakuraLanternsWidget> createState() => _SakuraLanternsWidgetState();
}

class _SakuraLanternsWidgetState extends State<SakuraLanternsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
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
        return CustomPaint(
          painter: _LanternPainter(animationValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _LanternPainter extends CustomPainter {
  final double animationValue;
  _LanternPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final wirePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double width = size.width;
    const double yOffset = 5.0;

    // 1. Draw sagging wires
    final path = Path()
      ..moveTo(0, yOffset)
      ..quadraticBezierTo(width * 0.25, yOffset + 10, width * 0.5, yOffset)
      ..quadraticBezierTo(width * 0.75, yOffset + 10, width, yOffset);
    canvas.drawPath(path, wirePaint);

    // 2. Draw Lanterns
    _drawLantern(canvas, Offset(width * 0.2, yOffset + 8), 1);
    _drawLantern(canvas, Offset(width * 0.5, yOffset + 10), 2);
    _drawLantern(canvas, Offset(width * 0.8, yOffset + 8), 3);
  }

  void _drawLantern(Canvas canvas, Offset pos, int seed) {
    final double flicker = 0.8 + (sin(animationValue * pi * 2 + seed) * 0.2);

    const lanternColor = Color(0xFFFFB7C5); // Pink

    // Lantern Body
    final bodyPaint = Paint()
      ..color = lanternColor.withValues(alpha: 0.9 * flicker)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = lanternColor.withValues(alpha: 0.4 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final rect =
        Rect.fromCenter(center: pos.translate(0, 15), width: 14, height: 20);

    // Draw Glow
    canvas.drawOval(rect.inflate(8), glowPaint);

    // Draw Body (rounded rectangle)
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)), bodyPaint);

    // Draw Top/Bottom caps
    final capPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
        Rect.fromLTWH(pos.dx - 8, pos.dy + 5, 16, 2), capPaint); // Top
    canvas.drawRect(
        Rect.fromLTWH(pos.dx - 8, pos.dy + 25, 16, 2), capPaint); // Bottom

    // Hanging wire
    final hangerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(pos.translate(0, -5), pos.translate(0, 5), hangerPaint);

    // Tassel
    final tasselPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(pos.translate(0, 27), pos.translate(0, 35), tasselPaint);
  }

  @override
  bool shouldRepaint(covariant _LanternPainter oldDelegate) => true;
}
