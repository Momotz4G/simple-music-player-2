import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/daily_mix_model.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../components/song_card_overlay.dart';
import '../components/playlist_collage.dart';

/// Detail page for viewing and playing a Daily Mix
class DailyMixDetailPage extends ConsumerStatefulWidget {
  final DailyMix mix;

  const DailyMixDetailPage({super.key, required this.mix});

  @override
  ConsumerState<DailyMixDetailPage> createState() => _DailyMixDetailPageState();
}

class _DailyMixDetailPageState extends ConsumerState<DailyMixDetailPage> {
  String? _loadingSongTitle;

  List<SongModel> get _songs => widget.mix.songs
      .map((meta) => SongModel(
            title: meta.title,
            artist: meta.artist,
            album: meta.album,
            filePath: '',
            duration: meta.durationSeconds.toDouble(),
            fileExtension: '.mp3',
            onlineArtUrl: meta.albumArtUrl,
            spotifyId: meta.spotifyId,
            isrc: meta.isrc,
          ))
      .toList();

  Future<void> _playTrack(SongModel song, List<SongModel> queue) async {
    if (_loadingSongTitle != null) return;

    setState(() => _loadingSongTitle = song.title);

    try {
      await ref.read(playerProvider.notifier).playSong(song, newQueue: queue);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSongTitle = null);
    }
  }

  void _playAll() {
    if (_songs.isNotEmpty) {
      _playTrack(_songs.first, _songs);
    }
  }

  void _saveAsPlaylist() {
    final notifier = ref.read(playlistProvider.notifier);

    // Add date to make unique (e.g. "Daily Mix 1 - Dec 27")
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final playlistName =
        "${widget.mix.title} - ${months[now.month - 1]} ${now.day}";

    // Create playlist
    notifier.createPlaylist(playlistName);

    // Get the newly created playlist
    final playlists = ref.read(playlistProvider);
    final newPlaylist = playlists.lastWhere((p) => p.name == playlistName);

    // Add songs
    notifier.addSongsToPlaylist(newPlaylist.id, _songs);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Saved as '$playlistName'!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Get art URLs for header collage
    final List<String> headerImagePaths = [];
    final List<String?> headerArtUrls = [];
    for (var song in _songs.take(4)) {
      headerImagePaths.add(song.filePath);
      headerArtUrls.add(song.onlineArtUrl);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => ref.read(navigationStackProvider.notifier).pop(),
            ),
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.mix.title),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Blur
                  if (headerArtUrls.isNotEmpty)
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Opacity(
                        opacity: 0.4,
                        child: PlaylistCollage(
                          imagePaths: headerImagePaths,
                          onlineArtUrls: headerArtUrls,
                          size: 400,
                        ),
                      ),
                    ),

                  // Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),

                  // Foreground Collage
                  Center(
                    child: Container(
                      decoration: const BoxDecoration(boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: PlaylistCollage(
                          imagePaths: headerImagePaths,
                          onlineArtUrls: headerArtUrls,
                          size: 160,
                        ),
                      ),
                    ),
                  ),

                  // Play Button
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      onPressed: _songs.isNotEmpty ? _playAll : null,
                      backgroundColor: accentColor,
                      child: const Icon(Icons.play_arrow, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.playlist_add, color: textColor),
                tooltip: "Save as Playlist",
                onPressed: _saveAsPlaylist,
              ),
              const SizedBox(width: 16),
            ],
          ),
          // Song List
          if (_songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text("No songs", style: TextStyle(color: subtitleColor)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = _songs[index];
                  final isLoading = _loadingSongTitle == song.title;

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Track number or loading
                        SizedBox(
                          width: 30,
                          child: isLoading
                              ? Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accentColor,
                                    ),
                                  ),
                                )
                              : Text(
                                  "${index + 1}",
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                        const SizedBox(width: 10),
                        // Song Card Overlay (matches playlist_detail)
                        SongCardOverlay(
                          song: song,
                          size: 48,
                          playQueue: _songs,
                          radius: 6,
                        ),
                      ],
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isLoading ? accentColor : textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      song.artist,
                      maxLines: 1,
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    trailing: SizedBox(
                      width: 45,
                      child: Text(
                        _formatDuration(song.duration),
                        textAlign: TextAlign.end,
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                    ),
                    onTap: () => _playTrack(song, _songs),
                  );
                },
                childCount: _songs.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  String _formatDuration(double duration) {
    if (duration <= 0) return "--:--";
    final int minutes = duration ~/ 60;
    final int seconds = (duration % 60).toInt();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}
