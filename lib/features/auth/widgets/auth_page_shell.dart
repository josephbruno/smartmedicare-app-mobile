import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/powered_by_footer.dart';

/// Shared auth page background, top bar, and decorative layers.
class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    super.key,
    required this.child,
    this.showTopBar = true,
    this.showBackButton = false,
    this.onBack,
  });

  final Widget child;
  final bool showTopBar;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _AuthBackground(),
          if (AppConfig.usesLargeUiScale) const _DashboardPreview(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showTopBar)
                  _AuthTopBar(
                    showBackButton: showBackButton,
                    onBack: onBack,
                  ),
                Expanded(
                  child: child,
                ),
                const PoweredByFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEFF6FF),
            Color(0xFFF8FAFC),
            Color(0xFFF0FDFA),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: _Orb(
              size: 280,
              color: AppTheme.primary.withValues(alpha: 0.07),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -30,
            child: _Orb(
              size: 220,
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.06),
            ),
          ),
          ..._pawPrints(),
        ],
      ),
    );
  }

  List<Widget> _pawPrints() {
    const positions = <_PawPosition>[
      _PawPosition(top: 120, left: 48, size: 28, opacity: 0.06),
      _PawPosition(top: 220, right: 80, size: 22, opacity: 0.05),
      _PawPosition(bottom: 180, right: 120, size: 26, opacity: 0.05),
      _PawPosition(bottom: 100, left: 100, size: 20, opacity: 0.04),
    ];

    return positions.map((p) {
      final icon = Icon(
        Icons.pets_rounded,
        size: p.size,
        color: AppTheme.primary.withValues(alpha: p.opacity),
      );
      return Positioned(
        top: p.top,
        bottom: p.bottom,
        left: p.left,
        right: p.right,
        child: icon,
      );
    }).toList();
  }
}

class _PawPosition {
  const _PawPosition({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.opacity,
  });

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final double opacity;
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

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

class _DashboardPreview extends StatelessWidget {
  const _DashboardPreview();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -40,
      top: 80,
      bottom: 40,
      width: MediaQuery.sizeOf(context).width * 0.42,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Opacity(
            opacity: 0.35,
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dashboard',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _PreviewStat('Today\'s Sales', '₹45,890')),
                      const SizedBox(width: 12),
                      Expanded(child: _PreviewStat('Invoices', '1,248')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.show_chart_rounded,
                          color: Color(0xFF93C5FD),
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTopBar extends StatelessWidget {
  const _AuthTopBar({
    required this.showBackButton,
    this.onBack,
  });

  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final isWide = AppConfig.usesLargeUiScale;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        showBackButton ? 8 : (isWide ? 32 : 16),
        12,
        isWide ? 32 : 16,
        8,
      ),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBack,
            ),
          const AppLogo(size: 32, borderRadius: 8),
          const SizedBox(width: 10),
          Text(
            'Maran Billing',
            style: TextStyle(
              fontSize: isWide ? 18 : 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0C4A6E),
            ),
          ),
          const Spacer(),
          if (isWide) ...[
            _TopAction(
              icon: Icons.help_outline_rounded,
              label: 'Help',
              onTap: () {},
            ),
            const SizedBox(width: 16),
            _TopAction(
              icon: Icons.dark_mode_outlined,
              label: 'Dark mode',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dark mode coming soon.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
          ],
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: isWide ? const Text('Secure Access') : const SizedBox.shrink(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 16 : 10,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
  const _TopAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
