import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';

class AmbientBackground extends ConsumerWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final settings = ref.watch(settingsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Default background colors
    final Color baseColor = isDark
        ? const Color(0xFF121212)
        : const Color.fromARGB(255, 244, 244, 244);

    final bool isEnabled = settings.syncThemeWithAlbumArt;

    Color targetColor = baseColor;

    // If enabled AND we have a color, blend it onto the base
    if (isEnabled &&
        playerState.currentSong != null &&
        playerState.dominantColor != null) {
      // Blend the accent color with the base color (8% opacity)
      // This creates the "Tint" effect without losing the dark/light theme feel
      targetColor = baseColor.mix(playerState.dominantColor!, 0.5);
    }

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 1000), // Smooth fade
      curve: Curves.easeInOut,
      tween: ColorTween(begin: baseColor, end: targetColor),
      builder: (context, color, child) {
        return Container(
          color: color ?? baseColor,
        );
      },
    );
  }
}

// Extension to mix colors easily
extension ColorMixer on Color {
  Color mix(Color other, double amount) {
    return Color.alphaBlend(other.withOpacity(amount), this);
  }
}
