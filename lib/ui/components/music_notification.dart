import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'smart_art.dart';

class MusicNotification extends StatelessWidget {
  final String label;
  final String title;
  final String? subtitle;
  final String? artPath; // Can be a File Path OR a URL now
  final String? onlineArtUrl;
  final Color? backgroundColor;
  final IconData? icon;

  const MusicNotification({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
    this.artPath,
    this.onlineArtUrl,
    this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Default Glass or Custom Glass (e.g. Red)
    final effectiveBgColor = backgroundColor ??
        (isDark
            ? const Color(0xFF0F0F0F).withOpacity(0.95)
            : Colors.white.withOpacity(0.95));

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: effectiveBgColor,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. ICON (Priority)
                if (icon != null)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
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
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8)
                        ]),
                    // 🚀 FIX: Check if it is a Network URL or Local File
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
                // 3. DEFAULT ICON
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
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
                      // Label
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Title
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Subtitle
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
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
}) {
  final overlayState = Overlay.of(context);
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
          ),
        ),
      );
    },
  );

  overlayState.insert(overlayEntry);
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
