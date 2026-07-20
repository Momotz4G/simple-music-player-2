import 'package:flutter/material.dart';

class CamelCaravanWidget extends StatefulWidget {
  const CamelCaravanWidget({super.key});

  @override
  State<CamelCaravanWidget> createState() => _CamelCaravanWidgetState();
}

class _CamelCaravanWidgetState extends State<CamelCaravanWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Very slow progression across the screen (right to left)
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 80))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _CamelPainter(_controller.value),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _CamelPainter extends CustomPainter {
  final double progress;
  _CamelPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Walk from right to left
    final double startX = size.width + 100;
    const double endX = -300; // Wide enough to clear 3 camels

    // Walk along the ridge of the midground dune (roughly 75% height)
    final double basePathY = size.height * 0.72;

    final currentX = startX + (endX - startX) * progress;

    // Bobbing animation to simulate walking
    final double bobbing = (progress * 800) % 2.0;
    final double yOffset = (bobbing > 1.0) ? 2.0 : 0.0;

    canvas.save();
    canvas.translate(currentX, basePathY);

    // Scale silhouette
    canvas.scale(0.8);

    final Paint silhouettePaint = Paint()
      ..color = const Color(0xFF3E1200); // Very deep shadow brown

    // Draw 3 camels in a caravan
    _drawCamel(canvas, silhouettePaint, 0, yOffset);
    _drawCamel(
        canvas, silhouettePaint, 70, yOffset > 0 ? 0 : 2); // Opposite leg cycle
    _drawCamel(canvas, silhouettePaint, 140, yOffset);

    // Draw handler in front
    _drawHandler(canvas, silhouettePaint, -40, yOffset > 0 ? 0 : 1);

    canvas.restore();
  }

  void _drawCamel(Canvas canvas, Paint paint, double dx, double dy) {
    canvas.save();
    canvas.translate(dx, dy);

    final Path p = Path();
    // Body and hump
    p.moveTo(0, 0); // Front chest
    p.quadraticBezierTo(5, -15, 20, -10); // Neck base
    p.quadraticBezierTo(25, -25, 30, -5); // Hump
    p.quadraticBezierTo(35, 5, 40, 0); // Tail base
    p.lineTo(40, -5); // Tail
    p.lineTo(42, 5); // Back leg
    p.lineTo(40, 5);
    p.lineTo(38, 0);

    // Belly
    p.lineTo(15, 5);

    // Front leg 1
    p.lineTo(15, 20);
    p.lineTo(13, 20);
    p.lineTo(13, 5);

    // Front leg 2 (offset)
    if (dy == 0) {
      p.moveTo(18, 5);
      p.lineTo(18, 18);
      p.lineTo(16, 18);
      p.lineTo(16, 5);
    }

    // Back leg 2 (offset)
    if (dy > 0) {
      p.moveTo(35, 0);
      p.lineTo(35, 18);
      p.lineTo(33, 18);
      p.lineTo(33, 0);
    }

    p.close();

    // Neck and Head
    final Path head = Path();
    head.moveTo(5, -10); // Base of neck
    head.lineTo(-8, -25); // Top of neck
    head.quadraticBezierTo(-15, -28, -12, -22); // Head/snout
    head.lineTo(-5, -15); // Under jaw
    head.close();

    canvas.drawPath(p, paint);
    canvas.drawPath(head, paint);

    canvas.restore();
  }

  void _drawHandler(Canvas canvas, Paint paint, double dx, double dy) {
    canvas.save();
    canvas.translate(dx, dy);

    // Walking stick
    canvas.drawLine(
        const Offset(5, -15), const Offset(-5, 18), paint..strokeWidth = 2);

    // Body
    final Rect body =
        Rect.fromCenter(center: const Offset(0, 5), width: 6, height: 18);
    canvas.drawRect(body, paint);

    // Head wrap
    canvas.drawCircle(const Offset(0, -6), 4, paint);

    // Rope leading back
    final Paint ropePaint = Paint()
      ..color = paint.color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(0, 0), const Offset(45, -5), ropePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CamelPainter oldDelegate) => true;
}
