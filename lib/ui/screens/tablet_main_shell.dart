import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/album_model.dart';
import '../../models/daily_mix_model.dart';
import '../../models/song_metadata.dart';
import '../../providers/library_presentation_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../providers/tablet_layout_provider.dart';
import '../../utils/layout_engine.dart';
import '../components/tablet_queue_panel.dart';

// --- ALL SCREEN IMPORTS ---
import 'album_detail_page.dart';
import 'albums_page.dart';
import 'artist_detail_page.dart';
import 'artists_page.dart';
import 'daily_mix_detail_page.dart';
import 'downloads_page.dart';
import 'history_page.dart';
import 'home_page.dart';
import 'leaderboard_page.dart';
import 'library_page.dart';
import 'playlist_detail_page.dart';
import 'playlists_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'tools_page.dart';
import 'track_detail_page.dart';

/// A tablet-specific main shell that uses a [NavigationRail] on the leading
/// edge instead of a bottom navigation bar or drawer.
///
/// The layout is a [Row] with:
///   - [NavigationRail] on the left (leading edge)
///   - [Expanded] content area on the right
///
/// Supports all [LibraryView] values and renders detail pages
/// (album, artist, track, playlist, daily mix) from the navigation stack.
class TabletMainShell extends ConsumerStatefulWidget {
  const TabletMainShell({super.key});

  @override
  ConsumerState<TabletMainShell> createState() => _TabletMainShellState();
}

class _TabletMainShellState extends ConsumerState<TabletMainShell> {
  int _selectedIndex = 0;

  /// The four primary NavigationRail destinations.
  /// All other views are reachable via the navigation drawer.
  static const List<LibraryView> _navDestinations = [
    LibraryView.browse,
    LibraryView.localLibrary,
    LibraryView.search,
    LibraryView.settings,
  ];

