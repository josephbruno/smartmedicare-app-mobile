import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/plan_catalog.dart';
import '../../data/models/subscription_info.dart';
import 'subscription_actions.dart';

/// Subscription & Plans (super admin only): current plan and validity, the
/// features it includes, and upgrade options paid on the website billing portal.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late Future<(SubscriptionInfo, PlanCatalog?)> _future;
  bool _opening = false;
  String _cycle = 'monthly';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(SubscriptionInfo, PlanCatalog?)> _load() async {
    final services = context.read<AppServices>();
    context.read<AuthSession>().refreshMe();
    final results = await Future.wait<Object?>([
      services.subscription.get(),
      services.subscription
          .plans()
          .then<PlanCatalog?>((c) => c)
          .catchError((_) => null),
    ]);
    final catalog = results[1] as PlanCatalog?;
    if (catalog?.billingCycle == 'yearly' && mounted) _cycle = 'yearly';
    return (results[0] as SubscriptionInfo, catalog);
  }

  Future<void> _open(String page, {String? planSlug, String? cycle}) async {
    setState(() => _opening = true);
    await openBillingPortal(context,
        page: page, planSlug: planSlug, billingCycle: cycle);
    if (mounted) setState(() => _opening = false);
  }

  Color _stateColor(String state) => switch (state) {
        'active' => AppTheme.accent,
        'trial' => AppTheme.primary,
        'grace' => AppTheme.warning,
        _ => AppTheme.danger,
      };

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final next = _load();
        setState(() => _future = next);
        await next;
      },
      child: FutureBuilder<(SubscriptionInfo, PlanCatalog?)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return ListView(children: [
              const SizedBox(height: 120),
              Center(
                child: Text('Could not load subscription.\n${snap.error ?? ''}',
                    textAlign: TextAlign.center),
              ),
            ]);
          }
          final (s, catalog) = snap.data!;
          final state = s.liveState;
          final color = _stateColor(state);
          final current = catalog?.current;
          final currentIndex =
              catalog?.plans.indexWhere((p) => p.slug == catalog.currentSlug) ??
                  -1;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Subscription & Plans',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              const Text(
                  'Your current plan, what it includes, and upgrade options.',
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),

              // Current plan
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Current plan',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(current?.name ?? s.planName ?? '—',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700)),
                                Text(
                                  state == 'trial' || s.status == 'trial'
                                      ? 'Free trial'
                                      : s.billingCycle == 'yearly'
                                          ? 'Billed yearly'
                                          : 'Billed monthly',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(s.stateLabel),
                            labelStyle: TextStyle(
                                color: color, fontWeight: FontWeight.w600),
                            backgroundColor: color.withValues(alpha: 0.1),
                            side: BorderSide.none,
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      _Fact(
                        label: state == 'trial'
                            ? 'Trial ends on'
                            : (state == 'grace' || state == 'expired')
                                ? 'Expired on'
                                : 'Valid until',
                        value: formatSubscriptionDate(s.expiresAt),
                      ),
                      _Fact(
                        label: 'Days remaining',
                        value: '${s.liveDaysRemaining}',
                        danger: s.nearEnd,
                      ),
                      _Fact(
                          label: 'Started on',
                          value: formatSubscriptionDate(s.startsAt)),
                      if (state == 'grace')
                        _Fact(
                            label: 'Access ends on',
                            value: formatSubscriptionDate(s.graceEndsAt),
                            danger: true),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _opening
                                ? null
                                : () => _open('plans',
                                    planSlug: catalog?.currentSlug,
                                    cycle: s.billingCycle ?? _cycle),
                            icon: const Icon(Icons.credit_card),
                            label: Text(state == 'trial'
                                ? 'Buy this plan'
                                : 'Renew plan'),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                _opening ? null : () => _open('payments'),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Payments & invoices'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Features in current plan
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Included in your plan',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (current == null || current.features.isEmpty)
                        const Text(
                            'Feature details are not available right now.',
                            style: TextStyle(color: AppTheme.textSecondary))
                      else
                        ...current.features.map((f) => _FeatureRow(f)),
                      if (s.modules.isNotEmpty) ...[
                        const Divider(height: 24),
                        const Text('Modules',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        ...([...s.modules]
                              ..sort((a, b) => (b.included ? 1 : 0) - (a.included ? 1 : 0)))
                            .map((m) => _ModuleRow(m)),
                      ],
                      const Divider(height: 24),
                      _UsageRow(
                          label: 'Branches',
                          used: s.usage['branches'],
                          max: current?.maxBranches ?? s.maxBranches),
                      _UsageRow(
                          label: 'Users',
                          used: s.usage['users'],
                          max: current?.maxUsers ?? s.maxUsers),
                      _UsageRow(
                          label: 'Products',
                          used: s.usage['products'],
                          max: current?.maxProducts ?? s.maxProducts),
                    ],
                  ),
                ),
              ),

              // Upgrade options
              if (catalog != null && catalog.plans.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Upgrade or change plan',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'monthly', label: Text('Monthly')),
                        ButtonSegment(value: 'yearly', label: Text('Yearly')),
                      ],
                      selected: {_cycle},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) =>
                          setState(() => _cycle = v.first),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...catalog.plans.asMap().entries.map((entry) {
                  final plan = entry.value;
                  final isCurrent = plan.slug == catalog.currentSlug;
                  final isUpgrade = !isCurrent &&
                      (currentIndex < 0 || entry.key > currentIndex);
                  final price = plan.priceFor(_cycle);
                  final label = isCurrent
                      ? (state == 'trial'
                          ? 'Buy ${plan.name}'
                          : 'Renew ${plan.name}')
                      : isUpgrade
                          ? 'Upgrade to ${plan.name}'
                          : 'Switch to ${plan.name}';
                  return Card(
                    margin: const EdgeInsets.only(top: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isCurrent
                            ? AppTheme.accent
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(plan.name,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ),
                              if (isCurrent)
                                const Chip(
                                    label: Text('Current'),
                                    visualDensity: VisualDensity.compact)
                              else if (plan.badgeText != null)
                                Chip(
                                    label: Text(plan.badgeText!),
                                    visualDensity: VisualDensity.compact),
                            ],
                          ),
                          Text(
                              '${formatInr(price)} / ${_cycle == 'yearly' ? 'year' : 'month'}',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700)),
                          const Text('Inclusive of 18% GST',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          ...plan.features.map((f) => _FeatureRow(f)),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: isUpgrade
                                ? FilledButton(
                                    onPressed: _opening || price <= 0
                                        ? null
                                        : () => _open('plans',
                                            planSlug: plan.slug, cycle: _cycle),
                                    child: Text(label),
                                  )
                                : OutlinedButton(
                                    onPressed: _opening || price <= 0
                                        ? null
                                        : () => _open('plans',
                                            planSlug: plan.slug, cycle: _cycle),
                                    child: Text(label),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Text(
                  'Payment opens in your browser, already signed in, with the plan selected. '
                  'After paying, come back and pull down to refresh.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 18, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.danger = false});

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppTheme.textSecondary))),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: danger ? AppTheme.danger : AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

/// A plan module: ✓ included or 🔒 needs an upgrade.
class _ModuleRow extends StatelessWidget {
  const _ModuleRow(this.module);

  final PlanModuleInfo module;

  @override
  Widget build(BuildContext context) {
    final on = module.included;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(on ? Icons.check_circle : Icons.lock_outline,
              size: 18, color: on ? AppTheme.accent : AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(module.label,
                style: TextStyle(color: on ? null : AppTheme.textSecondary)),
          ),
          if (!on)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Upgrade',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary)),
            ),
        ],
      ),
    );
  }
}

/// "2 of 3" with a bar; unlimited plans show just the count.
class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.label, this.used, this.max});

  final String label;
  final int? used;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final unlimited = max == null || max! < 0;
    final pct = (!unlimited && used != null)
        ? (max == 0 ? 1.0 : (used! / max!).clamp(0.0, 1.0))
        : null;
    final color = pct == null
        ? AppTheme.accent
        : pct >= 1
            ? AppTheme.danger
            : pct >= 0.8
                ? AppTheme.warning
                : AppTheme.accent;
    final value = unlimited
        ? (used != null ? '$used · Unlimited' : 'Unlimited')
        : (used != null ? '$used of $max' : '$max');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(color: AppTheme.textSecondary))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          if (pct != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: const Color(0xFFEEF2F7),
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
