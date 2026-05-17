import 'dart:io'; // Platform check
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../providers/player_provider.dart';
import '../../providers/timer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/interface_provider.dart';
import '../../providers/equalizer_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../providers/library_presentation_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../models/song_model.dart';
import '../../utils/layout_engine.dart';
import '../screens/full_screen_player.dart';
import '../screens/mobile_full_player.dart';
import '../screens/tablet_full_player.dart';
import '../../l10n/app_localizations.dart';
import 'smart_art.dart';
import 'timer_display.dart';
import 'audio_wave_visualizer.dart';
import 'equalizer_sheet.dart';
import 'version_selection_dialog.dart';
import 'song_context_menu.dart';
import 'song_info_dialog.dart';
import '../../services/audio_info_service.dart';
import '../../services/tray_service.dart';
import 'marquee_text.dart';
import 'audio_output_dialog.dart';
import 'player/device_selector_dialog.dart';

enum TimeUnit { hour, minute, second }

class PlayerBar extends ConsumerStatefulWidget {
  const PlayerBar({super.key});

  @override
  ConsumerState<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends ConsumerState<PlayerBar> {
  bool _isArtistHovered = false;
  bool _isTitleHovered = false;

  // Audio Quality Badge
  AudioInfo? _audioInfo;
  String? _lastFilePath;
  bool _isLoadingQuality = false;

  Future<void> _fetchAudioInfo(String? filePath) async {
    if (filePath == null) {
      if (mounted) setState(() => _audioInfo = null);
      return;
    }

    // Redundancy check: If we already have info OR are currently fetching for this path, stop.
    if (_lastFilePath == filePath && (_audioInfo != null || _isLoadingQuality))
      return;

    _lastFilePath = filePath;
    if (mounted) setState(() => _isLoadingQuality = true);

    try {
      // Ensure we pass a non-null String
      final info =
          await AudioInfoService().getAudioInfo(filePath, isPriority: true);
      if (mounted && _lastFilePath == filePath) {
        setState(() {
          _audioInfo = info;
          _isLoadingQuality = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingQuality = false);
    }
  }

  Widget _buildQualityBadgeWidget(bool isDark) {
    if (_audioInfo == null) return const SizedBox.shrink();

    final label = _audioInfo!.qualityLabel;
    final isHiRes = label.contains('Hi-Res');
    final isCdQuality = label.contains('CD');
    final isLossless = _audioInfo!.isLossless;

    String text;
    Color color;

    if (isHiRes) {
      text = "HI-RES";
      color = Colors.amber;
    } else if (isCdQuality || isLossless) {
      text = "LOSSLESS";
      color = isCdQuality ? Colors.cyan : Colors.blue;
    } else if (label == 'High Quality') {
      text = "HQ";
      color = Colors.green;
    } else {
      return const SizedBox.shrink();
    }

    final primaryColor = isDark ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        borderRadius: BorderRadius.circular(4),
        color: primaryColor.withValues(alpha: 0.1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return "0:00";
    final duration = Duration(seconds: seconds.round());
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final eq = ref.watch(equalizerProvider);

    final song = playerState.currentSong;
    final hasSong = song != null;

    // 1. Handle Song Changes and Initial Load

    if (song?.filePath != _lastFilePath) {
      // Update tracker immediately to prevent loop
      _lastFilePath = song?.filePath;

      // Reset info and fetch new
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 🚀 ALWAYS clear old quality info when file path changes to prevent stale badges
        if (mounted) setState(() => _audioInfo = null);

        // Fetch new info (either for new song or new path)
        _fetchAudioInfo(song?.filePath);
      });
    }

    // 2. Listen for buffering completion (when file is fully downloaded/ready)
    // This allows updating the badge from "Unknown" (or nothing) to actual quality once file exists
    ref.listen(playerProvider.select((s) => s.isBuffering), (prev, next) {
      if (prev == true && next == false) {
        // Buffering finished, force re-fetch properly
        _fetchAudioInfo(song?.filePath);
      }
    });

    // Initial fetch if needed (e.g. on first load)
    if (hasSong && _lastFilePath != song.filePath) {
      _lastFilePath = song.filePath;
      // Use microtask to avoid setState during build
      Future.microtask(() => _fetchAudioInfo(song.filePath));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;
    final l10n = AppLocalizations.of(context)!;

    // 🚀 MOBILE: Show simplified mini player bar
    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (isMobile) {
      // 🚀 TABLET: Show enhanced player bar with more info and controls
      if (LayoutEngine.isTablet(context)) {
        return _buildTabletPlayerBar(context, playerState, notifier, song,
            hasSong, isDark, settings, l10n);
      }
      return _buildMobilePlayerBar(context, playerState, notifier, song,
          hasSong, isDark, settings, l10n);
    }

    // DYNAMIC COLOR LOGIC (Desktop only)
    Color visualizerColor = settings.accentColor;

    if (settings.syncThemeWithAlbumArt) {
      if (playerState.dominantColor != null) {
        visualizerColor = playerState.dominantColor!;
      }
    }

    final disabledColor = Colors.grey.withValues(alpha: 0.3);

    // Dynamic Slider Logic
    double currentPos = playerState.currentPosition;
    double totalDur = playerState.totalDuration;
    double sliderMax = totalDur;
    if (sliderMax < currentPos) sliderMax = currentPos;
    if (sliderMax <= 0) sliderMax = 1.0;
    double sliderValue = currentPos;
    if (sliderValue > sliderMax) sliderValue = sliderMax;

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Stack(
        children: [
          // -----------------------------------------------------------
          // LAYER 2: VISUALIZER
          // -----------------------------------------------------------
          if (hasSong && settings.enableVisualizer)
            Positioned.fill(
              child: Opacity(
                opacity: settings.visualizerOpacity,
                child: TweenAnimationBuilder<Color?>(
                  duration: const Duration(milliseconds: 500),
                  tween: ColorTween(
                      begin: settings.accentColor, end: visualizerColor),
                  builder: (context, animColor, child) {
                    return AudioWaveVisualizer(
                      isPlaying: playerState.isPlaying,
                      color: animColor ?? settings.accentColor,
                      isRainbow: settings.isVisualizerRainbow,
                      barCount: 60,
                      style: settings.visualizerStyle,
                    );
                  },
                ),
              ),
            ),

          // -----------------------------------------------------------
          // LAYER 3: FOREGROUND CONTENT
          // -----------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // --- LEFT: Art & Text ---
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      // HERO WRAPPER
                      Hero(
                        tag: 'current_artwork',
                        // ✅ FIX: Use SmartArt here
                        child: hasSong
                            ? SmartArt(
                                path: song.filePath,
                                size: 56,
                                borderRadius: 4,
                                onlineArtUrl: song.onlineArtUrl,
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(4)),
                                child: Icon(Icons.music_note,
                                    color: primaryColor.withValues(alpha: 0.5)),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Song Title with right-click context menu
                            MouseRegion(
                              cursor: hasSong
                                  ? SystemMouseCursors.click
                                  : SystemMouseCursors.basic,
                              onEnter: (_) =>
                                  setState(() => _isTitleHovered = true),
                              onExit: (_) =>
                                  setState(() => _isTitleHovered = false),
                              child: GestureDetector(
                                onSecondaryTapUp: hasSong
                                    ? (details) => _showTitleContextMenu(
                                        context,
                                        details.globalPosition,
                                        song,
                                        l10n)
                                    : null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: MarqueeText(
                                        text: hasSong
                                            ? song.title
                                            : l10n.noSongPlaying,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: hasSong
                                              ? primaryColor
                                              : Colors.grey,
                                          decoration:
                                              (_isTitleHovered && hasSong)
                                                  ? TextDecoration.underline
                                                  : null,
                                        ),
                                        velocity: 30,
                                        blankSpace: 40,
                                      ),
                                    ),
                                    _buildQualityBadgeWidget(isDark),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            MouseRegion(
                              cursor: hasSong
                                  ? SystemMouseCursors.click
                                  : SystemMouseCursors.basic,
                              onEnter: (_) =>
                                  setState(() => _isArtistHovered = true),
                              onExit: (_) =>
                                  setState(() => _isArtistHovered = false),
                              child: GestureDetector(
                                onTap: hasSong
                                    ? () {
                                        // NAVIGATE TO ARTIST DETAIL
                                        ref
                                            .read(navigationStackProvider
                                                .notifier)
                                            .push(
                                              NavigationItem(
                                                type: NavigationType.artist,
                                                data: ArtistSelection(
                                                  artistName: song.artist,
                                                  songs: [], // Empty list allows detail page to fetch/filter
                                                ),
                                              ),
                                            );
                                      }
                                    : null,
                                child: Text(
                                  hasSong
                                      ? song.artist
                                      : l10n.selectTrackToStart,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    decoration: (_isArtistHovered && hasSong)
                                        ? TextDecoration.underline
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- CENTER: Controls & Seekbar ---
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shuffle_rounded),
                            iconSize: 20,
                            color: !hasSong
                                ? disabledColor
                                : (playerState.isShuffle
                                    ? settings.accentColor
                                    : Colors.grey),
                            onPressed: hasSong ? notifier.toggleShuffle : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            icon: Icon(Icons.skip_previous_rounded,
                                color: hasSong ? primaryColor : disabledColor),
                            iconSize: 28,
                            onPressed: hasSong ? notifier.playPrevious : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 24),
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: hasSong
                                  ? (isDark ? Colors.white : Colors.black)
                                  : disabledColor,
                              shape: BoxShape.circle,
                              boxShadow: hasSong
                                  ? [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: IconButton(
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Icon(
                                  playerState.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  key: ValueKey<bool>(playerState.isPlaying),
                                  color: isDark ? Colors.black : Colors.white,
                                  size: 28,
                                ),
                              ),
                              onPressed: hasSong ? notifier.togglePlay : null,
                            ),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            icon: Icon(Icons.skip_next_rounded,
                                color: hasSong ? primaryColor : disabledColor),
                            iconSize: 28,
                            onPressed: hasSong ? notifier.playNext : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            icon: Icon(playerState.loopMode == ja.LoopMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded),
                            iconSize: 20,
                            color: !hasSong
                                ? disabledColor
                                : (playerState.loopMode == ja.LoopMode.off
                                    ? Colors.grey
                                    : settings.accentColor),
                            onPressed: hasSong ? notifier.cycleLoopMode : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatTime(hasSong ? sliderValue : 0),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // 🚀 BUFFERING ANIMATION - Thin animated line on track
                                if (playerState.isBuffering)
                                  Positioned(
                                    left: 12,
                                    right: 12,
                                    child: SizedBox(
                                      height: 2,
                                      child: LinearProgressIndicator(
                                        backgroundColor:
                                            Colors.grey.withValues(alpha: 0.3),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          settings.accentColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Normal Slider
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 4),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 10),
                                    activeTrackColor: hasSong
                                        ? (isDark ? Colors.white : Colors.black)
                                        : disabledColor,
                                    inactiveTrackColor: playerState.isBuffering
                                        ? Colors
                                            .transparent // Hide track when buffering
                                        : Colors.grey.withValues(alpha: 0.3),
                                    thumbColor: hasSong
                                        ? (isDark ? Colors.white : Colors.black)
                                        : disabledColor,
                                    disabledActiveTrackColor: disabledColor,
                                    disabledThumbColor: disabledColor,
                                  ),
                                  child: Slider(
                                    value: hasSong ? sliderValue : 0.0,
                                    min: 0.0,
                                    max: sliderMax,
                                    onChanged: hasSong
                                        ? (val) => notifier.seek(val)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatTime(hasSong ? totalDur : 0),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- RIGHT: Volume & Menu ---
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Lyrics Button
                      TweenAnimationBuilder<Color?>(
                          duration: const Duration(milliseconds: 500),
                          tween: ColorTween(
                              begin: settings.accentColor,
                              end: visualizerColor),
                          builder: (context, animColor, child) {
                            final buttonColor = settings.syncThemeWithAlbumArt
                                ? (animColor ?? settings.accentColor)
                                : settings.accentColor;

                            return IconButton(
                              icon: const Icon(Icons.lyrics_outlined),
                              tooltip: l10n.lyricsTooltip,
                              iconSize: 20,
                              color: !hasSong
                                  ? disabledColor
                                  : (playerState.isLyricsVisible
                                      ? buttonColor
                                      : Colors.grey),
                              onPressed: hasSong
                                  ? () => notifier.setLyricsVisibility(
                                      !playerState.isLyricsVisible)
                                  : null,
                            );
                          }),

                      IconButton(
                        icon: const Icon(Icons.queue_music),
                        tooltip: l10n.queueTooltip,
                        iconSize: 20,
                        color: Colors.grey,
                        onPressed: () => Scaffold.of(context).openEndDrawer(),
                      ),

                      // --- MENU BUTTON ---
                      Tooltip(
                        message: l10n.moreOptionsTooltip,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: Colors.grey, size: 20),
                          color: Theme.of(context).cardColor,
                          onSelected: (value) {
                            if (value == 'timer') {
                              _showTimerDialog(context, ref, l10n);
                            } else if (value == 'equalizer') {
                              // LAUNCH EQUALIZER SHEET
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => const EqualizerSheet(),
                              );
                            } else if (value == 'version') {
                              // SELECT VERSION
                              if (hasSong) {
                                _showVersionSelector(context, ref, song);
                              }
                            } else if (value == 'connect_device') {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) =>
                                    const DeviceSelectorDialog(),
                              );
                            } else if (value == 'mini') {
                              ref
                                  .read(interfaceProvider.notifier)
                                  .enterMiniPlayer();
                            } else if (value == 'minimize_tray') {
                              TrayService().minimizeToTray();
                            } else if (value == 'song_info') {
                              // SHOW SONG INFORMATION DIALOG
                              if (hasSong) {
                                SongInfoDialog.show(context, song);
                              }
                            } else if (value == 'audio_output') {
                              if (hasSong) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AudioOutputDialog(
                                    audioInfo: _audioInfo,
                                    filePath: song.filePath,
                                  ),
                                );
                              }
                            }
                          },
                          itemBuilder: (context) {
                            final isTimerActive =
                                ref.read(timerProvider).isActive;
                            return [
                              // 1. SLEEP TIMER OPTION
                              PopupMenuItem(
                                value: 'timer',
                                child: Row(
                                  children: [
                                    Icon(
                                      isTimerActive
                                          ? Icons.timer_rounded
                                          : Icons.timer_outlined,
                                      color: isTimerActive
                                          ? settings.accentColor
                                          : primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    const TimerDisplay(),
                                  ],
                                ),
                              ),
                              // 2. EQUALIZER OPTION
                              PopupMenuItem(
                                value: 'equalizer',
                                child: Row(
                                  children: [
                                    Icon(Icons.equalizer_rounded,
                                        color: primaryColor, size: 20),
                                    const SizedBox(width: 12),
                                    Text(
                                        '${l10n.equalizer} (${eq.isEnabled ? "On" : "Off"})',
                                        style: TextStyle(color: primaryColor)),
                                  ],
                                ),
                              ),
                              // 3. SELECT VERSION OPTION
                              if (hasSong)
                                PopupMenuItem(
                                  value: 'version',
                                  child: Row(
                                    children: [
                                      Icon(Icons.switch_video_rounded,
                                          color: primaryColor, size: 20),
                                      const SizedBox(width: 12),
                                      Text(l10n.selectVersion,
                                          style:
                                              TextStyle(color: primaryColor)),
                                    ],
                                  ),
                                ),

                              // 4. MINI PLAYER OPTION (Desktop Only)
                              if (Platform.isWindows || Platform.isMacOS)
                                PopupMenuItem(
                                  value: 'mini',
                                  child: Row(
                                    children: [
                                      Icon(Icons.picture_in_picture_alt_rounded,
                                          color: primaryColor, size: 20),
                                      const SizedBox(width: 12),
                                      Text(l10n.miniPlayer,
                                          style:
                                              TextStyle(color: primaryColor)),
                                    ],
                                  ),
                                ),

                              // 4.5 MINIMIZE TO TRAY OPTION (Desktop Only)
                              if (Platform.isWindows ||
                                  Platform.isMacOS ||
                                  Platform.isLinux)
                                PopupMenuItem(
                                  value: 'minimize_tray',
                                  child: Row(
                                    children: [
                                      Icon(Icons.call_received_rounded,
                                          color: primaryColor, size: 20),
                                      const SizedBox(width: 12),
                                      Text(l10n.minimizeToTray,
                                          style:
                                              TextStyle(color: primaryColor)),
                                    ],
                                  ),
                                ),

                              // 5. CONNECT TO A DEVICE OPTION
                              PopupMenuItem(
                                value: 'connect_device',
                                child: Row(
                                  children: [
                                    Icon(Icons.devices_rounded,
                                        color: primaryColor, size: 20),
                                    const SizedBox(width: 12),
                                    Text(l10n.connectToADevice,
                                        style: TextStyle(color: primaryColor)),
                                  ],
                                ),
                              ),

                              // 6. SONG INFORMATION OPTION
                              if (hasSong)
                                PopupMenuItem(
                                  value: 'song_info',
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded,
                                          color: primaryColor, size: 20),
                                      const SizedBox(width: 12),
                                      Text(l10n.songInformation,
                                          style:
                                              TextStyle(color: primaryColor)),
                                    ],
                                  ),
                                ),

                              // 7. AUDIO OUTPUT OPTION
                              if (hasSong)
                                PopupMenuItem(
                                  value: 'audio_output',
                                  child: Row(
                                    children: [
                                      Icon(Icons.output_rounded,
                                          color: primaryColor, size: 20),
                                      const SizedBox(width: 12),
                                      Text(l10n.audioOutput,
                                          style:
                                              TextStyle(color: primaryColor)),
                                    ],
                                  ),
                                ),
                            ];
                          },
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Volume
                      Tooltip(
                        message: playerState.volume == 0
                            ? l10n.unmuteTooltip
                            : l10n.muteTooltip,
                        child: IconButton(
                          icon: Icon(
                            playerState.volume == 0
                                ? Icons.volume_off_rounded
                                : playerState.volume < 0.5
                                    ? Icons.volume_down_rounded
                                    : Icons.volume_up_rounded,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: notifier.toggleMute,
                        ),
                      ),

                      SizedBox(
                        width: 70,
                        height: 20,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 4),
                            overlayShape:
                                const RoundSliderOverlayShape(overlayRadius: 6),
                            activeTrackColor: Colors.grey,
                            inactiveTrackColor:
                                Colors.grey.withValues(alpha: 0.3),
                            thumbColor: Colors.grey,
                          ),
                          child: Slider(
                            value: playerState.volume,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (val) => notifier.setVolume(val),
                          ),
                        ),
                      ),

