import 'package:flutter/material.dart';

class CyberGridWidget extends StatefulWidget {
  const CyberGridWidget({super.key});

  @override
  State<CyberGridWidget> createState() => _CyberGridWidgetState();
}

class _CyberGridWidgetState extends State<CyberGridWidget>
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
          painter: _CyberGridPainter(animationValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _CyberGridPainter extends CustomPainter {
  final double animationValue;
  _CyberGridPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double horizonY = size.height * 0.45;
    final double bottomY = size.height;
    final double centerX = size.width / 2;

    final gridPaint = Paint()
      ..color = const Color(0xFFBD00FF).withValues(alpha: 0.5) // Neon Purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final glowPaint = Paint()
      ..color = const Color(0xFFBD00FF).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // 1. Perspective Lines (Converging at horizon)
    const int verticalLines = 20;
    for (int i = 0; i <= verticalLines; i++) {
      final double t = i / verticalLines;
      final double xTop = centerX; // All lines converge at horizon center
      final double xBottom =
          (t - 0.5) * size.width * 3.5 + centerX; // Spread wide at bottom

      canvas.drawLine(
          Offset(xBottom, bottomY), Offset(xTop, horizonY), gridPaint);
      canvas.drawLine(
          Offset(xBottom, bottomY), Offset(xTop, horizonY), glowPaint);
    }

    // 2. Horizontal Lines (Moving forward)
    const int horizontalLines = 15;
    for (int i = 0; i < horizontalLines; i++) {
      // Linear animation mapped to a non-linear Y to simulate perspective depth
      double progress = (i + animationValue) / horizontalLines;
      if (progress > 1.0) progress -= 1.0;

      // Exponential-ish curve to make lines feel like they move faster as they get closer
      final double y = horizonY + (progress * progress * (bottomY - horizonY));

      // Width of horizontal line based on depth
      final double gridWidthAtY = progress * size.width * 3.5;

      canvas.drawLine(Offset(centerX - gridWidthAtY / 2, y),
          Offset(centerX + gridWidthAtY / 2, y), gridPaint);
      canvas.drawLine(Offset(centerX - gridWidthAtY / 2, y),
          Offset(centerX + gridWidthAtY / 2, y), glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
