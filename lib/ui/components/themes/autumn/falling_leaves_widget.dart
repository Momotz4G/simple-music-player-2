import 'dart:math';
import 'package:flutter/material.dart';

class FallingLeavesWidget extends StatefulWidget {
  const FallingLeavesWidget({super.key});

  @override
  State<FallingLeavesWidget> createState() => _FallingLeavesWidgetState();
}

class _FallingLeavesWidgetState extends State<FallingLeavesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Leaf> _leaves = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_updateLeaves)
      ..repeat();
  }

  void _updateLeaves() {
    if (!mounted) return;
    setState(() {
      // Add new leaves occasionally
      if (_leaves.length < 40 && _random.nextDouble() < 0.1) {
        _leaves.add(_Leaf(
          x: _random.nextDouble() * 1.2 - 0.1, // Start slightly off-screen
          y: -0.1,
          size: _random.nextDouble() * 15 + 10,
          speed: _random.nextDouble() * 0.003 + 0.002,
          drift: _random.nextDouble() * 0.005 - 0.002,
          rotation: _random.nextDouble() * 2 * pi,
          rotationSpeed: _random.nextDouble() * 0.1 - 0.05,
          color: _getAutumnColor(),
        ));
      }

      // Update existing leaves
      for (int i = _leaves.length - 1; i >= 0; i--) {
        _leaves[i].y += _leaves[i].speed;
        _leaves[i].x += _leaves[i].drift + (sin(_leaves[i].y * 10) * 0.002);
        _leaves[i].rotation += _leaves[i].rotationSpeed;

        if (_leaves[i].y > 1.1) {
          _leaves.removeAt(i);
        }
      }
    });
  }

  Color _getAutumnColor() {
    final colors = [
      const Color(0xFFD35400), // Pumpkin
      const Color(0xFFE67E22), // Carrot
      const Color(0xFFF1C40F), // Sun Flower
      const Color(0xFFC0392B), // Pomegranate
      const Color(0xFF7E5109), // Earth brown
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
      painter: _LeafPainter(_leaves),
      child: const SizedBox.expand(),
    );
  }
}

class _Leaf {
  double x, y, size, speed, drift, rotation, rotationSpeed;
  Color color;

  _Leaf({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
  });
}

class _LeafPainter extends CustomPainter {
  final List<_Leaf> leaves;
  _LeafPainter(this.leaves);

  @override
  void paint(Canvas canvas, Size size) {
    for (var leaf in leaves) {
      final paint = Paint()
        ..color = leaf.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(leaf.x * size.width, leaf.y * size.height);
      canvas.rotate(leaf.rotation);

      // Draw a simple procedural maple leaf shape
      final path = Path();
      final s = leaf.size;
      path.moveTo(0, -s / 2);
      path.quadraticBezierTo(s / 4, -s / 2, s / 2, 0);
      path.quadraticBezierTo(s / 4, s / 2, 0, s / 2);
      path.quadraticBezierTo(-s / 4, s / 2, -s / 2, 0);
      path.quadraticBezierTo(-s / 4, -s / 2, 0, -s / 2);
      path.close();

      canvas.drawPath(path, paint);

      // Draw a center line
      final veinPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, -s / 2), Offset(0, s / 2), veinPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
