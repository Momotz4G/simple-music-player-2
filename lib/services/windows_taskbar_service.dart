import 'dart:io';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

class WindowsTaskbarService {
  static final WindowsTaskbarService _instance =
      WindowsTaskbarService._internal();
  factory WindowsTaskbarService() => _instance;
  WindowsTaskbarService._internal();

  SMTCWindows? _smtc;
  bool _isInitialized = false;

  // Stored callbacks for reusing in dynamic updates
  Function()? _onPlay;
  Function()? _onPause;
  Function()? _onNext;
  Function()? _onPrevious;

  Future<void> initialize({
    required Function() onPlay,
    required Function() onPause,
    required Function() onNext,
    required Function() onPrevious,
  }) async {
    if (!Platform.isWindows) return;

    // Store them
    _onPlay = onPlay;
    _onPause = onPause;
    _onNext = onNext;
    _onPrevious = onPrevious;

    try {
      // 1. Initialize SMTC (For Media Overlay)
      _smtc = SMTCWindows(
        metadata: const MusicMetadata(
          title: 'Ready',
          artist: 'Simple Music Player',
          album: '',
          thumbnail: null,
        ),
        timeline: const PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: 1000,
          positionMs: 0,
          minSeekTimeMs: 0,
          maxSeekTimeMs: 1000,
        ),
      );

      // 2. Initialize Taskbar Buttons
      await _setTaskbarButtons(isPlaying: false);

      _isInitialized = true;
      _smtc!.setPlaybackStatus(PlaybackStatus.paused);

      // 3. Listen to SMTC events
      _smtc!.buttonPressStream.listen((event) {
        switch (event) {
          case PressedButton.play:
            onPlay();
            break;
          case PressedButton.pause:
            onPause();
            break;
          case PressedButton.next:
            onNext();
            break;
          case PressedButton.previous:
            onPrevious();
            break;
          default:
            break;
        }
      });
    } catch (e) {
      print("Failed to initialize Windows Taskbar: $e");
    }
  }

  /// Helper to set buttons dynamically based on state
  Future<void> _setTaskbarButtons({required bool isPlaying}) async {
    if (!Platform.isWindows) return;

    final String prevIcon = 'assets/win_icon_prev.ico';
    final String nextIcon = 'assets/win_icon_next.ico';
    final String playIcon = 'assets/win_icon_play.ico';
    final String pauseIcon = 'assets/win_icon_pause.ico';

    try {
      await WindowsTaskbar.setThumbnailToolbar([
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon(prevIcon),
          'Previous',
          () {
            _onPrevious?.call();
          },
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon(isPlaying ? pauseIcon : playIcon),
          isPlaying ? 'Pause' : 'Play',
          () {
            if (isPlaying) {
              _onPause?.call();
            } else {
              _onPlay?.call();
            }
          },
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon(nextIcon),
          'Next',
          () {
            _onNext?.call();
          },
        ),
      ]);
    } catch (_) {}
  }

  Future<void> updateMetadata({
    required String title,
    required String artist,
    required String album,
    String? thumbnailPath,
  }) async {
    if (!_isInitialized || _smtc == null) return;
    try {
      // SANITIZE INPUTS (Prevent Rust Panic)
      final safeTitle = title.isEmpty ? "Unknown Title" : title;
      final safeArtist = artist.isEmpty ? "Unknown Artist" : artist;
      final safeAlbum = album.isEmpty ? "Unknown Album" : album;

      String? safeThumbnail = thumbnailPath;

      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        if (thumbnailPath.startsWith("http")) {
          // URLs are generally handled by specific implementations or ignored if unsupported
          // but we'll pass it through as is.
        } else {
          // For local files, verify existence!
          final file = File(thumbnailPath);
          if (!await file.exists()) {
            // print("⚠️ SMTC Warning: Thumbnail file does not exist: $thumbnailPath");
            safeThumbnail = null;
          }
        }
      } else {
        safeThumbnail = null;
      }

      _smtc!.updateMetadata(MusicMetadata(
        title: safeTitle,
        artist: safeArtist,
        album: safeAlbum,
        thumbnail: safeThumbnail,
      ));
    } catch (_) {}
  }

  Future<void> updatePlaybackStatus(bool isPlaying) async {
    if (!_isInitialized || _smtc == null) return;
    _smtc!.setPlaybackStatus(
        isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused);

    // DYNAMIC BUTTON UPDATE
    await _setTaskbarButtons(isPlaying: isPlaying);
  }

  // CHAMELEON MODE (Progress Bar)
  Future<void> updateProgress(int currentMs, int totalMs) async {
    if (!Platform.isWindows) return;
    try {
      WindowsTaskbar.setProgress(currentMs, totalMs);
      WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal);
    } catch (_) {}
  }

  void dispose() {
    _smtc?.dispose();
    _smtc = null;
    if (Platform.isWindows) {
      WindowsTaskbar.resetThumbnailToolbar();
    }
  }
}
