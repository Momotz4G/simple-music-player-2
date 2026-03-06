import 'dart:math';
import 'package:flutter/material.dart';

class SatelliteWidget extends StatefulWidget {
  const SatelliteWidget({super.key});

  @override
  State<SatelliteWidget> createState() => _SatelliteWidgetState();
}

class _SatelliteWidgetState extends State<SatelliteWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Drifts very slowly across the whole screen
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();
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
          painter: _SatellitePainter(_controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _SatellitePainter extends CustomPainter {
  final double progress;
  _SatellitePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Move from right to left slowly, with a slight upward drift
    // Starts off-screen right, ends off-screen left
    final double startX = size.width + 100;
    final double endX = -100;
    final double startY = size.height * 0.6;
    final double endY = size.height * 0.2;

    final double x = startX + (endX - startX) * progress;
    final double y = startY + (endY - startY) * progress;

    // Slow rotation
    final double rotation = progress * pi * 2;

    canvas.save();
    canvas.translate(x, y);

    // Add a slight bobbing motion
    canvas.translate(0, sin(progress * pi * 8) * 20);

    canvas.rotate(rotation);
    canvas.scale(0.8); // Slightly scale down

    final Paint silver = Paint()..color = const Color(0xFFBDC3C7);
    final Paint darkMetal = Paint()..color = const Color(0xFF7F8C8D);
    final Paint gold = Paint()..color = const Color(0xFFF1C40F);
    final Paint solarPanel = Paint()..color = const Color(0xFF2980B9);
    final Paint solarGrid = Paint()
      ..color = const Color(0xFF34495E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Center body (cylinder)
    canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 30, height: 40), silver);
    canvas.drawRect(
        Rect.fromCenter(center: const Offset(0, -15), width: 30, height: 10),
        darkMetal);
    canvas.drawRect(
        Rect.fromCenter(center: const Offset(0, 15), width: 30, height: 10),
        darkMetal);

    // Antenna dish
    final Path dishPath = Path();
    dishPath.moveTo(-15, -25);
    dishPath.quadraticBezierTo(0, -45, 15, -25);
    dishPath.close();
    canvas.drawPath(dishPath, silver);

    // Antenna spike
    canvas.drawRect(
        Rect.fromCenter(center: const Offset(0, -35), width: 3, height: 20),
        gold);
    canvas.drawCircle(
        const Offset(0, -45), 2, Paint()..color = Colors.red); // Blinking light

    // Left Solar Panel Unit
    _drawSolarPanel(canvas, const Offset(-55, 0), solarPanel, solarGrid);
    // Left connector arm
    canvas.drawRect(
        Rect.fromCenter(center: const Offset(-25, 0), width: 20, height: 6),
        darkMetal);

    // Right Solar Panel Unit
    _drawSolarPanel(canvas, const Offset(55, 0), solarPanel, solarGrid);
    // Right connector arm
    canvas.drawRect(
        Rect.fromCenter(center: const Offset(25, 0), width: 20, height: 6),
        darkMetal);

    canvas.restore();
  }

  void _drawSolarPanel(
      Canvas canvas, Offset center, Paint panelPaint, Paint gridPaint) {
    final Rect panel = Rect.fromCenter(center: center, width: 60, height: 30);
    canvas.drawRect(panel, panelPaint);

    // Draw grid lines
    for (double i = -20; i <= 20; i += 10) {
      canvas.drawLine(Offset(center.dx + i, center.dy - 15),
          Offset(center.dx + i, center.dy + 15), gridPaint);
    }
    canvas.drawLine(Offset(center.dx - 30, center.dy),
        Offset(center.dx + 30, center.dy), gridPaint);
  }

  @override
  bool shouldRepaint(covariant _SatellitePainter oldDelegate) => true;
}
