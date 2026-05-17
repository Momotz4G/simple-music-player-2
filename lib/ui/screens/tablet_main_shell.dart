import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/library_presentation_provider.dart';
import '../../providers/search_bridge_provider.dart';
import '../../providers/tablet_layout_provider.dart';
import '../../utils/layout_engine.dart';
import '../components/tablet_queue_panel.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'search_page.dart';
import 'settings_page.dart';

/// A tablet-specific main shell that uses a [NavigationRail] on the leading
/// edge instead of a bottom navigation bar or drawer.
///
/// The layout is a [Row] with:
///   - [NavigationRail] on the left (leading edge)
///   - [Expanded] content area on the right
///
/// Navigation destinations: Home, Library, Search, Settings.
class TabletMainShell extends ConsumerStatefulWidget {
  const TabletMainShell({super.key});

  @override
  ConsumerState<TabletMainShell> createState() => _TabletMainShellState();
}

class _TabletMainShellState extends ConsumerState<TabletMainShell> {
  int _selectedIndex = 0;

  /// Maps NavigationRail indices to [LibraryView] values.
  static const List<LibraryView> _navDestinations = [
    LibraryView.browse,
    LibraryView.localLibrary,
    LibraryView.search,
    LibraryView.settings,
  ];

  /// The page widgets corresponding to each navigation destination.
  static const List<Widget> _pages = [
    HomePage(),
    LibraryPage(),
    SearchPage(),
    SettingsPage(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLandscape = LayoutEngine.isLandscape(context);

    // Watch the tablet layout state for queue panel visibility.
    final tabletLayout = ref.watch(tabletLayoutProvider);
    final isQueueOpen = tabletLayout.isQueuePanelOpen && isLandscape;

    // Watch the presentation provider to stay in sync with external navigation
    // changes (e.g., from deep links or other widgets).
    final currentView = ref.watch(libraryPresentationProvider).currentView;
    final providerIndex = _navDestinations.indexOf(currentView);
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
                child: _pages[_selectedIndex],
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
