import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../data/schemas.dart'; // Required for HistoryEntry
import '../../providers/history_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/smart_download_service.dart';
import '../../models/song_model.dart';
import '../../models/song_metadata.dart';
import '../../models/youtube_search_result.dart';
import '../components/smart_art.dart';
import '../components/music_notification.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final SmartDownloadService _smartService = SmartDownloadService();
  bool _isRestoring = false;

  // 🚀 SMART PLAY FUNCTION
  // Handles playing local files OR restoring deleted cached files
  Future<void> _handleSongTap(HistoryEntry entry) async {
    if (_isRestoring) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final file = File(entry.originalFilePath);

    // CASE 1: File still exists (Local or Cached) -> PLAY
    if (await file.exists()) {
      final song = SongModel(
        title: entry.title,
        artist: entry.artist,
        album: entry.album,
        filePath: entry.originalFilePath,
        duration: entry.duration,
        fileExtension: '.mp3',
        sourceUrl: entry.youtubeUrl,
        onlineArtUrl: entry.albumArtUrl,
      );
      ref.read(playerProvider.notifier).playSong(song);
      return;
    }

    // CASE 2: File Deleted/Cleared (Restore Logic)
    if (entry.youtubeUrl.isEmpty) {
      if (mounted) {
        // 🚀 FIX: Perform Just-In-Time Search if URL is missing
        showCenterNotification(context,
            label: l10n.searchingStatus,
            title: entry.title,
            subtitle: l10n.findingStream,
            artPath: entry.albumArtUrl,
            onlineArtUrl: entry.albumArtUrl);
      }

      try {
        final meta = SongMetadata(
          title: entry.title,
          artist: entry.artist,
          album: entry.album,
          year: "",
          genre: "",
          durationSeconds: entry.duration.toInt(),
          albumArtUrl: entry.albumArtUrl,
        );

        final match = await _smartService.searchYouTubeForMatch(meta);

        if (match != null && match.youtubeMatches.isNotEmpty) {
          final bestMatch = match.youtubeMatches.first;

          // Update the entry with the found URL
          entry.youtubeUrl = bestMatch.url;
          if (entry.albumArtUrl.isEmpty) {
            entry.albumArtUrl = bestMatch.thumbnailUrl;
          }

          // Save back to DB so we don't have to search again
          await ref.read(historyProvider.notifier).updateHistoryEntry(entry);
        } else {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.noStreamMatch)),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint("Search failed: $e");
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.errorSearchingStream)),
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() => _isRestoring = true);
      showCenterNotification(context,
          label: l10n.restoring,
          title: entry.title,
          subtitle: l10n.rebufferingFromCloud,
          artPath: entry.albumArtUrl,
          onlineArtUrl: entry.albumArtUrl);
    }

    try {
      // Reconstruct Metadata object
      final meta = SongMetadata(
        title: entry.title,
        artist: entry.artist,
        album: entry.album,
        year: "", // Not critical for simple playback
        genre: "",
        durationSeconds: entry.duration.toInt(),
        albumArtUrl: entry.albumArtUrl,
      );

      // Reconstruct YouTube Result object
      final ytResult = YoutubeSearchResult(
        title: entry.title,
        artist: entry.artist,
        duration: "",
        url: entry.youtubeUrl, // The key to getting it back!
        thumbnailUrl: entry.albumArtUrl,
      );

      // Re-Download and Play
      final streamingQuality = ref.read(settingsProvider).streamingQuality;
      final song = await _smartService.cacheAndPlay(
        video: ytResult,
        metadata: meta,
        onProgress: (_) {},
        streamingQuality: streamingQuality,
      );

      if (song != null) {
        ref.read(playerProvider.notifier).playSong(song);
      }
    } catch (e) {
      debugPrint("Restore failed: $e");
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyEntries = ref.watch(historyProvider);
    final historyNotifier = ref.read(historyProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // --- HEADER ---
          SliverAppBar(
            pinned: true,
            expandedHeight: 120.0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                AppLocalizations.of(context)!.recentlyPlayed,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            ),
            actions: [
              if (historyEntries.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.redAccent,
                  tooltip: AppLocalizations.of(context)!.clearHistory,
                  onPressed: () => historyNotifier.clearHistory(),
                ),
              const SizedBox(width: 8),
            ],
          ),

          // --- LIST ---
          if (historyEntries.isEmpty)
            SliverFillRemaining(
              child: Center(
                  child: Text(AppLocalizations.of(context)!.noHistoryYet,
                      style: TextStyle(color: subTextColor))),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final entry = historyEntries[index];
                final fileExists = File(entry.originalFilePath).existsSync();

                // 🚀 CHECK FOR VALID ONLINE ART URL
                final bool hasOnlineArt = entry.albumArtUrl.isNotEmpty;

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

                  // 🚀 SMART ART FALLBACK LOGIC
                  // 1. If file exists -> Load from disk (SmartArt)
                  // 2. If file missing but URL exists -> Load from Network
                  // 3. Else -> Placeholder
                  leading: fileExists
                      ? SmartArt(
                          path: entry.originalFilePath,
                          size: 48,
                          borderRadius: 4,
                          onlineArtUrl: entry.albumArtUrl)
                      : (hasOnlineArt
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                entry.albumArtUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[900],
                                    child: const Icon(Icons.music_note,
                                        color: Colors.white24)),
                              ),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Icon(Icons.music_note,
                                  color: Colors.white24))),

                  title: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: textColor),
                  ),
                  subtitle: Row(
                    children: [
                      // 🚀 VISUAL STATUS BADGES
                      if (!fileExists)
                        Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4)),
                            child: Row(
                              children: [
                                const Icon(Icons.cloud_download,
                                    size: 10, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(AppLocalizations.of(context)!.cloud,
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold))
                              ],
                            ))
                      else if (entry.isStream)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(AppLocalizations.of(context)!.cached,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: accentColor,
                                  fontWeight: FontWeight.bold)),
                        ),

                      Expanded(
                        child: Text(
                          entry.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: subTextColor),
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.play_circle_outline,
                      size: 24, color: accentColor.withValues(alpha: 0.7)),
                  onTap: () => _handleSongTap(entry),
                );
              }, childCount: historyEntries.length),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
