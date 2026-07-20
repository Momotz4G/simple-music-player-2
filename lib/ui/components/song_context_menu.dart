import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/song_model.dart';
import '../../providers/metadata_provider.dart';
import 'metadata_editor_panel.dart';
import '../../models/song_metadata.dart';
import '../../providers/player_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/smart_download_service.dart';
import '../../services/download_queue_service.dart';
import '../../services/youtube_downloader_service.dart';
import '../../services/spotify_service.dart';
import '../../services/deezer_service.dart';
import '../../services/apple_music_backend_service.dart';
import '../../services/notification_service.dart';
import '../../services/flac_downloader_service.dart';
import 'music_notification.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

enum SongAction {
  playNext,
  addToQueue,
  addToPlaylist,
  addToFavorite,
  goToArtist,
  download,
  editMetadata,
  deleteFile
}

class SongContextMenuRegion extends ConsumerWidget {
  final SongModel song;
  final List<SongModel> currentQueue;
  final Widget child;
  final bool allowMetadataEdit;

  const SongContextMenuRegion({
    super.key,
    required this.song,
    required this.currentQueue,
    required this.child,
    this.allowMetadataEdit = false,
  });

  static Future<void> handleAction(BuildContext context, WidgetRef ref,
      SongAction action, SongModel song) async {
    final notifier = ref.read(playerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    switch (action) {
      case SongAction.deleteFile:
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.deleteFileTitle),
            content: Text(l10n.deleteFileContent(song.title)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel)),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.delete,
                    style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          try {
            final file = File(song.filePath);
            if (await file.exists()) {
              await file.delete();
            }
            if (context.mounted) {
              ref.read(libraryProvider.notifier).removeSongByPath(song.filePath);
            }
          } catch (e) {
            debugPrint("Failed to delete file: $e");
          }
        }
        break;

      case SongAction.editMetadata:
        // 🚀 Set active selection prior to launch
        ref.read(metadataProvider.notifier).selectSong(song);

        // Calculate size for Desktop Dialog viewport bounds
        final isDesktop = MediaQuery.of(context).size.width >= 800;

