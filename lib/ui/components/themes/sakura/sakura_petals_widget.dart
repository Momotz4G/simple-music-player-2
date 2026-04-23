import 'dart:math';
import 'package:flutter/material.dart';

class SakuraPetalsWidget extends StatefulWidget {
  const SakuraPetalsWidget({super.key});

  @override
  State<SakuraPetalsWidget> createState() => _SakuraPetalsWidgetState();
}

class _SakuraPetalsWidgetState extends State<SakuraPetalsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Petal> _petals = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _controller.addListener(_updatePetals);

    // Initialize petals
    for (int i = 0; i < 40; i++) {
      _petals.add(_createPetal(isInitial: true));
    }
  }

  _Petal _createPetal({bool isInitial = false}) {
    return _Petal(
      x: _random.nextDouble(),
      y: isInitial ? _random.nextDouble() : -0.1,
      speed: 0.001 + _random.nextDouble() * 0.002,
      drift: (_random.nextDouble() - 0.5) * 0.001,
      rotation: _random.nextDouble() * pi * 2,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.05,
      scale: 0.5 + _random.nextDouble() * 0.8,
      opacity: 0.3 + _random.nextDouble() * 0.4,
    );
  }

  void _updatePetals() {
    for (int i = 0; i < _petals.length; i++) {
      _petals[i].y += _petals[i].speed;
      _petals[i].x +=
          _petals[i].drift + sin(_controller.value * pi * 2 + i) * 0.0005;
      _petals[i].rotation += _petals[i].rotationSpeed;

      if (_petals[i].y > 1.1) {
        _petals[i] = _createPetal();
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
      painter: _SakuraPainter(petals: _petals),
      child: const SizedBox.expand(),
    );
  }
}

class _Petal {
  double x;
  double y;
  double speed;
  double drift;
  double rotation;
  double rotationSpeed;
  double scale;
  double opacity;

  _Petal({
    required this.x,
    required this.y,
    required this.speed,
    required this.drift,
    required this.rotation,
    required this.rotationSpeed,
    required this.scale,
    required this.opacity,
  });
}

class _SakuraPainter extends CustomPainter {
  final List<_Petal> petals;
  _SakuraPainter({required this.petals});

  @override
  void paint(Canvas canvas, Size size) {
    for (final petal in petals) {
      final paint = Paint()
        ..color =
            const Color(0xFFFFB7C5).withValues(alpha: petal.opacity) // Sakura Pink
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(petal.x * size.width, petal.y * size.height);
      canvas.rotate(petal.rotation);
      canvas.scale(petal.scale);

      final path = Path();
      // Draw a petal shape (like a heart or tear drop with a notch)
      path.moveTo(0, -5);
      path.quadraticBezierTo(5, -5, 5, 0);
      path.quadraticBezierTo(5, 5, 0, 8);
      path.quadraticBezierTo(-5, 5, -5, 0);
      path.quadraticBezierTo(-5, -5, 0, -5);

      // Notch at the top
      path.moveTo(0, -5);
      path.lineTo(0, -2);

      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SakuraPainter oldDelegate) => true;
}
