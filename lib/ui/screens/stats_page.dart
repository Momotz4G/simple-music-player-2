import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/stats_utils.dart';

// --- IMPORTS ---
import '../../providers/stats_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/library_presentation_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../models/song_model.dart';
import '../../models/stat_model.dart'; // REQUIRED for ID generation
import '../../services/spotify_service.dart';
import '../components/smart_art.dart';
import '../components/shareable_stats_card.dart';
import '../../services/vps_scraper_service.dart';
import '../../services/db_service.dart';
import '../../services/sync_engine.dart';
import 'artists_page.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/profile_provider.dart';
import '../components/profile_dialog.dart';

class _SlideData {
  final String label;
  final String mainText;
  final String subText;
  final String artistName;
  final int count;
  final SongModel? sourceSong;

  _SlideData({
    required this.label,
    required this.mainText,
    required this.subText,
    required this.artistName,
    required this.count,
    this.sourceSong,
  });
}

// 🚀 Persist selected tab across widget rebuilds (survives navigation stack push/pop)
final statsTabProvider =
    StateProvider<int>((ref) => 0); // 0 = Songs, 1 = Artists

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  int _slideIndex = 0;
  Timer? _slideTimer;
  List<_SlideData> _slides = [];

  // Image cache for the banner
  final Map<String, String?> _imageCache = {};
  final Set<String> _pendingFetches = {};
  bool _isRateLimited = false;
  bool _preferPrimarySpotify = false;

  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    // Reset tab to Songs whenever stats page is freshly opened
    Future.microtask(() => ref.read(statsTabProvider.notifier).state = 0);

    // 🚀 Refresh cloud stats on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(profileProvider.notifier).refreshAvatarFromCloud();
        // Pull latest per-song stats from cloud so other devices' plays appear
        SyncEngine().pullAndMerge();
      }
    });

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
  void _handleSongTap(SongModel song) {
    ref.read(playerProvider.notifier).playSong(song);
  }

  // ... Helpers ...

  Future<void> _shareStats(SongModel song, int count,
      {String header = "", ImageProvider? overrideImage}) async {
    final l10n = AppLocalizations.of(context)!;
    final cardWidget = ShareableStatsCard(
      song: song,
      playCount: count,
      headerText: header.isNotEmpty ? header : l10n.mostListened.toUpperCase(),
      totalPlaysLabel: l10n.totalPlays,
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
                      label: Text(AppLocalizations.of(context)!.close),
                      icon: const Icon(Icons.close),
                      backgroundColor: Colors.grey[800],
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton.extended(
                      heroTag: "share_action",
                      label: Text(AppLocalizations.of(context)!.share),
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

                            if (mounted && image != null) {
                              final l10n = AppLocalizations.of(context)!;
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(context);
                              messenger.showSnackBar(
                                SnackBar(content: Text(l10n.savedTo(filePath))),
                              );
                              navigator.pop();
                              await Share.shareXFiles(
                                [XFile(filePath, mimeType: 'image/png')],
                                text: l10n.myTopTrackOn(header),
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
    // 🚀 Refresh stats whenever navigating back to this tab (handles IndexedStack caching)
    ref.listen(libraryPresentationProvider, (previous, next) {
      if (next == LibraryView.stats && previous != LibraryView.stats) {
        ref.read(profileProvider.notifier).refreshAvatarFromCloud();
      }
    });

    final statsState = ref.watch(statsProvider);
    final profileState = ref.watch(profileProvider);
    final calculated = StatsUtils.calculate(statsState);

    // 🚀 UNIFIED CLOUD COMBINATION
    final totalMinutes =
        calculated.totalMinutes > (profileState.cloudTotalMinutes ?? 0)
            ? calculated.totalMinutes
            : (profileState.cloudTotalMinutes ?? 0);
    final totalPlays =
        calculated.totalPlays > (profileState.cloudTotalPlays ?? 0)
            ? calculated.totalPlays
            : (profileState.cloudTotalPlays ?? 0);

    final cloudTotalPlays = profileState.cloudTotalPlays ?? 0;
    final topArtistName = profileState.cloudTopArtist != null &&
            profileState.cloudTopArtist!.isNotEmpty
        ? profileState.cloudTopArtist!
        : calculated.topArtist?.key;

    final topTrackName = profileState.cloudTopTrack != null &&
            profileState.cloudTopTrack!.isNotEmpty
        ? profileState.cloudTopTrack!
        : calculated.topTrack?.key;

    // Slides Logic
    final List<_SlideData> newSlides = [];

    if (topArtistName != null) {
      final artist = topArtistName;
      // 🚀 BETTER LOOKUP: Try to find local plays for this specific artist
      final localPlays = statsState.entries.values
          .where((e) => e.artist == artist)
          .fold(0, (sum, e) => sum + e.playCount);

      final library = ref.read(libraryProvider);
      final artistFallbackSong = library.songs.firstWhere(
          (s) => s.artist == artist,
          orElse: () => SongModel(
              title: "",
              artist: artist,
              album: "",
              filePath: "",
              duration: 0,
              fileExtension: ""));

      // 🚀 PRIORITIZE CLOUD: Compare local plays vs cloud top item plays
      final cloudPlays = profileState.cloudTopArtistPlays ?? 0;
      final finalPlays = (cloudPlays > localPlays)
          ? cloudPlays
          : (localPlays > 0 ? localPlays : 0);

      newSlides.add(_SlideData(
        label: AppLocalizations.of(context)!.topArtist,
        mainText: artist,
        subText: finalPlays > 0
            ? "$finalPlays ${finalPlays == 1 ? AppLocalizations.of(context)!.play : AppLocalizations.of(context)!.plays}"
            : "All-Time Favorite",
        artistName: artist,
        count: finalPlays,
        sourceSong:
            artistFallbackSong.filePath.isNotEmpty ? artistFallbackSong : null,
      ));
    }

    if (topTrackName != null) {
      final trackName = topTrackName;
      // 🚀 BETTER LOOKUP: Try to find local plays for this specific track
      final localCount = statsState.entries.values
          .where((e) => e.title == trackName)
          .fold(0, (sum, e) => sum + e.playCount);

      // 🚀 PRIORITIZE CLOUD: Compare local plays vs cloud top item plays
      final cloudCount = profileState.cloudMostListenedPlays ?? 0;
      final finalCount = (cloudCount > localCount)
          ? cloudCount
          : (localCount > 0 ? localCount : 0);

      final library = ref.read(libraryProvider);
      final trackFallbackSong = library.songs.firstWhere(
          (s) => s.title == trackName,
          orElse: () => SongModel(
              title: trackName,
              artist: topArtistName ?? "Unknown",
              album: "",
              filePath: "",
              duration: 0,
              fileExtension: ""));

      newSlides.add(_SlideData(
        label: AppLocalizations.of(context)!.mostListened,
        mainText: trackName,
        subText: finalCount > 0
            ? "$finalCount ${finalCount == 1 ? AppLocalizations.of(context)!.play : AppLocalizations.of(context)!.plays}"
            : "All-Time Favorite",
        artistName: topArtistName ?? "Unknown",
        count: finalCount,
        sourceSong: (trackFallbackSong.filePath.isNotEmpty ||
                trackFallbackSong.onlineArtUrl != null)
            ? trackFallbackSong
            : null,
      ));
    }

    _slides = newSlides;

    // 🚀 RESTORE: Trigger metadata backfill for songs being displayed
    // This happens after the frame to avoid build-phase side effects
    if (statsState.entries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // 🚀 Priority 1: Slide metadata (Top Artist / Top Track images)
        final slideSongs = newSlides
            .where((s) => s.sourceSong != null)
            .map((s) => s.sourceSong!)
            .toList();

        // 🚀 Priority 2: Fetch Top Artist Image specifically
        if (topArtistName != null) {
          _fetchArtistImageSafely(topArtistName);
        }

        // Start background backfill
        _backfillMetadata(slideSongs);

        // 🚀 NEW: Artist Tab Backfill
        if (ref.read(statsTabProvider) == 1 &&
            calculated.sortedArtists.isNotEmpty) {
          final topArtists =
              calculated.sortedArtists.map((e) => e.key).toList();
          _backfillArtistMetadata(topArtists);
        }
      });
    }

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
        final file = File(currentSlide.sourceSong!.filePath);
        if (file.existsSync()) {
          bgImageProvider = FileImage(file);
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
            actions: [
              IconButton(
                icon:
                    const Icon(Icons.emoji_events_rounded, color: Colors.amber),
                tooltip: AppLocalizations.of(context)!.globalLeaderboard,
                onPressed: () {
                  final profileState = ref.read(profileProvider);
                  if (profileState.customNickname == null ||
                      profileState.customNickname!.trim().isEmpty) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: Text(
                            AppLocalizations.of(context)!.nicknameRequired),
                        content: Text(
                            AppLocalizations.of(context)!.nicknameRequiredDesc),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(AppLocalizations.of(context)!.close),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                barrierColor:
                                    Colors.black.withValues(alpha: 0.3),
                                builder: (context) => const ProfileDialog(),
                              );
                            },
                            child:
                                Text(AppLocalizations.of(context)!.openProfile),
                          ),
                        ],
                      ),
                    );
                  } else {
                    ref
                        .read(libraryPresentationProvider.notifier)
                        .setView(LibraryView.leaderboard);
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(AppLocalizations.of(context)!.listeningStats),
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
                              .withValues(alpha: 0.8),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenW = constraints.maxWidth;
                      final gap = screenW < 400 ? 12.0 : 32.0;
                      final hPad = screenW < 400 ? 16.0 : 32.0;
                      return Container(
                        padding: EdgeInsets.only(
                            right: hPad, left: hPad, bottom: 70, top: 100),
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
                                          Shadow(
                                              blurRadius: 4,
                                              color: Colors.black)
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currentSlide.mainText,
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontSize: screenW < 400 ? 22 : 28,
                                        fontWeight: FontWeight.bold,
                                        color: const Color.fromRGBO(
                                            255, 215, 0, 1),
                                        shadows: const [
                                          Shadow(
                                              blurRadius: 10,
                                              color: Colors.black)
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            currentSlide.subText,
                                            overflow: TextOverflow.ellipsis,
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
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8.0),
                                          child: IconButton(
                                            icon: const Icon(Icons.share,
                                                color: Colors.white, size: 20),
                                            onPressed: () async {
                                              if (currentSlide == null) return;

                                              final isArtist = currentSlide
                                                      .label ==
                                                  AppLocalizations.of(context)!
                                                      .topArtist;
                                              String? fetchedArtUrl =
                                                  currentSlide
                                                      .sourceSong?.onlineArtUrl;

                                              // 🚀 SMART FALLBACK: If art is missing OR the local file was deleted (cache cleared)
                                              bool needsArt =
                                                  fetchedArtUrl == null ||
                                                      fetchedArtUrl.isEmpty;
                                              if (needsArt &&
                                                  !isArtist &&
                                                  currentSlide.sourceSong
                                                          ?.filePath !=
                                                      null &&
                                                  currentSlide.sourceSong!
                                                      .filePath.isNotEmpty) {
                                                final file = File(currentSlide
                                                    .sourceSong!.filePath);
                                                if (!await file.exists()) {
                                                  // File is gone (cache cleared), we definitely need to fetch online
                                                  needsArt = true;
                                                } else {
                                                  // File exists, SmartArt will handle it
                                                  needsArt = false;
                                                }
                                              }

                                              if (!isArtist && needsArt) {
                                                debugPrint(
                                                    "🔍 Share: Art missing or cache cleared, fetching from Spotify...");
                                                fetchedArtUrl = await SpotifyService
                                                    .getTrackImage(
                                                        currentSlide.mainText,
                                                        currentSlide.artistName,
                                                        preferPrimary:
                                                            _preferPrimarySpotify);
                                              }

                                              ImageProvider? shareImage;
                                              if (isArtist) {
                                                // 🚀 ALWAYS use the square profile image for the share card
                                                String? profileUrl =
                                                    await DBService().getArtCache(
                                                        "profile:${currentSlide.artistName}");

                                                if (profileUrl == null ||
                                                    profileUrl.isEmpty) {
                                                  // ⚡ Proactively fetch from Spotify as backup if missing from cache
                                                  profileUrl =
                                                      await SpotifyService
                                                          .getArtistImage(
                                                              artistName:
                                                                  currentSlide
                                                                      .artistName,
                                                              highQuality:
                                                                  true);
                                                }

                                                if (profileUrl != null &&
                                                    profileUrl.isNotEmpty) {
                                                  shareImage =
                                                      NetworkImage(profileUrl);
                                                }
                                              }

                                              final shareObj = SongModel(
                                                title: currentSlide.mainText,
                                                artist: isArtist
                                                    ? "Most Listened Artist"
                                                    : currentSlide.artistName,
                                                album: isArtist
                                                    ? "All Time"
                                                    : "Most Listened Track",
                                                filePath: currentSlide
                                                        .sourceSong?.filePath ??
                                                    "",
                                                onlineArtUrl: fetchedArtUrl,
                                                duration: 0,
                                                fileExtension: "",
                                              );

                                              _shareStats(
                                                shareObj,
                                                currentSlide.count,
                                                header: currentSlide.label
                                                    .toUpperCase(),
                                                overrideImage: isArtist
                                                    ? shareImage
                                                    : null,
                                              );
                                            },
                                          ),
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(width: gap),
                            _buildStatColumn(
                                AppLocalizations.of(context)!.timeListened,
                                "$totalMinutes",
                                AppLocalizations.of(context)!.minutes,
                                accentColor),
                            SizedBox(width: gap),
                            _buildStatColumn(
                                AppLocalizations.of(context)!.totalPlays,
                                "$totalPlays",
                                AppLocalizations.of(context)!.tracks,
                                Colors.white),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // 🚀 TAB SWITCHER (Songs / Artists) - Unified n-shape design
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: _buildUnifiedTabs(accentColor),
            ),
          ),
          // 🚀 CONDITIONAL CONTENT: Songs tab vs Artists tab
          if (ref.watch(statsTabProvider) == 0) ...[
            // --- SONGS TAB ---
            Builder(builder: (context) {
              final songsList = statsState.entries.values
                  .where((e) => e.playCount > 0)
                  .toList()
                ..sort((a, b) {
                  int cmp = b.playCount.compareTo(a.playCount);
                  if (cmp != 0) return cmp;
                  return b.totalSeconds.compareTo(a.totalSeconds);
                });

              if (songsList.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                      child: Text(AppLocalizations.of(context)!.noStatsYet,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold))),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final entry = songsList[index];
                  final count = entry.playCount;

                  // Create ephemeral song model for the list
                  final song = SongModel(
                    title: entry.title,
                    artist: entry.artist,
                    album: entry.album,
                    filePath: entry.lastKnownPath,
                    onlineArtUrl: entry.onlineArtUrl,
                    duration: 0,
                    fileExtension: "",
                  );

                  Color? rankColor;
                  if (index == 0) rankColor = const Color(0xFFFFD700);
                  if (index == 1) rankColor = const Color(0xFFC0C0C0);
                  if (index == 2) rankColor = const Color(0xFFCD7F32);

                  final screenWidth = MediaQuery.of(context).size.width;
                  final leadingW = screenWidth < 400 ? 80.0 : 100.0;
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: screenWidth < 400 ? 16 : 24, vertical: 4),
                    leading: SizedBox(
                      width: leadingW,
                      child: Row(
                        children: [
                          SizedBox(
                            width: screenWidth < 400 ? 28 : 40,
                            child: Text("#${index + 1}",
                                style: TextStyle(
                                    fontSize: screenWidth < 400 ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: rankColor ?? Colors.grey),
                                textAlign: TextAlign.center),
                          ),
                          const SizedBox(width: 8),
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
                    subtitle: Text(song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12)),
                    trailing: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: screenWidth < 400 ? 120 : 160),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                  "$count ${count == 1 ? AppLocalizations.of(context)!.play : AppLocalizations.of(context)!.plays}",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: accentColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ),
                          SizedBox(width: screenWidth < 400 ? 2 : 8),
                          IconButton(
                            icon: Icon(Icons.ios_share,
                                size: 18, color: Colors.grey[600]),
                            tooltip: AppLocalizations.of(context)!.share,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            onPressed: () => _shareStats(song, count,
                                header: AppLocalizations.of(context)!
                                    .mostListened
                                    .toUpperCase()),
                          )
                        ],
                      ),
                    ),
                    onTap: () => _handleSongTap(song),
                  );
                },
                    childCount:
                        (songsList.length > 100) ? 100 : songsList.length),
              );
            }),
          ] else ...[
            // --- ARTISTS TAB ---
            if (calculated.sortedArtists.isEmpty)
              SliverFillRemaining(
                child: Center(
                    child: Text(AppLocalizations.of(context)!.noArtistStatsYet,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold))),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final entry = calculated.sortedArtists[index];
                  final artistName = entry.key;
                  final playCount = entry.value;

                  Color? rankColor;
                  if (index == 0) rankColor = const Color(0xFFFFD700);
                  if (index == 1) rankColor = const Color(0xFFC0C0C0);
                  if (index == 2) rankColor = const Color(0xFFCD7F32);

                  final screenWidth = MediaQuery.of(context).size.width;
                  final leadingW = screenWidth < 400 ? 80.0 : 100.0;
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: screenWidth < 400 ? 16 : 24, vertical: 4),
                    leading: SizedBox(
                      width: leadingW,
                      child: Row(
                        children: [
                          // ... same avatar logic ...
                          SizedBox(
                            width: screenWidth < 400 ? 28 : 40,
                            child: Text("#${index + 1}",
                                style: TextStyle(
                                    fontSize: screenWidth < 400 ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: rankColor ?? Colors.grey),
                                textAlign: TextAlign.center),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                              width: 40,
                              height: 40,
                              child: ArtistAvatar(artistName: artistName)),
                        ],
                      ),
                    ),
                    title: Text(artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        "$playCount ${playCount == 1 ? AppLocalizations.of(context)!.play : AppLocalizations.of(context)!.plays}",
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          "${calculated.artistMinutes[artistName] ?? 0} ${AppLocalizations.of(context)!.min}",
                          style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                    onTap: () {
                      ref.read(navigationStackProvider.notifier).push(
                            NavigationItem(
                              type: NavigationType.artist,
                              data: ArtistSelection(artistName: artistName),
                            ),
                          );
                    },
                  );
                }, childCount: calculated.sortedArtists.length),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  // 🚀 UNIFIED TAB SWITCHER (animated)
  Widget _buildUnifiedTabs(Color accentColor) {
    final selectedTab = ref.watch(statsTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.15);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final highlightColor = Colors.white.withValues(alpha: isDark ? 0.07 : 0.5);

    Widget buildTab(int index, String label) {
      final isSelected = selectedTab == index;
      final radius = BorderRadius.only(
        topLeft: index == 0 ? const Radius.circular(11) : Radius.zero,
        topRight: index == 1 ? const Radius.circular(11) : Radius.zero,
      );

      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => ref.read(statsTabProvider.notifier).state = index,
          hoverColor: Colors.white.withValues(alpha: isDark ? 0.05 : 0.15),
          splashColor: Colors.white.withValues(alpha: isDark ? 0.1 : 0.2),
          borderRadius: radius,
          mouseCursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? highlightColor : Colors.transparent,
              borderRadius: radius,
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? accentColor
                    : (isDark ? Colors.grey[500]! : Colors.grey[500]!),
              ),
              child: Text(label),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 1.0),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildTab(0, AppLocalizations.of(context)!.songs),
                    // Middle divider
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: borderColor,
                    ),
                    buildTab(1, AppLocalizations.of(context)!.artists),
                  ],
                ),
              ),
            ),
            // Cover bottom border
            Positioned(
              bottom: 0,
              left: 1,
              right: 1,
              child: Container(height: 1.5, color: bgColor),
            ),
          ],
        ),
      ],
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

  final Set<String> _processedBackfill = {};

  // 🚀 Global lock to prevent overlapping backfill floods
  static bool _isBackfilling = false;

  static DateTime? _rateLimitExpiry;

  /// Fallback art fetcher using YouTube Music API.
  /// Called when Spotify returns null or errors (5xx).
  Future<String?> _fetchArtFromYtMusic(String title, String artist) async {
    try {
      final query = Uri.encodeComponent('$title $artist');
      final url = Uri.parse(
          'https://ytmusic-api-omega.vercel.app/api/search?q=$query&limit=1');
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return null;
      final body = json.decode(response.body);
      if (body['success'] != true || body['data'] == null) return null;

      final results = body['data'] as List<dynamic>;
      if (results.isEmpty) return null;

      final thumbnails = results.first['thumbnails'] as List<dynamic>? ?? [];
      if (thumbnails.isEmpty) return null;

      final artUrl = thumbnails.last['url'] as String?;
      if (artUrl != null && artUrl.isNotEmpty) {
        debugPrint("✅ YT Music fallback art for '$title' → $artUrl");
      }
      return (artUrl != null && artUrl.isNotEmpty) ? artUrl : null;
    } catch (e) {
      debugPrint("⚠️ YT Music art fallback failed: $e");
      return null;
    }
  }

  Future<void> _backfillMetadata(List<SongModel> songs) async {
    if (_isBackfilling) return;

    // 🚀 Global API Cooldown (5 Minutes Hard Lock)
    if (_rateLimitExpiry != null) {
      if (DateTime.now().isBefore(_rateLimitExpiry!)) {
        return; // Still cooling down, don't even try.
      } else {
        _rateLimitExpiry = null;
        _isRateLimited = false;
      }
    }

    _isBackfilling = true;
    _isRateLimited = false;

    try {
      // 🚀 PHASE 1: Priority Backfill for slides (Top Artist / Top Track)
      for (final song in songs) {
        if (!mounted || _isRateLimited) break;

        final id = StatEntry.generateId(song.title, song.artist, song.album);
        if (_processedBackfill.contains(id) || _pendingFetches.contains(id))
          continue;

        // Skip if already has art
        if (song.onlineArtUrl != null && song.onlineArtUrl!.isNotEmpty)
          continue;

        _processedBackfill.add(id);
        _pendingFetches.add(id);

        try {
          debugPrint("🚀 Priority backfill for top item: ${song.title}");
          String? artUrl = await SpotifyService.getTrackImage(
              song.title, song.artist,
              preferPrimary: _preferPrimarySpotify);
          String? youtubeUrl = await SpotifyService.getTrackLink(
              song.title, song.artist,
              preferPrimary: _preferPrimarySpotify);

          // Fallback: try YouTube Music if Spotify didn't return art
          if (artUrl == null || artUrl.isEmpty) {
            artUrl = await _fetchArtFromYtMusic(song.title, song.artist);
          }

          if (artUrl != null || youtubeUrl != null) {
            if (mounted) {
              ref
                  .read(statsProvider.notifier)
                  .updateMetadata(id, artUrl: artUrl, youtubeUrl: youtubeUrl);
            }
          }
        } catch (e) {
          if (e.toString().contains("rate_limit_429")) {
            if (!_preferPrimarySpotify) {
              debugPrint(
                  "⚠️ Secondary API rate limited during priority backfill. Falling back to Primary...");
              _preferPrimarySpotify = true;
              _isRateLimited = false;
              _processedBackfill.remove(id);
              continue;
            } else {
              debugPrint(
                  "⚠️ Primary API also rate limited. Cooling down for 5 mins...");
              _isRateLimited = true;
              _rateLimitExpiry = DateTime.now().add(const Duration(minutes: 5));
              break;
            }
          }
        } finally {
          _pendingFetches.remove(id);
        }

        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // 🚀 PHASE 2: Standard backfill for the rest of the list
      final fullList = ref.read(statsProvider).entries.values.toList();
      for (final entry in fullList) {
        if (!mounted || _isRateLimited) break;

        final id =
            StatEntry.generateId(entry.title, entry.artist, entry.album ?? "");
        if (_processedBackfill.contains(id) || _pendingFetches.contains(id))
          continue;

        // If already fully backfilled, skip
        if (entry.onlineArtUrl != null && entry.youtubeUrl != null) {
          _processedBackfill.add(id);
          continue;
        }

        _processedBackfill.add(id);
        _pendingFetches.add(id);

        try {
          String? artUrl = entry.onlineArtUrl;
          if (artUrl == null || artUrl.isEmpty) {
            artUrl = await SpotifyService.getTrackImage(
                entry.title, entry.artist,
                preferPrimary: _preferPrimarySpotify);
          }

          // Fallback: try YouTube Music if Spotify didn't return art
          if (artUrl == null || artUrl.isEmpty) {
            artUrl = await _fetchArtFromYtMusic(entry.title, entry.artist);
          }

          String? youtubeUrl = entry.youtubeUrl;
          if (youtubeUrl == null || youtubeUrl.isEmpty) {
            youtubeUrl = await SpotifyService.getTrackLink(
                entry.title, entry.artist,
                preferPrimary: _preferPrimarySpotify);
          }

          if (artUrl != null || youtubeUrl != null) {
            if (mounted) {
              ref
                  .read(statsProvider.notifier)
                  .updateMetadata(id, artUrl: artUrl, youtubeUrl: youtubeUrl);
            }
          }
        } catch (e) {
          if (e.toString().contains("rate_limit_429")) {
            if (!_preferPrimarySpotify) {
              debugPrint(
                  "⚠️ Secondary API rate limited during list backfill. Falling back to Primary...");
              _preferPrimarySpotify = true;
              _processedBackfill.remove(id);
              continue;
            } else {
              debugPrint("⚠️ Primary API also rate limited. Cooling down...");
              _isRateLimited = true;
              break;
            }
          }
        } finally {
          _pendingFetches.remove(id);
        }

        await Future.delayed(const Duration(milliseconds: 1200));
      }
    } finally {
      _isBackfilling = false;
    }
  }

  final Set<String> _processedArtistBackfill = {};

  Future<void> _backfillArtistMetadata(List<String> artistNames) async {
    if (_isBackfilling) return;

    // Reuse the same rate limit check from the main backfill
    if (_rateLimitExpiry != null && DateTime.now().isBefore(_rateLimitExpiry!))
      return;

    // 🚀 STEP 1: Identify "Newcomers" (Artists in Top 100 but missing from Cache)
    final List<String> newcomers = [];
    for (final artist in artistNames) {
      if (_processedArtistBackfill.contains(artist)) continue;

      final cacheKey = "profile:$artist";
      final cached = await DBService().getArtCache(cacheKey);

      if (cached == null || cached.isEmpty) {
        newcomers.add(artist);
      } else {
        _processedArtistBackfill.add(artist); // Already in cache, mark as done
      }
    }

    if (newcomers.isEmpty) return;

    _isBackfilling = true;
    try {
      debugPrint(
          "🔍 Stats: Found ${newcomers.length} newcomers in Top Artists list. Starting backfill...");

      for (final artist in newcomers) {
        if (!mounted || _isRateLimited) break;

        _processedArtistBackfill.add(artist);

        try {
          debugPrint("🚀 Fetching profile for newcomer: $artist");
          final img = await SpotifyService.getArtistImage(
              artistName: artist,
              highQuality: true,
              preferPrimary: _preferPrimarySpotify);

          if (img != null) {
            // Save to Isar for all pages to use
            await DBService().saveArtCache("profile:$artist", img);
          }
        } catch (e) {
          if (e.toString().contains("rate_limit_429")) {
            _isRateLimited = true;
            _rateLimitExpiry = DateTime.now().add(const Duration(minutes: 5));
            break;
          }
        }

        // Polite delay between API calls
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    } finally {
      _isBackfilling = false;
    }
  }

  // Helper for artist images (Top Artist Slide) - Now uses high-res banners!
  Future<void> _fetchArtistImageSafely(String artist,
      {String? trackTitle}) async {
    final cacheKey =
        "banner:$artist"; // 🚀 Use the same key as Artist Detail Page
    if (_isRateLimited ||
        _pendingFetches.contains(cacheKey) ||
        _imageCache.containsKey(artist)) return;

    _pendingFetches.add(cacheKey);
    try {
      // 🚀 STEP 1: Check Local Cache First (Instant)
      final cached = await DBService().getArtCache(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _imageCache[artist] = cached;
          });
        }
        // Even if cached, we don't strictly need to re-fetch here to save VPS resources,
        // unless it's a very old fallback.
        return;
      }

      // 🚀 STEP 2: Fetch High-Res Banner from VPS
      final spotifyId = await SpotifyService.getArtistId(
          artistName: artist,
          trackTitle: trackTitle,
          preferPrimary: _preferPrimarySpotify);
      if (spotifyId != null) {
        final bannerData = await VpsScraperService.getArtistBanner(spotifyId);
        final bannerUrl = bannerData['banner'] ??
            bannerData['gallery'] ??
            bannerData['profile'];

        if (bannerUrl != null) {
          // Save to Isar for all pages to use
          await DBService().saveArtCache(cacheKey, bannerUrl);

          if (mounted) {
            setState(() {
              _imageCache[artist] = bannerUrl;
            });
          }
          return;
        }
      }

      // 🚀 STEP 3: Fallback to official Spotify API (Profile Pic)
      final img = await SpotifyService.getArtistImage(
          artistName: artist,
          trackTitle: trackTitle,
          highQuality: true,
          preferPrimary: _preferPrimarySpotify);
      if (mounted && img != null) {
        setState(() {
          _imageCache[artist] = img;
        });
        // Save as fallback
        await DBService().saveArtCache(cacheKey, img);
      }
    } catch (e) {
      if (e.toString().contains("rate_limit_429")) {
        if (!_preferPrimarySpotify) {
          _preferPrimarySpotify = true;
        } else {
          _isRateLimited = true;
        }
      }
    } finally {
      _pendingFetches.remove(cacheKey);
    }
  }
}
