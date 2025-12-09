import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/playlist_model.dart';
import '../../models/song_model.dart';

import 'playlist_collage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/search_bridge_provider.dart';

class HorizontalPlaylistSection extends StatefulWidget {
  final String title;
  final List<PlaylistModel> playlists;
  final List<SongModel> allLibrarySongs;
  final Function(bool isFocused)? onScrollFocus;

  const HorizontalPlaylistSection({
    super.key,
    required this.title,
    required this.playlists,
    required this.allLibrarySongs,
    this.onScrollFocus,
  });

  @override
  State<HorizontalPlaylistSection> createState() =>
      _HorizontalPlaylistSectionState();
}

class _HorizontalPlaylistSectionState extends State<HorizontalPlaylistSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.playlists.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;

    // --- 1. DEFINE DIMENSIONS ---
    const double itemWidth = 160.0; // Must match _PlaylistTile width
    const double gap = 20.0; // Must match separator width
    const double padding = 32.0; // Must match ListView padding

    // --- 2. CALCULATE EXACT CONTENT WIDTH ---
    // Formula: (Items * Width) + (Gaps) + (Left+Right Padding)
    final int count = widget.playlists.length;
    final double contentWidth =
        (count * itemWidth) + ((count - 1) * gap) + (padding * 2);

    // --- 3. GET SCREEN WIDTH ---
    final double screenWidth = MediaQuery.of(context).size.width;

    // --- 4. DETERMINE FINAL CONTAINER WIDTH ---
    // If content is smaller than screen, shrink the container.
    final double finalWidth = min(contentWidth, screenWidth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- HEADER ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: titleColor,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // --- SCROLLABLE LIST ---
        // 5. ALIGN LEFT: Keeps the list at the start, leaving empty space for vertical scroll
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 240,
            width: finalWidth, // APPLY CALCULATED WIDTH HERE
            child: MouseRegion(
              onEnter: (_) => widget.onScrollFocus?.call(true),
              onExit: (_) => widget.onScrollFocus?.call(false),
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    final offset = pointerSignal.scrollDelta.dy;
                    final targetOffset = _scrollController.offset + offset;
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(
                        targetOffset.clamp(
                            0.0, _scrollController.position.maxScrollExtent),
                      );
                    }
                  }
                },
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: padding),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.playlists.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: gap),
                  // 6. DISABLE PHYSICS if it fits on screen (Optional, adds cleaner feel)
                  physics: contentWidth <= screenWidth
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final playlist = widget.playlists[index];
                    return _PlaylistTile(
                      playlist: playlist,
                      librarySongs: widget.allLibrarySongs,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaylistTile extends ConsumerStatefulWidget {
  final PlaylistModel playlist;
  final List<SongModel> librarySongs;

  const _PlaylistTile({required this.playlist, required this.librarySongs});

  @override
  ConsumerState<_PlaylistTile> createState() => _PlaylistTileState();
}

class _PlaylistTileState extends ConsumerState<_PlaylistTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;
    final subTitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Collect paths (String) and URLs
    final List<String> imagePaths = [];
    final List<String?> onlineArtUrls = [];

    // We want to fill 4 slots if possible, or at least find 1 valid image to replicate.
    // We scan up to 20 songs to find 4 valid covers (avoid scanning huge playlists entirely)
    int validFound = 0;
    for (var entry in widget.playlist.entries) {
      if (validFound >= 4) break;

      bool hasLocal = entry.path.isNotEmpty && !entry.path.startsWith('http');
      bool hasOnline = entry.artUrl != null && entry.artUrl!.isNotEmpty;

      // If we have either local or online art, it's a candidate
      if (hasLocal || hasOnline) {
        imagePaths.add(entry.path);
        onlineArtUrls.add(entry.artUrl);
        validFound++;
      }
    }

    // FORCE GRID LOGIC
    List<String> finalPaths = [];
    List<String?> finalUrls = [];

    if (imagePaths.isNotEmpty) {
      if (widget.playlist.entries.length >= 4) {
        // Force 4 items to ensure Grid
        for (int i = 0; i < 4; i++) {
          finalPaths.add(imagePaths[i % imagePaths.length]);
          finalUrls.add(onlineArtUrls[i % onlineArtUrls.length]);
        }
      } else {
        // Small playlist (< 4 songs). Just use what we found.
        finalPaths = imagePaths;
        finalUrls = onlineArtUrls;
      }
    }

    return SizedBox(
      width: 160, // Used in calculation above
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: GestureDetector(
              onTap: () {
                // Use provider navigation instead of Navigator.push
                ref.read(navigationStackProvider.notifier).push(
                      NavigationItem(
                          type: NavigationType.playlist,
                          data: widget.playlist.id),
                    );
              },
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: _isHovering ? 1.05 : 1.0,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isHovering
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ]
                        : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PlaylistCollage(
                      // Pass paths instead of bytes
                      imagePaths: finalPaths,
                      onlineArtUrls: finalUrls, // PASS URLS
                      size: 160,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${widget.playlist.entries.length} Songs",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: subTitleColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
