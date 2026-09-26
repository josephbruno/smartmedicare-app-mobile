import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/plan_catalog.dart';
import '../../data/models/subscription_info.dart';

/// Shown when a screen's module isn't in the organization's subscription plan
/// (capability allowed for the clinic type but locked by the plan). Data in that
/// module is kept and returns on upgrade.
class UpgradeRequiredScreen extends StatefulWidget {
  const UpgradeRequiredScreen({super.key, required this.capability});

  final String capability;

  @override
  State<UpgradeRequiredScreen> createState() => _UpgradeRequiredScreenState();
}

class _UpgradeRequiredScreenState extends State<UpgradeRequiredScreen> {
  late final Future<(SubscriptionInfo?, PlanCatalog?)> _future = _load();

  Future<(SubscriptionInfo?, PlanCatalog?)> _load() async {
    final services = context.read<AppServices>();
    final sub = await services.subscription.get().then<SubscriptionInfo?>((s) => s).catchError((_) => null);
    final plans = await services.subscription.plans().then<PlanCatalog?>((c) => c).catchError((_) => null);
    return (sub, plans);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthSession>();
    return FutureBuilder<(SubscriptionInfo?, PlanCatalog?)>(
      future: _future,
      builder: (context, snap) {
        final (sub, catalog) = snap.data ?? (null, null);
        PlanModuleInfo? module;
        for (final m in sub?.modules ?? const <PlanModuleInfo>[]) {
          if (m.capabilities.contains(widget.capability) || m.key == widget.capability) {
            module = m;
            break;
          }
        }
        final label = module?.label ?? 'This feature';
        final unlocking = (catalog?.plans ?? const <PlanCatalogItem>[])
            .where((p) => p.slug != catalog?.currentSlug && module != null && p.modules.contains(module.key))
            .toList();
        final canManage = sub?.canManage ?? auth.isSuperAdmin;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.lock_outline, size: 30, color: Color(0xFFEA580C)),
                      ),
                      const SizedBox(height: 16),
                      Text("$label isn't in your plan",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        'Your ${sub?.planName != null ? '${sub!.planName} plan' : 'current plan'} doesn\'t include '
                        '$label. Any data you already have is kept safe and comes back as soon as you upgrade.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
                      ),
                      if (snap.connectionState == ConnectionState.waiting) ...[
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(),
                      ],
                      if (unlocking.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('AVAILABLE ON',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final p in unlocking)
                              Chip(
                                avatar: const Icon(Icons.check_circle, size: 18, color: AppTheme.accent),
                                label: Text(p.name),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          if (canManage)
                            FilledButton.icon(
                              onPressed: () => context.go('/settings/subscription'),
                              icon: const Icon(Icons.trending_up),
                              label: const Text('View plans & upgrade'),
                            ),
                          OutlinedButton(
                            onPressed: () => context.go(auth.homeRoute),
                            child: const Text('Back to dashboard'),
                          ),
                        ],
                      ),
                      if (!canManage) ...[
                        const SizedBox(height: 10),
                        const Text('Ask your organization owner to upgrade the plan.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
