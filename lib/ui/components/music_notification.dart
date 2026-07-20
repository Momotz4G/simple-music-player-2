import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../main.dart';
import 'smart_art.dart';

class MusicNotification extends StatelessWidget {
  final String label;
  final String title;
  final String? subtitle;
  final String? artPath; // Can be a File Path OR a URL now
  final String? onlineArtUrl;
  final Color? backgroundColor;
  final IconData? icon;
  final bool centered;

  const MusicNotification({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
    this.artPath,
    this.onlineArtUrl,
    this.backgroundColor,
    this.icon,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveBgColor = backgroundColor ??
        (isDark
            ? const Color(0xFF141414).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95));

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: centered ? 280 : 320, // Slightly narrower if centered
            padding: EdgeInsets.all(centered ? 24 : 16),
            decoration: BoxDecoration(
              color: effectiveBgColor,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: centered
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. CENTERED ICON
                      if (icon != null)
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: icon == Icons.check_circle_outline ||
                                    icon == Icons.check
                                ? const Color(
                                    0xFF7CB305) // Specific Green from pic
                                : (icon == Icons.error_outline ||
                                        icon == Icons.error
                                    ? Colors.redAccent
                                    : Colors.white.withValues(alpha: 0.15)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              icon == Icons.check_circle_outline
                                  ? Icons.check
                                  : icon,
                              color: Colors.white,
                              size: 36),
                        )
                      else ...[
                        const Icon(Icons.info_outline,
                            color: Colors.white, size: 48),
                      ],
                      const SizedBox(height: 20),

                      // 2. CENTERED TEXT
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. ICON (Priority)
                      if (icon != null)
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(icon, color: Colors.white, size: 28),
                        )
                      // 2. ARTWORK
                      else if (artPath != null && artPath!.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8)
                              ]),
                          child: artPath!.startsWith('http')
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    artPath!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 56,
                                      height: 56,
                                      color: Colors.grey[900],
                                      child: const Icon(Icons.music_note,
                                          color: Colors.white24),
                                    ),
                                  ),
                                )
                              : SmartArt(
                                  path: artPath!,
                                  size: 56,
                                  borderRadius: 8,
                                  onlineArtUrl: onlineArtUrl,
                                ),
                        )
                      else
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.info_outline_rounded,
                              color: Colors.white, size: 28),
                        ),

                      const SizedBox(width: 16),

                      // 2. TEXT STACK
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// NON-BLOCKING OVERLAY HELPER
void showCenterNotification(
  BuildContext context, {
  required String label,
  required String title,
  String? subtitle,
  String? artPath,
  String? onlineArtUrl,
  Color? backgroundColor,
  IconData? icon,
  bool centered = false,
}) {
  if (!context.mounted) return;

  try {
    final overlayState = Overlay.maybeOf(context) ?? globalNavigatorKey.currentState?.overlay;
    if (overlayState == null) {
      debugPrint("⚠️ Notification Error: No Overlay widget found in context or global fallback.");
      return;
    }

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return _NotificationAnimator(
          onDismiss: () {
            if (overlayEntry.mounted) {
              overlayEntry.remove();
            }
          },
          child: Align(
            alignment: Alignment.center,
            child: MusicNotification(
              label: label,
              title: title,
              subtitle: subtitle,
              artPath: artPath,
              onlineArtUrl: onlineArtUrl,
              backgroundColor: backgroundColor,
              icon: icon,
              centered: centered, // Passed down
            ),
          ),
        );
      },
    );

    overlayState.insert(overlayEntry);
  } catch (e) {
    debugPrint("⚠️ Notification Error: $e");
  }
}

// 🎬 INTERNAL ANIMATION HANDLER
class _NotificationAnimator extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const _NotificationAnimator({
    required this.child,
    required this.onDismiss,
  });

  @override
  State<_NotificationAnimator> createState() => _NotificationAnimatorState();
}

class _NotificationAnimatorState extends State<_NotificationAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400), // Intro Speed
      reverseDuration: const Duration(milliseconds: 300), // Outro Speed
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack, // Bouncy intro
      reverseCurve: Curves.easeInBack, // Smooth exit
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();

    _timer = Timer(const Duration(seconds: 3), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
