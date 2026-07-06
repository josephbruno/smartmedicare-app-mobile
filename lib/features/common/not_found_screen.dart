import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('404', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            const Text('Page not found'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
