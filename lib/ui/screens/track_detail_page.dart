import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../models/song_metadata.dart';
import '../../models/song_model.dart';
import '../../services/spotify_service.dart';
import '../../services/smart_download_service.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../components/music_notification.dart';
import '../components/song_context_menu.dart';

class TrackDetailPage extends ConsumerStatefulWidget {
  final SongMetadata songMetadata;

  const TrackDetailPage({super.key, required this.songMetadata});

  @override
  ConsumerState<TrackDetailPage> createState() => _TrackDetailPageState();
}

class _TrackDetailPageState extends ConsumerState<TrackDetailPage> {
  // UI State
  Color _dominantColor = const Color(0xFF121212);
  String _headerImageUrl = "";
  bool _isArtistHovered = false;

  // Track Logic
  SongModel? _song; // 🚀 FIX: Removed late, made nullable
  String? _loadingSongTitle;
  String? _artistImageUrl;

  @override
  void initState() {
    super.initState();
    _headerImageUrl = widget.songMetadata.albumArtUrl;
    _initData();
  }

  Future<void> _initData() async {
    // 1. Create SongModel
    final predictedPath =
        await SmartDownloadService().getPredictedCachePath(widget.songMetadata);

    if (mounted) {
      setState(() {
        _song = SongModel(
          title: widget.songMetadata.title,
          artist: widget.songMetadata.artist,
          album: widget.songMetadata.album,
          filePath: predictedPath,
          fileExtension: '.mp3',
          duration: widget.songMetadata.durationSeconds.toDouble(),
          onlineArtUrl: widget.songMetadata.albumArtUrl,
          isrc: widget.songMetadata.isrc,
          trackNumber: widget.songMetadata.trackNumber,
          discNumber: widget.songMetadata.discNumber,
          year: widget.songMetadata.year,
          genre: widget.songMetadata.genre,
        );
      });
    }

    // 2. Extract Colors
    _extractColors();

    // 3. Fetch Artist Image
    SpotifyService.getArtistImage(
      artistName: widget.songMetadata.artist,
      trackTitle: widget.songMetadata.title,
    ).then((url) {
      if (mounted && url != null) {
        setState(() => _artistImageUrl = url);
      }
    });
  }