                      SizedBox(
                        width: 35,
                        child: Text(
                          "${(playerState.volume * 100).toInt()}%",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.bold),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Full Screen Button
                      Tooltip(
                        message: l10n.fullScreenPlayerTooltip,
                        child: IconButton(
                          icon: Image.asset(
                            'assets/win_icon_fullscreen.png',
                            width: 20,
                            height: 20,
                            color: hasSong ? Colors.grey : disabledColor,
                          ),
                          color: hasSong ? Colors.grey : disabledColor,
                          onPressed: hasSong
                              ? () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      transitionDuration:
                                          const Duration(milliseconds: 800),
                                      reverseTransitionDuration:
                                          const Duration(milliseconds: 500),
                                      pageBuilder: (context, animation,
                                              secondaryAnimation) =>
                                          const FullScreenPlayer(),
                                      transitionsBuilder: (context, animation,
                                          secondaryAnimation, child) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SONG TITLE CONTEXT MENU ---
  void _showTitleContextMenu(BuildContext context, Offset position,
      SongModel song, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = Theme.of(context).colorScheme.primary;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: Theme.of(context).cardColor,
      items: [
        PopupMenuItem<String>(
          value: 'add_to_playlist',
          child: Row(
            children: [
              Icon(Icons.playlist_add, color: textColor, size: 20),
              const SizedBox(width: 12),
              Text(l10n.addToPlaylist, style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'add_to_favorite',
          child: Row(
            children: [
              Icon(Icons.favorite_border, color: Colors.redAccent, size: 20),
              const SizedBox(width: 12),
              Text(l10n.addToFavorite, style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'download',
          child: Row(
            children: [
              Icon(Icons.download_rounded, color: accentColor, size: 20),
              const SizedBox(width: 12),
              Text(l10n.downloadSong, style: TextStyle(color: textColor)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'add_to_playlist') {
        // Use song context menu handler for Add to Playlist
        SongContextMenuRegion.handleAction(
            context, ref, SongAction.addToPlaylist, song);
      } else if (value == 'add_to_favorite') {
        // Add to favorites
        SongContextMenuRegion.handleAction(
            context, ref, SongAction.addToFavorite, song);
      } else if (value == 'download') {
        // Download song
        SongContextMenuRegion.handleAction(
            context, ref, SongAction.download, song);
      }
    });
  }

  // --- TIMER DIALOG METHODS (Kept as is) ---
  void _showTimerDialog(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final dialogColor = Theme.of(context).cardColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(l10n.sleepTimer, style: TextStyle(color: textColor)),
        content: SizedBox(
          width: 240, // 🚀 Slimmer width to avoid "fat" look
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _timerOption(
                  context, ref, 15, l10n.minutesDuration(15), textColor, l10n),
              _timerOption(
                  context, ref, 30, l10n.minutesDuration(30), textColor, l10n),
              _timerOption(
                  context, ref, 45, l10n.minutesDuration(45), textColor, l10n),
              _timerOption(
                  context, ref, 60, l10n.hoursDuration(1), textColor, l10n),
              const Divider(),
              ListTile(
                leading: Icon(Icons.edit, color: textColor),
                title:
                    Text(l10n.customTime, style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomTimerInput(context, ref, l10n);
                },
              ),
              if (ref.watch(timerProvider).isActive ||
                  ref.watch(playerProvider).isSleepPending) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.timer_off_rounded,
                      color: Colors.redAccent),
                  title: Text(l10n.turnOffTimer,
                      style: const TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    ref.read(timerProvider.notifier).cancelTimer();
                    ref.read(playerProvider.notifier).setSleepPending(false);
                    Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _timerOption(BuildContext context, WidgetRef ref, int minutes,
      String label, Color textColor, AppLocalizations l10n) {
    return ListTile(
      title: Text(label, style: TextStyle(color: textColor)),
      onTap: () {
        ref.read(timerProvider.notifier).startTimer(Duration(minutes: minutes));
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.musicWillStopIn(label))));
      },
    );
  }

  void _showCustomTimerInput(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final TextEditingController controller = TextEditingController();
    TimeUnit unit = TimeUnit.minute;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title:
                  Text(l10n.setCustomTimer, style: TextStyle(color: textColor)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: l10n.enterDuration,
                      hintStyle:
                          TextStyle(color: textColor.withValues(alpha: 0.5)),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ToggleButtons(
                    isSelected: [
                      unit == TimeUnit.hour,
                      unit == TimeUnit.minute,
                      unit == TimeUnit.second,
                    ],
                    onPressed: (index) {
                      setState(() {
                        if (index == 0) unit = TimeUnit.hour;
                        if (index == 1) unit = TimeUnit.minute;
                        if (index == 2) unit = TimeUnit.second;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    selectedColor: Colors.white,
                    fillColor: accentColor,
                    color: textColor,
                    children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(l10n.hourShort)),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(l10n.minuteShort)),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(l10n.secondShort)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel, style: TextStyle(color: textColor)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                  onPressed: () {
                    final value = int.tryParse(controller.text);
                    if (value != null && value > 0) {
                      Duration duration;
                      String message;
                      if (unit == TimeUnit.hour) {
                        duration = Duration(hours: value);
                        message = l10n.timerSetForHours(value);
                      } else if (unit == TimeUnit.minute) {
                        duration = Duration(minutes: value);
                        message = l10n.timerSetForMinutes(value);
                      } else {
                        duration = Duration(seconds: value);
                        message = l10n.timerSetForSeconds(value);
                      }

                      ref.read(timerProvider.notifier).startTimer(duration);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(message)));
                    }
                  },
                  child: Text(l10n.start,
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showVersionSelector(
      BuildContext context, WidgetRef ref, SongModel song) async {
    final result = await showDialog(
      context: context,
      builder: (context) => VersionSelectionDialog(
        initialQuery: "${song.title} ${song.artist}",
        song: song,
      ),
    );

    if (result != null) {
      // User selected a new version
      // We need to cast result to YoutubeSearchResult since showDialog is generic
      // But we can just use dynamic dispatch or cast
      final newVersion = result; // as YoutubeSearchResult

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.switchingTo(newVersion.title))),
      );

      ref.read(playerProvider.notifier).swapCurrentSongVersion(
            newVersion.url,
          );
    }
  }

  // 🚀 TABLET ENHANCED PLAYER BAR (72dp, single row with seek + controls)
  Widget _buildTabletPlayerBar(
    BuildContext context,
    PlayerState playerState,
    PlayerNotifier notifier,
    SongModel? song,
    bool hasSong,
    bool isDark,
    SettingsState settings,
    AppLocalizations l10n,
  ) {
    final isLandscape = LayoutEngine.isLandscape(context);

    // Progress calculation
    double currentPos = playerState.currentPosition;
    double totalDur = playerState.totalDuration;
    double sliderMax = totalDur;
    if (sliderMax < currentPos) sliderMax = currentPos;
    if (sliderMax <= 0) sliderMax = 1.0;
    double sliderValue = currentPos;
    if (sliderValue > sliderMax) sliderValue = sliderMax;

    double progress = 0.0;
    if (hasSong && totalDur > 0) {
      progress = currentPos / totalDur;
      if (progress.isNaN || progress.isInfinite) progress = 0.0;
      if (progress > 1.0) progress = 1.0;
    }

    return GestureDetector(
      onTap: hasSong
          ? () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  transitionDuration: const Duration(milliseconds: 300),
                  reverseTransitionDuration: const Duration(milliseconds: 250),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const TabletFullPlayer(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    );
                  },
                ),
              );
            }
          : null,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Album art thumbnail
              hasSong
                  ? SmartArt(
                      path: song!.filePath,
                      size: 48,
                      borderRadius: 6,
                      onlineArtUrl: song.onlineArtUrl,
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.music_note,
                          color: isDark ? Colors.white54 : Colors.black38,
                          size: 24),
                    ),
              const SizedBox(width: 12),

              // Track title and artist name
              SizedBox(
                width: isLandscape ? 160 : 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSong ? song!.title : l10n.noSongPlaying,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: hasSong
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasSong ? song!.artist : l10n.selectTrackToStart,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Seek progress indicator (linear slider)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: hasSong
                            ? settings.accentColor
                            : Colors.grey.withValues(alpha: 0.3),
                        inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                        thumbColor: hasSong
                            ? settings.accentColor
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                      child: Slider(
                        value: hasSong ? sliderValue : 0.0,
                        min: 0.0,
                        max: sliderMax,
                        onChanged: hasSong ? (val) => notifier.seek(val) : null,
                      ),
                    ),
                  ],
                ),
              ),

              // Duration text (landscape only)
              if (isLandscape) ...[
                const SizedBox(width: 8),
                Text(
                  _formatTime(hasSong ? totalDur : 0),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],

              const SizedBox(width: 12),

              // Playback controls: previous, play/pause, next
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.skip_previous_rounded,
                        color: hasSong
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.grey.withValues(alpha: 0.3)),
                    iconSize: 28,
                    onPressed: hasSong ? notifier.playPrevious : null,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: hasSong
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.grey.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        playerState.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: isDark ? Colors.black : Colors.white,
                        size: 24,
                      ),
                      onPressed: hasSong ? notifier.togglePlay : null,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded,
                        color: hasSong
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.grey.withValues(alpha: 0.3)),
                    iconSize: 28,
                    onPressed: hasSong ? notifier.playNext : null,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ],
              ),

