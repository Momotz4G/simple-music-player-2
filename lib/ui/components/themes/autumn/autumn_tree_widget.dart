import 'dart:math';
import 'package:flutter/material.dart';

class AutumnTreeWidget extends StatefulWidget {
  final double height;
  final double width;
  const AutumnTreeWidget({super.key, this.height = 150, this.width = 150});

  @override
  State<AutumnTreeWidget> createState() => _AutumnTreeWidgetState();
}

class _AutumnTreeWidgetState extends State<AutumnTreeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
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
            painter: _AutumnTreePainter(
              swayValue: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _AutumnTreePainter extends CustomPainter {
  final double swayValue;

  _AutumnTreePainter({required this.swayValue});

  @override
  void paint(Canvas canvas, Size size) {
    final trunkPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.fill;

    final double centerX = size.width * 0.45;
    final double bottomY = size.height - 10;

    // 1. Draw Trunk
    final Path trunkPath = Path()
      ..moveTo(centerX - 8, bottomY)
      ..lineTo(centerX + 8, bottomY)
      ..lineTo(centerX + 3, bottomY - 50)
      ..lineTo(centerX - 3, bottomY - 50)
      ..close();
    canvas.drawPath(trunkPath, trunkPaint);

    // 2. Draw Foliage (Procedural overlapping circles with autumn colors)
    final Random random = Random(42); // Fixed seed for stable tree
    final colors = [
      const Color(0xFFD35400),
      const Color(0xFFE67E22),
      const Color(0xFFF1C40F),
      const Color(0xFFC0392B),
    ];

    // Sway oscillation
    final double swayX = sin(swayValue * pi) * 15;

    for (int i = 0; i < 60; i++) {
      final double angle = random.nextDouble() * 2 * pi;
      final double radius = random.nextDouble() * 40;
      final double x = centerX + cos(angle) * radius + (swayX * (radius / 40));
      final double y = bottomY - 60 + sin(angle) * radius * 0.8;

      final double circleSize = random.nextDouble() * 15 + 10;
      final paint = Paint()
        ..color = colors[random.nextInt(colors.length)].withValues(alpha: 0.8);

      canvas.drawCircle(Offset(x, y), circleSize, paint);
    }

    // 3. Draw a "Fallen Leaves" small pile at the base
    for (int i = 0; i < 15; i++) {
      final double lx = centerX + (random.nextDouble() - 0.5) * 60;
      final double ly = bottomY + (random.nextDouble() - 0.5) * 10;
      final paint = Paint()
        ..color = colors[random.nextInt(colors.length)].withValues(alpha: 0.7);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(lx, ly), width: 10, height: 5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AutumnTreePainter oldDelegate) {
    return oldDelegate.swayValue != swayValue;
  }
}
