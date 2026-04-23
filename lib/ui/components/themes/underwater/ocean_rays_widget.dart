import 'dart:math';
import 'package:flutter/material.dart';

class OceanRaysWidget extends StatefulWidget {
  const OceanRaysWidget({super.key});

  @override
  State<OceanRaysWidget> createState() => _OceanRaysWidgetState();
}

class _OceanRaysWidgetState extends State<OceanRaysWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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
          painter: _OceanRaysPainter(_controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _OceanRaysPainter extends CustomPainter {
  final double animationValue;
  _OceanRaysPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(42);
    final int rayCount = 12;

    for (int i = 0; i < rayCount; i++) {
      final double xBase = (i / rayCount) * size.width;

      // Wobble effect
      final double offset = sin(animationValue * 2 * pi + (i * 0.5)) * 20;
      final double x = xBase + offset;

      final double width = 40.0 + random.nextDouble() * 80.0;
      final double opacity = 0.05 + random.nextDouble() * 0.1;

      final rayPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(x - width / 2, 0, width, size.height))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

      final Path path = Path();
      // Ray shape: wider at bottom (perspective)
      path.moveTo(x - width / 3, 0);
      path.lineTo(x + width / 3, 0);
      path.lineTo(x + width * 1.5, size.height);
      path.lineTo(x - width * 1.5, size.height);
      path.close();

      canvas.drawPath(path, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OceanRaysPainter oldDelegate) => true;
}
