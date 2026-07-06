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

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppConfig.usesLargeUiScale;
    final size = MediaQuery.sizeOf(context);

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
                    horizontal: isDesktop ? 40 : 20,
                    vertical: isDesktop ? 32 : 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _HeaderCard(
                        title: title,
                        subtitle: subtitle,
                        secondaryText: secondaryText,
                        loading: loading,
                        error: error,
                      ),
                      SizedBox(height: isDesktop ? 32 : 24),
                      pinEntry,
                      if (footer != null) ...[
                        SizedBox(height: isDesktop ? 20 : 16),
                        footer!,
                      ],
                    ],
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
  });

  final String title;
  final String subtitle;
  final String? secondaryText;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppConfig.usesLargeUiScale;
    final initial = subtitle.trim().isNotEmpty
        ? subtitle.trim()[0].toUpperCase()
        : '?';

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isDesktop ? 520 : 400),
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
            child: AppLogo(size: isDesktop ? 72 : 60),
          ),
          SizedBox(height: isDesktop ? 28 : 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                  fontSize: isDesktop ? 32 : 26,
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
                  radius: isDesktop ? 18 : 16,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: isDesktop ? 16 : 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (secondaryText != null) ...[
            SizedBox(height: isDesktop ? 18 : 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: AppTheme.textSecondary.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  secondaryText!,
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 14,
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
              height: 26,
              width: 26,
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
