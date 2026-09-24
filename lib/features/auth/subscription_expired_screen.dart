import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../../data/models/subscription_info.dart';
import '../subscription/subscription_actions.dart';

/// Shown when the API answers 402: the plan (and its grace period) has ended.
class SubscriptionExpiredScreen extends StatefulWidget {
  const SubscriptionExpiredScreen({super.key});

  @override
  State<SubscriptionExpiredScreen> createState() => _SubscriptionExpiredScreenState();
}

class _SubscriptionExpiredScreenState extends State<SubscriptionExpiredScreen> {
  SubscriptionInfo? _info;
  bool _opening = false;
  bool _checking = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _info = context.read<AuthSession>().currentShop?.subscription;
    _load();
  }

  Future<SubscriptionInfo?> _load() async {
    try {
      final info = await context.read<AppServices>().subscription.get();
      if (mounted) setState(() => _info = info);
      return info;
    } catch (_) {
      return null;
    }
  }

  Future<void> _renew() async {
    setState(() => _opening = true);
    await openBillingPortal(context);
    if (mounted) setState(() => _opening = false);
  }

  Future<void> _checkAgain() async {
    setState(() {
      _checking = true;
      _notice = null;
    });
    final session = context.read<AuthSession>();
    final info = await _load();
    await session.refreshMe();
    if (!mounted) return;
    setState(() => _checking = false);
    if (info != null && info.isUsable) {
      context.go('/dashboard');
    } else {
      setState(() => _notice =
          'We have not received the payment yet. If you just paid, wait a minute and try again.');
    }
  }

  Future<void> _logout() async {
    await context.read<AuthSession>().logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final canManage = info?.canManage ?? context.watch<AuthSession>().isShopOwner;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppConfig.usesLargeUiScale ? AppConfig.desktopFormCardMaxWidth : 420,
            ),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 64)),
                    const SizedBox(height: 16),
                    Text('Subscription expired',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                      'Renew your plan to continue using SmartMediCare — your data is safe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    if (info != null) ...[
                      const Divider(height: 32),
                      _row('Plan', info.planName ?? '—'),
                      _row(info.status == 'trial' ? 'Trial ended on' : 'Expired on',
                          formatSubscriptionDate(info.expiresAt)),
                    ],
                    const SizedBox(height: 20),
                    if (_notice != null) ...[
                      Text(_notice!, style: const TextStyle(color: AppTheme.warning)),
                      const SizedBox(height: 12),
                    ],
                    if (canManage) ...[
                      FilledButton(
                        onPressed: _opening ? null : _renew,
                        child: Text(_opening ? 'Opening…' : 'Renew now'),
                      ),
                      const SizedBox(height: 4),
                      const Text('Opens the billing portal in your browser, already signed in.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ] else
                      const Text(
                        'Ask your organization owner to renew the subscription.',
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _checking ? null : _checkAgain,
                      child: Text(_checking ? 'Checking…' : "I've paid — refresh status"),
                    ),
                    TextButton(onPressed: _logout, child: const Text('Logout')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
