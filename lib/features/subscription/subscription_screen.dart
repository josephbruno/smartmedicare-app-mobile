import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/plan_catalog.dart';
import '../../data/models/subscription_info.dart';
import 'subscription_actions.dart';

String _normalizedBillingCycle(String? value) =>
    value == 'yearly' ? 'yearly' : 'monthly';

String _planActionLabel({
  required String planName,
  required bool isSamePlan,
  required int candidateIndex,
  required int currentIndex,
  required String activeCycle,
  required String selectedCycle,
}) {
  if (isSamePlan) {
    if (activeCycle == selectedCycle) return 'Current Plan';
    return selectedCycle == 'yearly'
        ? 'Upgrade to Yearly'
        : 'Downgrade to Monthly';
  }
  if (currentIndex >= 0 && candidateIndex > currentIndex) {
    return 'Upgrade to $planName';
  }
  if (currentIndex >= 0 && candidateIndex < currentIndex) {
    return 'Downgrade to $planName';
  }
  return 'Switch to $planName';
}

bool _isUpgradeAction(String action) => action.startsWith('Upgrade');

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthSession>().refreshMe();
    });
  }

  Future<(SubscriptionInfo, PlanCatalog?)> _load() async {
    final services = context.read<AppServices>();
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

  Future<void> _confirmPlanChange({
    required PlanCatalogItem plan,
    required String actionLabel,
    required String cycle,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x990F172A),
      builder: (dialogContext) => _PlanChangeDialog(
        plan: plan,
        actionLabel: actionLabel,
        cycle: cycle,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed == true && mounted) {
      await _open('plans', planSlug: plan.slug, cycle: cycle);
    }
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

          if (MediaQuery.sizeOf(context).width >= 1100) {
            return _DesktopSubscriptionPage(
              subscription: s,
              catalog: catalog,
              state: state,
              stateColor: color,
              cycle: _cycle,
              opening: _opening,
              onCycleChanged: (value) => setState(() => _cycle = value),
              onPlanSelected: (plan, actionLabel) => _confirmPlanChange(
                plan: plan,
                actionLabel: actionLabel,
                cycle: _cycle,
              ),
              onRenew: () => _open(
                'plans',
                planSlug: catalog?.currentSlug,
                cycle: s.billingCycle ?? _cycle,
              ),
              onPayments: () => _open('payments'),
            );
          }

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
                        ...([...s.modules]..sort((a, b) =>
                                (b.included ? 1 : 0) - (a.included ? 1 : 0)))
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
                  final activeCycle = _normalizedBillingCycle(
                    s.billingCycle ?? catalog.billingCycle,
                  );
                  final isSamePlan = plan.slug == catalog.currentSlug;
                  final isCurrent = isSamePlan && _cycle == activeCycle;
                  final label = _planActionLabel(
                    planName: plan.name,
                    isSamePlan: isSamePlan,
                    candidateIndex: entry.key,
                    currentIndex: currentIndex,
                    activeCycle: activeCycle,
                    selectedCycle: _cycle,
                  );
                  final isUpgrade = _isUpgradeAction(label);
                  final price = plan.priceFor(_cycle);
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
                                        : () => _confirmPlanChange(
                                              plan: plan,
                                              actionLabel: label,
                                              cycle: _cycle,
                                            ),
                                    child: Text(label),
                                  )
                                : OutlinedButton(
                                    onPressed:
                                        isCurrent || _opening || price <= 0
                                            ? null
                                            : () => _confirmPlanChange(
                                                  plan: plan,
                                                  actionLabel: label,
                                                  cycle: _cycle,
                                                ),
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

class _PlanChangeDialog extends StatelessWidget {
  const _PlanChangeDialog({
    required this.plan,
    required this.actionLabel,
    required this.cycle,
    required this.onCancel,
    required this.onConfirm,
  });

  final PlanCatalogItem plan;
  final String actionLabel;
  final String cycle;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final isUpgrade = _isUpgradeAction(actionLabel);
    final isDowngrade = actionLabel.startsWith('Downgrade');
    final actionName = isUpgrade
        ? 'Upgrade'
        : isDowngrade
            ? 'Downgrade'
            : 'Continue';
    final cycleLabel = cycle == 'yearly' ? 'yearly' : 'monthly';
    final actionIcon = isUpgrade
        ? Icons.trending_up_rounded
        : isDowngrade
            ? Icons.trending_down_rounded
            : Icons.swap_horiz_rounded;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x400F172A),
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: -60,
                bottom: -100,
                child: Container(
                  height: 180,
                  width: 240,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(120),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 26, 22, 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 470;
                    final content = _PlanChangeDialogContent(
                      plan: plan,
                      title: '$actionLabel?',
                      actionName: actionName,
                      cycleLabel: cycleLabel,
                      actionIcon: actionIcon,
                      isUpgrade: isUpgrade,
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: onCancel,
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded,
                                color: AppTheme.textSecondary),
                          ),
                        ),
                        if (compact)
                          content
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const _PlanChangeIllustration(),
                              const SizedBox(width: 22),
                              Expanded(child: content),
                            ],
                          ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: onCancel,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(96, 44),
                                foregroundColor: AppTheme.textPrimary,
                                side:
                                    const BorderSide(color: Color(0xFFD5E1F2)),
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: onConfirm,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(190, 44),
                                backgroundColor: AppTheme.primary,
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded,
                                  size: 18),
                              label: Text('Confirm $actionName'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanChangeDialogContent extends StatelessWidget {
  const _PlanChangeDialogContent({
    required this.plan,
    required this.title,
    required this.actionName,
    required this.cycleLabel,
    required this.actionIcon,
    required this.isUpgrade,
  });

  final PlanCatalogItem plan;
  final String title;
  final String actionName;
  final String cycleLabel;
  final IconData actionIcon;
  final bool isUpgrade;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              )),
          const SizedBox(height: 7),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
              children: [
                const TextSpan(
                    text:
                        'You will be redirected to billing to continue with '),
                TextSpan(
                  text: plan.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: ' on the $cycleLabel plan.'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0FBF5), Color(0xFFE7F8F3)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD0F0DD)),
            ),
            child: Column(
              children: [
                _PlanChangeBenefit(
                  icon: actionIcon,
                  color: AppTheme.accent,
                  text: cycleLabel == 'yearly'
                      ? 'Save more with yearly billing'
                      : 'Flexible monthly billing',
                ),
                const SizedBox(height: 9),
                _PlanChangeBenefit(
                  icon: Icons.workspace_premium_rounded,
                  color: const Color(0xFFF59E0B),
                  text: '$actionName with ${plan.name} plan',
                ),
                const SizedBox(height: 9),
                const _PlanChangeBenefit(
                  icon: Icons.verified_user_outlined,
                  color: AppTheme.accent,
                  text: 'No interruption to your clinic data',
                ),
              ],
            ),
          ),
        ],
      );
}

