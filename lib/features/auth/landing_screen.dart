import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final isDesktop = AppConfig.usesLargeUiScale;

    if (auth.hasStoredSession && !auth.isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go(auth.hasPinSet ? '/pin' : '/set-pin');
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          const _LandingBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 64 : 24,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 1040 : 480,
                  ),
                  child: isDesktop
                      ? _DesktopLayout(onSignIn: () => context.go('/login'))
                      : _MobileLayout(onSignIn: () => context.go('/login')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingBackground extends StatelessWidget {
  const _LandingBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0F7FF),
            Color(0xFFF8FAFC),
            Color(0xFFF0FDF4),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _GlowOrb(
              size: 360,
              color: AppTheme.primary.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: _GlowOrb(
              size: 300,
              color: AppTheme.accent.withValues(alpha: 0.07),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandBadge(),
              const SizedBox(height: 28),
              const AppLogo(size: 96),
              const SizedBox(height: 28),
              Text(
                'Maran Billing',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 14),
              Text(
                'Pet shop billing, POS, inventory & EMR — built for busy clinics and retail counters.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.55,
                      fontWeight: FontWeight.w400,
                    ),
              ),
              const SizedBox(height: 36),
              const _FeatureGrid(),
            ],
          ),
        ),
        const SizedBox(width: 72),
        SizedBox(
          width: AppConfig.desktopFormCardMaxWidth,
          child: _SignInCard(onSignIn: onSignIn),
        ),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _BrandBadge(),
        const SizedBox(height: 24),
        const AppLogo(size: 84),
        const SizedBox(height: 24),
        Text(
          'Maran Billing',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pet shop billing & EMR',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 32),
        const _FeatureGrid(),
        const SizedBox(height: 36),
        _SignInCard(onSignIn: onSignIn),
      ],
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: const Text(
        'Veterinary & Pet Retail',
        style: TextStyle(
          color: AppTheme.primaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  static const _features = [
    (
      Icons.point_of_sale_rounded,
      'Fast POS checkout',
      'Ring up sales in seconds',
    ),
    (
      Icons.medical_services_outlined,
      'Veterinary EMR',
      'Visits, records & reminders',
    ),
    (
      Icons.inventory_2_outlined,
      'Inventory & GST',
      'Stock control and tax reports',
    ),
    (
      Icons.lock_outline_rounded,
      'Secure PIN unlock',
      'Quick access, safe sessions',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppConfig.usesLargeUiScale;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: _features
          .map(
            (f) => SizedBox(
              width: isDesktop ? 240 : double.infinity,
              child: _FeatureTile(
                icon: f.$1,
                title: f.$2,
                subtitle: f.$3,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primary.withValues(alpha: 0.15),
                  AppTheme.primary.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8EDF3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 44, 36, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.login_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome back',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in with your staff credentials to open the dashboard, POS, and clinic records.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: onSignIn,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  'Protected with PIN unlock',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
