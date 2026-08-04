import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// API base URL including `/api/v1` suffix.
/// Override at build time: `flutter run --dart-define=API_BASE_URL=https://host/api/v1`
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-maran.biapps.cloud/api/v1',
  );

  /// Windows desktop auto-update check endpoint (no auth).
  static String get appUpdateCheckUrl => '$apiBaseUrl/app/updates/check';

  /// Skip silent update checks in debug unless overridden.
  static const bool enableWindowsAutoUpdate = bool.fromEnvironment(
    'ENABLE_WINDOWS_AUTO_UPDATE',
    defaultValue: true,
  );

  /// Web layout: sidebar + top bar from ~840dp.
  static const double desktopLayoutBreakpoint = 840;

  /// Wide desktop layouts (multi-pane, data tables).
  static const double desktopWideBreakpoint = 1280;

  /// Compact mobile shell (bottom nav) below this width.
  static const double mobileCompactBreakpoint = 600;

  /// True when running as a native desktop application (Windows/macOS/Linux).
  static bool get isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Cashier POS is supported only on Windows and Linux desktop builds.
  static bool get isCashierPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  /// True on web and native desktop — used for larger fonts, icons, and dialogs.
  /// Native mobile (Android/iOS) is excluded.
  static bool get usesLargeUiScale => kIsWeb || isDesktopPlatform;

  /// True on native Android/iOS builds (not web or desktop).
  static bool get isNativeMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Global text scale applied on web & desktop for readability.
  static const double desktopTextScale = 1.35;

  /// Multiplier applied to icon sizes on web & desktop.
  static const double desktopIconScale = 1.4;

  /// Wider [AlertDialog] / modal dialogs on web & desktop.
  static const double desktopDialogMaxWidth = 640;

  /// Auth and standalone form cards (login, register, etc.).
  static const double desktopFormCardMaxWidth = 540;

  /// Desktop top-bar search field max width.
  static const double desktopSearchMaxWidth = 560;

  /// POS checkout dialog width as fraction of screen width on web & desktop.
  static const double desktopPosDialogWidthFactor = 0.70;

  /// Wider checkout success dialog on web & desktop (legacy cap; prefer [desktopPosDialogWidthFactor]).
  static const double desktopPosDialogMaxWidth = 920;

  /// Minimum width so the POS checkout dialog does not shrink too small.
  static const double desktopPosDialogMinWidth = 580;

  /// Compute checkout dialog width for the current screen.
  static double posCheckoutDialogWidth(double screenWidth) {
    if (!usesLargeUiScale) return 360;
    final w = screenWidth * desktopPosDialogWidthFactor;
    return w.clamp(desktopPosDialogMinWidth, screenWidth - 48);
  }
}
