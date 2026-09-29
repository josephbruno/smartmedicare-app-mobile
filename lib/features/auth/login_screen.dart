import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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

  static final _loginCardKey = GlobalKey();

  static BoxDecoration _frameDecoration() => BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x4794A3B8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    if (auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
    } else if (auth.hasStoredSession && !auth.isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(auth.hasPinSet ? '/pin' : '/set-pin');
      });
    }

    return AuthPageShell(
      showTopBar: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const mobileBreakpoint = 720.0;
          const sideBySideBreakpoint = 1000.0;
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;

          // Phones and narrow tablets use a vertical, scrollable flow. A side
          // panel below 1000px would leave both the hero and form too narrow.
          if (availableWidth < sideBySideBreakpoint) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: availableWidth < mobileBreakpoint ? 16 : 24,
                vertical: 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: _frameDecoration(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AuthLoginCard(key: _loginCardKey),
                          const AuthMarketingPanel(compact: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // Desktop is fluid up to 1440px rather than being locked at 1200px.
          // The width split changes slightly at wide-desktop sizes, giving the
          // form enough space without shrinking the marketing content.
          const horizontalPadding = 32.0;
          const verticalPadding = 24.0;
          final maxFrameWidth =
              (availableWidth - horizontalPadding * 2).clamp(0.0, 1440.0);
          final frameWidth = maxFrameWidth;
          final desiredHeight = frameWidth >= 1280 ? 760.0 : 680.0;
          // Never force a height larger than the viewport. Each panel can
          // scroll internally if a compact desktop is shorter than its content.
          final frameHeight =
              (availableHeight - verticalPadding * 2).clamp(0.0, desiredHeight);
          final marketingRatio = frameWidth >= 1280 ? 0.57 : 0.55;
          final marketingWidth = frameWidth * marketingRatio;
          final loginWidth = frameWidth - marketingWidth;

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Center(
              child: SizedBox(
                width: frameWidth,
                height: frameHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: _frameDecoration(),
                    child: Row(
                      children: [
                        SizedBox(
                          width: marketingWidth,
                          height: frameHeight,
                          child: AuthMarketingPanel(panelHeight: frameHeight),
                        ),
                        SizedBox(
                          width: loginWidth,
                          height: frameHeight,
                          child: AuthLoginCard(key: _loginCardKey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