class _PlanChangeBenefit extends StatelessWidget {
  const _PlanChangeBenefit({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
        ],
      );
}

class _PlanChangeIllustration extends StatelessWidget {
  const _PlanChangeIllustration();

  @override
  Widget build(BuildContext context) => Container(
        height: 172,
        width: 172,
        decoration: const BoxDecoration(
          color: Color(0xFFEAF3FF),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.calendar_month_rounded,
                size: 84, color: AppTheme.primary),
            Positioned(
              right: 18,
              bottom: 22,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trending_up_rounded,
                    size: 24, color: Colors.white),
              ),
            ),
            const Positioned(
              top: 26,
              right: 24,
              child: Icon(Icons.auto_awesome_rounded,
                  size: 18, color: Color(0xFF60A5FA)),
            ),
          ],
        ),
      );
}

class _DesktopSubscriptionPage extends StatelessWidget {
  const _DesktopSubscriptionPage({
    required this.subscription,
    required this.catalog,
    required this.state,
    required this.stateColor,
    required this.cycle,
    required this.opening,
    required this.onCycleChanged,
    required this.onPlanSelected,
    required this.onRenew,
    required this.onPayments,
  });

  final SubscriptionInfo subscription;
  final PlanCatalog? catalog;
  final String state;
  final Color stateColor;
  final String cycle;
  final bool opening;
  final ValueChanged<String> onCycleChanged;
  final void Function(PlanCatalogItem plan, String actionLabel) onPlanSelected;
  final VoidCallback onRenew;
  final VoidCallback onPayments;

