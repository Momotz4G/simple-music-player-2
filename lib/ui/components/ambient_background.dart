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
    Color baseColor;
    if (settings.atmosphereTheme == AtmosphereTheme.autumn) {
      // Deep Autumn Sunset Brown for the autumn theme
      baseColor = const Color(0xFF2D1B0D); // Even darker for ambient feel
    } else if (settings.atmosphereTheme == AtmosphereTheme.winter) {
      // Deep starry night sky color for the winter theme
      baseColor = const Color(0xFF0F172A);
    } else if (settings.atmosphereTheme == AtmosphereTheme.rainyCity) {
      // Deep lofi violet/indigo for the rainy city theme
      baseColor = const Color(0xFF1A1A2E);
    } else if (settings.atmosphereTheme == AtmosphereTheme.sakura) {
      // Soft Sakura Lavender/Pink
      baseColor = const Color(0xFF2D1B2D); // Deep dark purple with pink tint
    } else if (settings.atmosphereTheme == AtmosphereTheme.lunarNewYear) {
      // Deep Festive Red for Lunar New Year
      baseColor = const Color(0xFF3D0C02); // Deep Imperial Red
    } else if (settings.atmosphereTheme == AtmosphereTheme.cyberpunk) {
      // Midnight Synthwave Purple
      baseColor = const Color(0xFF1A0B2E); // Deep Midnight Purple
    } else if (settings.atmosphereTheme == AtmosphereTheme.nordicAurora) {
      // Deep Boreal Night
      baseColor = const Color(0xFF030508); // Pitch Black / Deep Indigo
    } else if (settings.atmosphereTheme == AtmosphereTheme.galactic) {
      // The Void
      baseColor = const Color(0xFF010203); // Absolute Pitch Black
    } else if (settings.atmosphereTheme == AtmosphereTheme.desertMirage) {
      // Desert Heat
      baseColor = const Color(0xFF4A1000); // Deep Scorched Terracotta
    } else {
      baseColor = isDark
          ? const Color(0xFF121212)
          : const Color.fromARGB(255, 244, 244, 244);
    }

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
    return Color.alphaBlend(other.withValues(alpha: amount), this);
  }
}
