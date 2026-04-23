import 'dart:math';
import 'package:flutter/material.dart';

class FlyingVehiclesWidget extends StatefulWidget {
  const FlyingVehiclesWidget({super.key});

  @override
  State<FlyingVehiclesWidget> createState() => _FlyingVehiclesWidgetState();
}

class _FlyingVehiclesWidgetState extends State<FlyingVehiclesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Vehicle> _vehicles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_update)
      ..repeat();
  }

  void _update() {
    if (_random.nextDouble() < 0.03 && _vehicles.length < 8) {
      _vehicles.add(_Vehicle(
        y: 0.15 + _random.nextDouble() * 0.3,
        speed: 0.005 + _random.nextDouble() * 0.015,
        targetX:
            _random.nextBool() ? 1.2 : -0.2, // Left to right or right to left
        color: _random.nextBool()
            ? const Color(0xFF00FFFF)
            : const Color(0xFFFF00FF),
      ));
    }

    for (int i = _vehicles.length - 1; i >= 0; i--) {
      _vehicles[i].update();
      if (_vehicles[i].isDead) {
        _vehicles.removeAt(i);
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
      painter: _VehiclePainter(vehicles: _vehicles),
      child: const SizedBox.expand(),
    );
  }
}

class _Vehicle {
  double x;
  double y;
  double speed;
  double targetX;
  Color color;
  bool isDead = false;

  _Vehicle(
      {required this.y,
      required this.speed,
      required this.targetX,
      required this.color})
      : x = targetX > 0 ? -0.2 : 1.2;

  void update() {
    if (targetX > 0) {
      x += speed;
      if (x > targetX) isDead = true;
    } else {
      x -= speed;
      if (x < targetX) isDead = true;
    }
  }
}

class _VehiclePainter extends CustomPainter {
  final List<_Vehicle> vehicles;
  _VehiclePainter({required this.vehicles});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint skyPaint = Paint()
      ..color = const Color(0xFF000000); // Black silhouettes

    for (final v in vehicles) {
      final double vx = v.x * size.width;
      final double vy = v.y * size.height;

      // Draw Vehicle Body (futuristic pod/car)
      canvas.drawRRect(
          RRect.fromLTRBR(
              vx - 15, vy - 4, vx + 15, vy + 4, const Radius.circular(3)),
          skyPaint);

      // Draw Lights (Cyan/Magenta)
      final lightPaint = Paint()..color = v.color.withValues(alpha: 0.8);
      final tailPaint = Paint()..color = Colors.red.withValues(alpha: 0.6);

      if (v.targetX > 0) {
        // Moving Right
        canvas.drawRect(
            Rect.fromLTWH(vx + 10, vy - 2, 4, 4), lightPaint); // Front
        canvas.drawRect(
            Rect.fromLTWH(vx - 14, vy - 2, 4, 4), tailPaint); // Back
      } else {
        // Moving Left
        canvas.drawRect(
            Rect.fromLTWH(vx - 14, vy - 2, 4, 4), lightPaint); // Front
        canvas.drawRect(
            Rect.fromLTWH(vx + 10, vy - 2, 4, 4), tailPaint); // Back
      }

      // Occasional Glow
      final glowPaint = Paint()
        ..color = v.color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(vx, vy), 8, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter oldDelegate) => true;
}
