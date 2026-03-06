import 'dart:math';
import 'package:flutter/material.dart';

class RocketWidget extends StatefulWidget {
  const RocketWidget({super.key});

  @override
  State<RocketWidget> createState() => _RocketWidgetState();
}

class _RocketWidgetState extends State<RocketWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // A rocket moves significantly faster than a satellite
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 40))
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
            painter: _RocketPainter(_controller.value),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _RocketPainter extends CustomPainter {
  final double progress;
  _RocketPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Rocket moves diagonally from bottom-left to top-right
    final double startX = -100;
    final double endX = size.width + 100;
    final double startY = size.height + 100;
    final double endY = -100;

    final double x = startX + (endX - startX) * progress;
    final double y = startY + (endY - startY) * progress;

    // Angle the rocket to point towards its destination
    final double angle = atan2(endY - startY, endX - startX);

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    canvas.scale(0.5); // Keep it relatively small

    // Colors
    final Paint bodyPaint = Paint()..color = const Color(0xFFE0E0E0);
    final Paint nosePaint = Paint()..color = const Color(0xFFE74C3C);
    final Paint finPaint = Paint()..color = const Color(0xFFC0392B);
    final Paint windowPaint = Paint()..color = const Color(0xFF3498DB);
    final Paint outlinePaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 1. Rocket Fire / Exhaust
    _drawExhaust(canvas);

    // 2. Main Body (Cylinder)
    final Rect bodyRect =
        Rect.fromCenter(center: const Offset(-15, 0), width: 50, height: 20);
    canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(5)), bodyPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(5)),
        outlinePaint);

    // 3. Nose Cone
    final Path nosePath = Path();
    nosePath.moveTo(10, -10);
    nosePath.lineTo(35, 0); // Point
    nosePath.lineTo(10, 10);
    nosePath.close();
    canvas.drawPath(nosePath, nosePaint);
    canvas.drawPath(nosePath, outlinePaint);

    // 4. Fins
    // Top Fin
    final Path topFin = Path();
    topFin.moveTo(-35, -10);
    topFin.lineTo(-45, -25);
    topFin.lineTo(-15, -10);
    topFin.close();
    canvas.drawPath(topFin, finPaint);
    canvas.drawPath(topFin, outlinePaint);

    // Bottom Fin
    final Path bottomFin = Path();
    bottomFin.moveTo(-35, 10);
    bottomFin.lineTo(-45, 25);
    bottomFin.lineTo(-15, 10);
    bottomFin.close();
    canvas.drawPath(bottomFin, finPaint);
    canvas.drawPath(bottomFin, outlinePaint);

    // 5. Window
    canvas.drawCircle(const Offset(0, 0), 5, windowPaint);
    canvas.drawCircle(const Offset(0, 0), 5, outlinePaint);

    canvas.restore();
  }

  void _drawExhaust(Canvas canvas) {
    // Pulse effect
    final double pulse = sin(progress * pi * 100); // Fast pulse

    final Paint outerFlame = Paint()
      ..color = const Color(0xFFE67E22).withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final Paint innerFlame = Paint()
      ..color = const Color(0xFFF1C40F)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final Path outerPath = Path();
    outerPath.moveTo(-40, -5);
    outerPath.lineTo(-70 - (pulse * 10), 0);
    outerPath.lineTo(-40, 5);
    outerPath.close();

    final Path innerPath = Path();
    innerPath.moveTo(-40, -2);
    innerPath.lineTo(-55 - (pulse * 5), 0);
    innerPath.lineTo(-40, 2);
    innerPath.close();

    canvas.drawPath(outerPath, outerFlame);
    canvas.drawPath(innerPath, innerFlame);
  }

  @override
  bool shouldRepaint(covariant _RocketPainter oldDelegate) => true;
}
