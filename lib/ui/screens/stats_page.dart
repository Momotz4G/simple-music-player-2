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
import '../../providers/search_bridge_provider.dart';
import '../../models/song_model.dart';
import '../../models/stat_model.dart'; // REQUIRED for ID generation
import '../../services/spotify_service.dart';
import '../components/smart_art.dart';
import '../components/shareable_stats_card.dart';
import 'artists_page.dart';
import '../../l10n/app_localizations.dart';

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
  Timer? _slideTimer = null;
  List<_SlideData> _slides = [];

  // Image cache for the banner
  final Map<String, String?> _imageCache = {};

  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    // Reset tab to Songs whenever stats page is freshly opened
    Future.microtask(() => ref.read(statsTabProvider.notifier).state = 0);
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
        backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.95),
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
      {String header = "", ImageProvider? overrideImage}) async {
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

                            if (mounted) {
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
        label: AppLocalizations.of(context)!.topArtist,
        mainText: artist,
        subText:
            "$plays ${plays == 1 ? AppLocalizations.of(context)!.play : AppLocalizations.of(context)!.plays}",
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
        label: AppLocalizations.of(context)!.mostListened,
        mainText: song.title,
        subText:
            "$count ${count == 1 ? AppLocalizations.of(context)!.play : AppLocalizations.of(context)!.plays}",
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
                                            onPressed: () {
                                              if (currentSlide!.label ==
                                                  "Top Artist") {
                                                final artistShareObj =
                                                    SongModel(
                                                  title: result
                                                      .topArtistEntry!.key,
                                                  artist:
                                                      "Most Listened Artist",
                                                  album: "All Time",
                                                  filePath: artistFallbackSong
                                                          ?.filePath ??
                                                      "",
                                                  duration: 0,
                                                  fileExtension: "",
                                                );
                                                _shareStats(
                                                    artistShareObj,
                                                    result
                                                        .topArtistEntry!.value,
                                                    header: AppLocalizations.of(
                                                            context)!
                                                        .topArtist,
                                                    overrideImage:
                                                        bgImageProvider);
                                              } else {
                                                final song =
                                                    result.mostPlayed[0];
                                                final id = StatEntry.generateId(
                                                    song.title,
                                                    song.artist,
                                                    song.album);
                                                final count = statsState
                                                        .entries[id]
                                                        ?.playCount ??
                                                    0;
                                                _shareStats(song, count,
                                                    header: AppLocalizations.of(
                                                            context)!
                                                        .mostListened);
                                              }
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
                                "${result.totalMinutes}",
                                AppLocalizations.of(context)!.minutes,
                                accentColor),
                            SizedBox(width: gap),
                            _buildStatColumn(
                                AppLocalizations.of(context)!.totalPlays,
                                "${result.totalPlays}",
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
            if (result.mostPlayed.isEmpty)
              SliverFillRemaining(
                child: Center(
                    child: Text(AppLocalizations.of(context)!.noStatsYet,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold))),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = result.mostPlayed[index];
                  final id =
                      StatEntry.generateId(song.title, song.artist, song.album);
                  final count = statsState.entries[id]?.playCount ?? 0;

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
                                  color: accentColor.withOpacity(0.1),
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
                }, childCount: result.mostPlayed.length),
              ),
          ] else ...[
            // --- ARTISTS TAB ---
            if (result.sortedArtists.isEmpty)
              SliverFillRemaining(
                child: Center(
                    child: Text(AppLocalizations.of(context)!.noArtistStatsYet,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold))),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final entry = result.sortedArtists[index];
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
                          // Artist avatar with Spotify image
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: ArtistAvatar(
                              artistName: artistName,
                            ),
                          ),
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
                          "${result.artistMinutes[artistName] ?? 0} ${AppLocalizations.of(context)!.min}",
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
                }, childCount: result.sortedArtists.length),
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
    Map<String, int> artistSeconds = {};

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
        artistSeconds[artist] =
            (artistSeconds[artist] ?? 0) + entry.totalSeconds;

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

    // Sort all artists by minutes listened (descending)
    final sortedArtistList = artistCounts.entries.toList()
      ..sort((a, b) {
        final secA = artistSeconds[a.key] ?? 0;
        final secB = artistSeconds[b.key] ?? 0;
        final timeDiff = secB.compareTo(secA);
        if (timeDiff != 0) return timeDiff;
        // Fallback to play counts
        return b.value.compareTo(a.value);
      });

    MapEntry<String, int>? topArtist;
    if (sortedArtistList.isNotEmpty) {
      topArtist = sortedArtistList.first;
    }

    // BACKFILL METADATA (If missing)
    _backfillMetadata(displayList);

    // Convert artist seconds to minutes
    final Map<String, int> artistMinMap = {};
    for (final e in artistSeconds.entries) {
      artistMinMap[e.key] = (e.value / 60).floor();
    }

    return _StatsResult(
      mostPlayed: displayList,
      totalMinutes: (totalSeconds / 60).floor(),
      totalPlays: totalPlays,
      topArtistEntry: topArtist,
      sortedArtists: sortedArtistList.length > 50
          ? sortedArtistList.sublist(0, 50)
          : sortedArtistList,
      artistMinutes: artistMinMap,
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
          artUrl ??=
              await SpotifyService.getTrackImage(song.title, song.artist);

          // 2. Fetch URL
          String? youtubeUrl = song.sourceUrl;
          youtubeUrl ??=
              await SpotifyService.getTrackLink(song.title, song.artist);

          if (artUrl != null || youtubeUrl != null) {
            if (mounted) {
              ref
                  .read(statsProvider.notifier)
                  .updateMetadata(id, artUrl: artUrl, youtubeUrl: youtubeUrl);
            }
          }
        } catch (e) {
          debugPrint("Backfill failed for ${song.title}: $e");
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
  final List<MapEntry<String, int>> sortedArtists;
  final Map<String, int> artistMinutes;

  _StatsResult(
      {required this.mostPlayed,
      required this.totalMinutes,
      required this.totalPlays,
      this.topArtistEntry,
      this.sortedArtists = const [],
      this.artistMinutes = const {}});
  factory _StatsResult.empty() => _StatsResult(
      mostPlayed: [],
      totalMinutes: 0,
      totalPlays: 0,
      topArtistEntry: null,
      sortedArtists: [],
      artistMinutes: {});
}
