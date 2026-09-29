import 'package:flutter/material.dart';

import '../../../core/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/powered_by_footer.dart';

/// Full-screen shell for PIN unlock / set-PIN flows.
class PinFullscreenLayout extends StatelessWidget {
  const PinFullscreenLayout(
      {super.key,
      required this.title,
      required this.subtitle,
      this.secondaryText,
      required this.pinEntry,
      this.error,
      this.loading = false,
      this.footer});
  final String title;
  final String subtitle;
  final String? secondaryText;
  final Widget pinEntry;
  final String? error;
  final bool loading;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final desktop = AppConfig.usesLargeUiScale;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
              Color(0xFFF8FBFF),
              Color(0xFFEAF4FF),
              Color(0xFFE1F0FF)
            ])),
        child: Stack(children: [
          Positioned(
              top: -120,
              right: -130,
              child: _GlowCircle(
                  size: size.width * .46, color: const Color(0x244BA3FF))),
          Positioned(
              bottom: -150,
              left: -110,
              child: _GlowCircle(
                  size: size.width * .44, color: const Color(0x1A22C55E))),
          if (desktop)
            Positioned(
                left: 0,
                bottom: 0,
                width: size.width * .57,
                height: size.height * .66,
                child: IgnorePointer(
                    child: Opacity(
                        opacity: .88,
                        child: Image.asset(
                            'assets/branding/clinic-hero-transparent.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter)))),
          SafeArea(
              child: Column(children: [
            Expanded(
                child: desktop
                    ? _DesktopPinLayout(
                        title: title,
                        subtitle: subtitle,
                        secondaryText: secondaryText,
                        error: error,
                        loading: loading,
                        pinEntry: pinEntry,
                        footer: footer)
                    : _MobilePinLayout(
                        title: title,
                        subtitle: subtitle,
                        secondaryText: secondaryText,
                        error: error,
                        loading: loading,
                        pinEntry: pinEntry,
                        footer: footer)),
            const PoweredByFooter(),
          ])),
        ]),
      ),
    );
  }
}

class _DesktopPinLayout extends StatelessWidget {
  const _DesktopPinLayout(
      {required this.title,
      required this.subtitle,
      required this.secondaryText,
      required this.error,
      required this.loading,
      required this.pinEntry,
      required this.footer});
  final String title;
  final String subtitle;
  final String? secondaryText;
  final String? error;
  final bool loading;
  final Widget pinEntry;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            flex: 5,
            child: _PinMarketingPane(
                title: title,
                subtitle: subtitle,
                secondaryText: secondaryText,
                error: error,
                loading: loading)),
        Expanded(
            flex: 4,
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 576),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      pinEntry,
                      if (footer != null) ...[
                        const SizedBox(height: 18),
                        footer!
                      ]
                    ])))),
      ]);
}

class _MobilePinLayout extends StatelessWidget {
  const _MobilePinLayout(
      {required this.title,
      required this.subtitle,
      required this.secondaryText,
      required this.error,
      required this.loading,
      required this.pinEntry,
      required this.footer});
  final String title;
  final String subtitle;
  final String? secondaryText;
  final String? error;
  final bool loading;
  final Widget pinEntry;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _HeaderCard(
                title: title,
                subtitle: subtitle,
                secondaryText: secondaryText,
                loading: loading,
                error: error,
                screenWidth: MediaQuery.sizeOf(context).width),
            const SizedBox(height: 28),
            pinEntry,
            if (footer != null) ...[const SizedBox(height: 16), footer!],
          ])));
}

class _PinMarketingPane extends StatelessWidget {
  const _PinMarketingPane(
      {required this.title,
      required this.subtitle,
      required this.secondaryText,
      required this.error,
      required this.loading});
  final String title;
  final String subtitle;
  final String? secondaryText;
  final String? error;
  final bool loading;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(104, 52, 36, 60),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _PinBrand(),
          const SizedBox(height: 58),
          const _PinEyebrow(),
          const SizedBox(height: 18),
          Text(title,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: const Color(0xFF08154C),
                  fontWeight: FontWeight.w800,
                  fontSize: 56,
                  letterSpacing: -1.8,
                  height: 1.05)),
          const SizedBox(height: 14),
          SizedBox(
              width: 440,
              child: Text(subtitle,
                  style: const TextStyle(
                      color: Color(0xFF60789E),
                      fontSize: 21,
                      height: 1.35,
                      fontWeight: FontWeight.w500))),
          if (secondaryText != null) ...[
            const SizedBox(height: 8),
            Text(secondaryText!,
                style: const TextStyle(color: Color(0xFF60789E), fontSize: 14))
          ],
          const SizedBox(height: 30),
          const _PinBenefitRow(),
          if (error != null) ...[
            const SizedBox(height: 18),
            SizedBox(width: 430, child: _ErrorBanner(message: error!))
          ],
        ]),
      );
}

