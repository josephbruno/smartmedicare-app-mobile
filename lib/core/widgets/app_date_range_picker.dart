import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shows a date range picker that stays compact on tablet/desktop.
///
/// Flutter's default fullscreen range picker stretches day cells on wide
/// windows, which breaks the range highlight and leaves large empty space.
Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialDateRange,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = 'Select date range',
  String saveText = 'Apply',
  String cancelText = 'Cancel',
}) {
  return showDateRangePicker(
    context: context,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDateRange: initialDateRange,
    helpText: helpText,
    saveText: saveText,
    cancelText: cancelText,
    initialEntryMode: DatePickerEntryMode.calendar,
    builder: (context, child) {
      if (child == null) return const SizedBox.shrink();

      final size = MediaQuery.sizeOf(context);
      final compact = size.width >= 600;
      final themed = Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppTheme.primary,
                onPrimary: Colors.white,
                surface: AppTheme.surface,
                onSurface: AppTheme.textPrimary,
              ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: AppTheme.surface,
            headerBackgroundColor: AppTheme.surface,
            headerForegroundColor: AppTheme.textPrimary,
            rangeSelectionBackgroundColor: AppTheme.primary.withValues(alpha: 0.14),
            rangeSelectionOverlayColor: WidgetStateProperty.all(
              AppTheme.primary.withValues(alpha: 0.08),
            ),
            dayOverlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppTheme.primary;
              }
              return AppTheme.primary.withValues(alpha: 0.08);
            }),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            headerHeadlineStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            headerHelpStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.textPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
        ),
        child: child,
      );

      if (!compact) return themed;

      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: (size.height * 0.88).clamp(480.0, 640.0),
          ),
          child: Material(
            color: AppTheme.surface,
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: themed,
          ),
        ),
      );
    },
  );
}