  @override
  Widget build(BuildContext context) {
    final plans = catalog?.plans ?? const <PlanCatalogItem>[];
    final currentSlug = catalog?.currentSlug ?? subscription.planSlug;
    final activeCycle = _normalizedBillingCycle(
      subscription.billingCycle ?? catalog?.billingCycle,
    );
    final currentIndex = plans.indexWhere((plan) => plan.slug == currentSlug);
    final current = catalog?.current;
    final included = current != null && current.features.isNotEmpty
        ? current.features
        : subscription.modules
            .where((module) => module.included)
            .map((module) => module.label)
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('SETTINGS',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: .8,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary)),
                  SizedBox(height: 4),
                  Text('Subscription & Plans',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                  SizedBox(height: 4),
                  Text(
                      'Choose the plan that fits your clinic. Upgrade, downgrade or manage your subscription anytime.',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Container(
              height: 116,
              width: 410,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 18),
                      child: Text(
                        'Powering\nHealthier Pets,\nHappier Clinics',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF365A93),
                        ),
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Image(
                      image: AssetImage(
                          'assets/branding/pet-hero-transparent.png'),
                      width: 210,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD7E6FB)),
          ),
          child: Row(
            children: [
              const _SubscriptionTab(
                icon: Icons.workspace_premium_outlined,
                label: 'Plans & Pricing',
                selected: true,
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'monthly', label: Text('Monthly')),
                  ButtonSegment(value: 'yearly', label: Text('Yearly')),
                ],
                selected: {cycle},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    onCycleChanged(selection.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (plans.isEmpty)
          const _SubscriptionEmptyPlans()
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < plans.length; index++) ...[
                if (index > 0) const SizedBox(width: 14),
                Expanded(
                  child: _DesktopPlanCard(
                    plan: plans[index],
                    cycle: cycle,
                    isCurrent: plans[index].slug == currentSlug &&
                        cycle == activeCycle,
                    actionLabel: _planActionLabel(
                      planName: plans[index].name,
                      isSamePlan: plans[index].slug == currentSlug,
                      candidateIndex: index,
                      currentIndex: currentIndex,
                      activeCycle: activeCycle,
                      selectedCycle: cycle,
                    ),
                    opening: opening,
                    onSelected: () => onPlanSelected(
                      plans[index],
                      _planActionLabel(
                        planName: plans[index].name,
                        isSamePlan: plans[index].slug == currentSlug,
                        candidateIndex: index,
                        currentIndex: currentIndex,
                        activeCycle: activeCycle,
                        selectedCycle: cycle,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: _CurrentPlanDetails(
                subscription: subscription,
                state: state,
                stateColor: stateColor,
                planName:
                    current?.name ?? subscription.planName ?? 'Current plan',
                opening: opening,
                onRenew: onRenew,
                onPayments: onPayments,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 5,
              child: _IncludedPlanFeatures(features: included),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 17, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                  'Payment opens in your browser with the selected plan. After paying, return here and refresh.',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubscriptionTab extends StatelessWidget {
  const _SubscriptionTab(
      {required this.icon, required this.label, this.selected = false});
  final IconData icon;
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: const Color(0xFF93C5FD)) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 17,
              color: selected ? AppTheme.primary : AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppTheme.primary : AppTheme.textPrimary)),
        ]),
      );
}

class _DesktopPlanCard extends StatelessWidget {
  const _DesktopPlanCard({
    required this.plan,
    required this.cycle,
    required this.isCurrent,
    required this.actionLabel,
    required this.opening,
    required this.onSelected,
  });

  final PlanCatalogItem plan;
  final String cycle;
  final bool isCurrent;
  final String actionLabel;
  final bool opening;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final highlight = isCurrent
        ? AppTheme.accent
        : plan.isHighlighted
            ? AppTheme.primary
            : const Color(0xFFCFE0FA);
    final icon = isCurrent
        ? Icons.apartment_rounded
        : plan.isHighlighted
            ? Icons.groups_rounded
            : Icons.inventory_2_outlined;
    return Container(
      height: 440,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFF5FFFA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight,
          width: isCurrent || plan.isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.isHighlighted && !isCurrent)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: EdgeInsets.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text(
                  '★ Most Popular',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: highlight.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: highlight, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(
                      plan.description ?? 'Complete clinic solution',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                const Icon(Icons.check_circle,
                    color: AppTheme.accent, size: 21),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${formatInr(plan.priceFor(cycle))} / ${cycle == 'yearly' ? 'year' : 'month'}',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const Text('Inclusive of 18% GST',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          ...plan.features.take(6).map(_PlanFeature.new),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: isCurrent
                ? FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle, size: 17),
                    label: const Text('Current Plan'),
                  )
                : _isUpgradeAction(actionLabel)
                    ? FilledButton(
                        onPressed: opening ? null : onSelected,
                        child: Text(actionLabel),
                      )
                    : OutlinedButton(
                        onPressed: opening ? null : onSelected,
                        child: Text(actionLabel),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PlanFeature extends StatelessWidget {
  const _PlanFeature(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        const Icon(Icons.check_circle, size: 16, color: AppTheme.accent),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)))
      ]));
}

