import 'dart:math';
import 'package:flutter/material.dart';

class DigitalGlitchWidget extends StatefulWidget {
  const DigitalGlitchWidget({super.key});

  @override
  State<DigitalGlitchWidget> createState() => _DigitalGlitchWidgetState();
}

class _DigitalGlitchWidgetState extends State<DigitalGlitchWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_GlitchStream> _streams = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 50))
      ..addListener(_update)
      ..repeat();
  }

  void _update() {
    if (_random.nextDouble() < 0.2 && _streams.length < 15) {
      _streams.add(_GlitchStream(
        x: _random.nextDouble(),
        speed: 0.01 + _random.nextDouble() * 0.03,
      ));
    }

    for (int i = _streams.length - 1; i >= 0; i--) {
      _streams[i].update();
      if (_streams[i].isDead) {
        _streams.removeAt(i);
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
    return CustomPaint(
      painter: _GlitchPainter(streams: _streams),
      child: const SizedBox.expand(),
    );
  }
}

class _GlitchStream {
  double x;
  double y = -0.2;
  double speed;
  bool isDead = false;
  final List<String> characters = [];
  final Random _random = Random();

  _GlitchStream({required this.x, required this.speed}) {
    for (int i = 0; i < 10; i++) {
      characters.add(_random.nextBool() ? '0' : '1');
    }
  }

  void update() {
    y += speed;
    if (y > 1.2) isDead = true;

    // Occasionally mutate characters
    if (_random.nextDouble() < 0.1) {
      characters[_random.nextInt(characters.length)] =
          _random.nextBool() ? '0' : '1';
    }
  }
}

class _GlitchPainter extends CustomPainter {
  final List<_GlitchStream> streams;
  _GlitchPainter({required this.streams});

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: const Color(0xFF00FFFF).withOpacity(0.4), // Cyan Glow
      fontSize: 10,
      fontFamily: 'monospace',
      fontWeight: FontWeight.bold,
    );

    for (final s in streams) {
      final double sx = s.x * size.width;
      for (int i = 0; i < s.characters.length; i++) {
        final double sy = (s.y * size.height) - (i * 12);
        if (sy < 0 || sy > size.height) continue;

        final tp = TextPainter(
          text: TextSpan(
              text: s.characters[i],
              style: textStyle.copyWith(
                color: textStyle.color!
                    .withOpacity((1 - (i / s.characters.length)) * 0.4),
              )),
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(canvas, Offset(sx, sy));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter oldDelegate) => true;
}
