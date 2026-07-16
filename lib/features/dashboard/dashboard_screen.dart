import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/dashboard_data.dart';
import 'dashboard_view_model.dart';
import 'widgets/dashboard_widgets.dart';
import 'widgets/branch_manager_dashboard.dart';
import 'widgets/role_dashboard_sections.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();

    if (auth.hasRole(AppRoles.cashier) && AppConfig.isCashierPlatform) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: CashierDashboardSection(),
      );
    }

    if (auth.hasRole(AppRoles.doctor)) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: DoctorDashboardSection(),
      );
    }

    if (auth.hasRole(AppRoles.branchManager) && !auth.hasRole(AppRoles.superAdmin)) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: BranchManagerDashboardSection(),
      );
    }

    return ChangeNotifierProvider(
      create: (c) => DashboardViewModel(c.read<AppServices>())..load(),
      child: Consumer<DashboardViewModel>(
        builder: (context, vm, _) {
          if (vm.loading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text(
                    'Loading dashboard metrics...',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            );
          }
          if (vm.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load dashboard',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vm.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => vm.load(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(160, 44)),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => vm.load(),
            child: _DashboardBody(d: vm.data!),
          );
        },
      ),
    );
  }
}

/// Lays out cards in a responsive grid using [Wrap] so each card keeps its
/// intrinsic height (avoids fixed aspect-ratio clipping).
Widget _wrapGrid(double maxWidth, int columns, double spacing, List<Widget> children) {
  final itemWidth = columns <= 1
      ? maxWidth
      : (maxWidth - spacing * (columns - 1)) / columns - 0.5;
  return Wrap(
    spacing: spacing,
    runSpacing: spacing,
    children: [for (final child in children) SizedBox(width: itemWidth, child: child)],
  );
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.d});

  final DashboardData d;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: _ManagerDashboardContent(d: d),
    );
  }
}

class _ManagerDashboardContent extends StatelessWidget {
  const _ManagerDashboardContent({required this.d});

  final DashboardData d;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthSession>();

    return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          const spacing = 16.0;
          final statCols = w >= 700 ? 3 : (w >= 420 ? 2 : 1);
          final qaCols = w >= 900 ? 4 : (w >= 520 ? 2 : 1);
          final wide = w >= 980;

