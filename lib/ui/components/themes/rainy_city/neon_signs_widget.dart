import 'dart:math';
import 'package:flutter/material.dart';

class NeonSignsWidget extends StatefulWidget {
  const NeonSignsWidget({super.key});

  @override
  State<NeonSignsWidget> createState() => _NeonSignsWidgetState();
}

class _NeonSignsWidgetState extends State<NeonSignsWidget>
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
          painter: _NeonSignsPainter(animationValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _NeonSignsPainter extends CustomPainter {
  final double animationValue;
  _NeonSignsPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final wirePaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final double width = size.width;
    const double yOffset = 10.0;

    // 1. Draw Sagging Wire (Single long wire)
    final path = Path()
      ..moveTo(0, yOffset)
      ..quadraticBezierTo(width * 0.25, yOffset + 15, width * 0.5, yOffset)
      ..quadraticBezierTo(width * 0.75, yOffset + 15, width, yOffset);
    canvas.drawPath(path, wirePaint);

    // 2. Draw Neon Signs
    _drawNeonText(
        canvas, Offset(width * 0.3, yOffset + 10), "MUSIC", Colors.cyan, 1);
    _drawNeonText(canvas, Offset(width * 0.7, yOffset + 10), "LO-FI",
        const Color(0xFFFF00FF), 2);
  }

  void _drawNeonText(
      Canvas canvas, Offset pos, String text, Color color, int seed) {
    final Random random = Random(seed);
    final double flicker =
        sin(animationValue * 2 * pi * (1.5 + random.nextDouble()) + seed) *
                0.2 +
            0.8;

    // Check for "random" rapid flicker
    final bool isOff =
        random.nextDouble() < 0.05 && (animationValue % 0.1 < 0.02);
    final double opacity = isOff ? 0.1 : flicker;

    final glowPaint = Paint()
      ..color = color.withOpacity(opacity * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);

    final textStyle = TextStyle(
      color: color.withOpacity(opacity),
      fontSize: 14,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace', // Gives it a blocky feel
      shadows: [
        Shadow(color: color, blurRadius: 10 * opacity),
      ],
    );

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Draw glow behind
    canvas.drawRect(
        Rect.fromCenter(
            center:
                pos.translate(textPainter.width / 2, textPainter.height / 2),
            width: textPainter.width + 10,
            height: textPainter.height + 4),
        glowPaint);

    textPainter.paint(canvas, pos);

    // Vertical "hangers" for sign
    final hangerPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(pos.translate(5, -10), pos.translate(5, 0), hangerPaint);
    canvas.drawLine(pos.translate(textPainter.width - 5, -10),
        pos.translate(textPainter.width - 5, 0), hangerPaint);
  }

  @override
  bool shouldRepaint(covariant _NeonSignsPainter oldDelegate) => true;
}
