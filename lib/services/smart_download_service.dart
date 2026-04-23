import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:metadata_god/metadata_god.dart' show Metadata, Picture;
import '../services/metadata_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song_metadata.dart';
import '../models/youtube_search_result.dart';
import '../models/debug_match_result.dart';
import '../models/song_model.dart';
import '../services/youtube_downloader_service.dart';
import '../services/spotify_service.dart';
import '../services/flac_downloader_service.dart';
import '../ui/components/smart_art.dart';
import '../models/download_progress.dart';
import 'debug_log_service.dart'; // Import DebugLogService
import '../services/deezer_service.dart'; // Import DeezerService
import '../utils/filename_helper.dart';

class SmartDownloadService {
  final YoutubeDownloaderService _ytDlpService = YoutubeDownloaderService();
  final FlacDownloaderService _flacService = FlacDownloaderService();
  static const int maxDurationDifferenceSeconds = 5;

  // 🚀 SINGLE SONG DOWNLOAD PROGRESS NOTIFIER (for sidebar display)
  static final ValueNotifier<DownloadProgress?> progressNotifier =
      ValueNotifier<DownloadProgress?>(null);

  // --- Helper: Parse Duration ---
  int? parseDurationToSeconds(String durationString) {
    try {
      final parts = durationString.split(':').map(int.parse).toList();
      if (parts.length == 3) {
        return parts[0] * 3600 + parts[1] * 60 + parts[2];
      } else if (parts.length == 2) {
        return parts[0] * 60 + parts[1];
      } else if (parts.length == 1) {
        return parts[0];
      }
    } catch (e) {
      if (kDebugMode) print('Duration parse error: $e');
    }
    return null;
  }

  // --- Search Logic ---
  Future<DebugMatchResult?> searchYouTubeForMatch(SongMetadata metadata) async {
    final yt = YoutubeExplode();
    List<YoutubeSearchResult> youtubeMatches = [];

    try {
      dynamic searchList;

      // 1. PRIORITY: SEARCH BY ISRC
      if (metadata.isrc != null && metadata.isrc!.isNotEmpty) {
        try {
          print("🔍 Priority Search: ISRC ${metadata.isrc}");
          // Quote the ISRC for exact match
          searchList = await yt.search("\"${metadata.isrc}\"");
        } catch (e) {
          print("⚠️ ISRC Search Failed: $e");
        }
      }

      // 2. FALLBACK: STANDARD SEARCH
      if (searchList == null || (searchList as Iterable).isEmpty) {
        String query = "${metadata.artist} - ${metadata.title} Official Audio";
        print("🔍 Standard Search: $query");
        searchList = await yt.search(query);
      }

      // Map to our model
      var candidates = searchList.map((video) {
        final duration = video.duration ?? Duration.zero;
        final durationString =
            '${duration.inMinutes}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';

        return YoutubeSearchResult(
          title: video.title,
          artist: video.author,
          duration: durationString,
          url: video.url,
          thumbnailUrl: video.thumbnails.lowResUrl,
        );
      }).toList();

      // 🚀 FILTER & SORT BY DURATION
      // Prioritize videos that match the expected duration closely (avoiding intros/outros)
      if (metadata.durationSeconds > 0) {
        // 1. Sort by difference first
        candidates.sort((a, b) {
          final secA = parseDurationToSeconds(a.duration) ?? 0;
          final secB = parseDurationToSeconds(b.duration) ?? 0;
          final diffA = (secA - metadata.durationSeconds).abs();
          final diffB = (secB - metadata.durationSeconds).abs();
          return diffA.compareTo(diffB);
        });

        // 2. Filter: Only keep those within a reasonable range (e.g. 10s)
        // We keep the sorted list but filter out very bad matches if we have good ones.
        final bestMatches = candidates.where((video) {
          final vidSeconds = parseDurationToSeconds(video.duration) ?? 0;
          final diff = (vidSeconds - metadata.durationSeconds).abs();
          return diff <= maxDurationDifferenceSeconds + 5; // 10s tolerance
        }).toList();

        if (bestMatches.isNotEmpty) {
          youtubeMatches = bestMatches.take(5).toList();
        } else {
          // Fallback to top sorted results even if slightly off
          youtubeMatches = candidates.take(5).toList();
        }
      } else {
        youtubeMatches = candidates.take(5).toList();
      }
    } catch (e) {
      if (kDebugMode) print('YouTube Internal Search Error: $e');
      return null;
    } finally {
      yt.close();
    }

    if (youtubeMatches.isEmpty) return null;

    return DebugMatchResult(
      spotifyMetadata: metadata,
      youtubeMatches: youtubeMatches,
    );
  }

