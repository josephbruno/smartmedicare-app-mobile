import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// App-wide snackbars pinned to the top-right corner.
class AppMessenger {
  AppMessenger._();

  static final GlobalKey<ScaffoldMessengerState> rootKey =
      GlobalKey<ScaffoldMessengerState>();

  static ScaffoldMessengerState? _messenger(BuildContext context) {
    return ScaffoldMessenger.maybeOf(context) ?? rootKey.currentState;
  }

  static EdgeInsets _topRightMargin(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final top = media.padding.top + 12;
    const snackHeight = 56.0;
    final barWidth = math.min(420.0, width * 0.38).clamp(280.0, 420.0);

    return EdgeInsets.only(
      top: top,
      right: 16,
      left: width - barWidth - 16,
      bottom: height - top - snackHeight,
    );
  }

  static SnackBar _positioned(SnackBar snackBar, BuildContext context) {
    return SnackBar(
      content: snackBar.content,
      backgroundColor: snackBar.backgroundColor,
      action: snackBar.action,
      duration: snackBar.duration,
      behavior: SnackBarBehavior.floating,
      elevation: snackBar.elevation ?? 8,
      shape: snackBar.shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: _topRightMargin(context),
      padding: snackBar.padding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      clipBehavior: snackBar.clipBehavior,
      showCloseIcon: snackBar.showCloseIcon,
      closeIconColor: snackBar.closeIconColor,
      width: snackBar.width,
    );
  }

  /// Drop-in replacement for [AppMessenger.show(context,].
  static void show(BuildContext context, SnackBar snackBar) {
    final messenger = _messenger(context);
    if (messenger == null) return;
    messenger.showSnackBar(_positioned(snackBar, context));
  }

  static void showMessage(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Color? foregroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      SnackBar(
        backgroundColor: backgroundColor ?? AppTheme.textPrimary,
        duration: duration,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: foregroundColor ?? Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foregroundColor ?? Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void success(BuildContext context, String message) {
    showMessage(
      context,
      message,
      backgroundColor: AppTheme.accent,
      icon: Icons.check_circle_rounded,
    );
  }

  static void error(BuildContext context, String message) {
    showMessage(
      context,
      message,
      backgroundColor: AppTheme.danger,
      icon: Icons.error_outline_rounded,
    );
  }

  static void warning(BuildContext context, String message) {
    showMessage(
      context,
      message,
      backgroundColor: AppTheme.warning,
      icon: Icons.warning_amber_rounded,
    );
  }
}
