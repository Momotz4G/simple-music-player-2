import 'package:flutter/material.dart';

class DesertSunWidget extends StatelessWidget {
  const DesertSunWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DesertSunPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _DesertSunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // A massive, scorching sun dominating the center-right sky
    final Offset center = Offset(size.width * 0.7, size.height * 0.4);
    final double radius = size.width > 600 ? 250 : 150; // Responsive size

    // 1. Intense Outer Glow (Heat haze)
    final Paint outerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF5722).withValues(alpha: 0.3), // Deep Orange
          const Color(0xFFD84315).withValues(alpha: 0.1), // Burnt Orange
          const Color(0x00000000), // Transparent
        ],
        stops: const [0.4, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.8))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 1.8, outerGlowPaint);

    // 2. Inner Corona
    final Paint coronaPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF9800).withValues(alpha: 0.7), // Bright Orange
          const Color(0xFFFF5722).withValues(alpha: 0.2), // Transition
          const Color(0x00000000), // Transparent
        ],
        stops: const [0.6, 0.9, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 1.2, coronaPaint);

    // 3. Solid Bright Sun Core
    final Paint corePaint = Paint()
      ..color =
          const Color(0xFFFFB74D) // Very bright, pale orange/yellow center
      ..maskFilter =
          const MaskFilter.blur(BlurStyle.solid, 10); // Slight blur on edges

    canvas.drawCircle(center, radius, corePaint);
  }

  @override
  bool shouldRepaint(covariant _DesertSunPainter oldDelegate) => false;
}
