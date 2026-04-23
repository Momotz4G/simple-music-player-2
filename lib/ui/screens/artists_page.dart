import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/library_presentation_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../services/spotify_service.dart';
import '../../services/deezer_service.dart';
import '../../services/db_service.dart';
import '../../l10n/app_localizations.dart';

class ArtistsPage extends ConsumerWidget {
  const ArtistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryProviderInstance = ref.watch(libraryProvider);
    final groupedArtists = ref.watch(groupedArtistsProvider);

    // 1. Loading State (from library provider)
    if (libraryProviderInstance.isLoading && groupedArtists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Empty State
    if (groupedArtists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music,
                size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              libraryProviderInstance.selectedFolder == null
                  ? AppLocalizations.of(context)!.libraryNotLoaded
                  : AppLocalizations.of(context)!.noArtistsFound,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.goToLocalLibraryToSelect,
              style: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.7), fontSize: 14),
            ),
          ],
        ),
      );
    }

    // 3. The Grid
    // 🚀 Note: Sorting is now handled synchronously for instant feedback
    final artists = groupedArtists.keys.toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.8,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: artists.length,
        itemBuilder: (context, index) {
          final artistName = artists[index];
          final artistSongs = groupedArtists[artistName]!;
          final songCount = artistSongs.length;
          final anchorSong =
              artistSongs.isNotEmpty ? artistSongs.first : null;

          return InkWell(
            onTap: () {
              ref.read(navigationStackProvider.notifier).push(
                    NavigationItem(
                      type: NavigationType.artist,
                      data: ArtistSelection(
                        artistName: artistName,
                        songs: artistSongs,
                      ),
                    ),
                  );
            },
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ArtistAvatar(
                      artistName: artistName,
                      sampleTrack: anchorSong?.title,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$songCount ${AppLocalizations.of(context)!.songs}",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ArtistAvatar extends ConsumerStatefulWidget {
  final String artistName;
  final String? sampleTrack;

  const ArtistAvatar({super.key, required this.artistName, this.sampleTrack});

  @override
  ConsumerState<ArtistAvatar> createState() => _ArtistAvatarState();
}

class _ArtistAvatarState extends ConsumerState<ArtistAvatar> {
  String? _cachedArtUrl;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    try {
      final cached = await DBService().getArtCache("profile:${widget.artistName}");
      if (cached != null && cached.isNotEmpty && mounted) {
        setState(() => _cachedArtUrl = cached);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 Check Spotify then Deezer for artist art if local is missing
    final spotifyArt = ref.watch(spotifyArtistArtProvider(widget.artistName));
    final deezerArt = ref.watch(deezerArtistArtProvider(widget.artistName));

    final artUrl = _cachedArtUrl ?? spotifyArt.value ?? deezerArt.value;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.withValues(alpha: 0.1),
        image: artUrl != null
            ? DecorationImage(
                image: NetworkImage(artUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: artUrl == null
          ? Center(
              child: Icon(
                Icons.person_rounded,
                size: 48,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
            )
          : null,
    );
  }
}
