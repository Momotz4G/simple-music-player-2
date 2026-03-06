import 'package:flutter/material.dart';

class MountFujiWidget extends StatelessWidget {
  const MountFujiWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FujiPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _FujiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mountainPaint = Paint()
      ..color = const Color(0xFF2C3E50).withOpacity(0.4) // Deep bluish-gray
      ..style = PaintingStyle.fill;

    final snowPaint = Paint()
      ..color = const Color(0xFFECF0F1).withOpacity(0.6) // Off-white snow
      ..style = PaintingStyle.fill;

    final double width = size.width;
    final double height = size.height;
    final double centerX = width / 2;
    final double bottomY = height;

    // 1. Draw Mountain Body (Wide base, gentle slope)
    final Path mountPath = Path();
    mountPath.moveTo(0, bottomY);
    mountPath.lineTo(width * 0.1, bottomY);
    mountPath.quadraticBezierTo(
        width * 0.3, bottomY, centerX, height * 0.2); // Peak
    mountPath.quadraticBezierTo(width * 0.7, bottomY, width * 0.9, bottomY);
    mountPath.lineTo(width, bottomY);
    mountPath.close();

    canvas.drawPath(mountPath, mountainPaint);

    // 2. Draw Snow Cap (Jagged top)
    final Path snowPath = Path();
    // Start slightly below the peak and follow the top
    snowPath.moveTo(centerX - (width * 0.08), height * 0.35);
    snowPath.lineTo(centerX, height * 0.2); // Real peak
    snowPath.lineTo(centerX + (width * 0.08), height * 0.35);

    // Jagged bottom edge of snow
    snowPath.lineTo(centerX + (width * 0.04), height * 0.38);
    snowPath.lineTo(centerX, height * 0.3);
    snowPath.lineTo(centerX - (width * 0.04), height * 0.38);
    snowPath.close();

    canvas.drawPath(snowPath, snowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
