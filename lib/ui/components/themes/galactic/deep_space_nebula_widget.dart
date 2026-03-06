import 'dart:math';
import 'package:flutter/material.dart';

class DeepSpaceNebulaWidget extends StatefulWidget {
  const DeepSpaceNebulaWidget({super.key});

  @override
  State<DeepSpaceNebulaWidget> createState() => _DeepSpaceNebulaWidgetState();
}

class _DeepSpaceNebulaWidgetState extends State<DeepSpaceNebulaWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
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
          painter: _NebulaPainter(_controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _NebulaPainter extends CustomPainter {
  final double animationValue;
  _NebulaPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final double t = animationValue * 2 * pi;
    final Random random = Random(100);

    // Draw a few large, soft glowing blobs to act as nebulas
    for (int i = 0; i < 4; i++) {
      final double xOffset = sin(t * 0.5 + i) * size.width * 0.2;
      final double yOffset = cos(t * 0.3 + i * 2) * size.height * 0.2;

      final double centerX =
          size.width * (0.2 + random.nextDouble() * 0.6) + xOffset;
      final double centerY =
          size.height * (0.2 + random.nextDouble() * 0.6) + yOffset;
      final double radius = size.width * (0.4 + random.nextDouble() * 0.3);

      final Color nebulaColor = i % 2 == 0
          ? const Color(0xFF6A0DAD) // Deep Purple
          : const Color(0xFF00BFFF); // Deep Sky Blue

      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: [
            nebulaColor.withValues(alpha: 0.15 + 0.05 * sin(t + i)),
            nebulaColor.withValues(alpha: 0.0),
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(centerX, centerY), radius: radius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

      canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter oldDelegate) => true;
}
