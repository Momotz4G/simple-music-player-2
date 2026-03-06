import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';

class HeatDistortionWidget extends StatefulWidget {
  const HeatDistortionWidget({super.key});

  @override
  State<HeatDistortionWidget> createState() => _HeatDistortionWidgetState();
}

class _HeatDistortionWidgetState extends State<HeatDistortionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Vary the blur slightly to create a shimmering/wobbling heat effect
        final double blurAmount = 1.0 + sin(_controller.value * pi) * 1.5;

        return BackdropFilter(
          // Vertical blur creates that "rising heat" look
          filter: ImageFilter.blur(sigmaX: 0.2, sigmaY: blurAmount),
          child: Container(
            color: Colors.transparent, // Required to apply the filter
          ),
        );
      },
    );
  }
}
