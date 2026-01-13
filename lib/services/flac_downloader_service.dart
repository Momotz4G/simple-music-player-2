import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../env/env.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'debug_log_service.dart';

/// Service for downloading lossless FLAC audio from various streaming platforms.
/// Based on SpotiFLAC implementation (https://github.com/afkarxyz/SpotiFLAC).
///
/// Workflow:
/// 1. Match Spotify track to other platforms via song.link API
/// 2. Get FLAC download URL from the matched platform
/// 3. Download and save the file
class FlacDownloaderService {
  static final FlacDownloaderService _instance =
      FlacDownloaderService._internal();

  factory FlacDownloaderService() => _instance;

  FlacDownloaderService._internal();

  final http.Client _client = http.Client();

  // Rate limiting for song.link API (10 requests/minute, 7s delay between)
  DateTime? _lastSongLinkCall;
  int _songLinkCallCount = 0;
  DateTime _songLinkResetTime = DateTime.now();

  // Default service priority order
  static const List<String> defaultServiceOrder = ['deezer', 'tidal', 'qobuz'];

  /// Get streaming URLs from song.link API for a Spotify track
  Future<StreamingUrls?> getStreamingUrls(String spotifyTrackId) async {
    if (spotifyTrackId.isEmpty) return null;

    // Rate limiting
    await _applySongLinkRateLimit();

    try {
      // Build song.link API URL
      // Base64 decoded: https://api.song.link/v1-alpha.1/links?url=
      const apiBase = 'https://api.song.link/v1-alpha.1/links?url=';
      final spotifyUrl = 'https://open.spotify.com/track/$spotifyTrackId';
      final apiUrl = '$apiBase${Uri.encodeComponent(spotifyUrl)}';

      debugPrint('🔗 Getting streaming URLs from song.link...');

      final response = await _client.get(
        Uri.parse(apiUrl),
        headers: {'User-Agent': 'SimpleMusicPlayer/1.0'},
      );

      _lastSongLinkCall = DateTime.now();
      _songLinkCallCount++;

      if (response.statusCode == 429) {
        debugPrint('⚠️ song.link rate limit hit, waiting...');
        await Future.delayed(const Duration(seconds: 15));
        return getStreamingUrls(spotifyTrackId); // Retry
      }

      if (response.statusCode != 200) {
        debugPrint('❌ song.link API error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final linksByPlatform = data['linksByPlatform'] as Map<String, dynamic>?;

      if (linksByPlatform == null) return null;

      final urls = StreamingUrls(
        spotifyId: spotifyTrackId,
        deezerUrl: _extractPlatformUrl(linksByPlatform, 'deezer'),
        tidalUrl: _extractPlatformUrl(linksByPlatform, 'tidal'),
        amazonUrl: _extractPlatformUrl(linksByPlatform, 'amazonMusic'),
      );

      debugPrint('✓ Found URLs - Deezer: ${urls.deezerUrl != null}, '
          'Tidal: ${urls.tidalUrl != null}');

      return urls;
    } catch (e) {
      debugPrint('❌ Error getting streaming URLs: $e');
      return null;
    }
  }

  String? _extractPlatformUrl(
      Map<String, dynamic> linksByPlatform, String platform) {
    final platformData = linksByPlatform[platform] as Map<String, dynamic>?;
    return platformData?['url'] as String?;
  }

  /// Apply rate limiting for song.link API
  Future<void> _applySongLinkRateLimit() async {
    final now = DateTime.now();

    // Reset counter every minute
    if (now.difference(_songLinkResetTime).inSeconds >= 60) {
      _songLinkCallCount = 0;
      _songLinkResetTime = now;
    }

    // Wait if we've hit the limit (9 calls to be safe)
    if (_songLinkCallCount >= 9) {
      final waitTime =
          Duration(seconds: 60 - now.difference(_songLinkResetTime).inSeconds);
      debugPrint('⏳ Rate limit reached, waiting ${waitTime.inSeconds}s...');
      await Future.delayed(waitTime);
      _songLinkCallCount = 0;
      _songLinkResetTime = DateTime.now();
    }

    // Ensure 7 second delay between calls
    if (_lastSongLinkCall != null) {
      final timeSinceLast = now.difference(_lastSongLinkCall!);
      if (timeSinceLast.inSeconds < 7) {
        final waitTime = Duration(seconds: 7 - timeSinceLast.inSeconds);
        await Future.delayed(waitTime);
      }
    }
  }

  // ============================================================
  // DEEZER FLAC DOWNLOAD
  // ============================================================

  /// Get Deezer track ID from URL
  int? _extractDeezerTrackId(String deezerUrl) {
    // Format: https://www.deezer.com/track/3412534581
    final regex = RegExp(r'/track/(\d+)');
    final match = regex.firstMatch(deezerUrl);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Get track metadata from Deezer API
  Future<DeezerTrack?> getDeezerTrack(int trackId) async {
    try {
      // Deezer public API
      final url = 'https://api.deezer.com/2.0/track/$trackId';
      final response = await _client.get(Uri.parse(url));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data['id'] == null) return null;

      return DeezerTrack.fromJson(data);
    } catch (e) {
      debugPrint('❌ Error getting Deezer track: $e');
      return null;
    }
  }

  /// Get FLAC download URL from deezmate.com API
  Future<String?> getDeezerFlacUrl(int trackId) async {
    try {
      // DeezMate API endpoint
      // Base64 decoded: https://api.deezmate.com/dl/
      const apiBase = 'https://api.deezmate.com/dl/';
      final url = '$apiBase$trackId';

      final logger = DebugLogService();
      logger.info('DEEZER: Requesting DeezMate API for $trackId');

      final response = await _client.get(Uri.parse(url));

      if (response.statusCode != 200) {
        debugPrint('❌ DeezMate API error: ${response.statusCode}');
        logger.warning('DEEZER: API Error ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      if (data['success'] != true) {
        debugPrint('❌ DeezMate API: no FLAC available');
        return null;
      }

      final flacUrl = data['links']?['flac'] as String?;
      return flacUrl;
    } catch (e) {
      debugPrint('❌ Error getting FLAC URL: $e');
      return null;
    }
  }

  /// Download FLAC from Deezer
  Future<File?> downloadFromDeezer({
    required String deezerUrl,
    required String outputPath,
    String? trackName,
    String? artistName,
    String? albumName,
    Function(double)? onProgress,
  }) async {
    debugPrint('📥 Downloading from Deezer: $deezerUrl');

    final trackId = _extractDeezerTrackId(deezerUrl);
    if (trackId == null) {
      debugPrint('❌ Invalid Deezer URL');
      return null;
    }

    final logger = DebugLogService();
    logger.info("DEEZER: Getting info for track $trackId");

    // Get track info
    final track = await getDeezerTrack(trackId);
    if (track == null) {
      debugPrint('❌ Could not get Deezer track info');
      return null;
    }

    // Get FLAC download URL
    final flacUrl = await getDeezerFlacUrl(trackId);
    if (flacUrl == null) {
      debugPrint('❌ Could not get FLAC URL');
      logger.warning("DEEZER: Could not get FLAC URL for $trackId");
      return null;
    }
    logger.info("DEEZER: Got FLAC URL, starting download...");

    // Download the file
    final file = await _downloadFile(
      url: flacUrl,
      outputPath: outputPath,
      onProgress: onProgress,
    );

    if (file != null) {
      debugPrint('✓ Downloaded from Deezer: ${file.path}');
    }

    return file;
  }

  // ============================================================
  // TIDAL FLAC DOWNLOAD
  // ============================================================

  /// Extract Tidal track ID from URL
  int? _extractTidalTrackId(String tidalUrl) {
    // Format: https://tidal.com/browse/track/12345678
    // or: https://listen.tidal.com/track/12345678
    final regex = RegExp(r'/track/(\d+)');
    final match = regex.firstMatch(tidalUrl);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  Future<List<String>> _getTidalApiServers() async {
    final logger = DebugLogService();
    // Hardcoded fallback servers (Decoded from SpotiFLAC Go source)
    final fallbackServers = [
      'https://vogel.qqdl.site',
      'https://maus.qqdl.site',
      'https://hund.qqdl.site',
      'https://katze.qqdl.site',
      'https://wolf.qqdl.site',
      'https://tidal.kinoplus.online',
      'https://tidal-api.binimum.org',
      'https://triton.squid.wtf',
    ];

    try {
      // 🚀 FIX: Try 'master' branch instead of 'main'
      final url =
          'https://raw.githubusercontent.com/afkarxyz/SpotiFLAC/master/tidal.json';
      logger.info('TIDAL: Fetching servers from GitHub (master)...');
      final response = await _client.get(Uri.parse(url));

      if (response.statusCode != 200) {
        logger.warning(
            'TIDAL: GitHub returned ${response.statusCode}. Using fallbacks.');
        return fallbackServers;
      }

      final List<dynamic> servers = json.decode(response.body);
      logger.info('TIDAL: Parsed ${servers.length} servers from GitHub');
      // combine with fallbacks just in case
      final allServers = <String>{
        ...servers.map((s) => 'https://$s'),
        ...fallbackServers
      }.toList();
      return allServers;
    } catch (e) {
      debugPrint('❌ Error getting Tidal API servers: $e');
      logger.error('TIDAL: Error fetching servers: $e. Using fallbacks.');
      return fallbackServers;
    }
  }

  /// Download FLAC from Tidal using external API
  /// Tries HI_RES_LOSSLESS first, falls back to LOSSLESS if Hi-Res returns DASH manifest
  Future<File?> downloadFromTidal({
    required String tidalUrl,
    required String outputPath,
    Function(double)? onProgress,
  }) async {
    debugPrint('📥 Downloading from Tidal: $tidalUrl');

    final trackId = _extractTidalTrackId(tidalUrl);
    if (trackId == null) {
      debugPrint('❌ Invalid Tidal URL');
      return null;
    }

    // Get available API servers
    final servers = await _getTidalApiServers();
    if (servers.isEmpty) {
      debugPrint('❌ No Tidal API servers available');
      return null;
    }

    // Try quality levels in order of preference
    final qualityLevels = ['HI_RES_LOSSLESS', 'LOSSLESS', 'HIGH'];

    for (final quality in qualityLevels) {
      debugPrint('🎧 Trying Tidal quality: $quality');

      // Try each server for this quality
      for (final server in servers) {
        try {
          final apiUrl = '$server/track?id=$trackId&quality=$quality';
          final response = await _client
              .get(Uri.parse(apiUrl))
              .timeout(const Duration(seconds: 30));

          if (response.statusCode != 200) continue;

          // Check if response is XML (DASH manifest) - skip if so
          final body = response.body.trim();
          if (body.startsWith('<?xml') || body.startsWith('<MPD')) {
            debugPrint(
                '⚠️ $quality returned DASH manifest, trying lower quality...');
            break; // Try next quality level
          }

          final data = json.decode(body);

          // Handle different API response formats
          String? downloadUrl;

          // V1 format
          if (data['OriginalTrackUrl'] != null) {
            downloadUrl = data['OriginalTrackUrl'] as String;
          }
          // V2 format (manifest-based)
          else if (data['data']?['manifest'] != null) {
            final manifest = base64Decode(data['data']['manifest']);
            final manifestData = json.decode(utf8.decode(manifest));
            final urls = manifestData['urls'] as List?;
            if (urls != null && urls.isNotEmpty) {
              downloadUrl = urls[0] as String;
            }
          }

          if (downloadUrl == null) continue;

          // Download the file
          debugPrint('📥 Downloading at $quality quality...');
          final file = await _downloadFile(
            url: downloadUrl,
            outputPath: outputPath,
            onProgress: onProgress,
          );

          if (file != null) {
            debugPrint('✓ Downloaded from Tidal ($quality): ${file.path}');
            return file;
          }
        } catch (e) {
          debugPrint('⚠️ Tidal API $server failed: $e');
          continue;
        }
      }
    }

    debugPrint('❌ All Tidal quality levels failed');
    return null;
  }

  // ============================================================
  // QOBUZ FLAC DOWNLOAD
  // ============================================================

  /// Check if Qobuz has a track by ISRC
  Future<bool> checkQobuzAvailability(String isrc) async {
    if (isrc.isEmpty) return false;

    try {
      // Qobuz search API
      final appId = Env.qobuzAppId;
      final url =
          'https://www.qobuz.com/api.json/0.2/track/search?query=$isrc&limit=1&app_id=$appId';

      final response = await _client.get(Uri.parse(url));

      if (response.statusCode != 200) return false;

      final data = json.decode(response.body);
      final total = data['tracks']?['total'] as int? ?? 0;
      return total > 0;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // MAIN DOWNLOAD FLOW
  // ============================================================

  /// Download FLAC using cascading quality fallback:
  /// 1. Tidal Hi-Res → 2. Deezer → 3. Tidal Lossless → 4. Deezer (retry)
  Future<FlacDownloadResult> downloadFlac({
    required String spotifyTrackId,
    required String outputPath,
    String? isrc,
    String? trackName,
    String? artistName,
    String? albumName,
    Function(double)? onProgress,
  }) async {
    final logger = DebugLogService();
    logger.info("FLAC: downloadFlac called for $trackName");

    debugPrint('🎵 Starting FLAC download for Spotify ID: $spotifyTrackId');

    // Get streaming URLs from song.link
    final urls = await getStreamingUrls(spotifyTrackId);
    if (urls == null) {
      logger.warning("FLAC: No streaming URLs found");
      return FlacDownloadResult.failed('Could not find track on any platform');
    }
    logger.info(
        "FLAC: URLs found - Tidal: ${urls.tidalUrl != null}, Deezer: ${urls.deezerUrl != null}");

    File? file;

    // === STEP 1: Try Tidal HI_RES_LOSSLESS ===
    if (urls.tidalUrl != null) {
      debugPrint('🎧 Step 1: Trying Tidal HI_RES_LOSSLESS...');
      logger.info('FLAC: Step 1 - Trying Tidal HI_RES_LOSSLESS...');
      file = await _downloadFromTidalWithQuality(
        tidalUrl: urls.tidalUrl!,
        outputPath: outputPath,
        quality: 'HI_RES_LOSSLESS',
        onProgress: onProgress,
      );
      if (file != null) {
        logger.success('FLAC: Tidal Hi-Res success');
        return FlacDownloadResult.success(file, 'tidal-hires');
      }
      logger.warning('FLAC: Tidal Hi-Res failed');
    }

    // === STEP 2: Try Deezer (has own quality handling) ===
    if (urls.deezerUrl != null) {
      debugPrint('🎧 Step 2: Trying Deezer FLAC...');
      logger.info('FLAC: Step 2 - Trying Deezer FLAC...');
      file = await downloadFromDeezer(
        deezerUrl: urls.deezerUrl!,
        outputPath: outputPath,
        trackName: trackName,
        artistName: artistName,
        albumName: albumName,
        onProgress: onProgress,
      );
      if (file != null) {
        logger.success('FLAC: Deezer download success');
        return FlacDownloadResult.success(file, 'deezer');
      }
      logger.warning('FLAC: Deezer failed');
    }

    // === STEP 3: Try Tidal LOSSLESS (CD quality fallback) ===
    if (urls.tidalUrl != null) {
      debugPrint('🎧 Step 3: Trying Tidal LOSSLESS (CD quality)...');
      file = await _downloadFromTidalWithQuality(
        tidalUrl: urls.tidalUrl!,
        outputPath: outputPath,
        quality: 'LOSSLESS',
        onProgress: onProgress,
      );
      if (file != null) {
        return FlacDownloadResult.success(file, 'tidal-lossless');
      }
    }

    // === STEP 4: Final check with Qobuz if ISRC available ===
    if (isrc != null && isrc.isNotEmpty) {
      final available = await checkQobuzAvailability(isrc);
      if (available) {
        debugPrint('⚠️ Qobuz available but download not yet implemented');
      }
    }

    return FlacDownloadResult.failed('Download failed on all services');
  }

  /// Helper to download from Tidal with specific quality
  /// Supports both direct URL and DASH manifest formats
  Future<File?> _downloadFromTidalWithQuality({
    required String tidalUrl,
    required String outputPath,
    required String quality,
    Function(double)? onProgress,
  }) async {
    final trackId = _extractTidalTrackId(tidalUrl);
    if (trackId == null) return null;

    final logger = DebugLogService();
    final servers = await _getTidalApiServers();
    if (servers.isEmpty) {
      logger.error("TIDAL: No API servers available");
      return null;
    }
    logger.info("TIDAL: Found ${servers.length} servers for $quality");

    for (final server in servers) {
      try {
        final apiUrl = '$server/track?id=$trackId&quality=$quality';
        logger.info("TIDAL: Requesting $apiUrl");
        final response = await _client
            .get(Uri.parse(apiUrl))
            .timeout(const Duration(seconds: 10)); // Reduced timeout

        if (response.statusCode != 200) {
          logger
              .warning("TIDAL: Server $server returned ${response.statusCode}");
          continue;
        }

        final body = response.body.trim();

        // DEBUG: Log first characters to see what we're getting
        final firstChars = body.length > 20 ? body.substring(0, 20) : body;
        debugPrint(
            '📋 Response starts with: "$firstChars" (len=${body.length})');
        debugPrint('📋 Starts with <?xml: ${body.startsWith('<?xml')}');
        debugPrint('📋 Contains MPD: ${body.contains('<MPD')}');

        // === DASH MANIFEST HANDLING (Hi-Res) ===
        // Also check if body contains XML/MPD anywhere (in case of BOM)
        if (body.startsWith('<?xml') ||
            body.startsWith('<MPD') ||
            body.contains('<?xml') && body.contains('<MPD')) {
          debugPrint('📺 Got DASH manifest for $quality, parsing segments...');
          final file = await _downloadDashManifest(
            manifestXml: body,
            outputPath: outputPath,
            onProgress: onProgress,
          );
          if (file != null) {
            debugPrint('✓ Downloaded Hi-Res from DASH: ${file.path}');
            return file;
          }
          continue; // Try next server if this one failed
        }

        // === DIRECT URL HANDLING (Lossless) ===
        final data = json.decode(body);
        String? downloadUrl;

        if (data['OriginalTrackUrl'] != null) {
          downloadUrl = data['OriginalTrackUrl'] as String;
        } else if (data['data']?['manifest'] != null) {
          // Decode base64 manifest
          final manifestBytes = base64Decode(data['data']['manifest']);
          final manifestStr = utf8.decode(manifestBytes);

          debugPrint(
              '📋 Manifest decoded, starts with: "${manifestStr.substring(0, 30.clamp(0, manifestStr.length))}"');

          // Check if manifest is XML (Hi-Res DASH) or JSON (Lossless)
          if (manifestStr.trim().startsWith('<?xml') ||
              manifestStr.trim().startsWith('<MPD')) {
            // It's XML DASH manifest - use our DASH parser!
            debugPrint(
                '📺 Found DASH manifest inside JSON response, parsing...');
            final file = await _downloadDashManifest(
              manifestXml: manifestStr,
              outputPath: outputPath,
              onProgress: onProgress,
            );
            if (file != null) {
              debugPrint(
                  '✓ Downloaded Hi-Res from embedded DASH: ${file.path}');
              return file;
            }
            continue; // Try next server
          } else {
            // It's JSON with URLs
            try {
              final manifestData = json.decode(manifestStr);
              final downloadUrls = manifestData['urls'] as List?;
              if (downloadUrls != null && downloadUrls.isNotEmpty) {
                downloadUrl = downloadUrls[0] as String;
              }
            } catch (e) {
              debugPrint('⚠️ Could not parse manifest JSON: $e');
              continue;
            }
          }
        }

        if (downloadUrl == null) continue;

        debugPrint('📥 Downloading from Tidal at $quality...');

        // Download to temp file first, then convert to ensure proper FLAC
        final tempPath = outputPath.replaceAll('.flac', '_temp_direct.m4a');
        final tempFile = await _downloadFile(
          url: downloadUrl,
          outputPath: tempPath,
          onProgress: onProgress,
        );

        if (tempFile != null) {
          debugPrint('📥 Direct download complete, converting to FLAC...');
          // Apply same FFmpeg conversion as DASH downloads
          final convertedFile = await _convertToFlac(
            inputPath: tempPath,
            outputPath: outputPath,
          );

          // Cleanup temp file
          try {
            await tempFile.delete();
          } catch (_) {}

          if (convertedFile != null) {
            debugPrint(
                '✓ Downloaded and converted from Tidal ($quality): ${convertedFile.path}');
            return convertedFile;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Tidal $server ($quality) failed: $e');
        continue;
      }
    }

    return null;
  }

  /// Download from DASH manifest by parsing segments and concatenating
  Future<File?> _downloadDashManifest({
    required String manifestXml,
    required String outputPath,
    Function(double)? onProgress,
  }) async {
    try {
      final List<String> segmentUrls = [];

      // Extract base URL for relative paths
      String baseUrl = '';
      final baseUrlMatch =
          RegExp(r'<BaseURL>([^<]+)</BaseURL>').firstMatch(manifestXml);
      if (baseUrlMatch != null) {
        baseUrl = baseUrlMatch.group(1)!;
        // If baseUrl is a complete file, just download it directly
        if (baseUrl.contains('.flac') ||
            baseUrl.contains('.m4a') ||
            baseUrl.contains('audio')) {
          debugPrint('📎 Found direct audio BaseURL');
          segmentUrls.add(baseUrl);
        }
      }

      // SegmentTemplate format (most common for Hi-Res)
      if (segmentUrls.isEmpty) {
        final initMatch =
            RegExp(r'initialization="([^"]+)"').firstMatch(manifestXml);
        final mediaMatch = RegExp(r'media="([^"]+)"').firstMatch(manifestXml);

        if (initMatch != null && mediaMatch != null) {
          debugPrint('📺 Parsing SegmentTemplate DASH format...');

          final initTemplate = initMatch.group(1)!;
          final mediaTemplate = mediaMatch.group(1)!;

          // Get base URL from manifest (for relative URLs)
          if (baseUrl.isEmpty) {
            // Try to extract domain from any URL in the manifest
            final domainMatch =
                RegExp(r'(https?://[^/\s<>"]+)').firstMatch(manifestXml);
            if (domainMatch != null) {
              baseUrl = domainMatch.group(1)!;
            }
          }

          // Build initialization URL
          final initUrl = initTemplate.startsWith('http')
              ? initTemplate
              : '$baseUrl$initTemplate';
          segmentUrls.add(initUrl);
          debugPrint(
              '📎 Init segment: ${initUrl.substring(0, 50.clamp(0, initUrl.length))}...');

          // Parse SegmentTimeline to get segment numbers/times
          // Format: <S t="0" d="96000" r="44"/> means: start at t, duration d, repeat r times
          final timelineMatches =
              RegExp(r'<S\s+(?:t="(\d+)"\s+)?d="(\d+)"(?:\s+r="(\d+)")?')
                  .allMatches(manifestXml);

          int segmentNumber = 0;
          for (final match in timelineMatches) {
            final duration = int.parse(match.group(2)!);
            final repeat = int.tryParse(match.group(3) ?? '0') ?? 0;

            // Each timeline entry means (repeat + 1) segments
            for (int i = 0; i <= repeat; i++) {
              // Replace $Number$ template variable with actual segment number
              String segmentUrl = mediaTemplate
                  .replaceAll('\$Number\$', segmentNumber.toString())
                  .replaceAll(
                      '\$Time\$', (segmentNumber * duration).toString());

              if (!segmentUrl.startsWith('http')) {
                segmentUrl = '$baseUrl$segmentUrl';
              }

              segmentUrls.add(segmentUrl);
              segmentNumber++;
            }
          }

          // If no timeline found, might be simpler format
          if (segmentUrls.length <= 1) {
            // Try to find segment count from duration
            final durationMatch =
                RegExp(r'duration="(\d+)"').firstMatch(manifestXml);
            final timescaleMatch =
                RegExp(r'timescale="(\d+)"').firstMatch(manifestXml);

            if (durationMatch != null && timescaleMatch != null) {
              debugPrint('📊 Using duration-based segment calculation');
              // Estimate ~200 segments for a 4-minute song (rough)
              for (int i = 0; i < 200; i++) {
                String segmentUrl =
                    mediaTemplate.replaceAll('\$Number\$', i.toString());
                if (!segmentUrl.startsWith('http')) {
                  segmentUrl = '$baseUrl$segmentUrl';
                }
                segmentUrls.add(segmentUrl);
              }
            }
          }

          debugPrint('📋 Found ${segmentUrls.length} segments to download');
        }
      }

      // Fallback: Try to extract any audio URLs
      if (segmentUrls.isEmpty) {
        final urlMatches =
            RegExp(r'(https?://[^\s<>"]+\.(?:flac|m4a|fLaC)[^\s<>"]*)')
                .allMatches(manifestXml);
        for (final match in urlMatches) {
          segmentUrls.add(match.group(1)!);
        }
      }

      if (segmentUrls.isEmpty) {
        debugPrint('❌ Could not extract any segment URLs from manifest');
        return null;
      }

      debugPrint('📥 Downloading ${segmentUrls.length} segment(s)...');

      // Download all segments
      final List<List<int>> segments = [];
      int totalBytes = 0;

      for (int i = 0; i < segmentUrls.length; i++) {
        final url = segmentUrls[i];
        debugPrint('📥 Downloading segment ${i + 1}/${segmentUrls.length}...');

        final segmentResponse = await _client.get(Uri.parse(url));
        if (segmentResponse.statusCode != 200) {
          debugPrint('❌ Failed to download segment ${i + 1}');
          return null;
        }

        segments.add(segmentResponse.bodyBytes);
        totalBytes += segmentResponse.bodyBytes.length;

        if (onProgress != null) {
          onProgress((i + 1) / segmentUrls.length);
        }
      }

      // Concatenate all segments to a TEMP file first (fMP4 format)
      final tempPath = outputPath.replaceAll('.flac', '_temp.m4a');
      final tempFile = File(tempPath);
      final sink = tempFile.openWrite();

      for (final segment in segments) {
        sink.add(segment);
      }

      await sink.flush();
      await sink.close();

      final logger = DebugLogService(); // Re-get logger
      logger.info(
          "DASH: Segments downloaded. Size: ${await tempFile.length()} bytes");

      final tempSize = await tempFile.length();
      debugPrint(
          '📁 Temp Hi-Res: ${(tempSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Use FFmpeg to convert fMP4 to proper FLAC container
      debugPrint('🔄 Converting to FLAC container with FFmpeg...');

      // 🚀 Platform-aware FFmpeg conversion
      // 🚀 Platform-aware FFmpeg conversion
      bool conversionSuccess = false;

      if (Platform.isAndroid || Platform.isIOS) {
        debugPrint('📱 Mobile FFmpeg - processing...');
        logger.info(
            'Starting Mobile FFmpeg conversion: $tempPath -> $outputPath');

        // Execute FFmpeg command using ffmpeg_kit_flutter_new_audio
        // -y : Overwrite output files without asking
        // -i : Input file
        // -c:a copy : Copy audio stream (fastest), fallback to re-encode if fails

        final start = DateTime.now();
        try {
          logger.info('Executing FFmpeg command (copy)...');
          final session = await FFmpegKit.execute(
              '-y -i "$tempPath" -c:a copy "$outputPath"');
          final returnCode = await session.getReturnCode();
          final logs = await session.getAllLogsAsString();
          final duration = DateTime.now().difference(start).inMilliseconds;

          logger.info('FFmpeg finished in ${duration}ms');
          logger.info('Return Code: $returnCode');

          if (logs != null && logs.isNotEmpty) {
            // Log last 500 chars
            logger.info(
                'FFmpeg Logs: ${logs.length > 500 ? logs.substring(logs.length - 500) : logs}');
          }

          if (ReturnCode.isSuccess(returnCode)) {
            conversionSuccess = true;
            debugPrint('✓ Mobile FFmpeg conversion successful');
            logger.success('FFmpeg conversion successful');
          } else {
            debugPrint('⚠️ Mobile FFmpeg failed: $logs');
            logger.warning('FFmpeg copy failed, retrying with re-encode...');

            // Fallback: Try re-encoding if copy failed (sometimes containers disagree)
            debugPrint('🔄 Retrying with re-encode...');
            final retryStart = DateTime.now();
            final retrySession =
                await FFmpegKit.execute('-y -i "$tempPath" "$outputPath"');
            final retryCode = await retrySession.getReturnCode();
            final retryLogs = await retrySession.getAllLogsAsString();
            final retryDuration =
                DateTime.now().difference(retryStart).inMilliseconds;

            logger.info('Retry finished in ${retryDuration}ms');

            if (ReturnCode.isSuccess(retryCode)) {
              conversionSuccess = true;
              debugPrint('✓ Mobile FFmpeg re-encode successful');
              logger.success('FFmpeg re-encode successful');
            } else {
              debugPrint('❌ Mobile FFmpeg re-encode failed: $retryLogs');
              logger.error('FFmpeg re-encode failed: $retryLogs');
            }
          }
        } catch (e) {
          logger.error('FFmpeg Exception: $e');
          debugPrint('❌ FFmpeg Exception: $e');
        }
      } else {
        // Use system FFmpeg for desktop
        debugPrint('🖥️ Using system FFmpeg for desktop conversion...');
        final ffmpegPath = await _getFFmpegPath();

        if (ffmpegPath != null) {
          try {
            final result = await Process.run(
              ffmpegPath,
              [
                '-y', // Overwrite output
                '-i', tempPath, // Input temp file
                '-c:a', 'copy', // Copy audio (no re-encode)
                outputPath, // Output as .flac
              ],
              runInShell: true,
            );

            if (result.exitCode == 0 && await File(outputPath).exists()) {
              conversionSuccess = true;
              debugPrint('✓ FFmpeg conversion successful');
            } else {
              debugPrint('⚠️ FFmpeg conversion failed: ${result.stderr}');
            }
          } catch (e) {
            debugPrint('⚠️ FFmpeg error: $e');
          }
        } else {
          debugPrint('⚠️ FFmpeg not found on system');
        }
      }

      // Handle conversion result
      if (conversionSuccess) {
        // Delete temp file
        await tempFile.delete();

        final file = File(outputPath);
        final fileSize = await file.length();
        debugPrint(
            '📁 Hi-Res Downloaded: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        return file;
      } else {
        // Fall back to using temp file as FLAC (rename)
        debugPrint('⚠️ FFmpeg unavailable, using raw segments');
        await tempFile.rename(outputPath);
        final file = File(outputPath);
        final fileSize = await file.length();
        debugPrint(
            '📁 Hi-Res Downloaded (raw): ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        return file;
      }
    } catch (e) {
      debugPrint('❌ DASH download error: $e');
      return null;
    }
  }

  /// Get FFmpeg path from bin directory
  Future<String?> _getFFmpegPath() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final binDir = Directory('${appDir.path}/bin');

      final ffmpegName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
      final ffmpegFile = File('${binDir.path}/$ffmpegName');

      if (await ffmpegFile.exists()) {
        return ffmpegFile.path;
      }

      // Try system ffmpeg
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['ffmpeg'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        return result.stdout.toString().trim().split('\n').first;
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ Could not find FFmpeg: $e');
      return null;
    }
  }

  /// Convert audio file to FLAC using FFmpeg (mobile or desktop)
  Future<File?> _convertToFlac({
    required String inputPath,
    required String outputPath,
  }) async {
    final logger = DebugLogService();
    bool conversionSuccess = false;

    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile FFmpeg
      logger.info('Converting to FLAC: $inputPath -> $outputPath');
      try {
        // Try copy first (fastest)
        var session = await FFmpegKit.execute(
            '-y -i "$inputPath" -c:a copy "$outputPath"');
        var returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          conversionSuccess = true;
          logger.success('FFmpeg copy conversion successful');
        } else {
          // Fallback to re-encode
          logger.warning('FFmpeg copy failed, trying re-encode...');
          session = await FFmpegKit.execute(
              '-y -i "$inputPath" -c:a flac "$outputPath"');
          returnCode = await session.getReturnCode();

          if (ReturnCode.isSuccess(returnCode)) {
            conversionSuccess = true;
            logger.success('FFmpeg re-encode successful');
          } else {
            final logs = await session.getAllLogsAsString();
            logger.error('FFmpeg re-encode failed: $logs');
          }
        }
      } catch (e) {
        logger.error('FFmpeg Exception: $e');
      }
    } else {
      // Desktop FFmpeg
      final ffmpegPath = await _getFFmpegPath();
      if (ffmpegPath != null) {
        try {
          final result = await Process.run(
            ffmpegPath,
            ['-y', '-i', inputPath, '-c:a', 'copy', outputPath],
            runInShell: true,
          );

          if (result.exitCode == 0 && await File(outputPath).exists()) {
            conversionSuccess = true;
            debugPrint('✓ Desktop FFmpeg conversion successful');
          } else {
            debugPrint('⚠️ Desktop FFmpeg conversion failed: ${result.stderr}');
          }
        } catch (e) {
          debugPrint('⚠️ Desktop FFmpeg error: $e');
        }
      }
    }

    if (conversionSuccess && await File(outputPath).exists()) {
      return File(outputPath);
    }
    return null;
  }

  /// Low-level file download with progress
  Future<File?> _downloadFile({
    required String url,
    required String outputPath,
    Function(double)? onProgress,
  }) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await _client.send(request);

      if (streamedResponse.statusCode != 200) {
        debugPrint('❌ Download failed: ${streamedResponse.statusCode}');
        return null;
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      int receivedBytes = 0;

      final file = File(outputPath);
      final sink = file.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (contentLength > 0 && onProgress != null) {
          onProgress(receivedBytes / contentLength);
        }
      }

      await sink.flush();
      await sink.close();

      final fileSize = await file.length();
      debugPrint(
          '📁 Downloaded: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      return file;
    } catch (e) {
      debugPrint('❌ Download error: $e');
      return null;
    }
  }

  /// Get the download directory for FLAC files
  Future<String> getFlacDownloadPath(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('custom_download_path');

    final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    if (customPath != null) {
      final dir = Directory(customPath);
      if (await dir.exists()) {
        return '${dir.path}/$safeName.flac';
      }
    }

    // 🚀 Use public Download directory on Android
    String? basePath;

    if (Platform.isAndroid) {
      try {
        final updatePath = Directory("/storage/emulated/0/Download");
        if (await updatePath.exists()) {
          basePath = updatePath.path;
        } else {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            final androidPath = externalDir.path;
            final androidIndex = androidPath.indexOf("/Android/");
            if (androidIndex != -1) {
              basePath = "${androidPath.substring(0, androidIndex)}/Download";
            }
          }
        }
      } catch (e) {
        debugPrint("Error accessing public directory: $e");
      }
    } else if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      basePath = dir.path;
    } else {
      // Desktop: Use Downloads directory
      final dir = await getDownloadsDirectory();
      if (dir != null) {
        basePath = dir.path;
      }
    }

    if (basePath == null) {
      final dir = await getApplicationDocumentsDirectory();
      basePath = dir.path;
    }

    final outputDir = Directory('$basePath/SimpleMusicDownloads');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    return '${outputDir.path}/$safeName.flac';
  }

  /// Get temp cache path for FLAC streaming (separate from downloads)
  Future<String> getFlacCachePath(String filename) async {
    final tempDir = await getTemporaryDirectory();
    final safeName = filename.replaceAll(RegExp(r'[\\/:"*?<>|]'), '_');

    final cacheDir = Directory('${tempDir.path}/SimpleMusicCache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return '${cacheDir.path}/$safeName.flac';
  }
}

// ============================================================
// DATA MODELS
// ============================================================

/// URLs for a track on various streaming platforms
class StreamingUrls {
  final String spotifyId;
  final String? deezerUrl;
  final String? tidalUrl;
  final String? amazonUrl;
  final String? qobuzUrl;

  StreamingUrls({
    required this.spotifyId,
    this.deezerUrl,
    this.tidalUrl,
    this.amazonUrl,
    this.qobuzUrl,
  });

  /// Returns true if FLAC download is available (Deezer or Tidal only)
  /// Amazon is not included as we cannot download FLAC from it
  bool get hasAnyUrl => deezerUrl != null || tidalUrl != null;
}

/// Deezer track metadata
class DeezerTrack {
  final int id;
  final String title;
  final String? isrc;
  final int? duration;
  final int? trackNumber;
  final String artistName;
  final String albumTitle;
  final String? albumCoverUrl;
  final String? releaseDate;

  DeezerTrack({
    required this.id,
    required this.title,
    this.isrc,
    this.duration,
    this.trackNumber,
    required this.artistName,
    required this.albumTitle,
    this.albumCoverUrl,
    this.releaseDate,
  });

  factory DeezerTrack.fromJson(Map<String, dynamic> json) {
    return DeezerTrack(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      isrc: json['isrc'] as String?,
      duration: json['duration'] as int?,
      trackNumber: json['track_position'] as int?,
      artistName: json['artist']?['name'] as String? ?? 'Unknown Artist',
      albumTitle: json['album']?['title'] as String? ?? 'Unknown Album',
      albumCoverUrl: json['album']?['cover_xl'] as String?,
      releaseDate: json['release_date'] as String?,
    );
  }
}

/// Result of a FLAC download attempt
class FlacDownloadResult {
  final bool success;
  final File? file;
  final String? service;
  final String? error;

  FlacDownloadResult._({
    required this.success,
    this.file,
    this.service,
    this.error,
  });

  factory FlacDownloadResult.success(File file, String service) {
    return FlacDownloadResult._(
      success: true,
      file: file,
      service: service,
    );
  }

  factory FlacDownloadResult.failed(String error) {
    return FlacDownloadResult._(
      success: false,
      error: error,
    );
  }
}
