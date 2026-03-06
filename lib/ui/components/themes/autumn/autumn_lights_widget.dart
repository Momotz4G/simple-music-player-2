import 'dart:math';
import 'package:flutter/material.dart';

class AutumnLightsWidget extends StatefulWidget {
  const AutumnLightsWidget({super.key});

  @override
  State<AutumnLightsWidget> createState() => _AutumnLightsWidgetState();
}

class _AutumnLightsWidgetState extends State<AutumnLightsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
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
          painter: _AutumnLightsPainter(animationValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AutumnLightsPainter extends CustomPainter {
  final double animationValue;
  _AutumnLightsPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final vinePaint = Paint()
      ..color = const Color(0xFF6E2C00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double width = size.width;
    const double yOffset = 10.0;
    const int bulbCount = 12;
    final double spacing = width / (bulbCount + 1);

    // 1. Draw sagging vine path
    final path = Path();
    path.moveTo(0, yOffset);
    for (int i = 1; i <= bulbCount + 1; i++) {
      final double endX = i * spacing;
      final double controlX = endX - (spacing / 2);
      // Sagging calculation
      const double sag = 15.0;
      path.quadraticBezierTo(controlX, yOffset + sag, endX, yOffset);
    }
    canvas.drawPath(path, vinePaint);

    // 2. Draw Lanterns (flickering amber)
    for (int i = 1; i <= bulbCount; i++) {
      final double x = i * spacing;
      // Find Y on the sagging curve at x
      // Quadratic bezier at center point is roughly yOffset + sag * 0.75
      final double y = yOffset + 8;

      final double flicker =
          sin(animationValue * 2 * pi + (i * 0.5)) * 0.2 + 0.8;
      final Color amberColor = Colors.amber.withOpacity(flicker);

      final paint = Paint()
        ..color = amberColor
        ..style = PaintingStyle.fill;
      final glowPaint = Paint()
        ..color = amberColor.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

      // Lantern shape (rectangle)
      canvas.drawCircle(Offset(x, y + 5), 10, glowPaint);
      canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y + 5), width: 8, height: 12),
          paint);
      // Lantern cap
      canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y - 2), width: 10, height: 2),
          Paint()..color = const Color(0xFF3E2723));
    }
  }

  @override
  bool shouldRepaint(covariant _AutumnLightsPainter oldDelegate) => true;
}
