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
  final bool isKaraokeMode;
  final bool isActive;

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
    this.isKaraokeMode = false,
    this.isActive = true,
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
    if (widget.isPlaying && widget.isActive) {
      _ticker?.start();
    }
  }

  @override
  void didUpdateWidget(SmoothHighlightText oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !oldWidget.isActive) {
      _currentSmoothPos = widget.initialPosition;
    } else {
      final bool seeked = (widget.initialPosition - oldWidget.initialPosition).abs() > 0.5;
      if (seeked) {
        _currentSmoothPos = widget.initialPosition;
      } else {
        // Only pull forward to correct drift to prevent backwards jitter
        final double drift = widget.initialPosition - _currentSmoothPos;
        if (drift > 0.0) {
          _currentSmoothPos += drift * 0.1;
        }
      }
    }
    
    if (widget.isPlaying && widget.isActive && !(_ticker?.isActive ?? false)) {
      _ticker?.start();
      _lastTick = Duration.zero;
    } else if ((!widget.isPlaying || !widget.isActive) && (_ticker?.isActive ?? false)) {
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
    
    // Append trailing spaces to words (except the last one) so Wrap with spacing 0.0 looks natural
    for (int i = 0; i < wordTexts.length - 1; i++) {
      if (!wordTexts[i].endsWith(' ')) {
        wordTexts[i] += ' ';
      }
    }
    
    final lineDuration = widget.endTime - widget.startTime;
    
    // Finish highlighting slightly early so the last word is fully lit before the line switches
    final double adjustedLineDuration = widget.words != null 
        ? lineDuration 
        : (lineDuration > 0.5 ? lineDuration - 0.3 : lineDuration);
        
    final fallbackWordDuration = adjustedLineDuration / (wordCount > 0 ? wordCount : 1);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 0.0,
      runSpacing: 0.0,
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
        final isPassed = effectivePos >= wordStart;
        final displayProgress = widget.isKaraokeMode ? (isPassed ? 1.0 : 0.0) : progress;

        Widget textWidget = Text(
          wordTexts[index],
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: widget.fontWeight,
            fontStyle: widget.isItalic ? FontStyle.italic : FontStyle.normal,
            color: widget.isActive 
                ? (widget.isKaraokeMode ? (isPassed ? widget.activeColor : dimColor) : Colors.white)
                : widget.inactiveColor,
            height: 1.4,
            shadows: (!widget.isItalic && widget.isActive)
                ? [
                    Shadow(
                      color: widget.activeColor.withValues(alpha: 0.4 * displayProgress),
                      blurRadius: 15 * displayProgress,
                    )
                  ]
                : [],
          ),
        );

        if (widget.isKaraokeMode) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            transform: Matrix4.translationValues(0, (widget.isActive && isPassed) ? -10.0 : 0.0, 0),
            child: textWidget,
          );
        } else {
          if (!widget.isActive) {
            return textWidget;
          }
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              final double c = progress * 1.4 - 0.2;
              return LinearGradient(
                colors: [widget.activeColor, dimColor],
                stops: [
                  (c - 0.2).clamp(0.0, 1.0),
                  (c + 0.2).clamp(0.0, 1.0)
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds);
            },
            child: textWidget,
          );
        }
      }),
    );
  }
}
