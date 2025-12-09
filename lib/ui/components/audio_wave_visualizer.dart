import 'dart:math';
import 'package:flutter/material.dart';
import '../../providers/settings_provider.dart';

class AudioWaveVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final int barCount;
  final bool isRainbow;
  final VisualizerStyle style;

  const AudioWaveVisualizer({
    super.key,
    required this.isPlaying,
    required this.color,
    this.barCount = 30,
    this.isRainbow = false,
    this.style = VisualizerStyle.spectrum,
  });

  @override
  State<AudioWaveVisualizer> createState() => _AudioWaveVisualizerState();
}

class _AudioWaveVisualizerState extends State<AudioWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _barHeights;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Initialize bars
    _barHeights = List.generate(widget.barCount, (_) => _random.nextDouble());

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..addListener(() {
        if (widget.isPlaying) {
          setState(() {
            // Update random data for simulation
            for (int i = 0; i < widget.barCount; i++) {
              double target = _random.nextDouble();
              _barHeights[i] =
                  (_barHeights[i] + (target - _barHeights[i]) * 0.2);
            }
          });
        }
      });

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AudioWaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      // Reset to flat when paused
      setState(() {
        _barHeights = List.filled(widget.barCount, 0.05);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // SWITCH PAINTER BASED ON STYLE
    CustomPainter painter;

    switch (widget.style) {
      case VisualizerStyle.wave:
        painter = _SiriWavePainter(
            animationValue:
                _controller.value, // Use controller for smooth sine offset
            color: widget.color,
            isRainbow: widget.isRainbow);
        break;
      case VisualizerStyle.pulse:
        painter = _CircularPulsePainter(
            animationValue:
                _controller.value, // Use controller for expanding rings
            color: widget.color,
            isRainbow: widget.isRainbow);
        break;
      case VisualizerStyle.spectrum:
      default:
        painter = _SpectrumPainter(
            barHeights: _barHeights,
            color: widget.color,
            isRainbow: widget.isRainbow);
        break;
    }

    return CustomPaint(
      painter: painter,
      child: Container(),
    );
  }
}

// STYLE 1: SPECTRUM (Original Bars)
class _SpectrumPainter extends CustomPainter {
  final List<double> barHeights;
  final Color color;
  final bool isRainbow;

  _SpectrumPainter({
    required this.barHeights,
    required this.color,
    required this.isRainbow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final barWidth = size.width / barHeights.length;
    final gap = barWidth * 0.3;
    final drawWidth = barWidth - gap;

    for (int i = 0; i < barHeights.length; i++) {
      final height = barHeights[i] * size.height;
      final top = (size.height - height) / 2;
      final left = i * barWidth + (gap / 2);

      if (isRainbow) {
        final double hue = (i / barHeights.length) * 360;
        paint.color = HSVColor.fromAHSV(1.0, hue, 0.7, 1.0).toColor();
      } else {
        paint.color = color;
      }

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, drawWidth, height),
        const Radius.circular(4),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) => true;
}

// STYLE 2: SIRI WAVE (Smooth Sine Line)
class _SiriWavePainter extends CustomPainter {
  final double animationValue; // 0.0 to 1.0
  final Color color;
  final bool isRainbow;

  _SiriWavePainter({
    required this.animationValue,
    required this.color,
    required this.isRainbow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    if (!isRainbow) paint.color = color;

    final path = Path();
    final centerY = size.height / 2;

    path.moveTo(0, centerY);

    // Draw Sine Wave
    for (double x = 0; x <= size.width; x++) {
      // Math: y = A * sin(kx - wt)
      // Adjust frequency (0.05) and speed (animationValue)
      final y = centerY +
          (size.height * 0.4) * sin((x * 0.03) + (animationValue * 2 * pi));
      path.lineTo(x, y);
    }

    if (isRainbow) {
      // Gradient Shader for Rainbow Line
      paint.shader = const LinearGradient(
        colors: [Colors.red, Colors.green, Colors.blue],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    canvas.drawPath(path, paint);

    // Draw a second "Ghost" wave for effect
    final ghostPath = Path();
    ghostPath.moveTo(0, centerY);
    for (double x = 0; x <= size.width; x++) {
      final y = centerY +
          (size.height * 0.3) *
              sin((x * 0.04) + (animationValue * 2 * pi) + 1.5);
      ghostPath.lineTo(x, y);
    }
    paint.strokeWidth = 1.5;
    if (!isRainbow) paint.color = color.withOpacity(0.5);
    canvas.drawPath(ghostPath, paint);
  }

  @override
  bool shouldRepaint(covariant _SiriWavePainter oldDelegate) => true;
}

// STYLE 3: CIRCULAR PULSE (Centered Ripples)
class _CircularPulsePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final bool isRainbow;

  _CircularPulsePainter({
    required this.animationValue,
    required this.color,
    required this.isRainbow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);

    // Create 3 expanding rings based on animation loops
    for (int i = 0; i < 3; i++) {
      // Stagger the rings: (value + offset) % 1.0
      double progress = (animationValue + (i * 0.33)) % 1.0;

      // Radius grows from 0 to max height
      double radius = (size.height / 1.2) * progress;

      // Opacity fades out as it grows (1.0 -> 0.0)
      double opacity = 1.0 - progress;

      paint.strokeWidth = 2 + (4 * (1 - progress)); // Thicker at center

      if (isRainbow) {
        // Change color based on ring index
        paint.color = HSVColor.fromAHSV(opacity, (i * 120).toDouble(), 0.7, 1.0)
            .toColor();
      } else {
        paint.color = color.withOpacity(opacity);
      }

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularPulsePainter oldDelegate) => true;
}
