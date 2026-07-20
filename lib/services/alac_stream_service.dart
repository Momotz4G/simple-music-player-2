import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../env/env.dart';
import '../providers/data_usage_provider.dart';
import '../providers/settings_provider.dart';

/// ALAC lossless streaming service.
/// Handles queue, polling, and file download for Apple Music tracks.
class AlacStreamService {
  static Ref? globalRef;

  // Resolved at runtime from obfuscated env — never a plain string in source
  static String get _base => Env.alacStreamUrl;

  /// Default quality when no settings are available.
  static String get defaultQuality => _q(3);

  // ─── Quality helpers ────────────────────────────────────────────────────────

  /// Maps the app's audioFormat/streamingQuality settings to an API quality
  /// string.
  ///
  /// Rules:
  ///  - audioFormat == 'alac' or 'flac'  → highest lossless tier
  ///  - streamingQuality == 'lossless'   → highest lossless tier
  ///  - streamingQuality == 'high'       → CD lossless (16-bit/44kHz)
  ///  - anything else                    → lossy high-bitrate
  static String resolveQuality(SettingsState settings) {
    final fmt = settings.audioFormat;
    final sq = settings.streamingQuality;

    // Dolby Atmos requested explicitly
    if (fmt == 'atmos') {
      return _q(6); // DOLBY_ATMOS_MAX → cascades to DOLBY_ATMOS → ALAC
    }

    if (fmt == 'alac' || fmt == 'flac' || sq == 'lossless') {
      return _q(3); // highest lossless
    }
    if (sq == 'high' || fmt == 'm4a') {
      return _q(0); // CD lossless
    }
    return _q(4); // lossy fallback
  }

  /// Quality tier index → API string.
  /// Stored as an index so the actual strings aren't a readable list in source.
  static String _q(int tier) {
    // Tiers: 0=CD, 1=24/48, 2=24/96, 3=24/192, 4=AAC256, 5=Atmos, 6=AtmosMax
    const t = [
      'ALAC_16Bit_44kHz',
      'ALAC_24Bit_48kHz',
      'ALAC_24Bit_96kHz',
      'ALAC_24Bit_192kHz',
      'AAC_256Kbps',
      'DOLBY_ATMOS',
      'DOLBY_ATMOS_MAX',
    ];
    return t[tier.clamp(0, t.length - 1)];
  }

  /// Cascade order when the highest tier isn't available for a track.
  static List<String> _fallbackChain(String requested) {
    // Dolby Atmos: try AtmosMax first, then Atmos, then fall to best ALAC
    if (requested == _q(5) || requested == _q(6)) {
      return [_q(6), _q(5), _q(3), _q(2), _q(1), _q(0)];
    }
    // ALAC chain: highest first, cascade down
    final chain = [_q(3), _q(2), _q(1), _q(0)];
    final idx = chain.indexOf(requested);
    return idx >= 0 ? chain.sublist(idx) : [requested, _q(0), _q(4)];
  }

  // ─── Endpoint builders ──────────────────────────────────────────────────────

  static Uri _queueUri(String trackUrl, String quality) =>
      Uri.parse('$_base/${_seg(0)}').replace(queryParameters: {
        _param(0): trackUrl,
        _param(1): quality,
      });

  static Uri _statusUri(String jobId) => Uri.parse('$_base/${_seg(1)}/$jobId');

  static Uri _fileUri(String path) =>
      path.startsWith('http') ? Uri.parse(path) : Uri.parse('$_base$path');

  /// Segment names — split so they don't appear as full paths in the binary.
  static String _seg(int i) => const ['download', 'queue', 'lyrics'][i];

  /// Parameter names.
  static String _param(int i) => const ['url', 'quality'][i];

  // ─── Core API ───────────────────────────────────────────────────────────────

