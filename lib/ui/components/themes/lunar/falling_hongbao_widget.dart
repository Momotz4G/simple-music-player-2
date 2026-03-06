import 'dart:math';
import 'package:flutter/material.dart';

class FallingHongbaoWidget extends StatefulWidget {
  const FallingHongbaoWidget({super.key});

  @override
  State<FallingHongbaoWidget> createState() => _FallingHongbaoWidgetState();
}

class _FallingHongbaoWidgetState extends State<FallingHongbaoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_HongbaoItem> _items = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _controller.addListener(_updateItems);

    for (int i = 0; i < 30; i++) {
      _items.add(_createItem(isInitial: true));
    }
  }

  _HongbaoItem _createItem({bool isInitial = false}) {
    final isSparkle = _random.nextDouble() < 0.4;
    return _HongbaoItem(
      x: _random.nextDouble(),
      y: isInitial ? _random.nextDouble() : -0.1,
      speed: 0.001 + _random.nextDouble() * 0.002,
      drift: (_random.nextDouble() - 0.5) * 0.0005,
      rotation: _random.nextDouble() * pi * 2,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.05,
      scale: isSparkle
          ? 0.2 + _random.nextDouble() * 0.3
          : 0.6 + _random.nextDouble() * 0.4,
      opacity: 0.6 + _random.nextDouble() * 0.4,
      isSparkle: isSparkle,
    );
  }

  void _updateItems() {
    for (int i = 0; i < _items.length; i++) {
      _items[i].y += _items[i].speed;
      _items[i].x += _items[i].drift;
      _items[i].rotation += _items[i].rotationSpeed;

      if (_items[i].y > 1.1) {
        _items[i] = _createItem();
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
      painter: _LunarPainter(items: _items),
      child: const SizedBox.expand(),
    );
  }
}

class _HongbaoItem {
  double x, y, speed, drift, rotation, rotationSpeed, scale, opacity;
  bool isSparkle;

  _HongbaoItem({
    required this.x,
    required this.y,
    required this.speed,
    required this.drift,
    required this.rotation,
    required this.rotationSpeed,
    required this.scale,
    required this.opacity,
    required this.isSparkle,
  });
}

class _LunarPainter extends CustomPainter {
  final List<_HongbaoItem> items;
  _LunarPainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in items) {
      canvas.save();
      canvas.translate(item.x * size.width, item.y * size.height);
      canvas.rotate(item.rotation);
      canvas.scale(item.scale);

      if (item.isSparkle) {
        _drawSparkle(canvas, item.opacity);
      } else {
        _drawHongbao(canvas, item.opacity);
      }

      canvas.restore();
    }
  }

  void _drawHongbao(Canvas canvas, double opacity) {
    final paint = Paint()
      ..color = const Color(0xFFD00000).withOpacity(opacity) // Red
      ..style = PaintingStyle.fill;

    // Envelope body
    canvas.drawRRect(
        RRect.fromLTRBR(-8, -12, 8, 12, const Radius.circular(2)), paint);

    // Gold line/mark
    final goldPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(const Offset(0, -2), 3, goldPaint);
    canvas.drawLine(const Offset(-4, 4), const Offset(4, 4), goldPaint);
  }

  void _drawSparkle(Canvas canvas, double opacity) {
    final paint = Paint()
      ..color = const Color(0xFFFFCC33).withOpacity(opacity)
      ..style = PaintingStyle.fill;

    // Diamond shape for gold sparkle
    final path = Path()
      ..moveTo(0, -10)
      ..lineTo(6, 0)
      ..lineTo(0, 10)
      ..lineTo(-6, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LunarPainter oldDelegate) => true;
}
