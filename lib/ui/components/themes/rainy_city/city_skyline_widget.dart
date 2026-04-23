import 'dart:math';
import 'package:flutter/material.dart';

class CitySkylineWidget extends StatefulWidget {
  final double height;
  final double width;
  const CitySkylineWidget({super.key, this.height = 150, this.width = 250});

  @override
  State<CitySkylineWidget> createState() => _CitySkylineWidgetState();
}

class _CitySkylineWidgetState extends State<CitySkylineWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
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
            painter: _CitySkylinePainter(animationValue: _controller.value),
          );
        },
      ),
    );
  }
}

class _CitySkylinePainter extends CustomPainter {
  final double animationValue;
  _CitySkylinePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final buildingPaint = Paint()
      ..color = const Color(0xFF1A1A1D) // Very dark building color
      ..style = PaintingStyle.fill;

    final windowPaint = Paint()..style = PaintingStyle.fill;
    final Random random = Random(55); // Stable skyline

    final double bottomY = size.height;
    const double buildingWidth = 40.0;
    final int buildingCount = (size.width / buildingWidth).floor();

    // 1. Draw Buildings
    for (int i = 0; i < buildingCount; i++) {
      final double bHeight = size.height * (0.4 + random.nextDouble() * 0.4);
      final double bX = i * buildingWidth + 5;
      final double bW = buildingWidth - 10;

      final Rect bRect = Rect.fromLTWH(bX, bottomY - bHeight, bW, bHeight);
      canvas.drawRect(bRect, buildingPaint);

      // 2. Draw Windows
      const int rows = 5;
      const int cols = 2;
      final double winW = bW / (cols + 1);

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          // Only draw some windows
          if (random.nextDouble() > 0.4) {
            final double winX = bX + (c + 1) * winW - (winW / 2);
            final double winY =
                (bottomY - bHeight) + (r + 1) * (bHeight / (rows + 1));

            // Flickering logic
            final double flicker =
                sin(animationValue * 2 * pi + (i * 10) + r) * 0.3 + 0.7;

            windowPaint.color = Colors.amber.withValues(alpha: flicker * 0.6);
            canvas.drawRect(
                Rect.fromCenter(
                    center: Offset(winX, winY), width: 3, height: 4),
                windowPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CitySkylinePainter oldDelegate) => true;
}
