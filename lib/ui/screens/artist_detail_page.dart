import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../services/spotify_service.dart';
import '../../services/wikipedia_service.dart';
import '../../services/smart_download_service.dart';
import '../components/song_card_overlay.dart';
import '../components/song_context_menu.dart';
import '../../models/album_model.dart';
import '../components/album_card.dart';

class ArtistDetailPage extends ConsumerStatefulWidget {
  final String artistName;
  final List<SongModel> songs;

  const ArtistDetailPage({
    super.key,
    required this.artistName,
    required this.songs,
  });

  @override
  ConsumerState<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends ConsumerState<ArtistDetailPage> {
  String? _headerImageUrl;
  bool _isLoadingImage = true;
  Color _dominantColor = const Color(0xFF121212);
  String? _loadingSongTitle;

  // Spotify Mode State
  bool _isSpotifyMode = false;
  List<SongModel> _topTracks = [];
  List<AlbumModel> _albums = [];
  bool _isLoadingTracks = false;
  int _displayLimit = 5;
  ScrollPhysics _pageScrollPhysics = const BouncingScrollPhysics();

  // SERVICE INSTANCE
  final SmartDownloadService _smartService = SmartDownloadService();

  @override
  void initState() {
    super.initState();
    _isSpotifyMode = widget.songs.isEmpty;
    _fetchArtistHeader();
    if (_isSpotifyMode) {
      _fetchTopTracks();
    }
  }

  @override
  void didUpdateWidget(covariant ArtistDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.artistName != oldWidget.artistName) {
      // RESET STATE
      setState(() {
        _headerImageUrl = null;
        _isLoadingImage = true;
        _topTracks = [];
        _albums = [];
        _isLoadingTracks = true;
        _isSpotifyMode = widget.songs.isEmpty;
      });

      // RE-FETCH
      _fetchArtistHeader();
      if (_isSpotifyMode) {
        _fetchTopTracks();
      }
    }
  }

  Future<void> _fetchTopTracks() async {
    setState(() => _isLoadingTracks = true);
    final artistId =
        await SpotifyService.getArtistId(artistName: widget.artistName);
    if (artistId != null) {
      final tracks = await SpotifyService.getArtistTopTracks(artistId);

      // Convert to SongModel with predicted paths
      final songModels = await Future.wait(tracks.map((t) async {
        final predictedPath = await _smartService.getPredictedCachePath(t);
        return SongModel(
          title: t.title,
          artist: t.artist,
          album: t.album,
          filePath: predictedPath,
          fileExtension: '.mp3',
          duration: t.durationSeconds.toDouble(),
          onlineArtUrl: t.albumArtUrl,
          sourceUrl: null, // Will be resolved by JIT
        );
      }));

      // FETCH ALBUMS (Discography)
      final albums = await SpotifyService.getArtistAlbums(artistId);

      if (mounted) {
        setState(() {
          _topTracks = songModels;
          _albums = albums;
          _isLoadingTracks = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingTracks = false);
    }
  }

  Future<void> _fetchArtistHeader() async {
    String? url;

    // 1. Wikipedia (Priority 1)
    url = await WikipediaService.getArtistImage(widget.artistName);

    // 2. Spotify Banner (Priority 2)
    if (url == null) {
      final artistId =
          await SpotifyService.getArtistId(artistName: widget.artistName);
      if (artistId != null) {
        url = await SpotifyService.getFreshBannerUrl(artistId);

        // 3. Spotify Profile (Priority 3)
        url ??= await SpotifyService.getArtistImage(
            artistName: widget.artistName, highQuality: true);
      }
    }

    if (mounted) {
      setState(() {
        _headerImageUrl = url;
        _isLoadingImage = false;
      });
      if (url != null) {
        _extractColors(url);
      }
    }
  }

  Future<void> _extractColors(String imageUrl) async {
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
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
      // Ignore palette error
    }
  }

  // Play Track with Loading State
  Future<void> _playTrack(SongModel song, List<SongModel> queue) async {
    if (_loadingSongTitle != null) return; // Prevent double tap

    setState(() => _loadingSongTitle = song.title);

    // Add small artificial delay if it's too fast, or just let await handle it
    // The player provider's playSong handles JIT which might take time

    try {
      if (mounted) {
        await ref.read(playerProvider.notifier).playSong(
              song,
              newQueue: queue,
            );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loadingSongTitle = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(playerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = Theme.of(context).colorScheme.primary;
    final baseBg = Theme.of(context).scaffoldBackgroundColor;

    // Determine which list to show
    final currentList = _isSpotifyMode ? _topTracks : widget.songs;
    final int totalItems = currentList.length;
    final int displayCount =
        (totalItems > _displayLimit) ? _displayLimit : totalItems;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.6],
            colors: [
              _dominantColor.withOpacity(0.6),
              baseBg,
            ],
          ),
        ),
        child: CustomScrollView(
          physics: _pageScrollPhysics,
          slivers: [
            // --- HEADER ---
            SliverAppBar(
              expandedHeight: 380.0,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Image
                    if (_headerImageUrl != null)
                      Image.network(
                        _headerImageUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.black26),
                      )
                    else
                      Container(color: Colors.black26),

                    // 2. Gradient Overlay (Bottom Fade)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                            baseBg.withOpacity(0.9), // Blend to body
                          ],
                          stops: const [0.4, 0.7, 1.0],
                        ),
                      ),
                    ),

