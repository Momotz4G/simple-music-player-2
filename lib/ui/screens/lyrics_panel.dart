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
  
  // Smooth scroll ticker
  Ticker? _ticker;
  double _smoothPosition = 0;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker!.start();

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
    final sideWidth = showActions ? (isMobile ? 48.0 : 180.0) : 48.0;

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

    return GestureDetector(
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
                                              _pickAndImportLyrics(ref);
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
                                        () => _pickAndImportLyrics(ref),
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
                !_isEditing)
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
            if (lyricsState.parsedLyrics.isNotEmpty)
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
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ],
      ),
    );

    if (format == null) return;

    try {
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
      if (index == -1 && _activeLyricIndex >= 0) {
        setState(() => _activeLyricIndex = -1);
        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: 0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutQuart,
            alignment: 0.0,
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
      _itemScrollController.scrollTo(
        index: _activeLyricIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutQuart,
        alignment: 0.45,
      );
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
    return Listener(
      onPointerDown: (_) => _isUserScrolling = true,
      onPointerUp: (_) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _isUserScrolling = false;
        });
      },
      child: ScrollablePositionedList.builder(
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: lyrics.length + 1,
        itemBuilder: (context, index) {
          if (index == lyrics.length) {
            return SizedBox(height: screenHeight * 0.5);
          }

          final line = lyrics[index];
          final isActive = index == _activeLyricIndex;
          double opacity = 0.3;
          if (isActive) {
            opacity = 1.0;
          } else if ((index - _activeLyricIndex).abs() <= 1) {
            opacity = 0.6;
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

          return GestureDetector(
            onTap: () {
              playerNotifier.seek(line.time);
              setState(() => _activeLyricIndex = index);
              _itemScrollController.scrollTo(
                index: index,
                duration: const Duration(milliseconds: 300),
                alignment: 0.5,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 12),
              transform: Matrix4.diagonal3Values(
                  isActive ? 1.05 : 1.0, isActive ? 1.05 : 1.0, 1.0),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Original text
                  !isActive
                      ? Text(
                          line.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
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
                          inactiveColor: inactiveColor,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                  // Romanization
                  if (romanized != null) ...[
                    const SizedBox(height: 4),
                    !isActive
                        ? Text(
                            romanized,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                              color: inactiveColor.withValues(alpha: opacity * 0.6),
                              height: 1.3,
                            ),
                          )
                        : SmoothHighlightText(
                            text: romanized!,
                            startTime: line.time,
                            endTime: (index + 1 < lyrics.length)
                                ? lyrics[index + 1].time
                                : line.time + 5.0,
                            initialPosition: currentPosition,
                            isPlaying: isPlaying,
                            syncOffset: lyricsState.syncOffset,
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            isItalic: true,
                            spacing: 6.0,
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
                        padding: const EdgeInsets.only(top: 4),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildRawLyrics(String text, bool isDark, String? artPath,
      String? onlineArtUrl, bool isPlaying, AppLocalizations l10n) {
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
            text.contains("Error") ? text : l10n.justEnjoyVibes,
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
}
