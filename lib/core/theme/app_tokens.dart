import 'package:flutter/material.dart';

/// Design tokens mirrored from the Vue web app
/// (`frontend/src/assets/main.css` + Naive UI overrides in `App.vue`).
///
/// Keep these in sync with the web so screens look the same on every
/// platform. Prefer these constants over ad-hoc colours / radii in widgets.
abstract final class AppTokens {
  // ── Brand ────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF0B5ED7);
  static const Color primaryHover = Color(0xFF084298);
  static const Color primaryPressed = Color(0xFF06357C);
  static const Color primaryLight = Color(0xFFE7F1FF);

  // ── Semantic ─────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);
  static const Color purple = Color(0xFF7C3AED);

  // ── Neutrals ─────────────────────────────────────────────────────────
  static const Color text1 = Color(0xFF10213D); // headings / primary text
  static const Color text2 = Color(0xFF334155); // body
  static const Color text3 = Color(0xFF64748B); // muted / group titles
  static const Color placeholder = Color(0xFF94A3B8);
  static const Color menuIcon = Color(0xFF475569);
  static const Color menuText = Color(0xFF0F172A);

  static const Color bgPrimary = Color(0xFFFFFFFF);
  static const Color bgSecondary = Color(0xFFF5F8FC); // page background
  static const Color bgTertiary = Color(0xFFF1F5F9); // table header / hover
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFF1F5F9);
  static const Color inputBorder = Color(0xFFCBD5E1);

  // ── Radii ────────────────────────────────────────────────────────────
  static const double radiusXs = 4; // tags, checkboxes
  static const double radiusSm = 6; // small buttons
  static const double radiusMd = 8; // inputs, buttons, tables
  static const double radiusLg = 12; // cards
  static const double radiusModal = 16; // dialogs / drawers

  // ── Spacing ──────────────────────────────────────────────────────────
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double space2xl = 32;

  // ── Typography (px) ──────────────────────────────────────────────────
  static const double fontXs = 11;
  static const double fontSm = 12;
  static const double fontControl = 13; // buttons, tables, menu
  static const double fontBase = 14;
  static const double fontLg = 18;
  static const double fontXl = 20;
  static const double font2xl = 24;
  static const double font3xl = 26;

  // ── Control heights ──────────────────────────────────────────────────
  static const double heightSmall = 36;
  static const double heightMedium = 40;
  static const double heightLarge = 48;

  // ── Chrome ───────────────────────────────────────────────────────────
  static const double sidebarWidth = 240;
  static const double sidebarCollapsedWidth = 64;
  static const double sidebarItemHeight = 40;
  static const double sidebarIconSize = 18;
  static const double sidebarFontSize = 13;
  static const double sidebarGroupFontSize = 11;

  // ── Breakpoints (match the web's --bp-* tokens) ──────────────────────
  static const double bpMobile = 480;
  static const double bpTablet = 768;
  static const double bpLaptop = 1024;
  static const double bpDesktop = 1280;

  // ── Shadows ──────────────────────────────────────────────────────────
  static const List<BoxShadow> shadowXs = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 10, offset: Offset(0, 3)),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 28, offset: Offset(0, 12)),
  ];

  /// Card shadow used by Naive `Card` / `DataTable` overrides.
  static const List<BoxShadow> shadowCard = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Per-width UI zoom the web applies on `<html>` (see `main.css`).
  /// Below 1280px nothing is scaled.
  static double uiZoomForWidth(double width) {
    if (width >= 3440) return 1.6;
    if (width >= 2560) return 1.3;
    if (width >= 1920) return 1.1;
    if (width >= 1536) return 1.0;
    if (width >= 1280) return 0.92;
    return 1.0;
  }
}
