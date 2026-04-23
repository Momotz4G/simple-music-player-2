import 'dart:math';
import 'package:flutter/material.dart';

class StarrySkyWidget extends StatefulWidget {
  const StarrySkyWidget({super.key});

  @override
  State<StarrySkyWidget> createState() => _StarrySkyWidgetState();
}

class _StarrySkyWidgetState extends State<StarrySkyWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Star> _stars = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Initialize stars
    for (int i = 0; i < 80; i++) {
      _stars.add(_Star(
        x: _random.nextDouble(),
        y: _random.nextDouble() * 0.6, // Mostly in top half
        size: 0.5 + _random.nextDouble() * 1.5,
        pulseSpeed: 0.5 + _random.nextDouble() * 2.0,
        offset: _random.nextDouble() * 2 * pi,
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
          painter: _StarPainter(_stars, _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _Star {
  final double x;
  final double y;
  final double size;
  final double pulseSpeed;
  final double offset;

  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.pulseSpeed,
    required this.offset,
  });
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double animationValue;

  _StarPainter(this.stars, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white;

    for (final star in stars) {
      final double opacity = 0.2 +
          0.8 *
              (0.5 +
                  0.5 *
                      sin(animationValue * 2 * pi * star.pulseSpeed +
                          star.offset));
      paint.color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0));

      final Offset position = Offset(star.x * size.width, star.y * size.height);
      canvas.drawCircle(position, star.size, paint);

      // Some stars get a tiny glow
      if (star.size > 1.2) {
        canvas.drawCircle(
            position,
            star.size * 2,
            Paint()
              ..color = Colors.white.withValues(alpha: opacity * 0.3)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => true;
}
