import 'package:flutter/material.dart';

import '../../../core/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';

class AuthMarketingPanel extends StatelessWidget {
  const AuthMarketingPanel({super.key});

  static const _features = [
    (
      Icons.point_of_sale_rounded,
      'Fast POS Checkout',
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
      Icons.verified_user_outlined,
      'Secure PIN Unlock',
      'Quick access, safe sessions',
    ),
  ];

  static const _stats = [
    (Icons.receipt_long_outlined, '10,000+', 'Invoices Created'),
    (Icons.storefront_outlined, '500+', 'Happy Clinics'),
    (Icons.verified_outlined, '99.9%', 'Uptime'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = AppConfig.usesLargeUiScale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _VetBadge(),
        const SizedBox(height: 20),
        Row(
          children: [
            AppLogo(size: isWide ? 56 : 48),
            const SizedBox(width: 14),
            Text(
              'Maran Billing',
              style: TextStyle(
                fontSize: isWide ? 28 : 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0C4A6E),
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Modern billing software for veterinary clinics & pet shops',
          style: TextStyle(
            fontSize: isWide ? 32 : 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.5,
            color: const Color(0xFF1D4ED8),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Manage billing, inventory, EMR and more — built for busy clinics and retail counters.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: isWide ? 16 : 14,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCol = constraints.maxWidth >= 520;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: _features
                  .map(
                    (f) => SizedBox(
                      width: twoCol
                          ? (constraints.maxWidth - 14) / 2
                          : constraints.maxWidth,
                      child: _FeatureCard(
                        icon: f.$1,
                        title: f.$2,
                        subtitle: f.$3,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        const _StatsBar(),
        const SizedBox(height: 20),
        Container(
          height: isWide ? 160 : 132,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Image.asset(
                'assets/branding/pet-hero.png',
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VetBadge extends StatelessWidget {
  const _VetBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets_rounded, size: 15, color: Color(0xFF2563EB)),
          SizedBox(width: 6),
          Text(
            'Veterinary & Pet Retail',
            style: TextStyle(
              color: Color(0xFF1D4ED8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
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
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
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
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Color(0xFF93C5FD),
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        return Wrap(
          spacing: compact ? 16 : 24,
          runSpacing: 12,
          children: AuthMarketingPanel._stats
              .map(
                (s) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.$1, size: 18, color: const Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.$2,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          s.$3,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
              .toList(),
        );
      },
    );
  }
}