        if (isDesktop) {
          showDialog(
            context: context,
            builder: (context) {
              return Consumer(
                builder: (context, ref, _) {
                  final state = ref.watch(metadataProvider);
                  final notifier = ref.read(metadataProvider.notifier);
                  final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

                  return AlertDialog(
                    backgroundColor: Theme.of(context).cardColor,
                    contentPadding: EdgeInsets.zero,
                    content: SizedBox(
                      width: 900,
                      height: 600,
                      child: state.isLoadingMetadata 
                        ? const Center(child: CircularProgressIndicator())
                        : MetadataEditorPanel(
                            state: state,
                            notifier: notifier,
                            textColor: textColor,
                            popOnSave: true,
                          ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.close),
                      )
                    ],
                  );
                },
              );
            }
          );
        } else {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) {
              return Consumer(
                builder: (context, ref, _) {
                  final state = ref.watch(metadataProvider);
                  final notifier = ref.read(metadataProvider.notifier);
                  final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

                  return Container(
                    height: MediaQuery.of(context).size.height * 0.85,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        // Handle bar for Sheet drag
                        Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[600]?.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        Expanded(
                          child: state.isLoadingMetadata 
                            ? const Center(child: CircularProgressIndicator())
                            : MetadataEditorPanel(
                                state: state,
                                notifier: notifier,
                                textColor: textColor,
                                popOnSave: true,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }
          );
        }
        break;
      case SongAction.playNext:
        notifier.insertSongNext(song);
        if (!context.mounted) return;
        showCenterNotification(context,
            label: l10n.queueUpdated,
            title: l10n.playingNext,
            subtitle: song.title,
            // Use artPath instead of artBytes
            artPath: song.filePath,
            onlineArtUrl: song.onlineArtUrl);
        break;

      case SongAction.addToQueue:
        notifier.addToQueue(song);
        if (!context.mounted) return;
        showCenterNotification(context,
            label: l10n.queueUpdated,
            title: l10n.addedToQueue,
            subtitle: song.title,
            // Use artPath instead of artBytes
            artPath: song.filePath,
            onlineArtUrl: song.onlineArtUrl);
        break;

      case SongAction.addToPlaylist:
        final playlists = ref.read(playlistProvider);
        final playlistNotifier = ref.read(playlistProvider.notifier);

        if (playlists.isEmpty) {
          showCenterNotification(context,
              label: l10n.error,
              title: l10n.noPlaylistsFound,
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.9));
          return;
        }

        showDialog(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.addToPlaylist),
            backgroundColor: Theme.of(context).cardColor,
            children: playlists
                .map((p) => SimpleDialogOption(
                      onPressed: () {
                        // Check duplicate
                        final exists =
                            p.entries.any((e) => e.path == song.filePath);

                        if (exists) {
                          Navigator.pop(context);
                          // 🔴 GLASS RED ERROR
                          showCenterNotification(context,
                              label: l10n.error,
                              title: l10n
                                  .songAlreadyInPlaylist,
                              subtitle: p.name,
                              // Use artPath instead of artBytes
                              artPath: song.filePath,
                              backgroundColor:
                                  Colors.redAccent.withValues(alpha: 0.85),
                              onlineArtUrl: song.onlineArtUrl);
                        } else {
                          playlistNotifier.addSongToPlaylist(p.id, song);
                          Navigator.pop(context);
                          // 🟢 SUCCESS
                          showCenterNotification(context,
                              label: l10n
                                  .addedToPlaylistSuccess,
                              title: p.name,
                              subtitle: song.title,
                              // Use artPath instead of artBytes
                              artPath: song.filePath,
                              onlineArtUrl: song.onlineArtUrl);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(p.name),
                      ),
                    ))
                .toList(),
          ),
        );
        break;

      case SongAction.addToFavorite:
        final playlists = ref.read(playlistProvider);
        final playlistNotifier = ref.read(playlistProvider.notifier);

        // 🚀 CHECK IF ALREADY IN LIKED SONGS
        // Safely find the Liked Songs playlist
        final likedPlaylist =
            playlists.where((p) => p.name == "Liked Songs").firstOrNull;

        final alreadyExists = likedPlaylist != null &&
            likedPlaylist.entries.any((e) => e.path == song.filePath);

        if (alreadyExists) {
          // 🔴 ALREADY EXISTS - Show Error
          if (!context.mounted) return;
          showCenterNotification(context,
              label: l10n.alreadyInLikedSongs,
              title: song.title,
              subtitle: l10n.alreadyInLikedSongs,
              artPath: song.filePath,
              onlineArtUrl: song.onlineArtUrl,
              icon: Icons.favorite_rounded,
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.85));
        } else {
          // ✅ ADD TO LIKED SONGS
          playlistNotifier.addToLikedSongs(song);
          if (!context.mounted) return;
          showCenterNotification(context,
              label: l10n.likedSongs,
              title: l10n.addedToLikedSongs,
              subtitle: song.title,
              artPath: song.filePath,
              onlineArtUrl: song.onlineArtUrl,
              icon: Icons.favorite_rounded,
              backgroundColor: Colors.pinkAccent.withValues(alpha: 0.85));
        }
        break;

      case SongAction.goToArtist:
        final librarySongs = ref.read(libraryProvider).songs;
        final artistSongs =
            librarySongs.where((s) => s.artist == song.artist).toList();

        // FIX: Use Provider Navigation instead of manual Push
        // This ensures MainShell switches the view correctly
        ref.read(navigationStackProvider.notifier).push(
              NavigationItem(
                type: NavigationType.artist,
                data: ArtistSelection(
                  artistName: song.artist,
                  songs: artistSongs,
                ),
              ),
            );
        break;
      case SongAction.download:
        // Download song with settings format (like search_page flow)
        final smartService = SmartDownloadService();
        final ytService = YoutubeDownloaderService();
        final settings = ref.read(settingsProvider);
        final isYtSource = song.sourceUrl != null && song.sourceUrl!.contains('youtube.com');
        final isAppleMusicSource = (song.sourceUrl != null && song.sourceUrl!.contains('music.apple.com')) || 
            (settings.searchEngine == SearchEngine.appleMusic && (song.sourceUrl == null || !song.sourceUrl!.contains('youtube.com')));
        
        // 🚀 FEATURE GATE: YouTube sources only support HQ (not Lossless)
        String preferredFormat = settings.audioFormat; // mp3, m4a, flac
        if (isYtSource && (preferredFormat == 'flac' || preferredFormat == 'alac')) {
          preferredFormat = 'm4a'; // Force to High Quality M4A
          debugPrint("🚫 YouTube source: Forcing M4A instead of Lossless");
        }
        
        final isFlacRequested = preferredFormat == 'flac';

        // 🚀 INIT NOTIFICATIONS
        final notif = NotificationService();
        await notif.init();
        final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // 🍎 APPLE MUSIC FAST-PATH
          if (isAppleMusicSource) {
            DownloadQueueService().enqueue(
              title: song.title,
              artist: song.artist,
              artUrl: song.onlineArtUrl,
              task: (itemId, onProgress, onComplete, onError) async {
                final formatName = preferredFormat == 'm4a' ? 'AAC' : preferredFormat.toUpperCase();
                final formatSubtitle = preferredFormat == 'm4a' ? 'AAC (Standard)' : '${preferredFormat.toUpperCase()} (Lossless)';

                try {
                    final ctxSafe = globalNavigatorKey.currentContext;
                    if (ctxSafe != null && ctxSafe.mounted) {
                      showCenterNotification(ctxSafe,
                        label: l10n.downloadStarted,
                        title: song.title,
                        subtitle: "Fetching $formatName from Apple Music...",
                        artPath: song.onlineArtUrl,
                        onlineArtUrl: song.onlineArtUrl);
                  }

                  notif.showProgress(id: notifId, progress: 0, max: 100, title: "Apple Music Download", body: song.title);

                  String targetUrl = song.sourceUrl ?? '';
                  
                  // If we don't have an Apple Music URL yet, we must search for it first!
                  if (targetUrl.isEmpty || !targetUrl.contains('music.apple.com')) {
                    final ctxSafe = globalNavigatorKey.currentContext;
                    if (ctxSafe != null && ctxSafe.mounted) {
                      showCenterNotification(ctxSafe,
                        label: l10n.preparingDownload,
                        title: song.title,
                        subtitle: "Finding match on Apple Music...",
                        artPath: song.onlineArtUrl,
                        onlineArtUrl: song.onlineArtUrl);
                    }
                    
                    final results = await AppleMusicBackendService.search("${song.title} ${song.artist}", limit: 1);
                    if (results.isNotEmpty && results.first['url'] != null) {
                      targetUrl = results.first['url'];
                    } else {
                      throw Exception("Could not find this exact track on Apple Music.");
                    }
                  }

                  final remoteAudioUrl = await AppleMusicBackendService.requestDownload(
                    targetUrl,
                    title: song.title,
                    artist: song.artist,
                    onQueueUpdate: (pos) {
                      String queueText = pos > 0
                        ? l10n.queuePositionPleaseWait(pos)
                        : l10n.processingOnServer;
                      onProgress(0.0, queueText);
                    },
                    isCancelled: () => DownloadQueueService().isCancelled(itemId),
                  );
                  if (remoteAudioUrl == null) {
                    throw Exception("VPS Bot failed to fetch the song from Telegram.");
                  }

                  final meta = SongMetadata(
                    title: song.title,
                    artist: song.artist,
                    album: song.album,
                    albumArtUrl: song.onlineArtUrl ?? '',
                    durationSeconds: song.duration.toInt(),
                  );
                  final finalTitle = await smartService.generateFilename(meta);
                  final fileExtension = preferredFormat == 'alac' ? 'm4a' : preferredFormat;
                  final outputPath = await ytService.getDownloadPath(finalTitle, ext: fileExtension);
                  if (outputPath == null) throw Exception("Storage permission denied or path error");

                  final success = await AppleMusicBackendService.downloadFile(remoteAudioUrl, outputPath, 
                    isCancelled: () => DownloadQueueService().isCancelled(itemId),
                    onProgress: (p, receivedBytes, totalBytes) {
                      final rMB = receivedBytes / (1024 * 1024);
                      final tMB = totalBytes / (1024 * 1024);
                      final actualTotal = tMB > 0 ? tMB : 35.0; // Fallback if contentLength is missing
                      final actualReceived = tMB > 0 ? rMB : (p * 35.0);
                      
                      onProgress(p, "${(p * 100).toInt()}% - $formatName", receivedMB: actualReceived, totalMB: actualTotal);
                      notif.showProgress(id: notifId, progress: (p * 100).toInt(), max: 100, title: "Downloading $formatName", body: song.title);
                  });

                  if (success) {
                    final actualSavedPath = File(outputPath).existsSync()
                        ? outputPath
                        : (outputPath.endsWith('.flac') && File('${outputPath.substring(0, outputPath.length - 5)}.m4a').existsSync()
                            ? '${outputPath.substring(0, outputPath.length - 5)}.m4a'
                            : outputPath);
                    try { await smartService.tagFile(filePath: actualSavedPath, metadata: meta); } catch (e) { debugPrint("Tagging warning: $e"); }
                    final ctxSafe = globalNavigatorKey.currentContext;
                    if (ctxSafe != null && ctxSafe.mounted) {
                      // Fetch the real-time updated quota directly from the VPS database
                      try {
                        ProviderScope.containerOf(ctxSafe).read(profileProvider.notifier).refreshQuotaFromCloud();
                      } catch (_) {}

                      if (DownloadQueueService().pendingCount == 0) {
                        final qLength = DownloadQueueService().queueNotifier.value.length;
                        final isBatch = qLength > 1;
                        showCenterNotification(ctxSafe,
                            label: l10n.downloadComplete,
                            title: isBatch ? "All Downloads Complete" : song.title,
                            subtitle: isBatch ? "$qLength tracks successfully saved." : "Saved as $formatSubtitle",
                            artPath: isBatch ? null : outputPath,
                            onlineArtUrl: isBatch ? null : song.onlineArtUrl,
                            backgroundColor: Colors.green.withValues(alpha: 0.85),
                            icon: isBatch ? Icons.check_circle_outline : null);
                      }
                    }
                    notif.showComplete(id: notifId, title: l10n.downloadCompleteNotification, body: "${song.title} ($formatName)");
                    onComplete();
                  } else {
                    throw Exception("Failed to stream $formatName from VPS to local storage.");
                  }
                } catch (e) {
                  onError(e.toString());
                  final ctxSafe = globalNavigatorKey.currentContext;
                  
                  bool isQuotaError = e.toString().contains("QUOTA_EXCEEDED:");
                  String errorMsg = e.toString().replaceAll("Exception:", "").trim();
                  
                  if (isQuotaError) {
                      errorMsg = errorMsg.split("QUOTA_EXCEEDED:").last.trim();
                  }

                  if (ctxSafe != null && ctxSafe.mounted) {
                    showCenterNotification(ctxSafe,
                        label: isQuotaError ? "Quota Limit Reached" : l10n.downloadFailed,
                        title: isQuotaError ? "Daily Limit Reached" : song.title,
                        subtitle: errorMsg,
                        onlineArtUrl: song.onlineArtUrl,
                        icon: isQuotaError ? Icons.workspace_premium_rounded : Icons.error_rounded,
                        backgroundColor: isQuotaError ? Colors.amber[800]!.withValues(alpha: 0.95) : Colors.red.withValues(alpha: 0.85));
                  }
                  notif.showComplete(id: notifId, title: isQuotaError ? "Quota Limit Reached" : l10n.downloadFailed, body: isQuotaError ? errorMsg : "${song.title} - $errorMsg");
                }
              },
            );
            return; // EXIT DOWNLOAD EARLY
          }

          // 🔍 STEP 0: Preserve existing IDs from SongModel (from search results)
          String? spotifyArtUrl = song.onlineArtUrl;
          String? spotifyId = song.spotifyId;
          String? deezerId = song.deezerId;
          String? isrc = song.isrc;

          debugPrint("🔍 Searching for metadata (Spotify → Deezer fallback)...");
          debugPrint("   Existing IDs: spotifyId=$spotifyId, deezerId=$deezerId, isrc=$isrc");
          if (!context.mounted) return;
          showCenterNotification(context,
              label: l10n.preparingDownload,
              title: song.title,
              subtitle: l10n.fetchingMetadataSpotify,
              artPath: song.onlineArtUrl,
              onlineArtUrl: song.onlineArtUrl,
              icon: song.onlineArtUrl == null ? Icons.search_rounded : null);

          // Notify Start
          notif.showProgress(
              id: notifId,
              progress: 0,
              max: 100,
              title: l10n.preparingDownloadNotification,
              body: song.title);

          // 🚀 SMART METADATA ENRICHMENT (Spotify first, Deezer fallback)
          String? year = song.year;
          String? genre = song.genre;
          String title = song.title;
          String artist = song.artist;
          String album = song.album;
          bool spotifyEnrichmentSucceeded = false;

          final isYtSourceCurrent = song.sourceUrl != null && song.sourceUrl!.contains('youtube');

          // --- 🚀 FEATURE GATE: If YouTube source, we MUST notify user that lossless is unavailable if they have it set ---
          if (isYtSourceCurrent && (settings.audioFormat == 'flac' || settings.audioFormat == 'alac')) {
             final ctxSafe = globalNavigatorKey.currentContext;
                    if (ctxSafe != null && ctxSafe.mounted) {
                      showCenterNotification(ctxSafe,
                  label: l10n.losslessQuality,
                  title: l10n.flacUnavailable,
                  subtitle: "YouTube sources only support up to High Quality (M4A).",
                  onlineArtUrl: song.onlineArtUrl,
                  icon: Icons.info_outline_rounded,
                  backgroundColor: Colors.orange.withValues(alpha: 0.85));
             }
          }

          // --- TRY SPOTIFY FIRST ---
          if (isYtSource || year == null || year.isEmpty) {
             final query = "${song.title} ${song.artist}";
             try {
                final results = await SpotifyService.searchTracks(query);
                if (results.isNotEmpty) {
                  final richMeta = results.first;
                  spotifyId ??= richMeta.spotifyId;
                  spotifyArtUrl = richMeta.albumArtUrl.isNotEmpty ? richMeta.albumArtUrl : spotifyArtUrl;
                  isrc = richMeta.isrc ?? isrc;
                  year = (richMeta.year != null && richMeta.year!.isNotEmpty) ? richMeta.year : year;
                  genre = richMeta.genre ?? genre;
                  title = richMeta.title.isNotEmpty ? richMeta.title : title;
                  artist = richMeta.artist.isNotEmpty ? richMeta.artist : artist;
                  album = richMeta.album.isNotEmpty ? richMeta.album : album;
                  spotifyEnrichmentSucceeded = true;
                }
             } catch(e) {
                debugPrint("⚠️ Spotify enrichment failed: $e");
             }
          } else {
             // Fallback to old behavior if already has good metadata or not YT
             try {
               final spotifyResults = await SpotifyService.searchMetadata(
                "${song.artist} ${song.title}",
               );
  
               if (spotifyResults.isNotEmpty) {
                 final firstResult = spotifyResults.first;
                 spotifyId ??= firstResult['spotify_id'] as String?;
                 spotifyArtUrl =
                     firstResult['image_url'] as String? ?? spotifyArtUrl;
                 isrc = (firstResult['isrc'] as String?) ?? isrc;
                 spotifyEnrichmentSucceeded = true;
               }
             } catch(e) {
                debugPrint("⚠️ Spotify metadata search failed: $e");
             }
          }

          // --- 🚀 DEEZER FALLBACK: If Spotify failed AND we don't have a deezerId yet ---
          if (!spotifyEnrichmentSucceeded && (deezerId == null || deezerId.isEmpty)) {
            debugPrint("🔄 Spotify unavailable. Trying Deezer for metadata enrichment...");
            try {
              final deezerResults = await DeezerService.searchSongs(
                  "${song.title} ${song.artist}", limit: 5);
              if (deezerResults.isNotEmpty) {
                final bestMatch = deezerResults.first;
                deezerId = bestMatch.deezerId;
                spotifyArtUrl = bestMatch.albumArtUrl.isNotEmpty ? bestMatch.albumArtUrl : spotifyArtUrl;
                isrc = bestMatch.isrc ?? isrc;
                title = bestMatch.title.isNotEmpty ? bestMatch.title : title;
                artist = bestMatch.artist.isNotEmpty ? bestMatch.artist : artist;
                album = bestMatch.album.isNotEmpty ? bestMatch.album : album;
                debugPrint("✅ Deezer fallback success: deezerId=$deezerId");
              }
            } catch(e) {
              debugPrint("⚠️ Deezer fallback also failed: $e");
            }
          }

          // Build metadata with enriched data (includes both spotifyId AND deezerId)
          final meta = SongMetadata(
            title: title,
            artist: artist,
            album: album,
            albumArtUrl: spotifyArtUrl ?? '',
            durationSeconds: song.duration.toInt(),
            year: year ?? '',
            genre: genre ?? '',
            isrc: isrc,
            spotifyId: spotifyId,
            deezerId: deezerId,
          );

          if (!context.mounted) return;
          showCenterNotification(context,
              label: l10n.downloadStarted,
              title: song.title,
              subtitle: l10n
                  .preparingDownloadFormat(preferredFormat),
              artPath: spotifyArtUrl,
              onlineArtUrl: spotifyArtUrl);

          // 🚀 ENQUEUE YOUTUBE/FLAC DOWNLOAD
          DownloadQueueService().enqueue(
            title: song.title,
            artist: song.artist,
            artUrl: spotifyArtUrl,
            task: (itemId, onProgress, onComplete, onError) async {
              try {

              // 1. Get YouTube URL (use existing sourceUrl or search)
              String? youtubeUrl = song.sourceUrl;
              if (youtubeUrl == null || youtubeUrl.isEmpty) {
                final ctxSafe = globalNavigatorKey.currentContext;
                    if (ctxSafe != null && ctxSafe.mounted) {
                      showCenterNotification(ctxSafe,
                      label: l10n.searching,
                      title: song.title,
                      subtitle: l10n.findingBestMatchYoutube,
                      artPath: spotifyArtUrl,
                      onlineArtUrl: spotifyArtUrl);
                }

                final searchResult = await smartService.searchYouTubeForMatch(meta);
                if (searchResult != null &&
                    searchResult.youtubeMatches.isNotEmpty) {
                  youtubeUrl = searchResult.youtubeMatches.first.url;
                }
              }

              if (youtubeUrl == null || youtubeUrl.isEmpty) {
                throw Exception("No YouTube match found");
              }

              // 2. FLAC path (if requested and spotifyId available)
              if (isFlacRequested) {
                try {
                  final ctxSafe = globalNavigatorKey.currentContext;
                    if (ctxSafe != null && ctxSafe.mounted) {
                      showCenterNotification(ctxSafe,
                        label: l10n.downloadingFlac,
                        title: song.title,
                        subtitle: l10n.fetchingLosslessAudio,
                        artPath: spotifyArtUrl,
                        onlineArtUrl: spotifyArtUrl);
                  }

                  notif.showProgress(id: notifId, progress: 0, max: 100, title: l10n.downloadingFlac, body: song.title);

                  final flacResult = await smartService.downloadFlac(
                    metadata: meta,
                    onProgress: (p) {
                      final recMB = FlacDownloaderService.currentDownloadReceivedMB ?? (p * 30);
                      final totMB = FlacDownloaderService.currentDownloadTotalMB ?? 30.0;
                      onProgress(p, "${(p * 100).toInt()}% - FLAC", receivedMB: recMB, totalMB: totMB);
                      notif.showProgress(id: notifId, progress: (p * 100).toInt(), max: 100, title: l10n.downloadingFlac, body: song.title);
                    },
                    isStreaming: false,
                  );

                  if (flacResult != null) {
                    final ctxSafe = globalNavigatorKey.currentContext;
                    if (ctxSafe != null && ctxSafe.mounted) {
                      if (DownloadQueueService().pendingCount == 0) {
                        final qLength = DownloadQueueService().queueNotifier.value.length;
                        final isBatch = qLength > 1;
                        showCenterNotification(ctxSafe,
                            label: l10n.downloadComplete,
                            title: isBatch ? "All Downloads Complete" : song.title,
                            subtitle: isBatch ? "$qLength tracks successfully saved." : l10n.flacSavedToDownloads,
                            artPath: isBatch ? null : flacResult.filePath,
                            onlineArtUrl: isBatch ? null : spotifyArtUrl,
                            backgroundColor: Colors.green.withValues(alpha: 0.85),
                            icon: isBatch ? Icons.check_circle_outline : null);
                      }
                    }
                    notif.showComplete(id: notifId, title: l10n.downloadCompleteNotification, body: "${song.title} (FLAC)");
                    onComplete();
                    return;
                  }

                  final ctxSafe2 = globalNavigatorKey.currentContext;
                  if (ctxSafe2 != null && ctxSafe2.mounted) {
                    showCenterNotification(ctxSafe2,
                        label: l10n.flacUnavailable,
                        title: song.title,
                        subtitle: l10n.flacUnavailableDesc,
                        artPath: spotifyArtUrl,
                        onlineArtUrl: spotifyArtUrl,
                        icon: Icons.info_outline_rounded,
                        backgroundColor: Colors.orange.withValues(alpha: 0.85));
                  }
                  notif.showComplete(id: notifId, title: l10n.flacUnavailableNotification, body: "${song.title} - ${l10n.changeFormatInSettings}");
                  onError("FLAC Unavailable");
                  return;
                } catch (e) {
                  debugPrint("FLAC Error: $e");
                  final ctxSafe = globalNavigatorKey.currentContext;
                  if (ctxSafe != null && ctxSafe.mounted) {
                    showCenterNotification(ctxSafe,
                        label: l10n.flacError,
                        title: song.title,
                        subtitle: l10n.couldNotDownloadFlac,
                        artPath: spotifyArtUrl,
                        onlineArtUrl: spotifyArtUrl,
                        backgroundColor: Colors.red.withValues(alpha: 0.85));
                  }
                  notif.showComplete(id: notifId, title: l10n.downloadFailed, body: "${song.title} (FLAC Error)");
                  onError(e.toString());
                  return;
                }
              }

              // 3. YouTube download path (MP3/M4A or FLAC fallback)
              final actualFormat = isFlacRequested ? 'mp3' : preferredFormat;
              final actualFormatName = actualFormat == 'm4a' ? 'AAC' : actualFormat.toUpperCase();
              final actualFormatSubtitle = actualFormat == 'm4a' ? 'AAC (Standard)' : actualFormat.toUpperCase();

              final finalTitle = await smartService.generateFilename(meta);
              final outputPath = await ytService.getDownloadPath(finalTitle, ext: actualFormat);

              if (outputPath == null) {
                throw Exception("Storage permission denied or path error");
              }

              final ctxSafe = globalNavigatorKey.currentContext;
                    if (ctxSafe != null && ctxSafe.mounted) {
                      showCenterNotification(ctxSafe,
                    label: l10n.downloading,
                    title: song.title,
                    subtitle: l10n.downloadingFormat(actualFormatName),
                    artPath: spotifyArtUrl,
                    onlineArtUrl: spotifyArtUrl);
              }

              notif.showProgress(id: notifId, progress: 0, max: 100, title: l10n.downloadingFormat(actualFormatName), body: song.title);

              await ytService.startDownloadFromUrl(
                youtubeUrl: youtubeUrl,
                outputFilePath: outputPath,
                audioFormat: actualFormat,
                isCancelled: () => DownloadQueueService().isCancelled(itemId),
                onProgress: (p) {
                  onProgress(p, "${(p * 100).toInt()}% - $actualFormatName", receivedMB: p * 10, totalMB: 10);
                  notif.showProgress(id: notifId, progress: (p * 100).toInt(), max: 100, title: l10n.downloadingFormat(actualFormatName), body: song.title);
                },
                onComplete: (success) async {
                  if (success) {
                    try { await smartService.tagFile(filePath: outputPath, metadata: meta); } catch (e) { debugPrint("Tagging warning: $e"); }
                    final ctxSafe = globalNavigatorKey.currentContext;
                    if (ctxSafe != null && ctxSafe.mounted) {
                      if (DownloadQueueService().pendingCount == 0) {
                        final qLength = DownloadQueueService().queueNotifier.value.length;
                        final isBatch = qLength > 1;
                        showCenterNotification(ctxSafe,
                            label: l10n.downloadComplete,
                            title: isBatch ? "All Downloads Complete" : song.title,
                            subtitle: isBatch ? "$qLength tracks successfully saved." : "Saved as $actualFormatSubtitle",
                            artPath: isBatch ? null : outputPath,
                            onlineArtUrl: isBatch ? null : spotifyArtUrl,
                            backgroundColor: Colors.green.withValues(alpha: 0.85),
                            icon: isBatch ? Icons.check_circle_outline : null);
                      }
                    }
                    notif.showComplete(id: notifId, title: l10n.downloadCompleteNotification, body: "${song.title} ($actualFormatName)");
                    onComplete();
                  } else {
                    final ctxSafe = globalNavigatorKey.currentContext;
                    if (ctxSafe != null && ctxSafe.mounted) {
                      showCenterNotification(ctxSafe,
                          label: l10n.downloadFailed,
                          title: song.title,
                          subtitle: l10n.downloadError,
                          artPath: spotifyArtUrl,
                          onlineArtUrl: spotifyArtUrl,
                          backgroundColor: Colors.red.withValues(alpha: 0.85));
                    }
                    notif.cancel(notifId);
                    onError("YouTube Download Failed");
                  }
                },
              );
              } catch (e) {
                debugPrint("❌ Download Error: $e");
                final errorStr = e.toString();
                if (errorStr.contains('GOFILE_FALLBACK_URL:')) {
                  final gofileUrl = errorStr.split('GOFILE_FALLBACK_URL:').last.trim();
                  notif.cancel(notifId);
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Theme.of(context).cardColor,
                        title: Row(
                          children: [
                            const Icon(Icons.open_in_new_rounded, color: Colors.blueAccent),
                            const SizedBox(width: 12),
                            Text(l10n.externalLinkDetected),
                          ],
                        ),
                        content: Text(l10n.gofileDownloadFailedPrompt),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(l10n.close),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: gofileUrl));
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.linkCopied), duration: const Duration(seconds: 2)),
                              );
                            },
                            child: Text(l10n.copyLink),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                            onPressed: () async {
                              Navigator.pop(context);
                              try { await launchUrl(Uri.parse(gofileUrl), mode: LaunchMode.externalApplication); } catch (_) {}
                            },
                            child: Text(l10n.openBrowser),
                          ),
                        ],
                      ),
                    );
                  }
                  onError("Gofile fallback required");
                  return;
                }

                final ctxSafe = globalNavigatorKey.currentContext;
                if (ctxSafe != null && ctxSafe.mounted) {
                  showCenterNotification(ctxSafe,
                      label: l10n.downloadFailed,
                      title: song.title,
                      subtitle: e.toString().replaceAll("Exception:", "").trim(),
                      onlineArtUrl: song.onlineArtUrl,
                      icon: Icons.error_rounded,
                      backgroundColor: Colors.red.withValues(alpha: 0.85));
                }
                notif.showComplete(id: notifId, title: l10n.downloadFailed, body: "${song.title} - ${e.toString().replaceAll("Exception:", "").trim()}");
                onError(e.toString());
              }
            },
          );
        break;
    }
  }

  static Future<void> showSongMenu(BuildContext context, Offset offset,
      WidgetRef ref, SongModel song, {bool allowMetadataEdit = false}) async {
    final isLocal = await File(song.filePath).exists();
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;

    final selected = await showMenu<SongAction>(
      context: context,
      position:
          RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx, offset.dy),
      items: [
        PopupMenuItem(
            value: SongAction.playNext,
            child: Row(children: [
              const Icon(Icons.playlist_play),
              const SizedBox(width: 12),
              Text(l10n.playNext)
            ])),
        PopupMenuItem(
            value: SongAction.addToQueue,
            child: Row(children: [
              const Icon(Icons.queue_music),
              const SizedBox(width: 12),
              Text(l10n.addToQueue)
            ])),
        PopupMenuItem(
            value: SongAction.addToPlaylist,
            child: Row(children: [
              const Icon(Icons.playlist_add),
              const SizedBox(width: 12),
              Text(l10n.addToPlaylist)
            ])),
        PopupMenuItem(
            value: SongAction.addToFavorite,
            child: Row(children: [
              const Icon(Icons.favorite_border),
              const SizedBox(width: 12),
              Text(l10n.addToFavorite)
            ])),
        PopupMenuItem(
            value: SongAction.goToArtist,
            child: Row(children: [
              const Icon(Icons.person_search),
              const SizedBox(width: 12),
              Text(l10n.goToArtist)
            ])),
        if (!isLocal)
          PopupMenuItem(
              value: SongAction.download,
              child: Row(children: [
                const Icon(Icons.download_rounded),
                const SizedBox(width: 12),
                Text(l10n.download)
              ])),
        if (allowMetadataEdit && isLocal)
          PopupMenuItem(
              value: SongAction.editMetadata,
              child: Row(children: [
                const Icon(Icons.edit_note),
                const SizedBox(width: 12),
                Text(l10n.editMetadata)
              ])),
        if (isLocal)
          PopupMenuItem(
              value: SongAction.deleteFile,
              child: Row(children: [
                const Icon(Icons.delete_outline, color: Colors.red),
                const SizedBox(width: 12),
                Text(l10n.delete, style: const TextStyle(color: Colors.red))
              ])),
      ],
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).cardColor,
    );

    if (selected != null && context.mounted) {
      handleAction(context, ref, selected, song);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          showSongMenu(context, details.globalPosition, ref, song, allowMetadataEdit: allowMetadataEdit);
        },
        onLongPressStart: (details) {
          // Mobile Long Press
          if (Platform.isAndroid || Platform.isIOS) {
            showSongMenu(context, details.globalPosition, ref, song, allowMetadataEdit: allowMetadataEdit);
          }
        },
        child: child,
      ),
    );
  }
}
