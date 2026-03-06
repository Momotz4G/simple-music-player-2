import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class LightningWidget extends StatefulWidget {
  const LightningWidget({super.key});

  @override
  State<LightningWidget> createState() => _LightningWidgetState();
}

class _LightningWidgetState extends State<LightningWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Offset> _boltPoints = [];
  Timer? _strikeTimer;
  final Random _random = Random();
  double _flashOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _controller.addListener(() {
      setState(() {
        if (_controller.value < 0.3) {
          // Rapid flash at start
          _flashOpacity = (1.0 - (_controller.value / 0.3)) * 0.4;
        } else {
          _flashOpacity = 0.0;
        }
      });
    });

    _startRandomStrikes();
  }

  void _startRandomStrikes() {
    // Random delay between 4 and 10 seconds
    final delay = 4000 + _random.nextInt(6000);
    _strikeTimer = Timer(Duration(milliseconds: delay), () {
      if (mounted) {
        _triggerStrike();
        _startRandomStrikes();
      }
    });
  }

  void _triggerStrike() {
    _generateBolt();
    _controller.forward(from: 0.0);
  }

  void _generateBolt() {
    final List<Offset> points = [];
    double x = _random.nextDouble() * 400 + 100; // Random x start
    double y = 0;
    points.add(Offset(x, y));

    while (y < 600) {
      y += 15 + _random.nextDouble() * 30;
      x += (_random.nextDouble() - 0.5) * 60;
      points.add(Offset(x, y));

      // Small chance of a branch
      if (_random.nextDouble() < 0.1) {
        // Could add branching logic here, but keeping it simple for now
      }
    }

    setState(() {
      _boltPoints = points;
    });
  }

  @override
  void dispose() {
    _strikeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Screen Flash
          Container(
            color: Colors.white.withOpacity(_flashOpacity),
          ),
          // Bolt
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Bolt is visible only in the first 400ms
              double boltOpacity = 0.0;
              if (_controller.value < 0.4) {
                // Flicker effect
                boltOpacity = (_random.nextDouble() > 0.2) ? 0.8 : 0.2;
              }

              return CustomPaint(
                painter: _LightningPainter(
                  points: _boltPoints,
                  opacity: boltOpacity,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LightningPainter extends CustomPainter {
  final List<Offset> points;
  final double opacity;

  _LightningPainter({required this.points, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || points.isEmpty) return;

    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Glow
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LightningPainter oldDelegate) => true;
}
