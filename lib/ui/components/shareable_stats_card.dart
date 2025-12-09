import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/song_model.dart';
import 'smart_art.dart';

class ShareableStatsCard extends StatelessWidget {
  final SongModel song;
  final int playCount;
  final String title;
  final String appName;
  // Allow overriding the image (for Artist Photos)
  final ImageProvider? imageOverride;

  const ShareableStatsCard({
    super.key,
    required this.song,
    required this.playCount,
    this.title = "MY TOP TRACK",
    this.appName = "Simple Music Player",
    this.imageOverride,
  });

  @override
  Widget build(BuildContext context) {
    // 9:16 Aspect Ratio for Stories
    return Container(
      width: 350,
      height: 622,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.shade900,
            Colors.black,
            Colors.deepPurple.shade900,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. BACKGROUND: Blurred Art
          Positioned.fill(
            child: Opacity(
              opacity: 0.6,
              // Use Override if available, else SmartArt
              child: imageOverride != null
                  ? Image(
                      image: imageOverride!,
                      fit: BoxFit.cover,
                    )
                  : SmartArt(
                      path: song.filePath,
                      size: 800,
                      borderRadius: 0,
                      onlineArtUrl: song.onlineArtUrl,
                    ),
            ),
          ),
          // Blur Effect Layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.transparent),
            ),
          ),

          // 2. TEXTURE OVERLAY
          Container(color: Colors.black.withOpacity(0.2)),

          // 3. CONTENT
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // TOP BADGE
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white30),
                    borderRadius: BorderRadius.circular(50),
                    color: Colors.black26,
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // CENTER ARTWORK (Shadowed)
                Container(
                  height: 250,
                  width: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    // Use Override if available, else SmartArt
                    child: imageOverride != null
                        ? Image(
                            image: imageOverride!,
                            fit: BoxFit.cover,
                            width: 250,
                            height: 250,
                          )
                        : SmartArt(
                            path: song.filePath,
                            size: 250,
                            borderRadius: 12,
                            onlineArtUrl: song.onlineArtUrl,
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                // SONG INFO
                Text(
                  song.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  song.artist,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const Spacer(flex: 2),

                // STATS
                Text(
                  "$playCount",
                  style: const TextStyle(
                    color: Color(0xFF1DB954),
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                const Text(
                  "TOTAL PLAYS",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const Spacer(flex: 1),

                // FOOTER
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.music_note_rounded,
                        color: Colors.white54, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      appName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
