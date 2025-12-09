import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import '../../models/song_model.dart';
import '../../services/spotify_service.dart';

class AlbumCard extends StatefulWidget {
  final String albumName;
  final String artistName;
  final List<SongModel> songs;
  final VoidCallback onTap;
  final String? imageUrl;
  final String year;

  const AlbumCard({
    super.key,
    required this.albumName,
    required this.artistName,
    required this.songs,
    required this.onTap,
    this.imageUrl,
    required this.year,
  });

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard>
    with AutomaticKeepAliveClientMixin {
  Uint8List? _localBytes;
  String? _networkUrl;
  bool _isLoading = true;
  bool _isHovered = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAlbumArt();
  }

  Future<void> _loadAlbumArt() async {
    // 0. Use provided Image URL (Priority)
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _networkUrl = widget.imageUrl;
          _isLoading = false;
        });
      }
      return;
    }

    if (widget.songs.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 1. Try Local Metadata (from first song)
    try {
      final firstSongPath = widget.songs.first.filePath;
      final file = File(firstSongPath);
      if (await file.exists()) {
        final metadata = await MetadataGod.readMetadata(file: firstSongPath);
        if (metadata.picture != null) {
          if (mounted) {
            setState(() {
              _localBytes = metadata.picture!.data;
              _isLoading = false;
            });
          }
          return; // Found local, done.
        }
      }
    } catch (e) {
      // Ignore local read error
    }

    // 2. Try Spotify Fallback
    try {
      final query = "${widget.albumName} ${widget.artistName}";
      final albums = await SpotifyService.searchAlbums(query);

      if (albums.isNotEmpty) {
        if (albums.first.imageUrl.isNotEmpty) {
          if (mounted) {
            setState(() {
              _networkUrl = albums.first.imageUrl;
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      // Ignore network error
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Art Container
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(_isHovered ? 0.3 : 0.1),
                        blurRadius: _isHovered ? 12 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildImage(),
                ),
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                widget.albumName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _isHovered ? primaryColor : textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              // Artist • Year
              Text(
                "${widget.artistName} • ${widget.year}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_localBytes != null) {
      return Image.memory(_localBytes!, fit: BoxFit.cover);
    }

    if (_networkUrl != null) {
      return Image.network(
        _networkUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.withOpacity(0.1),
      child: Icon(
        Icons.album,
        color: Colors.grey.withOpacity(0.3),
        size: 48,
      ),
    );
  }
}
