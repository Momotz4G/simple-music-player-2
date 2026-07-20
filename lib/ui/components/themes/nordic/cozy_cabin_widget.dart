import 'package:flutter/material.dart';

class CozyCabinWidget extends StatefulWidget {
  const CozyCabinWidget({super.key});

  @override
  State<CozyCabinWidget> createState() => _CozyCabinWidgetState();
}

class _CozyCabinWidgetState extends State<CozyCabinWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
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
          painter: _CabinPainter(_controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _CabinPainter extends CustomPainter {
  final double pulse;
  _CabinPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    const double cabinWidth = 60;
    const double cabinHeight = 50;
    final double x = size.width * 0.5;
    final double y = size.height - 20;

    canvas.save();
    canvas.translate(x, y);

    final Paint cabinPaint = Paint()
      ..color = const Color(0xFF1A1F24)
      ..style = PaintingStyle.fill;
    final Paint roofPaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..style = PaintingStyle.fill;

    // Main structure
    canvas.drawRect(
        const Rect.fromLTWH(-cabinWidth * 0.5, -cabinHeight, cabinWidth, cabinHeight),
        cabinPaint);

    // Roof
    final Path roofPath = Path();
    roofPath.moveTo(-cabinWidth * 0.6, -cabinHeight);
    roofPath.lineTo(0, -cabinHeight * 1.4);
    roofPath.lineTo(cabinWidth * 0.6, -cabinHeight);
    roofPath.close();
    canvas.drawPath(roofPath, roofPaint);

    // Chimney
    canvas.drawRect(
        const Rect.fromLTWH(-cabinWidth * 0.35, -cabinHeight * 1.3, 8, 15),
        cabinPaint);

    // Window Glow
    final double glowIntensity = 0.4 + 0.6 * pulse;
    final Paint glowPaint = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final Rect windowRect =
        Rect.fromCenter(center: const Offset(10, -25), width: 14, height: 14);
    canvas.drawRect(windowRect, glowPaint);

    final Paint windowFrame = Paint()
      ..color = const Color(0xFFFFD166)
      ..style = PaintingStyle.fill;
    canvas.drawRect(windowRect, windowFrame);

    // Door
    final Paint doorPaint = Paint()..color = const Color(0xFF14181B);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-18, -25, 12, 25), const Radius.circular(2)),
        doorPaint);

    // Snow on roof
    final Paint snowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    final Path snowPath = Path();
    snowPath.moveTo(-cabinWidth * 0.6, -cabinHeight);
    snowPath.lineTo(0, -cabinHeight * 1.4);
    snowPath.lineTo(cabinWidth * 0.1, -cabinHeight * 1.33); // Irregular snow
    snowPath.lineTo(cabinWidth * 0.6, -cabinHeight);
    snowPath.lineTo(cabinWidth * 0.4, -cabinHeight + 5);
    snowPath.lineTo(0, -cabinHeight * 1.3);
    snowPath.lineTo(-cabinWidth * 0.4, -cabinHeight + 5);
    snowPath.close();
    canvas.drawPath(snowPath, snowPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CabinPainter oldDelegate) => true;
}
