import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/layout_engine.dart';
import '../components/smart_art.dart';
import '../components/queue_sheet.dart';

/// Tablet-optimized full player view with orientation-aware layout.
///
/// - Landscape: two-column layout with album art on the left half and
///   track info + seek bar + controls on the right half.
/// - Portrait: single-column layout with large album art (up to 60% of
///   screen height) followed by track info, seek bar, and controls.
///
/// Reuses [SmartArt] for album art and builds playback controls inline
/// using the same patterns as [MobileFullPlayer].
class TabletFullPlayer extends ConsumerStatefulWidget {
  const TabletFullPlayer({super.key});

  @override
  ConsumerState<TabletFullPlayer> createState() => _TabletFullPlayerState();
}

class _TabletFullPlayerState extends ConsumerState<TabletFullPlayer> {
  // SEEKBAR DRAG STATE
  bool _isDraggingSlider = false;
  double _sliderDragValue = 0.0;

  String _formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return '0:00';
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

    if (song == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text(
            'No music playing',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    // Slider logic
    double currentPos = playerState.currentPosition;
    double totalDur = playerState.totalDuration;
    double sliderMax = totalDur;
    if (sliderMax < currentPos) sliderMax = currentPos;
    if (sliderMax <= 0) sliderMax = 1.0;
    
    double sliderValue = _isDraggingSlider ? _sliderDragValue : currentPos;
    if (sliderValue > sliderMax) sliderValue = sliderMax;
    if (sliderValue < 0) sliderValue = 0;

    final isLandscape = LayoutEngine.isLandscape(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white,
            size: 32,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: isLandscape
            ? _buildLandscapeLayout(
                song, playerState, notifier, settings, sliderValue, sliderMax)
            : _buildPortraitLayout(
                song, playerState, notifier, settings, sliderValue, sliderMax),
      ),
    );
  }

  /// Landscape: two-column layout — album art left, controls right.
  Widget _buildLandscapeLayout(
    dynamic song,
    PlayerState playerState,
    dynamic notifier,
    dynamic settings,
    double sliderValue,
    double sliderMax,
  ) {
    return Row(
      children: [
        // Left half: Album Art
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Constrain art between 280dp min and 480dp max in either dimension
                  final availableWidth = constraints.maxWidth;
                  final availableHeight = constraints.maxHeight;
                  final artSize = availableWidth < availableHeight
                      ? availableWidth.clamp(280.0, 480.0)
                      : availableHeight.clamp(280.0, 480.0);
                  return ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 280,
                      minHeight: 280,
                      maxWidth: 480,
                      maxHeight: 480,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SmartArt(
                          path: song.filePath,
                          onlineArtUrl: song.onlineArtUrl,
                          size: artSize,
                          borderRadius: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // Right half: Track info + seek bar + controls
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                // Track info
                _buildTrackInfo(song),
                const SizedBox(height: 32),
                // Seek bar
                _buildSeekBar(sliderValue, sliderMax, notifier, settings),
                const SizedBox(height: 8),
                // Time labels
                _buildTimeLabels(sliderValue, sliderMax),
                const SizedBox(height: 32),
                // Playback controls
                _buildPlaybackControls(playerState, notifier, settings),
                const SizedBox(height: 24),
                // Secondary controls (shuffle, repeat, queue)
                _buildSecondaryControls(playerState, notifier, settings),
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Portrait: single-column layout — large art (up to 60% height) then controls.
  Widget _buildPortraitLayout(
    dynamic song,
    PlayerState playerState,
    dynamic notifier,
    dynamic settings,
    double sliderValue,
    double sliderMax,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxArtHeight = screenHeight * 0.60;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Album Art — constrained between 280dp min and 480dp max
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Clamp to 280-480dp range, also respecting 60% screen height
                  final artSize = constraints.maxWidth
                      .clamp(280.0, maxArtHeight.clamp(280.0, 480.0));
                  return ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 280,
                      minHeight: 280,
                      maxWidth: 480,
                      maxHeight: 480,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SmartArt(
                          path: song.filePath,
                          onlineArtUrl: song.onlineArtUrl,
                          size: artSize,
                          borderRadius: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            // Track info
            _buildTrackInfo(song),
            const SizedBox(height: 24),
            // Seek bar
            _buildSeekBar(sliderValue, sliderMax,
                ref.read(playerProvider.notifier), settings),
            const SizedBox(height: 8),
            // Time labels
            _buildTimeLabels(sliderValue, sliderMax),
            const SizedBox(height: 24),
            // Playback controls
            _buildPlaybackControls(
                playerState, ref.read(playerProvider.notifier), settings),
            const SizedBox(height: 16),
            // Secondary controls
            _buildSecondaryControls(
                playerState, ref.read(playerProvider.notifier), settings),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Track title and artist name.
  Widget _buildTrackInfo(dynamic song) {
    return Column(
      children: [
        Text(
          song.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          song.artist,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Seek bar slider.
  Widget _buildSeekBar(
    double sliderValue,
    double sliderMax,
    dynamic notifier,
    dynamic settings,
  ) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      child: Slider(
        value: sliderValue,
        min: 0.0,
        max: sliderMax,
        onChangeStart: (val) {
          setState(() {
            _isDraggingSlider = true;
            _sliderDragValue = val;
          });
        },
        onChanged: (val) {
          setState(() {
            _sliderDragValue = val;
          });
        },
        onChangeEnd: (val) async {
          // Wait for the backend engine to fully process the seek
          // before releasing the slider back to the data stream.
          // This completely eliminates the "snap back" visual bug.
          await notifier.seek(val);
          if (mounted) {
            setState(() {
              _isDraggingSlider = false;
            });
          }
        },
      ),
    );
  }

  /// Time labels (current position and total duration).
  Widget _buildTimeLabels(double sliderValue, double sliderMax) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatTime(sliderValue),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            _formatTime(sliderMax),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Primary playback controls: previous, play/pause, next.
  Widget _buildPlaybackControls(
    PlayerState playerState,
    dynamic notifier,
    dynamic settings,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: 48,
          color: Colors.white,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: notifier.playPrevious,
        ),
        const SizedBox(width: 24),
        // Play/Pause
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                playerState.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                key: ValueKey(playerState.isPlaying),
                color: Colors.black,
                size: 40,
              ),
            ),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: notifier.togglePlay,
          ),
        ),
        const SizedBox(width: 24),
        // Next
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 48,
          color: Colors.white,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: notifier.playNext,
        ),
      ],
    );
  }

  /// Secondary controls: shuffle, repeat, queue.
  Widget _buildSecondaryControls(
    PlayerState playerState,
    dynamic notifier,
    dynamic settings,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shuffle
        IconButton(
          icon: const Icon(Icons.shuffle_rounded),
          iconSize: 28,
          color: playerState.isShuffle ? settings.accentColor : Colors.white54,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: notifier.toggleShuffle,
        ),
        const SizedBox(width: 32),
        // Repeat
        IconButton(
          icon: Icon(
            playerState.loopMode == ja.LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
          ),
          iconSize: 28,
          color: playerState.loopMode == ja.LoopMode.off
              ? Colors.white54
              : settings.accentColor,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: notifier.cycleLoopMode,
        ),
        const SizedBox(width: 32),
        // Queue
        IconButton(
          icon: const Icon(Icons.queue_music_rounded),
          iconSize: 28,
          color: Colors.white70,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) => const QueueSheet(),
            );
          },
        ),
      ],
    );
  }
}
