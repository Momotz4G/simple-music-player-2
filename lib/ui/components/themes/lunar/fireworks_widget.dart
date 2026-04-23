import 'dart:math';
import 'package:flutter/material.dart';

class FireworksWidget extends StatefulWidget {
  const FireworksWidget({super.key});

  @override
  State<FireworksWidget> createState() => _FireworksWidgetState();
}

class _FireworksWidgetState extends State<FireworksWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Firework> _fireworks = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_update)
      ..repeat();
  }

  void _update() {
    // Randomly spawn new firework
    if (_random.nextDouble() < 0.05 && _fireworks.length < 5) {
      _fireworks.add(_Firework(
        x: 0.2 + _random.nextDouble() * 0.6,
        targetY: 0.2 + _random.nextDouble() * 0.3,
        color: _getRandomColor(),
      ));
    }

    for (int i = _fireworks.length - 1; i >= 0; i--) {
      _fireworks[i].update();
      if (_fireworks[i].isDead) {
        _fireworks.removeAt(i);
      }
    }
    if (mounted) setState(() {});
  }

  Color _getRandomColor() {
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFFF0000), // Red
      const Color(0xFF00FF00), // Green
      const Color(0xFF00BFFF), // Blue
      const Color(0xFFFF00FF), // Magenta
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FireworksPainter(fireworks: _fireworks),
      child: const SizedBox.expand(),
    );
  }
}

class _Firework {
  double x;
  double y = 1.1; // Start below screen
  double targetY;
  Color color;
  bool exploded = false;
  List<_Particle> particles = [];
  bool isDead = false;
  final Random _random = Random();

  _Firework({required this.x, required this.targetY, required this.color});

  void update() {
    if (!exploded) {
      y -= 0.015; // Launch speed
      if (y <= targetY) {
        exploded = true;
        _createParticles();
      }
    } else {
      for (final p in particles) {
        p.update();
      }
      if (particles.every((p) => p.life <= 0)) {
        isDead = true;
      }
    }
  }

  void _createParticles() {
    for (int i = 0; i < 40; i++) {
      double angle = _random.nextDouble() * pi * 2;
      double speed = 1.0 + _random.nextDouble() * 3.0;
      particles.add(_Particle(
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        color: color,
      ));
    }
  }
}

class _Particle {
  double x = 0, y = 0;
  double vx, vy;
  double life = 1.0;
  Color color;

  _Particle({required this.vx, required this.vy, required this.color});

  void update() {
    x += vx;
    y += vy;
    vy += 0.05; // Gravity
    life -= 0.02; // Fade out
  }
}

class _FireworksPainter extends CustomPainter {
  final List<_Firework> fireworks;
  _FireworksPainter({required this.fireworks});

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in fireworks) {
      if (!f.exploded) {
        // Rocket trail
        final paint = Paint()
          ..color = f.color.withValues(alpha: 0.8)
          ..strokeWidth = 3
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
            Offset(f.x * size.width, f.y * size.height), 3, paint);
      } else {
        // Explosion particles
        final centerX = f.x * size.width;
        final centerY = f.y * size.height;
        for (final p in f.particles) {
          if (p.life > 0) {
            final paint = Paint()
              ..color = f.color.withValues(alpha: p.life)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(
                Offset(centerX + p.x, centerY + p.y), 2 * p.life, paint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) => true;
}
