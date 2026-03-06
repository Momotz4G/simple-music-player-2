import 'dart:math';
import 'package:flutter/material.dart';

class HongbaoPackWidget extends StatelessWidget {
  const HongbaoPackWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HongbaoPackPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _HongbaoPackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(456);
    final paint = Paint()..style = PaintingStyle.fill;

    final double yBase = size.height;

    // Draw ground piles of red envelopes and gold coins
    for (int i = 0; i < 50; i++) {
      final double x = random.nextDouble() * size.width;
      final double yShift = random.nextDouble() * 12;
      final bool isCoin = random.nextDouble() < 0.4;

      if (isCoin) {
        paint.color = const Color(0xFFFFD700)
            .withOpacity(0.7 + random.nextDouble() * 0.3);
        canvas.drawCircle(Offset(x, yBase - yShift - 5),
            3.0 + random.nextDouble() * 2, paint);
      } else {
        paint.color = const Color(0xFFD00000)
            .withOpacity(0.7 + random.nextDouble() * 0.3);
        canvas.save();
        canvas.translate(x, yBase - yShift - 5);
        canvas.rotate((random.nextDouble() - 0.5) * 0.5);
        canvas.drawRRect(
            RRect.fromLTRBR(-6, -8, 6, 8, const Radius.circular(1)), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
