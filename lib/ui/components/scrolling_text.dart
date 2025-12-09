import 'package:flutter/material.dart';

class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double width;

  const ScrollingText({
    super.key,
    required this.text,
    required this.width, // We need to know how wide the space is
    this.style,
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Set the scroll speed duration based on length
  Duration _getScrollDuration() {
    // Estimate 50ms per character for better UX
    return Duration(milliseconds: 50 * widget.text.length.clamp(20, 100));
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: _getScrollDuration(),
    );

    // Wait for widget to build to measure text size
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  void _checkScroll() {
    if (!mounted) return;

    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      final double scrollDistance = _scrollController.position.maxScrollExtent;

      // Calculate raw duration based on distance (ms per pixel)
      final int rawDurationMs = (scrollDistance * 30).toInt();

      // CRITICAL FIX: Clamp the numeric value (ms) before creating the Duration
      final int clampedDurationMs = rawDurationMs.clamp(
        const Duration(seconds: 5).inMilliseconds,
        const Duration(seconds: 15).inMilliseconds,
      );

      // Recreate the AnimationController with the SAFE, clamped duration
      _animationController.duration = Duration(milliseconds: clampedDurationMs);

      // Setup the animation path
      _animation = Tween<double>(
        begin: 0.0,
        end: scrollDistance,
      ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.linear),
      );

      _animation.addListener(() {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_animation.value);
        }
      });

      _startLoop();
    } else {
      // If content fits, ensure animation is stopped
      _animationController.reset();
    }
  }

  void _startLoop() async {
    while (mounted) {
      if (!_scrollController.hasClients ||
          _scrollController.position.maxScrollExtent <= 0) break;

      // 1. Scroll to End
      _animationController.forward(from: 0.0);

      // Wait for scroll to complete
      await Future.delayed(_animationController.duration!);

      // 2. Pause at End
      await Future.delayed(const Duration(seconds: 2));

      // 3. Scroll Back to Start
      if (!mounted) break;
      await _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );

      // 4. Pause at Start
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart scroll if the text content has changed
    if (widget.text != oldWidget.text) {
      _animationController.reset();
      // Ensure state is clean before remeasuring on next frame
      _scrollController.jumpTo(0.0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics:
            const NeverScrollableScrollPhysics(), // Disable manual scrolling
        child: Text(widget.text, style: widget.style, maxLines: 1),
      ),
    );
  }
}