  @override
  void initState() {
    super.initState();
    // Sync initial index with the current library presentation state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncIndexFromProvider();
    });
  }

  /// Synchronizes the selected index from the current [LibraryView] in the
  /// presentation provider, so external navigation changes are reflected.
  void _syncIndexFromProvider() {
    final currentView = ref.read(libraryPresentationProvider).currentView;
    final index = _navDestinations.indexOf(currentView);
    if (index != -1 && index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);

    // Clear any detail page navigation stack when switching tabs.
    ref.read(navigationStackProvider.notifier).clear();

    // Update the library presentation provider so other parts of the app
    // stay in sync.
    ref
        .read(libraryPresentationProvider.notifier)
        .setView(_navDestinations[index]);
  }

  /// Returns the correct page widget for any [LibraryView], including views
  /// that are not part of the NavigationRail (accessed via the drawer).
  Widget _getPageForView(LibraryView view) {
    switch (view) {
      case LibraryView.browse:
        return const HomePage();
      case LibraryView.localLibrary:
        return const LibraryPage();
      case LibraryView.search:
        return const SearchPage();
      case LibraryView.settings:
        return const SettingsPage();
      case LibraryView.history:
        return const HistoryPage();
      case LibraryView.stats:
        return const StatsPage();
      case LibraryView.playlists:
        return const PlaylistsPage();
      case LibraryView.artists:
        return const ArtistsPage();
      case LibraryView.albums:
        return const AlbumsPage();
      case LibraryView.downloads:
        return const DownloadsPage();
      case LibraryView.tools:
        return const ToolsPage();
      case LibraryView.leaderboard:
        return const LeaderboardPage();
      default:
        return const HomePage();
    }
  }

  /// Builds the detail page for the topmost item on the navigation stack.
  /// Returns `null` if the stack is empty.
  Widget? _buildDetailPage(List<NavigationItem> stack) {
    if (stack.isEmpty) return null;

    final item = stack.last;
    switch (item.type) {
      case NavigationType.artist:
        final selection = item.data as ArtistSelection;
        return ArtistDetailPage(
          artistName: selection.artistName,
          songs: selection.songs ?? [],
        );
      case NavigationType.album:
        return AlbumDetailPage(album: item.data as AlbumModel);
      case NavigationType.playlist:
        return PlaylistDetailPage(playlistId: item.data as String);
      case NavigationType.track:
        return TrackDetailPage(songMetadata: item.data as SongMetadata);
      case NavigationType.dailyMix:
        return DailyMixDetailPage(mix: item.data as DailyMix);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLandscape = LayoutEngine.isLandscape(context);

    // Watch the tablet layout state for queue panel visibility.
    final tabletLayout = ref.watch(tabletLayoutProvider);
    final isQueueOpen = tabletLayout.isQueuePanelOpen && isLandscape;

    // Watch the navigation stack for detail page rendering.
    final navigationStack = ref.watch(navigationStackProvider);
    final detailPage = _buildDetailPage(navigationStack);

    // Watch the presentation provider to stay in sync with external navigation
    // changes (e.g., from the drawer, deep links, or other widgets).
    final currentView = ref.watch(libraryPresentationProvider).currentView;
    final providerIndex = _navDestinations.indexOf(currentView);

    // Sync selected rail index when the view is one of the rail destinations.
    if (providerIndex != -1 && providerIndex != _selectedIndex) {
      // Schedule state update to avoid building during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedIndex = providerIndex);
        }
      });
    }

    return Row(
      children: [
        // Leading edge: NavigationRail
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          labelType: isLandscape
              ? NavigationRailLabelType.all
              : NavigationRailLabelType.none,
          minWidth: isLandscape ? 80 : 56,
          backgroundColor: colorScheme.surface,
          selectedIconTheme: IconThemeData(color: colorScheme.primary),
          unselectedIconTheme: IconThemeData(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          selectedLabelTextStyle: TextStyle(
            color: colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
          // LEADING: Menu button to open the navigation drawer
          leading: Builder(
            builder: (scaffoldContext) => IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              tooltip: AppLocalizations.of(context)?.navigation ?? 'Menu',
              onPressed: () {
                Scaffold.of(scaffoldContext).openDrawer();
              },
            ),
          ),
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: IconButton(
                  icon: Icon(
                    isQueueOpen
                        ? Icons.queue_music_rounded
                        : Icons.queue_music_outlined,
                    color: isQueueOpen
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  tooltip: 'Queue',
                  onPressed: () {
                    if (isLandscape) {
                      ref
                          .read(tabletLayoutProvider.notifier)
                          .toggleQueuePanel();
                    } else {
                      // In portrait, show as bottom sheet
                      TabletQueuePanel.showAsBottomSheet(context);
                    }
                  },
                ),
              ),
            ),
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: Text('Home'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music_rounded),
              label: Text('Library'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search_rounded),
              label: Text('Search'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: Text('Settings'),
            ),
          ],
        ),

        // Vertical divider between rail and content
        VerticalDivider(
          thickness: 1,
          width: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),

        // Content area: animates width when queue panel opens/closes
        Expanded(
          child: Row(
            children: [
              // Main content compresses when queue is open
              Expanded(
                child: Stack(
                  children: [
                    // BASE LAYER: Current page view.
                    // Hidden (but kept alive) when a detail page is active.
                    IgnorePointer(
                      ignoring: detailPage != null,
                      child: Opacity(
                        opacity: detailPage != null ? 0.0 : 1.0,
                        child: _getPageForView(currentView),
                      ),
                    ),

                    // DETAIL LAYER: Overlay for detail pages (album, artist,
                    // track, playlist, daily mix) pushed onto the nav stack.
                    if (detailPage != null)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(
                            'tablet_stack_${navigationStack.length}_${navigationStack.last.type}',
                          ),
                          child: detailPage,
                        ),
                      ),
                  ],
                ),
              ),

              // Queue panel (landscape only) — animated width container
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: isQueueOpen ? 320 : 0,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: isQueueOpen
                    ? TabletQueuePanel(
                        isVisible: isQueueOpen,
                        onClose: () {
                          ref
                              .read(tabletLayoutProvider.notifier)
                              .setQueuePanelOpen(false);
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
