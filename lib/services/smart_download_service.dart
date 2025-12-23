import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:metadata_god/metadata_god.dart';
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
    final fileName = "${metadata.artist} - ${metadata.title}";

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

      // Try FLAC download if we have Spotify ID or ISRC
      if (flacMeta.spotifyId != null ||
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
      print("Stream: File found in cache, playing directly.");
      return _createSongModel(file, metadata, video.url);
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
    );
  }

  // AUTO-TAGGER FUNCTION
  Future<void> tagFile({
    required String filePath,
    required SongMetadata metadata,
  }) async {
    try {
      if (!await File(filePath).exists()) {
        print("⚠️ TAGGING: File does not exist at $filePath");
        return;
      }
      print("🏷️ TAGGING: Starting tag process for $filePath");

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

      await MetadataGod.writeMetadata(
        file: filePath,
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
    filename = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    return filename;
  }

  // PREDICT CACHE PATH (For Queue Building)
  Future<String> getPredictedCachePath(SongMetadata metadata) async {
    final fileName = "${metadata.artist} - ${metadata.title}";

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

    // Fallback to YouTube cache path
    final path = await _ytDlpService.getCachePath(fileName);
    return path ?? "";
  }

  // BACKGROUND CACHE (PRELOAD) FUNCTION
  // Now respects streaming quality for FLAC support
  Future<void> cacheSong(SongMetadata metadata, {String? youtubeUrl}) async {
    final fileName = "${metadata.artist} - ${metadata.title}";

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
          print("⚠️ Spotify search failed: $e");
        }
      }

      // Try FLAC download if we have either Spotify ID or ISRC
      if (flacMeta.spotifyId != null ||
          (flacMeta.isrc != null && flacMeta.isrc!.isNotEmpty)) {
        final flacResult = await downloadFlac(
          metadata: flacMeta,
          onProgress: (_) {},
          isStreaming: true,
        );

        if (flacResult != null) {
          print("✓ Preload: FLAC cached successfully for ${metadata.title}");
          return; // Success! No need for YouTube fallback
        }
      }

      print("⚠️ Preload: FLAC unavailable, falling back to YouTube...");
    }

    // 📺 YOUTUBE PATH: Standard/High quality or lossless fallback
    final cachePath = await _ytDlpService.getCachePath(fileName);
    if (cachePath == null) return;

    final file = File(cachePath);
    if (await file.exists()) {
      print("Preload: File already exists for ${metadata.title}");
      return;
    }

    print("Preload: Starting background cache for ${metadata.title}");

    String? targetUrl = youtubeUrl;

    // 1. Search (ONLY IF URL IS MISSING OR EMPTY)
    if (targetUrl == null || targetUrl.isEmpty) {
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
    // FLAC download requires Spotify ID
    if (metadata.spotifyId == null || metadata.spotifyId!.isEmpty) {
      debugPrint(
          '❌ FLAC Download: No Spotify ID available for ${metadata.title}');
      return null;
    }

    debugPrint(
        '🎵 Starting FLAC ${isStreaming ? "stream" : "download"} for: ${metadata.title}');

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
    final result = await _flacService.downloadFlac(
      spotifyTrackId: metadata.spotifyId!,
      outputPath: outputPath,
      isrc: metadata.isrc,
      trackName: metadata.title,
      artistName: metadata.artist,
      albumName: metadata.album,
      onProgress: onProgress,
    );

    if (result.success && result.file != null) {
      debugPrint('✓ FLAC Download Success via ${result.service}');

      // Tag the file
      try {
        await tagFile(filePath: result.file!.path, metadata: metadata);
      } catch (e) {
        debugPrint('⚠️ FLAC Tagging failed: $e');
      }

      return _createSongModel(result.file!, metadata, null);
    }

    debugPrint('❌ FLAC Download failed: ${result.error}');
    return null;
  }

  /// Check if FLAC download is available for this track
  bool canDownloadFlac(SongMetadata metadata) {
    return metadata.spotifyId != null && metadata.spotifyId!.isNotEmpty;
  }
}
