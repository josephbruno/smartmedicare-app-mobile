import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// Material theme that mirrors the web app's Naive UI theme overrides
/// (`frontend/src/App.vue`). Raw values live in [AppTokens].
class AppTheme {
  // Brand colors (kept as aliases so existing screens keep compiling).
  static const Color primary = AppTokens.primary;
  static const Color primaryDark = AppTokens.primaryHover;
  static const Color accent = AppTokens.success;
  static const Color warning = AppTokens.warning;
  static const Color danger = AppTokens.error;
  static const Color background = AppTokens.bgSecondary;
  static const Color surface = AppTokens.bgPrimary;
  static const Color textPrimary = AppTokens.text1;
  static const Color textSecondary = AppTokens.text3;

  /// Inter — the web's `--font-family-sans`.
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

  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        borderSide: BorderSide(color: color, width: width),
      );

  /// Builds the light theme. [desktop] is true on web & native desktop.
  /// Sizes match the web at 100% zoom; the width-based zoom tiers from the
  /// web are applied globally via `MediaQuery.textScaler`.
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
        surface: surface,
        outline: AppTokens.border,
        outlineVariant: AppTokens.borderSubtle,
      ),
      scaffoldBackgroundColor: background,
      dividerColor: AppTokens.borderSubtle,
    );

    final double defaultIconSize = desktop ? 20 : 22;
    final double appBarIconSize = desktop ? 20 : 22;

    return base.copyWith(
      dividerTheme: const DividerThemeData(
        color: AppTokens.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        alignment: Alignment.center,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: surface,
        surfaceTintColor: surface,
        elevation: 8,
        shadowColor: const Color(0x1A0F172A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusModal)),
        titleTextStyle: _inter(
            color: textPrimary,
            fontSize: AppTokens.fontLg,
            fontWeight: FontWeight.w600),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppTokens.radiusModal)),
        ),
        showDragHandle: false,
      ),
      iconTheme: IconThemeData(color: AppTokens.menuIcon, size: defaultIconSize),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: surface,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppTokens.border)),
        iconTheme: IconThemeData(color: textPrimary, size: appBarIconSize),
        titleTextStyle: _inter(
          color: textPrimary,
          fontSize: AppTokens.fontLg,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: const BorderSide(color: AppTokens.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        hintStyle: _inter(
            color: AppTokens.placeholder,
            fontSize: AppTokens.fontBase,
            fontWeight: FontWeight.w400),
        labelStyle: _inter(
            color: AppTokens.text2,
            fontSize: AppTokens.fontBase,
            fontWeight: FontWeight.w500),
        floatingLabelStyle: _inter(
            color: AppTokens.text2,
            fontSize: AppTokens.fontBase,
            fontWeight: FontWeight.w500),
        prefixIconColor: AppTokens.placeholder,
        suffixIconColor: AppTokens.placeholder,
        border: _inputBorder(AppTokens.border),
        enabledBorder: _inputBorder(AppTokens.border),
        disabledBorder: _inputBorder(AppTokens.borderSubtle),
        focusedBorder: _inputBorder(primary, 1.5),
        errorBorder: _inputBorder(danger),
        focusedErrorBorder: _inputBorder(danger, 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(background: primary, foreground: Colors.white),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(background: primary, foreground: Colors.white),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        // Naive "default" button: white, grey border, dark text.
        style: _buttonStyle(foreground: AppTokens.text2).copyWith(
          side: WidgetStateProperty.resolveWith((states) => BorderSide(
                color: states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)
                    ? primary
                    : AppTokens.border,
              )),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)
                  ? primary
                  : AppTokens.text2),
          backgroundColor: const WidgetStatePropertyAll(surface),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(48, AppTokens.heightSmall),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: _inter(
            fontSize: AppTokens.fontControl,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppTokens.menuIcon,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppTokens.bgTertiary,
        side: const BorderSide(color: AppTokens.border),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusXs)),
        labelStyle: _inter(
            color: AppTokens.text2,
            fontSize: AppTokens.fontSm,
            fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: AppTokens.text2,
        indicatorColor: primary,
        dividerColor: AppTokens.border,
        labelStyle: _inter(
            fontSize: AppTokens.fontBase, fontWeight: FontWeight.w600),
        unselectedLabelStyle: _inter(
            fontSize: AppTokens.fontBase, fontWeight: FontWeight.w500),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppTokens.bgTertiary),
        headingTextStyle: _inter(
            color: AppTokens.text2,
            fontSize: AppTokens.fontControl,
            fontWeight: FontWeight.w600),
        dataTextStyle: _inter(
            color: AppTokens.text1,
            fontSize: AppTokens.fontControl,
            fontWeight: FontWeight.w400),
        dividerThickness: 1,
        headingRowHeight: AppTokens.heightMedium + 4,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusXs)),
        side: const BorderSide(color: AppTokens.inputBorder, width: 1.2),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? primary : AppTokens.inputBorder),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: AppTokens.border),
        ),
        textStyle: _inter(color: AppTokens.text1, fontSize: AppTokens.fontBase),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppTokens.text1,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        textStyle: _inter(color: Colors.white, fontSize: AppTokens.fontSm),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        contentTextStyle: _inter(
          fontWeight: FontWeight.w500,
          fontSize: AppTokens.fontBase,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppTokens.menuIcon,
        textColor: AppTokens.text1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      ),
      // Web typography: Typography h1 28 / h2 22 / h3 18, body 13–14.
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: _inter(
            color: textPrimary, fontSize: 48, fontWeight: FontWeight.w700),
        displayMedium: _inter(
            color: textPrimary, fontSize: 40, fontWeight: FontWeight.w700),
        displaySmall: _inter(
            color: textPrimary, fontSize: 32, fontWeight: FontWeight.w700),
        headlineLarge: _inter(
            color: textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
        headlineMedium: _inter(
            color: textPrimary,
            fontSize: AppTokens.font3xl,
            fontWeight: FontWeight.w700),
        headlineSmall: _inter(
            color: textPrimary,
            fontSize: AppTokens.font2xl,
            fontWeight: FontWeight.w600),
        titleLarge: _inter(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: _inter(
          color: textPrimary,
          fontSize: AppTokens.fontLg,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: _inter(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: _inter(
          color: textPrimary,
          fontSize: AppTokens.fontBase,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: _inter(
          color: AppTokens.text2,
          fontSize: AppTokens.fontControl,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: _inter(
          color: textSecondary,
          fontSize: AppTokens.fontSm,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: _inter(
          color: textPrimary,
          fontSize: AppTokens.fontBase,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: _inter(
          color: textSecondary,
          fontSize: AppTokens.fontSm,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: _inter(
          color: textSecondary,
          fontSize: AppTokens.fontXs,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Naive UI button look: 40px tall, radius 8, 13px semibold label.
  static ButtonStyle _buttonStyle({
    Color? background,
    required Color foreground,
  }) {
    return ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: background != null
          ? WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return background.withValues(alpha: 0.5);
              }
              if (states.contains(WidgetState.pressed)) {
                return AppTokens.primaryPressed;
              }
              if (states.contains(WidgetState.hovered)) {
                return AppTokens.primaryHover;
              }
              return background;
            })
          : null,
      foregroundColor: WidgetStatePropertyAll(foreground),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      // Avoid Size.fromHeight — infinite width breaks buttons in a Row.
      minimumSize: const WidgetStatePropertyAll(Size(64, AppTokens.heightMedium)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      ),
      textStyle: WidgetStatePropertyAll(
        _inter(fontSize: AppTokens.fontControl, fontWeight: FontWeight.w600),
      ),
      iconSize: const WidgetStatePropertyAll(18),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
