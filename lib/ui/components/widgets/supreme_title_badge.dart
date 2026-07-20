import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../utils/stats_utils.dart';

class SupremeTitleBadge extends StatefulWidget {
  final String title;
  final int rarityTier;
  final Color primaryColor;
  final Color secondaryColor;
  final double width;
  final double height;
  final bool isLocked;
  final String? tooltip;

  const SupremeTitleBadge({
    super.key,
    required this.title,
    required this.rarityTier,
    required this.primaryColor,
    required this.secondaryColor,
    this.width = 140,
    this.height = 24,
    this.isLocked = false,
    this.tooltip,
  });

  factory SupremeTitleBadge.fromDefinition(TitleDefinition def,
      {String? displayName, bool isLocked = false, double width = 140, double height = 24, String? tooltip}) {
    return SupremeTitleBadge(
      title: (displayName != null && displayName.trim().isNotEmpty) ? displayName : def.name,
      rarityTier: def.rarityTier,
      primaryColor: Color(def.primaryColor),
      secondaryColor: Color(def.secondaryColor),
      isLocked: isLocked,
      width: width,
      height: height,
      tooltip: tooltip,
    );
  }

  @override
  State<SupremeTitleBadge> createState() => _SupremeTitleBadgeState();
}

class _SupremeTitleBadgeState extends State<SupremeTitleBadge>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _shimmerController;
  late AnimationController _orbitController;
  late AnimationController
      _introController; // Added for intro animations like falling text
  late AnimationController _fastPulseController;
  late AnimationController _atomicController;
  late Animation<double> _glowAnimation;
  late Animation<double> _heartbeatAnimation;
  late Animation<double> _atomicGlowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000), // Reverted to 5.0 seconds for elegant orbit
    );
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: 2000), // 2 seconds for all letters to fall
    );
    _fastPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _atomicController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200), // 3.2 seconds (Slown down by 50% as requested)
    );

    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted && !widget.isLocked) {
            _introController.forward(from: 0);
          }
        });
      }
    });

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    final heartbeatSequence = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 0.85)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 0.6)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.6, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.4)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]);

    _heartbeatAnimation = heartbeatSequence.animate(_fastPulseController);
    _atomicGlowAnimation = heartbeatSequence.animate(_atomicController);

    if (widget.rarityTier >= 2 && !widget.isLocked) {
      _glowController.repeat(reverse: true);
    }
    if (widget.rarityTier >= 3 && !widget.isLocked) {
      _shimmerController.repeat();
    }
    if (widget.title == "Contributor" && !widget.isLocked) {
      _orbitController.repeat();
    }
    if (widget.title == "Atomic Rhythm" && !widget.isLocked) {
      _atomicController.repeat();
    }
    if (widget.title == "Unstoppable Pulse" && !widget.isLocked) {
      _fastPulseController.repeat();
    }
    if (!widget.isLocked) {
      _introController.forward();
    }
  }

  @override
  void didUpdateWidget(SupremeTitleBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLocked != oldWidget.isLocked ||
        widget.rarityTier != oldWidget.rarityTier) {
      if (widget.rarityTier >= 2 && !widget.isLocked) {
        if (!_glowController.isAnimating) _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
      }

      if (widget.rarityTier >= 3 && !widget.isLocked) {
        if (!_shimmerController.isAnimating) _shimmerController.repeat();
      } else {
        _shimmerController.stop();
      }

      if (widget.title == "Contributor" && !widget.isLocked) {
        if (!_orbitController.isAnimating) _orbitController.repeat();
      } else {
        _orbitController.stop();
      }

      if (widget.title == "Atomic Rhythm" && !widget.isLocked) {
        if (!_atomicController.isAnimating) _atomicController.repeat();
      } else {
        _atomicController.stop();
      }

      if (widget.title == "Unstoppable Pulse" && !widget.isLocked) {
        if (!_fastPulseController.isAnimating) _fastPulseController.repeat();
      } else {
        _fastPulseController.stop();
      }

      if (!widget.isLocked) {
        _introController.forward();
      } else {
        _introController.reset();
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _shimmerController.dispose();
    _orbitController.dispose();
    _introController.dispose();
    _fastPulseController.dispose();
    _atomicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        Widget badge = Transform.scale(
            scale: (widget.title == "Contributor" && !widget.isLocked)
                ? 1.0 + (_glowAnimation.value * 0.03) // Soft heartbeat 3% scale
                : 1.0,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.height / 2),
                boxShadow: [
                  if (widget.rarityTier >= 2 && !widget.isLocked)
                    BoxShadow(
                      color: widget.primaryColor.withValues(
                          alpha: 0.5 *
                              (widget.title == "Unstoppable Pulse"
                                  ? _heartbeatAnimation.value
                                  : (widget.title == "Atomic Rhythm"
                                      ? _atomicGlowAnimation.value
                                      : _glowAnimation.value))),
                      blurRadius: 10 *
                          (widget.title == "Unstoppable Pulse"
                              ? _heartbeatAnimation.value
                              : (widget.title == "Atomic Rhythm"
                                  ? _atomicGlowAnimation.value
                                  : _glowAnimation.value)),
                      spreadRadius: 2 *
                          (widget.title == "Unstoppable Pulse"
                              ? _heartbeatAnimation.value
                              : (widget.title == "Atomic Rhythm"
                                  ? _atomicGlowAnimation.value
                                  : _glowAnimation.value)),
                    ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 👑 CROWN for TOP 1 (Global Dominance)
                  if (widget.title == "Top 1 Global" && !widget.isLocked)
                    Positioned(
                      top: -widget.height * 0.55, // Adjusted for smaller crown
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Transform.scale(
                          scale: 0.9 + (_glowAnimation.value * 0.2), // Pulse
                          child: CrownWidget(
                            size:
                                widget.height * 0.6, // 40% smaller than 1.0
                            color: Colors.amber,
                            glowValue: _glowAnimation.value,
                          ),
                        ),
                      ),
                    ),

                  // Tier 3 External Wings
                  if (widget.rarityTier >= 3) ...[
                    Positioned(
                      left: -16,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _buildWingsByTier(true)),
                    ),
                    Positioned(
                      right: -16,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _buildWingsByTier(false)),
                    ),
                  ],

                  // 1. BACK Orbiting Hearts (Contributor Exclusive)
                  if (widget.title == "Contributor" && !widget.isLocked) ...[
                    _buildOrbitingParticle(isFront: false, offsetPi: 0.0),
                    _buildOrbitingParticle(isFront: false, offsetPi: math.pi),
                  ],

                  // 1. BACK Orbiting Electrons (Atomic Rhythm Exclusive)
                  if (widget.title == "Atomic Rhythm" && !widget.isLocked) ...[
                    _buildOrbitingParticle(
                        isFront: false, offsetPi: 0.0, isAtomic: true),
                    _buildOrbitingParticle(
                        isFront: false, offsetPi: math.pi * 0.66, isAtomic: true),
                    _buildOrbitingParticle(
                        isFront: false, offsetPi: math.pi * 1.33, isAtomic: true),
                  ],

                  // Main Body
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.height / 2),
                      gradient: LinearGradient(
                        colors: [
                          widget.secondaryColor.withValues(alpha: 0.8),
                          Colors.black.withValues(alpha: 0.9),
                          widget.secondaryColor.withValues(alpha: 0.8),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      border: Border.all(
                        color: widget.primaryColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                  ),

                  // 2. FRONT Orbiting Hearts (Contributor Exclusive)
                  if (widget.title == "Contributor" && !widget.isLocked) ...[
                    _buildOrbitingParticle(isFront: true, offsetPi: 0.0),
                    _buildOrbitingParticle(isFront: true, offsetPi: math.pi),
                  ],

                  // 2. FRONT Orbiting Electrons (Atomic Rhythm Exclusive)
                  if (widget.title == "Atomic Rhythm" && !widget.isLocked) ...[
                    _buildOrbitingParticle(
                        isFront: true, offsetPi: 0.0, isAtomic: true),
                    _buildOrbitingParticle(
                        isFront: true, offsetPi: math.pi * 0.66, isAtomic: true),
                    _buildOrbitingParticle(
                        isFront: true, offsetPi: math.pi * 1.33, isAtomic: true),
                  ],

                  // Decorative Caps (Wings)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: _buildCap(true),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: _buildCap(false),
                  ),

                  // Waving Shine (Tier 3)
                  if (widget.rarityTier >= 3 && !widget.isLocked)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.height / 2),
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(
                                      -2.0 + (_shimmerController.value * 4.0),
                                      -1.0),
                                  end: Alignment(
                                      -0.5 + (_shimmerController.value * 4.0),
                                      1.0),
                                  stops: const [0.0, 0.5, 1.0],
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    widget.primaryColor.withValues(alpha: 0.6),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Tier 6: Falling Golden Music Notes
                  if (widget.rarityTier == 6 && !widget.isLocked)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.height / 2),
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, child) {
                            return Stack(
                              children: List.generate(4, (index) {
                                final startPositions = [0.15, 0.35, 0.65, 0.85];
                                final speedOffsets = [0.2, 0.7, 0.4, 0.9];
                                var progress = (_shimmerController.value +
                                        speedOffsets[index]) %
                                    1.0;
                                return Positioned(
                                  left: widget.width * startPositions[index],
                                  top: -widget.height * 0.5 +
                                      (widget.height * 2.5 * progress),
                                  child: Opacity(
                                    opacity: math.sin(progress * math.pi),
                                    child: Transform.rotate(
                                      angle: progress * math.pi / 2,
                                      child: Icon(
                                          index % 2 == 0
                                              ? Icons.music_note
                                              : Icons.audiotrack,
                                          color: Colors.amberAccent
                                              .withValues(alpha: 0.7),
                                          size: widget.height * 0.5),
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                    ),

                  // Title Text
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, child) {
                            final textWidget = Text(
                              widget.title.toUpperCase(),
                              style: TextStyle(
                                color: (widget.rarityTier == 5 &&
                                        !widget.isLocked)
                                    ? Color.lerp(
                                        Colors.white,
                                        const Color(0xFFD500F9),
                                        _glowAnimation.value)
                                    : ((widget.title == "Developer" &&
                                            !widget.isLocked)
                                        ? Colors.white // Developer text color
                                        : Colors.white),
                                fontSize: widget.height * 0.52,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                shadows: [
                                  Shadow(
                                    color: widget.primaryColor
                                        .withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            );

                            if (widget.title == "Developer" &&
                                !widget.isLocked) {
                              return AnimatedBuilder(
                                animation: _introController,
                                builder: (context, child) {
                                  final text = widget.title.toUpperCase();

                                  if (_introController.value == 1.0) {
                                    // Animation finished, render normal row to save performance
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children:
                                          List.generate(text.length, (index) {
                                        final char = text[index];
                                        final letterColor = HSVColor.fromAHSV(
                                                1.0,
                                                (index / text.length) * 360,
                                                0.75,
                                                1.0)
                                            .toColor();
                                        return Text(char,
                                            style: textWidget.style
                                                ?.copyWith(color: letterColor));
                                      }),
                                    );
                                  }

                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children:
                                        List.generate(text.length, (index) {
                                      final char = text[index];
                                      final totalLetters = text.length;

                                      // Stagger the start time of each letter
                                      final start = (index / totalLetters) *
                                          0.6; // Last letter starts at 60% of 2s = 1.2s
                                      final end = start +
                                          0.4; // Each letter takes 40% (0.8s) to fall

                                      // Calculate progress for this specific letter
                                      var letterProgress =
                                          (_introController.value - start) /
                                              (end - start);
                                      letterProgress =
                                          letterProgress.clamp(0.0, 1.0);

                                      // Falling bounce effect
                                      const curve = Curves.bounceOut;
                                      final curvedValue =
                                          curve.transform(letterProgress);

                                      // Start high up and invisible, fall to 0
                                      final yOffset = -widget.height *
                                          1.5 *
                                          (1.0 - curvedValue);
                                      final opacity =
                                          letterProgress.clamp(0.0, 1.0);

                                      // Unique neon color for each letter
                                      final letterColor = HSVColor.fromAHSV(
                                              1.0,
                                              (index / totalLetters) * 360,
                                              0.75,
                                              1.0)
                                          .toColor();

                                      return Transform.translate(
                                        offset: Offset(0, yOffset),
                                        child: Opacity(
                                          opacity: opacity == 0.0
                                              ? 0.0
                                              : 1.0, // hide before start
                                          child: Text(char,
                                              style: textWidget.style?.copyWith(
                                                  color: letterColor)),
                                        ),
                                      );
                                    }),
                                  );
                                },
                              );
                            }

                            if ((widget.title == "Top 1 Global" || widget.title == "Top 2 Global" || widget.title == "Top 3 Global") &&
                                !widget.isLocked) {
                              final List<Color> shimmerColors = widget.title == "Top 1 Global" 
                                ? const [Colors.white, Color(0xFFFF00D4), Color(0xFFFF8AD2), Colors.white]
                                : (widget.title == "Top 2 Global"
                                    ? const [Colors.white, Color(0xFF00B0FF), Color(0xFFCACACA), Colors.white] // Deeper Blue/Silver for Platinum
                                    : const [Colors.white, Color(0xFFFFAB40), Color(0xFFA1887F), Colors.white]); // Darker Bronze/Orange

                              return ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: shimmerColors,
                                    stops: const [0.0, 0.4, 0.6, 1.0],
                                    transform: GradientTranslation(
                                        _shimmerController.value * 2.0 - 1.0),
                                  ).createShader(bounds);
                                },
                                child: textWidget,
                              );
                            }

                            if (widget.title == "Contributor" &&
                                !widget.isLocked) {
                              return ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white,
                                      widget.secondaryColor, // Silver
                                      widget.primaryColor, // Radiant Pink
                                      Colors.white,
                                    ],
                                    stops: const [0.0, 0.45, 0.55, 1.0],
                                    transform: GradientTranslation(1.5 -
                                        (_shimmerController.value *
                                            3.0)), // Sweeping glass effect
                                  ).createShader(bounds);
                                },
                                child: textWidget,
                              );
                            }

                            if (widget.title == "Atomic Rhythm" &&
                                !widget.isLocked) {
                              return ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) {
                                  // Atomic Flicker: High-speed chaotic shifts
                                  final flicker =
                                      (math.sin(_atomicController.value *
                                                  math.pi *
                                                  10) *
                                              0.1) +
                                          0.9;
                                  return LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      widget.primaryColor,
                                      Colors.white.withValues(alpha: flicker),
                                      widget.primaryColor,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                    transform: GradientTranslation(
                                        math.sin(_atomicController.value *
                                            math.pi)),
                                  ).createShader(bounds);
                                },
                                child: textWidget,
                              );
                            }
                            return textWidget;
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ));

        if (widget.isLocked) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.35,
                child: badge,
              ),
              Container(
                padding: EdgeInsets.all(widget.height * 0.1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: widget.height * 0.45,
                ),
              ),
            ],
          );
        }

        if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
          return Tooltip(
            message: widget.tooltip!,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.primaryColor.withValues(alpha: 0.5), width: 1),
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            preferBelow: false,
            child: badge,
          );
        }

        return badge;
      },
    );
  }

  Widget _buildCap(bool isLeft) {
    final double capWidth = widget.width * 0.15;
    return Container(
      width: capWidth,
      decoration: BoxDecoration(
        color: widget.primaryColor,
        borderRadius: BorderRadius.only(
          topLeft: isLeft ? Radius.circular(widget.height / 2) : Radius.zero,
          bottomLeft: isLeft ? Radius.circular(widget.height / 2) : Radius.zero,
          topRight: !isLeft ? Radius.circular(widget.height / 2) : Radius.zero,
          bottomRight:
              !isLeft ? Radius.circular(widget.height / 2) : Radius.zero,
        ),
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            widget.primaryColor,
            widget.primaryColor.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildWingsByTier(bool isLeft) {
    switch (widget.rarityTier) {
      case 3:
        return _buildTier3Wing(isLeft);
      case 4:
        return _buildTier4Wing(isLeft);
      case 5:
        return _buildTier5Wing(isLeft);
      case 6:
      default:
        return _buildTier6Wing(isLeft);
    }
  }

  // Tier 3: Legendary (Diamonds & Lines)
  Widget _buildTier3Wing(bool isLeft) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isLeft)
          Container(
            width: 2,
            height: widget.height * 0.7,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.8),
              boxShadow: [BoxShadow(color: widget.primaryColor, blurRadius: 4)],
            ),
          ),
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: widget.height * 0.35,
            height: widget.height * 0.35,
            decoration: BoxDecoration(
              border: Border.all(color: widget.primaryColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: widget.primaryColor
                      .withValues(alpha: 0.5 * _glowAnimation.value),
                  blurRadius: 6 * _glowAnimation.value,
                )
              ],
            ),
          ),
        ),
        if (!isLeft)
          Container(
            width: 2,
            height: widget.height * 0.7,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.8),
              boxShadow: [BoxShadow(color: widget.primaryColor, blurRadius: 4)],
            ),
          ),
      ],
    );
  }

  // Tier 4: Resonant Soul (Glowing Crystal Core)
  Widget _buildTier4Wing(bool isLeft) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.height * 0.45,
            height: widget.height * 0.45,
            decoration: BoxDecoration(
                color: widget.primaryColor.withValues(alpha: 0.2),
                border: Border.all(color: widget.primaryColor, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: widget.primaryColor,
                      blurRadius: 10 * _glowAnimation.value)
                ]),
          ),
          Container(
            width: widget.height * 0.25,
            height: widget.height * 0.25,
            decoration: BoxDecoration(
              color: widget.secondaryColor.withValues(alpha: 0.9),
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        ],
      ),
    );
  }

  // Tier 5: Adaptive (Holographic Pulse for Contributor, Eternal Echo for others)
  Widget _buildTier5Wing(bool isLeft) {
    if (widget.title == "Contributor") {
      return Transform.rotate(
        angle: isLeft ? -math.pi / 12 : math.pi / 12,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.favorite_rounded,
                color: widget.secondaryColor.withValues(alpha: 0.8), // Silver
                size: widget.height * 0.7 +
                    (widget.height * 0.1 * _glowAnimation.value),
                shadows: [
                  Shadow(
                      color: widget.primaryColor,
                      blurRadius: 12 * _glowAnimation.value)
                ]),
            Icon(
              Icons.favorite_rounded,
              color: widget.primaryColor, // Radiant Pink
              size: widget.height * 0.45 +
                  (widget.height * 0.1 * _glowAnimation.value),
            ),
          ],
        ),
      );
    }
    
    // Original Tier 5 Cascading Chevrons Fallback
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLeft) ...[
          Icon(
            Icons.arrow_back_ios_rounded, 
            color: const Color(0xFFD500F9), // Purple
            size: widget.height * 0.5, 
            shadows: [Shadow(color: widget.secondaryColor, blurRadius: 6 * _glowAnimation.value)]
          ),
          Icon(
            Icons.arrow_back_ios_rounded, 
            color: widget.secondaryColor, // Cyan
            size: widget.height * 0.8, 
            shadows: [Shadow(color: widget.secondaryColor, blurRadius: 10 * _glowAnimation.value)]
          ),
        ] else ...[
          Icon(
            Icons.arrow_forward_ios_rounded, 
            color: widget.secondaryColor, // Cyan
            size: widget.height * 0.8, 
            shadows: [Shadow(color: widget.secondaryColor, blurRadius: 10 * _glowAnimation.value)]
          ),
          Icon(
            Icons.arrow_forward_ios_rounded, 
            color: const Color(0xFFD500F9), // Purple
            size: widget.height * 0.5, 
            shadows: [Shadow(color: widget.secondaryColor, blurRadius: 6 * _glowAnimation.value)]
          ),
        ],
      ],
    );
  }

  // Tier 6: Melody Archon (Golden Crown/Celestial Stars)
  Widget _buildTier6Wing(bool isLeft) {
    return Transform.rotate(
      angle: isLeft ? -math.pi / 2 : math.pi / 2, // Rotated to point outwards
      child: Icon(
        Icons.auto_awesome,
        color: widget.primaryColor,
        size: widget.height * 0.8,
        shadows: [
          Shadow(
              color: widget.primaryColor,
              blurRadius: 15 * _glowAnimation.value),
          const Shadow(color: Colors.white, blurRadius: 5),
        ],
      ),
    );
  }

  // 3D Orbiting Heart/Atomic Particles
  Widget _buildOrbitingParticle(
      {required bool isFront, required double offsetPi, bool isAtomic = false}) {
    return AnimatedBuilder(
      animation: isAtomic ? _atomicController : _orbitController,
      builder: (context, child) {
        final controller = isAtomic ? _atomicController : _orbitController;
        // Orbit angle. Atomic is much faster and follows a tighter path
        final t = (controller.value * 2 * math.pi) + offsetPi;

        // When sin(t) is positive, it's in the bottom/front half. When negative, top/back half.
        // We orbit around X (left-right) and Y (up-down)
        final isCurrentlyFront = math.sin(t) >= 0;

        // Only render the particle in its responsible Z-layer (Front vs Back)
        if (isFront != isCurrentlyFront) return const SizedBox.shrink();

        // Ellipse radii. Atomic is tighter and more chaotic
        final rx = isAtomic ? (widget.width / 2 + 8) : (widget.width / 2 + 12);
        final ry = isAtomic ? (widget.height / 2 + 4) : (widget.height / 2 + 6);

        final x = math.cos(t) * rx;
        final y = math.sin(t) * ry;

        // Scale simulates 3D depth
        final scale = 1.0 + (math.sin(t) * (isAtomic ? 0.3 : 0.4));

        IconData iconData;
        if (isAtomic) {
          if (offsetPi == 0.0) {
            iconData = Icons.brightness_7;
          } else if (offsetPi < math.pi) {
            iconData = Icons.bolt;
          } else {
            iconData = Icons.blur_on;
          }
        } else {
          iconData = Icons.favorite_rounded;
        }

        return Positioned(
          left: widget.width / 2 + x - (widget.height * 0.3),
          top: widget.height / 2 + y - (widget.height * 0.3),
          child: Transform.scale(
            scale: scale,
            child: Icon(
              iconData,
              color: isAtomic
                  ? Color.lerp(
                      Colors.white,
                      widget.primaryColor,
                      (math.sin(t * 2) + 1) /
                          2) // Metallic flash for atomic
                  : Color.lerp(widget.secondaryColor, widget.primaryColor,
                      (math.sin(t) + 1) / 2),
              size: widget.height * (isAtomic ? 0.5 : 0.6),
              shadows: [
                Shadow(
                    color: widget.primaryColor.withValues(alpha: 0.8),
                    blurRadius: 8 * scale)
              ],
            ),
          ),
        );
      },
    );
  }
}

