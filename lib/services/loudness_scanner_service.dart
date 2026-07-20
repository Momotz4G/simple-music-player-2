import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'db_service.dart';
import 'debug_log_service.dart';
import 'player_activity_notifier.dart';

/// Scans local audio files for integrated loudness using ffprobe/ffmpeg
/// and stores the ReplayGain offset (dB) in the Isar database.
///
/// Target loudness: -14 LUFS (matches Spotify/Apple Music/Tidal normalization)
/// ReplayGain = -14 - measuredLUFS  (positive = quiet file needs boost)
///
/// Only runs on desktop (Windows/macOS/Linux) where ffprobe is available.
/// On mobile, embedded REPLAYGAIN_TRACK_GAIN tags are used instead.
class LoudnessScannerService {
  static final LoudnessScannerService _instance =
      LoudnessScannerService._internal();
  factory LoudnessScannerService() => _instance;
  LoudnessScannerService._internal();

  static const double _targetLufs = -14.0;
  static const double _maxGainDb = 12.0; // Cap boost to prevent clipping
  static const double _minGainDb = -12.0; // Cap cut

  bool _isScanning = false;
  bool _cancelRequested = false;

  /// Number of songs scanned in the current session
  int scannedCount = 0;

  final ValueNotifier<String?> statusNotifier = ValueNotifier(null);

  /// Wait until the player is idle (not loading/buffering/playing). Used to
  /// yield disk + event-loop bandwidth to the audio decoder during the
  /// critical first seconds of FLAC/MQA playback. The scanner resumes on
  /// its own when the player goes idle, so the user never has to wait for
  /// "30 seconds after scan" — they just get smooth playback as soon as
  /// they tap a song, and the scanner picks back up between tracks.
  Future<void> _waitWhilePlayerActive() async {
    if (!PlayerActivityNotifier.isActive) return;

    final completer = Completer<void>();
    void listener() {
      if (!PlayerActivityNotifier.isActive && !completer.isCompleted) {
        completer.complete();
      }
    }

    PlayerActivityNotifier.listenable.addListener(listener);
    try {
      // Defensive timeout: even if the listener somehow misses an edge
      // (e.g. native crash), don't deadlock the scan forever.
      await completer.future
          .timeout(const Duration(seconds: 30), onTimeout: () {});
    } finally {
      PlayerActivityNotifier.listenable.removeListener(listener);
    }
  }

  // ─── ffprobe path ──────────────────────────────────────────────────────────

