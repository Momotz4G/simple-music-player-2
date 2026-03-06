import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/daily_mix_model.dart';
import '../../models/song_model.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../l10n/app_localizations.dart';

/// Displays Daily Mix playlist cards in a horizontal scroll
class DailyMixSection extends ConsumerWidget {
  final List<DailyMix> mixes;
  final Function(bool)? onScrollFocus;

  const DailyMixSection({
    super.key,
    required this.mixes,
    this.onScrollFocus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (mixes.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: Text(
            l10n.madeForYou,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: Listener(
            onPointerDown: (_) => onScrollFocus?.call(true),
            onPointerUp: (_) => onScrollFocus?.call(false),
            onPointerCancel: (_) => onScrollFocus?.call(false),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: mixes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final mix = mixes[index];
                return _DailyMixCard(mix: mix);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyMixCard extends ConsumerWidget {
  final DailyMix mix;

  const _DailyMixCard({required this.mix});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get first 4 album art URLs for collage
    final artUrls = mix.songs
        .take(4)
        .map((s) => s.albumArtUrl)
        .where((url) => url.isNotEmpty)
        .toList();

    return GestureDetector(
      onTap: () => _openDetail(ref),
      onLongPress: () => _showSaveDialog(context, ref),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Collage Art
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildCollageArt(artUrls),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                mix.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),

              // Song count
              Text(
                AppLocalizations.of(context)!.countSongs(mix.songs.length),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollageArt(List<String> artUrls) {
    if (artUrls.isEmpty) {
      return Container(
        color: Colors.grey[800],
        child: const Icon(Icons.music_note, size: 48, color: Colors.white54),
      );
    }

    if (artUrls.length == 1) {
      return Image.network(artUrls[0], fit: BoxFit.cover);
    }

    // 2x2 Collage
    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(4, (i) {
        final url = artUrls[i % artUrls.length];
        return Image.network(url, fit: BoxFit.cover);
      }),
    );
  }

  void _openDetail(WidgetRef ref) {
    ref.read(navigationStackProvider.notifier).push(
          NavigationItem(type: NavigationType.dailyMix, data: mix),
        );
  }

  void _showSaveDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.savePlaylistTitle(mix.title)),
        content: Text(l10n.savePlaylistContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveAsPlaylist(ref, context);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _saveAsPlaylist(WidgetRef ref, BuildContext context) {
    final songs = mix.songs
        .map((meta) => SongModel(
              title: meta.title,
              artist: meta.artist,
              album: meta.album,
              filePath: '',
              duration: meta.durationSeconds.toDouble(),
              fileExtension: '.mp3',
              onlineArtUrl: meta.albumArtUrl,
              spotifyId: meta.spotifyId,
              isrc: meta.isrc,
            ))
        .toList();

    // Add date to make unique (e.g. "Daily Mix 1 - Dec 27")
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final playlistName = "${mix.title} - ${months[now.month - 1]} ${now.day}";

    // Create playlist first
    ref.read(playlistProvider.notifier).createPlaylist(playlistName);

    // Get the newly created playlist (it will be the last one)
    final playlists = ref.read(playlistProvider);
    final newPlaylist = playlists.lastWhere((p) => p.name == playlistName);

    // Add all songs to it
    ref
        .read(playlistProvider.notifier)
        .addSongsToPlaylist(newPlaylist.id, songs);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)!.savedAs(playlistName))),
    );
  }
}
