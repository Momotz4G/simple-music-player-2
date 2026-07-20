import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedTreeWidget extends StatefulWidget {
  final double height;
  final double width;
  const AnimatedTreeWidget({super.key, this.height = 150, this.width = 150});

  @override
  State<AnimatedTreeWidget> createState() => _AnimatedTreeWidgetState();
}

class _AnimatedTreeWidgetState extends State<AnimatedTreeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
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
            painter: _TreePainter(
              animationValue: _controller.value,
              treeColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.3),
            ),
          );
        },
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  final double animationValue;
  final Color treeColor;

  _TreePainter({required this.animationValue, required this.treeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Shift the tree slightly left
    final double treeCenterX = size.width * 0.40;

    // Normal padding now that it clears the player bar
    final double bottomY = size.height - 5;
    const double topY = 20;
    final double treeHeight = bottomY - topY;

    // We build the tree out of overlapping dots (leaves/branches) arranged in a spiral
    const int totalDots = 400;
    const double rotations = 15.0; // How many times the spiral wraps around

    List<_Point3D> points = [];

    // The maximum radius the tree reaches at the bottom
    final double maxTreeRadius = size.width / 3.2;

    for (int i = 0; i < totalDots; i++) {
      final double progress = i / totalDots;
      final double y = topY + (progress * treeHeight);

      // Max radius at this Y (cone shape).
      final double currentMaxRadius = maxTreeRadius * pow(progress, 1.2);

      final double baseAngle = progress * rotations * 2 * pi;
      final double currentAngle = baseAngle + (animationValue * 2 * pi);

      // Calculate 3D positions (origin center)
      final double xOffset = cos(currentAngle) * currentMaxRadius;
      final double zOffset = sin(currentAngle) * currentMaxRadius;

      // Project to 2D screen space around the shifted tree center
      final double screenX = treeCenterX + xOffset;

      final double dotRadius = 1.0 + (progress * 2.5);

      final List<Color> colors = [
        Colors.redAccent.shade100,
        Colors.greenAccent.shade400,
        Colors.blueAccent.shade100,
        Colors.yellow.shade300,
        Colors.purpleAccent.shade100,
        Colors.orangeAccent.shade200,
        Colors.white,
      ];
      final Color dotColor = colors[i % colors.length];

      points.add(_Point3D(screenX, y, zOffset, dotRadius, dotColor));
    }

    // Sort by Z depth (ascending: draw negative/back first)
    points.sort((a, b) => a.z.compareTo(b.z));

    // --- GINGERBREAD HOUSE ---
    // Draw it explicitly to the right of the tree's maximum radius
    // Base it strictly off the tree's center + max radius + small padding
    final double houseX = treeCenterX + maxTreeRadius + 15.0;
    final double houseY = bottomY - 30; // Sitting on the "ground"

    // Draw House Base
    final Paint houseBasePaint = Paint()
      ..color = const Color(0xFF8B5A2B); // Brown
    canvas.drawRect(Rect.fromLTWH(houseX, houseY, 35, 30), houseBasePaint);

    // Draw Roof
    final Path roofPath = Path()
      ..moveTo(houseX - 5, houseY) // Left overhang
      ..lineTo(houseX + 17.5, houseY - 20) // Peak
      ..lineTo(houseX + 40, houseY) // Right overhang
      ..close();
    final Paint roofPaint = Paint()
      ..color = const Color(0xFFCD853F); // Light Brown Roof
    canvas.drawPath(roofPath, roofPaint);

    // Draw Snow on Roof (thick rounded line)
    final Path snowPath = Path()
      ..moveTo(houseX - 5, houseY)
      ..lineTo(houseX + 17.5, houseY - 20)
      ..lineTo(houseX + 40, houseY);
    final Paint snowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(snowPath, snowPaint);

    // Draw Door
    final Paint doorPaint = Paint()
      ..color = const Color(0xFF5C4033); // Dark brown door
    canvas.drawRect(Rect.fromLTWH(houseX + 10, houseY + 12, 12, 18), doorPaint);

    // Glowing warm Window
    final Paint windowPaint = Paint()
      ..color = Colors.yellowAccent.withValues(alpha: 0.8);
    // Left window
    canvas.drawCircle(Offset(houseX + 5, houseY + 12), 4, windowPaint);
    // Right window
    canvas.drawCircle(Offset(houseX + 30, houseY + 12), 4, windowPaint);

    // Chimney
    canvas.drawRect(
        Rect.fromLTWH(houseX + 25, houseY - 22, 6, 12), houseBasePaint);
    // Chimney snow
    canvas.drawLine(Offset(houseX + 24, houseY - 22),
        Offset(houseX + 32, houseY - 22), snowPaint..strokeWidth = 4.0);

    for (var pt in points) {
      // Depth shading: dots in back are darker/more transparent
      // Normalized Z from -1 to 1 roughly
      final double maxZ = size.width / 2.5;
      final double normalizedZ = (pt.z / maxZ).clamp(-1.0, 1.0);

      // opacity: 0.4 (back) to 0.9 (front)
      final double opacity = 0.4 + (normalizedZ * 0.3) + 0.1;

      paint.color = pt.color.withValues(alpha: opacity.clamp(0.1, 1.0));
      canvas.drawCircle(Offset(pt.x, pt.y), pt.radius, paint);
    }

    // Draw a shining 5-pointed star at the top
    final Paint starGlowPaint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0)
      ..style = PaintingStyle.fill;

    final Paint starCorePaint = Paint()
      ..color = Colors.yellowAccent
      ..style = PaintingStyle.fill;

    // Helper to draw a 5 pointed star
    void drawStar(Canvas c, Offset center, double outerRadius,
        double innerRadius, Paint p) {
      final path = Path();
      const int points = 5;
      const double step = pi / points;
      // Start pointing straight up  (angle -pi/2)
      double angle = -pi / 2;

      for (int i = 0; i < points * 2; i++) {
        final double r = (i.isEven) ? outerRadius : innerRadius;
        final double x = center.dx + cos(angle) * r;
        final double y = center.dy + sin(angle) * r;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        angle += step;
      }
      path.close();
      c.drawPath(path, p);
    }

    // Animate the star glowing slightly
    final double starGlowScale =
        1.0 + sin(animationValue * pi * 8) * 0.2; // Fast pulse

    final Offset starCenter = Offset(treeCenterX, topY - 6);
    // Draw glow
    drawStar(canvas, starCenter, 12 * starGlowScale, 5 * starGlowScale,
        starGlowPaint);
    // Draw solid core
    drawStar(canvas, starCenter, 8, 3.5, starCorePaint);
  }

  @override
  bool shouldRepaint(covariant _TreePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.treeColor != treeColor;
  }
}

class _Point3D {
  final double x;
  final double y;
  final double z;
  final double radius;
  final Color color;
  _Point3D(this.x, this.y, this.z, this.radius, this.color);
}
