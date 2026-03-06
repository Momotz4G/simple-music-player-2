import 'dart:math';
import 'package:flutter/material.dart';

class HangingLightsWidget extends StatefulWidget {
  const HangingLightsWidget({super.key});

  @override
  State<HangingLightsWidget> createState() => _HangingLightsWidgetState();
}

class _HangingLightsWidgetState extends State<HangingLightsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Twinkle/pulse cycle: 2 seconds per cycle
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
          painter: _HangingLightsPainter(animationValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _HangingLightsPainter extends CustomPainter {
  final double animationValue;

  _HangingLightsPainter({required this.animationValue});

  // A nice holiday palette
  static const List<Color> _bulbColors = [
    Color(0xFFFF3030), // Red
    Color(0xFF30FF60), // Green
    Color(0xFF3090FF), // Blue
    Color(0xFFFFDD30), // Yellow
    Color(0xFFFF30E0), // Magenta/Pink
    Color(0xFF30FFEE), // Cyan
    Color(0xFFFF8C30), // Orange
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;

    // --- Wire Setup ---
    // We draw a single string that sags gently (catenary-like using sine).
    // Number of bulbs across the width
    const int bulbCount = 18;
    final double spacing = w / (bulbCount + 1);

    // The wire hangs top to bottom based on a sine curve to emulate sag.
    // Wire sag: starts at the edge anchors on the top edge
    final double sagDepth = 55.0; // how deep the wire sags in the center
    final double wireY = 0.0; // wire anchor at very top

    // Draw the wire first
    final wirePaint = Paint()
      ..color = const Color(0xFF555555)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final wirePath = Path();
    wirePath.moveTo(0, wireY);
    // Approximate a catenary by using multiple quadratic curves
    for (int i = 0; i < bulbCount; i++) {
      final double x1 = (i + 1) * spacing;
      // Sag based on a sine wave segment: peak sag in the center
      final double t = x1 / w; // 0..1
      final double sagAtX = sagDepth * sin(t * pi);
      final double cpX = x1 - spacing / 2;
      final double cpT = (cpX) / w;
      final double cpY = wireY + sagDepth * sin(cpT * pi) + 4; // control point
      wirePath.quadraticBezierTo(cpX, cpY, x1, wireY + sagAtX);
    }
    wirePath.quadraticBezierTo(w - spacing / 2,
        wireY + sagDepth * sin(((w - spacing / 2) / w) * pi) + 4, w, wireY);
    canvas.drawPath(wirePath, wirePaint);

    // Draw each bulb
    for (int i = 0; i < bulbCount; i++) {
      final int colorIdx = i % _bulbColors.length;
      final Color baseColor = _bulbColors[colorIdx];

      // Calculate the X position
      final double bx = (i + 1) * spacing;

      // Calculate the Y position on the wire at this X
      final double t = bx / w;
      final double sagAtX = sagDepth * sin(t * pi);
      final double by = wireY + sagAtX;

      // Each bulb has a different phase for twinkling
      final double phase = (i * 0.4) % 1.0;
      // Twinkle: brightness oscillates between 0.5 and 1.0
      final double brightness =
          0.55 + 0.45 * sin((animationValue + phase) * 2 * pi);

      // Compute the glowing color
      final Color glowColor = Color.lerp(
          baseColor.withOpacity(0.1), baseColor.withOpacity(1.0), brightness)!;

      // Draw glow halo
      final glowPaint = Paint()
        ..color = glowColor.withOpacity(0.35 * brightness)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawCircle(Offset(bx, by + 10), 11, glowPaint);

      // Draw bulb socket (small grey rect)
      final socketPaint = Paint()
        ..color = const Color(0xFF888888)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
          Rect.fromCenter(center: Offset(bx, by + 2), width: 7, height: 6),
          socketPaint);

      // Draw the bulb itself (oval drop shape)
      final bulbPaint = Paint()
        ..color = glowColor
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bx, by + 13), width: 14, height: 18),
        bulbPaint,
      );

      // Draw a tiny specular highlight on the bulb
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.5 * brightness)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromLTWH(bx - 4, by + 6, 5, 6),
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HangingLightsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
