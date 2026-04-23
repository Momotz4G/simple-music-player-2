import 'dart:math';
import 'package:flutter/material.dart';

class BubblesWidget extends StatefulWidget {
  const BubblesWidget({super.key});

  @override
  State<BubblesWidget> createState() => _BubblesWidgetState();
}

class _BubblesWidgetState extends State<BubblesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Bubble> _bubbles = [];
  final Random _random = Random();

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
    if (_random.nextDouble() < 0.08 && _bubbles.length < 25) {
      _bubbles.add(_Bubble(
        x: _random.nextDouble(),
        radius: 2.0 + _random.nextDouble() * 5.0,
        speed: 0.002 + _random.nextDouble() * 0.005,
        wobble: _random.nextDouble() * 2 * pi,
      ));
    }

    for (int i = _bubbles.length - 1; i >= 0; i--) {
      _bubbles[i].update();
      if (_bubbles[i].isDead) {
        _bubbles.removeAt(i);
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
      painter: _BubblePainter(_bubbles),
      child: const SizedBox.expand(),
    );
  }
}

class _Bubble {
  double x;
  double y = 1.1; // Start below the screen
  double radius;
  double speed;
  double wobble;
  bool isDead = false;

  _Bubble(
      {required this.x,
      required this.radius,
      required this.speed,
      required this.wobble});

  void update() {
    y -= speed;
    wobble += 0.05;
    if (y < -0.1) isDead = true;
  }
}

class _BubblePainter extends CustomPainter {
  final List<_Bubble> bubbles;
  _BubblePainter(this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {
    final bubblePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    for (final b in bubbles) {
      final double bx = (b.x * size.width) + sin(b.wobble) * 10;
      final double by = b.y * size.height;

      canvas.drawCircle(Offset(bx, by), b.radius, bubblePaint);

      // Bubble shine
      canvas.drawCircle(Offset(bx - b.radius * 0.4, by - b.radius * 0.4),
          b.radius * 0.2, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) => true;
}
