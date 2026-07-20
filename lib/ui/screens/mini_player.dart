import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_music_player_2/providers/player_provider.dart';
import 'package:simple_music_player_2/ui/components/smart_art.dart';
import 'package:window_manager/window_manager.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../../providers/interface_provider.dart';
import '../../providers/lyrics_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/chinese_romanizer.dart';
import '../../utils/japanese_romanizer.dart';
import '../../utils/korean_romanizer.dart';
import '../../utils/translation_service.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/smooth_highlight_text.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  // Idle fade state
  bool _showControls = true;
  Timer? _hideTimer;
  bool _showLyrics = false;

  static const double _baseHeight = 160.0;
  static const double _lyricsHeight = 280.0;
  static const double _windowWidth = 380.0;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    // Load lyrics for the current song
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final song = ref.read(playerProvider).currentSong;
      if (song != null) {
        ref.read(lyricsProvider.notifier).loadLyrics(
              song.filePath,
              song.title,
              song.artist,
              song.duration,
            );
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onUserInteraction() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
  }

  Future<void> _toggleLyrics() async {
    _onUserInteraction();
    setState(() => _showLyrics = !_showLyrics);

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final targetHeight = _showLyrics ? _lyricsHeight : _baseHeight;
      await windowManager.setMinimumSize(Size(_windowWidth - 60, targetHeight));
      await windowManager.setSize(Size(_windowWidth, targetHeight));
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final song = playerState.currentSong;
    final lyricsState = ref.watch(lyricsProvider);

    // Listen for song changes to reload lyrics
    ref.listen<PlayerState>(playerProvider, (previous, next) {
      if (previous?.currentSong?.filePath != next.currentSong?.filePath ||
          previous?.currentSong?.title != next.currentSong?.title) {
        if (next.currentSong != null) {
          ref.read(lyricsProvider.notifier).loadLyrics(
                next.currentSong!.filePath,
                next.currentSong!.title,
                next.currentSong!.artist,
                next.currentSong!.duration,
              );
        }
      }
    });

    // Find current lyric (must match lyrics_panel._syncLyrics formula)
    final lyrics = lyricsState.parsedLyrics;
    final effectiveTime =
        playerState.currentPosition - lyricsState.syncOffset + 0.5;
    int currentIndex = -1;
    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (effectiveTime >= lyrics[i].time) {
        currentIndex = i;
        break;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onHover: (_) => _onUserInteraction(),
        onEnter: (_) => _onUserInteraction(),
        cursor:
            _showControls ? SystemMouseCursors.basic : SystemMouseCursors.none,
        child: GestureDetector(
          onPanUpdate: (details) async {
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
              await windowManager.startDragging();
            }
          },
          onTap: _onUserInteraction,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.zero,
            ),
            child: Stack(
              children: [
                // 1. Background Art
                if (song != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.6,
                      child: SmartArt(
                        path: song.filePath,
                        onlineArtUrl: song.onlineArtUrl,
                        size: 400,
                        borderRadius: 0,
                      ),
                    ),
                  ),

                // 2. Glass Overlay
                Positioned.fill(
                  child: GlassmorphicContainer(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                    blur: 20,
                    alignment: Alignment.center,
                    border: 0,
                    linearGradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderGradient: const LinearGradient(colors: [
                      Colors.white24,
                      Colors.white10,
                    ]),
                    child: Container(),
                  ),
                ),

                // 3. Content
                if (song != null)
                  Column(
                    children: [
                      // Top section: Art + Info + Controls
                      SizedBox(
                        height: _baseHeight,
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Art
                                SmartArt(
                                  path: song.filePath,
                                  onlineArtUrl: song.onlineArtUrl,
                                  size: 80,
                                  borderRadius: 8,
                                ),
                                const SizedBox(width: 16),
                                // Info & Controls
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                      // Controls Row - fade out on idle
                                      AnimatedSize(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        child: _showControls
                                            ? Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons
                                                              .skip_previous_rounded,
                                                          color: Colors.white),
                                                      onPressed: () {
                                                        _onUserInteraction();
                                                        ref
                                                            .read(playerProvider
                                                                .notifier)
                                                            .playPrevious();
                                                      },
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .primaryColor,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: IconButton(
                                                        icon: Icon(
                                                          playerState.isPlaying
                                                              ? Icons
                                                                  .pause_rounded
                                                              : Icons
                                                                  .play_arrow_rounded,
                                                          color: Colors.black,
                                                        ),
                                                        onPressed: () {
                                                          _onUserInteraction();
                                                          ref
                                                              .read(
                                                                  playerProvider
                                                                      .notifier)
                                                              .togglePlay();
                                                        },
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8),
                                                        constraints:
                                                            const BoxConstraints(),
                                                        iconSize: 24,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons
                                                              .skip_next_rounded,
                                                          color: Colors.white),
                                                      onPressed: () {
                                                        _onUserInteraction();
                                                        ref
                                                            .read(playerProvider
                                                                .notifier)
                                                            .playNext();
                                                      },
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    // Lyrics toggle button
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.lyrics_outlined,
                                                        color: _showLyrics
                                                            ? Theme.of(context)
                                                                .primaryColor
                                                            : Colors.white54,
                                                        size: 20,
                                                      ),
                                                      onPressed: _toggleLyrics,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                      tooltip:
                                                          AppLocalizations.of(
                                                                  context)!
                                                              .toggleLyrics,
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bottom section: Lyrics (only when expanded)
                      if (_showLyrics)
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: _buildMiniLyrics(
                                lyrics, currentIndex, lyricsState, playerState),
                          ),
                        ),
                    ],
                  )
                else
                  const Center(
                    child: Text(
                      "No Music Playing",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),

                // 4. Return to Full Button - fades with controls
                Positioned(
                  top: 8,
                  right: 8,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _showControls ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: IconButton(
                        icon: const Icon(Icons.open_in_full_rounded,
                            color: Colors.white54, size: 20),
                        tooltip: AppLocalizations.of(context)!.expand,
                        onPressed: () {
                          ref.read(interfaceProvider.notifier).exitMiniPlayer();
                        },
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniLyrics(
      List<LyricLine> lyrics, int currentIndex, LyricsState lyricsState, PlayerState playerState) {
    if (lyricsState.isLoading) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white24,
          ),
        ),
      );
    }

    if (lyrics.isEmpty) {
      return const Center(
        child: Text(
          "No Synced Lyrics",
          style: TextStyle(
            color: Colors.white30,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Show current and next line
    final currentLine = currentIndex >= 0 ? lyrics[currentIndex] : null;
    final currentText = currentLine?.text ?? "♪ ♪ ♪";
    final nextText =
        (currentIndex + 1 < lyrics.length) ? lyrics[currentIndex + 1].text : "";

    // Romanization for current line
    String? currentRoman;
    if (currentIndex >= 0 && !ref.read(settingsProvider).disableRomanization) {
      final text = lyrics[currentIndex].text;
      if (KoreanRomanizer.containsKorean(text)) {
        currentRoman = KoreanRomanizer.romanize(text);
      } else if (JapaneseRomanizer.containsJapanese(text)) {
        currentRoman = JapaneseRomanizer.getCached(text);
      } else if (ChineseRomanizer.containsChinese(text)) {
        currentRoman = ChineseRomanizer.getCached(text);
      }
    }

    final accentColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current line
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.topLeft,
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            child: (currentIndex >= 0)
                ? SmoothHighlightText(
                    key: ValueKey(currentText),
                    text: currentText,
                    startTime: currentLine!.time,
                    endTime: (currentIndex + 1 < lyrics.length)
                        ? lyrics[currentIndex + 1].time
                        : currentLine.time + 5.0,
                    initialPosition: playerState.currentPosition,
                    isPlaying: playerState.isPlaying,
                    syncOffset: lyricsState.syncOffset,
                    activeColor: accentColor,
                    inactiveColor: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    words: currentLine.words,
                  )
                : Text(
                    currentText,
                    key: ValueKey(currentText),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          // Romanization
          if (currentRoman != null && currentRoman.isNotEmpty)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topLeft,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: (currentIndex >= 0)
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: SmoothHighlightText(
                        key: ValueKey(currentRoman),
                        text: currentRoman,
                        startTime: currentLine!.time,
                        endTime: (currentIndex + 1 < lyrics.length)
                            ? lyrics[currentIndex + 1].time
                            : currentLine.time + 5.0,
                        initialPosition: playerState.currentPosition,
                        isPlaying: playerState.isPlaying,
                        syncOffset: lyricsState.syncOffset,
                        activeColor: accentColor.withValues(alpha: 0.8),
                        inactiveColor: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                        isItalic: true,
                        spacing: 4.0,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        currentRoman,
                        key: ValueKey(currentRoman),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
            ),
          // Translation (if cached AND translation toggle is on)
          if (currentIndex >= 0 &&
              ref.watch(lyricsProvider).showTranslation) ...{
            Builder(builder: (context) {
              final song = ref.read(playerProvider).currentSong;
              if (song == null) return const SizedBox.shrink();
              final songKey = '${song.title}-${song.artist}';
              final translations = TranslationService.getCached(songKey);
              if (translations == null ||
                  currentIndex >= translations.length ||
                  translations[currentIndex].isEmpty) {
                return const SizedBox.shrink();
              }
              final transText = translations[currentIndex];
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topLeft,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: Text(
                  '($transText)',
                  key: ValueKey(transText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: currentIndex >= 0
                        ? accentColor.withValues(alpha: 0.6)
                        : Colors.white38,
                    fontSize: 11,
                  ),
                ),
              );
            }),
          },
          // Next line
          if (nextText.isNotEmpty)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topLeft,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: Text(
                nextText,
                key: ValueKey(nextText),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