class CrownWidget extends StatelessWidget {
  final double size;
  final Color color;
  final double glowValue;

  const CrownWidget(
      {super.key, required this.size, required this.color, this.glowValue = 0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.8),
      painter: CrownPainter(color: color, glowValue: glowValue),
    );
  }
}

class CrownPainter extends CustomPainter {
  final Color color;
  final double glowValue;

  CrownPainter({required this.color, this.glowValue = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color,
          color.withValues(alpha: 0.7),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    // Start bottom left (slightly above bottom to leave room for shadow)
    path.moveTo(size.width * 0.1, size.height * 0.9);
    // Base line
    path.lineTo(size.width * 0.9, size.height * 0.9);
    // Right upward point
    path.lineTo(size.width * 1.0, size.height * 0.3);
    // Right valley
    path.lineTo(size.width * 0.7, size.height * 0.6);
    // Center peak
    path.lineTo(size.width * 0.5, size.height * 0.1);
    // Left valley
    path.lineTo(size.width * 0.3, size.height * 0.6);
    // Left upward point
    path.lineTo(0, size.height * 0.3);
    path.close();

    // Shadow/Glow
    canvas.drawShadow(path.shift(const Offset(0, 1)),
        color.withValues(alpha: 0.5), 10 * glowValue, true);

    canvas.drawPath(path, paint);

    // Jewel at center peak
    final jewelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8 + (0.2 * glowValue))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.15),
        size.width * 0.08, jewelPaint);
  }

  @override
  bool shouldRepaint(covariant CrownPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.glowValue != glowValue;
}

class GradientTranslation extends GradientTransform {
  final double offset;
  const GradientTranslation(this.offset);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * offset, 0, 0);
  }
}
