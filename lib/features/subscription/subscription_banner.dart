import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import 'subscription_actions.dart';

/// Banner above the page content: the whole trial (all users), near expiry, and
/// the grace period. Only the owner (super admin) gets the payment button.
/// Also refreshes plan/validity once per app launch.
class SubscriptionBannerHost extends StatefulWidget {
  const SubscriptionBannerHost({super.key, required this.child});

  final Widget child;

  @override
  State<SubscriptionBannerHost> createState() => _SubscriptionBannerHostState();
}

class _SubscriptionBannerHostState extends State<SubscriptionBannerHost> {
  static bool _refreshedThisLaunch = false;
  static String? _dismissedFor;

  bool _opening = false;

  @override
  void initState() {
    super.initState();
    if (!_refreshedThisLaunch) {
      _refreshedThisLaunch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AuthSession>().refreshMe();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final sub = session.currentShop?.subscription;
    final signature =
        sub == null ? null : '${sub.liveState}:${sub.nearEnd}:${sub.expiresAt}';
    final show =
        sub != null && sub.needsAttention && _dismissedFor != signature;

    if (!show) return widget.child;

    final state = sub.liveState;
    final grace = state == 'grace';
    final trial = state == 'trial';
    final color = grace
        ? AppTheme.danger
        : (trial && !sub.nearEnd)
            ? AppTheme.primary
            : AppTheme.warning;
    final days = sub.liveDaysRemaining;
    final left =
        days <= 0 ? 'ends today' : '$days day${days == 1 ? '' : 's'} left';
    final owner = session.isShopOwner;
    final hint = owner ? '' : ' Contact your administrator to upgrade.';
    final text = grace
        ? 'Subscription expired on ${formatSubscriptionDate(sub.expiresAt)}. '
            'Access stops on ${formatSubscriptionDate(sub.graceEndsAt)} unless it is renewed.$hint'
        : trial
            ? 'You are on the free trial of ${sub.planName ?? 'SmartMediCare'} — $left '
                '(until ${formatSubscriptionDate(sub.expiresAt)}).$hint'
            : 'Your subscription ends '
                '${days <= 0 ? 'today' : 'in $days day${days == 1 ? '' : 's'}'} '
                '(${formatSubscriptionDate(sub.expiresAt)}).$hint';

    return Column(
      children: [
        Material(
          color: color.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                    grace
                        ? Icons.error_outline
                        : trial
                            ? Icons.info_outline
                            : Icons.schedule,
                    color: color,
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(text,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary)),
                ),
                if (owner)
                  TextButton(
                    onPressed: _opening
                        ? null
                        : () async {
                            setState(() => _opening = true);
                            await openBillingPortal(context);
                            if (mounted) setState(() => _opening = false);
                          },
                    child: Text(trial ? 'Choose a plan' : 'Renew now'),
                  ),
                IconButton(
                  tooltip: 'Dismiss',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _dismissedFor = signature),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
