import 'package:flutter/material.dart';

class RetroSunWidget extends StatelessWidget {
  const RetroSunWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RetroSunPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _RetroSunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height * 0.4;
    final double radius = size.width * 0.25;

    // 1. Draw the Sun Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD700), // Gold/Yellow
          const Color(0xFFFF007F).withValues(alpha: 0.8), // Neon Pink
          const Color(0xFFBD00FF).withValues(alpha: 0.0), // Fade to Purple
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(centerX, centerY), radius: radius * 1.5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawCircle(Offset(centerX, centerY), radius, glowPaint);

    // 2. Draw the Sun Disk with Stripes
    final sunPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFD700), // Gold
          const Color(0xFFFF007F), // Pink
        ],
      ).createShader(
          Rect.fromCircle(center: Offset(centerX, centerY), radius: radius));

    final Path sunPath = Path();
    sunPath.addOval(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: radius));

    // Clip the sun with horizontal stripes (vhs style)
    final Path clipPath = Path();
    clipPath.addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    const double stripeStartPct = 0.45; // Start stripes halfway down
    const double stripeInitialHeight = 4.0;

    for (int i = 0; i < 15; i++) {
      final double yPos = centerY + (radius * stripeStartPct) + (i * 12);
      if (yPos > centerY + radius) break;

      // Increase stripe height as we go down
      final double h = stripeInitialHeight + (i * 1.5);
      clipPath.addRect(
          Rect.fromLTWH(centerX - radius - 10, yPos, radius * 2 + 20, h));
    }

    // We use Path.combine to subtract the stripes from the sun
    final finalSunPath =
        Path.combine(PathOperation.difference, sunPath, clipPath);

    canvas.drawPath(finalSunPath, sunPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
