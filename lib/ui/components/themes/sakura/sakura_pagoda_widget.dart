import 'package:flutter/material.dart';

class SakuraPagodaWidget extends StatelessWidget {
  final double height;
  final double width;
  const SakuraPagodaWidget({super.key, this.height = 200, this.width = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _PagodaPainter(),
      ),
    );
  }
}

class _PagodaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E1E1E) // Dark silhouette
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = const Color(0xFFB71C1C).withOpacity(0.4) // Subtle red accent
      ..style = PaintingStyle.fill;

    final double centerX = size.width / 2;
    final double bottomY = size.height;

    // Draw Base
    canvas.drawRect(
        Rect.fromLTWH(
            centerX - (size.width * 0.35), bottomY - 15, size.width * 0.7, 15),
        paint);

    // Tiered structure (5 tiers usually for a classic pagoda)
    double currentY = bottomY - 15;
    double currentWidth = size.width * 0.7; // Substantial width
    const double tierHeight = 35.0; // Taller tiers

    for (int i = 0; i < 5; i++) {
      _drawTier(canvas, centerX, currentY, currentWidth, tierHeight, paint,
          accentPaint);
      currentY -= (tierHeight + 8);
      currentWidth *= 0.82; // Tapering
    }

    // Spire (Finial)
    final spirePaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(centerX, currentY + 5),
        Offset(centerX, currentY - 15), spirePaint);
    canvas.drawCircle(Offset(centerX, currentY - 15), 2, paint);
  }

  void _drawTier(Canvas canvas, double cx, double cy, double w, double h,
      Paint paint, Paint accentPaint) {
    // 1. Pillar/Walls
    canvas.drawRect(Rect.fromLTWH(cx - (w * 0.4), cy - h, w * 0.8, h), paint);

    // Subtle red glow inside
    canvas.drawRect(Rect.fromLTWH(cx - 2, cy - (h * 0.6), 4, 6), accentPaint);

    // 2. Curved Roof
    final Path roofPath = Path();
    final double rw = w * 1.4; // Roof wider than walls
    final double rh = 8.0; // Roof height/curve

    roofPath.moveTo(cx - rw / 2, cy - h);
    roofPath.quadraticBezierTo(cx, cy - h - rh, cx + rw / 2, cy - h);
    roofPath.lineTo(cx + rw / 2 + 4, cy - h + 2); // Eave tip
    roofPath.quadraticBezierTo(
        cx, cy - h - (rh * 0.3), cx - rw / 2 - 4, cy - h + 2);
    roofPath.close();

    canvas.drawPath(roofPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
