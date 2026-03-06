import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song_model.dart';
import '../../models/song_metadata.dart';
import '../../providers/player_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/smart_download_service.dart';
import '../../services/youtube_downloader_service.dart';
import '../../services/spotify_service.dart';
import '../../models/download_progress.dart';
import '../../services/notification_service.dart';
import 'music_notification.dart';
import '../../l10n/app_localizations.dart';

enum SongAction {
  playNext,
  addToQueue,
  addToPlaylist,
  addToFavorite,
  goToArtist,
  download
}

class SongContextMenuRegion extends ConsumerWidget {
  final SongModel song;
  final List<SongModel> currentQueue;
  final Widget child;

  const SongContextMenuRegion({
    super.key,
    required this.song,
    required this.currentQueue,
    required this.child,
  });

  static Future<void> handleAction(BuildContext context, WidgetRef ref,
      SongAction action, SongModel song) async {
    final notifier = ref.read(playerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    switch (action) {
      case SongAction.playNext:
        notifier.insertSongNext(song);
        if (!context.mounted) return;
        showCenterNotification(context,
            label: AppLocalizations.of(context)!.queueUpdated,
            title: AppLocalizations.of(context)!.playingNext,
            subtitle: song.title,
            // Use artPath instead of artBytes
            artPath: song.filePath,
            onlineArtUrl: song.onlineArtUrl);
        break;

      case SongAction.addToQueue:
        notifier.addToQueue(song);
        if (!context.mounted) return;
        showCenterNotification(context,
            label: AppLocalizations.of(context)!.queueUpdated,
            title: AppLocalizations.of(context)!.addedToQueue,
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
              label: AppLocalizations.of(context)!.error,
              title: AppLocalizations.of(context)!.noPlaylistsFound,
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.9));
          return;
        }

        showDialog(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(AppLocalizations.of(context)!.addToPlaylist),
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
                              label: AppLocalizations.of(context)!.error,
                              title: AppLocalizations.of(context)!
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
                              label: AppLocalizations.of(context)!
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
              label: AppLocalizations.of(context)!.alreadyInLikedSongs,
              title: song.title,
              subtitle: AppLocalizations.of(context)!.alreadyInLikedSongs,
              artPath: song.filePath,
              onlineArtUrl: song.onlineArtUrl,
              icon: Icons.favorite_rounded,
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.85));
        } else {
          // ✅ ADD TO LIKED SONGS
          playlistNotifier.addToLikedSongs(song);
          if (!context.mounted) return;
          showCenterNotification(context,
              label: AppLocalizations.of(context)!.likedSongs,
              title: AppLocalizations.of(context)!.addedToLikedSongs,
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
        final preferredFormat = settings.audioFormat; // mp3, m4a, flac
        final isFlacRequested = preferredFormat == 'flac';

        // 🚀 INIT NOTIFICATIONS
        final notif = NotificationService();
        await notif.init();
        final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        try {
          // 🔍 STEP 0: Search Spotify FIRST to get metadata + album art
          String? spotifyArtUrl = song.onlineArtUrl;
          String? spotifyId;
          String? isrc = song.isrc;

          debugPrint("🔍 Searching Spotify for metadata...");
          if (!context.mounted) return;
          showCenterNotification(context,
              label: AppLocalizations.of(context)!.preparingDownload,
              title: song.title,
              subtitle: AppLocalizations.of(context)!.fetchingMetadataSpotify,
              artPath: song.onlineArtUrl,
              onlineArtUrl: song.onlineArtUrl,
              icon: song.onlineArtUrl == null ? Icons.search_rounded : null);

          // Notify Start
          notif.showProgress(
              id: notifId,
              progress: 0,
              max: 100,
              title:
                  AppLocalizations.of(context)!.preparingDownloadNotification,
              body: song.title);

          final spotifyResults = await SpotifyService.searchMetadata(
            "${song.artist} ${song.title}",
          );

          if (spotifyResults.isNotEmpty) {
            final firstResult = spotifyResults.first;
            spotifyId = firstResult['spotify_id'] as String?;
            spotifyArtUrl =
                firstResult['image_url'] as String? ?? spotifyArtUrl;
            isrc = (firstResult['isrc'] as String?) ?? isrc;
            debugPrint(
                "✓ Found Spotify metadata: ID=$spotifyId, Art=$spotifyArtUrl");
          }

          // Build metadata with Spotify data
          final meta = SongMetadata(
            title: song.title,
            artist: song.artist,
            album: song.album,
            albumArtUrl: spotifyArtUrl ?? '',
            durationSeconds: song.duration.toInt(),
            year: song.year ?? '',
            genre: song.genre ?? '',
            isrc: isrc,
            spotifyId: spotifyId,
          );

          showCenterNotification(context,
              label: AppLocalizations.of(context)!.downloadStarted,
              title: song.title,
              subtitle: AppLocalizations.of(context)!
                  .preparingDownloadFormat(preferredFormat),
              artPath: spotifyArtUrl,
              onlineArtUrl: spotifyArtUrl);

          // 🚀 UPDATE SIDEBAR PROGRESS
          SmartDownloadService.progressNotifier.value = DownloadProgress(
            receivedMB: 0,
            totalMB: 0,
            progress: 0.0,
            status: "${l10n.downloading}: ${song.title}",
            details: "${l10n.searching}...",
          );

          // 1. Get YouTube URL (use existing sourceUrl or search)
          String? youtubeUrl = song.sourceUrl;
          if (youtubeUrl == null || youtubeUrl.isEmpty) {
            if (!context.mounted) return;
            showCenterNotification(context,
                label: AppLocalizations.of(context)!.searching,
                title: song.title,
                subtitle: AppLocalizations.of(context)!.findingBestMatchYoutube,
                artPath: spotifyArtUrl,
                onlineArtUrl: spotifyArtUrl);

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
          if (isFlacRequested &&
              (meta.spotifyId != null ||
                  (meta.isrc != null && meta.isrc!.isNotEmpty))) {
            try {
              showCenterNotification(context,
                  label: AppLocalizations.of(context)!.downloadingFlac,
                  title: song.title,
                  subtitle: AppLocalizations.of(context)!.fetchingLosslessAudio,
                  artPath: spotifyArtUrl,
                  onlineArtUrl: spotifyArtUrl);

              notif.showProgress(
                  id: notifId,
                  progress: 0,
                  max: 100,
                  title: AppLocalizations.of(context)!.downloadingFlac,
                  body: song.title);

              final flacResult = await smartService.downloadFlac(
                metadata: meta,
                onProgress: (p) {
                  // 🚀 UPDATE SIDEBAR PROGRESS FOR FLAC
                  SmartDownloadService.progressNotifier.value =
                      DownloadProgress(
                    receivedMB: p * 30, // FLAC is larger
                    totalMB: 30,
                    progress: p,
                    status: "${l10n.downloading}: ${song.title}",
                    details: "${(p * 100).toInt()}% - FLAC",
                  );
                  // 🚀 NOTIF
                  notif.showProgress(
                      id: notifId,
                      progress: (p * 100).toInt(),
                      max: 100,
                      title: l10n.downloadingFlac,
                      body: song.title);
                },
                isStreaming: false,
              );

              if (flacResult != null) {
                // 🚀 CLEAR SIDEBAR PROGRESS
                SmartDownloadService.progressNotifier.value = null;

                if (!context.mounted) return;
                showCenterNotification(context,
                    label: AppLocalizations.of(context)!.downloadComplete,
                    title: song.title,
                    subtitle:
                        AppLocalizations.of(context)!.flacSavedToDownloads,
                    artPath: flacResult.filePath,
                    onlineArtUrl: spotifyArtUrl,
                    backgroundColor: Colors.green.withValues(alpha: 0.85));

                notif.showComplete(
                    id: notifId,
                    title: AppLocalizations.of(context)!
                        .downloadCompleteNotification,
                    body: "${song.title} (FLAC)");
                return; // SUCCESS!
              }

              // 🚀 FLAC UNAVAILABLE - Notify user instead of crashing
              SmartDownloadService.progressNotifier.value = null;
              if (!context.mounted) return;
              showCenterNotification(context,
                  label: AppLocalizations.of(context)!.flacUnavailable,
                  title: song.title,
                  subtitle: AppLocalizations.of(context)!.flacUnavailableDesc,
                  artPath: spotifyArtUrl,
                  onlineArtUrl: spotifyArtUrl,
                  icon: Icons.info_outline_rounded,
                  backgroundColor: Colors.orange.withValues(alpha: 0.85));

              notif.showComplete(
                  id: notifId,
                  title:
                      AppLocalizations.of(context)!.flacUnavailableNotification,
                  body:
                      "${song.title} - ${AppLocalizations.of(context)!.changeFormatInSettings}");

              return; // Stop here, don't fallback silently to avoid confusion
            } catch (e) {
              // FLAC specific error
              debugPrint("FLAC Error: $e");
              // Throw to outer catch to handle generic failure if needed
              // or just handle here. Let's handle here to be specific.
              SmartDownloadService.progressNotifier.value = null;
              showCenterNotification(context,
                  label: AppLocalizations.of(context)!.flacError,
                  title: song.title,
                  subtitle: AppLocalizations.of(context)!.couldNotDownloadFlac,
                  artPath: spotifyArtUrl,
                  onlineArtUrl: spotifyArtUrl,
                  backgroundColor: Colors.red.withValues(alpha: 0.85));

              notif.showComplete(
                  id: notifId,
                  title: AppLocalizations.of(context)!.downloadFailed,
                  body: "${song.title} (FLAC Error)");
              return;
            }
          }

          // 3. YouTube download path (MP3/M4A or FLAC fallback)
          final actualFormat = isFlacRequested ? 'mp3' : preferredFormat;
          final finalTitle = await smartService.generateFilename(meta);
          final outputPath =
              await ytService.getDownloadPath(finalTitle, ext: actualFormat);

          if (outputPath == null) {
            throw Exception("Storage permission denied or path error");
          }

          if (!context.mounted) return;
          showCenterNotification(context,
              label: l10n.downloading,
              title: song.title,
              subtitle: l10n.downloadingFormat(actualFormat),
              artPath: spotifyArtUrl,
              onlineArtUrl: spotifyArtUrl);

          notif.showProgress(
              id: notifId,
              progress: 0,
              max: 100,
              title: l10n.downloadingFormat(actualFormat),
              body: song.title);

          await ytService.startDownloadFromUrl(
            youtubeUrl: youtubeUrl,
            outputFilePath: outputPath,
            audioFormat: actualFormat,
            onProgress: (p) {
              // 🚀 UPDATE SIDEBAR PROGRESS
              SmartDownloadService.progressNotifier.value = DownloadProgress(
                receivedMB: p * 10, // Estimated
                totalMB: 10,
                progress: p,
                status: "${l10n.downloading}: ${song.title}",
                details: "${(p * 100).toInt()}% - $actualFormat",
              );
              // 🚀 NOTIF
              notif.showProgress(
                  id: notifId,
                  progress: (p * 100).toInt(),
                  max: 100,
                  title: AppLocalizations.of(context)!
                      .downloadingFormat(actualFormat),
                  body: song.title);
            },
            onComplete: (success) async {
              SmartDownloadService.progressNotifier.value = null;

              if (success) {
                try {
                  await smartService.tagFile(
                      filePath: outputPath, metadata: meta);
                } catch (e) {
                  debugPrint("Tagging warning: $e");
                }
                if (!context.mounted) return;
                showCenterNotification(context,
                    label: AppLocalizations.of(context)!.downloadComplete,
                    title: song.title,
                    subtitle: AppLocalizations.of(context)!
                        .savedAsFormat(actualFormat),
                    artPath: outputPath,
                    onlineArtUrl: spotifyArtUrl,
                    backgroundColor: Colors.green.withValues(alpha: 0.85));

                notif.showComplete(
                    id: notifId,
                    title: AppLocalizations.of(context)!
                        .downloadCompleteNotification,
                    body: "${song.title} ($actualFormat)");
              } else {
                // Handled by outer catch if we throw? No, onComplete is async callback.
                // We must handle failure here.
                if (!context.mounted) return;
                showCenterNotification(context,
                    label: AppLocalizations.of(context)!.downloadFailed,
                    title: song.title,
                    subtitle: AppLocalizations.of(context)!.downloadError,
                    artPath: spotifyArtUrl,
                    onlineArtUrl: spotifyArtUrl,
                    backgroundColor: Colors.red.withValues(alpha: 0.85));
                notif.cancel(notifId);
              }
            },
          );
        } catch (e) {
          debugPrint("❌ Download Error: $e");
          SmartDownloadService.progressNotifier.value = null;

          if (!context.mounted) return;
          showCenterNotification(context,
              label: AppLocalizations.of(context)!.downloadFailed,
              title: song.title,
              subtitle: e.toString().replaceAll("Exception:", "").trim(),
              onlineArtUrl: song.onlineArtUrl,
              icon: Icons.error_rounded,
              backgroundColor: Colors.red.withValues(alpha: 0.85));

          notif.showComplete(
              id: notifId,
              title: AppLocalizations.of(context)!.downloadFailed,
              body:
                  "${song.title} - ${e.toString().replaceAll("Exception:", "").trim()}");
        }
        break;
    }
  }

  static Future<void> showSongMenu(BuildContext context, Offset offset,
      WidgetRef ref, SongModel song) async {
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
              Text(AppLocalizations.of(context)!.playNext)
            ])),
        PopupMenuItem(
            value: SongAction.addToQueue,
            child: Row(children: [
              const Icon(Icons.queue_music),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.addToQueue)
            ])),
        PopupMenuItem(
            value: SongAction.addToPlaylist,
            child: Row(children: [
              const Icon(Icons.playlist_add),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.addToPlaylist)
            ])),
        PopupMenuItem(
            value: SongAction.addToFavorite,
            child: Row(children: [
              const Icon(Icons.favorite_border),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.addToFavorite)
            ])),
        PopupMenuItem(
            value: SongAction.goToArtist,
            child: Row(children: [
              const Icon(Icons.person_search),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.goToArtist)
            ])),
        PopupMenuItem(
            value: SongAction.download,
            child: Row(children: [
              const Icon(Icons.download_rounded),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.download)
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
          showSongMenu(context, details.globalPosition, ref, song);
        },
        onLongPressStart: (details) {
          // Mobile Long Press
          if (Platform.isAndroid || Platform.isIOS) {
            showSongMenu(context, details.globalPosition, ref, song);
          }
        },
        child: child,
      ),
    );
  }
}
