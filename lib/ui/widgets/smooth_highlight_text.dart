import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../providers/lyrics_provider.dart';

class SmoothHighlightText extends StatefulWidget {
  final String text;
  final double startTime;
  final double endTime;
  final double initialPosition;
  final bool isPlaying;
  final double syncOffset;
  final Color activeColor;
  final Color inactiveColor;
  final double fontSize;
  final FontWeight fontWeight;
  final bool isItalic;
  final double spacing;
  final List<LyricWord>? words;

  const SmoothHighlightText({
    super.key,
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.initialPosition,
    required this.isPlaying,
    required this.syncOffset,
    required this.activeColor,
    required this.inactiveColor,
    this.fontSize = 32,
    this.fontWeight = FontWeight.w900,
    this.isItalic = false,
    this.spacing = 8.0,
    this.words,
  });

  @override
  State<SmoothHighlightText> createState() => _SmoothHighlightTextState();
}

class _SmoothHighlightTextState extends State<SmoothHighlightText> with SingleTickerProviderStateMixin {
  late double _currentSmoothPos;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _currentSmoothPos = widget.initialPosition;
    _ticker = createTicker(_onTick);
    if (widget.isPlaying) {
      _ticker?.start();
    }
  }

  @override
  void didUpdateWidget(SmoothHighlightText oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Sync if drift is too large or seek happened
    if ((widget.initialPosition - _currentSmoothPos).abs() > 0.5) {
      _currentSmoothPos = widget.initialPosition;
    }
    
    if (widget.isPlaying && !(_ticker?.isActive ?? false)) {
      _ticker?.start();
      _lastTick = Duration.zero;
    } else if (!widget.isPlaying && (_ticker?.isActive ?? false)) {
      _ticker?.stop();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTick != Duration.zero) {
      final delta = (elapsed - _lastTick).inMicroseconds / 1000000.0;
      if (mounted) {
        setState(() {
          _currentSmoothPos += delta;
        });
      }
    }
    _lastTick = elapsed;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty && (widget.words == null || widget.words!.isEmpty)) return const SizedBox.shrink();
    
    // Smooth position calculation
    final effectivePos = _currentSmoothPos - widget.syncOffset + 0.5;

    // Word configuration
    final int wordCount = widget.words?.length ?? widget.text.split(' ').length;
    final List<String> wordTexts = widget.words?.map((w) => w.text).toList() ?? widget.text.split(' ');
    
    final lineDuration = widget.endTime - widget.startTime;
    final fallbackWordDuration = lineDuration / (wordCount > 0 ? wordCount : 1);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: widget.spacing,
      runSpacing: widget.spacing / 2,
      children: List.generate(wordCount, (index) {
        // Use explicit word timings if available, else fallback
        final wordStart = widget.words != null 
            ? widget.words![index].startTime 
            : widget.startTime + index * fallbackWordDuration;
            
        final wordEnd = widget.words != null 
            ? widget.words![index].endTime 
            : wordStart + fallbackWordDuration;
            
        final wordDuration = wordEnd - wordStart;

        double progress = 0.0;
        if (effectivePos >= wordEnd) {
          progress = 1.0;
        } else if (effectivePos >= wordStart && wordDuration > 0) {
          progress = ((effectivePos - wordStart) / wordDuration).clamp(0.0, 1.0);
        }

        final dimColor = widget.inactiveColor.withValues(alpha: widget.isItalic ? 0.3 : 0.5);

        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [widget.activeColor, dimColor],
              stops: [
                (progress - 0.05).clamp(0.0, 1.0),
                (progress + 0.05).clamp(0.0, 1.0)
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds);
          },
          child: Text(
            wordTexts[index],
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: widget.fontWeight,
              fontStyle: widget.isItalic ? FontStyle.italic : FontStyle.normal,
              color: Colors.white,
              height: 1.4,
              shadows: (progress > 0.05 && !widget.isItalic)
                  ? [
                      BoxShadow(
                        color: widget.activeColor.withValues(alpha: 0.4 * progress),
                        blurRadius: 15 * progress,
                      )
                    ]
                  : [],
            ),
          ),
        );
      }),
    );
  }
}