                    // 3. Content
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ARTIST",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.artistName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                              height: 1.0,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isSpotifyMode
                                ? "Popular on Spotify"
                                : "${widget.songs.length} songs in library",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  // Pop from navigation stack
                  ref.read(navigationStackProvider.notifier).pop();
                },
              ),
            ),

            // --- ACTION BAR ---
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    // Play Button (Matches Album Detail)
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
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.play_arrow_rounded,
                            color: Colors.black, size: 38),
                        onPressed: () {
                          if (currentList.isNotEmpty) {
                            // 🚀 PLAY ALL with Queue
                            notifier.playSong(currentList.first,
                                newQueue: currentList);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    // SHUFFLE BUTTON
                    IconButton(
                      icon: Icon(Icons.shuffle,
                          color: textColor.withOpacity(0.7), size: 28),
                      tooltip: "Shuffle",
                      onPressed: () {
                        if (currentList.isNotEmpty) {
                          // SHOW FEEDBACK
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.shuffle,
                                      color: Colors.white),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Shuffling ${widget.artistName}...",
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF333333),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          notifier.playRandom(currentList);
                        }
                      },
                    ),
                    const SizedBox(width: 24),
                    Icon(Icons.more_horiz,
                        color: textColor.withOpacity(0.7), size: 32),
                  ],
                ),
              ),
            ),

            // --- SONG LIST ---
            if (_isSpotifyMode && _isLoadingTracks)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = currentList[index];
                    return SongContextMenuRegion(
                      song: song,
                      currentQueue: currentList,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 4),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 30,
                              child: _loadingSongTitle == song.title
                                  ? Center(
                                      child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: accentColor)))
                                  : Text(
                                      "${index + 1}",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.5),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Use SmartArt for both modes
                            SongCardOverlay(
                              song: song,
                              size: 40,
                              radius: 4,
                              playQueue: currentList,
                            ),
                          ],
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _loadingSongTitle == song.title
                                  ? accentColor
                                  : textColor), // Highlight title too
                        ),
                        subtitle: Text(
                          song.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: textColor.withOpacity(0.6)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDuration(song.duration),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: textColor.withOpacity(0.6)),
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
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          // PLAY LOGIC (Unified) with Loading
                          // notifier.playSong(song, newQueue: currentList);
                          _playTrack(song, currentList);
                        },
                      ),
                    );
                  },
                  childCount: displayCount,
                ),
              ),

            // SHOW MORE / SHOW LESS BUTTON
            if (totalItems > 5)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          // Toggle between 5 and 10 (Max 10)
                          if (_displayLimit == 5) {
                            _displayLimit = 10;
                          } else {
                            _displayLimit = 5;
                          }
                        });
                      },
                      child: Text(
                        _displayLimit == 5 ? "Show More" : "Show Less",
                        style: TextStyle(color: accentColor),
                      ),
                    ),
                  ),
                ),
              ),

            // DISCOGRAPHY SECTION
            if (_isSpotifyMode && _albums.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Text(
                    "Discography",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220, // Height for Album Cards
                  child: DiscographySection(
                    albums: _albums,
                    onScrollFocus: (isLocked) {
                      setState(() {
                        _pageScrollPhysics = isLocked
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics();
                      });
                    },
                    onAlbumTap: (album) {
                      ref.read(navigationStackProvider.notifier).push(
                            NavigationItem(
                                type: NavigationType.album, data: album),
                          );
                    },
                  ),
                ),
              ),
            ],

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// DiscographySection Widget
class DiscographySection extends StatefulWidget {
  final List<AlbumModel> albums;
  final Function(bool) onScrollFocus;
  final Function(AlbumModel) onAlbumTap;

  const DiscographySection({
    super.key,
    required this.albums,
    required this.onScrollFocus,
    required this.onAlbumTap,
  });

  @override
  State<DiscographySection> createState() => _DiscographySectionState();
}

class _DiscographySectionState extends State<DiscographySection> {
  final ScrollController _scrollController = ScrollController();
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final limit = 10;
    final showExpandButton = !_showAll && widget.albums.length > limit;
    final itemCount = _showAll
        ? widget.albums.length
        : (widget.albums.length > limit ? limit + 1 : widget.albums.length);

    return MouseRegion(
      onEnter: (_) => widget.onScrollFocus(true),
      onExit: (_) => widget.onScrollFocus(false),
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
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // EXPAND BUTTON
            if (showExpandButton && index == limit) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 160,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.grey.withOpacity(0.5)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_forward, size: 30),
                          onPressed: () => setState(() => _showAll = true),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text("See All",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }

            final album = widget.albums[index];
            final year = album.releaseDate.split('-').first;

            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 160,
                child: AlbumCard(
                  albumName: album.title,
                  artistName: album.artist,
                  songs: const [],
                  imageUrl: album.imageUrl,
                  year: year,
                  onTap: () => widget.onAlbumTap(album),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