class _CurrentPlanDetails extends StatelessWidget {
  const _CurrentPlanDetails({
    required this.subscription,
    required this.state,
    required this.stateColor,
    required this.planName,
    required this.opening,
    required this.onRenew,
    required this.onPayments,
  });

  final SubscriptionInfo subscription;
  final String state;
  final Color stateColor;
  final String planName;
  final bool opening;
  final VoidCallback onRenew;
  final VoidCallback onPayments;

  @override
  Widget build(BuildContext context) => _SubscriptionPanel(
        icon: Icons.workspace_premium_rounded,
        title: 'Current Plan Details',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAFBF2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(planName,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                        Text(
                          state == 'trial'
                              ? 'Free trial'
                              : subscription.billingCycle == 'yearly'
                                  ? 'Billed yearly'
                                  : 'Billed monthly',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    subscription.stateLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: stateColor,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SubscriptionFact(
                icon: Icons.calendar_today_outlined,
                label: 'Valid until',
                value: formatSubscriptionDate(subscription.expiresAt)),
            _SubscriptionFact(
                icon: Icons.schedule_outlined,
                label: 'Days remaining',
                value: '${subscription.liveDaysRemaining} days'),
            _SubscriptionFact(
                icon: Icons.play_arrow_rounded,
                label: 'Started on',
                value: formatSubscriptionDate(subscription.startsAt)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: FilledButton.icon(
                        onPressed: opening ? null : onRenew,
                        icon: const Icon(Icons.refresh, size: 17),
                        label: const Text('Renew Plan'))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: opening ? null : onPayments,
                        icon: const Icon(Icons.receipt_long_outlined, size: 17),
                        label: const Text('Payments & Invoices'))),
              ],
            ),
          ],
        ),
      );
}

class _IncludedPlanFeatures extends StatelessWidget {
  const _IncludedPlanFeatures({required this.features});
  final List<String> features;
  @override
  Widget build(BuildContext context) => _SubscriptionPanel(
      icon: Icons.star_rounded,
      title: 'Included in your plan',
      subtitle: 'Complete features available with your current plan',
      child: LayoutBuilder(builder: (context, c) {
        final split = (features.length / 2).ceil();
        final left = features.take(split);
        final right = features.skip(split);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child:
                  Column(children: left.map((f) => _PlanFeature(f)).toList())),
          const SizedBox(width: 20),
          Expanded(
              child:
                  Column(children: right.map((f) => _PlanFeature(f)).toList()))
        ]);
      }));
}

class _SubscriptionPanel extends StatelessWidget {
  const _SubscriptionPanel(
      {required this.icon,
      required this.title,
      required this.child,
      this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: const Color(0xFFE8F2FF),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 21, color: AppTheme.primary)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary))
              ]))
        ]),
        const SizedBox(height: 12),
        child
      ]));
}

class _SubscriptionFact extends StatelessWidget {
  const _SubscriptionFact(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary))),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
      ]));
}

class _SubscriptionEmptyPlans extends StatelessWidget {
  const _SubscriptionEmptyPlans();
  @override
  Widget build(BuildContext context) => const SizedBox(
      height: 220,
      child: Center(
          child: Text('Plan options are not available right now.',
              style: TextStyle(color: AppTheme.textSecondary))));
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
