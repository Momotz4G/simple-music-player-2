import 'dart:math';
import 'package:flutter/material.dart';

class RainFallWidget extends StatefulWidget {
  const RainFallWidget({super.key});

  @override
  State<RainFallWidget> createState() => _RainFallWidgetState();
}

class _RainFallWidgetState extends State<RainFallWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_RainDrop> _rainDrops = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_updateRain)
      ..repeat();
  }

  void _updateRain() {
    if (!mounted) return;
    setState(() {
      // Add new drops
      if (_rainDrops.length < 150) {
        _rainDrops.add(_RainDrop(
          x: _random.nextDouble() * 1.5 -
              0.25, // Diagonally starts further left
          y: -0.1,
          length: _random.nextDouble() * 20 + 15,
          width: _random.nextDouble() * 1.0 + 0.5,
          speed: _random.nextDouble() * 0.02 + 0.03,
          opacity: _random.nextDouble() * 0.3 + 0.2,
        ));
      }

      // Update existing drops
      for (int i = _rainDrops.length - 1; i >= 0; i--) {
        _rainDrops[i].y += _rainDrops[i].speed;
        _rainDrops[i].x += _rainDrops[i].speed * 0.3; // Diagonal drift

        if (_rainDrops[i].y > 1.1) {
          _rainDrops.removeAt(i);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RainPainter(_rainDrops),
      child: const SizedBox.expand(),
    );
  }
}

class _RainDrop {
  double x, y, length, width, speed, opacity;

  _RainDrop({
    required this.x,
    required this.y,
    required this.length,
    required this.width,
    required this.speed,
    required this.opacity,
  });
}

class _RainPainter extends CustomPainter {
  final List<_RainDrop> rainDrops;
  _RainPainter(this.rainDrops);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round;

    for (var drop in rainDrops) {
      paint.color = Colors.white.withOpacity(drop.opacity);
      paint.strokeWidth = drop.width;

      final double startX = drop.x * size.width;
      final double startY = drop.y * size.height;

      // Calculate end point for diagonal line
      // Since it drifts 0.3 units X for every 1.0 unit Y
      final double endX = startX + (drop.length * 0.3);
      final double endY = startY + drop.length;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
