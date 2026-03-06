import 'dart:math';
import 'package:flutter/material.dart';

class SantaSleighWidget extends StatefulWidget {
  const SantaSleighWidget({super.key});

  @override
  State<SantaSleighWidget> createState() => _SantaSleighWidgetState();
}

class _SantaSleighWidgetState extends State<SantaSleighWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // A full loop takes 15 seconds to cross the screen and reset
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _SantaPainter(
              animationValue: _controller.value,
              brightness: Theme.of(context).brightness,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _SantaPainter extends CustomPainter {
  final double animationValue;
  final Brightness brightness;

  _SantaPainter({required this.animationValue, required this.brightness});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Movement logic
    // We want the sleigh to fly from right to left.
    // X goes from (w + 400) down to -400.
    final double totalFlightDistance = w + 800; // Extra padding
    final double currentX = (w + 400) - (animationValue * totalFlightDistance);

    // Sine wave bobbing flight path
    // The sleigh bobs up and down smoothly based on horizontal position
    final double flyHeight = h * 0.3; // Flies roughly at upper 30% of screen
    final double bobAmount = 30.0;
    // Faster sine wave based on X so it bobs multiple times across the screen
    final double currentY =
        flyHeight + sin(animationValue * pi * 8) * bobAmount;

    // Fast leg animation cycle (galloping) for reindeer
    final double gallopCycle = (animationValue * 150) % (2 * pi);

    // Common Colors
    final isDark = brightness == Brightness.dark;
    final Color sleighRed = Colors.red.shade700;
    final Color sleighGold = Colors.amber;
    final Color reindeerBrown =
        isDark ? const Color(0xFFC48A5A) : const Color(0xFF8B5A2B);
    final Color darkBrown = const Color(0xFF5C4033);
    final Color reinsColor = isDark
        ? Colors.redAccent.withOpacity(0.5)
        : Colors.red.withOpacity(0.8);

    canvas.save();
    // Translate canvas to the current X and Y origin for drawing everything relative
    canvas.translate(currentX, currentY);

    // The scale of the entire team
    final double scale = 0.5; // Roughly half scale for elegance
    canvas.scale(scale);

    // DRAW REINDEER
    // Sleigh is at origin (0,0) (or slightly adjusted). Reindeer lead ahead (left -> negative X).

    // Draw from right to left (back to front visually logic if they overlapped, but we'll just draw them)
    // Actually, draw front ones first (furthest left)? Doesn't matter much.
    // Let's draw 3 reindeer in a row.
    final List<Offset> reindeerPositions = [
      const Offset(-150, 20), // Closest to sleigh
      const Offset(-280, 10), // Middle
      const Offset(-410, 0), // Front leader (Rudolph)
    ];

    // Helper to draw a single reindeer
    void drawReindeer(Offset pos, bool isLeader) {
      canvas.save();
      canvas.translate(pos.dx, pos.dy);

      // Reindeer body
      final Paint bodyPaint = Paint()
        ..color = reindeerBrown
        ..style = PaintingStyle.fill;
      final Paint legPaint = Paint()
        ..color = darkBrown
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      // Gallop math: Legs rotate opposite to each other.
      // - Front legs angle
      final double angleF = sin(gallopCycle) * 0.8;
      // - Back legs angle
      final double angleB = -sin(gallopCycle) * 0.8;

      final Offset frontHip = const Offset(-20, 10);
      final Offset backHip = const Offset(20, 10);

      // Back legs
      canvas.drawLine(
          backHip,
          Offset(backHip.dx + sin(angleB) * 20, backHip.dy + cos(angleB) * 20),
          legPaint); // Back Far
      canvas.drawLine(
          backHip,
          Offset(backHip.dx + sin(angleB - 0.5) * 20,
              backHip.dy + cos(angleB - 0.5) * 20),
          legPaint); // Back Near

      // Front legs
      canvas.drawLine(
          frontHip,
          Offset(
              frontHip.dx + sin(angleF) * 20, frontHip.dy + cos(angleF) * 20),
          legPaint); // Front Far
      canvas.drawLine(
          frontHip,
          Offset(frontHip.dx + sin(angleF - 0.5) * 20,
              frontHip.dy + cos(angleF - 0.5) * 20),
          legPaint); // Front Near

      // Torso (oval)
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, 0), width: 60, height: 30),
          bodyPaint);

      // Neck & Head
      canvas.drawPath(
          Path()
            ..moveTo(-15, -5)
            ..lineTo(-35, -25)
            ..lineTo(-45, -20)
            ..lineTo(-30, 0)
            ..close(),
          bodyPaint);

      // Snout
      canvas.drawOval(
          Rect.fromCenter(
              center: const Offset(-45, -20), width: 20, height: 12),
          bodyPaint);

      // Antlers
      final Paint antlerPaint = Paint()
        ..color = darkBrown
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          const Offset(-35, -25), const Offset(-30, -40), antlerPaint);
      canvas.drawLine(
          const Offset(-35, -25), const Offset(-40, -45), antlerPaint);

      if (isLeader) {
        // Rudolph red nose
        final Paint redPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;
        final Paint glowPaint = Paint()
          ..color = Colors.redAccent.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(const Offset(-52, -20), 4, glowPaint);
        canvas.drawCircle(const Offset(-52, -20), 3, redPaint);
      } else {
        // Normal nose
        canvas.drawCircle(
            const Offset(-52, -20), 2, Paint()..color = Colors.black87);
      }

      // Reins attachment point
      // canvas.drawCircle(Offset(-20, 0), 2, Paint()..color = sleighGold);

      canvas.restore();
    }

    // Draw Reins connecting sleigh to reindeer
    final Paint reinsLinePaint = Paint()
      ..color = reinsColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final Offset sleighReinsAttach = const Offset(0, 10);
    // Draw wavy lines connecting them
    Path reinsPath = Path()..moveTo(sleighReinsAttach.dx, sleighReinsAttach.dy);
    for (var pos in reindeerPositions) {
      // Reins attach near neck/collar (dy is pos relative)
      final Offset target = Offset(pos.dx - 20, pos.dy - 5);
      // Quadratic bezier for slight droop
      reinsPath.quadraticBezierTo(
          (reinsPath.getBounds().right + target.dx) / 2,
          (reinsPath.getBounds().bottom + target.dy) / 2 + 10, // Droop
          target.dx,
          target.dy);
    }
    canvas.drawPath(reinsPath, reinsLinePaint);

    // Draw all reindeer
    for (int i = 0; i < reindeerPositions.length; i++) {
      drawReindeer(reindeerPositions[i], i == 2); // 3rd is leader
    }

    // DRAW SLEIGH (At 0,0)
    canvas.translate(40, -10); // Adjust sleigh visual center

    // Runners (skis)
    final Paint runnerPaint = Paint()
      ..color = sleighGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    // Ski line
    canvas.drawLine(const Offset(-60, 45), const Offset(40, 45), runnerPaint);
    // Curl at the front (left side)
    canvas.drawArc(
        Rect.fromLTWH(-75, 25, 30, 40), pi / 2, pi, false, runnerPaint);

    // Ski supports
    canvas.drawLine(const Offset(-40, 25), const Offset(-40, 45), runnerPaint);
    canvas.drawLine(const Offset(20, 25), const Offset(20, 45), runnerPaint);

    // Main sleigh body
    final Path sleighPath = Path()
      ..moveTo(50, -10) // Back top
      ..lineTo(50, 20) // Back bottom
      ..quadraticBezierTo(25, 35, -20, 30) // Curve bottom
      ..lineTo(-50, 25) // Front bottom
      ..quadraticBezierTo(-60, 15, -50, 5) // Front curl
      ..lineTo(-30, 10) // Front dip
      ..quadraticBezierTo(0, 20, 50, -10) // Trim top line
      ..close();

    final Paint sleighBodyPaint = Paint()
      ..color = sleighRed
      ..style = PaintingStyle.fill;
    canvas.drawPath(sleighPath, sleighBodyPaint);

    // Santa's Bag
    final Paint bagPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill; // Dark green bag
    canvas.drawCircle(const Offset(35, -15), 25, bagPaint);
    // Bag tie
    canvas.drawRect(
        Rect.fromCenter(center: const Offset(25, -42), width: 10, height: 10),
        bagPaint);

    // Santa figure
    final Paint santaSuit = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    // Torso
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -15), width: 35, height: 40),
        santaSuit);
    // Head / Face
    canvas.drawCircle(const Offset(-5, -35), 14,
        Paint()..color = const Color(0xFFFFCCAA)); // Skin
    // Hat
    Path hatPath = Path()
      ..moveTo(-20, -35)
      ..lineTo(10, -35)
      ..lineTo(0, -55)
      ..close();
    canvas.drawPath(hatPath, santaSuit);
    // Hat trim & pompom
    canvas.drawCircle(const Offset(-5, -55), 6, Paint()..color = Colors.white);
    canvas.drawRect(
        Rect.fromCenter(center: const Offset(-5, -38), width: 32, height: 6),
        Paint()..color = Colors.white);

    // Beard
    final Paint beardPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-15, -26), 8, beardPaint);
    canvas.drawCircle(const Offset(-5, -20), 10, beardPaint);
    canvas.drawCircle(const Offset(5, -26), 8, beardPaint);

    // Arm holding reins
    canvas.drawLine(
        const Offset(0, -15),
        const Offset(-25, -5),
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round);
    // Mitten
    canvas.drawCircle(const Offset(-28, -5), 5, Paint()..color = Colors.black);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SantaPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.brightness != brightness;
  }
}
