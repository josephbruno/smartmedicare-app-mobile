import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  /// Inter — primary typeface for POS, dashboards, and admin UI.
  static String get fontFamily => GoogleFonts.inter().fontFamily!;

  static TextStyle _inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Builds the light theme. When [desktop] is true (web & native desktop),
  /// default icon sizes and dialog widths are enlarged. Font sizes are left
  /// unchanged here; text scaling is applied globally via `MediaQuery.textScaler`.
  static ThemeData light({bool desktop = false}) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
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
        // Headings: SemiBold (600–700)
        titleTextStyle: _inter(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
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
        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        // Body: Regular (400) / Medium (500)
        hintStyle: _inter(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w400),
        labelStyle: _inter(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        floatingLabelStyle: _inter(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
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
          textStyle: _inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: _inter(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      // Inter text scale:
      // Headings → SemiBold/Bold (600–700)
      // Body → Regular/Medium (400–500)
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: _inter(color: textPrimary, fontSize: 57, fontWeight: FontWeight.w700),
        displayMedium: _inter(color: textPrimary, fontSize: 45, fontWeight: FontWeight.w700),
        displaySmall: _inter(color: textPrimary, fontSize: 36, fontWeight: FontWeight.w700),
        headlineLarge: _inter(color: textPrimary, fontSize: 32, fontWeight: FontWeight.w700),
        headlineMedium: _inter(color: textPrimary, fontSize: 28, fontWeight: FontWeight.w600),
        headlineSmall: _inter(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w600),
        titleLarge: _inter(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleMedium: _inter(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleSmall: _inter(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: _inter(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: _inter(
          color: textSecondary,
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        bodySmall: _inter(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: _inter(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: _inter(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        labelSmall: _inter(
          color: textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
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
      textStyle: WidgetStatePropertyAll(
        _inter(
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
