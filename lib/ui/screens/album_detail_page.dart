import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:metadata_god/metadata_god.dart';
import '../../models/album_model.dart';

import '../../models/song_model.dart';
import '../../services/spotify_service.dart';
import '../../services/smart_download_service.dart';
import '../../services/youtube_downloader_service.dart';
import '../../services/bulk_download_service.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../providers/library_presentation_provider.dart';
import '../../providers/playlist_provider.dart';
import '../components/music_notification.dart';
import '../components/song_context_menu.dart';
import '../components/song_card_overlay.dart';

class AlbumDetailPage extends ConsumerStatefulWidget {
  final AlbumModel album;

  const AlbumDetailPage({super.key, required this.album});

  @override
  ConsumerState<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends ConsumerState<AlbumDetailPage> {
  // Services
  final SmartDownloadService _smartService = SmartDownloadService();
  final YoutubeDownloaderService _ytService = YoutubeDownloaderService();

  List<SongModel> _tracks = [];
  bool _isLoading = true;

  // UI State
  Color _dominantColor = const Color(0xFF121212);
  String? _artistImageUrl;
  String _headerImageUrl = "";
  Uint8List? _localImageBytes; // 🚀 ADDED: For local album art
  bool _isArtistHovered = false;

  // Playback Loading State
  String? _loadingSongTitle;

  @override
  void initState() {
    super.initState();
    _headerImageUrl = widget.album.imageUrl;
    _ytService.initialize();
    _initData();
  }

  @override
  void didUpdateWidget(covariant AlbumDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.album.id != oldWidget.album.id) {
      setState(() {
        _isLoading = true;
        _tracks = [];
        _dominantColor = const Color(0xFF121212);
        _artistImageUrl = null;
        _headerImageUrl = widget.album.imageUrl;
        _localImageBytes = null;
      });
      _initData();
    }
  }

  Future<void> _initData() async {
    await _fetchTracks();
    await _fetchAlbumImageIfNeeded();
    _extractColors();
    _fetchArtistImage();
  }