          final quickActions = _quickActions(context, auth);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 22),
              _wrapGrid(w, statCols, spacing, _statCards()),
              const SizedBox(height: 30),
              if (d.branches != null && d.branches!.isNotEmpty)
                _branchAndSummary(context, wide: wide, width: w, spacing: spacing)
              else
                _salesSummary(context),
              if (quickActions.isNotEmpty) ...[
                const SizedBox(height: 30),
                const DashboardSectionHeader(icon: Icons.bolt_rounded, title: 'Quick Actions'),
                const SizedBox(height: 16),
                _wrapGrid(w, qaCols, spacing, quickActions),
              ],
            ],
          );
        },
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.insights_rounded, color: AppTheme.primary, size: 22),
            SizedBox(width: 10),
            Text(
              'Business Overview',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(left: 32, top: 4),
          child: Text(
            "Here's what's happening with your store today.",
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }

  List<Widget> _statCards() {
    return [
      DashboardStatCard(
        title: "TODAY'S SALES",
        value: '₹${d.todaySalesTotal.toStringAsFixed(2)}',
        subtitle: '${d.todaySalesCount} transactions today',
        icon: Icons.point_of_sale_rounded,
        color: AppTheme.primary,
        trend: syntheticTrend(d.todaySalesTotal),
      ),
      DashboardStatCard(
        title: 'MONTHLY SALES',
        value: '₹${d.monthlySalesTotal.toStringAsFixed(2)}',
        subtitle: 'Accumulated this month',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF8B5CF6),
        trend: syntheticTrend(d.monthlySalesTotal),
      ),
      DashboardStatCard(
        title: 'LOW STOCK ITEMS',
        value: '${d.lowStockCount}',
        subtitle: d.lowStockCount > 0 ? 'Requires reordering' : 'All stocks healthy',
        icon: Icons.warning_amber_rounded,
        color: d.lowStockCount > 0 ? AppTheme.warning : AppTheme.accent,
        trend: syntheticTrend(d.lowStockCount),
      ),
      DashboardStatCard(
        title: 'OUTSTANDING DUES',
        value: '₹${d.outstandingDues.toStringAsFixed(2)}',
        subtitle: 'Unpaid invoice balance',
        icon: Icons.account_balance_wallet_outlined,
        color: d.outstandingDues > 0 ? AppTheme.danger : AppTheme.accent,
        trend: syntheticTrend(d.outstandingDues),
      ),
      DashboardStatCard(
        title: "TODAY'S APPOINTMENTS",
        value: '${d.todayAppointments.count}',
        subtitle: 'Scheduled for today',
        icon: Icons.calendar_today_rounded,
        color: const Color(0xFF0EA5E9),
        trend: syntheticTrend(d.todayAppointments.count),
      ),
      DashboardStatCard(
        title: 'UPCOMING VACCINES',
        value: '${d.upcomingVaccines}',
        subtitle: 'Due within 7 days',
        icon: Icons.vaccines_outlined,
        color: AppTheme.accent,
        trend: syntheticTrend(d.upcomingVaccines),
      ),
    ];
  }

  Widget _branchAndSummary(BuildContext context, {required bool wide, required double width, required double spacing}) {
    final auth = context.read<AuthSession>();
    final canViewReports = auth.hasPermission(AppPermissions.reportsView) && auth.isSuperAdmin;
    final header = DashboardSectionHeader(
      icon: Icons.apartment_rounded,
      title: 'Performance by Branch',
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (canViewReports) _dateRangeChip(context),
          if (canViewReports)
            OutlinedButton.icon(
              onPressed: () => context.go('/reports/sales'),
              icon: const Icon(Icons.assessment_outlined, size: 18),
              label: const Text('View Report'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
        ],
      ),
    );

    if (wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final cols = c.maxWidth >= 620 ? 2 : 1;
                    return _wrapGrid(c.maxWidth, cols, spacing, _branchCards(context));
                  },
                ),
              ),
              SizedBox(width: spacing),
              Expanded(flex: 1, child: _salesSummary(context)),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 18),
        _wrapGrid(width, width >= 680 ? 2 : 1, spacing, _branchCards(context)),
        SizedBox(height: spacing),
        _salesSummary(context),
      ],
    );
  }

  Widget _dateRangeChip(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final label =
        '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, y').format(now)}';
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 2),
          lastDate: DateTime(now.year + 1),
          initialDateRange: DateTimeRange(start: start, end: now),
        );
        if (picked != null && context.mounted) context.go('/reports/sales');
      },
      icon: const Icon(Icons.calendar_today_rounded, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        foregroundColor: AppTheme.textSecondary,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }

  List<Widget> _branchCards(BuildContext context) {
    final auth = context.read<AuthSession>();
    final canViewReports =
        auth.hasPermission(AppPermissions.reportsView) && auth.isSuperAdmin;
    final branches = d.branches ?? const <BranchDashboardStat>[];
    return [
      for (var i = 0; i < branches.length; i++)
        BranchPerformanceCard(
          branch: branches[i],
          color: kChartPalette[i % kChartPalette.length],
          onView: canViewReports ? () => context.go('/reports/sales') : null,
        ),
    ];
  }

  Widget _salesSummary(BuildContext context) {
    final auth = context.read<AuthSession>();
    final canViewReports = auth.hasPermission(AppPermissions.reportsView) && auth.isSuperAdmin;
    final data = _donutData();
    final total = data.fold<double>(0, (s, e) => s + e.value);
    return SalesSummaryCard(
      data: data,
      centerValue: '₹${total.toStringAsFixed(0)}',
      onViewReport: canViewReports ? () => context.go('/reports/sales') : null,
    );
  }

  List<DonutDatum> _donutData() {
    final branches = d.branches;
    if (branches != null && branches.isNotEmpty) {
      return [
        for (var i = 0; i < branches.length; i++)
          DonutDatum(
            label: branches[i].branchName,
            value: branches[i].monthlySales,
            color: kChartPalette[i % kChartPalette.length],
          ),
      ];
    }
    final byMode = d.monthlySales.byMode;
    if (byMode.isNotEmpty) {
      final entries = byMode.entries.toList();
      return [
        for (var i = 0; i < entries.length; i++)
          DonutDatum(
            label: _titleCase(entries[i].key),
            value: entries[i].value,
            color: kChartPalette[i % kChartPalette.length],
          ),
      ];
    }
    return [
      DonutDatum(label: 'Monthly Sales', value: d.monthlySalesTotal, color: AppTheme.primary),
    ];
  }

  List<Widget> _quickActions(BuildContext context, AuthSession auth) {
    final actions = <Widget>[];
    if (auth.hasPermission(AppPermissions.invoicesCreate)) {
      actions.add(QuickActionCard(
        icon: Icons.point_of_sale_rounded,
        label: 'New Sale',
        subtitle: 'Create new invoice',
        color: AppTheme.primary,
        onTap: () => context.go('/pos'),
      ));
    }
    if (auth.hasPermission(AppPermissions.productsCreate)) {
      actions.add(QuickActionCard(
        icon: Icons.add_box_rounded,
        label: 'Add Product',
        subtitle: 'Add to inventory',
        color: AppTheme.accent,
        onTap: () => context.go('/products/new'),
      ));
    }
    if (auth.hasPermission(AppPermissions.patientAppointmentsCreate)) {
      actions.add(QuickActionCard(
        icon: Icons.event_available_rounded,
        label: 'New Appointment',
        subtitle: 'Schedule now',
        color: const Color(0xFF8B5CF6),
        onTap: () => context.go('/emr/appointments/new'),
      ));
    }
    if (auth.hasPermission(AppPermissions.inventoryTransfer)) {
      actions.add(QuickActionCard(
        icon: Icons.swap_horiz_rounded,
        label: 'Stock Transfer',
        subtitle: 'Move stock',
        color: AppTheme.warning,
        onTap: () => context.go('/stock-transfers/new'),
      ));
    }
    return actions;
  }
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s
      .split(RegExp(r'[_\s]+'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
