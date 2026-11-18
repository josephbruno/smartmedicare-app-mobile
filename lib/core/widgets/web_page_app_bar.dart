import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Drop-in replacement for an in-page [AppBar] that renders like the web
/// page header (`page-header` / `cl-header`): bold title on the page
/// background, no divider. The shell already provides the top bar and back
/// button, so screens only need this content header.
class WebPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WebPageAppBar({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.leading,
    this.automaticallyImplyLeading = false,
    // Accepted for source compatibility with AppBar; the web look wins.
    Color? backgroundColor,
    Color? foregroundColor,
    Color? surfaceTintColor,
    double? elevation,
    double? titleSpacing,
  });

  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => Size.fromHeight(64 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < AppTokens.bpTablet;
    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      toolbarHeight: 64,
      backgroundColor: AppTokens.bgSecondary,
      surfaceTintColor: AppTokens.bgSecondary,
      foregroundColor: AppTokens.text1,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const Border(),
      titleSpacing: narrow ? 12 : 16,
      titleTextStyle: TextStyle(
        fontSize: narrow ? 20 : AppTokens.font2xl,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF0F172A),
        fontFamily: Theme.of(context).textTheme.titleLarge?.fontFamily,
      ),
      title: title,
      actions: actions == null
          ? null
          : [
              ...actions!,
              SizedBox(width: narrow ? 4 : 8),
            ],
      bottom: bottom,
    );
  }
}
