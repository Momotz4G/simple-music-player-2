import 'dart:math';
import 'package:flutter/material.dart';

class CosmicStarsWidget extends StatefulWidget {
  const CosmicStarsWidget({super.key});

  @override
  State<CosmicStarsWidget> createState() => _CosmicStarsWidgetState();
}

class _CosmicStarsWidgetState extends State<CosmicStarsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_StarData> _stars = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60), // Slow parallax drift
    )..repeat();

    // Initialize stars with different layers for parallax
    for (int i = 0; i < 200; i++) {
      int layer = _random.nextInt(3) + 1; // Layer 1 (front) to 3 (back)
      _stars.add(_StarData(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: layer == 1
            ? 2.0
            : layer == 2
                ? 1.0
                : 0.5,
        speed: layer == 1
            ? 0.05
            : layer == 2
                ? 0.02
                : 0.005,
        baseOpacity: layer == 1
            ? 0.8
            : layer == 2
                ? 0.5
                : 0.3,
        pulseSpeed: 0.5 + _random.nextDouble() * 2.0,
        pulseOffset: _random.nextDouble() * 2 * pi,
      ));
    }
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
          painter: _CosmicStarPainter(_stars, _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _StarData {
  double x, y;
  final double size;
  final double speed;
  final double baseOpacity;
  final double pulseSpeed;
  final double pulseOffset;

  _StarData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.baseOpacity,
    required this.pulseSpeed,
    required this.pulseOffset,
  });
}

class _CosmicStarPainter extends CustomPainter {
  final List<_StarData> stars;
  final double animationValue;

  _CosmicStarPainter(this.stars, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();

    for (final star in stars) {
      // Calculate parallax movement
      double currentX = (star.x - (animationValue * star.speed)) % 1.0;
      if (currentX < 0) currentX += 1.0;

      // Calculate pulsing opacity
      double pulse = 0.5 +
          0.5 * sin(animationValue * 100 * star.pulseSpeed + star.pulseOffset);
      double currentOpacity = star.baseOpacity * (0.5 + 0.5 * pulse);

      paint.color =
          Colors.white.withValues(alpha: currentOpacity.clamp(0.0, 1.0));

      final Offset currentPos =
          Offset(currentX * size.width, star.y * size.height);
      canvas.drawCircle(currentPos, star.size, paint);

      // Glow out for front stars
      if (star.size > 1.5 && pulse > 0.8) {
        paint.color = Colors.white.withValues(alpha: currentOpacity * 0.3);
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawCircle(currentPos, star.size * 2, paint);
        paint.maskFilter = null; // Revert
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicStarPainter oldDelegate) => true;
}
