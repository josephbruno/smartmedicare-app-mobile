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
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 48 : 20,
                8,
                isWide ? 48 : 20,
                40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 1120 : 520,
                  ),
                  child: isWide
                      ? const _DesktopAuthLayout()
                      : const _MobileAuthLayout(),
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
  const _DesktopAuthLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(child: AuthMarketingPanel()),
        const SizedBox(width: 48),
        SizedBox(
          width: AppConfig.desktopFormCardMaxWidth,
          child: const AuthLoginCard(),
        ),
      ],
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
