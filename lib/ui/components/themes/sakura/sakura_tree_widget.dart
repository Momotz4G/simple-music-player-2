import 'dart:math';
import 'package:flutter/material.dart';

class SakuraTreeWidget extends StatefulWidget {
  final double height;
  final double width;
  const SakuraTreeWidget({super.key, this.height = 150, this.width = 250});

  @override
  State<SakuraTreeWidget> createState() => _SakuraTreeWidgetState();
}

class _SakuraTreeWidgetState extends State<SakuraTreeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _SakuraTreePainter(sway: _controller.value),
          );
        },
      ),
    );
  }
}

class _SakuraTreePainter extends CustomPainter {
  final double sway;
  _SakuraTreePainter({required this.sway});

  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(42); // Seed for consistency
    final double trunkX = size.width * 0.7;
    final double bottomY = size.height - 10;

    final trunkPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.fill;

    // Draw trunk
    final Path trunkPath = Path()
      ..moveTo(trunkX - 10, bottomY)
      ..quadraticBezierTo(
          trunkX, bottomY - 40, trunkX - 5 + (sway * 5), bottomY - 80)
      ..lineTo(trunkX + 5 + (sway * 5), bottomY - 80)
      ..quadraticBezierTo(trunkX + 10, bottomY - 40, trunkX + 10, bottomY)
      ..close();
    canvas.drawPath(trunkPath, trunkPaint);

    // Draw foliage (Sakura Blooms)
    final bloomPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 25; i++) {
      final double dist = random.nextDouble() * 50;
      final double angle = random.nextDouble() * pi * 2;
      final double bloomX = trunkX + (sway * 15) + dist * cos(angle);
      final double bloomY = (bottomY - 80) + dist * sin(angle);
      final double bloomSize = 8.0 + random.nextDouble() * 12;

      // Sakura Pink Variations
      final List<Color> colors = [
        const Color(0xFFFFB7C5),
        const Color(0xFFFFC0CB),
        const Color(0xFFFFD1DC),
      ];

      bloomPaint.color =
          colors[random.nextInt(colors.length)].withOpacity(0.85);
      canvas.drawCircle(Offset(bloomX, bloomY), bloomSize, bloomPaint);
    }

    // Some floating petals around the tree
    for (int i = 0; i < 5; i++) {
      final double px = trunkX + (random.nextDouble() - 0.5) * 100;
      final double py = bottomY - 20 - random.nextDouble() * 80;
      bloomPaint.color = const Color(0xFFFFB7C5).withOpacity(0.4);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(px, py), width: 6, height: 4),
          bloomPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SakuraTreePainter oldDelegate) => true;
}
