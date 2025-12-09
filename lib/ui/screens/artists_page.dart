import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/library_presentation_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../services/spotify_service.dart';

class ArtistsPage extends ConsumerWidget {
  const ArtistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryProviderInstance = ref.watch(libraryProvider);
    final groupedArtists = ref.watch(groupedArtistsProvider);

    // 1. Loading State
    if (libraryProviderInstance.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Empty State
    if (groupedArtists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music,
                size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              libraryProviderInstance.selectedFolder == null
                  ? 'Library not loaded.'
                  : 'No artists found.',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Go to 'Local Library' to select your music folder.",
              style:
                  TextStyle(color: Colors.grey.withOpacity(0.7), fontSize: 14),
            ),
          ],
        ),
      );
    }

    // 3. The Grid
    final artists = groupedArtists.keys.toList();
    artists.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.8, // Slightly taller for the name text
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: artists.length,
        itemBuilder: (context, index) {
          final artistName = artists[index];
          final artistSongs = groupedArtists[artistName]!;
          final songCount = artistSongs.length;

          // Grab a sample song to help Spotify find the correct artist ID
          final anchorSong = artistSongs.isNotEmpty ? artistSongs.first : null;

          return InkWell(
            onTap: () {
              // 🚀 FIX: Use Provider Navigation instead of Push
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
                // 🚀 SMART AVATAR WIDGET
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ArtistAvatar(
                      artistName: artistName,
                      sampleTrack:
                          anchorSong?.title, // Pass title for verification
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  artistName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  songCount == 1 ? '1 Song' : '$songCount Songs',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
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

// ARTIST AVATAR WIDGET
// Handles fetching, caching, and displaying Spotify Images
class ArtistAvatar extends StatefulWidget {
  final String artistName;
  final String? sampleTrack; // Used to anchor the search to the correct artist

  const ArtistAvatar({
    super.key,
    required this.artistName,
    this.sampleTrack,
  });

  @override
  State<ArtistAvatar> createState() => _ArtistAvatarState();
}

class _ArtistAvatarState extends State<ArtistAvatar> {
  // Static cache to prevent re-fetching the same URL when scrolling
  static final Map<String, String?> _urlCache = {};

  String? _imageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  Future<void> _fetchImage() async {
    // 1. Check Memory Cache first
    if (_urlCache.containsKey(widget.artistName)) {
      if (mounted) {
        setState(() {
          _imageUrl = _urlCache[widget.artistName];
          _isLoading = false;
        });
      }
      return;
    }

    // RATE LIMIT FIX:
    // Add a tiny random delay (0-500ms) before requesting.
    // This prevents firing 50 requests at the exact same millisecond when the page opens.
    await Future.delayed(
        Duration(milliseconds: (widget.artistName.hashCode % 500)));

    // 2. Fetch from Spotify API (Deep Search)
    try {
      final url = await SpotifyService.getArtistImage(
        artistName: widget.artistName,
        trackTitle: widget.sampleTrack, // DEEP SEARCH ENABLED
      );

      // Update Cache
      _urlCache[widget.artistName] = url;

      if (mounted) {
        setState(() {
          _imageUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      // On error, cache null so we don't retry endlessly
      _urlCache[widget.artistName] = null;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.grey[850] : Colors.grey[200],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: _buildContent(isDark),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      // Show small loading spinner inside the circle
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return Image.network(
        _imageUrl!,
        fit: BoxFit.cover,
        // 🚀 MEMORY FIX: Force decoding to small size (thumbnail)
        cacheWidth: 200,
        errorBuilder: (c, e, s) => _buildPlaceholder(isDark),
      );
    }

    return _buildPlaceholder(isDark);
  }

  Widget _buildPlaceholder(bool isDark) {
    return Icon(
      Icons.person,
      size: 60,
      color: isDark ? Colors.grey[700] : Colors.grey[400],
    );
  }
}
