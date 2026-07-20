import 'dart:math';
import 'package:flutter/material.dart';

class FirecrackersWidget extends StatefulWidget {
  final double height;
  final double width;
  const FirecrackersWidget({super.key, this.height = 300, this.width = 60});

  @override
  State<FirecrackersWidget> createState() => _FirecrackersWidgetState();
}

class _FirecrackersWidgetState extends State<FirecrackersWidget>
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
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _FirecrackerPainter(animationValue: _controller.value),
          );
        },
      ),
    );
  }
}

class _FirecrackerPainter extends CustomPainter {
  final double animationValue;
  _FirecrackerPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(88); // Stable string
    final double centerX = size.width / 2;
    const double stringTopY = 10.0;
    final double stringBottomY = size.height - 40;

    final redPaint = Paint()
      ..color = const Color(0xFFD00000)
      ..style = PaintingStyle.fill;

    final goldPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    // String/Wire
    final stringPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(
        Offset(centerX, 0), Offset(centerX, stringBottomY), stringPaint);

    // Crackers on sides
    for (int i = 0; i < 6; i++) {
      final double y = stringTopY + (i * 16);
      final bool isLeft = i % 2 == 0;
      final double sign = isLeft ? -1 : 1;

      // Slight sway based on animationValue
      final double sway = sin(animationValue * pi + i) * 2;

      canvas.save();
      canvas.translate(centerX + sway, y);
      canvas.rotate(sign * (pi / 8 + random.nextDouble() * 0.2));

      // Cracker body
      canvas.drawRRect(
          RRect.fromLTRBR(0, -4, 18 * sign, 4, const Radius.circular(1)),
          redPaint);
      // Gold tip
      canvas.drawRect(
          Rect.fromLTWH(14 * sign, -4, 4 * sign.abs(), 8), goldPaint);

      canvas.restore();
    }

    // Bottom bundle
    const double bundleY = stringTopY + (6 * 16) + 10;
    canvas.drawCircle(Offset(centerX, bundleY), 8, redPaint);
    canvas.drawCircle(
        Offset(centerX, bundleY),
        8,
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke);

    // Sparkle at bottom occasionally
    if (animationValue > 0.8) {
      final sparklePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(
          Offset(centerX + (random.nextDouble() - 0.5) * 10, bundleY + 10),
          3,
          sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FirecrackerPainter oldDelegate) => true;
}
