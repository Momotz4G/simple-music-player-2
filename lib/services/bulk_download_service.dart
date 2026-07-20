import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart'; // IMPORT
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song_model.dart';
import '../models/song_metadata.dart';
import '../models/download_progress.dart';
import 'smart_download_service.dart';
import 'youtube_downloader_service.dart';
import 'metrics_service.dart';
import 'spotify_service.dart';
import 'deezer_service.dart';
import 'notification_service.dart'; // IMPORT
import 'apple_music_backend_service.dart';
import '../utils/filename_helper.dart';
import '../providers/settings_provider.dart';

class BulkDownloadService {
  static final BulkDownloadService _instance = BulkDownloadService._internal();

  factory BulkDownloadService() {
    return _instance;
  }

  BulkDownloadService._internal();

  final SmartDownloadService _smartService = SmartDownloadService();
  final YoutubeDownloaderService _ytService = YoutubeDownloaderService();

  // Notifier for UI
  final ValueNotifier<DownloadProgress?> progressNotifier = ValueNotifier(null);

  // Error notifier for ban/limit messages
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);

  // Real-time status for UI
  final ValueNotifier<String?> currentSongNotifier = ValueNotifier(null);
  final StreamController<String> _songCompleteController =
      StreamController.broadcast();
  Stream<String> get songCompleteStream => _songCompleteController.stream;

  bool _isDownloading = false;
  bool _isCancelled = false; // ADDED

  void cancelDownload() {
    if (_isDownloading) {
      _isCancelled = true;
      debugPrint("⚠️ Bulk download cancel requested.");

      // IMMEDIATE UI FEEDBACK
      if (progressNotifier.value != null) {
        final current = progressNotifier.value!;
        progressNotifier.value = DownloadProgress(
          receivedMB: current.receivedMB,
          totalMB: current.totalMB,
          progress: current.progress,
          status: "Cancelling...",
          details: current.details,
        );
      }
    }
  }

  Future<void> downloadAlbum(String albumTitle, List<SongModel> songs,
      {String? coverUrl}) async {
    if (_isDownloading) {
      debugPrint("⚠️ Bulk Download already in progress");
      return;
    }

    _isDownloading = true;
    int total = songs.length;
    int completed = 0;

    // INIT NOTIFICATIONS
    final notif = NotificationService();
    // Unique ID based on time
    final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      // 0. ENSURE YOUTUBE DOWNLOADER IS INITIALIZED
      await _ytService.initialize();

      // REQUEST PERMISSIONS (ANDROID)
      if (Platform.isAndroid) {
        // Request Storage (Android < 13)
        var status = await Permission.storage.request();
        // Request Audio (Android 13+)
        if (status.isDenied || status.isRestricted) {
          final audioStatus = await Permission.audio.request();
          if (audioStatus.isGranted) status = audioStatus;
        }

        // Final Check
        if (!status.isGranted &&
            !await Permission.manageExternalStorage.isGranted) {
          debugPrint("⛔ Permission Denied");
          errorNotifier.value = "Storage permission required to download!";
          _isDownloading = false;
          return;
        }
      }

      // 1. Get Base Directory: downloads/SimpleMusicDownloads/playlists/{Album Title}
      final baseDir = await getAlbumDownloadDirectory(albumTitle);
      if (baseDir == null) {
        debugPrint("❌ Could not get download directory");
        _isDownloading = false;
        return;
      }

      debugPrint("📂 Downloading to: ${baseDir.path}");

      // Notify Start
      await notif.showProgress(
          id: notifId,
          progress: 0,
          max: total,
          title: "Downloading $albumTitle",
          body: "Starting download...");

      for (var i = 0; i < songs.length; i++) {
        // 🛑 CHECK CANCELLATION
        if (_isCancelled) {
          debugPrint("⛔ Bulk download cancelled by user.");
          _updateProgress(completed, total, "Cancelled");
          errorNotifier.value = "Download cancelled by user.";
          notif.cancel(notifId);
          break;
        }

        var song = songs[i];
        currentSongNotifier.value = song.filePath; // Notify Start

        // 🛑 CHECK BAN STATUS FIRST
        final isBanned = await MetricsService().isUserBanned();
        if (isBanned) {
          debugPrint("⛔ User is banned. Stopping bulk download.");
          _updateProgress(completed, total, "⛔ Account Suspended");
          errorNotifier.value =
              "⛔ Your account has been suspended. Downloads are disabled.";
          notif.cancel(notifId); // Cancel
          break;
        }

        // 🛑 CHECK QUOTA
        final isAlac = song.sourceUrl != null && song.sourceUrl!.contains('apple.com');
        
        if (!isAlac) {
          final canDownload = await MetricsService().canDownload();
          if (!canDownload) {
            debugPrint("⛔ Daily download limit reached. Stopping bulk download.");
            _updateProgress(completed, total, "📊 Limit Reached");
            errorNotifier.value =
                "📊 Daily Download Limit Reached (50/day). Try again tomorrow!";
            notif.showComplete(
                id: notifId,
                title: "Download Paused",
                body:
                    "Daily limit reached ($completed/$total)."); // Show Paused
            break;
          }
        }

        // Update Progress: "Downloading... (x/total)"
        _updateProgress(completed, total, "Downloading...");

        // UPDATE NOTIF (Current Song)
        // Show "Song Title • 1 of 10"
        notif.showProgress(
            id: notifId,
            progress: completed,
            max: total,
            title: "Downloading $albumTitle",
            body: "${song.title} • ${i + 1} of $total");

        // 2. Prepare Metadata

        // Use provided coverUrl if song's art is missing, or prefer coverUrl for uniformity in album dl
        String artUrl = (coverUrl != null && coverUrl.isNotEmpty)
            ? coverUrl
            : (song.onlineArtUrl ?? "");

        // SMART METADATA ENRICHMENT
        // Always try to enrich YT Music tracks with Spotify data for high-res art and exact album
        String? year = song.year;
        String? genre = song.genre;
        int? trackNum = song.trackNumber;
        int? discNum = song.discNumber;
        String? isrc = song.isrc;

        final isYtSource = song.sourceUrl != null && song.sourceUrl!.contains('youtube');

        if (isYtSource || year == null || year.isEmpty || trackNum == null) {
          try {
            debugPrint(
                "🔍 Fetching rich Spotify metadata for ${song.title}...");
            // Ensure we search precisely, matching the playlist player behavior
            final query = "${song.title} ${song.artist}";
            List<SongMetadata> results = [];
          
          try {
            results = await SpotifyService.searchTracks(query);
          } catch (e) {
            debugPrint("Spotify enrichment failed during bulk download: $e, falling back to Deezer");
          }

          if (results.isEmpty) {
            try {
              results = await DeezerService.searchSongs(query);
            } catch (e) {
              debugPrint("Deezer enrichment failed during bulk download: $e");
            }
          }

          if (results.isNotEmpty) {
            final richMeta = results.first;
            debugPrint("✅ Found rich metadata: Album=${richMeta.album}");

            // Override basic YT metadata with Official Meta
            artUrl = richMeta.albumArtUrl.isNotEmpty ? richMeta.albumArtUrl : artUrl;
            year = (richMeta.year != null && richMeta.year!.isNotEmpty) ? richMeta.year : year;
            genre = richMeta.genre ?? genre;
            trackNum = richMeta.trackNumber ?? trackNum;
            discNum = richMeta.discNumber ?? discNum;
            isrc = richMeta.isrc ?? isrc;
            
            // Also update the song title and artist to standard formatting
            song = song.copyWith(
              title: richMeta.title,
              artist: richMeta.artist,
              album: richMeta.album,
              spotifyId: richMeta.spotifyId ?? song.spotifyId,
              deezerId: richMeta.deezerId ?? song.deezerId,
            );
            }
          } catch (e) {
            debugPrint("Metadata enrichment failed completely during bulk download: $e");
          }
        }

        final metadata = SongMetadata(
            title: song.title,
            artist: song.artist,
            album: song.album,
            albumArtUrl: artUrl,
            durationSeconds: song.duration.toInt(),
            isrc: isrc,
            year: year,
            genre: genre,
            trackNumber: trackNum ?? (i + 1), // Fallback to loop index
            discNumber: discNum ?? 1);

        // USE GENERATED FILENAME (Configurable)
        // Pass patternKey for playlist and the index (1-based)
        final filename = await _smartService.generateFilename(metadata,
            patternKey: 'playlist_filename_pattern', playlistIndex: i + 1);

        String preferredFormat = 'm4a';
        SearchEngine? currentEngine;
        if (AppleMusicBackendService.globalRef != null) {
          final settings = AppleMusicBackendService.globalRef!.read(settingsProvider);
          preferredFormat = settings.audioFormat;
          currentEngine = settings.searchEngine;
        }
        
        final isAppleMusic = (song.sourceUrl != null && song.sourceUrl!.contains('apple.com')) ||
            (currentEngine == SearchEngine.appleMusic && (song.sourceUrl == null || !song.sourceUrl!.contains('youtube.com')));

        if (preferredFormat == 'flac' && !isAppleMusic) {
          preferredFormat = 'm4a'; // Youtube doesn't support FLAC
        }

        final fileExtension = preferredFormat == 'alac' ? 'm4a' : preferredFormat;
        final filePath = "${baseDir.path}/$filename.$fileExtension";

        // SKIP IF EXISTS: Don't re-download, don't count quota
        final file = File(filePath);
        if (await file.exists()) {
          debugPrint("⏭️ Skipping (already exists): ${song.title}");
          completed++;
          _updateProgress(completed, total, "Skipping existing...");
          _songCompleteController.add(song.filePath); // Notify Cached
          continue; // Next song
        }

        bool success = false;

        // 3. Search / Match or Use Source URL
        if (isAppleMusic) {
           // APPLE MUSIC FLOW
           debugPrint("🎵 Apple Music source detected. Processing via VPS...");
           try {
             String targetUrl = song.sourceUrl ?? '';
             if (targetUrl.isEmpty || !targetUrl.contains('apple.com')) {
               final searchResults = await AppleMusicBackendService.search("${song.title} ${song.artist}", limit: 1);
               if (searchResults.isNotEmpty && searchResults.first['url'] != null) {
                 targetUrl = searchResults.first['url'];
               }
             }

             if (targetUrl.isNotEmpty && targetUrl.contains('apple.com')) {
               final remoteUrl = await AppleMusicBackendService.requestDownload(
                 targetUrl,
                 title: metadata.title,
                 artist: metadata.artist,
                 isCancelled: () => _isCancelled,
               );
               
               if (remoteUrl != null && !_isCancelled) {
                 success = await AppleMusicBackendService.downloadFile(
                   remoteUrl,
                   filePath,
                   isCancelled: () => _isCancelled,
                 );
               }
             }
           } catch (e) {
             if (e.toString().contains('QUOTA_EXCEEDED')) {
               debugPrint("⛔ ALAC Quota Exceeded. Stopping bulk download.");
               errorNotifier.value = "QUOTA_EXCEEDED";
               cancelDownload(); // Abort the remaining queue
               break;
             }
           }
        } else {
           // NORMAL YOUTUBE / FALLBACK FLOW
           String? videoUrl;
           if (song.sourceUrl != null &&
               song.sourceUrl!.isNotEmpty &&
               !song.sourceUrl!.contains("spotify.com")) {
             videoUrl = song.sourceUrl;
             debugPrint("Using direct source URL for ${song.title}");
           } else {
             final debugResult = await _smartService.searchYouTubeForMatch(metadata);
             if (debugResult != null && debugResult.youtubeMatches.isNotEmpty) {
               var match = debugResult.youtubeMatches.first;
               if (debugResult.youtubeMatches.length > 1) {
                 match = debugResult.youtubeMatches.firstWhere((m) {
                   final parts = m.duration.split(':');
                   int seconds = 0;
                   if (parts.length == 2) {
                     seconds = int.parse(parts[0]) * 60 + int.parse(parts[1]);
                   }
                   return (seconds - metadata.durationSeconds).abs() < 10;
                 }, orElse: () => debugResult.youtubeMatches.first);
               }
               videoUrl = match.url;
             }
           }

           if (videoUrl != null && !_isCancelled) {
             try {
               success = await _downloadWrapper(videoUrl, filePath);
             } catch (e) {
               debugPrint("❌ Failed to download ${song.title}: $e");
             }
           } else if (videoUrl == null) {
             debugPrint("⚠️ No match found for ${song.title}");
           }
        }

        if (!success) {
          debugPrint("⚠️ Download reported failure for ${song.title}");
        }

          if (success) {
            // Wait for file handle release (Critical for Windows)
            await Future.delayed(const Duration(milliseconds: 500));

            // 5. Tag
            final actualPath = File(filePath).existsSync()
                ? filePath
                : (filePath.endsWith('.flac') && File('${filePath.substring(0, filePath.length - 5)}.m4a').existsSync()
                    ? '${filePath.substring(0, filePath.length - 5)}.m4a'
                    : filePath);
            await _smartService.tagFile(filePath: actualPath, metadata: metadata);

            // 6. 🛑 TRACK USAGE (Only for new downloads)
            if (!isAlac) {
              await MetricsService().trackDownloadMetadata(metadata);
            }

            _songCompleteController.add(song.filePath); // Notify Success
          }


        completed++;
        _updateProgress(completed, total, "Downloading...");
      }

      if (!_isCancelled) {
        int remaining = await MetricsService().getRemainingQuota();
        _updateProgress(total, total, "Completed ($remaining left)");

        // DONE
        String pFormat = 'm4a';
        if (AppleMusicBackendService.globalRef != null) {
          pFormat = AppleMusicBackendService.globalRef!.read(settingsProvider).audioFormat;
        }
        final ext = pFormat == 'm4a' ? 'AAC' : pFormat.toUpperCase();
        await notif.showComplete(
            id: notifId,
            title: "Download Complete",
            body: "$albumTitle downloaded successfully ($ext).");
      }

      // Clear after a delay
      await Future.delayed(const Duration(seconds: 3));
      progressNotifier.value = null;
    } catch (e) {
      debugPrint("❌ Bulk Download Error: $e");
      progressNotifier.value = null;
    } finally {
      _isDownloading = false;
      _isCancelled = false; // Reset flag
      currentSongNotifier.value = null; // Reset
    }
  }

  Future<bool> _downloadWrapper(String url, String path) async {
    final completer = Completer<bool>();

    await _ytService.startDownloadFromUrl(
        youtubeUrl: url,
        outputFilePath: path,
        audioFormat: 'm4a', // FORCE ENC M4A
        onProgress: (p) {},
        onComplete: (s) {
          if (!completer.isCompleted) completer.complete(s);
        });

    return completer.future;
  }

  void _updateProgress(int completed, int total, String status) {
    double p = total > 0 ? completed / total : 0;
    progressNotifier.value = DownloadProgress(
        receivedMB: 0, // Not relevant
        totalMB: 0, // Not relevant
        progress: p,
        status: status,
        details: "$completed / $total Songs Downloaded");
  }

  Future<Directory?> getAlbumDownloadDirectory(String albumTitle) async {
    // downloads/SimpleMusicDownloads/playlists/{Album Title}

    String? basePath;

    if (Platform.isAndroid) {
      // FIX: Use public Download directory on Android
      // /storage/emulated/0/Download/SimpleMusicDownloads/Playlists
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final updatePath = Directory("/storage/emulated/0/Download");
          if (await updatePath.exists()) {
            basePath = updatePath.path;
          } else {
            final path = externalDir.path;
            final androidIndex = path.indexOf("/Android/");
            if (androidIndex != -1) {
              basePath = "${path.substring(0, androidIndex)}/Download";
            } else {
              basePath = externalDir.path;
            }
          }
        }
      } catch (e) {
        debugPrint("⛔ Error getting external storage: $e");
      }

      // Fallback to app documents directory
      if (basePath == null) {
        final appDocDir = await getApplicationDocumentsDirectory();
        basePath = appDocDir.path;
      }
    } else if (Platform.isIOS) {
      // iOS uses app documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      basePath = appDocDir.path;
    } else {
      // Desktop: Use Downloads directory
      final downloadDir = await getDownloadsDirectory();
      if (downloadDir != null) {
        basePath = downloadDir.path;
      }
    }

    if (basePath == null) return null;

    final base = Directory("$basePath/SimpleMusicDownloads/playlists");
    if (!await base.exists()) {
      await base.create(recursive: true);
    }

    final safeAlbum = FilenameHelper.sanitize(albumTitle);
    final albumDir = Directory("${base.path}/$safeAlbum");

    if (!await albumDir.exists()) {
      await albumDir.create(recursive: true);
    }

    return albumDir;
  }
}
