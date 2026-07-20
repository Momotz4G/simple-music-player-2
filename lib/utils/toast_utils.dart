import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomToast {
  static OverlayEntry? _overlayEntry;
  static _ToastContainerState? _containerState;

  static void show(BuildContext context, String message, {IconData icon = Icons.info_outline, Duration duration = const Duration(seconds: 15)}) {
    final theme = Theme.of(context);
    
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) => _ToastContainer(
          onInit: (state) {
            _containerState = state;
            _containerState?.addToast(message, icon, duration, theme);
          },
        ),
      );
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _containerState?.addToast(message, icon, duration, theme);
    }
  }
}

class _ToastData {
  final Key key;
  final String message;
  final IconData icon;
  final Duration duration;
  final ThemeData theme;

  _ToastData({required this.key, required this.message, required this.icon, required this.duration, required this.theme});
}

class _ToastContainer extends StatefulWidget {
  final Function(_ToastContainerState) onInit;
  const _ToastContainer({required this.onInit});

  @override
  State<_ToastContainer> createState() => _ToastContainerState();
}

class _ToastContainerState extends State<_ToastContainer> {
  final List<_ToastData> _toasts = [];

  @override
  void initState() {
    super.initState();
    // Schedule the callback for after the build phase finishes initializing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onInit(this);
    });
  }

  void addToast(String message, IconData icon, Duration duration, ThemeData theme) {
    SystemSound.play(SystemSoundType.alert);
    setState(() {
      // Add new toast to the end of the list (bottom of the column)
      _toasts.add(_ToastData(
        key: UniqueKey(),
        message: message,
        icon: icon,
        duration: duration,
        theme: theme,
      ));
    });
  }

  void removeToast(Key key) {
    if (mounted) {
      setState(() {
        _toasts.removeWhere((t) => t.key == key);
      });
      if (_toasts.isEmpty) {
        CustomToast._overlayEntry?.remove();
        CustomToast._overlayEntry = null;
        CustomToast._containerState = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Positioned(
      bottom: 100, // Positioned above the player bar
      // On mobile, we anchor to both sides to center it
      right: isMobile ? 16 : 24,
      left: isMobile ? 16 : null,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.end,
          // Older toasts are pushed UP because new ones are added to the bottom
          children: _toasts.map((t) => Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _ToastWidget(
              key: t.key,
              data: t,
              isMobile: isMobile,
              onDismissed: () => removeToast(t.key),
            ),
          )).toList(),
        ),
      ),
    );
  }
}

class _ToastWidget extends StatefulWidget {
  final _ToastData data;
  final bool isMobile;
  final VoidCallback onDismissed;

  const _ToastWidget({super.key, required this.data, required this.isMobile, required this.onDismissed});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: widget.isMobile ? const Offset(0.0, 0.5) : const Offset(1.0, 0.0), // Slide up on mobile, side on desktop
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Auto dismiss after the specified duration
    Future.delayed(widget.data.duration, () {
      _dismissToast();
    });
  }
  
  void _dismissToast() {
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismissed();
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
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: widget.isMobile ? double.infinity : 340,
          constraints: BoxConstraints(
            maxWidth: widget.isMobile ? double.infinity : 340, // Max width on desktop, fill on mobile
            minHeight: 85, // Makes the bar fundamentally fatter
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // Thicker padding
          decoration: BoxDecoration(
            color: widget.data.theme.brightness == Brightness.dark
                ? Colors.grey.shade900.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(8), // Less rounded, more rectangular
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: widget.data.theme.colorScheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Align to top for multiline
            children: [
              // Icon with its own little background box for more visual weight
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.data.theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.data.icon,
                    color: widget.data.theme.colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded( // Expanded forces the text to take up remaining fixed width and wrap properly
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    widget.data.message,
                    softWrap: true,
                    style: TextStyle(
                      color: widget.data.theme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.4, // Gives wrapped text room to breathe
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Close button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _dismissToast,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: widget.data.theme.brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
