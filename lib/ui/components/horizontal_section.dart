import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import 'smart_art.dart';
import 'song_context_menu.dart';

class HorizontalSection extends ConsumerStatefulWidget {
  final String title;
  final List<SongModel> songs;
  final VoidCallback? onSeeAll;
  final Function(bool isFocused)? onScrollFocus;

  const HorizontalSection({
    super.key,
    required this.title,
    required this.songs,
    this.onSeeAll,
    this.onScrollFocus,
  });

  @override
  ConsumerState<HorizontalSection> createState() => _HorizontalSectionState();
}

class _HorizontalSectionState extends ConsumerState<HorizontalSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- HEADER ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  letterSpacing: 0.5,
                ),
              ),
              if (widget.onSeeAll != null)
                TextButton(
                  onPressed: widget.onSeeAll,
                  child: const Text("See all"),
                ),
            ],
          ),
        ),

        // --- SCROLLABLE LIST ---
        SizedBox(
          height: 240,
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
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                scrollDirection: Axis.horizontal,
                itemCount: widget.songs.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 20),
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final song = widget.songs[index];
                  return _SimpleSongTile(song: song, queue: widget.songs);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SimpleSongTile extends ConsumerStatefulWidget {
  final SongModel song;
  final List<SongModel> queue;

  const _SimpleSongTile({required this.song, required this.queue});

  @override
  ConsumerState<_SimpleSongTile> createState() => _SimpleSongTileState();
}

class _SimpleSongTileState extends ConsumerState<_SimpleSongTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(playerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;
    final subTitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return SongContextMenuRegion(
      song: widget.song,
      currentQueue: widget.queue,
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              child: GestureDetector(
                onTap: () {
                  notifier.playSong(widget.song, newQueue: widget.queue);
                },
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: _isHovering ? 1.05 : 1.0,
                  child: Container(
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
                    child: SmartArt(
                      path: widget.song.filePath,
                      size: 160,
                      borderRadius: 12,
                      onlineArtUrl: widget.song.onlineArtUrl,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.song.title,
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
              widget.song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subTitleColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
