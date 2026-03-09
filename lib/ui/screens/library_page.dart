import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p_path;

import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/library_presentation_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../models/song_model.dart';
import '../../models/album_model.dart';
import '../../providers/settings_provider.dart';
import '../components/song_card_overlay.dart';
import '../components/song_context_menu.dart';
import '../components/smart_art.dart';
import '../components/album_card.dart';
import '../../l10n/app_localizations.dart';

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

    final settings = ref.watch(settingsProvider);
    final hasTheme = settings.atmosphereTheme != AtmosphereTheme.none;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF212121);
    final surfaceColor = hasTheme
        ? (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05))
        : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5));
    final iconColor = isDark ? Colors.grey : Colors.grey[600];
    final activeIconColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 12),

            // HEADER
            Padding(
              padding: EdgeInsets.only(
                  left: (Platform.isAndroid || Platform.isIOS) ? 72.0 : 0.0),
              child: Text(
                AppLocalizations.of(context)!.local_library,
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
                            decoration: InputDecoration(
                              hintText:
                                  AppLocalizations.of(context)!.searchSongs,
                              hintStyle: const TextStyle(
                                  color: Colors.grey, fontSize: 15),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(bottom: 4),
                            ),
                            style: TextStyle(color: titleColor, fontSize: 15),
                            cursorColor: Theme.of(context).primaryColor,
                            onChanged: (value) => library.search(value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // REFRESH BUTTON
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    tooltip: AppLocalizations.of(context)!.refreshLibrary,
                    icon: Icon(Icons.refresh_rounded, color: activeIconColor),
                    onPressed: () => library.refreshLibrary(),
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
                    tooltip: AppLocalizations.of(context)!.shuffleAll,
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
                        ? AppLocalizations.of(context)!.switchToListView
                        : AppLocalizations.of(context)!.switchToGridView,
                    onPressed: () => ref
                        .read(libraryPresentationProvider.notifier)
                        .toggleViewMode(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // FILTER TABS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: AppLocalizations.of(context)!.songs,
                    isSelected:
                        presentationState.currentFilter == LibraryFilter.songs,
                    onTap: () => ref
                        .read(libraryPresentationProvider.notifier)
                        .setFilter(LibraryFilter.songs),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: AppLocalizations.of(context)!.folders,
                    isSelected: presentationState.currentFilter ==
                        LibraryFilter.folders,
                    onTap: () => ref
                        .read(libraryPresentationProvider.notifier)
                        .setFilter(LibraryFilter.folders),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: AppLocalizations.of(context)!.artists,
                    isSelected: presentationState.currentFilter ==
                        LibraryFilter.artists,
                    onTap: () => ref
                        .read(libraryPresentationProvider.notifier)
                        .setFilter(LibraryFilter.artists),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: AppLocalizations.of(context)!.albums,
                    isSelected:
                        presentationState.currentFilter == LibraryFilter.albums,
                    onTap: () => ref
                        .read(libraryPresentationProvider.notifier)
                        .setFilter(LibraryFilter.albums),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // CONTENT
            Expanded(
              child: _buildBody(context, ref, library, presentationState,
                  isGridView, isDark, titleColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      WidgetRef ref,
      LibraryProvider library,
      LibraryPresentationState presentationState,
      bool isGridView,
      bool isDark,
      Color textColor) {
    // 🚀 IMPROVED LOADING LOGIC:
    // Only show the big spinner if we have NO songs yet.
    // If we have songs, let the user browse even if it's "loading" in the background.
    if (library.isLoading && library.songs.isEmpty) {
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
            Text(
                AppLocalizations.of(context)!
                    .songsLoadedCount(library.songs.length),
                style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    if (library.error != null) {
      return _buildError(context, library, textColor);
    }

    if (library.selectedFolder == null) {
      return _buildNoFolder(context, library, textColor);
    }

    switch (presentationState.currentFilter) {
      case LibraryFilter.folders:
        return _buildFoldersView(context, ref, textColor);
      case LibraryFilter.artists:
        return _buildArtistsView(context, ref, textColor);
      case LibraryFilter.albums:
        return _buildAlbumsView(context, ref, textColor);
      case LibraryFilter.songs:
        return _buildSongsView(context, ref, library, presentationState,
            isGridView, isDark, textColor);
    }
  }

  Widget _buildSongsView(
      BuildContext context,
      WidgetRef ref,
      LibraryProvider library,
      LibraryPresentationState presentationState,
      bool isGridView,
      bool isDark,
      Color textColor) {
    List<SongModel> displaySongs = library.songs;

    if (presentationState.selectedFolderPath != null) {
      final groupedFolders = ref.watch(groupedFoldersProvider);
      displaySongs =
          groupedFolders[presentationState.selectedFolderPath!] ?? [];
    }

    if (displaySongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              presentationState.selectedFolderPath != null
                  ? "No songs in folder '${p_path.basename(presentationState.selectedFolderPath!)}'"
                  : AppLocalizations.of(context)!.noSongsInFolder,
              style: TextStyle(color: textColor, fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (presentationState.selectedFolderPath != null)
              OutlinedButton(
                onPressed: () => ref
                    .read(libraryPresentationProvider.notifier)
                    .clearFolderFilter(),
                child: const Text("Show All Songs"),
              )
            else
              OutlinedButton(
                onPressed: library.pickFolder,
                child:
                    Text(AppLocalizations.of(context)!.selectDifferentFolder),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (presentationState.selectedFolderPath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(Icons.folder_open_rounded,
                    color: textColor.withValues(alpha: 0.5), size: 20),
                const SizedBox(width: 8),
                Text(
                  p_path.basename(presentationState.selectedFolderPath!),
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => ref
                      .read(libraryPresentationProvider.notifier)
                      .clearFolderFilter(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text("Clear Filter"),
                ),
              ],
            ),
          ),
        Expanded(
          child: isGridView
              ? GridView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: displaySongs.length,
                  itemBuilder: (context, index) => SongGridTile(
                    song: displaySongs[index],
                    allSongs: displaySongs,
                    isDark: isDark,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: displaySongs.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => SongListTile(
                    song: displaySongs[index],
                    allSongs: displaySongs,
                    index: index,
                    isDark: isDark,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFoldersView(
      BuildContext context, WidgetRef ref, Color textColor) {
    final groupedFolders = ref.watch(groupedFoldersProvider);

    if (groupedFolders.isEmpty) {
      return Center(
          child: Text("No folders found", style: TextStyle(color: textColor)));
    }

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: groupedFolders.length,
      itemBuilder: (context, index) {
        final folderPath = groupedFolders.keys.elementAt(index);
        final folderName = p_path.basename(folderPath);
        final songs = groupedFolders[folderPath]!;

        return AlbumCard(
          albumName: folderName,
          artistName: "${songs.length} songs",
          songs: songs,
          year: "",
          onTap: () => ref
              .read(libraryPresentationProvider.notifier)
              .selectFolder(folderPath),
        );
      },
    );
  }

  Widget _buildArtistsView(
      BuildContext context, WidgetRef ref, Color textColor) {
    final groupedArtists = ref.watch(groupedArtistsProvider);

    if (groupedArtists.isEmpty) {
      return Center(
          child: Text("No artists found", style: TextStyle(color: textColor)));
    }

    final artists = groupedArtists.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 120),
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

        return AlbumCard(
          albumName: artistName,
          artistName: "${artistSongs.length} songs",
          songs: artistSongs,
          year: "",
          onTap: () {
            ref.read(navigationStackProvider.notifier).push(
                  NavigationItem(
                    type: NavigationType.artist,
                    data: ArtistSelection(
                        artistName: artistName, songs: artistSongs),
                  ),
                );
          },
        );
      },
    );
  }

  Widget _buildAlbumsView(
      BuildContext context, WidgetRef ref, Color textColor) {
    final groupedAlbums = ref.watch(groupedAlbumsProvider);

    if (groupedAlbums.isEmpty) {
      return Center(
          child: Text("No albums found", style: TextStyle(color: textColor)));
    }

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: groupedAlbums.length,
      itemBuilder: (context, index) {
        final albumName = groupedAlbums.keys.elementAt(index);
        final songs = groupedAlbums[albumName]!;
        final artistName =
            songs.isNotEmpty ? songs.first.artist : "Unknown Artist";
        final year = songs
                .firstWhere((s) => s.year != null && s.year!.isNotEmpty,
                    orElse: () => songs.first)
                .year ??
            "Unknown";

        return AlbumCard(
          albumName: albumName,
          artistName: artistName,
          songs: songs,
          year: year,
          onTap: () {
            final album = AlbumModel(
              id: "local_$albumName",
              title: albumName,
              artist: artistName,
              imageUrl: "",
              releaseDate: year,
              localSongs: songs,
            );
            ref.read(navigationStackProvider.notifier).push(
                  NavigationItem(type: NavigationType.album, data: album),
                );
          },
        );
      },
    );
  }

  Widget _buildError(
      BuildContext context, LibraryProvider library, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.redAccent),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(library.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 15)),
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
              label: Text(AppLocalizations.of(context)!.grantAccess),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white),
            )
          else
            OutlinedButton.icon(
              onPressed: library.pickFolder,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(AppLocalizations.of(context)!.selectDifferentFolder),
            ),
        ],
      ),
    );
  }

  Widget _buildNoFolder(
      BuildContext context, LibraryProvider library, Color textColor) {
    return Center(
      child: OutlinedButton(
        onPressed: library.pickFolder,
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.grey),
            foregroundColor: textColor),
        child: Text(AppLocalizations.of(context)!.selectFolder),
      ),
    );
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
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text("${index + 1}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: isPlaying ? activeColor : metaColor,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                SongCardOverlay(
                    song: song, size: 56, radius: 6, playQueue: allSongs),
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

    final settings = ref.watch(settingsProvider);
    final hasTheme = settings.atmosphereTheme != AtmosphereTheme.none;

    final cardBg = hasTheme
        ? (isDark
            ? Colors.black.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.15))
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);

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
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: isPlaying
                  ? Border.all(
                      color: activeColor.withValues(alpha: 0.5), width: 2)
                  : (hasTheme
                      ? Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05))
                      : null),
              boxShadow: [
                if (!isDark && !hasTheme)
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _FilterChip(
      {required this.label,
      required this.isSelected,
      required this.onTap,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).primaryColor;
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: isSelected ? activeColor : surfaceColor,
            borderRadius: BorderRadius.circular(20)),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
