import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song_model.dart';
import '../../models/song_metadata.dart';
import '../../models/youtube_search_result.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/smart_download_service.dart';
import 'smart_art.dart';
import 'music_notification.dart';
import 'song_context_menu.dart';

class AutoScrollSection extends ConsumerStatefulWidget {
  final String title;
  final String? subtitle;
  final List<SongModel> songs;
  final Function(bool)? onScrollFocus;

  const AutoScrollSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.songs,
    this.onScrollFocus,
  });

  @override
  ConsumerState<AutoScrollSection> createState() => _AutoScrollSectionState();
}

class _AutoScrollSectionState extends ConsumerState<AutoScrollSection> {
  final ScrollController _scrollController = ScrollController();
  final SmartDownloadService _smartService = SmartDownloadService();
  Timer? _timer;
  bool _isUserInteracting = false;
  bool _isRestoring = false;

  final double _itemWidth = 140.0;
  final double _gap = 16.0;
  final Duration _scrollInterval = const Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(_scrollInterval, (timer) {
      if (!_isUserInteracting && mounted && _scrollController.hasClients) {
        final double maxScroll = _scrollController.position.maxScrollExtent;
        final double currentOffset = _scrollController.offset;

        if (currentOffset >= maxScroll - 10) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeInOutQuart,
          );
        } else {
          _scrollController.animateTo(
            currentOffset + _itemWidth + _gap,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  void _stopAutoScroll() {
    _timer?.cancel();
  }

  // SMART PLAY LOGIC (Restores file if missing)
  Future<void> _handleSongTap(SongModel song) async {
    if (_isRestoring) return;

    final file = File(song.filePath);

    // CASE 1: File exists -> PLAY
    if (await file.exists()) {
      ref.read(playerProvider.notifier).playSong(song);
      return;
    }

    // CASE 2: File Missing -> RESTORE
    setState(() => _isRestoring = true);

    // Show Glass Notification so user knows something is happening
    if (!mounted) return;
    showCenterNotification(context,
        label: "RESTORING",
        title: song.title,
        subtitle: "Re-buffering...",
        artPath: song.onlineArtUrl // Use online URL since file is gone
        );

    try {
      final meta = SongMetadata(
        title: song.title,
        artist: song.artist,
        album: song.album,
        year: "",
        genre: "",
        durationSeconds: song.duration.toInt(),
        albumArtUrl: song.onlineArtUrl ?? "",
        isrc: song.isrc,
      );

      // Perform Just-In-Time YouTube Search if URL is missing or invalid (Spotify)
      String finalUrl = song.sourceUrl ?? "";
      if (finalUrl.isEmpty || finalUrl.contains("spotify.com")) {
        print("🔍 Searching YouTube for: ${song.artist} - ${song.title}");
        final match = await _smartService.searchYouTubeForMatch(meta);
        if (match != null && match.youtubeMatches.isNotEmpty) {
          finalUrl = match.youtubeMatches.first.url;
          print("✅ Found YouTube Match: $finalUrl");
        } else {
          throw Exception("No YouTube match found.");
        }
      }

      final ytResult = YoutubeSearchResult(
        title: song.title,
        artist: song.artist,
        duration: "",
        url: finalUrl,
        thumbnailUrl: song.onlineArtUrl ?? "",
      );

      final streamingQuality = ref.read(settingsProvider).streamingQuality;
      final restoredSong = await _smartService.cacheAndPlay(
        video: ytResult,
        metadata: meta,
        onProgress: (_) {},
        streamingQuality: streamingQuality,
      );

      if (restoredSong != null) {
        if (mounted) {
          ref.read(playerProvider.notifier).playSong(restoredSong);
          // Update to "Now Playing"
          showCenterNotification(context,
              label: "NOW PLAYING",
              title: restoredSong.title,
              subtitle: restoredSong.artist,
              artPath: restoredSong.filePath,
              onlineArtUrl: restoredSong.onlineArtUrl);
        }
      }
    } catch (e) {
      print("Restore failed: $e");
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: Listener(
            onPointerDown: (_) {
              setState(() => _isUserInteracting = true);
              _stopAutoScroll();
              widget.onScrollFocus?.call(true);
            },
            onPointerUp: (_) {
              setState(() => _isUserInteracting = false);
              widget.onScrollFocus?.call(false);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted && !_isUserInteracting) {
                  _startAutoScroll();
                }
              });
            },
            onPointerCancel: (_) {
              setState(() => _isUserInteracting = false);
              widget.onScrollFocus?.call(false);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted && !_isUserInteracting) {
                  _startAutoScroll();
                }
              });
            },
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.songs.length,
              separatorBuilder: (ctx, i) => SizedBox(width: _gap),
              itemBuilder: (context, index) {
                final song = widget.songs[index];
                return _buildSongCard(song);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSongCard(SongModel song) {
    // Use Network if file is missing AND we have a URL

    // Mobile Check
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return _SongCardItem(
        song: song,
        width: _itemWidth,
        isMobile: isMobile,
        queue: widget.songs,
        onTap: () => _handleSongTap(song));
  }
}

class _SongCardItem extends StatefulWidget {
  final SongModel song;
  final double width;
  final bool isMobile;
  final List<SongModel> queue;
  final VoidCallback onTap;

  const _SongCardItem({
    required this.song,
    required this.width,
    required this.isMobile,
    required this.queue,
    required this.onTap,
  });

  @override
  State<_SongCardItem> createState() => _SongCardItemState();
}

class _SongCardItemState extends State<_SongCardItem> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // We need ConsumerRef to show menu?
    // Wait, SongContextMenuRegion.showSongMenu needs ref.
    // So this widget needs to be a ConsumerStatefulWidget or pass ref.
    // Easier to make it ConsumerStatefulWidget.

    return Consumer(builder: (context, ref, _) {
      return SongContextMenuRegion(
        song: widget.song,
        currentQueue: widget.queue,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTap: widget.onTap,
            // LONG PRESS HIGHLIGHT LOGIC
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onLongPressStart: (details) {
              setState(() => _isPressed = true);
              if (widget.isMobile) {
                SongContextMenuRegion.showSongMenu(
                    context, details.globalPosition, ref, widget.song);
              }
            },
            onLongPressEnd: (_) => setState(() => _isPressed = false),
            child: SizedBox(
              width: widget.width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ARTWORK
                  AspectRatio(
                    aspectRatio: 1.0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 100),
                      scale: _isPressed ? 0.95 : (_isHovering ? 1.05 : 1.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[900],
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SmartArt(
                                path: widget.song.filePath,
                                size: widget.width,
                                borderRadius: 12,
                                onlineArtUrl: widget.song.onlineArtUrl,
                              ),
                            ),
                            // PRESSED STATE OVERLAY
                            if (_isPressed)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // TEXT
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              widget.song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isMobile)
                        GestureDetector(
                          onTapDown: (details) {
                            SongContextMenuRegion.showSongMenu(context,
                                details.globalPosition, ref, widget.song);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Icon(
                              Icons.more_vert_rounded,
                              size: 20,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
