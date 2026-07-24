import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dashboard_data.dart';
import '../../emr/visit_billing_queue_notifier.dart';
import '../../emr/widgets/visit_billing_queue_panel.dart';
import 'dashboard_widgets.dart';

/// Branch manager ops view: branch KPIs and billing queue.
class BranchManagerDashboardSection extends StatefulWidget {
  const BranchManagerDashboardSection({super.key});

  @override
  State<BranchManagerDashboardSection> createState() => _BranchManagerDashboardSectionState();
}

class _BranchManagerDashboardSectionState extends State<BranchManagerDashboardSection> {
  late Future<DashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = context.read<AppServices>().reports.dashboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VisitBillingQueueNotifier>().startPolling(
            context.read<AppServices>().emr,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();

    return FutureBuilder<DashboardData>(
      future: _dashboardFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              auth.currentBranch?.name ?? 'Branch overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Operations at a glance for your branch.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 200,
                  child: DashboardStatCard(
                    title: "TODAY'S SALES",
                    value: '₹${d.todaySalesTotal.toStringAsFixed(0)}',
                    subtitle: '${d.todaySalesCount} invoices',
                    icon: Icons.point_of_sale_rounded,
                    color: AppTheme.primary,
                    trend: const [],
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DashboardStatCard(
                    title: 'LOW STOCK',
                    value: '${d.lowStockCount}',
                    subtitle: 'Items below reorder',
                    icon: Icons.warning_amber_rounded,
                    color: AppTheme.warning,
                    trend: const [],
                    onTap: () => context.go('/stock-alerts'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DashboardStatCard(
                    title: 'OUTSTANDING',
                    value: '₹${d.outstandingDues.toStringAsFixed(0)}',
                    subtitle: 'Unpaid balance',
                    icon: Icons.account_balance_wallet_outlined,
                    color: d.outstandingDues > 0 ? AppTheme.danger : AppTheme.accent,
                    trend: const [],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (auth.hasPermission(AppPermissions.emrVisitsBill) ||
                auth.hasPermission(AppPermissions.emrVisitsView)) ...[
              const DashboardSectionHeader(
                icon: Icons.receipt_long_outlined,
                title: 'Visits ready to bill',
              ),
              const SizedBox(height: 12),
              const VisitBillingQueuePanel(),
              const SizedBox(height: 28),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (auth.hasPermission(AppPermissions.invoicesCreate))
                  QuickActionCard(
                    icon: Icons.point_of_sale_rounded,
                    label: 'POS',
                    subtitle: 'New sale',
                    color: AppTheme.primary,
                    onTap: () => context.go('/pos'),
                  ),
                if (auth.hasPermission(AppPermissions.inventoryView))
                  QuickActionCard(
                    icon: Icons.warehouse_outlined,
                    label: 'Inventory',
                    subtitle: 'Stock levels',
                    color: AppTheme.warning,
                    onTap: () => context.go('/inventory'),
                  ),
                if (auth.hasPermission(AppPermissions.inventoryTransfer))
                  QuickActionCard(
                    icon: Icons.swap_horiz_outlined,
                    label: 'Stock transfers',
                    subtitle: 'Send / receive',
                    color: AppTheme.primary,
                    onTap: () => context.go('/stock-transfers'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
