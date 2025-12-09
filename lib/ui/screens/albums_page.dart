import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/grouped_albums_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../models/album_model.dart';
import '../components/album_card.dart';

class AlbumsPage extends ConsumerWidget {
  const AlbumsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAlbums = ref.watch(groupedAlbumsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    if (groupedAlbums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.album_outlined,
                size: 64, color: textColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              "No albums found",
              style: TextStyle(
                color: textColor.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: CustomScrollView(
        key: const PageStorageKey(
            'albums_page_scroll'), // Preserve Scroll Position
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 16),
              child: Text(
                "Albums",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: -1.0,
                ),
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final albumName = groupedAlbums.keys.elementAt(index);
                final songs = groupedAlbums[albumName]!;
                final artistName =
                    songs.isNotEmpty ? songs.first.artist : "Unknown Artist";

                return AlbumCard(
                  albumName: albumName,
                  artistName: artistName,
                  songs: songs,
                  year: "Unknown", // Placeholder for local albums
                  onTap: () {
                    // Create a local AlbumModel
                    final album = AlbumModel(
                      id: "local_$albumName", // Dummy ID for local
                      title: albumName,
                      artist: artistName,
                      imageUrl: "", // Detail page will fetch/find it
                      releaseDate: "2023",
                      localSongs: songs, // PASS LOCAL SONGS
                    );

                    // Navigate
                    ref.read(navigationStackProvider.notifier).push(
                          NavigationItem(
                              type: NavigationType.album, data: album),
                        );
                  },
                );
              },
              childCount: groupedAlbums.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }
}