              // Favorite/like button (landscape only)
              if (isLandscape) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.favorite_border,
                      color: Colors.redAccent, size: 22),
                  onPressed: hasSong
                      ? () {
                          ref
                              .read(playlistProvider.notifier)
                              .addToLikedSongs(song!);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.addToFavorite)),
                          );
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 MOBILE MINI PLAYER BAR (Floating design) + Bottom Navigation
  Widget _buildMobilePlayerBar(
    BuildContext context,
    PlayerState playerState,
    PlayerNotifier notifier,
    SongModel? song,
    bool hasSong,
    bool isDark,
    SettingsState settings,
    AppLocalizations l10n,
  ) {
    // Progress calculation
    double progress = 0.0;
    if (hasSong && playerState.totalDuration > 0) {
      progress = playerState.currentPosition / playerState.totalDuration;
      if (progress.isNaN || progress.isInfinite) progress = 0.0;
      if (progress > 1.0) progress = 1.0;
    }

    final presentationNotifier = ref.read(libraryPresentationProvider.notifier);
    final currentView = ref.watch(libraryPresentationProvider).currentView;
    final primaryColor = isDark ? Colors.white : Colors.black;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating Mini Player
        Container(
          margin: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
          child: GestureDetector(
            onTap: hasSong
                ? () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque:
                            false, // 🚀 Allow seeing behind when dragging down
                        transitionDuration: const Duration(milliseconds: 300),
                        reverseTransitionDuration:
                            const Duration(milliseconds: 250),
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const MobileFullPlayer(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          );
                        },
                      ),
                    );
                  }
                : null,
            // 🚀 GESTURE: Pull Up to Expand
            // 🚀 GESTURE: Pull Up to Expand
            onVerticalDragEnd: (details) {
              if (hasSong && details.primaryVelocity! < -150) {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false, // 🚀 Allow seeing behind when dragging down
                    transitionDuration: const Duration(milliseconds: 300),
                    reverseTransitionDuration:
                        const Duration(milliseconds: 250),
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const MobileFullPlayer(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: child,
                      );
                    },
                  ),
                );
              }
            },
            child: TweenAnimationBuilder<Color?>(
              // 🚀 ANIMATE color changes for smooth transitions
              duration: const Duration(milliseconds: 500),
              tween: ColorTween(
                begin: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                // Mobile always uses dominant color (no setting check)
                end: playerState.dominantColor ??
                    (isDark ? const Color(0xFF1E1E1E) : Colors.white),
              ),
              builder: (context, animatedColor, child) {
                // Determine if we're using a colored background
                final hasCustomColor = playerState.dominantColor != null;

                return Container(
                  height: 60,
                  decoration: BoxDecoration(
                    // 🚀 Use dominant album color with reduced opacity
                    color: hasCustomColor
                        ? primaryColor.withValues(
                            alpha: 0.1) // Much more subtle!
                        : animatedColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Container(
                    // Dark overlay for better text readability
                    decoration: BoxDecoration(
                      color: hasCustomColor
                          ? Colors.black.withValues(alpha: 0.4) // Dark overlay
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Column(
                        children: [
                          // Content
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  // Album art
                                  Hero(
                                    tag: 'mobile_player_art',
                                    child: hasSong
                                        ? SmartArt(
                                            path: song!.filePath,
                                            size: 40,
                                            borderRadius: 6,
                                            onlineArtUrl: song.onlineArtUrl,
                                          )
                                        : Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[800],
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(Icons.music_note,
                                                color: primaryColor.withValues(
                                                    alpha: 0.5),
                                                size: 20),
                                          ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Title and Artist
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: MarqueeText(
                                                  text: hasSong
                                                      ? song!.title
                                                      : l10n.noSongPlaying,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: hasSong
                                                        ? (isDark
                                                            ? Colors.white
                                                            : Colors.black)
                                                        : Colors.grey,
                                                  ),
                                                  velocity:
                                                      25, // Slower on mobile
                                                  blankSpace: 30),
                                            ),
                                            if (hasSong)
                                              _buildQualityBadgeWidget(isDark),
                                          ],
                                        ),
                                        Text(
                                          hasSong
                                              ? song!.artist
                                              : l10n.selectTrackToStart,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Play/Pause button
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: hasSong
                                          ? (isDark
                                              ? Colors.white
                                              : Colors.black)
                                          : Colors.grey.withValues(alpha: 0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        playerState.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: isDark
                                            ? Colors.black
                                            : Colors.white,
                                        size: 20,
                                      ),
                                      onPressed:
                                          hasSong ? notifier.togglePlay : null,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Progress indicator at BOTTOM
                          SizedBox(
                            height: 3,
                            child: playerState.isBuffering
                                // Buffering: Show animated indeterminate progress
                                ? LinearProgressIndicator(
                                    backgroundColor: isDark
                                        ? Colors.white12
                                        : Colors.black12,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      settings.accentColor,
                                    ),
                                  )
                                // Normal: Show fixed progress value
                                : LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: isDark
                                        ? Colors.white12
                                        : Colors.black12,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      settings.accentColor,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ), // Close dark overlay Container
                );
              },
            ),
          ),
        ),
        // Bottom Navigation Bar
        Container(
          padding:
              const EdgeInsets.only(left: 24, right: 24, bottom: 8, top: 4),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Home
              _buildNavButton(
                icon: Icons.home_rounded,
                label: "Home",
                isActive: currentView == LibraryView.browse,
                onTap: () {
                  ref.read(navigationStackProvider.notifier).clear();
                  presentationNotifier.setView(LibraryView.browse);
                },
                isDark: isDark,
                accentColor: settings.accentColor,
              ),
              // Search
              _buildNavButton(
                icon: Icons.search_rounded,
                label: "Search",
                isActive: currentView == LibraryView.search,
                onTap: () {
                  ref.read(navigationStackProvider.notifier).clear();
                  presentationNotifier.setView(LibraryView.search);
                },
                isDark: isDark,
                accentColor: settings.accentColor,
              ),
              // Library
              _buildNavButton(
                icon: Icons.folder_rounded,
                label: "Library",
                isActive: currentView == LibraryView.localLibrary,
                onTap: () {
                  ref.read(navigationStackProvider.notifier).clear();
                  presentationNotifier.setView(LibraryView.localLibrary);
                },
                isDark: isDark,
                accentColor: settings.accentColor,
              ),
              // Settings
              _buildNavButton(
                icon: Icons.settings_rounded,
                label: "Settings",
                isActive: currentView == LibraryView.settings,
                onTap: () {
                  ref.read(navigationStackProvider.notifier).clear();
                  presentationNotifier.setView(LibraryView.settings);
                },
                isDark: isDark,
                accentColor: settings.accentColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
    required Color accentColor,
  }) {
    final color =
        isActive ? accentColor : (isDark ? Colors.grey[500] : Colors.grey[600]);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
