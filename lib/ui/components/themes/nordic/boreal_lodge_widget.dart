import 'dart:math';
import 'package:flutter/material.dart';

class BorealLodgeWidget extends StatefulWidget {
  const BorealLodgeWidget({super.key});

  @override
  State<BorealLodgeWidget> createState() => _BorealLodgeWidgetState();
}

class _BorealLodgeWidgetState extends State<BorealLodgeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_SmokeParticle> _smoke = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )
      ..addListener(_update)
      ..repeat();
  }

  void _update() {
    // Spawn smoke
    if (_random.nextDouble() < 0.05) {
      _smoke.add(_SmokeParticle(
          x: 0,
          y: 0,
          vx: (_random.nextDouble() - 0.2) * 0.5,
          vy: -0.8 - _random.nextDouble() * 0.5));
    }

    // Update smoke
    for (int i = _smoke.length - 1; i >= 0; i--) {
      _smoke[i].update();
      if (_smoke[i].life <= 0) {
        _smoke.removeAt(i);
      }
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
    // Pulsing value for window light
    final double pulse =
        0.5 + 0.5 * sin(DateTime.now().millisecondsSinceEpoch / 1000.0 * 2.0);

    return CustomPaint(
      painter: _LodgePainter(pulse, _smoke),
      child: const SizedBox.expand(),
    );
  }
}

class _SmokeParticle {
  double x, y, vx, vy;
  double life = 1.0;

  _SmokeParticle(
      {required this.x, required this.y, required this.vx, required this.vy});

  void update() {
    x += vx;
    y += vy;
    vx += 0.01; // Slight wind
    life -= 0.01;
  }
}

class _LodgePainter extends CustomPainter {
  final double windowPulse;
  final List<_SmokeParticle> smoke;
  _LodgePainter(this.windowPulse, this.smoke);

  @override
  void paint(Canvas canvas, Size size) {
    final double lodgeX = size.width * 0.65;
    final double lodgeY = size.height * 0.88;
    const double scale = 80.0;

    canvas.save();
    canvas.translate(lodgeX, lodgeY);

    // 1. DRAW SMOKE
    final Paint smokePaint = Paint()..style = PaintingStyle.fill;
    for (final p in smoke) {
      smokePaint.color = Colors.white.withValues(alpha: p.life * 0.2);
      canvas.drawCircle(Offset(p.x - scale * 0.3, p.y - scale * 0.8),
          2 + (1.0 - p.life) * 8, smokePaint);
    }

    // 2. DRAW LODGE STRUCTURE
    final Paint woodPaint = Paint()
      ..color = const Color(0xFF1B1411); // Very dark brown
    final Paint secondaryWood = Paint()..color = const Color(0xFF140E0C);

    // Main base
    canvas.drawRect(
        const Rect.fromLTWH(-scale * 0.5, -scale * 0.5, scale, scale * 0.5),
        woodPaint);

    // Left wing
    canvas.drawRect(
        const Rect.fromLTWH(-scale * 0.8, -scale * 0.4, scale * 0.4, scale * 0.4),
        secondaryWood);

    // Roofs
    final Path mainRoof = Path();
    mainRoof.moveTo(-scale * 0.6, -scale * 0.5);
    mainRoof.lineTo(0, -scale * 0.9);
    mainRoof.lineTo(scale * 0.6, -scale * 0.5);
    mainRoof.close();

    final Path sideRoof = Path();
    sideRoof.moveTo(-scale * 0.9, -scale * 0.4);
    sideRoof.lineTo(-scale * 0.6, -scale * 0.65);
    sideRoof.lineTo(-scale * 0.3, -scale * 0.4);
    sideRoof.close();

    final Paint roofPaint = Paint()..color = const Color(0xFF0D0908);
    canvas.drawPath(mainRoof, roofPaint);
    canvas.drawPath(sideRoof, roofPaint);

    // Chimney
    canvas.drawRect(
        const Rect.fromLTWH(-scale * 0.35, -scale * 0.85, scale * 0.1, scale * 0.2),
        woodPaint);

    // 3. WINDOWS GOW
    final Paint glowPaint = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.3 * windowPulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final Paint lightPaint = Paint()
      ..color =
          const Color(0xFFFFD166).withValues(alpha: 0.8 + 0.2 * windowPulse);

    // Main window
    final Rect mainWindow = Rect.fromCenter(
        center: const Offset(0, -scale * 0.25),
        width: scale * 0.25,
        height: scale * 0.2);
    canvas.drawRect(mainWindow, glowPaint);
    canvas.drawRect(mainWindow, lightPaint);

    // Small side windows
    final List<Offset> sideWindows = [
      const Offset(-scale * 0.6, -scale * 0.2),
      const Offset(scale * 0.35, -scale * 0.25),
    ];

    for (final offset in sideWindows) {
      final Rect r = Rect.fromCenter(
          center: offset, width: scale * 0.12, height: scale * 0.1);
      canvas.drawRect(r, glowPaint);
      canvas.drawRect(r, lightPaint);
    }

    // Window frames
    final Paint framePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(mainWindow, framePaint);
    canvas.drawLine(mainWindow.centerLeft, mainWindow.centerRight, framePaint);
    canvas.drawLine(mainWindow.topCenter, mainWindow.bottomCenter, framePaint);

    // 4. SNOW ON ROOFS
    final Paint snowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawPath(
        mainRoof,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);

    // Snow caps
    final Path snowCap = Path();
    snowCap.moveTo(-scale * 0.6, -scale * 0.5);
    snowCap.lineTo(0, -scale * 0.9);
    snowCap.lineTo(scale * 0.1, -scale * 0.84);
    snowCap.lineTo(scale * 0.6, -scale * 0.5);
    snowCap.lineTo(scale * 0.4, -scale * 0.45);
    snowCap.lineTo(0, -scale * 0.82);
    snowCap.lineTo(-scale * 0.4, -scale * 0.45);
    snowCap.close();
    canvas.drawPath(snowCap, snowPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LodgePainter oldDelegate) => true;
}
