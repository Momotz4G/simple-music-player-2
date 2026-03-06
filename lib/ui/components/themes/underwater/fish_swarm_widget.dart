import 'dart:math';
import 'package:flutter/material.dart';

class FishSwarmWidget extends StatefulWidget {
  const FishSwarmWidget({super.key});

  @override
  State<FishSwarmWidget> createState() => _FishSwarmWidgetState();
}

class _FishSwarmWidgetState extends State<FishSwarmWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Fish> _fishElements = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Initialize a school of fish
    for (int i = 0; i < 15; i++) {
      _fishElements.add(_Fish(
        x: _random.nextDouble(),
        y: 0.2 + _random.nextDouble() * 0.6,
        speed: 0.001 + _random.nextDouble() * 0.002,
        color: _random.nextBool()
            ? const Color(0xFFFFA07A)
            : const Color(0xFFFFD700), // Salmon or Gold
        offset: _random.nextDouble() * 2 * pi,
      ));
    }
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_update)
      ..repeat();
  }

  void _update() {
    for (final fish in _fishElements) {
      fish.update();
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
      painter: _FishSwarmPainter(_fishElements),
      child: const SizedBox.expand(),
    );
  }
}

class _Fish {
  double x;
  double y;
  double speed;
  Color color;
  double offset;
  double wobble = 0;

  _Fish(
      {required this.x,
      required this.y,
      required this.speed,
      required this.color,
      required this.offset});

  void update() {
    x += speed;
    wobble += 0.05;
    if (x > 1.2) x = -0.2; // Loop back
  }
}

class _FishSwarmPainter extends CustomPainter {
  final List<_Fish> fishList;
  _FishSwarmPainter(this.fishList);

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in fishList) {
      final double fx = f.x * size.width;
      final double fy = (f.y * size.height) + sin(f.wobble + f.offset) * 15;

      final fishPaint = Paint()
        ..color = f.color.withOpacity(0.6)
        ..style = PaintingStyle.fill;

      // DRAW SMALL FISH (Simple tear shape)
      final Path path = Path();
      path.moveTo(fx, fy);
      path.quadraticBezierTo(fx - 10, fy - 5, fx - 20, fy); // Top
      path.quadraticBezierTo(fx - 10, fy + 5, fx, fy); // Bottom
      path.close();

      // TAIL
      path.moveTo(fx - 20, fy);
      path.lineTo(fx - 25, fy - 5);
      path.lineTo(fx - 25, fy + 5);
      path.close();

      canvas.drawPath(path, fishPaint);

      // EYE
      canvas.drawCircle(Offset(fx - 5, fy - 1), 1.0,
          Paint()..color = Colors.black.withOpacity(0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _FishSwarmPainter oldDelegate) => true;
}