  Future<void> _fetchTracks() async {
    // CASE 1: Local Album
    if (widget.album.localSongs != null &&
        widget.album.localSongs!.isNotEmpty) {
      final localSongs = widget.album.localSongs!.cast<SongModel>();

      if (mounted) {
        setState(() {
          _tracks = localSongs; // Direct assignment!
          _isLoading = false;
        });
      }
      return;
    }

    // CASE 2: Spotify Album
    try {
      final tracks = await SpotifyService.getAlbumTracks(widget.album.id);

      // Convert to SongModel with predicted paths
      final songModels = await Future.wait(tracks.map((t) async {
        final predictedPath = await _smartService.getPredictedCachePath(t);
        return SongModel(
          title: t.title,
          artist: t.artist,
          album: widget.album.title,
          filePath: predictedPath,
          fileExtension: '.mp3',
          duration: t.durationSeconds.toDouble(),
          onlineArtUrl: widget.album.imageUrl,
          isrc: t.isrc,
          trackNumber: t.trackNumber,
          discNumber: t.discNumber,
          year: t.year,
          genre: t.genre,
        );
      }));

      if (mounted) {
        setState(() {
          _tracks = songModels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // NEW: Fetch Album Image if missing (Local -> Spotify)
  Future<void> _fetchAlbumImageIfNeeded() async {
    // If we already have a URL, we are good (unless it's empty)
    if (_headerImageUrl.isNotEmpty) return;

    // 1. Try Local Metadata FIRST
    if (widget.album.localSongs != null &&
        widget.album.localSongs!.isNotEmpty) {
      try {
        final firstSong = widget.album.localSongs!.first as SongModel;
        final file = File(firstSong.filePath);
        if (await file.exists()) {
          final metadata =
              await MetadataGod.readMetadata(file: firstSong.filePath);
          if (metadata.picture != null) {
            if (mounted) {
              setState(() {
                _localImageBytes = metadata.picture!.data;
                // We don't set _headerImageUrl here because we use bytes
              });
            }
            return; // Found local, done.
          }
        }
      } catch (e) {
        print("Error reading local metadata: $e");
      }
    }

    // 2. Try Spotify Fallback
    try {
      final query = "${widget.album.title} ${widget.album.artist}";
      final albums = await SpotifyService.searchAlbums(query);
      if (albums.isNotEmpty && albums.first.imageUrl.isNotEmpty) {
        if (mounted) {
          setState(() {
            _headerImageUrl = albums.first.imageUrl;
            // Update tracks with new image URL
            _tracks = _tracks
                .map((t) => t.copyWith(onlineArtUrl: _headerImageUrl))
                .toList();
          });
        }
      }
    } catch (e) {
      print("Error fetching album image: $e");
    }
  }

  Future<void> _extractColors() async {
    ImageProvider? imageProvider;

    if (_localImageBytes != null) {
      imageProvider = MemoryImage(_localImageBytes!);
    } else if (_headerImageUrl.isNotEmpty) {
      imageProvider = NetworkImage(_headerImageUrl);
    }

    if (imageProvider == null) return;

    try {
      final generator = await PaletteGenerator.fromImageProvider(
        imageProvider,
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

  Future<void> _fetchArtistImage() async {
    final url = await SpotifyService.getArtistImagetoAlbum(widget.album.artist);
    if (mounted && url != null) {
      setState(() => _artistImageUrl = url);
    }
  }

  Future<void> _playTrack(SongModel song) async {
    if (_loadingSongTitle != null) return;

    setState(() => _loadingSongTitle = song.title);

    try {
      final queue = List<SongModel>.from(_tracks);

      if (mounted) {
        await ref.read(playerProvider.notifier).playSong(
              song,
              newQueue: queue,
            );

        showCenterNotification(context,
            label: "PLAYING FROM ALBUM",
            title: song.title,
            subtitle: song.artist,
            artPath: song.filePath,
            onlineArtUrl: song.onlineArtUrl);
      }
    } catch (e) {
      _showError("Playback error: $e");
    } finally {
      if (mounted) setState(() => _loadingSongTitle = null);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final baseBg = Theme.of(context).scaffoldBackgroundColor;
    final accentColor = Theme.of(context).colorScheme.primary;

    // Determine Image Provider
    ImageProvider imageProvider;
    if (_localImageBytes != null) {
      imageProvider = MemoryImage(_localImageBytes!);
    } else if (_headerImageUrl.isNotEmpty) {
      imageProvider = NetworkImage(_headerImageUrl);
    } else {
      // Fallback placeholder
      imageProvider = const NetworkImage("https://via.placeholder.com/300");
    }

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
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
                  // --- ALBUM HEADER ---
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
                                image: imageProvider, // USE DYNAMIC PROVIDER
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
                                const Text("ALBUM",
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1)),
                                const SizedBox(height: 8),
                                Text(
                                  widget.album.title,
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
                                      backgroundColor: Colors.grey[800],
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
                                      onEnter: (_) => setState(
                                          () => _isArtistHovered = true),
                                      onExit: (_) => setState(
                                          () => _isArtistHovered = false),
                                      child: GestureDetector(
                                        onTap: () {
                                          ref
                                              .read(navigationStackProvider
                                                  .notifier)
                                              .push(
                                                NavigationItem(
                                                  type: NavigationType.artist,
                                                  data: ArtistSelection(
                                                      artistName:
                                                          widget.album.artist,
                                                      songs: <SongModel>[]),
                                                ),
                                              );
                                        },
                                        child: Text(widget.album.artist,
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
                                      " • ${widget.album.releaseDate.split('-').first} • ${_tracks.length} songs",
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 8),
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
                              onPressed: () {
                                if (_tracks.isNotEmpty) _playTrack(_tracks[0]);
                              },
                            ),
                          ),
                          const SizedBox(width: 24),

                          // 🚀 FAVORITE ALBUM BUTTON
                          Consumer(
                            builder: (context, ref, child) {
                              final playlists = ref.watch(playlistProvider);
                              final isFavorite = playlists
                                  .any((p) => p.name == widget.album.title);

                              return IconButton(
                                icon: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorite
                                      ? Colors.redAccent
                                      : textColor.withOpacity(0.7),
                                  size: 32,
                                ),
                                onPressed: () {
                                  final notifier =
                                      ref.read(playlistProvider.notifier);
                                  if (isFavorite) {
                                    // Remove
                                    final playlist = playlists.firstWhere(
                                        (p) => p.name == widget.album.title);
                                    notifier.deletePlaylist(playlist.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Album removed from playlists"),
                                          duration: Duration(seconds: 1)),
                                    );
                                  } else {
                                    // Add
                                    notifier.createPlaylist(widget.album.title);
                                    // We need to get the ID of the newly created playlist
                                    // Since createPlaylist is sync but state update might be async in riverpod?
                                    // Actually StateNotifier updates are immediate.
                                    final newPlaylists =
                                        ref.read(playlistProvider);
                                    final newPlaylist = newPlaylists.firstWhere(
                                        (p) => p.name == widget.album.title);
                                    notifier.addSongsToPlaylist(
                                        newPlaylist.id, _tracks);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text("Album added to playlists"),
                                          duration: Duration(seconds: 1)),
                                    );
                                  }
                                },
                              );
                            },
                          ),

                          const SizedBox(width: 24),

                          // 🚀 DOWNLOAD ALL BUTTON
                          IconButton(
                            icon: Icon(Icons.download_rounded,
                                color: textColor.withOpacity(0.7), size: 32),
                            tooltip: "Download All",
                            onPressed: () {
                              BulkDownloadService()
                                  .downloadAlbum(widget.album.title, _tracks);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content:
                                    Text("Started downloading all songs..."),
                                duration: Duration(seconds: 2),
                              ));
                            },
                          ),

                          const SizedBox(width: 24),
                          Icon(Icons.more_horiz,
                              color: textColor.withOpacity(0.7), size: 32),
                        ],
                      ),
                    ),
                  ),

                  // --- TRACK LIST ---
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = _tracks[index];
                        final isThisLoading = _loadingSongTitle == song.title;

                        // 🎵 Check if this song is currently playing
                        final playerState = ref.watch(playerProvider);
                        final isNowPlaying = playerState.currentSong != null &&
                            playerState.currentSong!.title == song.title &&
                            playerState.currentSong!.artist == song.artist;

                        return SongContextMenuRegion(
                          song: song,
                          currentQueue: _tracks,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 0),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: isThisLoading
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
                                            color: isNowPlaying
                                                ? accentColor
                                                : textColor.withOpacity(0.5),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Album art with play/pause overlay
                                SongCardOverlay(
                                  song: song,
                                  size: 40,
                                  radius: 4,
                                  playQueue: _tracks,
                                ),
                              ],
                            ),
                            title: Text(song.title,
                                style: TextStyle(
                                    color: isNowPlaying
                                        ? accentColor
                                        : (isThisLoading
                                            ? accentColor
                                            : textColor),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(song.artist,
                                style: TextStyle(
                                    color: isNowPlaying
                                        ? accentColor.withOpacity(0.7)
                                        : textColor.withOpacity(0.6),
                                    fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${song.duration.toInt() ~/ 60}:${(song.duration.toInt() % 60).toString().padLeft(2, '0')}",
                                  style: TextStyle(
                                      color: textColor.withOpacity(0.6),
                                      fontSize: 13),
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
                            onTap: () => _playTrack(song),
                          ),
                        );
                      },
                      childCount: _tracks.length,
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 160)),
                ],
              ),
            ),
    );
  }
}
