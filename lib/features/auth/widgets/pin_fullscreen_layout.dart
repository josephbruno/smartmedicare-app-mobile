import 'package:flutter/material.dart';

import '../../../core/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';

/// Full-screen shell for PIN unlock / set-PIN flows.
class PinFullscreenLayout extends StatelessWidget {
  const PinFullscreenLayout({
    super.key,
    required this.title,
    required this.subtitle,
    this.secondaryText,
    required this.pinEntry,
    this.error,
    this.loading = false,
    this.footer,
  });

  final String title;
  final String subtitle;
  final String? secondaryText;
  final Widget pinEntry;
  final String? error;
  final bool loading;
  final Widget? footer;

  Widget _buildDesktopTwoColumnLayout({
    required String title,
    required String subtitle,
    required String? secondaryText,
    required bool loading,
    required String? error,
    required double screenWidth,
    required Widget pinEntry,
    required Widget? footer,
    required bool isWideDesktop,
  }) {
    final columnGap = isWideDesktop ? 80.0 : 60.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: _HeaderCard(
            title: title,
            subtitle: subtitle,
            secondaryText: secondaryText,
            loading: loading,
            error: error,
            screenWidth: screenWidth,
          ),
        ),
        SizedBox(width: columnGap),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              pinEntry,
              if (footer != null) ...[
                SizedBox(height: isWideDesktop ? 24.0 : 20.0),
                footer!,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileColumnLayout({
    required String title,
    required String subtitle,
    required String? secondaryText,
    required bool loading,
    required String? error,
    required double screenWidth,
    required Widget pinEntry,
    required Widget? footer,
    required double spaceBetweenElements,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _HeaderCard(
          title: title,
          subtitle: subtitle,
          secondaryText: secondaryText,
          loading: loading,
          error: error,
          screenWidth: screenWidth,
        ),
        SizedBox(height: spaceBetweenElements),
        pinEntry,
        if (footer != null) ...[
          SizedBox(height: spaceBetweenElements > 24 ? 20.0 : 16.0),
          footer!,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = AppConfig.usesLargeUiScale;

    // More granular breakpoints for responsive design
    final isWideDesktop = size.width >= 1280;
    final isTablet = size.width >= 600 && size.width < 840;

    final horizontalPadding = isWideDesktop ? 60.0 : isDesktop ? 40.0 : isTablet ? 32.0 : 20.0;
    final verticalPadding = isWideDesktop ? 48.0 : isDesktop ? 32.0 : isTablet ? 28.0 : 20.0;
    final spaceBetweenElements = isWideDesktop ? 48.0 : isDesktop ? 32.0 : isTablet ? 28.0 : 24.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F1FF),
              Color(0xFFF8FAFC),
              Color(0xFFF0FDF9),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: size.height * 0.08,
              right: -size.width * 0.12,
              child: _GlowCircle(
                size: size.width * 0.42,
                color: AppTheme.primary.withValues(alpha: 0.09),
              ),
            ),
            Positioned(
              bottom: size.height * 0.05,
              left: -size.width * 0.1,
              child: _GlowCircle(
                size: size.width * 0.35,
                color: AppTheme.accent.withValues(alpha: 0.07),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: isDesktop
                      ? _buildDesktopTwoColumnLayout(
                          title: title,
                          subtitle: subtitle,
                          secondaryText: secondaryText,
                          loading: loading,
                          error: error,
                          screenWidth: size.width,
                          pinEntry: pinEntry,
                          footer: footer,
                          isWideDesktop: isWideDesktop,
                        )
                      : _buildMobileColumnLayout(
                          title: title,
                          subtitle: subtitle,
                          secondaryText: secondaryText,
                          loading: loading,
                          error: error,
                          screenWidth: size.width,
                          pinEntry: pinEntry,
                          footer: footer,
                          spaceBetweenElements: spaceBetweenElements,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    this.secondaryText,
    required this.loading,
    this.error,
    required this.screenWidth,
  });

  final String title;
  final String subtitle;
  final String? secondaryText;
  final bool loading;
  final String? error;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final isWideDesktop = screenWidth >= 1280;
    final isDesktop = AppConfig.usesLargeUiScale;
    final isTablet = screenWidth >= 600 && screenWidth < 840;

    // Narrower max width for desktop two-column layout
    final maxWidth = isWideDesktop ? 380.0 : isDesktop ? 340.0 : isTablet ? 480.0 : 400.0;
    final logoSize = isWideDesktop ? 84.0 : isDesktop ? 72.0 : isTablet ? 68.0 : 60.0;
    final titleFontSize = isWideDesktop ? 36.0 : isDesktop ? 32.0 : isTablet ? 30.0 : 26.0;
    final spaceBetween = isWideDesktop ? 32.0 : isDesktop ? 28.0 : isTablet ? 24.0 : 22.0;
    final avatarRadius = isWideDesktop ? 20.0 : isDesktop ? 18.0 : isTablet ? 17.0 : 16.0;
    final subtitleFontSize = isWideDesktop ? 17.0 : isDesktop ? 16.0 : isTablet ? 15.5 : 15.0;
    final secondaryFontSize = isWideDesktop ? 16.0 : isDesktop ? 15.0 : isTablet ? 14.5 : 14.0;

    final initial = subtitle.trim().isNotEmpty
        ? subtitle.trim()[0].toUpperCase()
        : '?';

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AppLogo(size: logoSize),
          ),
          SizedBox(height: spaceBetween),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                  fontSize: titleFontSize,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: subtitleFontSize - 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (secondaryText != null) ...[
            SizedBox(height: isWideDesktop ? 20.0 : isDesktop ? 18.0 : 14.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: isWideDesktop ? 18.0 : 16.0,
                  color: AppTheme.textSecondary.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  secondaryText!,
                  style: TextStyle(
                    fontSize: secondaryFontSize,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (loading) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: isWideDesktop ? 30.0 : 26.0,
              width: isWideDesktop ? 30.0 : 26.0,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primary.withValues(alpha: 0.8),
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 18),
            _ErrorBanner(message: error!),
          ],
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Styled footer link for PIN screens.
class PinFooterLink extends StatelessWidget {
  const PinFooterLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.swap_horiz_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.primaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}
