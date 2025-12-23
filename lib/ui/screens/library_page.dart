import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/library_presentation_provider.dart';
import '../../models/song_model.dart';
import '../components/song_card_overlay.dart';
import '../components/song_context_menu.dart';
import '../components/smart_art.dart';

String _formatDuration(double seconds) {
  if (seconds.isNaN || seconds.isInfinite) return "--:--";
  final duration = Duration(seconds: seconds.round());
  final minutes = duration.inMinutes;
  final remainingSeconds = duration.inSeconds % 60;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = p.Provider.of<LibraryProvider>(context);
    final presentationState = ref.watch(libraryPresentationProvider);
    final isGridView = presentationState.isGridView;

    // --- THEME LOGIC ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF212121);
    final surfaceColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    final iconColor = isDark ? Colors.grey : Colors.grey[600];
    final activeIconColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            // HEADER (Shifted Mobile)
            Padding(
              padding: EdgeInsets.only(
                  left: (Platform.isAndroid || Platform.isIOS) ? 40.0 : 0.0),
              child: Text(
                'Local Library',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                      fontSize: 32,
                      letterSpacing: 0.5,
                    ),
              ),
            ),

            const SizedBox(height: 24),

            // CONTROLS ROW
            Row(
              children: [
                // SEARCH BAR
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: iconColor, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: "Search songs...",
                              hintStyle:
                                  TextStyle(color: Colors.grey, fontSize: 15),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(bottom: 4),
                            ),
                            style: TextStyle(color: titleColor, fontSize: 15),
                            cursorColor: Theme.of(context).primaryColor,
                            onChanged: (value) {
                              library.search(value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // SHUFFLE BUTTON
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    tooltip: "Shuffle All",
                    icon: Icon(Icons.shuffle_rounded, color: activeIconColor),
                    onPressed: () {
                      if (library.songs.isNotEmpty) {
                        ref
                            .read(playerProvider.notifier)
                            .playRandom(library.songs);
                      }
                    },
                  ),
                ),

                const SizedBox(width: 12),

                // GRID TOGGLE
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                        isGridView
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        color: activeIconColor,
                        size: 22),
                    tooltip: isGridView
                        ? "Switch to List View"
                        : "Switch to Grid View",
                    onPressed: () {
                      ref
                          .read(libraryPresentationProvider.notifier)
                          .toggleViewMode();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // CONTENT
            Expanded(
              child: _buildBody(
                  context, ref, library, isGridView, isDark, titleColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      LibraryProvider library, bool isGridView, bool isDark, Color textColor) {
    if (library.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: textColor)),
            const SizedBox(height: 20),
            Text("${library.songs.length} songs loaded...",
                style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    if (library.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                library.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 15),
              ),
            ),
            const SizedBox(height: 24),
            if (library.isPermissionDenied)
              ElevatedButton.icon(
                onPressed: () async {
                  await Permission.audio.request();
                  await Permission.storage.request();
                  await Permission.manageExternalStorage.request();
                  library.requestPermissions();
                },
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text("Grant Access"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: library.pickFolder,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text("Select Different Folder"),
              ),
          ],
        ),
      );
    }

    if (library.selectedFolder == null) {
      return Center(
        child: OutlinedButton(
          onPressed: library.pickFolder,
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              foregroundColor: textColor),
          child: const Text("Select Folder"),
        ),
      );
    }

    if (library.songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              "No songs found in this folder.",
              style: TextStyle(color: textColor, fontSize: 16),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: library.pickFolder,
              child: const Text("Select Different Folder"),
            ),
          ],
        ),
      );
    }

    if (isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: library.songs.length,
        itemBuilder: (context, index) {
          return SongGridTile(
            song: library.songs[index],
            allSongs: library.songs,
            isDark: isDark,
          );
        },
      );
    } else {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: library.songs.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return SongListTile(
            song: library.songs[index],
            allSongs: library.songs,
            index: index,
            isDark: isDark,
          );
        },
      );
    }
  }
}

class SongListTile extends ConsumerWidget {
  final SongModel song;
  final List<SongModel> allSongs;
  final int index;
  final bool isDark;

  const SongListTile(
      {super.key,
      required this.song,
      required this.allSongs,
      required this.index,
      required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final isPlaying = playerState.currentSong?.filePath == song.filePath;
    final activeColor = Theme.of(context).primaryColor;

    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final metaColor = isDark ? Colors.grey[600] : Colors.grey[500];

    return SongContextMenuRegion(
      song: song,
      currentQueue: allSongs,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => notifier.playSong(song, newQueue: allSongs),
          borderRadius: BorderRadius.circular(8),
          hoverColor: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    "${index + 1}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: isPlaying ? activeColor : metaColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                SongCardOverlay(
                  song: song,
                  size: 56,
                  radius: 6,
                  playQueue: allSongs,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isPlaying ? activeColor : titleColor)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Text(song.album,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style:
                                    TextStyle(fontSize: 13, color: metaColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: subtitleColor)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(_formatDuration(song.duration),
                    style: TextStyle(
                        fontSize: 13,
                        color: metaColor,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(width: 16),
                Icon(Icons.more_vert_rounded, color: metaColor, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SongGridTile extends ConsumerWidget {
  final SongModel song;
  final List<SongModel> allSongs;
  final bool isDark;

  const SongGridTile(
      {super.key,
      required this.song,
      required this.allSongs,
      required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final isPlaying = playerState.currentSong?.filePath == song.filePath;
    final activeColor = Theme.of(context).primaryColor;

    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF212121);
    final artistColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return SongContextMenuRegion(
      song: song,
      currentQueue: allSongs,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => notifier.playSong(song, newQueue: allSongs),
          borderRadius: BorderRadius.circular(12),
          hoverColor: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: isPlaying
                  ? Border.all(color: activeColor.withOpacity(0.5), width: 2)
                  : null,
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: Hero(
                      tag: 'art_grid_${song.filePath}',
                      child: SmartArt(
                          path: song.filePath,
                          size: 200,
                          borderRadius: 8,
                          onlineArtUrl: song.onlineArtUrl),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isPlaying ? activeColor : titleColor)),
                const SizedBox(height: 4),
                Text(song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: artistColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
