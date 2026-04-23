import 'dart:math';
import 'package:flutter/material.dart';

class AuroraBorealisWidget extends StatefulWidget {
  const AuroraBorealisWidget({super.key});

  @override
  State<AuroraBorealisWidget> createState() => _AuroraBorealisWidgetState();
}

class _AuroraBorealisWidgetState extends State<AuroraBorealisWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
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
          painter: _AuroraPainter(_controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double animationValue;
  _AuroraPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(42);
    final int ribbonCount = 3;

    for (int i = 0; i < ribbonCount; i++) {
      _drawRibbon(canvas, size, i, random);
    }
  }

  void _drawRibbon(Canvas canvas, Size size, int index, Random random) {
    final double t = animationValue * 2 * pi;
    final double baseOpacity = 0.15 + (sin(t * 0.5 + index) * 0.05);

    final Color auroraColor = index == 0
        ? const Color(0xFF2ECC71) // Green
        : index == 1
            ? const Color(0xFF9B59B6) // Purple
            : const Color(0xFF1ABC9C); // Teal

    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          auroraColor.withValues(alpha: 0.0),
          auroraColor.withValues(alpha: baseOpacity),
          auroraColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.4))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    final Path path = Path();
    final double centerY = size.height * (0.15 + (index * 0.08));

    path.moveTo(0, centerY);

    for (double x = 0; x <= size.width; x += 10) {
      final double wave1 = sin(x * 0.005 + t + (index * 2)) * 40;
      final double wave2 = cos(x * 0.002 - t * 0.5 + (index * 1.5)) * 20;
      final double y = centerY + wave1 + wave2;
      path.lineTo(x, y);
    }

    // Create depth by drawing multiple slightly offset layers
    for (int j = 0; j < 5; j++) {
      final double offset = j * 15.0;
      final Path shiftedPath = Path();
      shiftedPath.moveTo(0, centerY + offset);

      for (double x = 0; x <= size.width; x += 10) {
        final double wave1 = sin(x * 0.005 + t + (index * 2) + (j * 0.1)) * 40;
        final double wave2 =
            cos(x * 0.002 - t * 0.5 + (index * 1.5) + (j * 0.05)) * 20;
        final double y = centerY + offset + wave1 + wave2;
        shiftedPath.lineTo(x, y);
      }

      canvas.drawPath(shiftedPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => true;
}
