import 'dart:io'; // Platform check
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:qr_flutter/qr_flutter.dart'; // QR Code
import '../../services/pocketbase_service.dart'; // Session ID

import '../../providers/player_provider.dart';
import '../../providers/timer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/interface_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../models/song_model.dart';
import '../screens/full_screen_player.dart';
import 'smart_art.dart';
import 'timer_display.dart';
import 'audio_wave_visualizer.dart';
import 'equalizer_sheet.dart';
import 'version_selection_dialog.dart';
import 'song_context_menu.dart';

enum TimeUnit { hour, minute, second }

class PlayerBar extends ConsumerStatefulWidget {
  const PlayerBar({super.key});

  @override
  ConsumerState<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends ConsumerState<PlayerBar> {
  bool _isArtistHovered = false;
  bool _isTitleHovered = false;

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

    final song = playerState.currentSong;
    final hasSong = song != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;

    // DYNAMIC COLOR LOGIC
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
                                child: const Icon(Icons.music_note,
                                    color: Colors.white24),
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
                                        context, details.globalPosition, song)
                                    : null,
                                child: Text(
                                  hasSong ? song.title : "No Song Playing",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: hasSong ? primaryColor : Colors.grey,
                                    decoration: (_isTitleHovered && hasSong)
                                        ? TextDecoration.underline
                                        : null,
                                  ),
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
                                      : "Select a track to start",
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
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 4),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 10),
                                activeTrackColor: hasSong
                                    ? (isDark ? Colors.white : Colors.black)
                                    : disabledColor,
                                inactiveTrackColor:
                                    Colors.grey.withValues(alpha: 0.3),
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
                              tooltip: "Lyrics",
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
                        tooltip: "Queue",
                        iconSize: 20,
                        color: Colors.grey,
                        onPressed: () => Scaffold.of(context).openEndDrawer(),
                      ),

                      // --- MENU BUTTON ---
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.grey, size: 20),
                        tooltip: "More Options",
                        color: Theme.of(context).cardColor,
                        onSelected: (value) {
                          if (value == 'timer') {
                            _showTimerDialog(context, ref);
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
                              _showVersionSelector(context, ref, song!);
                            }
                          } else if (value == 'remote') {
                            _showRemotePairingDialog();
                          } else if (value == 'mini') {
                            ref
                                .read(interfaceProvider.notifier)
                                .enterMiniPlayer();
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
                                  Text("Equalizer",
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
                                    Text("Select Version",
                                        style: TextStyle(color: primaryColor)),
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
                                    Text("Mini Player",
                                        style: TextStyle(color: primaryColor)),
                                  ],
                                ),
                              ),

                            // 5. REMOTE CONTROL OPTION
                            PopupMenuItem(
                              value: 'remote',
                              child: Row(
                                children: [
                                  Icon(Icons.qr_code_2_rounded,
                                      color: primaryColor, size: 20),
                                  const SizedBox(width: 12),
                                  Text("Connect to Control",
                                      style: TextStyle(color: primaryColor)),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),

                      const SizedBox(width: 8),

                      // Volume
                      IconButton(
                        icon: Icon(
                          playerState.volume == 0
                              ? Icons.volume_off_rounded
                              : playerState.volume < 0.5
                                  ? Icons.volume_down_rounded
                                  : Icons.volume_up_rounded,
                          size: 20,
                          color: Colors.grey,
                        ),
                        tooltip: "Mute",
                        onPressed: notifier.toggleMute,
                      ),

                      SizedBox(
                        width: 70,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 4),
                            overlayShape:
                                const RoundSliderOverlayShape(overlayRadius: 8),
                            activeTrackColor: Colors.grey,
                            inactiveTrackColor: Colors.grey.withOpacity(0.3),
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
                      IconButton(
                        icon: Image.asset(
                          'assets/win_icon_fullscreen.png',
                          width: 20,
                          height: 20,
                          color: hasSong ? Colors.grey : disabledColor,
                        ),
                        color: hasSong ? Colors.grey : disabledColor,
                        tooltip: "Full Screen Player",
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
  void _showTitleContextMenu(
      BuildContext context, Offset position, SongModel song) {
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
              Text("Add to Playlist", style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'add_to_favorite',
          child: Row(
            children: [
              Icon(Icons.favorite_border, color: Colors.redAccent, size: 20),
              const SizedBox(width: 12),
              Text("Add to Favorite", style: TextStyle(color: textColor)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'download',
          child: Row(
            children: [
              Icon(Icons.download_rounded, color: accentColor, size: 20),
              const SizedBox(width: 12),
              Text("Download Song", style: TextStyle(color: textColor)),
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
            context, ref, SongAction.addToFavorites, song);
      } else if (value == 'download') {
        // Download song
        SongContextMenuRegion.handleAction(
            context, ref, SongAction.download, song);
      }
    });
  }

  // --- TIMER DIALOG METHODS (Kept as is) ---
  void _showTimerDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final dialogColor = Theme.of(context).cardColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogColor,
        title: Text("Sleep Timer", style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _timerOption(context, ref, 15, "15 Minutes", textColor),
            _timerOption(context, ref, 30, "30 Minutes", textColor),
            _timerOption(context, ref, 45, "45 Minutes", textColor),
            _timerOption(context, ref, 60, "1 Hour", textColor),
            ListTile(
              leading: Icon(Icons.edit, color: textColor),
              title: Text("Custom Time", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _showCustomTimerInput(context, ref);
              },
            ),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.timer_off_rounded, color: Colors.redAccent),
              title: const Text("Turn Off Timer",
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                ref.read(timerProvider.notifier).cancelTimer();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _timerOption(BuildContext context, WidgetRef ref, int minutes,
      String label, Color textColor) {
    return ListTile(
      title: Text(label, style: TextStyle(color: textColor)),
      onTap: () {
        ref.read(timerProvider.notifier).startTimer(Duration(minutes: minutes));
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Music will stop in $label")));
      },
    );
  }

  void _showCustomTimerInput(BuildContext context, WidgetRef ref) {
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
                  Text("Set Custom Timer", style: TextStyle(color: textColor)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Enter duration...",
                      hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
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
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text("Hr")),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text("Min")),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text("Sec")),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: textColor)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                  onPressed: () {
                    final value = int.tryParse(controller.text);
                    if (value != null && value > 0) {
                      Duration duration;
                      if (unit == TimeUnit.hour) {
                        duration = Duration(hours: value);
                      } else if (unit == TimeUnit.minute) {
                        duration = Duration(minutes: value);
                      } else {
                        duration = Duration(seconds: value);
                      }

                      ref.read(timerProvider.notifier).startTimer(duration);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Timer set for $value ${unit.name}s")));
                    }
                  },
                  child: const Text("Start",
                      style: TextStyle(color: Colors.white)),
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
        SnackBar(content: Text("Switching to: ${newVersion.title}")),
      );

      ref.read(playerProvider.notifier).swapCurrentSongVersion(
            newVersion.url,
          );
    }
  }

  // REMOTE CONTROL DIALOG
  void _showRemotePairingDialog() async {
    // Get the session record ID (not user_id) for security
    final sessionId = await PocketBaseService().getUniqueSessionId();
    if (sessionId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Could not create session.")),
        );
      }
      return;
    }

    // Use session record ID in URL instead of user_id
    final url =
        "https://glittering-basbousa-564237.netlify.app/?sid=$sessionId";

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remote Control"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Scan with your phone to control playback.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(
              "Session: $sessionId",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close")),
        ],
      ),
    );
  }
}
