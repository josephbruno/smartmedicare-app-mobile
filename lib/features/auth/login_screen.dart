import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/session/auth_session.dart';
import 'login_view_model.dart';
import 'widgets/auth_login_card.dart';
import 'widgets/auth_marketing_panel.dart';
import 'widgets/auth_page_shell.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => LoginViewModel(c.read<AuthSession>()),
      child: const _LoginBody(),
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final isWide = AppConfig.usesLargeUiScale;

    if (auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
    } else if (auth.hasStoredSession && !auth.isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go(auth.hasPinSet ? '/pin' : '/set-pin');
      });
    }

    return AuthPageShell(
      showBackButton: true,
      onBack: () => context.go('/'),
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
                ? const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: AuthMarketingPanel()),
                      SizedBox(width: 48),
                      SizedBox(
                        width: AppConfig.desktopFormCardMaxWidth,
                        child: AuthLoginCard(),
                      ),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthLoginCard(),
                      SizedBox(height: 24),
                      AuthMarketingPanel(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
