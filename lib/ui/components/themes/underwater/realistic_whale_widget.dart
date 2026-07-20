import 'package:flutter/material.dart';

class RealisticWhaleWidget extends StatefulWidget {
  const RealisticWhaleWidget({super.key});

  @override
  State<RealisticWhaleWidget> createState() => _RealisticWhaleWidgetState();
}

class _RealisticWhaleWidgetState extends State<RealisticWhaleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _x = -0.5;
  double _direction = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 50))
      ..addListener(_update)
      ..repeat();
  }

  void _update() {
    _x += 0.0004 * _direction;
    if (_x > 1.5 && _direction > 0) {
      _direction = -1.0;
      _x = 1.5;
    } else if (_x < -0.5 && _direction < 0) {
      _direction = 1.0;
      _x = -0.5;
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
      painter: _WhalePainter(_x, _direction),
      child: const SizedBox.expand(),
    );
  }
}

class _WhalePainter extends CustomPainter {
  final double xPct;
  final double direction;
  _WhalePainter(this.xPct, this.direction);

  @override
  void paint(Canvas canvas, Size size) {
    final double whaleX = xPct * size.width;
    final double whaleY = size.height * 0.45;
    final double scale = size.width * 0.38;

    canvas.save();
    canvas.translate(whaleX, whaleY);
    if (direction < 0) {
      canvas.scale(-1, 1);
    }

    // Colors for the "Real" whale
    const Color topColor =
        Color(0xFF4A6B8A); // Lighter blue-gray for the back
    const Color bottomColor =
        Color(0xFF23395B); // Darker navy for the belly
    final Color highlightColor = Colors.white.withValues(alpha: 0.1);

    // DRAW WHALE BODY
    final Path bodyPath = Path();
    bodyPath.moveTo(-scale * 0.5, 0);
    bodyPath.quadraticBezierTo(0, -scale * 0.28, scale * 0.5, 0); // Top
    bodyPath.quadraticBezierTo(
        scale * 0.75, scale * 0.1, scale * 0.5, scale * 0.25); // Mouth area
    bodyPath.quadraticBezierTo(
        0, scale * 0.4, -scale * 0.5, scale * 0.05); // Bottom
    bodyPath.close();

    final bodyGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [topColor, bottomColor],
    ).createShader(
        Rect.fromLTWH(-scale * 0.5, -scale * 0.2, scale, scale * 0.6));

    final Paint bodyPaint = Paint()..shader = bodyGradient;
    canvas.drawPath(bodyPath, bodyPaint);

    // DRAW TAIL
    final Path tailPath = Path();
    tailPath.moveTo(-scale * 0.5, 0.05);
    tailPath.quadraticBezierTo(
        -scale * 0.7, -scale * 0.12, -scale * 0.85, -scale * 0.18);
    tailPath.quadraticBezierTo(-scale * 0.75, 0, -scale * 0.85, scale * 0.18);
    tailPath.quadraticBezierTo(-scale * 0.7, scale * 0.12, -scale * 0.5, 0.05);
    tailPath.close();
    canvas.drawPath(tailPath, bodyPaint);

    // DRAW FIN (Detailed)
    final Path finPath = Path();
    finPath.moveTo(0, scale * 0.18);
    finPath.quadraticBezierTo(
        scale * 0.12, scale * 0.38, -scale * 0.12, scale * 0.28);
    finPath.close();

    final Paint finPaint = Paint()
      ..color = bottomColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(finPath, finPaint);

    // DRAW EYE
    final Paint eyePaint = Paint()..color = Colors.black.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(scale * 0.42, scale * 0.08), 2.5, eyePaint);
    // Eye shine
    canvas.drawCircle(Offset(scale * 0.43, scale * 0.07), 0.8,
        Paint()..color = Colors.white.withValues(alpha: 0.5));

    // SUBTLE BODY LINES (For texture)
    final Paint linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(scale * 0.2, scale * (0.2 + i * 0.03)),
          Offset(scale * 0.4, scale * (0.2 + i * 0.02)), linePaint);
    }

    // BACK HIGHLIGHT
    final Paint highlightPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(bodyPath, highlightPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WhalePainter oldDelegate) => true;
}
