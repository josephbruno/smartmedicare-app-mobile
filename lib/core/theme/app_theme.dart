import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const Color primary = Color(0xFF3B82F6); // Vibrant Blue
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color accent = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444); // Red
  static const Color background = Color(0xFFF8FAFC); // Slate background
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500

  /// Builds the light theme. When [desktop] is true (web & native desktop),
  /// default icon sizes and dialog widths are enlarged. Font sizes are left
  /// unchanged here; text scaling is applied globally via `MediaQuery.textScaler`.
  static ThemeData light({bool desktop = false}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        error: danger,
        background: background,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
    );

    // Default icon size: 24 on mobile, larger on web & desktop for legibility.
    final double defaultIconSize = desktop ? 30 : 24;
    final double appBarIconSize = desktop ? 30 : 22;

    return base.copyWith(
      dialogTheme: DialogThemeData(
        alignment: Alignment.center,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: surface,
        surfaceTintColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: false,
      ),
      iconTheme: IconThemeData(color: textPrimary, size: defaultIconSize),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary, size: appBarIconSize),
        titleTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1), // Slate 200
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        hintStyle: const TextStyle(fontFamily: 'Roboto', color: textSecondary, fontSize: 14),
        labelStyle: const TextStyle(fontFamily: 'Roboto', color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
        floatingLabelStyle: const TextStyle(fontFamily: 'Roboto', color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger, width: 2),
        ),
      ),
      // Shared across Elevated / Filled / Outlined so buttons stay tappable and
      // never look undersized. Padding is at least 8dp on every side.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _primaryButtonStyle(background: primary, foreground: Colors.white),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _primaryButtonStyle(background: primary, foreground: Colors.white),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _primaryButtonStyle(
          foreground: primary,
        ).copyWith(
          side: const WidgetStatePropertyAll(
            BorderSide(color: primary, width: 1.5),
          ),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.all(8),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: const TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleSmall: const TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'Roboto',
          color: textSecondary,
          fontSize: 13.5,
          height: 1.4,
        ),
        labelMedium: const TextStyle(
          fontFamily: 'Roboto',
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Primary action button look (Filled / Elevated). Min height keeps buttons
  /// comfortable; [padding] is at least 8dp on every side app-wide.
  static ButtonStyle _primaryButtonStyle({
    Color? background,
    required Color foreground,
  }) {
    return ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: background != null
          ? WidgetStatePropertyAll(background)
          : null,
      foregroundColor: WidgetStatePropertyAll(foreground),
      // Avoid Size.fromHeight — infinite width breaks buttons in a Row.
      minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