class _PinBrand extends StatelessWidget {
  const _PinBrand();
  @override
  Widget build(BuildContext context) =>
      const Row(mainAxisSize: MainAxisSize.min, children: [
        AppLogo(size: 74, borderRadius: 0),
        SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(
              style: TextStyle(
                  color: Color(0xFF0B1A55),
                  fontSize: 36,
                  letterSpacing: -1.4,
                  height: 1),
              children: [
                TextSpan(
                    text: 'Smart',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(
                    text: 'MediCare',
                    style: TextStyle(color: Color(0xFF1463D8)))
              ])),
          SizedBox(height: 7),
          Text('SMARTER CLINICS  •  HEALTHIER LIVES',
              style: TextStyle(
                  color: Color(0xFF60789E),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6)),
        ]),
      ]);
}

class _PinEyebrow extends StatelessWidget {
  const _PinEyebrow();
  @override
  Widget build(BuildContext context) =>
      const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 34, child: Divider(color: Color(0xFF1463D8), thickness: 3)),
        SizedBox(width: 14),
        Text('SECURE ACCESS',
            style: TextStyle(
                color: Color(0xFF6B7F9F),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 3)),
      ]);
}

class _PinBenefitRow extends StatelessWidget {
  const _PinBenefitRow();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(
            child: _PinBenefit(
              icon: Icons.verified_user_rounded,
              label: 'Secure\nAccess',
              color: Color(0xFF2384FF),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _PinBenefit(
              icon: Icons.speed_rounded,
              label: 'Quick\nLogin',
              color: Color(0xFF10B981),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _PinBenefit(
              icon: Icons.lock_rounded,
              label: 'Your Data\nProtected',
              color: Color(0xFF7C3AED),
            ),
          ),
        ],
      );
}

class _PinBenefit extends StatelessWidget {
  const _PinBenefit({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 130;
          final labelWidget = Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: compact ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
              color: Color(0xFF172554),
              fontSize: 12,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          );

          return Container(
            height: 88,
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .85)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: compact
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: color, size: 28),
                      const SizedBox(height: 5),
                      labelWidget,
                    ],
                  )
                : Row(
                    children: [
                      Icon(icon, color: color, size: 30),
                      const SizedBox(width: 8),
                      Expanded(child: labelWidget),
                    ],
                  ),
          );
        },
      );
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
    final maxWidth = isWideDesktop
        ? 380.0
        : isDesktop
            ? 340.0
            : isTablet
                ? 480.0
                : 400.0;
    final logoSize = isWideDesktop
        ? 84.0
        : isDesktop
            ? 72.0
            : isTablet
                ? 68.0
                : 60.0;
    final titleFontSize = isWideDesktop
        ? 36.0
        : isDesktop
            ? 32.0
            : isTablet
                ? 30.0
                : 26.0;
    final spaceBetween = isWideDesktop
        ? 32.0
        : isDesktop
            ? 28.0
            : isTablet
                ? 24.0
                : 22.0;
    final avatarRadius = isWideDesktop
        ? 20.0
        : isDesktop
            ? 18.0
            : isTablet
                ? 17.0
                : 16.0;
    final subtitleFontSize = isWideDesktop
        ? 17.0
        : isDesktop
            ? 16.0
            : isTablet
                ? 15.5
                : 15.0;
    final secondaryFontSize = isWideDesktop
        ? 16.0
        : isDesktop
            ? 15.0
            : isTablet
                ? 14.5
                : 14.0;

    final initial =
        subtitle.trim().isNotEmpty ? subtitle.trim()[0].toUpperCase() : '?';

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
            SizedBox(
                height: isWideDesktop
                    ? 20.0
                    : isDesktop
                        ? 18.0
                        : 14.0),
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
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.danger, size: 18),
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
