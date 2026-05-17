import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State class for tablet-specific layout state.
///
/// Tracks UI state that is specific to the tablet layout, such as
/// the selected settings category in master-detail mode and the
/// queue panel visibility.
class TabletLayoutState {
  final bool isQueuePanelOpen;
  final int selectedSettingsCategory;

  const TabletLayoutState({
    this.isQueuePanelOpen = false,
    this.selectedSettingsCategory = 0,
  });

  TabletLayoutState copyWith({
    bool? isQueuePanelOpen,
    int? selectedSettingsCategory,
  }) {
    return TabletLayoutState(
      isQueuePanelOpen: isQueuePanelOpen ?? this.isQueuePanelOpen,
      selectedSettingsCategory:
          selectedSettingsCategory ?? this.selectedSettingsCategory,
    );
  }
}

/// Notifier for managing tablet layout state.
class TabletLayoutNotifier extends StateNotifier<TabletLayoutState> {
  TabletLayoutNotifier() : super(const TabletLayoutState());

  void setSelectedSettingsCategory(int index) {
    state = state.copyWith(selectedSettingsCategory: index);
  }

  void toggleQueuePanel() {
    state = state.copyWith(isQueuePanelOpen: !state.isQueuePanelOpen);
  }

  void setQueuePanelOpen(bool open) {
    state = state.copyWith(isQueuePanelOpen: open);
  }
}

/// Provider for tablet layout state.
final tabletLayoutProvider =
    StateNotifierProvider<TabletLayoutNotifier, TabletLayoutState>(
  (ref) => TabletLayoutNotifier(),
);
