import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../widgets/smooth_highlight_text.dart';

import '../../providers/lyrics_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/chinese_romanizer.dart';
import '../../utils/japanese_romanizer.dart';
import '../../utils/korean_romanizer.dart';
import '../../utils/translation_service.dart';
import '../../services/apple_music_backend_service.dart';
import '../../services/spotify_lyrics_service.dart';
import '../../services/itunes_api_service.dart';
import '../../models/song_metadata.dart';
import 'package:http/http.dart' as http;
import 'lyrics_editor.dart';
import '../components/smart_art.dart';
import '../../l10n/app_localizations.dart';
import '../components/vinyl_disk.dart';

class LyricsPanel extends ConsumerStatefulWidget {
  const LyricsPanel({super.key});

  @override
  ConsumerState<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<LyricsPanel> with SingleTickerProviderStateMixin {
  bool _isEditing = false;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  int _activeLyricIndex = -1;
  bool _isUserScrolling = false;
  bool _translationLoading = false;
  Timer? _scrollResumeTimer;
  Timer? _karaokeIdleTimer;
  bool _showExitButton = true;
  
  // Smooth scroll ticker
  Ticker? _ticker;
  double _smoothPosition = 0;
  Duration _lastTick = Duration.zero;

  void _resetKaraokeIdleTimer() {
    _karaokeIdleTimer?.cancel();
    if (!mounted) return;
    if (!_showExitButton) {
      setState(() {
        _showExitButton = true;
      });
    }
    _karaokeIdleTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showExitButton = false;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker!.start();

    if (ref.read(lyricsProvider).isKaraokeMode) {
      _resetKaraokeIdleTimer();
    }

    Future.microtask(() {
      final currentSong = ref.read(playerProvider).currentSong;
      if (currentSong != null) {
        ref.read(lyricsProvider.notifier).loadLyrics(
              currentSong.filePath,
              currentSong.title,
              currentSong.artist,
              currentSong.duration,
            );
      }
    });
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    
    final player = ref.read(playerProvider);
    if (!player.isPlaying) {
      _lastTick = elapsed;
      return;
    }

    if (_lastTick != Duration.zero) {
      final delta = (elapsed - _lastTick).inMicroseconds / 1000000.0;
      _smoothPosition += delta;
      
      // Periodically sync with real position to prevent drift
      // We do this gently to avoid jumps
      final realPos = player.currentPosition;
      if ((realPos - _smoothPosition).abs() > 0.1) {
        _smoothPosition = realPos;
      }

      // Check for index change at high frequency
      if (!_isUserScrolling) {
        final lyricsState = ref.read(lyricsProvider);
        final lyrics = lyricsState.parsedLyrics;
        if (lyrics.isNotEmpty) {
          _syncLyrics(_smoothPosition, lyrics, lyricsState.syncOffset);
        }
      }
    }
    _lastTick = elapsed;
  }

  void _toggleTranslation(dynamic lyricsState, dynamic playerState) async {
    final currentlyShowing = ref.read(lyricsProvider).showTranslation;

    if (currentlyShowing) {
      ref.read(lyricsProvider.notifier).setShowTranslation(false);
      return;
    }

    final song = playerState.currentSong;
    if (song == null) return;
    final lyrics = lyricsState.parsedLyrics;
    if (lyrics.isEmpty) return;

    final songKey = '${song.title}-${song.artist}';

    // If already cached, just show
    if (TranslationService.hasCached(songKey)) {
      ref.read(lyricsProvider.notifier).setShowTranslation(true);
      return;
    }

    // Fetch translation
    setState(() => _translationLoading = true);
    final targetLang = ref.read(settingsProvider).translationLanguage;
    final lines = lyrics.map<String>((l) => l.text as String).toList();
    await TranslationService.translateLyrics(
      songKey: songKey,
      lines: lines,
      targetLang: targetLang,
    );
    if (mounted) {
      setState(() {
        _translationLoading = false;
      });
      ref.read(lyricsProvider.notifier).setShowTranslation(true);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _scrollResumeTimer?.cancel();
    _karaokeIdleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(lyricsProvider.notifier);

    final accentColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF121212).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.95);
    final headerTextColor = isDark ? Colors.white : Colors.black;
    final l10n = AppLocalizations.of(context)!;

    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final showActions = playerState.currentSong != null;
    final sideWidth = showActions ? (isMobile ? 48.0 : 240.0) : 48.0;

    ref.listen(playerProvider.select((s) => s.currentSong), (previous, next) {
      if (!mounted) return;

      if (next != null &&
          (previous?.filePath != next.filePath ||
              previous?.title != next.title)) {
        JapaneseRomanizer.clearCache();
        ChineseRomanizer.clearCache();

        ref.read(lyricsProvider.notifier).loadLyrics(
              next.filePath,
              next.title,
              next.artist,
              next.duration,
            );
      }
    });

    ref.listen(playerProvider.select((s) => s.currentPosition), (prev, next) {
      _smoothPosition = next;
      if (!_isUserScrolling) {
        _syncLyrics(next, lyricsState.parsedLyrics, lyricsState.syncOffset);
      }
    });

    // Auto-translate when lyrics finish loading and translation is on
    ref.listen(lyricsProvider, (previous, next) {
      if (!mounted || !ref.read(lyricsProvider).showTranslation) return;
      if (next.parsedLyrics.isNotEmpty &&
          (previous == null ||
              previous.parsedLyrics.isEmpty ||
              previous.isLoading)) {
        final song = ref.read(playerProvider).currentSong;
        if (song == null) return;
        final songKey = '${song.title}-${song.artist}';
        if (TranslationService.hasCached(songKey)) return;
        setState(() => _translationLoading = true);
        final targetLang = ref.read(settingsProvider).translationLanguage;
        final lines = next.parsedLyrics.map<String>((l) => l.text).toList();
        TranslationService.translateLyrics(
          songKey: songKey,
          lines: lines,
          targetLang: targetLang,
        ).then((_) {
          if (mounted) setState(() => _translationLoading = false);
        });
      }
    });

    // Re-translate when target language changes in settings
    ref.listen(settingsProvider, (previous, next) {
      if (!mounted || !ref.read(lyricsProvider).showTranslation) return;
      if (previous != null &&
          previous.translationLanguage != next.translationLanguage) {
        final song = ref.read(playerProvider).currentSong;
        if (song == null) return;
        final lyrics = ref.read(lyricsProvider).parsedLyrics;
        if (lyrics.isEmpty) return;
        final songKey = '${song.title}-${song.artist}';
        setState(() => _translationLoading = true);
        final lines = lyrics.map<String>((l) => l.text).toList();
        TranslationService.translateLyrics(
          songKey: songKey,
          lines: lines,
          targetLang: next.translationLanguage,
        ).then((_) {
          if (mounted) setState(() => _translationLoading = false);
        });
      }
    });

    // Auto-reset Karaoke idle timer on mode change
    ref.listen<LyricsState>(lyricsProvider, (previous, next) {
      if (previous?.isKaraokeMode != next.isKaraokeMode) {
        if (next.isKaraokeMode) {
          _resetKaraokeIdleTimer();
        } else {
          _karaokeIdleTimer?.cancel();
        }
      }
    });

    return Listener(
      onPointerDown: (_) {
        if (ref.read(lyricsProvider).isKaraokeMode) {
          _resetKaraokeIdleTimer();
        }
      },
      onPointerHover: (_) {
        if (ref.read(lyricsProvider).isKaraokeMode) {
          _resetKaraokeIdleTimer();
        }
      },
      onPointerMove: (_) {
        if (ref.read(lyricsProvider).isKaraokeMode) {
          _resetKaraokeIdleTimer();
        }
      },
      child: MouseRegion(
        cursor: (lyricsState.isKaraokeMode && !_showExitButton)
            ? SystemMouseCursors.none
            : SystemMouseCursors.basic,
        child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
            ref.read(playerProvider.notifier).setLyricsVisibility(false);
          }
        },
      child: Container(
        color: bgColor,
        child: Stack(
          children: [
            // LAYER 1: BACKGROUND
            if (playerState.currentSong != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: SmartArt(
                    path: playerState.currentSong!.filePath,
                    size: 800,
                    borderRadius: 0,
                    onlineArtUrl: playerState.currentSong!.onlineArtUrl,
                  ),
                ),
              ),

            // LAYER 2: TINT
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.9)
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.5),
                            Colors.white.withValues(alpha: 0.9)
                          ],
                  ),
                ),
              ),
            ),

            // LAYER 3: CONTENT
            Column(
              children: [
                // Header
                if (lyricsState.isKaraokeMode)
                  AnimatedOpacity(
                    opacity: _showExitButton ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !_showExitButton,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                tooltip: "Exit Immersive Mode",
                                icon: Icon(Icons.close_rounded, color: headerTextColor),
                                onPressed: () {
                                  ref.read(lyricsProvider.notifier).setKaraokeMode(false);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    children: [
                      // Left side: down arrow, sized to balance the right side
                      SizedBox(
                        width: sideWidth,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: Icon(Icons.keyboard_arrow_down,
                                color: headerTextColor),
                            onPressed: () {
                              ref
                                  .read(playerProvider.notifier)
                                  .setLyricsVisibility(false);
                            },
                          ),
                        ),
                      ),
                      // Center: Title (always perfectly centered)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              l10n.nowPlayingHeader,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                color: isDark ? Colors.white54 : Colors.black54,
                                letterSpacing: 1.0,
                              ),
                            ),
                            if (playerState.currentSong != null)
                              Text(
                                playerState.currentSong!.title,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: headerTextColor,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Container(
                              width: 60,
                              height: 3,
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right side: action buttons
                      if (showActions && !_isEditing)
                        SizedBox(
                          width: sideWidth,
                          child: isMobile
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: lyricsState.isLoading
                                      ? Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: headerTextColor,
                                            ),
                                          ),
                                        )
                                      : PopupMenuButton<String>(
                                          icon: Icon(Icons.more_vert,
                                              color: headerTextColor),
                                          color: isDark
                                              ? const Color(0xFF1E1E1E)
                                              : Colors.white,
                                          onSelected: (value) {
                                            if (value == 'import') {
                                              if (playerState.currentSong != null) {
                                                _showImportOptions(context, ref, playerState.currentSong!);
                                              } else {
                                                _pickAndImportLyrics(ref);
                                              }
                                            } else if (value == 'save') {
                                              _saveLyricsToFile(
                                                ref,
                                                playerState.currentSong!,
                                                lyricsState.rawLyrics,
                                              );
                                            } else if (value == 'refresh') {
                                              final song =
                                                  playerState.currentSong!;
                                              ref
                                                  .read(lyricsProvider.notifier)
                                                  .refreshLyricsFromApi(
                                                    song.title,
                                                    song.artist,
                                                    song.duration,
                                                  );
                                            } else if (value == 'translate') {
                                              _toggleTranslation(
                                                  lyricsState, playerState);
                                            } else if (value == 'generate_ai') {
                                              final song =
                                                  playerState.currentSong!;
                                              ref
                                                  .read(lyricsProvider.notifier)
                                                  .generateAiLyrics(
                                                      song.filePath);
                                            } else if (value == 'karaoke') {
                                                ref
                                                    .read(lyricsProvider.notifier)
                                                    .toggleKaraokeMode();
                                            } else if (value == 'edit') {
                                              setState(() {
                                                _isEditing = true;
                                              });
                                            }
                                          },
                                          itemBuilder: (BuildContext context) =>
                                              <PopupMenuEntry<String>>[
                                            PopupMenuItem<String>(
                                              value: 'import',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.file_open_outlined,
                                                      color: headerTextColor,
                                                      size: 20),
                                                  const SizedBox(width: 12),
                                                  Text(l10n.importLabel,
                                                      style: TextStyle(
                                                          color:
                                                              headerTextColor)),
                                                ],
                                              ),
                                            ),
                                            if ((lyricsState.parsedLyrics
                                                        .isNotEmpty ||
                                                    lyricsState.rawLyrics
                                                        .isNotEmpty) &&
                                                playerState.currentSong!
                                                        .filePath !=
                                                    'cloud_stream')
                                              PopupMenuItem<String>(
                                                value: 'save',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.save_outlined,
                                                        color: headerTextColor,
                                                        size: 20),
                                                    const SizedBox(width: 12),
                                                    Text(l10n.saveLabel,
                                                        style: TextStyle(
                                                            color:
                                                                headerTextColor)),
                                                  ],
                                                ),
                                              ),
                                            PopupMenuItem<String>(
                                              value: 'karaoke',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                      Icons.mic_external_on_rounded,
                                                      color: lyricsState
                                                              .isKaraokeMode
                                                          ? accentColor
                                                          : headerTextColor,
                                                      size: 20),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                      "Karaoke Mode",
                                                      style: TextStyle(
                                                          color:
                                                              headerTextColor)),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'refresh',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.refresh,
                                                      color: headerTextColor,
                                                      size: 20),
                                                  const SizedBox(width: 12),
                                                  Text(l10n.refreshLabel,
                                                      style: TextStyle(
                                                          color:
                                                              headerTextColor)),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_note_outlined,
                                                      color: headerTextColor,
                                                      size: 20),
                                                  const SizedBox(width: 12),
                                                  Text(l10n.lyricsEditorTitle,
                                                      style: const TextStyle(
                                                          color:
                                                              Colors.white)),
                                                ],
                                              ),
                                            ),
                                            if (lyricsState
                                                .parsedLyrics.isNotEmpty)
                                              PopupMenuItem<String>(
                                                value: 'translate',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                        Icons.translate_rounded,
                                                        color: lyricsState
                                                                .showTranslation
                                                            ? accentColor
                                                            : headerTextColor,
                                                        size: 20),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                        lyricsState
                                                                .showTranslation
                                                            ? l10n
                                                                .hideTranslation
                                                            : l10n
                                                                .translateLabel,
                                                        style: TextStyle(
                                                            color:
                                                                headerTextColor)),
                                                  ],
                                                ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'generate_ai',
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.auto_awesome,
                                                      color: Colors.amber,
                                                      size: 20),
                                                  const SizedBox(width: 12),
                                                  Text(l10n.generateAiLyrics,
                                                      style: TextStyle(
                                                          color:
                                                              headerTextColor)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: l10n.editLyricsTooltip,
                                      child: _buildMiniButton(
                                        Icons.edit_note_rounded,
                                        () {
                                          setState(() {
                                            _isEditing = true;
                                          });
                                        },
                                        isDark,
                                      ),
                                    ),
                                    Tooltip(
                                      message: l10n.importLyricsTooltip,
                                      child: _buildMiniButton(
                                        Icons.file_open_outlined,
                                        () {
                                          if (playerState.currentSong != null) {
                                            _showImportOptions(context, ref, playerState.currentSong!);
                                          } else {
                                            _pickAndImportLyrics(ref);
                                          }
                                        },
                                        isDark,
                                      ),
                                    ),
                                    // Save button: when any lyrics are loaded
                                    if ((lyricsState.parsedLyrics.isNotEmpty ||
                                            lyricsState.rawLyrics.isNotEmpty) &&
                                        playerState.currentSong!.filePath !=
                                            'cloud_stream')
                                      Tooltip(
                                        message: l10n.saveLyricsTooltip,
                                        child: _buildMiniButton(
                                          Icons.save_outlined,
                                          () => _saveLyricsToFile(
                                            ref,
                                            playerState.currentSong!,
                                            lyricsState.rawLyrics,
                                          ),
                                          isDark,
                                        ),
                                      ),
                                    lyricsState.isLoading
                                        ? Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: headerTextColor,
                                              ),
                                            ),
                                          )
                                        : Tooltip(
                                            message: l10n.refreshLyricsTooltip,
                                            child: _buildMiniButton(
                                              Icons.refresh,
                                              () {
                                                final song =
                                                    playerState.currentSong!;
                                                ref
                                                    .read(
                                                        lyricsProvider.notifier)
                                                    .refreshLyricsFromApi(
                                                      song.title,
                                                      song.artist,
                                                      song.duration,
                                                    );
                                              },
                                              isDark,
                                            ),
                                          ),
                                    if (lyricsState.parsedLyrics.isNotEmpty)
                                      _translationLoading
                                          ? Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: headerTextColor,
                                                ),
                                              ),
                                            )
                                          : Tooltip(
                                              message:
                                                  lyricsState.showTranslation
                                                      ? l10n.hideTranslation
                                                      : l10n.translateLabel,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                onTap: () => _toggleTranslation(
                                                    lyricsState, playerState),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: Icon(
                                                    Icons.translate_rounded,
                                                    color: lyricsState
                                                            .showTranslation
                                                        ? accentColor
                                                        : headerTextColor,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          Tooltip(
                                            message: "Karaoke Mode",
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              onTap: () => ref
                                                  .read(lyricsProvider.notifier)
                                                  .toggleKaraokeMode(),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Icon(
                                                  Icons.mic_external_on_rounded,
                                                  color: lyricsState
                                                          .isKaraokeMode
                                                      ? accentColor
                                                      : headerTextColor,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                    ],
                                  ),
                        )
                      else
                        SizedBox(width: sideWidth),
                    ],
                  ),
                ),

                // Lyrics Content
                Expanded(
                  child: _isEditing
                      ? LyricsEditor(
                          onBack: () => setState(() => _isEditing = false),
                        )
                      : lyricsState.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : lyricsState.parsedLyrics.isEmpty
                              ? _buildRawLyrics(
                                  lyricsState.rawLyrics,
                                  isDark,
                                  playerState.currentSong?.filePath,
                                  playerState.currentSong?.onlineArtUrl,
                                  playerState.isPlaying,
                                  l10n,
                                )
                              : Consumer(
                                  builder: (context, ref, _) {
                                    final position = ref.watch(playerProvider.select((s) => s.currentPosition));
                                    return _buildSyncedLyricsList(
                                      lyricsState.parsedLyrics,
                                      accentColor,
                                      headerTextColor.withValues(alpha: 0.54),
                                      ref.read(playerProvider.notifier),
                                      screenHeight,
                                      lyricsState,
                                      position,
                                      playerState.isPlaying,
                                    );
                                  },
                                ),
                ),
                const SizedBox(height: 95),
              ],
            ),

            // LAYER 4: WATERMARK (only when lyrics are actually found)
            if (lyricsState.isFromApi &&
                !lyricsState.isLoading &&
                lyricsState.parsedLyrics.isNotEmpty &&
                !_isEditing &&
                !lyricsState.isKaraokeMode)
              Positioned(
                top: 90,
                right: 24,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white12)),
                  child: Text(
                    l10n.lyricsByLRCLIB,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // LAYER 5: TIMESHIFT
            if (lyricsState.parsedLyrics.isNotEmpty && !lyricsState.isKaraokeMode)
              Positioned(
                bottom: 110,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black87 : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMiniButton(
                          Icons.remove, () => notifier.addOffset(-0.5), isDark),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "${lyricsState.syncOffset > 0 ? '+' : ''}${lyricsState.syncOffset}s",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: accentColor),
                        ),
                      ),
                      _buildMiniButton(
                          Icons.add, () => notifier.addOffset(0.5), isDark),
                    ],
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

  Widget _buildMiniButton(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(icon,
            size: 20, color: isDark ? Colors.white70 : Colors.black87),
      ),
    );
  }

  Future<void> _pickAndImportLyrics(WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lrc', 'txt', 'ttml', 'srt'],
      dialogTitle: l10n.importLyricsFile,
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      if (content.trim().isNotEmpty) {
        ref.read(lyricsProvider.notifier).loadLyricsFromContent(content);
      }
    }
  }

  Future<void> _saveLyricsToFile(
    WidgetRef ref,
    dynamic song,
    String rawLyrics,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(l10n.saveLyricsTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.chooseFormat, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            _buildFormatOption(
              context,
              title: l10n.lrcFormat,
              subtitle: l10n.lrcFormatDesc,
              icon: Icons.description_outlined,
              value: "lrc",
            ),
            const SizedBox(height: 12),
            _buildFormatOption(
              context,
              title: l10n.ttmlFormat,
              subtitle: l10n.ttmlFormatDesc,
              icon: Icons.auto_awesome_outlined,
              value: "ttml",
            ),
            const SizedBox(height: 12),
            _buildFormatOption(
              context,
              title: "Embed in Audio File",
              subtitle: "Writes lyrics directly into the song metadata.",
              icon: Icons.album_outlined,
              value: "embed",
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ],
      ),
    );

    if (format == null) return;

    try {
      if (format == 'embed') {
        final success = await ref.read(lyricsProvider.notifier).embedLyrics(song.filePath);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Lyrics embedded into audio file successfully!"),
                backgroundColor: Colors.green.withValues(alpha: 0.8),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.failedToSave)),
            );
          }
        }
      } else {
        final String extension = '.$format';
        final String savePath = song.filePath.replaceAll(RegExp(r'\.[^.]+$'), extension);
        
        final success = await ref.read(lyricsProvider.notifier).saveLyrics(
          savePath,
          asTtml: format == "ttml",
        );

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.savedSuccessfully(extension)),
                backgroundColor: Colors.green.withValues(alpha: 0.8),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.failedToSave)),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to save lyrics: $e');
    }
  }

  Widget _buildFormatOption(BuildContext context, {required String title, required String subtitle, required IconData icon, required String value}) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.03),
        ),
        child: Row(
          children: [
            Icon(icon, color: value == "ttml" ? Colors.amber : Colors.blueAccent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _syncLyrics(double currentPos, List<dynamic> lyrics, double offset) {
    double effectiveTime = currentPos - offset + 0.5;
    int index = -1;

    for (int i = 0; i < lyrics.length; i++) {
      if (effectiveTime >= lyrics[i].time) {
        index = i;
      } else {
        break;
      }
    }

    if (index != _activeLyricIndex) {
      if (index < _activeLyricIndex && _activeLyricIndex >= 0 && _activeLyricIndex < lyrics.length) {
        double activeLineTime = lyrics[_activeLyricIndex].time;
        if (activeLineTime - effectiveTime > 0.0 && activeLineTime - effectiveTime < 0.5) {
          // Ignore tiny backward time jitters to prevent rapid flickering
          return;
        }
      }

      if (index == -1 && _activeLyricIndex >= 0) {
        setState(() => _activeLyricIndex = -1);
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: 0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutQuart,
            alignment: ref.read(lyricsProvider).isKaraokeMode ? 0.45 : 0.0,
          );
        }
        return;
      }

      setState(() => _activeLyricIndex = index);
      if (!_isUserScrolling && _activeLyricIndex >= 0) {
        _scrollToActiveLine();
      }
    }
  }
  void _scrollToActiveLine() {
    if (_itemScrollController.isAttached) {
      final isKaraoke = ref.read(lyricsProvider).isKaraokeMode;
      if (isKaraoke) {
        _itemScrollController.scrollTo(
          index: _activeLyricIndex,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutQuart,
          alignment: 0.45,
        );
      } else if (_activeLyricIndex < 3) {
        _itemScrollController.scrollTo(
          index: 0,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutQuart,
          alignment: 0.0,
        );
      } else {
        _itemScrollController.scrollTo(
          index: _activeLyricIndex,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutQuart,
          alignment: 0.45,
        );
      }
    }
  }

  Widget _buildSyncedLyricsList(
    List<dynamic> lyrics,
    Color activeColor,
    Color inactiveColor,
    dynamic playerNotifier,
    double screenHeight,
    LyricsState lyricsState,
    double currentPosition,
    bool isPlaying,
  ) {
    Widget buildLyricItem(BuildContext context, int index) {
      if (index == lyrics.length) {
        return SizedBox(height: screenHeight * 0.45);
      }

      final line = lyrics[index];
      final isActive = index == _activeLyricIndex;
      double opacity = 0.3;
          if (lyricsState.isKaraokeMode) {
            opacity = isActive ? 1.0 : 0.0;
          } else {
            if (isActive) {
              opacity = 1.0;
            } else if ((index - _activeLyricIndex).abs() == 1) {
              opacity = 0.6;
            } else if ((index - _activeLyricIndex).abs() == 2) {
              opacity = 0.4;
            } else {
              opacity = 0.2;
            }
          }

          // Calculate dynamic font size for main text based on length
          double mainActiveFontSize = 32.0;
          if (lyricsState.isKaraokeMode) {
            double maxFont = MediaQuery.of(context).size.height < 500 ? 32.0 : 48.0;
            if (line.text.length > 70) {
              mainActiveFontSize = maxFont * 0.66;
            } else if (line.text.length > 40) {
              mainActiveFontSize = maxFont * 0.83;
            } else {
              mainActiveFontSize = maxFont;
            }
          } else {
            mainActiveFontSize = 26.0;
          }

          final hasKorean = KoreanRomanizer.containsKorean(line.text);
          final hasJapanese =
              !hasKorean && JapaneseRomanizer.containsJapanese(line.text);
          final hasChinese = !hasKorean &&
              !hasJapanese &&
              ChineseRomanizer.containsChinese(line.text);
          String? romanized;
          if (!ref.read(settingsProvider).disableRomanization) {
            if (hasKorean) {
              romanized = KoreanRomanizer.romanize(line.text);
            } else if (hasJapanese) {
              romanized = JapaneseRomanizer.getCached(line.text);
            } else if (hasChinese) {
              romanized = ChineseRomanizer.getCached(line.text);
            }
          }

          double romanizedActiveFontSize = 18.0;
          if (lyricsState.isKaraokeMode && romanized != null) {
            double maxRomFont = MediaQuery.of(context).size.height < 500 ? 18.0 : 24.0;
            if (romanized.length > 70) {
              romanizedActiveFontSize = maxRomFont * 0.75;
            } else if (romanized.length > 40) {
              romanizedActiveFontSize = maxRomFont * 0.83;
            } else {
              romanizedActiveFontSize = maxRomFont;
            }
          }

          return ConstrainedBox(
            key: ValueKey(index),
            constraints: BoxConstraints(
              minHeight: lyricsState.isKaraokeMode ? 140 : 60,
            ),
            child: GestureDetector(
              onTap: lyricsState.isKaraokeMode ? null : () {
              playerNotifier.seek(line.time);
              setState(() => _activeLyricIndex = index);
              if (index < 3) {
                _itemScrollController.scrollTo(
                  index: 0,
                  duration: const Duration(milliseconds: 300),
                  alignment: 0.0,
                );
              } else {
                _itemScrollController.scrollTo(
                  index: index,
                  duration: const Duration(milliseconds: 300),
                  alignment: 0.45,
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 12),
              transform: Matrix4.diagonal3Values(
                  isActive ? 1.05 : 1.0, isActive ? 1.05 : 1.0, 1.0),
              alignment: Alignment.center,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                  children: [
                  // Original text
                  !isActive
                      ? Text(
                          line.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22.0,
                            fontWeight: FontWeight.w600,
                            color: inactiveColor.withValues(alpha: opacity),
                            height: 1.4,
                          ),
                        )
                      : SmoothHighlightText(
                          text: line.text,
                          startTime: line.time,
                          endTime: index + 1 < lyrics.length
                              ? lyrics[index + 1].time
                              : line.time + 5.0,
                          initialPosition: currentPosition,
                          isPlaying: isPlaying,
                          syncOffset: lyricsState.syncOffset,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor.withValues(alpha: 1.0),
                          fontSize: mainActiveFontSize,
                          fontWeight: FontWeight.w900,
                          words: line.words,
                          isKaraokeMode: lyricsState.isKaraokeMode,
                          isActive: true,
                        ),
                  // Romanization
                  if (romanized != null) ...[
                    SizedBox(height: lyricsState.isKaraokeMode ? 24 : 8),
                    !isActive
                        ? Text(
                            romanized,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              color: inactiveColor.withValues(alpha: opacity * 0.6),
                              height: 1.4,
                            ),
                          )
                        : SmoothHighlightText(
                            text: romanized,
                            startTime: line.time,
                            endTime: (index + 1 < lyrics.length)
                                ? lyrics[index + 1].time
                                : line.time + 5.0,
                            initialPosition: currentPosition,
                            isPlaying: isPlaying,
                            syncOffset: lyricsState.syncOffset,
                            activeColor: activeColor,
                            inactiveColor: inactiveColor.withValues(alpha: 1.0),
                            fontSize: romanizedActiveFontSize,
                            fontWeight: FontWeight.w500,
                            isItalic: true,
                            spacing: 6.0,
                            isKaraokeMode: lyricsState.isKaraokeMode,
                            isActive: true,
                          ),
                  ],
                  // Translation
                  if (lyricsState.showTranslation) ...[
                    Builder(builder: (context) {
                      final song = ref.read(playerProvider).currentSong;
                      if (song == null) return const SizedBox.shrink();
                      final songKey = '${song.title}-${song.artist}';
                      final translations =
                          TranslationService.getCached(songKey);
                      if (translations == null ||
                          index >= translations.length ||
                          translations[index].isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: EdgeInsets.only(top: lyricsState.isKaraokeMode ? 24 : 8),
                        child: Text(
                          '(${translations[index]})',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isActive ? 16 : 12,
                            fontWeight: FontWeight.w400,
                            color: isActive
                                ? activeColor.withValues(alpha: 0.6)
                                : inactiveColor.withValues(
                                    alpha: opacity * 0.5),
                            height: 1.3,
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
              ), // Close SizedBox
              ), // Close AnimatedSize
            ), // Close AnimatedContainer
          ),
        );
    } // End of buildLyricItem

    if (lyricsState.isKaraokeMode) {
      if (lyrics.isEmpty) {
        return const SizedBox();
      }

      double effectiveTime = currentPosition - lyricsState.syncOffset;

      bool isIntro = _activeLyricIndex < 0 || (lyrics.isNotEmpty && effectiveTime < lyrics[0].time);
      bool isOutro = _activeLyricIndex >= lyrics.length ||
                     (_activeLyricIndex == lyrics.length - 1 &&
                      effectiveTime > (lyrics.last.time + 5.0));

      bool isInterlude = false;
      if (!isIntro && !isOutro && _activeLyricIndex >= 0 && _activeLyricIndex < lyrics.length - 1) {
        final currentLine = lyrics[_activeLyricIndex];
        double currentLineStart = currentLine.time;
        double nextLineTime = lyrics[_activeLyricIndex + 1].time;
        
        if (currentLine.endTime != null) {
          // If TTML/Karaoke provides an explicit end time, use it
          double gap = nextLineTime - currentLine.endTime!;
          // Only show note if there is at least a 3 second gap.
          // Note appears 1.5s AFTER the line ends, and stays until the next line starts.
          if (gap >= 3.0 && effectiveTime >= (currentLine.endTime! + 1.5) && effectiveTime < nextLineTime) {
            isInterlude = true;
          }
        } else {
          // Fallback for LRC (no end time)
          double lineGap = nextLineTime - currentLineStart;
          
          // Only show notes for significant gaps (>= 8s) since we don't know the exact end time.
          if (lineGap >= 8.0) {
            // Assume the lyric takes at most 5s or 50% of the gap, whichever is smaller
            double maxAllowed = lineGap * 0.5;
            double estimatedDuration = 5.0;
            if (estimatedDuration > maxAllowed) estimatedDuration = maxAllowed;
            
            double estimatedEnd = currentLineStart + estimatedDuration;
            
            if (effectiveTime >= (estimatedEnd + 1.5) && effectiveTime < nextLineTime) {
              isInterlude = true;
            }
          }
        }
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: (isIntro || isInterlude || isOutro)
                ? KeyedSubtree(
                    key: const ValueKey('karaoke_notes_indicator'),
                    child: _buildMusicalNotesIndicator(activeColor),
                  )
                : KeyedSubtree(
                    key: ValueKey('karaoke_line_$_activeLyricIndex'),
                    child: buildLyricItem(context, _activeLyricIndex),
                  ),
          ),
        ),
      );
    }

    return Listener(
      onPointerDown: (_) => _isUserScrolling = true,
      onPointerUp: (_) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _isUserScrolling = false;
        });
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: ScrollablePositionedList.builder(
          initialScrollIndex: _activeLyricIndex > 0 ? _activeLyricIndex : 0,
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            top: 32,
            bottom: 32,
          ),
          itemCount: lyrics.length + 1,
          itemBuilder: (context, index) => buildLyricItem(context, index),
        ),
      ),
    );
  }

  Widget _buildMusicalNotesIndicator(Color color) {
    return Text(
      '♪',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 48.0,
        fontWeight: FontWeight.bold,
        color: color,
        shadows: [
          Shadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 20,
          ),
        ],
      ),
    );
  }



  Widget _buildRawLyrics(String text, bool isDark, String? artPath,
      String? onlineArtUrl, bool isPlaying, AppLocalizations l10n) {
    
    // Determine if we should show the text or the fallback graphic
    final isErrorOrEmpty = text.trim().isEmpty || 
        text.contains("Error") || 
        text.contains("No local lyrics") || 
        text.contains("No lyrics found") || 
        text.contains("Offline Mode") ||
        text.contains("Offline or Disabled");

    if (!isErrorOrEmpty && !text.startsWith('<tt')) {
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.8,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              icon: const Icon(Icons.edit_note),
              label: Text(l10n.lyricsEditorTitle),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Use VinylDisk for fallback visual (with path)
          VinylDisk(
              artPath: artPath,
              onlineArtUrl: onlineArtUrl,
              isPlaying: isPlaying),
          const SizedBox(height: 40),
          Text(
            l10n.noSyncedLyricsFound,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            (text.contains("Error") || text.contains("Offline")) ? text : l10n.justEnjoyVibes,
            style: TextStyle(
                fontSize: 14, color: isDark ? Colors.white54 : Colors.black54),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isEditing = true;
              });
            },
            icon: const Icon(Icons.edit_note),
            label: Text(l10n.lyricsEditorTitle),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showImportOptions(BuildContext context, WidgetRef ref, dynamic currentSong) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.importLyricsFile, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.file_open_outlined, color: isDark ? Colors.white : Colors.black),
                title: Text(l10n.localFile, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                subtitle: Text(l10n.importLocalFileSubtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndImportLyrics(ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.apple, color: Colors.redAccent),
                title: Text(l10n.searchFromAppleMusic, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                subtitle: Text(l10n.searchAppleMusicSubtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _searchAppleMusicLyrics(context, ref, currentSong);
                },
              ),
              ListTile(
                leading: const Icon(Icons.music_note, color: Colors.green),
                title: Text(l10n.searchFromSpotifyLyrics, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                subtitle: Text(l10n.searchSpotifyLyricsSubtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _searchSpotifyLyrics(context, ref, currentSong);
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_music, color: Colors.orange),
                title: Text(l10n.searchFromMusixmatch, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                subtitle: Text(l10n.searchMusixmatchSubtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _searchMusixmatchLyrics(context, ref, currentSong);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ],
        );
      },
    );
  }

  void _searchAppleMusicLyrics(BuildContext context, WidgetRef ref, dynamic currentSong) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = "${currentSong.title} ${currentSong.artist}";

    // 1. Show Loading Search Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(l10n.searchingAppleMusic, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(l10n.findingMatches, style: const TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );

    // 2. Perform Search
    final results = await ITunesApiService.searchSongs(query, limit: 10);
    
    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noResultsAppleMusic)),
      );
      return;
    }

    // 3. Show Results Selection Dialog
    SongMetadata? selectedSong = await showDialog<SongMetadata>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(l10n.selectSong, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: results.length,
            separatorBuilder: (c, i) => Divider(color: isDark ? Colors.white10 : Colors.black12),
            itemBuilder: (ctx, index) {
              final song = results[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: song.albumArtUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(song.albumArtUrl, width: 40, height: 40, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.music_note, size: 40),
                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                onTap: () => Navigator.pop(ctx, song),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(l10n.cancel)),
        ],
      ),
    );

    if (selectedSong == null || selectedSong.youtubeUrl == null || selectedSong.youtubeUrl!.isEmpty) {
      return;
    }

    if (!context.mounted) return;

    // 4. Download Lyrics via VPS
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(l10n.downloadingLyrics, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(l10n.fetchingLyricsFromServer, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54))),
          ],
        ),
      ),
    );

    final lyricsUrl = await AppleMusicBackendService.requestLyricsDownload(
      selectedSong.youtubeUrl!, // The iTunes service maps trackViewUrl to youtubeUrl
      title: selectedSong.title,
      artist: selectedSong.artist,
    );

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (lyricsUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedDownloadAppleMusic)),
      );
      return;
    }

    // 5. Fetch raw text and import
    try {
      final response = await http.get(Uri.parse(lyricsUrl)).timeout(const Duration(seconds: 15));
      if (!context.mounted) return;
      if (response.statusCode == 200) {
        final rawText = response.body;
        if (rawText.trim().isNotEmpty) {
          ref.read(lyricsProvider.notifier).loadLyricsFromContent(rawText);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.lyricsImportedSuccess),
              backgroundColor: Colors.green,
            ),
          );
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.receivedEmptyLyrics)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to fetch lyrics text. HTTP ${response.statusCode}")),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching lyrics: $e")),
      );
    }
  }

  void _searchSpotifyLyrics(BuildContext context, WidgetRef ref, dynamic currentSong) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(l10n.downloadingFromSpotify, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(l10n.fetchingLyrics, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54))),
          ],
        ),
      ),
    );

    final rawLyrics = await SpotifyLyricsService.fetchSpotifyLyrics(currentSong.title, currentSong.artist);
    
    if (!context.mounted) return;
    Navigator.pop(context); // close loading

    if (rawLyrics != null && rawLyrics.trim().isNotEmpty) {
      ref.read(lyricsProvider.notifier).loadLyricsFromContent(rawLyrics);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lyricsImportedSpotify), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noLyricsSpotify)),
      );
    }
  }

  void _searchMusixmatchLyrics(BuildContext context, WidgetRef ref, dynamic currentSong) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(l10n.downloadingFromMusixmatch, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(l10n.fetchingLyrics, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54))),
          ],
        ),
      ),
    );

    final rawLyrics = await SpotifyLyricsService.fetchMusixmatchLyrics(currentSong.title, currentSong.artist);
    
    if (!context.mounted) return;
    Navigator.pop(context); // close loading

    if (rawLyrics != null && rawLyrics.trim().isNotEmpty) {
      ref.read(lyricsProvider.notifier).loadLyricsFromContent(rawLyrics);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lyricsImportedMusixmatch), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noLyricsMusixmatch)),
      );
    }
  }
}
