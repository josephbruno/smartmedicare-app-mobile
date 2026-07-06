import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../core/widgets/app_logo.dart';

class SubscriptionExpiredScreen extends StatelessWidget {
  const SubscriptionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppConfig.usesLargeUiScale
                ? AppConfig.desktopFormCardMaxWidth
                : 420,
          ),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 64),
                  const SizedBox(height: 16),
                  Text('Subscription expired', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  const Text('Your shop subscription is no longer active. Please renew to continue using the app.'),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/dashboard'),
                    child: const Text('Back'),
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
