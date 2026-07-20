import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../models/song_metadata.dart';
import '../../models/song_model.dart';
import '../../l10n/app_localizations.dart';
import '../../services/spotify_service.dart';
import '../../services/smart_download_service.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../providers/settings_provider.dart';
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
  SongModel? _song;
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
          fileExtension: predictedPath.isNotEmpty ? '.${predictedPath.split('.').last}' : '.mp3',
          duration: widget.songMetadata.durationSeconds.toDouble(),
          onlineArtUrl: widget.songMetadata.albumArtUrl,
          isrc: widget.songMetadata.isrc,
          trackNumber: widget.songMetadata.trackNumber,
          discNumber: widget.songMetadata.discNumber,
          year: widget.songMetadata.year,
          genre: widget.songMetadata.genre,
          spotifyId: widget.songMetadata.spotifyId,
          deezerId: widget.songMetadata.deezerId,
          sourceUrl: widget.songMetadata.youtubeUrl,
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

        if (!mounted) return;

        showCenterNotification(context,
            label: AppLocalizations.of(context)!.playingTrack,
            title: song.title,
            subtitle: song.artist,
            artPath: song.filePath,
            onlineArtUrl: song.onlineArtUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("${AppLocalizations.of(context)!.playbackError}: $e"),
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
              _dominantColor.withValues(alpha: 0.7),
              baseBg.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // --- HEADER ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Responsive: Use vertical layout on narrow screens
                    final isNarrow = constraints.maxWidth < 500;
                    final artSize = isNarrow
                        ? constraints.maxWidth * 0.6
                        : 220.0; // Scale album art
                    final titleFontSize =
                        isNarrow ? 28.0 : 50.0; // Scale title font

                    if (isNarrow) {
                      // --- MOBILE: VERTICAL LAYOUT ---
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Album Art
                          Container(
                            width: artSize,
                            height: artSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                )
                              ],
                              image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Song Label
                          Text(AppLocalizations.of(context)!.songLabelUpper,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Colors.grey)),
                          const SizedBox(height: 8),
                          // Title
                          Text(
                            song.title,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          // Artist Row
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) => setState(() => _isArtistHovered = true),
                            onExit: (_) => setState(() => _isArtistHovered = false),
                            child: GestureDetector(
                              onTap: () {
                                ref.read(navigationStackProvider.notifier).push(
                                      NavigationItem(
                                        type: NavigationType.artist,
                                        data: ArtistSelection(
                                            artistName: song.artist,
                                            songs: <SongModel>[]),
                                      ),
                                    );
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.grey,
                                    backgroundImage: _artistImageUrl != null
                                        ? NetworkImage(_artistImageUrl!)
                                        : null,
                                    child: _artistImageUrl == null
                                        ? const Icon(Icons.person, size: 16)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      song.artist,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration: _isArtistHovered
                                            ? TextDecoration.underline
                                            : null,
                                        decorationColor: textColor,
                                        color: textColor,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Year & Duration
                          Text(
                            "${song.year?.split('-').first ?? "Unknown"} • ${song.duration.toInt() ~/ 60}:${(song.duration.toInt() % 60).toString().padLeft(2, '0')}",
                            style: TextStyle(
                                color: textColor.withValues(alpha: 0.6),
                                fontSize: 13),
                          ),
                        ],
                      );
                    } else {
                      // --- DESKTOP/TABLET: HORIZONTAL LAYOUT ---
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: artSize,
                            height: artSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
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
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                      AppLocalizations.of(context)!
                                          .songLabelUpper,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1)),
                                  const SizedBox(height: 8),
                                  Text(
                                    song.title,
                                    style: TextStyle(
                                      fontSize: titleFontSize,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                      height: 1.0,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 24),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) => setState(() => _isArtistHovered = true),
                                    onExit: (_) => setState(() => _isArtistHovered = false),
                                    child: GestureDetector(
                                      onTap: () {
                                        ref.read(navigationStackProvider.notifier).push(
                                          NavigationItem(
                                            type: NavigationType.artist,
                                            data: ArtistSelection(
                                                artistName: song.artist,
                                                songs: <SongModel>[]),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
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
                                          Flexible(
                                            child: Text(
                                              song.artist,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                decoration: _isArtistHovered
                                                    ? TextDecoration.underline
                                                    : null,
                                                decorationColor: textColor,
                                                color: textColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${song.year?.split('-').first ?? "Unknown"} • ${song.duration.toInt() ~/ 60}:${(song.duration.toInt() % 60).toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                        color: textColor.withValues(alpha: 0.7),
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  },
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
                                color: Colors.black.withValues(alpha: 0.3),
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
                          color: textColor.withValues(alpha: 0.7), size: 32),
                      tooltip: AppLocalizations.of(context)!.moreOptions,
                      onSelected: (action) {
                        SongContextMenuRegion.handleAction(
                            context, ref, action, song);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                            value: SongAction.playNext,
                            child: Row(children: [
                              const Icon(Icons.playlist_play),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context)!.playNext)
                            ])),
                        PopupMenuItem(
                            value: SongAction.addToQueue,
                            child: Row(children: [
                              const Icon(Icons.queue_music),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context)!.addToQueue)
                            ])),
                        PopupMenuItem(
                            value: SongAction.addToPlaylist,
                            child: Row(children: [
                              const Icon(Icons.playlist_add),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context)!.addToPlaylist)
                            ])),
                        PopupMenuItem(
                            value: SongAction.addToFavorite,
                            child: Row(children: [
                              const Icon(Icons.favorite_border),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context)!.addToFavorite)
                            ])),
                        PopupMenuItem(
                            value: SongAction.goToArtist,
                            child: Row(children: [
                              const Icon(Icons.person_search),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context)!.goToArtist)
                            ])),
                        PopupMenuItem(
                            value: SongAction.download,
                            child: Row(children: [
                              const Icon(Icons.download_rounded),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context)!.download)
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
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${song.duration.toInt() ~/ 60}:${(song.duration.toInt() % 60).toString().padLeft(2, '0')}",
                          style: TextStyle(
                              color: textColor.withValues(alpha: 0.6),
                              fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        PopupMenuButton<SongAction>(
                          icon: Icon(Icons.more_horiz,
                              color: textColor.withValues(alpha: 0.6)),
                          tooltip: AppLocalizations.of(context)!.moreOptions,
                          onSelected: (action) {
                            SongContextMenuRegion.handleAction(
                                context, ref, action, song);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                                value: SongAction.playNext,
                                child: Row(children: [
                                  const Icon(Icons.playlist_play),
                                  const SizedBox(width: 12),
                                  Text(AppLocalizations.of(context)!.playNext)
                                ])),
                            PopupMenuItem(
                                value: SongAction.addToQueue,
                                child: Row(children: [
                                  const Icon(Icons.queue_music),
                                  const SizedBox(width: 12),
                                  Text(AppLocalizations.of(context)!.addToQueue)
                                ])),
                            PopupMenuItem(
                                value: SongAction.addToPlaylist,
                                child: Row(children: [
                                  const Icon(Icons.playlist_add),
                                  const SizedBox(width: 12),
                                  Text(AppLocalizations.of(context)!
                                      .addToPlaylist)
                                ])),
                            PopupMenuItem(
                                value: SongAction.addToFavorite,
                                child: Row(children: [
                                  const Icon(Icons.favorite_border),
                                  const SizedBox(width: 12),
                                  Text(AppLocalizations.of(context)!
                                      .addToFavorite)
                                ])),
                            PopupMenuItem(
                                value: SongAction.goToArtist,
                                child: Row(children: [
                                  const Icon(Icons.person_search),
                                  const SizedBox(width: 12),
                                  Text(AppLocalizations.of(context)!.goToArtist)
                                ])),
                            PopupMenuItem(
                                value: SongAction.download,
                                child: Row(children: [
                                  const Icon(Icons.download_rounded),
                                  const SizedBox(width: 12),
                                  Text(AppLocalizations.of(context)!.download)
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

// --- MARQUEE TEXT WIDGET ---
class _MarqueeText extends StatefulWidget {
  final String text;

  const _MarqueeText({
    required this.text,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    if (!mounted) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      setState(() => _needsScroll = true);
      _startScrolling();
    }
  }

  void _startScrolling() {
    if (!_needsScroll || !mounted) return;

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _animateScroll();
    });
  }

  void _animateScroll() async {
    if (!mounted || !_needsScroll) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    // Scroll to end
    await _scrollController.animateTo(
      maxScroll,
      duration:
          Duration(milliseconds: (maxScroll * 30).toInt().clamp(2000, 8000)),
      curve: Curves.linear,
    );

    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 2));

    // Scroll back to start
    if (!mounted) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );

    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 2));

    // Repeat
    _animateScroll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          maxLines: 1,
        ),
      ),
    );
  }
}
