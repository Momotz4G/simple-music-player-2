import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/spotify_service.dart';
import '../../models/song_metadata.dart';
import '../../models/album_model.dart';
import '../../models/artist_model.dart';
import '../../providers/search_bridge_provider.dart';
import '../../providers/library_presentation_provider.dart';
import '../screens/album_detail_page.dart';

class TopSearchBar extends ConsumerStatefulWidget {
  const TopSearchBar({super.key});

  @override
  ConsumerState<TopSearchBar> createState() => _TopSearchBarState();
}

class _TopSearchBarState extends ConsumerState<TopSearchBar> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _debounce;

  // Store both songs and albums
  List<SongMetadata> _songSuggestions = [];
  List<AlbumModel> _albumSuggestions = [];
  List<ArtistModel> _artistSuggestions = [];

  bool _isLoading = false;
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _showOverlay();
      } else {
        // Small delay to allow tap events on the list to register
        Future.delayed(const Duration(milliseconds: 200), _removeOverlay);
      }
    });

    // Listen to controller changes to toggle clear button
    _controller.addListener(() {
      setState(() {
        _showClearButton = _controller.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.dispose();
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- SEARCH LOGIC ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          _songSuggestions = [];
          _albumSuggestions = [];
          _artistSuggestions = [];
        });
        _overlayEntry?.markNeedsBuild();
        return;
      }

      setState(() => _isLoading = true);
      _overlayEntry?.markNeedsBuild();

      try {
        // Fetch both Songs and Albums
        final results = await SpotifyService.searchAll(query, limit: 5);

        if (mounted) {
          setState(() {
            _songSuggestions = results['songs'] as List<SongMetadata>;
            _albumSuggestions = results['albums'] as List<AlbumModel>;
            _artistSuggestions = results['artists'] as List<ArtistModel>;
            _isLoading = false;
          });
          _overlayEntry?.markNeedsBuild();
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  // --- SELECTION LOGIC ---

  void _onSongSelected(SongMetadata song) {
    _controller.clear();
    _focusNode.unfocus();
    _removeOverlay();

    // Navigate to Track Detail Page (NEW)
    ref.read(navigationStackProvider.notifier).push(
          NavigationItem(type: NavigationType.track, data: song),
        );
  }

  void _onAlbumSelected(AlbumModel album) {
    _controller.clear();
    _focusNode.unfocus();
    _removeOverlay();

    // Navigate to Album Detail Page
    ref.read(navigationStackProvider.notifier).push(
          NavigationItem(type: NavigationType.album, data: album),
        );
  }

  void _onArtistSelected(ArtistModel artist) {
    _controller.clear();
    _focusNode.unfocus();
    _removeOverlay();

    // Navigate to Artist Detail Page
    ref.read(navigationStackProvider.notifier).push(
          NavigationItem(
            type: NavigationType.artist,
            data: ArtistSelection(artistName: artist.name),
          ),
        );
  }

  // --- OVERLAY LOGIC ---

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 8.0),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).cardColor,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  maxHeight: 400), // Increased height for both lists
              child: _buildOverlayContent(),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildOverlayContent() {
    if (_isLoading) {
      return const SizedBox(
          height: 60, child: Center(child: CircularProgressIndicator()));
    }
    if (_songSuggestions.isEmpty &&
        _albumSuggestions.isEmpty &&
        _artistSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        // --- SONGS SECTION ---
        if (_songSuggestions.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text("Songs",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1)),
          ),
          ..._songSuggestions.map((song) => ListTile(
                dense: true,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(song.albumArtUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) =>
                          Container(color: Colors.grey, width: 40, height: 40)),
                ),
                title: Text(song.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(song.artist,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => _onSongSelected(song),
              )),
        ],

        // --- ALBUMS SECTION ---
        if (_albumSuggestions.isNotEmpty) ...[
          if (_songSuggestions.isNotEmpty)
            const Divider(height: 1), // Separator
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text("Albums",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1)),
          ),
          ..._albumSuggestions.map((album) => ListTile(
                dense: true,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(album.imageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) =>
                          Container(color: Colors.grey, width: 40, height: 40)),
                ),
                title: Text(album.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Row(
                  children: [
                    Expanded(
                        child: Text(album.artist,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text("ALBUM",
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey)),
                    )
                  ],
                ),
                onTap: () => _onAlbumSelected(album),
              )),
        ],

        // --- ARTISTS SECTION ---
        if (_artistSuggestions.isNotEmpty) ...[
          if (_songSuggestions.isNotEmpty || _albumSuggestions.isNotEmpty)
            const Divider(height: 1), // Separator
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text("Artists",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1)),
          ),
          ..._artistSuggestions.map((artist) => ListTile(
                dense: true,
                leading: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(20), // Circular for artists
                  child: Image.network(artist.imageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) =>
                          Container(color: Colors.grey, width: 40, height: 40)),
                ),
                title: Text(artist.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: const Text("Artist",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () => _onArtistSelected(artist),
              )),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // --- BUILD ---
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        width: 400, // Fixed width for center bar
        height: 32, // Slightly taller for better touch area
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(
              fontSize: 13, color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: "Search Songs or Albums...",
            hintStyle: TextStyle(
                fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
            prefixIcon: Icon(Icons.search,
                size: 18, color: isDark ? Colors.white54 : Colors.black54),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 1.5),
            ),
            // Clear Button
            suffixIcon: _showClearButton
                ? IconButton(
                    icon: Icon(Icons.close,
                        size: 16,
                        color: isDark ? Colors.white54 : Colors.black54),
                    onPressed: () {
                      _controller.clear();
                      _onSearchChanged(''); // Manually trigger clear
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
