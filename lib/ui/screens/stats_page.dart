import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

// --- IMPORTS ---
import '../../providers/stats_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/smart_download_service.dart';
import '../../models/song_model.dart';
import '../../models/song_metadata.dart';
import '../../models/youtube_search_result.dart';
import '../../models/stat_model.dart';
import '../../services/spotify_service.dart';
import '../components/smart_art.dart';
import '../components/shareable_stats_card.dart';
import '../components/music_notification.dart';

class _SlideData {
  final String label;
  final String mainText;
  final String subText;
  final String artistName;
  final SongModel? sourceSong;

  _SlideData({
    required this.label,
    required this.mainText,
    required this.subText,
    required this.artistName,
    this.sourceSong,
  });
}

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  int _slideIndex = 0;
  Timer? _slideTimer;
  List<_SlideData> _slides = [];

  final SmartDownloadService _smartService = SmartDownloadService();
  bool _isRestoring = false;

  // Image cache for the banner
  final Map<String, String?> _imageCache = {};

  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _slideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_slides.length > 1 && mounted) {
        setState(() {
          _slideIndex = (_slideIndex + 1) % _slides.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    super.dispose();
  }

  // SMART PLAY / RESTORE LOGIC
  Future<void> _handleSongTap(SongModel song) async {
    if (_isRestoring) return;

    final file = File(song.filePath);

    // 1. File Exists -> Play immediately
    if (await file.exists()) {
      ref.read(playerProvider.notifier).playSong(song);
      return;
    }

    // 2. File Missing -> Try to Restore via History Lookup OR Persisted URL
    // Stats entry only has the path, but History has the YouTube URL.
    final history = ref.read(historyProvider);
    String? restoreUrl = song.sourceUrl; // 🚀 Try Persisted URL First
    String? restoreArt = song.onlineArtUrl;

    if (restoreUrl == null) {
      try {
        // Find the most recent match in history
        final match = history.firstWhere((entry) =>
            entry.title == song.title && entry.artist == song.artist);
        restoreUrl = match.youtubeUrl;
        restoreArt = match.albumArtUrl;
      } catch (e) {
        // Not found in history
      }
    }

    if (restoreUrl == null || restoreUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File missing and not found in history.")),
      );
      return;
    }

    setState(() => _isRestoring = true);
    showCenterNotification(context,
        label: "RESTORING",
        title: song.title,
        subtitle: "Re-buffering...",
        artPath: restoreArt);

    try {
      final meta = SongMetadata(
        title: song.title,
        artist: song.artist,
        album: song.album,
        year: "",
        genre: "",
        durationSeconds: song.duration.toInt(),
        albumArtUrl: restoreArt ?? "",
        isrc: song.isrc,
      );

      // FIX: Perform Just-In-Time YouTube Search if URL is missing or invalid (Spotify)
      String finalUrl = restoreUrl;
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
        thumbnailUrl: restoreArt ?? "",
      );

      final streamingQuality = ref.read(settingsProvider).streamingQuality;
      final restoredSong = await _smartService.cacheAndPlay(
        video: ytResult,
        metadata: meta,
        onProgress: (_) {},
        streamingQuality: streamingQuality,
      );

      if (restoredSong != null && mounted) {
        ref.read(playerProvider.notifier).playSong(restoredSong);
        showCenterNotification(context,
            label: "NOW PLAYING",
            title: restoredSong.title,
            subtitle: restoredSong.artist,
            artPath: restoredSong.filePath,
            onlineArtUrl: restoredSong.onlineArtUrl);
      }
    } catch (e) {
      print("Stats Restore Failed: $e");
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  // ... Helpers ...
  void _showErrorPopup(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Flexible(
                child: Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white))),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFE53935).withOpacity(0.95),
        elevation: 6,
        margin: const EdgeInsets.only(bottom: 300, left: 80, right: 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _fetchArtistImageIfNeeded(String artistName, {String? trackTitle}) {
    if (_imageCache.containsKey(artistName)) return;
    _imageCache[artistName] = "";

    SpotifyService.getArtistId(artistName: artistName, trackTitle: trackTitle)
        .then((id) async {
      String? bannerUrl;
      String? fallbackUrl;

      if (id != null) {
        try {
          bannerUrl = await SpotifyService.getFreshBannerUrl(id);
        } catch (e) {}
      }

      if (bannerUrl == null) {
        fallbackUrl = await SpotifyService.getArtistImage(
            artistName: artistName, trackTitle: trackTitle, highQuality: true);
      }

      if (mounted) {
        if (bannerUrl != null || fallbackUrl != null) {
          setState(() => _imageCache[artistName] = bannerUrl ?? fallbackUrl);
        }
      }
    });
  }

  Future<void> _shareStats(SongModel song, int count,
      {String header = "MY TOP TRACK", ImageProvider? overrideImage}) async {
    final cardWidget = ShareableStatsCard(
      song: song,
      playCount: count,
      title: header,
      imageOverride: overrideImage,
    );

    await showDialog(
      context: context,
      builder: (context) {
        final double maxHeight = MediaQuery.of(context).size.height * 0.85;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: cardWidget,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: "close_share",
                      onPressed: () => Navigator.pop(context),
                      label: const Text("Close"),
                      icon: const Icon(Icons.close),
                      backgroundColor: Colors.grey[800],
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton.extended(
                      heroTag: "share_action",
                      label: const Text("Share"),
                      icon: const Icon(Icons.ios_share),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      onPressed: () async {
                        try {
                          final Uint8List? image =
                              await _screenshotController.captureFromWidget(
                            Material(
                              child: Container(
                                color: Colors.black,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(0),
                                  child: cardWidget,
                                ),
                              ),
                            ),
                            delay: const Duration(milliseconds: 500),
                            pixelRatio: 3.0,
                            context: context,
                          );

                          if (image != null) {
                            final dir =
                                await getApplicationDocumentsDirectory();
                            final timestamp =
                                DateTime.now().millisecondsSinceEpoch;
                            final fileName =
                                'simple_music_player_v2_$timestamp.png';
                            final filePath = path_lib.join(dir.path, fileName);
                            final file = File(filePath);
                            await file.writeAsBytes(image, flush: true);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Saved to "$filePath"')),
                              );
                              Navigator.pop(context);
                              await Share.shareXFiles(
                                [XFile(filePath, mimeType: 'image/png')],
                                text: "My $header on Simple Player! 🎵",
                              );
                            }
                          }
                        } catch (e) {
                          debugPrint("Error sharing stats: $e");
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsState = ref.watch(statsProvider);
    final library = ref.watch(libraryProvider); // Using watch is fine here
    final allSongs = library.songs;
    final result = _calculateStats(statsState, allSongs);

    // Slides Logic
    final List<_SlideData> newSlides = [];
    SongModel? artistFallbackSong;

    if (result.topArtistEntry != null) {
      final artist = result.topArtistEntry!.key;
      final plays = result.topArtistEntry!.value;

      artistFallbackSong = result.mostPlayed.firstWhere(
          (s) => s.artist == artist,
          orElse: () => result.mostPlayed.isNotEmpty
              ? result.mostPlayed[0]
              : SongModel(
                  title: "",
                  artist: "",
                  album: "",
                  filePath: "",
                  duration: 0,
                  fileExtension: ""));

      newSlides.add(_SlideData(
        label: "Top Artist",
        mainText: artist,
        subText: "$plays plays",
        artistName: artist,
        sourceSong:
            artistFallbackSong.filePath.isNotEmpty ? artistFallbackSong : null,
      ));
      _fetchArtistImageIfNeeded(artist, trackTitle: artistFallbackSong.title);
    }

    if (result.mostPlayed.isNotEmpty) {
      final song = result.mostPlayed[0];
      final id = StatEntry.generateId(song.title, song.artist, song.album);
      final count = statsState.entries[id]?.playCount ?? 0;

      newSlides.add(_SlideData(
        label: "Most Listened",
        mainText: song.title,
        subText: "$count plays",
        artistName: song.artist,
        sourceSong: song,
      ));
      _fetchArtistImageIfNeeded(song.artist, trackTitle: song.title);
    }

    _slides = newSlides;

    ImageProvider? bgImageProvider;
    _SlideData? currentSlide;
    if (_slides.isNotEmpty) {
      currentSlide = _slides[_slideIndex % _slides.length];
      final cachedUrl = _imageCache[currentSlide.artistName];

      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        bgImageProvider = NetworkImage(cachedUrl);
      } else if (currentSlide.sourceSong != null &&
          currentSlide.sourceSong!.filePath.isNotEmpty) {
        // Check if file exists to determine image source
        if (File(currentSlide.sourceSong!.filePath).existsSync()) {
          bgImageProvider = FileImage(File(currentSlide.sourceSong!.filePath));
        } else if (currentSlide.sourceSong!.onlineArtUrl != null) {
          bgImageProvider =
              NetworkImage(currentSlide.sourceSong!.onlineArtUrl!);
        }
      }
    }

    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320.0,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text("Listening Stats"),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1000),
                    child: Container(
                      key: ValueKey(currentSlide?.label ?? "bg"),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        image: bgImageProvider != null
                            ? DecorationImage(
                                image: bgImageProvider,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              )
                            : null,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Theme.of(context)
                              .scaffoldBackgroundColor
                              .withOpacity(0.8),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.only(right: 32, bottom: 70, top: 100),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (currentSlide != null)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currentSlide.label.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    shadows: const [
                                      Shadow(blurRadius: 4, color: Colors.black)
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentSlide.mainText,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromRGBO(255, 215, 0, 1),
                                    shadows: [
                                      Shadow(
                                          blurRadius: 10, color: Colors.black)
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currentSlide.subText,
                                      style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.bold,
                                        shadows: const [
                                          Shadow(
                                              blurRadius: 4,
                                              color: Colors.black)
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: IconButton(
                                        icon: const Icon(Icons.share,
                                            color: Colors.white, size: 20),
                                        onPressed: () {
                                          if (currentSlide!.label ==
                                              "Top Artist") {
                                            final artistShareObj = SongModel(
                                              title: result.topArtistEntry!.key,
                                              artist: "Most Listened Artist",
                                              album: "All Time",
                                              filePath: artistFallbackSong
                                                      ?.filePath ??
                                                  "",
                                              duration: 0,
                                              fileExtension: "",
                                            );
                                            _shareStats(artistShareObj,
                                                result.topArtistEntry!.value,
                                                header: "TOP ARTIST",
                                                overrideImage: bgImageProvider);
                                          } else {
                                            final song = result.mostPlayed[0];
                                            final id = StatEntry.generateId(
                                                song.title,
                                                song.artist,
                                                song.album);
                                            final count = statsState
                                                    .entries[id]?.playCount ??
                                                0;
                                            _shareStats(song, count,
                                                header: "TOP TRACK");
                                          }
                                        },
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 32),
                        _buildStatColumn("Time Listened",
                            "${result.totalMinutes}", "Minutes", accentColor),
                        const SizedBox(width: 32),
                        _buildStatColumn("Total Plays", "${result.totalPlays}",
                            "Tracks", Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (result.mostPlayed.isEmpty)
            const SliverFillRemaining(
              child: Center(
                  child: Text("No stats yet.",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final song = result.mostPlayed[index];
                final id =
                    StatEntry.generateId(song.title, song.artist, song.album);
                final count = statsState.entries[id]?.playCount ?? 0;

                // Check History for fallback URL if file missing
                // Note: We rely on _handleSongTap to do the actual restoration lookup

                Color? rankColor;
                if (index == 0) rankColor = const Color(0xFFFFD700);
                if (index == 1) rankColor = const Color(0xFFC0C0C0);
                if (index == 2) rankColor = const Color(0xFFCD7F32);

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  leading: SizedBox(
                    width: 100,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text("#${index + 1}",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: rankColor ?? Colors.grey),
                              textAlign: TextAlign.center),
                        ),
                        const SizedBox(width: 8),

                        // 🚀 HYBRID ART: SmartArt handles fallback internally now
                        SmartArt(
                          path: song.filePath,
                          size: 40,
                          borderRadius: 4,
                          onlineArtUrl: song.onlineArtUrl,
                        ),
                      ],
                    ),
                  ),
                  title: Text(song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),

                  // 🚀 CLEAN SUBTITLE: No Badges, just Artist
                  subtitle: Text(song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 12)),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text("$count plays",
                            style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.ios_share,
                            size: 18, color: Colors.grey[600]),
                        tooltip: "Share",
                        onPressed: () =>
                            _shareStats(song, count, header: "TOP TRACK"),
                      )
                    ],
                  ),
                  // SMART TAP: Plays if exists, Restores if missing
                  onTap: () => _handleSongTap(song),
                );
              }, childCount: result.mostPlayed.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
      String label, String value, String subLabel, Color valueColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black)])),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: valueColor,
                height: 1.0,
                shadows: const [Shadow(blurRadius: 10, color: Colors.black)])),
        Text(subLabel,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
      ],
    );
  }

  _StatsResult _calculateStats(StatsState stats, List<SongModel> librarySongs) {
    if (stats.entries.isEmpty) return _StatsResult.empty();

    final Map<String, SongModel> libraryMap = {};
    for (var song in librarySongs) {
      final id = StatEntry.generateId(song.title, song.artist, song.album);
      libraryMap[id] = song;
    }

    List<SongModel> displayList = [];
    int totalPlays = 0;
    int totalSeconds = 0;
    Map<String, int> artistCounts = {};

    // We need to read history to get metadata for missing files
    // But we can't read provider asynchronously inside this synchronous method.
    // So we rely on the fact that StatEntry contains basic info (title, artist),
    // and we will try to find the rest later during render or tap.

    for (var entry in stats.entries.values) {
      totalSeconds += entry.totalSeconds;
      totalPlays += entry.playCount;

      if (entry.playCount > 0) {
        final artist = entry.artist.isEmpty ? "Unknown" : entry.artist;
        artistCounts[artist] = (artistCounts[artist] ?? 0) + entry.playCount;

        if (libraryMap.containsKey(entry.id)) {
          displayList.add(libraryMap[entry.id]!);
        } else {
          // Create model from StatEntry (might be missing URL here, resolved on Tap)
          displayList.add(SongModel(
            title: entry.title,
            artist: entry.artist,
            album: entry.album,
            filePath: entry.lastKnownPath,
            fileExtension: path_lib.extension(entry.lastKnownPath),
            duration: 0,
            onlineArtUrl: entry.onlineArtUrl,
            sourceUrl: entry.youtubeUrl,
          ));
        }
      }
    }

    displayList.sort((a, b) {
      final idA = StatEntry.generateId(a.title, a.artist, a.album);
      final idB = StatEntry.generateId(b.title, b.artist, b.album);
      final countA = stats.entries[idA]?.playCount ?? 0;
      final countB = stats.entries[idB]?.playCount ?? 0;
      return countB.compareTo(countA);
    });

    if (displayList.length > 100) {
      displayList = displayList.sublist(0, 100);
    }

    MapEntry<String, int>? topArtist;
    if (artistCounts.isNotEmpty) {
      final sorted = artistCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topArtist = sorted.first;
    }

    // BACKFILL METADATA (If missing)
    _backfillMetadata(displayList);

    return _StatsResult(
      mostPlayed: displayList,
      totalMinutes: (totalSeconds / 60).floor(),
      totalPlays: totalPlays,
      topArtistEntry: topArtist,
    );
  }

  final Set<String> _processedBackfill = {};

  Future<void> _backfillMetadata(List<SongModel> songs) async {
    for (var song in songs) {
      // If we already have metadata, skip
      if (song.onlineArtUrl != null && song.sourceUrl != null) continue;

      // If file exists, we might not need online metadata immediately,
      // but it's good to have for the future.
      // Let's prioritize items where file is MISSING.
      final fileExists = File(song.filePath).existsSync();
      if (fileExists && song.onlineArtUrl == null) {
        // Optional: Fetch for local files too?
        // For now, let's focus on missing files or missing art
      }

      final id = StatEntry.generateId(song.title, song.artist, song.album);
      if (_processedBackfill.contains(id)) continue;
      _processedBackfill.add(id);

      // Run in background
      Future.delayed(Duration.zero, () async {
        try {
          // 1. Fetch Art
          String? artUrl = song.onlineArtUrl;
          if (artUrl == null) {
            artUrl =
                await SpotifyService.getTrackImage(song.title, song.artist);
          }

          // 2. Fetch URL
          String? youtubeUrl = song.sourceUrl;
          if (youtubeUrl == null) {
            // We can use Spotify Link or search YouTube.
            // For now, let's just get Spotify Link as a placeholder or leave null
            // The 'SmartDownloadService' usually needs a YouTube URL.
            // But 'SpotifyService' gives us Spotify Metadata.
            // We can try to get the Spotify Track URL.
            youtubeUrl =
                await SpotifyService.getTrackLink(song.title, song.artist);
          }

          if (artUrl != null || youtubeUrl != null) {
            if (mounted) {
              ref
                  .read(statsProvider.notifier)
                  .updateMetadata(id, artUrl: artUrl, youtubeUrl: youtubeUrl);
            }
          }
        } catch (e) {
          print("Backfill failed for ${song.title}: $e");
        }
      });
    }
  }
}

class _StatsResult {
  final List<SongModel> mostPlayed;
  final int totalMinutes;
  final int totalPlays;
  final MapEntry<String, int>? topArtistEntry;

  _StatsResult(
      {required this.mostPlayed,
      required this.totalMinutes,
      required this.totalPlays,
      this.topArtistEntry});
  factory _StatsResult.empty() => _StatsResult(
      mostPlayed: [], totalMinutes: 0, totalPlays: 0, topArtistEntry: null);
}