  // STREAM (CACHE & PLAY) FUNCTION
  // quality: 'standard' (MP3), 'high' (M4A), 'lossless' (FLAC with M4A fallback)
  Future<SongModel?> cacheAndPlay({
    required YoutubeSearchResult video,
    required SongMetadata metadata,
    required Function(double) onProgress,
    String streamingQuality = 'high',
  }) async {
    final fileName = FilenameHelper.sanitize("${metadata.artist} - ${metadata.title}");

    // 🎵 LOSSLESS PATH: Try FLAC from Deezer/Tidal first
    if (streamingQuality == 'lossless') {
      print("🎧 Lossless streaming: Trying FLAC from Deezer/Tidal...");

      // If spotifyId is missing, try to find it via Spotify search
      SongMetadata flacMeta = metadata;
      if (metadata.spotifyId == null || metadata.spotifyId!.isEmpty) {
        print("🔍 Searching Spotify for track ID...");
        try {
          final spotifyResults = await SpotifyService.searchMetadata(
              '${metadata.artist} ${metadata.title}');
          if (spotifyResults.isNotEmpty) {
            final firstResult = spotifyResults.first;
            final foundSpotifyId = firstResult['spotify_id'] as String?;
            final foundIsrc = firstResult['isrc'] as String?;

            flacMeta = metadata.copyWith(
              spotifyId: foundSpotifyId,
              isrc: foundIsrc ?? metadata.isrc,
            );
            if (foundSpotifyId != null) {
              print("✓ Found Spotify ID: $foundSpotifyId");
            }
          }
        } catch (e) {
          print("⚠️ Spotify search failed: $e");
        }
      }

      // Try FLAC download if we have Spotify ID, Deezer ID, or ISRC
      // 🚀 FIX: Use canDownloadFlac checks to include Deezer ID support
      if (canDownloadFlac(flacMeta) ||
          (flacMeta.isrc != null && flacMeta.isrc!.isNotEmpty)) {
        final flacResult = await downloadFlac(
          metadata: flacMeta,
          onProgress: onProgress,
          isStreaming: true,
        );

        if (flacResult != null) {
          print("✓ Lossless stream ready: ${flacResult.filePath}");
          return flacResult;
        }
      }

      // FLAC failed, fall back to M4A
      print("⚠️ FLAC unavailable, falling back to M4A...");
    }

    // 📺 YOUTUBE PATH: Standard/High quality or lossless fallback
    final cachePath = await _ytDlpService.getCachePath(fileName);
    if (cachePath == null) {
      print("Stream Error: Could not resolve cache path.");
      return null;
    }

    final file = File(cachePath);

    // Optimization: If file exists in cache, play immediately!
    if (await file.exists()) {
      final size = await file.length();
      bool isValid = size > 1024; // Ensure file isn't 0-byte or tiny corrupt junk
      
      if (isValid && p.extension(file.path).toLowerCase() == '.flac') {
        isValid = await FlacDownloaderService.isFlacFileValid(file.path);
      }

      if (isValid) {
        print("Stream: File found in cache & valid, playing directly.");
        return _createSongModel(file, metadata, video.url);
      } else {
        print("Stream: Cached file is invalid/corrupted. Deleting and retrying...");
        await file.delete();
      }
    }

    // Download to Cache
    final completer = Completer<bool>();

    try {
      await _ytDlpService.startDownloadFromUrl(
        youtubeUrl: video.url,
        outputFilePath: cachePath,
        onProgress: onProgress,
        onComplete: (success) {
          if (!completer.isCompleted) {
            completer.complete(success);
          }
        },
      );
    } catch (e) {
      print("Stream Error: Unexpected error starting download: $e");
      if (!completer.isCompleted) completer.complete(false);
    }

    final success = await completer.future;
    if (!success) {
      print("Stream Error: Download failed.");
      return null;
    }

    // Wait for file handle release
    await Future.delayed(const Duration(milliseconds: 500));

    // Tag the File (DISABLED for streaming to prevent corruption risk on mobile)
    // try {
    //   await tagFile(filePath: cachePath, metadata: metadata);
    // } catch (e) {
    //   print("Stream Warning: Tagging failed, but playing anyway. $e");
    // }

    // Return Model
    return _createSongModel(file, metadata, video.url);
  }