  Future<String?> _getFFprobePath() async {
    if (Platform.isAndroid || Platform.isIOS) return null;
    try {
      final appDir = await getApplicationSupportDirectory();
      final ffprobeName = Platform.isWindows ? 'ffprobe.exe' : 'ffprobe';
      final bundled = File('${appDir.path}/bin/$ffprobeName');
      if (await bundled.exists()) return bundled.path;

      final which = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['ffprobe'],
        runInShell: true,
      );
      if (which.exitCode == 0) {
        return which.stdout.toString().trim().split('\n').first.trim();
      }
    } catch (_) {}
    return null;
  }

  // ─── Single file scan ──────────────────────────────────────────────────────

  /// Measures integrated loudness of [filePath] using ffprobe ebur128.
  /// Returns the ReplayGain offset in dB, or null on failure.
  Future<double?> scanFile(String filePath) async {
    final ffprobe = await _getFFprobePath();
    if (ffprobe == null) {
      // Mobile: try to read embedded tag via ffprobe-less approach
      return _readEmbeddedTag(filePath);
    }

    try {
      // Use ffmpeg with ebur128 filter for accurate ITU-R BS.1770-4 measurement
      // -t 60 limits scan to first 60s for speed (good enough for normalization)
      final result = await Process.run(
        ffprobe,
        [
          '-v',
          'quiet',
          '-of',
          'json',
          '-show_entries',
          'format_tags=REPLAYGAIN_TRACK_GAIN',
          filePath,
        ],
        runInShell: false,
      ).timeout(const Duration(seconds: 10));

      // First try: read embedded ReplayGain tag (instant, no analysis needed)
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final match = RegExp(r'REPLAYGAIN_TRACK_GAIN["\s:]+([+-]?\d+\.?\d*)')
            .firstMatch(output);
        if (match != null) {
          final gain = double.tryParse(match.group(1)!);
          if (gain != null) {
            debugPrint(' [Loudness] Embedded tag: $filePath → ${gain}dB');
            return gain.clamp(_minGainDb, _maxGainDb);
          }
        }
      }

      // Second try: measure with ffmpeg ebur128 (takes 1-5s per file)
      return await _measureWithFfmpeg(filePath, ffprobe);
    } catch (e) {
      debugPrint(' [Loudness] Scan failed for $filePath: $e');
      return null;
    }
  }

  Future<double?> _measureWithFfmpeg(
      String filePath, String ffprobePath) async {
    try {
      final ffmpegPath = ffprobePath.replaceAll('ffprobe', 'ffmpeg');
      if (!await File(ffmpegPath).exists()) return null;

      // Use loudnorm filter — more reliable for M4A/AAC than ebur128
      // Scans the full file for accurate integrated loudness
      final result = await Process.run(
        ffmpegPath,
        [
          '-i',
          filePath,
          '-af',
          'loudnorm=print_format=json',
          '-f',
          'null',
          '-'
        ],
        runInShell: false,
      ).timeout(const Duration(seconds: 60));

      final stderr = result.stderr.toString();

      // loudnorm outputs JSON with input_i (integrated loudness in LUFS)
      final match =
          RegExp(r'"input_i"\s*:\s*"([+-]?\d+\.?\d+)"').firstMatch(stderr);
      if (match != null) {
        final measuredLufs = double.tryParse(match.group(1)!);
        if (measuredLufs != null &&
            measuredLufs.isFinite &&
            measuredLufs > -60.0) {
          final gain = _targetLufs - measuredLufs;
          final clamped = gain.clamp(_minGainDb, _maxGainDb);
          debugPrint(
              ' [Loudness] Measured: $filePath → ${measuredLufs.toStringAsFixed(1)} LUFS → ${clamped.toStringAsFixed(1)}dB gain');
          return clamped;
        } else {
          debugPrint(
              ' [Loudness] Invalid measurement ($measuredLufs LUFS) for $filePath — skipping');
          return null;
        }
      }

      // Fallback: ebur128 if loudnorm JSON not found
      final ebur128 = await Process.run(
        ffmpegPath,
        ['-i', filePath, '-af', 'ebur128=peak=true', '-f', 'null', '-'],
        runInShell: false,
      ).timeout(const Duration(seconds: 60));

      final ebur128Match = RegExp(r'I:\s+([+-]?\d+\.?\d+)\s+LUFS')
          .firstMatch(ebur128.stderr.toString());
      if (ebur128Match != null) {
        final measuredLufs = double.tryParse(ebur128Match.group(1)!);
        if (measuredLufs != null &&
            measuredLufs.isFinite &&
            measuredLufs > -60.0) {
          final gain = _targetLufs - measuredLufs;
          final clamped = gain.clamp(_minGainDb, _maxGainDb);
          debugPrint(
              ' [Loudness] ebur128: $filePath → ${measuredLufs.toStringAsFixed(1)} LUFS → ${clamped.toStringAsFixed(1)}dB');
          return clamped;
        }
      }
    } catch (e) {
      debugPrint(' [Loudness] ffmpeg measure failed: $e');
    }
    return null;
  }

  /// Read embedded REPLAYGAIN_TRACK_GAIN tag without ffprobe (mobile fallback).
  /// Uses a simple byte scan for ID3v2 and Vorbis comment tags.
  Future<double?> _readEmbeddedTag(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.openRead(0, 4096).toList();
      final content = String.fromCharCodes(bytes.expand((b) => b));
      final match = RegExp(r'REPLAYGAIN_TRACK_GAIN[=\0\s"]+([+-]?\d+\.?\d*)',
              caseSensitive: false)
          .firstMatch(content);
      if (match != null) {
        return double.tryParse(match.group(1)!)?.clamp(_minGainDb, _maxGainDb);
      }
    } catch (_) {}
    return null;
  }

  // ─── Background library scan ───────────────────────────────────────────────

  /// Scans all local songs in the DB that don't have a replayGain value yet.
  /// Runs in the background — safe to call after library scan completes.
  /// Uses throttled sequential scanning to avoid impacting UI performance.
  Future<void> scanLibrary({bool rescanAll = false}) async {
    if (_isScanning) return;
    _isScanning = true;
    _cancelRequested = false;
    scannedCount = 0;

    final logger = DebugLogService();
    final db = DBService();

    try {
      // Use targeted query — only fetch songs needing a scan
      final toScan = rescanAll
          ? await db.getAllSongs()
          : await db.getSongsWithoutReplayGain();

      if (toScan.isEmpty) {
        logger.info('[Loudness] All songs already scanned.');
        statusNotifier.value = null;
        return;
      }

      // Reset songs stored at exactly ±12dB (the cap) — these are bad
      // measurements from the old ebur128 approach that returned -70 LUFS.
      // Reset them to null so they get re-measured with the new loudnorm method.
      if (!rescanAll) {
        final allSongs = await db.getAllSongs();
        final badSongs = allSongs
            .where(
                (s) => s.replayGain == _maxGainDb || s.replayGain == _minGainDb)
            .toList();
        for (final s in badSongs) {
          await db.updateSongReplayGain(s.id, null);
        }
        if (badSongs.isNotEmpty) {
          logger.info(
              '[Loudness] Reset ${badSongs.length} capped-gain songs for re-scan.');
        }
      }

      // Re-fetch after reset to include newly-nulled songs
      final finalToScan = rescanAll
          ? await db.getAllSongs()
          : await db.getSongsWithoutReplayGain();

      logger.info('[Loudness] Starting scan of ${finalToScan.length} songs...');

      // On Android: tag-only scan (fast, no ffmpeg)
      // On Desktop: tag first, then ffmpeg measurement if no tag
      final isDesktop = !Platform.isAndroid && !Platform.isIOS;
      final ffprobe = isDesktop ? await _getFFprobePath() : null;

      for (int i = 0; i < finalToScan.length; i++) {
        if (_cancelRequested) break;

        // BACKOFF: yield to the player whenever it's loading/buffering/
        // playing. This is the per-file gate so even if playback starts
        // mid-scan we immediately stop fighting the audio decoder for IO.
        await _waitWhilePlayerActive();
        if (_cancelRequested) break;

        final song = finalToScan[i];
        if (!await File(song.path).exists()) continue;

        double? gain;

        // Step 1: Try embedded tag first (instant, no CPU cost)
        gain = await _readEmbeddedTag(song.path);

        // Step 2: Desktop only — measure with ffmpeg if no tag
        if (gain == null && ffprobe != null) {
          gain = await _measureWithFfmpeg(song.path, ffprobe);
        }

        if (gain != null) {
          await db.updateSongReplayGain(song.id, gain);
          scannedCount++;
        } else {
          // Store 0.0 so we don't re-scan this file every time
          await db.updateSongReplayGain(song.id, 0.0);
        }

        // Update status every 5 songs
        if (i % 5 == 0) {
          statusNotifier.value = 'Scanning loudness ($i/${finalToScan.length})';
        }

        // Throttle: yield to event loop every file to keep UI responsive
        // On desktop with ffmpeg this is already slow enough; on Android
        // the tag scan is fast so we add a small delay to avoid blocking.
        if (!isDesktop || i % 3 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      logger.info('[Loudness] Scan complete. $scannedCount songs updated.');
    } catch (e) {
      logger.error('[Loudness] Scan error: $e');
    } finally {
      _isScanning = false;
      statusNotifier.value = null;
    }
  }

  void cancelScan() {
    _cancelRequested = true;
  }

  bool get isScanning => _isScanning;
}
