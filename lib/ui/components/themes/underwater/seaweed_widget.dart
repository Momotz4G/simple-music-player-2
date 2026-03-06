import 'dart:math';
import 'package:flutter/material.dart';

class SeaweedWidget extends StatefulWidget {
  final double height;
  final double width;
  const SeaweedWidget({super.key, required this.height, required this.width});

  @override
  State<SeaweedWidget> createState() => _SeaweedWidgetState();
}

class _SeaweedWidgetState extends State<SeaweedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
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
          size: Size(widget.width, widget.height),
          painter: _SeaweedPainter(_controller.value),
        );
      },
    );
  }
}

class _SeaweedPainter extends CustomPainter {
  final double animationValue;
  _SeaweedPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(1234);
    final int plantCount = 5;

    for (int i = 0; i < plantCount; i++) {
      final double xBase = (i * (size.width / plantCount)) + 20;
      final double h = size.height * (0.6 + random.nextDouble() * 0.4);

      final seaweedPaint = Paint()
        ..color = i % 2 == 0 ? const Color(0xFF2D5A27) : const Color(0xFF1E3F19)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round;

      final Path path = Path();
      path.moveTo(xBase, size.height);

      // Define a swaying curve
      for (int j = 0; j <= 10; j++) {
        final double t = j / 10;
        final double py = size.height - (t * h);

        // Sway calculation
        final double sway = sin(animationValue * 2 * pi + (t * 2)) * (15 * t);
        final double px = xBase + sway;

        if (j == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }

        // Draw small leaves
        if (j > 2 && j % 2 == 0) {
          _drawLeaf(canvas, px, py, sway > 0, seaweedPaint.color);
        }
      }

      canvas.drawPath(path, seaweedPaint);
    }
  }

  void _drawLeaf(Canvas canvas, double x, double y, bool right, Color color) {
    final leafPaint = Paint()..color = color.withOpacity(0.8);
    final double leafOffset = right ? 8 : -8;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x + leafOffset, y), width: 12, height: 6),
        leafPaint);
  }

  @override
  bool shouldRepaint(covariant _SeaweedPainter oldDelegate) => true;
}