  SongModel _createSongModel(File file, SongMetadata meta, String? sourceUrl) {
    return SongModel(
      title: meta.title,
      artist: meta.artist,
      album: meta.album,
      filePath: file.path,
      duration: meta.durationSeconds.toDouble(),
      fileExtension: p.extension(file.path),
      // SAVE DATA FOR HISTORY
      sourceUrl: sourceUrl,
      onlineArtUrl: meta.albumArtUrl,
      spotifyId: meta.spotifyId,
      spotifyArtistId: meta.spotifyArtistId,
      deezerId: meta.deezerId,
    );
  }

  // AUTO-TAGGER FUNCTION
  Future<void> tagFile({
    required String filePath,
    required SongMetadata metadata,
  }) async {
    final logger = DebugLogService();
    try {
      if (!await File(filePath).exists()) {
        logger.warning("Tagging Skipped: File does not exist at $filePath");
        return;
      }
      logger.info("Starting tag process for $filePath");

      Uint8List? imageBytes;
      String mimeType = 'image/jpeg'; // Default

      if (metadata.albumArtUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(metadata.albumArtUrl));
          if (response.statusCode == 200) {
            imageBytes = response.bodyBytes;
            // Try to get mime from headers
            if (response.headers.containsKey('content-type')) {
              mimeType = response.headers['content-type']!;
            }
          }
        } catch (e) {
          print("⚠️ TAGGING: Failed to download album art: $e");
        }
      }

      await MetadataService().writeMetadata(
        filePath: filePath,
        metadata: Metadata(
          title: metadata.title,
          artist: metadata.artist,
          album: metadata.album,
          year: (metadata.year != null && metadata.year!.isNotEmpty)
              ? int.tryParse(metadata.year!.split('-').first)
              : null, // YEAR PARSING
          genre: metadata.genre,
          trackNumber: metadata.trackNumber,
          discNumber: metadata.discNumber,
          picture: imageBytes != null
              ? Picture(
                  data: imageBytes,
                  mimeType: mimeType,
                )
              : null,
        ),
      );

      // INVALIDATE UI CACHE
      SmartArt.invalidateCache(filePath);

      // 🚀 POST-TAGGING VERIFICATION: Ensure MetadataGod didn't corrupt the file
      if (filePath.toLowerCase().endsWith('.flac')) {
        final isValid = await FlacDownloaderService.isFlacFileValid(filePath);
        if (!isValid) {
          logger.error("❌ TAGGING CORRUPTION DETECTED: $filePath is no longer a valid FLAC after tagging!");
          // Try to delete corrupted file so it doesn't break playback
          try { await File(filePath).delete(); } catch (_) {}
          throw Exception("Tagging corrupted the FLAC bitstream");
        }
      }

