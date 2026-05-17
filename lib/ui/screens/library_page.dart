import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p_path;
import '../../utils/folder_picker.dart';

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
import '../../utils/layout_engine.dart';
import '../../l10n/app_localizations.dart';

String _formatDuration(double seconds) {
  if (seconds.isNaN || seconds.isInfinite) return "--:--";
  final duration = Duration(seconds: seconds.round());
  final minutes = duration.inMinutes;
  final remainingSeconds = duration.inSeconds % 60;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  List<SongModel> _stableGridSongs = const [];

  @override
  void initState() {
    super.initState();
    // 🚀 Clear any leftover search from previous visit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        p.Provider.of<LibraryProvider>(context, listen: false).search('');
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final filterKey = GlobalKey<PopupMenuButtonState<LibraryFilter>>();
    final sortKey = GlobalKey<PopupMenuButtonState<LibrarySort>>();

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
                        Icon(Icons.search,
                            color: titleColor.withValues(alpha: 0.5), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl, // 🚀 Persistent controller
                            decoration: InputDecoration(
                              hintText:
                                  AppLocalizations.of(context)!.searchSongs,
                              hintStyle: TextStyle(
                                  color: titleColor.withValues(alpha: 0.3),
                                  fontSize: 15),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(bottom: 4),
                            ),
                            style: TextStyle(color: titleColor, fontSize: 15),
                            cursorColor: Theme.of(context).primaryColor,
                            onChanged: (value) {
                              _searchDebounce?.cancel();
                              _searchDebounce =
                                  Timer(const Duration(milliseconds: 300), () {
                                library.search(value);
                              });
                            },
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

            const SizedBox(height: 8),

            // SUB-CONTROLS (Separate Filters & Sort)
            Row(
              children: [
                // --- FILTERS ---
                Theme(
                  data: Theme.of(context).copyWith(
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: PopupMenuButton<LibraryFilter>(
                    key: filterKey,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => filterKey.currentState?.showButtonMenu(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.filters,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.filter_list_rounded,
                                color: settings.accentColor, size: 20),
                          ],
                        ),
                      ),
                    ),
                    tooltip: "",
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (filter) => ref
                        .read(libraryPresentationProvider.notifier)
                        .setFilter(filter),
                    itemBuilder: (context) =>
                        LibraryFilter.values.map((filter) {
                      String label = _getFilterLabel(context, filter);
                      IconData iconData;
                      switch (filter) {
                        case LibraryFilter.songs:
                          iconData = Icons.music_note_rounded;
                          break;
                        case LibraryFilter.folders:
                          iconData = Icons.folder_rounded;
                          break;
                        case LibraryFilter.artists:
                          iconData = Icons.person_rounded;
                          break;
                        case LibraryFilter.albums:
                          iconData = Icons.album_rounded;
                          break;
                      }
                      return PopupMenuItem(
                        value: filter,
                        child: Row(
                          children: [
                            Icon(iconData,
                                size: 20,
                                color: presentationState.currentFilter == filter
                                    ? settings.accentColor
                                    : iconColor),
                            const SizedBox(width: 12),
                            Text(label,
                                style: TextStyle(
                                    color: presentationState.currentFilter ==
                                            filter
                                        ? settings.accentColor
                                        : titleColor,
                                    fontWeight:
                                        presentationState.currentFilter ==
                                                filter
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(width: 12),
                Container(
                  height: 20,
                  width: 1,
                  color: iconColor?.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 12),

                // --- SORT ---
                Theme(
                  data: Theme.of(context).copyWith(
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: PopupMenuButton<LibrarySort>(
                    key: sortKey,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => sortKey.currentState?.showButtonMenu(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getSortLabel(
                                  context,
                                  presentationState.sortBy,
                                  presentationState.currentFilter,
                                  presentationState.isSortDescending),
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                                presentationState.isSortDescending
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: settings.accentColor,
                                size: 18),
                          ],
                        ),
                      ),
                    ),
                    tooltip: "",
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (sort) => ref
                        .read(libraryPresentationProvider.notifier)
                        .setSortBy(sort),
                    itemBuilder: (context) {
                      final isCategoryView = presentationState.currentFilter ==
                              LibraryFilter.artists ||
                          presentationState.currentFilter ==
                              LibraryFilter.albums;

                      final options = isCategoryView
                          ? [LibrarySort.title]
                          : LibrarySort.values;
                      return options.map((sort) {
                        final isSelected = presentationState.sortBy == sort;
                        String label = _getSortLabel(
                            context,
                            sort,
                            presentationState.currentFilter,
                            presentationState.isSortDescending);
                        return PopupMenuItem(
                          value: sort,
                          child: Row(
                            children: [
                              Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: 18,
                                  color: isSelected
                                      ? settings.accentColor
                                      : iconColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(label,
                                    style: TextStyle(
                                        color: isSelected
                                            ? settings.accentColor
                                            : titleColor,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ),
                              if (isSelected)
                                Icon(
                                    presentationState.isSortDescending
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    size: 16,
                                    color: settings.accentColor),
                            ],
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

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

  String _getFilterLabel(BuildContext context, LibraryFilter filter) {
    switch (filter) {
      case LibraryFilter.songs:
        return AppLocalizations.of(context)!.songs;
      case LibraryFilter.folders:
        return AppLocalizations.of(context)!.folders;
      case LibraryFilter.artists:
        return AppLocalizations.of(context)!.artists;
      case LibraryFilter.albums:
        return AppLocalizations.of(context)!.albums;
    }
  }

  String _getSortLabel(BuildContext context, LibrarySort sort,
      LibraryFilter currentFilter, bool isDescending) {
    if (sort == LibrarySort.title &&
        (currentFilter == LibraryFilter.artists ||
            currentFilter == LibraryFilter.albums)) {
      return isDescending ? "Z-A" : "A-Z";
    }

    switch (sort) {
      case LibrarySort.title:
        return AppLocalizations.of(context)!.title;
      case LibrarySort.artist:
        return AppLocalizations.of(context)!.artist;
      case LibrarySort.fileName:
        return AppLocalizations.of(context)!.fileName;
    }
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
                library.scanProgress > 0
                    ? AppLocalizations.of(context)!
                        .songsLoadedCount(library.scanProgress)
                    : 'Scanning...',
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
        return _buildFoldersView(
            context, ref, presentationState, isGridView, isDark, textColor);
      case LibraryFilter.artists:
        return _buildArtistsView(
            context, ref, presentationState, isGridView, isDark, textColor);
      case LibraryFilter.albums:
        return _buildAlbumsView(
            context, ref, presentationState, isGridView, isDark, textColor);
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
    final settings = ref.watch(settingsProvider);
    final hasTheme = settings.atmosphereTheme != AtmosphereTheme.none;
    final titleColor = textColor; // Resolve titleColor errors in overlay

    List<SongModel> displaySongs = ref.watch(displaySortedSongsProvider);
    if (presentationState.selectedFolderPath != null) {
      final groupedFolders = ref.watch(groupedFoldersProvider);
      displaySongs =
          groupedFolders[presentationState.selectedFolderPath!] ?? [];
    }

    // 🚀 STABLE GRID: Cache last non-empty results so the grid/list
    // retains its tiles instead of mass-disposing them (which deadlocks Win32).
    if (displaySongs.isNotEmpty) {
      _stableGridSongs = displaySongs;
    }
    final gridSongs = _stableGridSongs;
    return Stack(
      children: [
        Column(
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
              child: Stack(
                children: [
                  // 🚀 STRUCTURAL PRESERVATION GRID:
                  // This Grid/List remains in the tree at all times with the cached gridSongs.
                  // It is visually hidden by the full-screen overlay below when search hits zero.
                  isGridView
                      ? GridView.builder(
                          key: const PageStorageKey('library_songs_grid'),
                          padding: const EdgeInsets.only(bottom: 120),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: gridSongs.length,
                          itemBuilder: (context, index) => SongGridTile(
                            song: gridSongs[index],
                            allSongs: gridSongs,
                            isDark: isDark,
                          ),
                        )
                      : ListView.separated(
                          key: const PageStorageKey('library_songs_list'),
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                              bottom: 120,
                              right: settings.enableAlphabetIndexer ? 30 : 0),
                          itemCount: gridSongs.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) => SongListTile(
                            song: gridSongs[index],
                            allSongs: gridSongs,
                            index: index,
                            isDark: isDark,
                          ),
                        ),

                  // 🚀 PERMANENT INDEXER:
                  // We NEVER remove the Indexer from the tree to avoid Win32 deadlocks.
                  if (!isGridView && settings.enableAlphabetIndexer)
                    Positioned(
                      right: 2,
                      top: 0,
                      bottom: 110,
                      width: 28,
                      child: _AlphabetIndexer(
                        songs: displaySongs,
                        sortBy: presentationState.sortBy,
                        onLetterSelected: (letter) {
                          final index = displaySongs.indexWhere((s) {
                            String matchStr = s.title;
                            if (presentationState.sortBy ==
                                LibrarySort.artist) {
                              matchStr = s.artist;
                            } else if (presentationState.sortBy ==
                                LibrarySort.fileName) {
                              matchStr = p_path.basename(s.filePath);
                            }

                            matchStr = matchStr.trim();
                            if (matchStr.isEmpty) return false;
                            final firstChar = matchStr[0].toUpperCase();
                            if (letter == '#') {
                              return RegExp(r'[^a-zA-Z]').hasMatch(firstChar);
                            }
                            return firstChar == letter;
                          });
                          if (index != -1) {
                            _scrollController.jumpTo(index * 80.0);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        // 🚀 FULL-VIEWPORT OVERLAY:
        // By placing this in the outer Stack, we ignore the 32px horizontal padding
        // of the parent Column and cover the entire screen edge-to-edge.
        if (displaySongs.isEmpty)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  // 🚀 TRUE ATMOSPHERIC GLASS:
                  // We match your grid cards exactly by using a dark tint in dark mode,
                  // but with a lower alpha (0.08) to make it even smoother.
                  color: hasTheme
                      ? (isDark
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.1))
                      : Theme.of(context)
                          .scaffoldBackgroundColor
                          .withValues(alpha: 0.85),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 🚀 ICON THEMING: Use accent color for thematic pop
                        Icon(Icons.music_off_rounded,
                            size: 80,
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.9)),
                        const SizedBox(height: 24),
                        Text(
                          presentationState.selectedFolderPath != null
                              ? "No songs in folder '${p_path.basename(presentationState.selectedFolderPath!)}'"
                              : AppLocalizations.of(context)!.noSongsInFolder,
                          style: TextStyle(
                              color: titleColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                )
                              ]),
                        ),
                        const SizedBox(height: 24),
                        if (presentationState.selectedFolderPath != null)
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.5)),
                              foregroundColor: titleColor,
                            ),
                            onPressed: () => ref
                                .read(libraryPresentationProvider.notifier)
                                .clearFolderFilter(),
                            child: const Text("Show All Songs"),
                          )
                        else
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.5)),
                              foregroundColor: titleColor,
                            ),
                            onPressed: () async {
                              final path = await FolderPicker.pickDirectory();
                              if (path != null) {
                                library.setFolder(path);
                              }
                            },
                            child: Text(AppLocalizations.of(context)!
                                .selectDifferentFolder),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFoldersView(
      BuildContext context,
      WidgetRef ref,
      LibraryPresentationState presentationState,
      bool isGridView,
      bool isDark,
      Color textColor) {
    final groupedFolders = ref.watch(groupedFoldersProvider);

    if (groupedFolders.isEmpty) {
      return Center(
          child: Text("No folders found", style: TextStyle(color: textColor)));
    }

    if (isGridView) {
      return GridView.builder(
        key: const PageStorageKey('library_folders_grid'),
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
    } else {
      return ListView.separated(
        key: const PageStorageKey('library_folders_list'),
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: groupedFolders.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final folderPath = groupedFolders.keys.elementAt(index);
          final folderName = p_path.basename(folderPath);
          final songs = groupedFolders[folderPath]!;

          return CategoryListTile(
            title: folderName,
            subtitle: "${songs.length} songs",
            icon: Icons.folder_rounded,
            artPath: songs.isNotEmpty ? songs.first.filePath : null,
            onlineArtUrl: songs.isNotEmpty ? songs.first.onlineArtUrl : null,
            isDark: isDark,
            onTap: () => ref
                .read(libraryPresentationProvider.notifier)
                .selectFolder(folderPath),
          );
        },
      );
    }
  }

  Widget _buildArtistsView(
      BuildContext context,
      WidgetRef ref,
      LibraryPresentationState presentationState,
      bool isGridView,
      bool isDark,
      Color textColor) {
    final groupedArtists = ref.watch(groupedArtistsProvider);

    if (groupedArtists.isEmpty) {
      return Center(
          child: Text("No artists found", style: TextStyle(color: textColor)));
    }

    final artists = groupedArtists.keys.toList()
      ..sort((a, b) {
        final cmp = a.toLowerCase().compareTo(b.toLowerCase());
        return presentationState.isSortDescending ? -cmp : cmp;
      });

    if (isGridView) {
      return GridView.builder(
        key: const PageStorageKey('library_artists_grid'),
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
    } else {
      return ListView.separated(
        key: const PageStorageKey('library_artists_list'),
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: artists.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final artistName = artists[index];
          final artistSongs = groupedArtists[artistName]!;

          return CategoryListTile(
            title: artistName,
            subtitle: "${artistSongs.length} songs",
            icon: Icons.person_rounded,
            artPath: artistSongs.isNotEmpty ? artistSongs.first.filePath : null,
            onlineArtUrl:
                artistSongs.isNotEmpty ? artistSongs.first.onlineArtUrl : null,
            isDark: isDark,
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
  }

  Widget _buildAlbumsView(
      BuildContext context,
      WidgetRef ref,
      LibraryPresentationState presentationState,
      bool isGridView,
      bool isDark,
      Color textColor) {
    final groupedAlbums = ref.watch(groupedAlbumsProvider);

    if (groupedAlbums.isEmpty) {
      return Center(
          child: Text("No albums found", style: TextStyle(color: textColor)));
    }

    final albumNames = groupedAlbums.keys.toList()
      ..sort((a, b) {
        final cmp = a.toLowerCase().compareTo(b.toLowerCase());
        return presentationState.isSortDescending ? -cmp : cmp;
      });

    if (isGridView) {
      return GridView.builder(
        key: const PageStorageKey('library_albums_grid'),
        padding: const EdgeInsets.only(bottom: 120),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: albumNames.length,
        itemBuilder: (context, index) {
          final albumName = albumNames[index];
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
    } else {
      return ListView.separated(
        key: const PageStorageKey('library_albums_list'),
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: albumNames.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final albumName = albumNames[index];
          final songs = groupedAlbums[albumName]!;
          final artistName =
              songs.isNotEmpty ? songs.first.artist : "Unknown Artist";

          return CategoryListTile(
            title: albumName,
            subtitle: artistName,
            icon: Icons.album_rounded,
            artPath: songs.isNotEmpty ? songs.first.filePath : null,
            onlineArtUrl: songs.isNotEmpty ? songs.first.onlineArtUrl : null,
            isDark: isDark,
            onTap: () {
              final album = AlbumModel(
                id: "local_$albumName",
                title: albumName,
                artist: artistName,
                imageUrl: "",
                releaseDate: songs.first.year ?? "Unknown",
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
              onPressed: () async {
                final path = await FolderPicker.pickDirectory();
                if (path != null) {
                  library.setFolder(path);
                }
              },
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
        onPressed: () async {
          final path = await FolderPicker.pickDirectory();
          if (path != null) {
            library.setFolder(path);
          }
        },
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
    // 🚀 SELECTIVE WATCH: Only rebuild when the current song changes, not on every position tick
    final currentFilePath =
        ref.watch(playerProvider.select((s) => s.currentSong?.filePath));
    final notifier = ref.read(playerProvider.notifier);
    final isPlaying = currentFilePath == song.filePath;
    final activeColor = Theme.of(context).primaryColor;

    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final metaColor = isDark ? Colors.grey[600] : Colors.grey[500];

    // Determine if we should show additional metadata columns (tablet/desktop)
    final layoutType = LayoutEngine.getLayoutType(context);
    final showMetadataColumns =
        layoutType == LayoutType.tablet || layoutType == LayoutType.desktop;

    return SongContextMenuRegion(
      song: song,
      currentQueue: allSongs,
      allowMetadataEdit: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => notifier.playSong(song, newQueue: allSongs),
          borderRadius: BorderRadius.circular(8),
          hoverColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          child: SizedBox(
            height: 72,
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
                    child: showMetadataColumns
                        ? _buildTabletLayout(isPlaying, activeColor, titleColor,
                            subtitleColor, metaColor)
                        : _buildPhoneLayout(
                            isPlaying, activeColor, titleColor, subtitleColor),
                  ),
                  if (showMetadataColumns) ...[
                    const SizedBox(width: 16),
                    Text(_formatDuration(song.duration),
                        style: TextStyle(
                            fontSize: 13,
                            color: metaColor,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                  ],
                  const SizedBox(width: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        () {}, // Absorb tap tapping so parent InkWell doesn't capture on desktop
                    onTapDown: (details) {
                      SongContextMenuRegion.showSongMenu(
                        context,
                        details.globalPosition,
                        ref,
                        song,
                        allowMetadataEdit: true,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: Icon(Icons.more_vert_rounded,
                          color: metaColor, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tablet/Desktop layout: Title + Album name in a row, artist below.
  /// Duration is shown as a separate column in the parent Row.
  Widget _buildTabletLayout(bool isPlaying, Color activeColor, Color titleColor,
      Color? subtitleColor, Color? metaColor) {
    return Column(
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
                      color: isPlaying ? activeColor : titleColor)),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Text(song.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 13, color: metaColor)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: subtitleColor)),
      ],
    );
  }

  /// Phone layout: Title and artist only (no album/duration columns to save space).
  Widget _buildPhoneLayout(bool isPlaying, Color activeColor, Color titleColor,
      Color? subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isPlaying ? activeColor : titleColor)),
        const SizedBox(height: 4),
        Text(song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: subtitleColor)),
      ],
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
    // 🚀 SELECTIVE WATCH: Only rebuild when the current song changes, not on every position tick
    final currentFilePath =
        ref.watch(playerProvider.select((s) => s.currentSong?.filePath));
    final notifier = ref.read(playerProvider.notifier);
    final isPlaying = currentFilePath == song.filePath;
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
      allowMetadataEdit: true,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              style:
                                  TextStyle(fontSize: 12, color: artistColor)),
                        ],
                      ),
                    ),
                    if (Platform.isAndroid || Platform.isIOS)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap:
                            () {}, // Absorb tap tapping so parent InkWell doesn't capture on desktop/hover context overlays
                        onTapDown: (details) {
                          SongContextMenuRegion.showSongMenu(
                            context,
                            details.globalPosition,
                            ref,
                            song,
                            allowMetadataEdit: true,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: artistColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? artPath;
  final String? onlineArtUrl;
  final bool isDark;
  final VoidCallback onTap;

  const CategoryListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.artPath,
    this.onlineArtUrl,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final iconBgColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: artPath != null
                    ? SmartArt(
                        path: artPath!,
                        size: 56,
                        borderRadius: 8,
                        onlineArtUrl: onlineArtUrl)
                    : Icon(icon, size: 28, color: titleColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.chevron_right_rounded,
                  color: (subtitleColor ?? Colors.grey).withValues(alpha: 0.5),
                  size: 20),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlphabetIndexer extends StatefulWidget {
  final List<SongModel> songs;
  final LibrarySort sortBy;
  final Function(String) onLetterSelected;

  const _AlphabetIndexer({
    required this.songs,
    required this.sortBy,
    required this.onLetterSelected,
  });

  @override
  State<_AlphabetIndexer> createState() => _AlphabetIndexerState();
}

class _AlphabetIndexerState extends State<_AlphabetIndexer> {
  final List<String> _alphabet = '#ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
  String? _activeLetter;
  Set<String> _availableLetters = {};

  @override
  void initState() {
    super.initState();
    _computeAvailableLetters();
  }

  @override
  void didUpdateWidget(covariant _AlphabetIndexer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.songs != oldWidget.songs || widget.sortBy != oldWidget.sortBy) {
      _computeAvailableLetters();
    }
  }

  void _computeAvailableLetters() {
    final Set<String> letters = {};
    for (final s in widget.songs) {
      final str = _getSongSortString(s).trim();
      if (str.isEmpty) continue;

      final firstChar = str[0].toUpperCase();
      final codeUnit = firstChar.codeUnitAt(0);

      // A-Z is 65-90
      if (codeUnit >= 65 && codeUnit <= 90) {
        letters.add(firstChar);
      } else {
        letters.add('#');
      }

      if (letters.length == 27) break; // Optimization: all found
    }
    setState(() {
      _availableLetters = letters;
    });
  }

  String _getSongSortString(SongModel s) {
    switch (widget.sortBy) {
      case LibrarySort.artist:
        return s.artist;
      case LibrarySort.fileName:
        return p_path.basename(s.filePath);
      default:
        return s.title;
    }
  }

  void _triggerLetter(String letter) {
    widget.onLetterSelected(letter);
    setState(() => _activeLetter = letter);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemHeight = constraints.maxHeight / _alphabet.length;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) {
            final index = (details.localPosition.dy / itemHeight)
                .floor()
                .clamp(0, _alphabet.length - 1);
            _triggerLetter(_alphabet[index]);
          },
          onVerticalDragDown: (details) {
            final index = (details.localPosition.dy / itemHeight)
                .floor()
                .clamp(0, _alphabet.length - 1);
            _triggerLetter(_alphabet[index]);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _alphabet.map((letter) {
                final isPresent = _availableLetters.contains(letter);
                final isCurrent = _activeLetter == letter;

                return Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: isCurrent
                            ? Theme.of(context).primaryColor
                            : isPresent
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
                        fontSize: 10,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
