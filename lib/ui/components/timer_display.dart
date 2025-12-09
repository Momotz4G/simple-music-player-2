import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/timer_provider.dart';

class TimerDisplay extends ConsumerWidget {
  const TimerDisplay({super.key});

  String _formatTimer(Duration d) {
    if (d.inHours > 0) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final s = d.inSeconds % 60;
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the timer state (this will cause this small widget to rebuild every second)
    final timerState = ref.watch(timerProvider);
    final accentColor = Theme.of(context).colorScheme.primary;

    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;

    if (!timerState.isActive) {
      return Text("Sleep Timer", style: TextStyle(color: textColor));
    }

    // Active State Display
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The icon is handled by the parent PopupMenuItem, so we just handle the text/spacing
        // const SizedBox(width: 12), // Optional: Removed to prevent double spacing in menu
        Text(
          "Stop Timer (${_formatTimer(timerState.remaining)})",
          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
