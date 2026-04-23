import 'dart:math';
import 'package:flutter/material.dart';

class MilkyWayEffectWidget extends StatefulWidget {
  const MilkyWayEffectWidget({super.key});

  @override
  State<MilkyWayEffectWidget> createState() => _MilkyWayEffectWidgetState();
}

class _MilkyWayEffectWidgetState extends State<MilkyWayEffectWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ShootingStar> _shootingStars = [];
  final Random _random = Random();
  double _lastSpawnTime = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )
      ..addListener(_update)
      ..repeat();
  }

  void _update() {
    final double now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    // Occasionally spawn a shooting star
    if (now - _lastSpawnTime > 2 + _random.nextDouble() * 5) {
      _shootingStars.add(_ShootingStar(
        x: _random.nextDouble() * 0.8,
        y: _random.nextDouble() * 0.4,
        angle: pi / 4 + (_random.nextDouble() - 0.5) * 0.2,
        speed: 0.005 + _random.nextDouble() * 0.008,
      ));
      _lastSpawnTime = now;
    }

    // Update existing stars
    for (int i = _shootingStars.length - 1; i >= 0; i--) {
      _shootingStars[i].update();
      if (_shootingStars[i].life <= 0) {
        _shootingStars.removeAt(i);
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MilkyWayPainter(_shootingStars),
      child: const SizedBox.expand(),
    );
  }
}

class _ShootingStar {
  double x, y;
  double angle;
  double speed;
  double life = 1.0;

  _ShootingStar(
      {required this.x,
      required this.y,
      required this.angle,
      required this.speed});

  void update() {
    x += cos(angle) * speed;
    y += sin(angle) * speed;
    life -= 0.006;
  }
}

class _MilkyWayPainter extends CustomPainter {
  final List<_ShootingStar> shootingStars;
  _MilkyWayPainter(this.shootingStars);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. DRAW STATIC MILKY WAY BAND (Subtle stardust)
    final Paint bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.3, 0.5, 0.7],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bandPaint);

    // 2. DRAW SHOOTING STARS
    for (final star in shootingStars) {
      final double sx = star.x * size.width;
      final double sy = star.y * size.height;
      final double length = 80.0 * star.life;

      final Paint starPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: star.life.clamp(0.0, 1.0)),
          ],
        ).createShader(Rect.fromLTWH(sx - length, sy - 2, length, 4));

      canvas.save();
      canvas.translate(sx, sy);
      canvas.rotate(star.angle);

      // The trail
      canvas.drawRect(Rect.fromLTWH(-length, -1, length, 2), starPaint);

      // The head
      canvas.drawCircle(Offset.zero, 1.5 * star.life,
          Paint()..color = Colors.white.withValues(alpha: star.life.clamp(0.0, 1.0)));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MilkyWayPainter oldDelegate) => true;
}
