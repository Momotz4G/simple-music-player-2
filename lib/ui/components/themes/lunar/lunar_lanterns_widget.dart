import 'dart:math';
import 'package:flutter/material.dart';

class LunarLanternsWidget extends StatefulWidget {
  const LunarLanternsWidget({super.key});

  @override
  State<LunarLanternsWidget> createState() => _LunarLanternsWidgetState();
}

class _LunarLanternsWidgetState extends State<LunarLanternsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
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
          painter: _LunarLanternPainter(animationValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _LunarLanternPainter extends CustomPainter {
  final double animationValue;
  _LunarLanternPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final wirePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double width = size.width;
    const double yOffset = 5.0;

    // Sagging wires
    final path = Path()
      ..moveTo(0, yOffset)
      ..quadraticBezierTo(width * 0.25, yOffset + 12, width * 0.5, yOffset)
      ..quadraticBezierTo(width * 0.75, yOffset + 12, width, yOffset);
    canvas.drawPath(path, wirePaint);

    // Lanterns
    _drawRoundLantern(canvas, Offset(width * 0.25, yOffset + 10), 1);
    _drawRoundLantern(canvas, Offset(width * 0.5, yOffset + 12), 2);
    _drawRoundLantern(canvas, Offset(width * 0.75, yOffset + 10), 3);
  }

  void _drawRoundLantern(Canvas canvas, Offset pos, int seed) {
    final double flicker = 0.85 + (sin(animationValue * pi * 2 + seed) * 0.15);
    const lanternRed = Color(0xFFD00000);
    const goldColor = Color(0xFFFFD700);

    // Lantern Body (Large Round)
    final bodyPaint = Paint()
      ..color = lanternRed.withValues(alpha: 0.95 * flicker)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = lanternRed.withValues(alpha: 0.4 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    // Draw Glow
    canvas.drawCircle(pos.translate(0, 20), 22, glowPaint);

    // Draw Round Body
    canvas.drawOval(
        Rect.fromCenter(center: pos.translate(0, 20), width: 28, height: 32),
        bodyPaint);

    // Vertical Gold Lines
    final linePaint = Paint()
      ..color = goldColor.withValues(alpha: 0.3 * flicker)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawOval(
        Rect.fromCenter(center: pos.translate(0, 20), width: 14, height: 32),
        linePaint);
    canvas.drawLine(pos.translate(0, 4), pos.translate(0, 36), linePaint);

    // Top/Bottom caps (Gold)
    final capPaint = Paint()
      ..color = goldColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: pos.translate(0, 4), width: 14, height: 4),
            const Radius.circular(1)),
        capPaint); // Top
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: pos.translate(0, 36), width: 14, height: 4),
            const Radius.circular(1)),
        capPaint); // Bottom

    // Gold Tassel
    final tasselPaint = Paint()
      ..color = goldColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 3; i++) {
      final double tx = (i - 1) * 3.0;
      canvas.drawLine(
          pos.translate(tx, 38), pos.translate(tx, 52), tasselPaint);
    }

    // Hanger
    final wirePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(pos.translate(0, -5), pos.translate(0, 4), wirePaint);
  }

  @override
  bool shouldRepaint(covariant _LunarLanternPainter oldDelegate) => true;
}
