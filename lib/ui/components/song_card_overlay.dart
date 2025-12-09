import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import 'smart_art.dart';

class SongCardOverlay extends ConsumerStatefulWidget {
  final SongModel song;
  final double size;
  final List<SongModel> playQueue;
  final double radius;

  const SongCardOverlay({
    super.key,
    required this.song,
    this.size = 40,
    required this.playQueue,
    this.radius = 4.0,
  });

  @override
  ConsumerState<SongCardOverlay> createState() => _SongCardOverlayState();
}

class _SongCardOverlayState extends ConsumerState<SongCardOverlay> {
  bool _isHovering = false;

  // Use a unique key for the icon transition
  final GlobalKey _iconKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(playerProvider.notifier);
    final playerState = ref.watch(playerProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final isCurrentSong =
        playerState.currentSong?.filePath == widget.song.filePath;
    final isPlaying = playerState.isPlaying && isCurrentSong;

    final displayIcon =
        isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill;

    // Determine the icon color based on dynamic theme status
    Color iconColor = primaryColor;
    if (isCurrentSong) {
      // Use the actual accent color for consistency with the player bar controls
      iconColor = Theme.of(context).colorScheme.primary;
    }

    return MouseRegion(
      // DESKTOP HOVER LOGIC
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: () {
          // PLAYBACK LOGIC: Play or Pause the specific song
          if (isCurrentSong) {
            notifier.togglePlay();
          } else {
            // Start playing the clicked song within the new queue context
            notifier.playSong(widget.song, newQueue: widget.playQueue);
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Smart Art (Base Layer)
            // Uses path instead of bytes
            SmartArt(
              path: widget.song.filePath,
              size: widget.size,
              borderRadius: widget.radius,
              onlineArtUrl: widget.song.onlineArtUrl,
            ),

            // 2. Play/Pause Overlay Icon
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              // Show icon if hovering OR if the current song is playing/paused
              opacity: _isHovering || isCurrentSong ? 1.0 : 0.0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 150),
                scale: _isHovering ? 1.1 : 1.0, // Slight zoom on hover
                child: Icon(
                  displayIcon,
                  key: _iconKey,
                  size: widget.size * 0.9,
                  color: iconColor.withOpacity(0.9),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 6,
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