  /// Queue a download and return the direct download URL once completed.
  /// Automatically cascades through lossless quality tiers if the highest
  /// isn't available for the track.
  static Future<String?> requestDownload(
    String trackUrl, {
    String quality = '',
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    final q = quality.isEmpty ? _q(3) : quality;
    debugPrint(' [AlacStream] Queuing: $trackUrl @ $q');

    final chain = (q.startsWith('ALAC') || q.startsWith('DOLBY'))
        ? _fallbackChain(q)
        : [q];

    for (final tier in chain) {
      final result = await _tryTier(
        trackUrl,
        tier,
        onProgress: onProgress,
        onStatusUpdate: onStatusUpdate,
      );
      if (result != null) return result;
      debugPrint(' [AlacStream] Tier $tier unavailable, trying next...');
    }

    debugPrint(' [AlacStream] All tiers failed for $trackUrl');
    return null;
  }

  static Future<String?> _tryTier(
    String trackUrl,
    String quality, {
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    try {
      // Step 1: Queue
      final queueRes = await http
          .get(_queueUri(trackUrl, quality))
          .timeout(const Duration(seconds: 30));

      if (queueRes.statusCode != 200 && queueRes.statusCode != 202) {
        debugPrint(' [AlacStream] Queue HTTP ${queueRes.statusCode}');
        return null;
      }

      final queueData = json.decode(queueRes.body) as Map<String, dynamic>;
      final job = queueData['job'] as Map<String, dynamic>?;
      final jobId = job?['id'] as String?;
      if (jobId == null) {
        debugPrint(' [AlacStream] No job ID in response');
        return null;
      }

      debugPrint(' [AlacStream] Job: $jobId ($quality)');
      onProgress?.call(0.1);
      onStatusUpdate?.call('Queued');

      // Step 2: Poll (max 3 min, 2s interval)
      const maxPolls = 90;
      for (int i = 0; i < maxPolls; i++) {
        await Future.delayed(const Duration(seconds: 2));

        final statusRes = await http
            .get(_statusUri(jobId))
            .timeout(const Duration(seconds: 15));

        if (statusRes.statusCode != 200) continue;

        final data = json.decode(statusRes.body) as Map<String, dynamic>;
        final status = (data['status'] as String? ?? '').toLowerCase();
        final progress = data['progress'] as Map<String, dynamic>?;
        final stage = (progress?['stage'] as String? ?? status);

        onStatusUpdate?.call(stage);
        onProgress?.call((0.1 + (i / maxPolls) * 0.8).clamp(0.1, 0.9));

        if (status == 'completed') {
          final dlPath = data['downloadUrl'] as String?;
          if (dlPath == null) return null;
          final fullUrl = _fileUri(dlPath).toString();
          debugPrint(' [AlacStream] Ready: $fullUrl');
          onProgress?.call(1.0);
          return fullUrl;
        }

        if (status == 'failed' || status == 'error') {
          debugPrint(' [AlacStream] Job failed: ${data['error']}');
          return null;
        }
      }

      debugPrint(' [AlacStream] Poll timeout for $jobId');
      return null;
    } catch (e) {
      debugPrint('💥 [AlacStream] Exception: $e');
      return null;
    }
  }

  // ─── File download ───────────────────────────────────────────────────────────

  /// Stream the audio file from [remoteUrl] to [localPath].
  static Future<bool> downloadFile(
    String remoteUrl,
    String localPath, {
    Function(double)? onProgress,
  }) async {
    try {
      final client = http.Client();
      final response = await client.send(
        http.Request('GET', Uri.parse(remoteUrl)),
      );

      if (response.statusCode != 200) {
        debugPrint(' [AlacStream] File HTTP ${response.statusCode}');
        return false;
      }

      final file = File(localPath);
      final total = response.contentLength ?? 0;
      int received = 0;

      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0));
      }
      await sink.close();

      final ref = globalRef;
      if (ref != null && received > 0) {
        ref.read(dataUsageProvider.notifier).addBytes(received);
      }

      debugPrint(
          ' [AlacStream] Saved: $localPath (${(received / 1024 / 1024).toStringAsFixed(1)} MB)');
      return true;
    } catch (e) {
      debugPrint('💥 [AlacStream] Download exception: $e');
      return false;
    }
  }

  // ─── Lyrics ──────────────────────────────────────────────────────────────────

  /// Fetch synced lyrics for an Apple Music track by its numeric track ID.
  ///
  /// Returns a map with keys: `lrc`, `ttml_content`, `plain`, `timing_mode`.
  /// Returns null if the track has no lyrics or the request fails.
  static Future<Map<String, dynamic>?> fetchLyricsById(String trackId) async {
    try {
      debugPrint(' [AlacStream] Fetching lyrics for track $trackId');
      final uri = Uri.parse('$_base/${_seg(2)}/$trackId');
      // 30s timeout — proxy can be slow on first fetch for uncached tracks
      final res = await http.get(uri).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final mode = data['timing_mode'] as String? ?? 'None';
        final lrc = data['lrc'] as String?;
        final ttml = data['ttml_content'] as String?;
        final plain = data['plain'] as String?;

        // Reject if there's genuinely no usable content at all
        final hasContent = (lrc != null && lrc.trim().isNotEmpty) ||
            (ttml != null && ttml.trim().isNotEmpty) ||
            (plain != null && plain.trim().isNotEmpty);

        if (!hasContent) {
          debugPrint(' [AlacStream] Track $trackId has no lyrics content');
          return null;
        }

        debugPrint(' [AlacStream] Lyrics fetched (mode: $mode)');
        return data;
      }
      if (res.statusCode == 404) {
        debugPrint(' [AlacStream] No lyrics for track $trackId');
        return null;
      }
      debugPrint(' [AlacStream] Lyrics HTTP ${res.statusCode}');
      return null;
    } catch (e) {
      debugPrint('💥 [AlacStream] Lyrics exception: $e');
      return null;
    }
  }

  /// Extract the Apple Music numeric track ID from a trackViewUrl.
  /// e.g. "https://music.apple.com/us/album/iris/1109658139?i=1109658204"
  ///     → "1109658204"
  static String? extractTrackId(String appleMusicUrl) {
    // Try ?i= parameter first (most common)
    final iParam = RegExp(r'[?&]i=(\d+)').firstMatch(appleMusicUrl);
    if (iParam != null) return iParam.group(1);
    // Fallback: last numeric path segment
    final pathNum = RegExp(r'/(\d+)(?:[?#]|$)').allMatches(appleMusicUrl);
    if (pathNum.isNotEmpty) return pathNum.last.group(1);
    return null;
  }

  /// Full pipeline: queue → poll → download to [localPath].
  static Future<bool> downloadTrack(
    String trackUrl,
    String localPath, {
    String quality = '',
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    final dlUrl = await requestDownload(
      trackUrl,
      quality: quality,
      onProgress: (p) => onProgress?.call(p * 0.5),
      onStatusUpdate: onStatusUpdate,
    );
    if (dlUrl == null) return false;
    return downloadFile(
      dlUrl,
      localPath,
      onProgress: (p) => onProgress?.call(0.5 + p * 0.5),
    );
  }
}
