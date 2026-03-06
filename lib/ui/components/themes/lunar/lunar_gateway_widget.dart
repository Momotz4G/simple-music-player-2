import 'package:flutter/material.dart';

class LunarGatewayWidget extends StatelessWidget {
  final double height;
  final double width;
  const LunarGatewayWidget({super.key, this.height = 300, this.width = 400});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _GatewayPainter(),
      ),
    );
  }
}

class _GatewayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final redPaint = Paint()
      ..color = const Color(0xFFD00000)
      ..style = PaintingStyle.fill;

    final darkRedPaint = Paint()
      ..color = const Color(0xFF900000)
      ..style = PaintingStyle.fill;

    final goldPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    final double centerX = size.width / 2;
    final double bottomY = size.height;

    // 1. Pillars (Paifang has multiple pillars, usually 2 or 4)
    const double pillarWidth = 12.0;
    const double mainSpan = 140.0;

    // Draw Main Pillars
    canvas.drawRect(
        Rect.fromLTWH(centerX - (mainSpan / 2) - pillarWidth, bottomY - 300,
            pillarWidth, 300),
        darkRedPaint);
    canvas.drawRect(
        Rect.fromLTWH(
            centerX + (mainSpan / 2), bottomY - 300, pillarWidth, 300),
        darkRedPaint);

    // Bases for pillars
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(centerX - (mainSpan / 2) - pillarWidth - 4,
                bottomY - 10, pillarWidth + 8, 10),
            const Radius.circular(2)),
        redPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(centerX + (mainSpan / 2) - 4, bottomY - 10,
                pillarWidth + 8, 10),
            const Radius.circular(2)),
        redPaint);

    // 2. Main Beam/Signboard area
    canvas.drawRect(
        Rect.fromLTWH(centerX - (mainSpan / 2), bottomY - 260, mainSpan, 40),
        redPaint);
    // Gold Trim on beam
    canvas.drawRect(
        Rect.fromLTWH(centerX - (mainSpan / 2), bottomY - 260, mainSpan, 4),
        goldPaint);
    canvas.drawRect(
        Rect.fromLTWH(centerX - (mainSpan / 2), bottomY - 224, mainSpan, 4),
        goldPaint);

    // 3. Ornate Roof (Traditional Paifang roof)
    _drawCurvedRoof(canvas, centerX, bottomY - 260, mainSpan * 1.4, 40,
        darkRedPaint, goldPaint);
  }

  void _drawCurvedRoof(Canvas canvas, double cx, double topY, double w,
      double h, Paint paint, Paint goldPaint) {
    final Path roofPath = Path();
    roofPath.moveTo(cx - w / 2, topY);
    roofPath.quadraticBezierTo(cx, topY - h, cx + w / 2, topY);
    roofPath.lineTo(cx + w / 2 + 10, topY + 12); // Upcurved eave
    roofPath.quadraticBezierTo(
        cx, topY - (h * 0.4), cx - w / 2 - 10, topY + 12);
    roofPath.close();

    canvas.drawPath(roofPath, paint);

    // Gold accents on roof tips
    canvas.drawCircle(Offset(cx - w / 2 - 8, topY + 10), 4, goldPaint);
    canvas.drawCircle(Offset(cx + w / 2 + 8, topY + 10), 4, goldPaint);

    // Top ridge decoration
    canvas.drawRect(Rect.fromLTWH(cx - 20, topY - h - 5, 40, 6), goldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
