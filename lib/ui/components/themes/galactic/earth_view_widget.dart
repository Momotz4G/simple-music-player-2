import 'package:flutter/material.dart';

class EarthViewWidget extends StatelessWidget {
  const EarthViewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EarthPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _EarthPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Earth should take up roughly 1/4 of the screen (bottom right corner)
    final double radius = size.width * 0.45;
    final Offset center =
        Offset(size.width * 0.95, size.height * 0.95 + radius * 0.2);

    // 1. ATMOSPHERIC GLOW
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1976D2).withValues(alpha: 0.2), // Darker Blue Glow
          const Color(0xFF0D47A1).withValues(alpha: 0.1), // Deep Blue Glow
          const Color(0xFF000000).withValues(alpha: 0.0), // Fade to void
        ],
        stops: const [0.8, 0.9, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.05))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 1.05, glowPaint);

    // 2. EARTH BODY (OCEAN)
    final Paint earthPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.2, -0.8), // Light source from top left
        radius: 0.8,
        colors: [
          Color(0xFF0D47A1), // Darker Ocean
          Color(0xFF000033), // Deeper Ocean
          Color(0xFF000000), // Shadow side
        ],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, earthPaint);

    // 2.5 CONTINENTS
    final Paint continentPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.2, -0.8), // Same light source
        radius: 0.8,
        colors: [
          Color(0xFF388E3C), // Sunlit Green
          Color(0xFF1B5E20), // Deep Forest Green
          Color(0xFF000000), // Shadow side
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final Path continentPath = Path();

    // Abstract Continent 1 (Top Left)
    continentPath.moveTo(center.dx - radius * 0.85, center.dy - radius * 0.3);
    continentPath.quadraticBezierTo(
        center.dx - radius * 0.6,
        center.dy - radius * 0.5,
        center.dx - radius * 0.45,
        center.dy - radius * 0.35);
    continentPath.quadraticBezierTo(
        center.dx - radius * 0.4,
        center.dy - radius * 0.1,
        center.dx - radius * 0.6,
        center.dy + radius * 0.1);
    continentPath.quadraticBezierTo(
        center.dx - radius * 0.8,
        center.dy + radius * 0.2,
        center.dx - radius * 0.85,
        center.dy - radius * 0.3);

    // Abstract Continent 2 (Top Mid/Right)
    continentPath.moveTo(center.dx - radius * 0.2, center.dy - radius * 0.8);
    continentPath.quadraticBezierTo(
        center.dx + radius * 0.2,
        center.dy - radius * 0.9,
        center.dx + radius * 0.6,
        center.dy - radius * 0.6);
    continentPath.quadraticBezierTo(
        center.dx + radius * 0.4,
        center.dy - radius * 0.3,
        center.dx + radius * 0.1,
        center.dy - radius * 0.4);
    continentPath.quadraticBezierTo(
        center.dx - radius * 0.1,
        center.dy - radius * 0.5,
        center.dx - radius * 0.2,
        center.dy - radius * 0.8);

    // Abstract Continent 3 (Bottom Center)
    continentPath.moveTo(center.dx - radius * 0.2, center.dy + radius * 0.3);
    continentPath.quadraticBezierTo(
        center.dx + radius * 0.2,
        center.dy + radius * 0.2,
        center.dx + radius * 0.4,
        center.dy + radius * 0.5);
    continentPath.quadraticBezierTo(
        center.dx + radius * 0.2,
        center.dy + radius * 0.8,
        center.dx - radius * 0.1,
        center.dy + radius * 0.7);
    continentPath.quadraticBezierTo(
        center.dx - radius * 0.3,
        center.dy + radius * 0.6,
        center.dx - radius * 0.2,
        center.dy + radius * 0.3);

    // Draw continents clipped to the earth circle
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawPath(continentPath, continentPaint);
    canvas.restore();

    // 3. CLOUDS OVERLAY
    // Very subtle, stylized cloud swooshes using paths
    final Paint cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    final Path cloudPath1 = Path();
    cloudPath1.moveTo(center.dx - radius * 0.4, center.dy - radius * 0.8);
    cloudPath1.quadraticBezierTo(
        center.dx - radius * 0.1,
        center.dy - radius * 0.85,
        center.dx + radius * 0.2,
        center.dy - radius * 0.75);
    canvas.drawPath(cloudPath1, cloudPaint);

    final Path cloudPath2 = Path();
    cloudPath2.moveTo(center.dx - radius * 0.6, center.dy - radius * 0.6);
    cloudPath2.quadraticBezierTo(
        center.dx - radius * 0.3,
        center.dy - radius * 0.65,
        center.dx + radius * 0.1,
        center.dy - radius * 0.55);
    canvas.drawPath(cloudPath2, cloudPaint..strokeWidth = 20);

    // Tiny city lights on the dark edge
    final Paint cityLights = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final Path lightsPath = Path();
    // Simulate scattered light clusters near the terminator line
    _addLightCluster(
        lightsPath, center.dx - radius * 0.45, center.dy - radius * 0.6);
    _addLightCluster(
        lightsPath, center.dx - radius * 0.35, center.dy - radius * 0.55);
    _addLightCluster(
        lightsPath, center.dx - radius * 0.5, center.dy - radius * 0.45);

    canvas.drawPath(lightsPath, cityLights);
  }

  void _addLightCluster(Path path, double x, double y) {
    path.addOval(Rect.fromCircle(center: Offset(x, y), radius: 2));
    path.addOval(Rect.fromCircle(center: Offset(x + 5, y - 2), radius: 1.5));
    path.addOval(Rect.fromCircle(center: Offset(x - 3, y + 4), radius: 1));
    path.addOval(Rect.fromCircle(center: Offset(x + 2, y + 5), radius: 1));
  }

  @override
  bool shouldRepaint(covariant _EarthPainter oldDelegate) => false;
}
