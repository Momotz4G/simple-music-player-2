import 'package:flutter/widgets.dart';

/// Device layout classification based on screen width breakpoints.
enum LayoutType { phone, tablet, desktop }

/// A stateless utility providing layout decisions based on device
/// characteristics and orientation.
///
/// Breakpoints:
///   phone:   width < 600dp
///   tablet:  600dp ≤ width ≤ 800dp
///   desktop: width > 800dp
class LayoutEngine {
  /// Returns the current [LayoutType] based on the window width.
  static LayoutType getLayoutType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 800) return LayoutType.desktop;
    if (width >= 600) return LayoutType.tablet;
    return LayoutType.phone;
  }

  /// Returns `true` when the current layout is classified as tablet.
  static bool isTablet(BuildContext context) =>
      getLayoutType(context) == LayoutType.tablet;

  /// Returns `true` when the device is in landscape orientation.
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Returns the number of grid columns appropriate for the current layout
  /// and orientation.
  ///
  /// - Phone: 2 columns
  /// - Tablet portrait: 3 columns
  /// - Tablet landscape: 4 columns
  /// - Desktop: defers to desktop-specific logic (defaults to 4)
  static int getGridColumns(BuildContext context) {
    final layoutType = getLayoutType(context);
    switch (layoutType) {
      case LayoutType.phone:
        return 2;
      case LayoutType.tablet:
        return isLandscape(context) ? 4 : 3;
      case LayoutType.desktop:
        return 4;
    }
  }

  /// Returns `true` when a NavigationRail should be displayed instead of
  /// a bottom navigation bar. This is the case for tablet layouts.
  static bool shouldShowNavRail(BuildContext context) =>
      getLayoutType(context) == LayoutType.tablet;
}
