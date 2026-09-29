import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/session/auth_session.dart';
import 'login_view_model.dart';
import 'widgets/auth_login_card.dart';
import 'widgets/auth_marketing_panel.dart';
import 'widgets/auth_page_shell.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(_fadeAnimation);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final isWide = AppConfig.usesLargeUiScale;

    if (auth.hasStoredSession && !auth.isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go(auth.hasPinSet ? '/pin' : '/set-pin');
      });
    }

    if (auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
    }

    return ChangeNotifierProvider(
      create: (c) => LoginViewModel(c.read<AuthSession>()),
      child: AuthPageShell(
        showFooter: !isWide,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: isWide
                ? LayoutBuilder(
                    builder: (context, constraints) =>
                        _DesktopAuthLayout(height: constraints.maxHeight),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 520),
                        child: _MobileAuthLayout(),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DesktopAuthLayout extends StatelessWidget {
  const _DesktopAuthLayout({required this.height});

  final double height;
  static const _cardRadius = BorderRadius.all(Radius.circular(14));

  @override
  Widget build(BuildContext context) {
    final cardHeight = height >= 728 ? 680.0 : height - 48;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: AuthMarketingPanel(panelHeight: height),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: SizedBox(
                  height: cardHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: _cardRadius,
                      border: Border.all(color: const Color(0x4794A3B8)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A0F172A),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: _cardRadius,
                      child: const AuthLoginCard(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileAuthLayout extends StatelessWidget {
  const _MobileAuthLayout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthMarketingPanel(),
        SizedBox(height: 28),
        AuthLoginCard(),
      ],
    );
  }
}
