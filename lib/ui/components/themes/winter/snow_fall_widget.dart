import 'dart:math';

import 'package:flutter/material.dart';

class _Snowflake {
  double x;
  double y;
  double radius;
  double speed;
  double drift;
  double opacity;

  _Snowflake({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.drift,
    required this.opacity,
  });
}

class SnowFallWidget extends StatefulWidget {
  final int snowflakeCount;

  const SnowFallWidget({super.key, this.snowflakeCount = 60});

  @override
  State<SnowFallWidget> createState() => _SnowFallWidgetState();
}

class _SnowFallWidgetState extends State<SnowFallWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Snowflake> _snowflakes = [];
  final Random _random = Random();
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  void _initSnowflakes(Size size) {
    if (_snowflakes.isNotEmpty && _lastSize == size) return;
    _lastSize = size;
    _snowflakes.clear();

    for (int i = 0; i < widget.snowflakeCount; i++) {
      _snowflakes.add(_createSnowflake(size, randomY: true));
    }
  }

  _Snowflake _createSnowflake(Size size, {bool randomY = false}) {
    return _Snowflake(
      x: _random.nextDouble() * size.width,
      y: randomY ? _random.nextDouble() * size.height : -10,
      radius: _random.nextDouble() * 2.5 + 0.5, // 0.5 - 3.0
      speed: _random.nextDouble() * 0.8 + 0.2, // 0.2 - 1.0
      drift: (_random.nextDouble() - 0.5) * 0.5, // -0.25 to 0.25
      opacity: _random.nextDouble() * 0.5 + 0.2, // 0.2 - 0.7
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _initSnowflakes(size);

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Update snowflake positions
              for (var flake in _snowflakes) {
                flake.y += flake.speed;
                flake.x += flake.drift;

                // Reset if below screen
                if (flake.y > size.height + 10) {
                  flake.y = -10;
                  flake.x = _random.nextDouble() * size.width;
                }

                // Wrap horizontally
                if (flake.x > size.width) flake.x = 0;
                if (flake.x < 0) flake.x = size.width;
              }

              return CustomPaint(
                size: size,
                painter: _SnowPainter(_snowflakes),
              );
            },
          );
        },
      ),
    );
  }
}

class _SnowPainter extends CustomPainter {
  final List<_Snowflake> snowflakes;

  _SnowPainter(this.snowflakes);

  @override
  void paint(Canvas canvas, Size size) {
    for (var flake in snowflakes) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: flake.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(flake.x, flake.y), flake.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => true;
}
