import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/youtube_downloader_service.dart';
import '../../models/youtube_search_result.dart';
import '../components/smart_art.dart';

import '../../models/song_model.dart';

class VersionSelectionDialog extends ConsumerStatefulWidget {
  final String initialQuery;
  final SongModel song;

  const VersionSelectionDialog(
      {super.key, required this.initialQuery, required this.song});

  @override
  ConsumerState<VersionSelectionDialog> createState() =>
      _VersionSelectionDialogState();
}

class _VersionSelectionDialogState
    extends ConsumerState<VersionSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final YoutubeDownloaderService _downloader = YoutubeDownloaderService();

  List<YoutubeSearchResult> _results = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _performSearch(widget.initialQuery);
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
    });

    try {
      final results = await _downloader.searchVideo(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Search failed: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.switch_video_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text("Select Version",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Search YouTube...",
                hintStyle: TextStyle(color: subtitleColor),
                prefixIcon: Icon(Icons.search, color: subtitleColor),
                suffixIcon: IconButton(
                  icon: Icon(Icons.arrow_forward,
                      color: Theme.of(context).colorScheme.primary),
                  onPressed: () => _performSearch(_searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: isDark ? Colors.black12 : Colors.grey[100],
              ),
              onSubmitted: _performSearch,
            ),
            const SizedBox(height: 16),

            // Results List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red)))
                      : _results.isEmpty
                          ? Center(
                              child: Text("No results found",
                                  style: TextStyle(color: subtitleColor)))
                          : ListView.separated(
                              itemCount: _results.length,
                              separatorBuilder: (ctx, i) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final result = _results[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 4),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: SmartArt(
                                      path: "", // No local path
                                      onlineArtUrl: result.thumbnailUrl,
                                      size: 50,
                                      borderRadius: 4,
                                    ),
                                  ),
                                  title: Text(result.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: textColor, fontSize: 14)),
                                  subtitle: Row(
                                    children: [
                                      Text(result.artist,
                                          style: TextStyle(
                                              color: subtitleColor,
                                              fontSize: 12)),
                                      const SizedBox(width: 8),
                                      Text("•  ${result.duration}",
                                          style: TextStyle(
                                              color: subtitleColor,
                                              fontSize: 12)),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(context, result);
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
