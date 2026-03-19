import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_usage_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../env/env.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'debug_log_service.dart';
import '../utils/filename_helper.dart';

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

  static Ref? globalRef; // Added for Data Usage tracking

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
    final spotifyUrl = 'https://open.spotify.com/track/$spotifyTrackId';
    return getStreamingUrlsFromSpecificUrl(spotifyUrl);
  }

  /// Get streaming URLs from song.link API for ANY provider URL (Spotify, Deezer, etc)
  Future<StreamingUrls?> getStreamingUrlsFromSpecificUrl(
      String resourceUrl) async {
    // Rate limiting
    await _applySongLinkRateLimit();

    try {
      // Build song.link API URL
      const apiBase = 'https://api.song.link/v1-alpha.1/links?url=';
      final apiUrl = '$apiBase${Uri.encodeComponent(resourceUrl)}';

      debugPrint('🔗 Getting streaming URLs from song.link for: $resourceUrl');

      final response = await _client.get(
        Uri.parse(apiUrl),
        headers: {'User-Agent': 'SimpleMusicPlayer/1.0'},
      ).timeout(const Duration(seconds: 15));

      _lastSongLinkCall = DateTime.now();
      _songLinkCallCount++;

      if (response.statusCode == 429) {
        debugPrint('⚠️ song.link rate limit hit, waiting...');
        await Future.delayed(const Duration(seconds: 15));
        return getStreamingUrlsFromSpecificUrl(resourceUrl); // Retry
      }

      if (response.statusCode != 200) {
        debugPrint('❌ song.link API error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final linksByPlatform = data['linksByPlatform'] as Map<String, dynamic>?;

      if (linksByPlatform == null) return null;

      final urls = StreamingUrls(
        spotifyId: '',
        deezerUrl: _extractPlatformUrl(linksByPlatform, 'deezer'),
        tidalUrl: _extractPlatformUrl(linksByPlatform, 'tidal'),
        amazonUrl: _extractPlatformUrl(linksByPlatform, 'amazonMusic'),
        qobuzUrl: _extractPlatformUrl(linksByPlatform, 'qobuz'),
      );

      debugPrint('✓ Found URLs - Deezer: ${urls.deezerUrl != null}, '
          'Tidal: ${urls.tidalUrl != null}, Qobuz: ${urls.qobuzUrl != null}');

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

  /// 🚀 NEW: Direct Tidal Search Fallback on API Server
  Future<String?> getTidalTrackIdBySearch(String title, String artist) async {
    final logger = DebugLogService();
    final servers = await _getTidalApiServers();
    final query = "$title $artist";
    
    logger.info('🔍 Direct Tidal Search: $query');
    
    for (final server in servers) {
      try {
         // Only search if it is a trusted instance that supports it 
         final isSelfHosted = server.contains('stephanus-dev.online');
         if (!isSelfHosted) continue; // Skip public nodes that might not have our new route

         final uri = Uri.parse('$server/search?q=${Uri.encodeComponent(query)}&limit=5&countryCode=US');
         final Map<String, String> headers = {'Accept': 'application/json'};
         
         headers['x-api-key'] = Env.tidalApiKey;
         
         final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
         
         logger.info('📡 Direct Tidal Search Status on $server: ${response.statusCode}');

         if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final tracks = data['tracks'] ?? data; 
            final items = tracks['items'] as List?;
            
            if (items != null && items.isNotEmpty) {
               // 🎧 Prioritize Hi-Res Master tracks if multiple editions exist
               final bestMatch = items.firstWhere(
                  (i) => i['audioQuality'] == 'HI_RES_LOSSLESS' || i['audioQuality'] == 'HI_RES',
                  orElse: () => items.first
               );
               final foundId = bestMatch['id']?.toString();
               if (foundId != null) {
                  logger.success('✅ [Tidal Search] Found Match on $server: $foundId (Quality: ${bestMatch['audioQuality'] ?? 'Standard'})');
                  return foundId;
               }
            } else {
               logger.warning('⚠️ [Tidal Search] No tracks found for $query on $server');
            }
         }
      } catch (e) {
         logger.warning('⚠️ Tidal search failed on $server: $e');
      }
    }
    return null;
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

      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

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
    Ref? ref, // Added for Data Usage
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

    // Download to temp file first, then re-encode to fix bitstream
    final tempPath = outputPath + ".tmp";
    final tempFile = await _downloadFile(
      url: flacUrl,
      outputPath: tempPath,
      onProgress: onProgress,
      ref: ref,
    );

    if (tempFile != null) {
      debugPrint('📥 Deezer download complete, re-encoding to fix bitstream...');
      final convertedFile = await _convertToFlac(
        inputPath: tempPath,
        outputPath: outputPath,
        forceReencode: true, // 🚀 FORCE
      );

      // Cleanup
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}

      if (convertedFile != null) {
        debugPrint('✓ Downloaded and re-encoded from Deezer: ${convertedFile.path}');
        return convertedFile;
      }
    }

    return null;
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

    // 🚀 NEW: Standardized public hifi-api servers
    final fallbackServers = [
      'https://tidal-api.stephanus-dev.online', // Cloudflare domain (Primary)
      'https://triton.squid.wtf', // Priority Fallback (can return previews)
      'https://tnm.ngrok.app', // ngrok proxy
      'https://api.mizu.moe', // mizu.moe hifi-api instance
      'https://l.yokai.ee/api', // yokai api
      'https://arran.monochrome.tf', // New monochrome node
      'https://tidal-api.binimum.org', // hifi-api author's instance
      'https://tidal.squid.wtf', // squid.wtf hifi-api instance
      'https://api.monochrome.tf', // Original monochrome
      'https://eu-central.monochrome.tf', // EU fallback
    ];

    logger.info(
        'TIDAL: Using ${fallbackServers.length} servers (Primary + Public Fallbacks)');

    return fallbackServers;
  }

  /// Download FLAC from Tidal using external API
  /// Tries HI_RES_LOSSLESS first, falls back to LOSSLESS if Hi-Res returns DASH manifest
  Future<File?> downloadFromTidal({
    required String tidalUrl,
    required String outputPath,
    Function(double)? onProgress,
    Ref? ref, // Added for Data Usage
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
          final apiUrl = '$server/track/?id=$trackId&quality=$quality';
          final response = await _client.get(Uri.parse(apiUrl), headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
            'Origin': 'https://monochrome.tf',
            'Referer': 'https://monochrome.tf/',
            'x-api-key': '8f7G2k9P5mQ1nL4vW6xZ', // Your 20-character secure key
          }).timeout(const Duration(seconds: 30));

          if (response.statusCode != 200) continue;

          // Check if response is XML (DASH manifest) - skip if so
          final body = response.body.trim();
          if (body.startsWith('<?xml') || body.startsWith('<MPD')) {
            debugPrint(
                '⚠️ $quality returned DASH manifest, trying lower quality...');
            break; // Try next quality level
          }

          // 🚀 FIX: Check if response is raw binary FLAC data (self-hosted server returns raw bytes)
          // FLAC files start with the magic bytes "fLaC"
          if (response.bodyBytes.length > 4 &&
              response.bodyBytes[0] == 0x66 && // 'f'
              response.bodyBytes[1] == 0x4C && // 'L'
              response.bodyBytes[2] == 0x61 && // 'a'
              response.bodyBytes[3] == 0x43) { // 'C'
            debugPrint('🎧 Received raw FLAC binary from $server ($quality). Saving directly...');
            final tempPath = outputPath + ".tmp";
            final tempFile = File(tempPath);
            await tempFile.writeAsBytes(response.bodyBytes);

            debugPrint('📥 Raw FLAC: ${(response.bodyBytes.length / 1024 / 1024).toStringAsFixed(1)} MB. Re-encoding...');
            final convertedFile = await _convertToFlac(
              inputPath: tempPath,
              outputPath: outputPath,
              forceReencode: true,
            );

            try { await tempFile.delete(); } catch (_) {}

            if (convertedFile != null) {
              debugPrint('✓ Downloaded and re-encoded from Tidal ($quality) via $server: ${convertedFile.path}');
              return convertedFile;
            }
            continue; // Try next server if re-encode failed
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
          final tempPath = outputPath + ".tmp";
          final file = await _downloadFile(
            url: downloadUrl,
            outputPath: tempPath,
            onProgress: onProgress,
            ref: ref,
          );

          if (file != null) {
            debugPrint('📥 Download complete, re-encoding to fix bitstream (MANDATORY)...');
            final convertedFile = await _convertToFlac(
              inputPath: tempPath,
              outputPath: outputPath,
              forceReencode: true, // 🚀 FORCE
            );

            // Cleanup
            try { await file.delete(); } catch (_) {}

            if (convertedFile != null) {
              debugPrint('✓ Downloaded and re-encoded from Tidal ($quality) via $server: ${convertedFile.path}');
              return convertedFile;
            }
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
    
    // 🚀 NEW: DIRECT TIDAL SEARCH FALLBACK
    String? fallbackTidalId;
    if (urls == null || urls.tidalUrl == null) {
      logger.info('⚠️ song.link didn\'t find Tidal URL for $trackName. Trying Direct Search...');
      fallbackTidalId = await getTidalTrackIdBySearch(trackName ?? '', artistName ?? '');
    }

    if (urls == null && fallbackTidalId == null) {
      logger.warning("FLAC: No streaming URLs found and direct search failed");
      return FlacDownloadResult.failed('Could not find track on any platform');
    }

    final resolvedTidalUrl = urls?.tidalUrl ?? (fallbackTidalId != null ? 'https://tidal.com/track/$fallbackTidalId' : null);

    logger.info(
        "FLAC: URLs found - Tidal: ${resolvedTidalUrl != null}, Deezer: ${urls?.deezerUrl != null}");

    File? file;

    // === STEP 1: Try Tidal HI_RES_LOSSLESS first ===
    if (resolvedTidalUrl != null) {
      debugPrint('🎧 Step 1: Trying Tidal HI_RES_LOSSLESS...');
      logger.info('FLAC: Step 1 - Trying Tidal HI_RES_LOSSLESS...');
      file = await downloadFromTidalWithQuality(
        tidalUrl: resolvedTidalUrl,
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

    // === STEP 2: Try Qobuz FLAC/Hi-Res ===
    if (urls?.qobuzUrl != null) {
      debugPrint('🎧 Step 2: Trying Qobuz FLAC...');
      logger.info('FLAC: Step 2 - Trying Qobuz FLAC...');
      file = await _downloadFromQobuz(
        qobuzUrl: urls!.qobuzUrl!,
        outputPath: outputPath,
        onProgress: onProgress,
      );
      if (file != null) {
        logger.success('FLAC: Qobuz download success');
        return FlacDownloadResult.success(file, 'qobuz');
      }
      logger.warning('FLAC: Qobuz failed');
    }

    // === STEP 3: Try Deezer (CD quality) ===
    if (urls?.deezerUrl != null) {
      debugPrint('🎧 Step 3: Trying Deezer FLAC...');
      logger.info('FLAC: Step 3 - Trying Deezer FLAC...');
      file = await downloadFromDeezer(
        deezerUrl: urls!.deezerUrl!,
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

    // === STEP 4: Try Tidal LOSSLESS (CD quality fallback) ===
    if (resolvedTidalUrl != null) {
      debugPrint('🎧 Step 4: Trying Tidal LOSSLESS (CD quality)...');
      file = await downloadFromTidalWithQuality(
        tidalUrl: resolvedTidalUrl,
        outputPath: outputPath,
        quality: 'LOSSLESS',
        onProgress: onProgress,
      );
      if (file != null) {
        return FlacDownloadResult.success(file, 'tidal-lossless');
      }
    }

    return FlacDownloadResult.failed('Download failed on all services');
  }

  /// Helper to download from Tidal with specific quality
  /// Supports both direct URL and DASH manifest formats
  Future<File?> downloadFromTidalWithQuality({
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
        String apiUrl = '$server/track/?id=$trackId&quality=$quality';

        final Map<String, String> requestHeaders = {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
          'Origin': 'https://monochrome.tf',
          'Referer': 'https://monochrome.tf/',
        };

        if (server.contains('stephanus-dev.online')) {
          requestHeaders['x-api-key'] = Env.tidalApiKey;
          // Also send as a parameter as requested
          apiUrl += '&key=${Env.tidalApiKey}';
        }

        final request = http.Request('GET', Uri.parse(apiUrl));
        request.headers.addAll(requestHeaders);

        final response = await _client.send(request).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final contentLength = response.contentLength ?? 0;
          
          final tempPath = '$outputPath.tmp';
          final tempFile = File(tempPath);
          final sink = tempFile.openWrite();
          
          int downloadedBytes = 0;
          final List<int> headerBytes = [];
          bool headerChecked = false;
          bool isValidFlac = true;

          logger.info('TIDAL: Streaming direct file buffer from $server...');

          // Stream chunks to file and update progress
          await for (final chunk in response.stream) {
            if (!headerChecked) {
              headerBytes.addAll(chunk);
              if (headerBytes.length >= 4) {
                 final hasFlacHeader = headerBytes[0] == 0x66 && 
                                       headerBytes[1] == 0x4C && 
                                       headerBytes[2] == 0x61 && 
                                       headerBytes[3] == 0x43;
                 if (!hasFlacHeader) {
                    isValidFlac = false;
                    break; 
                 }
                 headerChecked = true;
              }
            }
            
            sink.add(chunk);
            downloadedBytes += chunk.length;
            
            // Send Progress to UI (assume ~50MB if length unknown for smoother UX)
            if (onProgress != null) {
              final total = contentLength > 0 ? contentLength : 50 * 1024 * 1024;
              double progress = downloadedBytes / total;
              
              // If using assumed total, cap at 99% until fully done
              if (contentLength <= 0 && progress > 0.99) progress = 0.99;
              
              onProgress(progress.clamp(0.0, 1.0));
            }
          }
          await sink.flush();
          await sink.close();

          if (!isValidFlac) {
             logger.warning('TIDAL: Server $server returned non-FLAC response, skipping');
             try { await tempFile.delete(); } catch(_) {}
             continue;
          }

          if (downloadedBytes < 100 * 1024) {
             logger.warning('TIDAL: Server $server returned only ${(downloadedBytes / 1024).toStringAsFixed(1)}KB — too small, skipping');
             try { await tempFile.delete(); } catch(_) {}
             continue;
          }

          // Increment Data Usage
          final activeRef = FlacDownloaderService.globalRef;
          if (activeRef != null) {
            activeRef.read(dataUsageProvider.notifier).addBytes(downloadedBytes);
          }

          logger.info('TIDAL: Received ${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)}MB FLAC from $server ($quality). Re-encoding...');

          // Re-encode (MANDATORY for bitstream fix)
          final convertedFile = await _convertToFlac(
            inputPath: tempPath,
            outputPath: outputPath,
            forceReencode: true,
          );

          // Cleanup temp
          try { await tempFile.delete(); } catch (_) {}

          if (convertedFile != null) {
            logger.info('TIDAL: ✅ Re-encoded from $server ($quality): ${convertedFile.path}');
            if (onProgress != null) onProgress(1.0); // Ensure 100%
            return convertedFile;
          }

          logger.warning('TIDAL: Re-encode failed for $server, trying next...');
          continue;
        }

        // For non-200 responses (like 202 or errors), we need the body as string to parse JSON
        final bodyBytes = await response.stream.toBytes();
        final bodyString = utf8.decode(bodyBytes);
        
        // Create a mock response object interface for the 202 handler below
        final responseBody = bodyString;

        // === TWO-STEP DOWNLOAD: Server returns 202 while processing ===
        if (response.statusCode == 202) {
          try {
            final jobData = json.decode(responseBody);
            final jobId = jobData['jobId'] as String?;
            if (jobId == null) {
              logger.warning('TIDAL: Got 202 but no jobId');
              continue;
            }
            logger.info('TIDAL: Download started, jobId=$jobId. Polling...');

            // Poll /status/ until done (max 3 minutes)
            String jobStatus = 'processing';
            int totalChunks = 0;
            int totalSize = 0;
            for (int i = 0; i < 90; i++) {
              await Future.delayed(const Duration(seconds: 2));
              try {
                String statusUrl = '$server/status/?jobId=$jobId';
                if (server.contains('stephanus-dev.online')) {
                  statusUrl += '&key=${Env.tidalApiKey}';
                }

                final statusResp = await _client
                    .get(
                      Uri.parse(statusUrl),
                      headers: requestHeaders,
                    )
                    .timeout(const Duration(seconds: 10));
                if (statusResp.statusCode == 200) {
                  final statusData = json.decode(statusResp.body);
                  jobStatus = statusData['status'] as String? ?? 'processing';
                  if (jobStatus == 'done') {
                    totalChunks = statusData['totalChunks'] as int? ?? 1;
                    totalSize = statusData['size'] as int? ?? 0;
                    logger.info(
                        'TIDAL: Job $jobId done! $totalChunks chunks, ${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB');
                    break;
                  } else if (jobStatus == 'error') {
                    logger.warning(
                        'TIDAL: Job $jobId failed: ${statusData['error']}');
                    break;
                  }
                }
              } catch (pollErr) {
                debugPrint('⚠️ Poll error: $pollErr');
              }
            }

            if (jobStatus != 'done') {
              logger.warning(
                  'TIDAL: Job $jobId did not complete (status=$jobStatus)');
              continue;
            }

            // Download in chunks (5 MB each, Cloudflare-safe)
            final tempPath = outputPath + ".tmp";
            final file = File(tempPath);
            bool downloadOk = true;

            final isSelfHosted = server.contains('stephanus-dev.online');

            if (isSelfHosted) {
              logger.info('TIDAL: Server is self-hosted. Downloading full buffer directly (streamed)...');
              String downloadUrl = '$server/track/?id=$trackId&quality=$quality&key=${Env.tidalApiKey}';
              final downloadedFile = await _downloadFile(
                url: downloadUrl,
                outputPath: tempPath,
                headers: requestHeaders,
                onProgress: onProgress,
              );
              
              if (downloadedFile != null) {
                downloadOk = true;
              } else {
                logger.warning('TIDAL: Full buffer streamed download failed or returned invalid file');
                downloadOk = false;
              }
            } else {
              final sink = file.openWrite();
              for (int c = 0; c < totalChunks; c++) {
                try {
                  logger.info('TIDAL: Downloading chunk ${c + 1}/$totalChunks...');
                  String chunkUrl = '$server/download/?jobId=$jobId&chunk=$c';
                  final chunkResp = await _client
                      .get(Uri.parse(chunkUrl), headers: requestHeaders)
                      .timeout(const Duration(seconds: 30));

                  if (chunkResp.statusCode == 200 && chunkResp.bodyBytes.isNotEmpty) {
                    sink.add(chunkResp.bodyBytes);
                    
                    // Increment Data Usage
                    final activeRef = FlacDownloaderService.globalRef;
                    if (activeRef != null) {
                      activeRef.read(dataUsageProvider.notifier).addBytes(chunkResp.bodyBytes.length);
                    }
                    if (onProgress != null) {
                      onProgress((c + 1) / totalChunks);
                    }
                  } else {
                    logger.warning('TIDAL: Chunk $c failed: ${chunkResp.statusCode}');
                    downloadOk = false;
                    break;
                  }
                } catch (chunkErr) {
                  logger.warning('TIDAL: Chunk $c error: $chunkErr');
                  downloadOk = false;
                  break;
                }
              }
              await sink.close();
            }

            if (downloadOk) {
              final fileSize = await file.length();
              if (fileSize > 1024 * 1024) {
                logger.info('TIDAL: Chunked download success! Re-encoding to fix bitstream (MANDATORY)...');
                
                // 🚀 FIX: FORCE Re-encode to reconstructions sync codes and remove fMP4 headers
                final convertedFile = await _convertToFlac(
                  inputPath: tempPath,
                  outputPath: outputPath,
                  forceReencode: true, // MANDATORY
                );

                // Cleanup temp
                try { await file.delete(); } catch (_) {}

                if (convertedFile != null) {
                   logger.success('TIDAL: Chunked download and re-encode success! ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
                   return convertedFile;
                }
                logger.error('TIDAL: Re-encode failed for chunked download');
              } else {
                logger.warning('TIDAL: Downloaded file too small ($fileSize bytes)');
                try { await file.delete(); } catch (_) {}
              }
            } else {
              logger.error('TIDAL: Chunked download ABORTED due to segment failure');
              try { await file.delete(); } catch (_) {}
            }
            continue;
          } catch (twoStepErr) {
            logger.warning('TIDAL: Two-step download error: $twoStepErr');
            continue;
          }
        }

        if (response.statusCode != 200) {
          logger
              .warning("TIDAL: Server $server returned ${response.statusCode}");
          debugPrint("📋 Error body: $responseBody");
          try {
            final errorData = json.decode(responseBody);
            if (errorData['detail'] != null) {
              logger.error("TIDAL ERROR: ${errorData['detail']}");
            }
          } catch (_) {}
          continue;
        }

        // === DIRECT FLAC BINARY (cache hit or direct response) ===
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('audio/flac') ||
            contentType.contains('audio/x-flac')) {
          final contentLengthStr = response.headers['content-length'];
          final totalBytes = contentLengthStr != null
              ? int.tryParse(contentLengthStr) ?? 1
              : 1;

          logger.info(
              'TIDAL: Got direct FLAC binary from $server ($totalBytes bytes). Streaming to file...');

          // For direct binary, we need to use a streamed request to get progress
          String directUrl = apiUrl;
          if (server.contains('stephanus-dev.online')) {
            directUrl += '&key=${Env.tidalApiKey}';
          }

          final streamedRequest = http.Request('GET', Uri.parse(directUrl));
          streamedRequest.headers.addAll(requestHeaders);

          final streamedResponse = await _client
              .send(streamedRequest)
              .timeout(const Duration(seconds: 120));

          if (streamedResponse.statusCode != 200) {
            logger.warning(
                'TIDAL: Streamed direct request failed: ${streamedResponse.statusCode}');
            continue;
          }

          final tempPath = outputPath + ".tmp";
          final file = File(tempPath);
          final sink = file.openWrite();
          int downloadedBytes = 0;

          int directAccumulator = 0; // Added for Data Usage tracking

          try {
            await for (final chunk in streamedResponse.stream) {
              sink.add(chunk);
              downloadedBytes += chunk.length;
              directAccumulator += chunk.length; // Added

              // Optimal update
              if (directAccumulator > 1024 * 1024) {
                final activeRef = FlacDownloaderService.globalRef;
                if (activeRef != null) {
                  activeRef.read(dataUsageProvider.notifier).addBytes(directAccumulator);
                }
                directAccumulator = 0;
              }

              if (onProgress != null && totalBytes > 1) {
                onProgress(downloadedBytes / totalBytes);
              }
            }
          } finally {
            // Flush remainder bytes (Handles failed downloads too)
            if (directAccumulator > 0) {
              final activeRef = FlacDownloaderService.globalRef;
              if (activeRef != null) {
                activeRef.read(dataUsageProvider.notifier).addBytes(directAccumulator);
              }
              directAccumulator = 0;
            }
          }

          await sink.close();

          final fileSize = await file.length();
          if (fileSize < 1024 * 1024) {
            logger.warning('TIDAL: Direct FLAC too small (${fileSize} bytes), likely preview');
            try { await file.delete(); } catch (_) {}
            continue;
          }

          logger.info('TIDAL: Direct download success! Re-encoding to fix bitstream...');
          
          // 🚀 FIX: FORCE Re-encode to avoid sync issues
          final convertedFile = await _convertToFlac(
            inputPath: tempPath,
            outputPath: outputPath,
            forceReencode: true, // MANDATORY
          );

          // Cleanup temp
          try { await file.delete(); } catch (_) {}

          if (convertedFile != null) {
            logger.success('TIDAL: Direct FLAC download and re-encode success (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
            return convertedFile;
          }
          logger.error('TIDAL: Re-encode failed for direct download');
          continue;
        }

        final body = responseBody.trim();

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
                  '✓ Downloaded Hi-Res from embedded DASH via $server: ${file.path}');
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
          debugPrint('📥 Direct download complete, re-encoding to fix bitstream (MANDATORY)...');
          // Apply same FFmpeg conversion as DASH downloads
          final convertedFile = await _convertToFlac(
            inputPath: tempPath,
            outputPath: outputPath,
            forceReencode: true, // 🚀 FORCE
          );

          // Cleanup temp file
          try {
            if (await tempFile.exists()) await tempFile.delete();
          } catch (_) {}

          if (convertedFile != null) {
            debugPrint(
                '✓ Downloaded and re-encoded from Tidal ($quality): ${convertedFile.path}');
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

  /// Extract Qobuz track ID from URL
  /// Handles formats like: https://www.qobuz.com/us-en/album/.../track_id
  /// or https://open.qobuz.com/track/track_id
  String? _extractQobuzTrackId(String qobuzUrl) {
    try {
      final uri = Uri.parse(qobuzUrl);
      final segments = uri.pathSegments;

      // Format: /track/12345 or /us-en/album/.../12345
      // Try to get the last numeric segment
      for (int i = segments.length - 1; i >= 0; i--) {
        if (RegExp(r'^\d+$').hasMatch(segments[i])) {
          return segments[i];
        }
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ Could not extract Qobuz track ID from: $qobuzUrl');
      return null;
    }
  }

  /// Download FLAC from Qobuz using qobuz.squid.wtf API
  /// Quality codes: 5=HiRes 192/24, 6=HiRes 96/24, 7=FLAC, 27=MP3 320
  Future<File?> _downloadFromQobuz({
    required String qobuzUrl,
    required String outputPath,
    Function(double)? onProgress,
  }) async {
    final trackId = _extractQobuzTrackId(qobuzUrl);
    if (trackId == null) {
      debugPrint('❌ Could not extract Qobuz track ID from: $qobuzUrl');
      return null;
    }

    final logger = DebugLogService();
    const qobuzApiBase = 'https://qobuz.squid.wtf/api';

    // Try qualities in order: HiRes 192/24 → HiRes 96/24 → FLAC
    final qualities = ['5', '6', '7'];

    for (final quality in qualities) {
      try {
        final apiUrl =
            '$qobuzApiBase/download-music?track_id=$trackId&quality=$quality';
        logger.info('QOBUZ: Requesting $apiUrl');

        final response = await _client.get(
          Uri.parse(apiUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          logger.warning(
              'QOBUZ: API returned ${response.statusCode} for quality $quality');
          continue;
        }

        final data = json.decode(response.body);

        if (data['success'] != true || data['data']?['url'] == null) {
          logger.warning('QOBUZ: No download URL for quality $quality');
          continue;
        }

        final downloadUrl = data['data']['url'] as String;
        debugPrint('📥 Downloading from Qobuz (quality=$quality)...');
        logger.info('QOBUZ: Got download URL, downloading...');

        // Download to temp file first
        final tempPath = outputPath + ".tmp";
        final file = await _downloadFile(
          url: downloadUrl,
          outputPath: tempPath,
          onProgress: onProgress,
        );

        if (file != null) {
          final fileSize = await file.length();
          debugPrint('📥 Qobuz download complete, re-encoding to fix bitstream...');
          
          final convertedFile = await _convertToFlac(
            inputPath: tempPath,
            outputPath: outputPath,
            forceReencode: true, // 🚀 FORCE
          );

          // Cleanup
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {}

          if (convertedFile != null) {
            debugPrint('✓ Downloaded and re-encoded from Qobuz ($quality): ${convertedFile.path}');
            logger.success('QOBUZ: Download and re-encode success (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
            return convertedFile;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Qobuz quality $quality failed: $e');
        logger.warning('QOBUZ: Quality $quality failed: $e');
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
    Ref? ref, // Added for Data Usage
  }) async {
    final activeRef = ref ?? FlacDownloaderService.globalRef; // Added
    final logger = DebugLogService();
    try {
      final List<String> segmentUrls = [];

      // DUMP MANIFEST FOR DEBUGGING (Round 5)
      final dumpLen = manifestXml.length > 2000 ? 2000 : manifestXml.length;
      debugPrint(
          '📄 DASH Manifest Dump (First $dumpLen chars):\n${manifestXml.substring(0, dumpLen)}');

      // Helper to find attribute in a string/tag (handles namespaces)
      String? getAttr(String source, String name) {
        final regex = RegExp('(?:\\w+:)?$name="([^"]+)"');
        return regex.firstMatch(source)?.group(1);
      }

      // 0. Parse total duration (Round 5: Look at MPD and Period levels)
      double totalDurationSeconds = 0;

      // Try MPD level mediaPresentationDuration
      final mpdDurationStr = getAttr(manifestXml, 'mediaPresentationDuration');
      // Try Period level duration
      final periodDurationStr = RegExp(r'<Period\s+[^>]*?duration="([^"]+)"')
          .firstMatch(manifestXml)
          ?.group(1);

      final bestDurationStr = mpdDurationStr ?? periodDurationStr;

      if (bestDurationStr != null) {
        final match = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:([\d.]+)S)?')
            .firstMatch(bestDurationStr);
        if (match != null) {
          final h = double.tryParse(match.group(1) ?? '0') ?? 0;
          final m = double.tryParse(match.group(2) ?? '0') ?? 0;
          final s = double.tryParse(match.group(3) ?? '0') ?? 0;
          totalDurationSeconds = (h * 3600) + (m * 60) + s;
          debugPrint(
              '⏱️ DASH: Duration parsed from ${mpdDurationStr != null ? "MPD" : "Period"} field: ${totalDurationSeconds.toStringAsFixed(1)}s');
        }
      }

      // Fallback: If duration is still 0 or very small, search for any PT...S in the whole manifest
      if (totalDurationSeconds < 10) {
        final allDurations = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:([\d.]+)S)?')
            .allMatches(manifestXml);
        for (final m in allDurations) {
          final seconds = (double.tryParse(m.group(1) ?? '0') ?? 0) * 3600 +
              (double.tryParse(m.group(2) ?? '0') ?? 0) * 60 +
              (double.tryParse(m.group(3) ?? '0') ?? 0);
          if (seconds > totalDurationSeconds) {
            totalDurationSeconds = seconds;
            debugPrint(
                '⏱️ DASH: Duration updated from fallback PT scan: ${totalDurationSeconds.toStringAsFixed(1)}s');
          }
        }
      }

      debugPrint(
          '⏱️ DASH: Calculated total duration: ${totalDurationSeconds.toStringAsFixed(2)}s');

      // PREVIEW REJECTION (Round 6)
      // If duration is ~30s (±15s), it's almost certainly a Tidal preview.
      // We reject it to allow fallback to other servers or LOSSLESS quality.
      if (totalDurationSeconds > 0 && totalDurationSeconds < 45) {
        logger.warning(
            'DASH: Detected preview duration (${totalDurationSeconds.toStringAsFixed(1)}s). Rejecting to trigger fallback.');
        return null;
      }
      // 1. Identify Representations and pick best
      final representationRegex = RegExp(
          r'<(?:\w+:)?Representation\s+([^>]+)>(.*?)</(?:\w+:)?Representation>',
          dotAll: true);
      final representations =
          representationRegex.allMatches(manifestXml).toList();
      if (representations.isEmpty) {
        logger.error('DASH: No representations found');
        return null;
      }

      int highestBandwidth = -1;
      Match? bestRepMatch;
      for (final match in representations) {
        final bw =
            int.tryParse(getAttr(match.group(1)!, 'bandwidth') ?? '0') ?? 0;
        if (bw > highestBandwidth) {
          highestBandwidth = bw;
          bestRepMatch = match;
        }
      }
      bestRepMatch ??= representations.first;
      final bestRepAttr = bestRepMatch.group(1)!;
      final bestRepContent = bestRepMatch.group(2)!;

      // 2. Extract Template (Inherit attributes)
      String? templateAttr;
      String? timelineContent;

      final templateRegex = RegExp(
          r'<(?:\w+:)?SegmentTemplate\s+([^>]*?)(?:/>|>(.*?)</(?:\w+:)?SegmentTemplate>)',
          dotAll: true);

      var tMatch = templateRegex.firstMatch(bestRepContent);
      if (tMatch != null) {
        templateAttr = tMatch.group(1);
        timelineContent = tMatch.group(2);
      } else {
        tMatch = templateRegex.firstMatch(manifestXml);
        if (tMatch != null) {
          templateAttr = tMatch.group(1);
          timelineContent = tMatch.group(2);
        }
      }

      if (templateAttr == null) {
        logger.error('DASH: No SegmentTemplate found');
        return null;
      }

      final timescale = double.tryParse(getAttr(templateAttr, 'timescale') ??
              getAttr(bestRepAttr, 'timescale') ??
              getAttr(manifestXml, 'timescale') ??
              '1') ??
          1;
      final startNumber =
          int.tryParse(getAttr(templateAttr, 'startNumber') ?? '1') ?? 1;
      final mediaTemplate = getAttr(templateAttr, 'media');
      final initTemplate = getAttr(templateAttr, 'initialization');

      if (mediaTemplate == null) {
        logger.error('DASH: Missing media template');
        return null;
      }

      // 3. BaseURL
      final manifestBaseUrls =
          RegExp(r'<(?:\w+:)?BaseURL>([^<]+)</(?:\w+:)?BaseURL>')
              .allMatches(manifestXml)
              .map((m) => m.group(1)!)
              .toList();
      String baseUrl =
          manifestBaseUrls.isNotEmpty ? manifestBaseUrls.first : '';
      if (!baseUrl.startsWith('http')) {
        final domainMatch =
            RegExp(r'(https?://[^/\s<>"]+)').firstMatch(manifestXml);
        if (domainMatch != null) {
          final domain = domainMatch.group(1)!;
          baseUrl = baseUrl.startsWith('/')
              ? domain + baseUrl
              : domain + (baseUrl.isEmpty ? '/' : '/$baseUrl');
        }
      }

      if (initTemplate != null) {
        segmentUrls.add(initTemplate.startsWith('http')
            ? initTemplate
            : '$baseUrl$initTemplate');
      }

      // 4. Timeline
      timelineContent ??= RegExp(
              r'<(?:\w+:)?SegmentTimeline>(.*?)</(?:\w+:)?SegmentTimeline>',
              dotAll: true)
          .firstMatch(manifestXml)
          ?.group(1);

      if (timelineContent != null) {
        final sTagRegex = RegExp(
            r'<(?:\w+:)?S\s+([^>]*?)(?:/>|>(?:.*?)</(?:\w+:)?S>)',
            dotAll: true);
        final sMatches = sTagRegex.allMatches(timelineContent);
        int currentNumber = startNumber;
        int currentTime = 0;

        for (final sMatch in sMatches) {
          final attr = sMatch.group(1)!;
          final t = getAttr(attr, 't');
          final d = getAttr(attr, 'd');
          final r = getAttr(attr, 'r');

          if (d == null) continue;
          final durationTicks = int.parse(d);
          int repeat = int.tryParse(r ?? '0') ?? 0;

          if (t != null) currentTime = int.parse(t);

          if (repeat < 0) {
            if (totalDurationSeconds > 0) {
              final totalTicks = totalDurationSeconds * timescale;
              final remainingTicks = totalTicks - currentTime;
              if (remainingTicks > 0) {
                repeat = (remainingTicks / durationTicks).floor() - 1;
                if (repeat < 0) repeat = 0;
                debugPrint(
                    '🔄 Calculated r=$repeat for infinite segment (remainingTicks=$remainingTicks)');
              }
            } else {
              // Final Fallback: If duration unknown, try to guess song is 4 mins
              debugPrint(
                  '⚠️ DASH: Duration unknown for r="-1", assuming 4min fallback');
              final remainingTicks = (240 * timescale) - currentTime;
              repeat = (remainingTicks / durationTicks).floor() - 1;
              if (repeat < 0) repeat = 0;
            }
          }

          for (int i = 0; i <= repeat; i++) {
            String name = mediaTemplate;
            final numRegex = RegExp(r'\$Number(%0(\d)d)?\$');
            name = name.replaceAllMapped(
                numRegex,
                (m) => m.group(2) != null
                    ? currentNumber
                        .toString()
                        .padLeft(int.parse(m.group(2)!), '0')
                    : currentNumber.toString());
            final timeRegex = RegExp(r'\$Time(%0(\d)d)?\$');
            name = name.replaceAllMapped(
                timeRegex,
                (m) => m.group(2) != null
                    ? currentTime
                        .toString()
                        .padLeft(int.parse(m.group(2)!), '0')
                    : currentTime.toString());

            final segmentUrl = name.startsWith('http') ? name : '$baseUrl$name';
            segmentUrls.add(segmentUrl);

            currentNumber++;
            currentTime += durationTicks;

            // Avoid infinite loops if something goes wrong
            if (segmentUrls.length > 500) break;
          }
          if (segmentUrls.length > 500) break;
        }
      }

      if (segmentUrls.isEmpty) return null;

      debugPrint('📥 DASH: Downloading ${segmentUrls.length} segments...');

      // USE SYSTEM TEMP DIRECTORY FOR INTERMEDIATE FILE
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/smp_dash_temp_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final tempFile = File(tempPath);

      try {
        final sink = tempFile.openWrite();
        int downloadedCount = 0;
        int totalBytes = 0;

        for (int i = 0; i < segmentUrls.length; i++) {
          try {
            final resp = await _client.get(Uri.parse(segmentUrls[i]), headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
            }).timeout(const Duration(seconds: 15));
            if (resp.statusCode != 200) {
              debugPrint(
                  '⚠️ DASH: Failed segment $i (${resp.statusCode} ${resp.reasonPhrase})');
              continue;
            }
            sink.add(resp.bodyBytes);
            totalBytes += resp.bodyBytes.length;
            if (activeRef != null) {
              activeRef.read(dataUsageProvider.notifier).addBytes(resp.bodyBytes.length);
            }
            downloadedCount++;
            if (onProgress != null)
              onProgress(downloadedCount / segmentUrls.length);
          } catch (e) {
            logger.error('⚠️ DASH: Error downloading segment: $e. ABORTING.');
            downloadedCount = 0; // Trigger failure
            break;
          }
        }

        await sink.flush();
        await sink.close();

        logger.info(
            "DASH: Downloaded $totalBytes bytes ($downloadedCount/${segmentUrls.length} segments)");

        if (downloadedCount < segmentUrls.length) {
          logger.error("DASH: Download incomplete ($downloadedCount/${segmentUrls.length}), rejecting.");
          return null;
        }

        // SIZE-BASED PREVIEW REJECTION
        if (totalBytes < 10 * 1024 * 1024) {
          logger.warning(
              'DASH: Downloaded size too small (${(totalBytes / 1024 / 1024).toStringAsFixed(1)}MB). Rejecting as suspected preview.');
          return null;
        }

        // 5. FFmpeg (FORCE RE-ENCODE)
        bool success = false;
        final convertedFile = await _convertToFlac(
          inputPath: tempPath,
          outputPath: outputPath,
          forceReencode: true,
        );
        if (convertedFile != null) success = true;

        if (success) {
          return File(outputPath);
        } else {
          logger
              .error('DASH: FFmpeg re-encode failed');
          return null;
        }
      } finally {
        // ALWAYS CLEAN UP TEMP FILE
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
            debugPrint('🧹 DASH: Cleaned up temporary file: $tempPath');
          }
        } catch (e) {
          debugPrint('⚠️ DASH: Failed to cleanup temp file: $e');
        }
      }
    } catch (e) {
      logger.error('DASH fatal error: $e');
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
    bool forceReencode = false, // 🚀 Added
  }) async {
    final logger = DebugLogService();
    bool conversionSuccess = false;

    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile FFmpeg
      logger.info('Converting to FLAC: $inputPath -> $outputPath (forceReencode: $forceReencode)');
      try {
        String command = forceReencode 
            ? '-y -i "$inputPath" -c:a flac "$outputPath"'
            : '-y -i "$inputPath" -c:a copy "$outputPath"';
            
        var session = await FFmpegKit.execute(command);
        var returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          conversionSuccess = true;
          logger.success('FFmpeg ${forceReencode ? "re-encode" : "copy"} successful');
        } else if (!forceReencode) {
          // Fallback to re-encode if copy failed
          logger.warning('FFmpeg copy failed, trying re-encode...');
          session = await FFmpegKit.execute('-y -i "$inputPath" -c:a flac "$outputPath"');
          returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            conversionSuccess = true;
            logger.success('FFmpeg re-encode fallback successful');
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
          final ffmpegFile = File(ffmpegPath);
          final workingDir = ffmpegFile.parent.path;
          final exeName = ffmpegFile.uri.pathSegments.last;

          List<String> args = forceReencode
              ? ['-y', '-i', inputPath, '-c:a', 'flac', outputPath]
              : ['-y', '-i', inputPath, '-c:a', 'copy', outputPath];

          var result = await Process.run(exeName, args, workingDirectory: workingDir, runInShell: false);

          if (result.exitCode == 0 && await File(outputPath).exists()) {
            conversionSuccess = true;
            debugPrint('✓ Desktop FFmpeg ${forceReencode ? "re-encode" : "copy"} successful');
          } else if (!forceReencode) {
            // Fallback
            debugPrint('⚠️ Copy failed, trying re-encode...');
            args = ['-y', '-i', inputPath, '-c:a', 'flac', outputPath];
            result = await Process.run(exeName, args, workingDirectory: workingDir, runInShell: false);
            if (result.exitCode == 0 && await File(outputPath).exists()) {
              conversionSuccess = true;
            }
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
    Map<String, String>? headers,
    Ref? ref, 
  }) async {
    final activeRef = ref ?? FlacDownloaderService.globalRef; // Added
    IOSink? sink;
    File file = File(outputPath);
    bool success = false;
    int chunkAccumulator = 0; 

    try {
      final request = http.Request('GET', Uri.parse(url));
      if (headers != null) {
        request.headers.addAll(headers);
      }
      final streamedResponse = await _client.send(request);

      if (streamedResponse.statusCode != 200) {
        debugPrint('❌ Download failed: ${streamedResponse.statusCode}');
        return null;
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      int receivedBytes = 0;

      sink = file.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        chunkAccumulator += chunk.length; 

        // Optimal update
        if (chunkAccumulator > 1024 * 1024) {
          if (activeRef != null) {
            activeRef.read(dataUsageProvider.notifier).addBytes(chunkAccumulator);
          }
          chunkAccumulator = 0;
        }

        // 🚀 Improved Progress Handling: fallback to assumed 50MB if length unknown
        if (onProgress != null) {
          final total = contentLength > 0 ? contentLength : 50 * 1024 * 1024;
          double progress = receivedBytes / total;
          
          // If using assumed total, cap at 99% until fully done
          if (contentLength <= 0 && progress > 0.99) progress = 0.99;
          
          onProgress(progress.clamp(0.0, 1.0));
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final fileSize = await file.length();
      debugPrint(
          '📁 Downloaded: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // 1. Reject suspiciously small files (< 1MB = likely a preview/fragment)
      if (fileSize < 1024 * 1024) {
        debugPrint(
            '⚠️ File too small (${fileSize} bytes), likely a preview/fragment. Rejecting.');
        throw Exception("File too small");
      }

      // 2. 🚀 VALIDATE FLAC HEADER
      if (!await FlacDownloaderService.isFlacFileValid(outputPath)) {
        debugPrint('❌ FLAC Validation Failed: Invalid sync code or header');
        throw Exception("Invalid FLAC header");
      }

      success = true;
      return file;
    } catch (e) {
      debugPrint('❌ Download error: $e');
      return null;
    } finally {
      // Flush remainder bytes (Handles failed downloads too)
      if (chunkAccumulator > 0 && activeRef != null) {
        activeRef.read(dataUsageProvider.notifier).addBytes(chunkAccumulator);
        chunkAccumulator = 0;
      }

      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }

      if (!success) {
        // 🧹 CLEANUP PARTIAL/CORRUPTED FILE
        try {
          if (await file.exists()) {
            await file.delete();
            debugPrint('🧹 Cleaned up partial/invalid file: $outputPath');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to cleanup file: $e');
        }
      }
    }
  }

  /// 🚀 STATIC HELPER: Check if a file is a valid FLAC by reading headers and optionally probing bitstream
  static Future<bool> isFlacFileValid(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      final size = await file.length();
      
      // 1. Basic size check (Reject < 1MB as it's almost certainly a preview/fragment)
      if (size < 1024 * 1024) return false;

      // 2. Header check (Check fLaC signature + STREAMINFO block)
      final raf = await file.open(mode: FileMode.read);
      final header = await raf.read(8);
      await raf.close();

      if (header.length < 8) return false;

      // Check 'fLaC' signature
      final hasFlacHeader = header[0] == 0x66 &&
          header[1] == 0x4C &&
          header[2] == 0x61 &&
          header[3] == 0x43;

      if (!hasFlacHeader) return false;

      // Check for STREAMINFO block (Type 0)
      // The 5th byte (index 4) contains the last-block flag and block type
      final blockType = header[4] & 0x7F;
      if (blockType != 0) {
        debugPrint('⚠️ Integrity Check: First block is not STREAMINFO (Type $blockType)');
        return false;
      }

      // 3. Probing (Desktop only, catch bitstream corruption)
      if (!Platform.isAndroid && !Platform.isIOS) {
        final ffprobe = await FlacDownloaderService()._getFFprobePath();
        if (ffprobe != null) {
          final result = await Process.run(
            ffprobe,
            ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', filePath],
            runInShell: false,
          );
          
          if (result.exitCode != 0 || result.stdout.toString().trim().isEmpty) {
            debugPrint('❌ Integrity Check: ffprobe failed to read bitstream duration');
            return false;
          }
          debugPrint('✅ Integrity Check: ffprobe verified duration: ${result.stdout.toString().trim()}s');
        }
      }

      return true;
    } catch (e) {
      debugPrint('⚠️ Integrity Check Error: $e');
      return false;
    }
  }

  /// Get FFprobe path from bin directory
  Future<String?> _getFFprobePath() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final binDir = Directory('${appDir.path}/bin');

      final ffprobeName = Platform.isWindows ? 'ffprobe.exe' : 'ffprobe';
      final ffprobeFile = File('${binDir.path}/$ffprobeName');

      if (await ffprobeFile.exists()) {
        return ffprobeFile.path;
      }

      // Try system ffprobe
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['ffprobe'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        return result.stdout.toString().trim().split('\n').first;
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ Could not find FFprobe: $e');
      return null;
    }
  }

  /// Get the download directory for FLAC files
  Future<String> getFlacDownloadPath(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('custom_download_path');

    final safeName = FilenameHelper.sanitize(filename);

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
    final safeName = FilenameHelper.sanitize(filename);

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

  /// Returns true if FLAC download is available (Deezer, Tidal, or Qobuz)
  bool get hasAnyUrl =>
      deezerUrl != null || tidalUrl != null || qobuzUrl != null;
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
