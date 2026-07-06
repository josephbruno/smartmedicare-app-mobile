import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';

/// Device size categories
enum DeviceCategory {
  mobile,    // < 600px
  tablet,    // 600px - 1200px
  desktop,   // >= 1200px
}

/// Responsive layout helper
class ResponsiveLayout {
  static const double mobileMaxWidth = AppConfig.mobileCompactBreakpoint;
  static const double tabletMaxWidth = AppConfig.desktopLayoutBreakpoint;
  static const double desktopWideBreakpoint = AppConfig.desktopWideBreakpoint;
  static const double desktopSidebarWidth = 280;

  /// Get device category based on width
  static DeviceCategory getDeviceCategory(double width) {
    if (width < mobileMaxWidth) return DeviceCategory.mobile;
    if (width < desktopWideBreakpoint) return DeviceCategory.tablet;
    return DeviceCategory.desktop;
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileMaxWidth;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileMaxWidth && width < tabletMaxWidth;
  }

  /// Check if device is desktop (wide multi-pane layouts)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopWideBreakpoint;
  }

  /// Tablet / sidebar layout
  static bool isTabletOrDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletMaxWidth;
  }

  /// Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(12);
    if (isTablet(context)) return const EdgeInsets.all(16);
    return const EdgeInsets.all(24);
  }

  /// Get responsive font size
  static double getResponsiveFontSize(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet ?? mobile * 1.1;
    return desktop ?? mobile * 1.2;
  }

  /// Get responsive grid columns
  static int getGridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3;
  }

  /// Get responsive app bar height
  static double getAppBarHeight(BuildContext context) {
    return isDesktop(context) ? 72 : 56;
  }

  /// Get responsive drawer width
  static double getDrawerWidth(BuildContext context) {
    if (isMobile(context)) return MediaQuery.of(context).size.width * 0.75;
    return desktopSidebarWidth;
  }

  /// Get max content width for centered layout
  static double getMaxContentWidth(BuildContext context) {
    return isDesktop(context) ? 1400 : double.infinity;
  }
}

/// Responsive layout widget
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) mobileBuilder;
  final Widget Function(BuildContext context)? tabletBuilder;
  final Widget Function(BuildContext context)? desktopBuilder;

  const ResponsiveBuilder({
    Key? key,
    required this.mobileBuilder,
    this.tabletBuilder,
    this.desktopBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isDesktop(context) && desktopBuilder != null) {
      return desktopBuilder!(context);
    } else if (ResponsiveLayout.isTablet(context) && tabletBuilder != null) {
      return tabletBuilder!(context);
    }
    return mobileBuilder(context);
  }
}

/// Desktop-specific navigation rail
class DesktopNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final List<DesktopNavigationItem> items;
  final Color? backgroundColor;

  const DesktopNavigationRail({
    Key? key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.items,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onIndexChanged,
      backgroundColor: backgroundColor ?? Colors.white,
      extended: true,
      destinations: items
          .map((item) => NavigationRailDestination(
                icon: item.icon,
                selectedIcon: item.selectedIcon ?? item.icon,
                label: Text(item.label),
              ))
          .toList(),
    );
  }
}

/// Navigation item for desktop rail
class DesktopNavigationItem {
  final String label;
  final Widget icon;
  final Widget? selectedIcon;

  DesktopNavigationItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });
}

/// Keyboard shortcut handler
class KeyboardShortcutHandler extends StatelessWidget {
  final Map<ShortcutKey, VoidCallback> shortcuts;
  final Widget child;

  const KeyboardShortcutHandler({
    Key? key,
    required this.shortcuts,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        for (final entry in shortcuts.entries) {
          if (_matchesKeyEvent(event, entry.key)) {
            entry.value();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }

  bool _matchesKeyEvent(KeyEvent event, ShortcutKey shortcut) {
    final hw = HardwareKeyboard.instance;
    final isControlPressed = hw.isControlPressed || hw.isMetaPressed;
    final isShiftPressed = hw.isShiftPressed;
    final isAltPressed = hw.isAltPressed;

    if (shortcut.ctrl != isControlPressed) return false;
    if (shortcut.shift != isShiftPressed) return false;
    if (shortcut.alt != isAltPressed) return false;

    return event.logicalKey == shortcut.logicalKey;
  }
}

/// Keyboard shortcut definition
class ShortcutKey {
  final LogicalKeyboardKey logicalKey;
  final bool ctrl;
  final bool shift;
  final bool alt;

  ShortcutKey({
    required this.logicalKey,
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
  });

  /// Create shortcut for Ctrl+Key
  factory ShortcutKey.ctrl(LogicalKeyboardKey key) {
    return ShortcutKey(logicalKey: key, ctrl: true);
  }

  /// Create shortcut for Ctrl+Shift+Key
  factory ShortcutKey.ctrlShift(LogicalKeyboardKey key) {
    return ShortcutKey(logicalKey: key, ctrl: true, shift: true);
  }

  /// Create shortcut for Alt+Key
  factory ShortcutKey.alt(LogicalKeyboardKey key) {
    return ShortcutKey(logicalKey: key, alt: true);
  }
}

/// Multi-pane layout for desktop
class MultiPaneLayout extends StatelessWidget {
  final Widget leftPane;
  final Widget centerPane;
  final Widget? rightPane;
  final double leftPaneWidth;
  final double rightPaneWidth;

  const MultiPaneLayout({
    Key? key,
    required this.leftPane,
    required this.centerPane,
    this.rightPane,
    this.leftPaneWidth = 300,
    this.rightPaneWidth = 350,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveLayout.isDesktop(context)) {
      return centerPane;
    }

    if (rightPane == null) {
      return Row(
        children: [
          SizedBox(width: leftPaneWidth, child: leftPane),
          Expanded(child: centerPane),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(width: leftPaneWidth, child: leftPane),
        Expanded(child: centerPane),
        SizedBox(width: rightPaneWidth, child: rightPane!),
      ],
    );
  }
}

/// Responsive grid layout
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int Function(BuildContext) columnCountBuilder;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    Key? key,
    required this.children,
    required this.columnCountBuilder,
    this.spacing = 16,
    this.runSpacing = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: children
          .map((child) => SizedBox(
                width: _getItemWidth(context, columnCountBuilder(context)),
                child: child,
              ))
          .toList(),
    );
  }

  double _getItemWidth(BuildContext context, int columns) {
    final width = MediaQuery.of(context).size.width;
    return (width - (spacing * (columns - 1))) / columns;
  }
}