      print("✅ TAGGING: Success!");
    } catch (e) {
      print("❌ TAGGING ERROR: $e");
      // Don't rethrow, just log it. This prevents the app from crashing.
      // rethrow;
    }
  }

  // FILENAME GENERATOR (Moved OUT of tagFile)
  Future<String> generateFilename(SongMetadata meta,
      {String patternKey = 'filename_pattern', int? playlistIndex}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Get Pattern (Default: "{artist} - {title}")
    String pattern = prefs.getString(patternKey) ?? "{artist} - {title}";

    // 2. Handle {number} (Global Increment)
    if (pattern.contains('{number}')) {
      int counter = prefs.getInt('download_counter') ?? 1;
      // Pad with zeros (e.g. 001, 002)
      String numberStr = counter.toString().padLeft(3, '0');
      pattern = pattern.replaceAll('{number}', numberStr);

      // Increment and save for next time
      await prefs.setInt('download_counter', counter + 1);
    }

    // 3. Replace Metadata Placeholders
    String filename = pattern
        .replaceAll('{artist}', meta.artist)
        .replaceAll('{title}', meta.title)
        .replaceAll(
            '{album}', meta.album.isNotEmpty ? meta.album : 'Unknown Album')
        .replaceAll('{year}',
            (meta.year != null && meta.year!.isNotEmpty) ? meta.year! : '0000')
        .replaceAll('{track}', meta.trackNumber?.toString() ?? '0')
        .replaceAll('{disc}', meta.discNumber?.toString() ?? '1')
        .replaceAll(
            '{playlist_index}',
            (playlistIndex ?? 0)
                .toString()
                .padLeft(2, '0')) // 🚀 PLAYLIST INDEX
        .replaceAll(
            '{date}', DateTime.now().toString().split(' ')[0]); // YYYY-MM-DD

    // 4. Sanitize Filename (Remove illegal characters)
    filename = FilenameHelper.sanitize(filename);

    return filename;
  }

  // PREDICT CACHE PATH (For Queue Building)
  Future<String> getPredictedCachePath(SongMetadata metadata) async {
    final fileName = FilenameHelper.sanitize("${metadata.artist} - ${metadata.title}");

    // Check streaming quality - if lossless, check FLAC cache first
    final prefs = await SharedPreferences.getInstance();
    final streamingQuality = prefs.getString('streamingQuality') ?? 'high';

    if (streamingQuality == 'lossless') {
      // Check FLAC cache in temp folder first
      final flacPath = await _flacService.getFlacCachePath(fileName);
      if (await File(flacPath).exists()) {
        return flacPath;
      }
    }

    // Fallback to YouTube cache path with correct format
    // standard = mp3, high = m4a, lossless fallback = m4a
    final audioFormat = streamingQuality == 'standard' ? 'mp3' : 'm4a';
    final path = await _ytDlpService.getCachePath(fileName, ext: audioFormat);
    return path ?? "";
  }

  // BACKGROUND CACHE (PRELOAD) FUNCTION
  // Now respects streaming quality for FLAC support
  Future<void> cacheSong(SongMetadata metadata, {String? youtubeUrl, String? streamUrl}) async {
    DebugLogService()
        .info("📥 SmartDownload: cacheSong called for ${metadata.title}");
    final fileName = FilenameHelper.sanitize("${metadata.artist} - ${metadata.title}");

    // Read streaming quality from settings
    final prefs = await SharedPreferences.getInstance();
    final streamingQuality = prefs.getString('streamingQuality') ?? 'high';

    // 🎵 LOSSLESS PATH: Try FLAC first if quality is 'lossless'
    if (streamingQuality == 'lossless') {
      print("🎧 Preload: Lossless mode - trying FLAC for ${metadata.title}");

      // If spotifyId is missing, try to find it via Spotify search
      SongMetadata flacMeta = metadata;
      if (metadata.spotifyId == null || metadata.spotifyId!.isEmpty) {
        print("🔍 Preload: Searching Spotify for track ID...");
        try {
          final spotifyResults = await SpotifyService.searchMetadata(
              '${metadata.artist} ${metadata.title}');
          if (spotifyResults.isNotEmpty) {
            final firstResult = spotifyResults.first;
            final foundSpotifyId = firstResult['spotify_id'] as String?;
            final foundIsrc = firstResult['isrc'] as String?;

            // Update metadata with Spotify info for FLAC lookup
            flacMeta = metadata.copyWith(
              spotifyId: foundSpotifyId,
              isrc: foundIsrc ?? metadata.isrc,
            );
            if (foundSpotifyId != null) {
              print("✓ Found Spotify ID: $foundSpotifyId");
            }
          }
        } catch (e) {
          print("⚠️ Spotify search failed: $e. Trying Deezer fallback...");
          try {
            final deezerResults = await DeezerService.searchSongs(
                '${metadata.artist} ${metadata.title}',
                limit: 1);
            if (deezerResults.isNotEmpty) {
              final first = deezerResults.first;
              flacMeta = metadata.copyWith(
                deezerId: first.deezerId,
                isrc: first.isrc ?? metadata.isrc,
              );
              print("✓ Found Deezer ID: ${first.deezerId}");
            }
          } catch (de) {
            print("⚠️ Deezer search fallback also failed: $de");
          }
        }
      }

      // Try FLAC download if we have IDs OR if we want to force a fallback search
      // 🚀 FIX: Attempt download even if IDs are missing, so downloadFlac can trigger its fallback search
      if (canDownloadFlac(flacMeta) ||
          (flacMeta.isrc != null && flacMeta.isrc!.isNotEmpty) ||
          (flacMeta.spotifyId == null && flacMeta.deezerId == null)) {
        // Note: The third condition (null IDs) is risky unless downloadFlac handles it.
        // We verified downloadFlac has a "Smart Fallback" for Spotify failures,
        // but we need to ensure it handles "No Start ID" too.
        // Actually, let's just fall through to the downloadFlac call and ensure IT handles the missing ID.

        final flacSong = await downloadFlac(
          metadata: flacMeta,
          onProgress: (_) {},
          isStreaming: true,
        );

        if (flacSong != null) {
          print("✓ Preload: FLAC cached successfully for ${metadata.title}");
          return; // Success! No need for YouTube fallback
        } else {
          print("⚠️ Preload: FLAC download failed for ${metadata.title}");
        }
      }

      print("⚠️ Preload: FLAC unavailable, falling back to YouTube...");
    }

    // 📺 YOUTUBE PATH: Standard/High quality or lossless fallback
    // Determine audio format based on streaming quality setting
    // standard = mp3, high = m4a, lossless fallback = m4a
    final audioFormat = streamingQuality == 'standard' ? 'mp3' : 'm4a';

    final cachePath =
        await _ytDlpService.getCachePath(fileName, ext: audioFormat);
    if (cachePath == null) return;

    final file = File(cachePath);
    if (await file.exists()) {
      final size = await file.length();
      bool isValid = size > 1024;
      
      if (isValid && p.extension(file.path).toLowerCase() == '.flac') {
        isValid = await FlacDownloaderService.isFlacFileValid(file.path);
      }

      if (isValid) {
        print("Preload: File already exists and valid for ${metadata.title}");
        return;
      } else {
        print("Preload: Existing file corrupted, deleting: ${file.path}");
        await file.delete();
      }
    }

    // 📺 STREAM URL PATH: Download directly from VPS stream for HIGH/STANDARD consistency
    if (streamingQuality != 'lossless' && streamUrl != null) {
      print("🎧 Preload: Downloading directly from Stream URL instead of YouTube...");
      final success = await _downloadFromStreamUrl(streamUrl, cachePath);
      if (success) {
        print("✓ Preload: Stream downloaded successfully for ${metadata.title}");
        return; 
      } else {
        print("⚠️ Preload: Stream download failed, falling back to YouTube...");
      }
    }

    print("Preload: Starting background cache for ${metadata.title}");

    String? targetUrl = youtubeUrl;

    // 1. Search (ONLY IF URL IS MISSING, EMPTY, OR IS A QUERY PLACEHOLDER)
    // Cloud songs use "query: Artist - Title" format which is NOT a real URL
    if (targetUrl == null ||
        targetUrl.isEmpty ||
        targetUrl.startsWith('query:')) {
      if (targetUrl != null && targetUrl.startsWith('query:')) {
        print("Preload: Detected query placeholder, searching YouTube...");
      }
      final debugResult = await searchYouTubeForMatch(metadata);
      if (debugResult == null || debugResult.youtubeMatches.isEmpty) {
        print("Preload Error: No match found for ${metadata.title}");
        return;
      }

      // 2. Find Best Match
      var bestMatch = debugResult.youtubeMatches.firstWhere(
        (match) {
          final ytSeconds = parseDurationToSeconds(match.duration) ?? 0;
          return (metadata.durationSeconds - ytSeconds).abs() <= 1;
        },
        orElse: () => debugResult.youtubeMatches.first,
      );
      targetUrl = bestMatch.url;
    } else {
      print("Preload: Using provided YouTube URL: $targetUrl");
    }

    // 3. Download
    final completer = Completer<bool>();
    await _ytDlpService.startDownloadFromUrl(
      youtubeUrl: targetUrl,
      outputFilePath: cachePath,
      onProgress: (_) {}, // No UI progress for background preload
      onComplete: (success) => completer.complete(success),
      audioFormat: audioFormat,
      isQuiet: true, // 🚀 Crucial: Prevents Win32 IPC buffer overflow crashing TaskRunner
    );

    final success = await completer.future;

    if (success) {
      // 4. Tag
      try {
        await tagFile(filePath: cachePath, metadata: metadata);
        print("Preload: Successfully cached ${metadata.title}");
      } catch (e) {
        print("Preload Warning: Tagging failed: $e");
      }
    } else {
      // 🚀 FALLBACK: If initial download failed (e.g. 403 Forbidden, Geo-block), try searching fresh
      if (targetUrl == youtubeUrl &&
          youtubeUrl != null &&
          !youtubeUrl.startsWith('query:')) {
        print(
            "⚠️ Preload: Initial download failed for provided URL. Attempts Fallback Search...");

        final debugResult = await searchYouTubeForMatch(metadata);
        if (debugResult != null && debugResult.youtubeMatches.isNotEmpty) {
          // Find best match again
          var bestMatch = debugResult.youtubeMatches.firstWhere(
            (match) {
              final ytSeconds = parseDurationToSeconds(match.duration) ?? 0;
              return (metadata.durationSeconds - ytSeconds).abs() <= 1;
            },
            orElse: () => debugResult.youtubeMatches.first,
          );

          print(
              "🔄 Fallback: Found fresh match: ${bestMatch.title} (${bestMatch.url})");
          print("🚀 Retrying download with new URL...");

          final retryCompleter = Completer<bool>();
          await _ytDlpService.startDownloadFromUrl(
            youtubeUrl: bestMatch.url,
            outputFilePath: cachePath,
            onProgress: (_) {},
            onComplete: (s) => retryCompleter.complete(s),
            audioFormat: audioFormat,
          );

          final retrySuccess = await retryCompleter.future;
          if (retrySuccess) {
            await tagFile(filePath: cachePath, metadata: metadata);
            print("✅ Fallback Success: Cached ${metadata.title} after retry.");
            return;
          }
        }
      }

      print("Preload Error: Download failed for ${metadata.title}");
    }
  }

  // ============================================================
  // FLAC DOWNLOAD (Lossless from Deezer/Tidal)
  // ============================================================

  /// Download FLAC for a track using its Spotify ID
  /// Returns the downloaded file as a SongModel, or null on failure
  /// isStreaming: if true, saves to temp cache folder; if false, saves to downloads folder
  Future<SongModel?> downloadFlac({
    required SongMetadata metadata,
    required Function(double) onProgress,
    bool isStreaming = false,
  }) async {
    // FLAC download requires either Spotify ID OR Deezer ID
    final initialHasSpotifyId =
        metadata.spotifyId != null && metadata.spotifyId!.isNotEmpty;
    final hasDeezerId =
        metadata.deezerId != null && metadata.deezerId!.isNotEmpty;

    SongMetadata flacMeta = metadata;

    // 🚀 RESOLVE SPOTIFY ID FOR DEEZER TRACKS (cascade backup)
    if (!initialHasSpotifyId) {
      debugPrint("🔍 downloadFlac: Searching Spotify for track ID for fallback...");
      try {
        final spotifyResults = await SpotifyService.searchMetadata(
            '${metadata.artist} ${metadata.title}');
        if (spotifyResults.isNotEmpty) {
          final firstResult = spotifyResults.first;
          final foundSpotifyId = firstResult['spotify_id'] as String?;
          final foundIsrc = firstResult['isrc'] as String?;

          flacMeta = metadata.copyWith(
            spotifyId: foundSpotifyId,
            isrc: foundIsrc ?? metadata.isrc,
          );
          if (foundSpotifyId != null) {
            debugPrint("✓ Found Spotify ID: $foundSpotifyId");
          }
        }
      } catch (e) {
        debugPrint("⚠️ Spotify search failed: $e");
      }
    }

    // 🚀 RESOLVE ISRC FROM DEEZER IF MISSING
    if (hasDeezerId && (flacMeta.isrc == null || flacMeta.isrc!.isEmpty)) {
      debugPrint("🔍 downloadFlac: Fetching detailed Deezer metadata for ISRC...");
      try {
        final detailedTrack = await DeezerService.getTrack(metadata.deezerId!);
        if (detailedTrack != null && detailedTrack.isrc != null) {
          flacMeta = flacMeta.copyWith(isrc: detailedTrack.isrc);
          debugPrint("✓ Found Deezer ISRC: ${detailedTrack.isrc}");
        }
      } catch (e) {
        debugPrint("⚠️ Deezer details fetch failed: $e");
      }
    }

    final hasSpotifyId = flacMeta.spotifyId != null && flacMeta.spotifyId!.isNotEmpty;

    if (!hasSpotifyId && !hasDeezerId) {
      debugPrint(
          '⚠️ FLAC Download: No IDs provided. Attempting Smart Fallback (Deezer Search)...');
      // Allow execution to proceed to the fallback block below
    }

    debugPrint(
        '🎵 Starting FLAC ${isStreaming ? "stream" : "download"} for: ${metadata.title}');

    final logger = DebugLogService();
    logger.info("SMA: Starting FLAC download/stream for ${metadata.title}");

    // Get output path - cache for streaming, downloads for permanent
    final filename = await generateFilename(metadata);
    final outputPath = isStreaming
        ? await _flacService.getFlacCachePath(filename)
        : await _flacService.getFlacDownloadPath(filename);

    // Check if already exists
    final file = File(outputPath);
    if (await file.exists()) {
      debugPrint('✓ FLAC already exists: $outputPath');
      return _createSongModel(file, metadata, null);
    }

    // Download via FLAC service
    // 🚀 PRIORITY ORDER: Tidal Direct Search → Deezer Direct → song.link fallback
    // Tidal Direct Search is fastest (no song.link dependency, parallel server probing)
    FlacDownloadResult result = FlacDownloadResult.failed("Pending Evaluation");

    // 🚀 STAGE 1: Direct Tidal Search (fastest path - no song.link required)
    debugPrint("🚀 Stage 1: Searching Tidal directly for lossless match...");
    try {
      final tidalId = await _flacService.getTidalTrackIdBySearch(metadata.title, metadata.artist);
      if (tidalId != null) {
         debugPrint("✅ Found Direct Tidal Match: $tidalId");
         var file = await _flacService.downloadFromTidalWithQuality(
            tidalUrl: "https://tidal.com/track/$tidalId",
            outputPath: outputPath,
            quality: 'HI_RES_LOSSLESS',
            onProgress: onProgress,
            timeoutSeconds: 60,
         );
         
         if (file == null) {
            debugPrint("⚠️ Tidal Hi-Res failed. Trying Standard LOSSLESS CD quality...");
            file = await _flacService.downloadFromTidalWithQuality(
               tidalUrl: "https://tidal.com/track/$tidalId",
               outputPath: outputPath,
               quality: 'LOSSLESS',
               onProgress: onProgress,
               timeoutSeconds: 60,
            );
         }

         if (file != null) {
            result = FlacDownloadResult.success(file, "tidal_direct_search");
         }
      }
    } catch (e) {
      debugPrint("❌ Tidal Direct Search error: $e");
    }

    // 🚀 STAGE 2: Try Direct IDs (Deezer direct / Spotify-based song.link)
    // Only attempt song.link path with a timeout when streaming to avoid stalling
    if (!result.success && (hasSpotifyId || hasDeezerId)) {
      debugPrint("🚀 Stage 2: Attempting platform download via existing IDs...");
      try {
        final directResultFuture = _flacService.downloadFlac(
          spotifyTrackId: flacMeta.spotifyId ?? '',
          outputPath: outputPath,
          isrc: flacMeta.isrc,
          trackName: flacMeta.title,
          artistName: flacMeta.artist,
          albumName: flacMeta.album,
          onProgress: onProgress,
          timeoutSeconds: isStreaming ? 10 : 30,
        );

        // When streaming, cap song.link-dependent path to 15s to avoid hanging
        final directResult = isStreaming
            ? await directResultFuture.timeout(const Duration(seconds: 15),
                onTimeout: () => FlacDownloadResult.failed("song.link timeout"))
            : await directResultFuture;
      
        if (directResult.success && directResult.file != null) {
          result = directResult;
        } else {
          debugPrint("⚠️ Stage 2 failed, trying more fallbacks...");
        }
      } on TimeoutException {
        debugPrint("⏱️ Stage 2: song.link path timed out (streaming mode)");
      } catch (e) {
        debugPrint("⚠️ Stage 2: Direct ID download failed: $e");
      }
    }

      // 🔄 FALLBACK: If Spotify-based download failed, try finding formatting Deezer ID manually
      if (!result.success && !hasDeezerId) {
        debugPrint(
            "⚠️ FLAC (Spotify Path) Failed. Attempting fallback via Deezer Search...");
        DebugLogService().warning(
            "⚠️ FLAC (Spotify Path) Failed. Triggering Deezer Search Fallback...");
        try {
          // Search Deezer for this exact track
          // 🚀 CLEAN QUERY: Remove "Official Video", "(Lyrics)", etc. to improve match rate
          String cleanTitle = metadata.title
              .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '') // Remove brackets/parentheses
              .replaceAll(RegExp(r'(?i)official\s+(music\s+)?video|lyrics?|audio|hd|4k|mv'), '') // Remove tags
              .split(' - ').last // Often "Artist - Title", take Title
              .trim();
          
          String cleanArtist = metadata.artist
              .replaceAll(RegExp(r'(?i)vevo|topic|records'), '') // Remove channel fluff
              .trim();

          final searchQuery = "$cleanTitle $cleanArtist";
          DebugLogService().info(
              "🔍 Deezer Fallback: Searching '$searchQuery' (Original: ${metadata.title})");
          
          final deezerSongs = await DeezerService.searchSongs(searchQuery, limit: 5);

          if (deezerSongs.isNotEmpty) {
            // Find best match (simple check for now)
            final bestMatch = deezerSongs.first; // Grab top result
            // Verify somewhat close match (optional, but safe)
            if (bestMatch.title.toLowerCase() == metadata.title.toLowerCase() ||
                bestMatch.deezerId != null) {
              debugPrint(
                  "✅ Found Fallback Deezer Match: ID=${bestMatch.deezerId}");
              DebugLogService().success(
                  "✅ Deezer Fallback Match Found: ${bestMatch.title} (ID: ${bestMatch.deezerId})");

              // RECURSIVE CALL (mostly safe as hasDeezerId is now effectively true for next logic)
              // But to avoid recursion depth issues, let's just trigger direct download logic here
              // actually, constructing a new metadata with deezerId is cleaner:
              final newMeta = metadata.copyWith(deezerId: bestMatch.deezerId);
              return downloadFlac(
                  metadata: newMeta,
                  onProgress: onProgress,
                  isStreaming: isStreaming);
            }
          } else {
            DebugLogService().warning(
                "⚠️ Deezer Fallback: No matches found for '${metadata.title}'");
          }
        } catch (e) {
          debugPrint("❌ Deezer Fallback Search Error: $e");
          DebugLogService().error("❌ Deezer Fallback Error: $e");
        }
      }


    logger.info(
        "SMA: Download result success=${result.success} error=${result.error}");

    if (result.success && result.file != null) {
      debugPrint('✓ FLAC Download Success via ${result.service}');

      // Tag the file
      try {
        await tagFile(filePath: result.file!.path, metadata: flacMeta);
      } catch (e) {
        debugPrint('⚠️ FLAC Tagging failed: $e');
      }

      return _createSongModel(result.file!, flacMeta, null);
    }

    debugPrint('❌ FLAC Download failed: ${result.error}');
    return null;
  }

  Future<bool> _downloadFromStreamUrl(String url, String cachePath) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final file = File(cachePath);
        final sink = file.openWrite();
        await response.stream.pipe(sink);
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Stream download error: $e');
    }
    return false;
  }

  /// Check if FLAC download is available for this track
  bool canDownloadFlac(SongMetadata metadata) {
    return (metadata.spotifyId != null && metadata.spotifyId!.isNotEmpty) ||
        (metadata.deezerId != null && metadata.deezerId!.isNotEmpty);
  }
}
