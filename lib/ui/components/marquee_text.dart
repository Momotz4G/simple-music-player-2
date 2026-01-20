import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double velocity; // Pixels per second
  final double blankSpace; // DEPRECATED: Not used in current logic
  final Duration startPause;
  final Duration endPause;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.velocity = 30.0,
    this.blankSpace = 40.0,
    this.startPause = const Duration(seconds: 5),
    this.endPause = const Duration(seconds: 2),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late ScrollController _scrollController;
  late TextPainter _textPainter;
  double _textWidth = 0.0;
  double _containerWidth = 0.0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _isAnimating = false;
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startAnimationLoop() async {
    if (_isAnimating || !mounted) return;
    _isAnimating = true;

    try {
      while (mounted) {
        // 1. Reset to start
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }

        // 2. Wait at start
        await Future.delayed(widget.startPause);
        if (!mounted) break;

        // Verify we still need to scroll
        if (!_scrollController.hasClients) break;
        final maxScroll = _scrollController.position.maxScrollExtent;

        // If text fits or is barely larger (jitter protection), stop
        if (maxScroll <= 0.5) {
          _isAnimating = false;
          break;
        }

        // 3. Walk to the end
        final duration = Duration(
            milliseconds: (maxScroll / widget.velocity * 1000).round());

        if (_scrollController.hasClients) {
          await _scrollController.animateTo(
            maxScroll,
            duration: duration,
            curve: Curves.linear,
          );
        }
        if (!mounted) break;

        // 4. Wait at end
        await Future.delayed(widget.endPause);
      }
    } catch (e) {
      debugPrint("Marquee error: $e");
    } finally {
      if (mounted) _isAnimating = false;
    }
  }

  void _measureText() {
    _textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    _textWidth = _textPainter.width;
  }

  void _checkAnimation() {
    if (!mounted) return;
    if (_textWidth > _containerWidth) {
      // Only start if not already running
      if (!_isAnimating) _startAnimationLoop();
    } else {
      _isAnimating = false;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text || widget.style != oldWidget.style) {
      // If content changes, the loop might be running with old params
      // or standard build pipeline will handle it.
      // Ideally we cancel the current loop, but we can't easily cancel a future.
      // However, the loop checks "mounted".
      // We rely on build() calling _measureText/checkAnimation to re-trigger if needed.
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_containerWidth != constraints.maxWidth) {
          _containerWidth = constraints.maxWidth;
          _measureText();
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _checkAnimation());
        }

        // If text fits, just return Text
        if (_textWidth <= _containerWidth && _textWidth > 0) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        // Marquee view
        // Removed Padding: Stops exactly at end of text.
        return SizedBox(
          height: _textPainter.height,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(widget.text, style: widget.style),
          ),
        );
      },
    );
  }
}