  Future<void> _extractColors() async {
    if (_headerImageUrl.isEmpty) return;
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(_headerImageUrl),
        size: const Size(100, 100),
        maximumColorCount: 10,
      );
      if (mounted) {
        setState(() {
          _dominantColor = generator.mutedColor?.color ??
              generator.dominantColor?.color ??
              const Color(0xFF121212);
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _playTrack() async {
    final song = _song;
    if (song == null || _loadingSongTitle != null) return;

    setState(() => _loadingSongTitle = song.title);

    try {
      if (mounted) {
        // Play just this song, with itself as the queue
        await ref.read(playerProvider.notifier).playSong(
          song,
          newQueue: [song],
        );

        showCenterNotification(context,
            label: "PLAYING TRACK",
            title: song.title,
            subtitle: song.artist,
            artPath: song.filePath,
            onlineArtUrl: song.onlineArtUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Playback error: $e"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSongTitle = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = _song;

    if (song == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final baseBg = Theme.of(context).scaffoldBackgroundColor;
    final accentColor = Theme.of(context).colorScheme.primary;

    final imageProvider = _headerImageUrl.isNotEmpty
        ? NetworkImage(_headerImageUrl)
        : const NetworkImage("https://via.placeholder.com/300")
            as ImageProvider;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            ref.read(navigationStackProvider.notifier).pop();
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.7],
            colors: [
              _dominantColor.withOpacity(0.7),
              baseBg.withOpacity(0.8),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // --- HEADER ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 100, 32, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          )
                        ],
                        image: DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text("SONG",
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Text(
                            song.title,
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              height: 1.0,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.grey,
                                backgroundImage: _artistImageUrl != null
                                    ? NetworkImage(_artistImageUrl!)
                                    : null,
                                child: _artistImageUrl == null
                                    ? const Icon(Icons.person, size: 14)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) =>
                                    setState(() => _isArtistHovered = true),
                                onExit: (_) =>
                                    setState(() => _isArtistHovered = false),
                                child: GestureDetector(
                                  onTap: () {
                                    ref
                                        .read(navigationStackProvider.notifier)
                                        .push(
                                          NavigationItem(
                                            type: NavigationType.artist,
                                            data: ArtistSelection(
                                                artistName: song.artist,
                                                songs: <SongModel>[]),
                                          ),
                                        );
                                  },
                                  child: Text(song.artist,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          decoration: _isArtistHovered
                                              ? TextDecoration.underline
                                              : null,
                                          decorationColor: textColor,
                                          color: textColor)),
                                ),
                              ),
                              Text(
                                " • ${song.year?.split('-').first ?? "Unknown"} • ${song.duration.toInt() ~/ 60}:${(song.duration.toInt() % 60).toString().padLeft(2, '0')}",
                                style: TextStyle(
                                    color: textColor.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- ACTION BUTTONS ---
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ]),
                      child: IconButton(
                        icon: const Icon(Icons.play_arrow_rounded,
                            color: Colors.black, size: 38),
                        onPressed: _playTrack,
                      ),
                    ),
                    const SizedBox(width: 24),
                    const SizedBox(width: 24),
                    PopupMenuButton<SongAction>(
                      icon: Icon(Icons.more_horiz,
                          color: textColor.withOpacity(0.7), size: 32),
                      tooltip: "More Options",
                      onSelected: (action) {
                        SongContextMenuRegion.handleAction(
                            context, ref, action, song);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: SongAction.playNext,
                            child: Row(children: [
                              Icon(Icons.playlist_play),
                              SizedBox(width: 12),
                              Text('Play Next')
                            ])),
                        const PopupMenuItem(
                            value: SongAction.addToPlaylist,
                            child: Row(children: [
                              Icon(Icons.playlist_add),
                              SizedBox(width: 12),
                              Text('Add to Playlist')
                            ])),
                        const PopupMenuItem(
                            value: SongAction.addToFavorites,
                            child: Row(children: [
                              Icon(Icons.favorite_border),
                              SizedBox(width: 12),
                              Text('Add to Favorites')
                            ])),
                        const PopupMenuItem(
                            value: SongAction.goToArtist,
                            child: Row(children: [
                              Icon(Icons.person_search),
                              SizedBox(width: 12),
                              Text('Go to Artist')
                            ])),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // --- SINGLE TRACK ITEM ---
            SliverList(
              delegate: SliverChildListDelegate([
                SongContextMenuRegion(
                  song: song,
                  currentQueue: [song],
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
                    leading: SizedBox(
                      width: 30,
                      height: 30,
                      child: (_loadingSongTitle == song.title)
                          ? Center(
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: accentColor)))
                          : const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "1",
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ),
                    ),
                    title: Text(song.title,
                        style: TextStyle(
                            color: (_loadingSongTitle == song.title)
                                ? accentColor
                                : textColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(song.artist,
                        style: TextStyle(
                            color: textColor.withOpacity(0.6), fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${song.duration.toInt() ~/ 60}:${(song.duration.toInt() % 60).toString().padLeft(2, '0')}",
                          style: TextStyle(
                              color: textColor.withOpacity(0.6), fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        PopupMenuButton<SongAction>(
                          icon: Icon(Icons.more_horiz,
                              color: textColor.withOpacity(0.6)),
                          tooltip: "More Options",
                          onSelected: (action) {
                            SongContextMenuRegion.handleAction(
                                context, ref, action, song);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: SongAction.playNext,
                                child: Row(children: [
                                  Icon(Icons.playlist_play),
                                  SizedBox(width: 12),
                                  Text('Play Next')
                                ])),
                            const PopupMenuItem(
                                value: SongAction.addToPlaylist,
                                child: Row(children: [
                                  Icon(Icons.playlist_add),
                                  SizedBox(width: 12),
                                  Text('Add to Playlist')
                                ])),
                            const PopupMenuItem(
                                value: SongAction.addToFavorites,
                                child: Row(children: [
                                  Icon(Icons.favorite_border),
                                  SizedBox(width: 12),
                                  Text('Add to Favorites')
                                ])),
                            const PopupMenuItem(
                                value: SongAction.goToArtist,
                                child: Row(children: [
                                  Icon(Icons.person_search),
                                  SizedBox(width: 12),
                                  Text('Go to Artist')
                                ])),
                          ],
                        ),
                      ],
                    ),
                    onTap: _playTrack,
                  ),
                )
              ]),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 160)),
          ],
        ),
      ),
    );
  }
}
