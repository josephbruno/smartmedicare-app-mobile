import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/app_config.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_date_range_picker.dart';
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
      return const CashierDashboardSection();
    }

    if (auth.hasRole(AppRoles.doctor)) {
      final mobile = ResponsiveLayout.isMobile(context);
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(mobile ? 12 : 16, mobile ? 12 : 16, mobile ? 12 : 16, 28),
        child: const DoctorDashboardSection(),
      );
    }

    if (auth.hasRole(AppRoles.branchManager) && !auth.hasRole(AppRoles.superAdmin)) {
      final mobile = ResponsiveLayout.isMobile(context);
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(mobile ? 12 : 24, mobile ? 16 : 24, mobile ? 12 : 24, 36),
        child: const BranchManagerDashboardSection(),
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
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(160, 44),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
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

/// Always places the business-overview KPI cards in a single equal-width row.
Widget _statCardsRow(List<Widget> cards, {required double spacing}) {
  // Align tops without IntrinsicHeight — that combo with Flex children can
  // leave parentData dirty through flushSemantics in debug builds.
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) SizedBox(width: spacing),
        Expanded(child: cards[i]),
      ],
    ],
  );
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.d});

  final DashboardData d;

  @override
  Widget build(BuildContext context) {
    final mobile = ResponsiveLayout.isMobile(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(mobile ? 12 : 24, mobile ? 16 : 24, mobile ? 12 : 24, 36),
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
          final mobile = w < 600;
          final spacing = mobile ? 10.0 : 16.0;
          final qaCols = w >= 900 ? 4 : (w >= 520 ? 2 : 1);
          final wide = w >= 980;
          final statCols = w >= 900 ? 4 : 2;

          final quickActions = _quickActions(context, auth);
          final stats = _statCards(context, compact: mobile);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(compact: mobile),
              SizedBox(height: mobile ? 16 : 22),
              w >= 900
                  ? _statCardsRow(stats, spacing: spacing)
                  : _wrapGrid(w, statCols, spacing, stats),
              SizedBox(height: mobile ? 20 : 30),
              if (d.branches != null && d.branches!.isNotEmpty)
                _branchAndSummary(context, wide: wide, width: w, spacing: spacing)
              else
                _salesSummary(context),
              if (quickActions.isNotEmpty) ...[
                SizedBox(height: mobile ? 20 : 30),
                const DashboardSectionHeader(icon: Icons.bolt_rounded, title: 'Quick Actions'),
                const SizedBox(height: 16),
                _wrapGrid(w, qaCols, spacing, quickActions),
              ],
            ],
          );
        },
    );
  }

  Widget _header({required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.insights_rounded, color: AppTheme.primary, size: compact ? 20 : 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Business Overview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(left: compact ? 0 : 32, top: 4),
          child: const Text(
            "Here's what's happening with your store today.",
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  List<Widget> _statCards(BuildContext context, {required bool compact}) {
    return [
      DashboardStatCard(
        title: compact ? 'TODAY' : "TODAY'S SALES",
        value: formatDashboardPrice(d.todaySalesTotal),
        subtitle: compact ? '${d.todaySalesCount} bills' : '${d.todaySalesCount} transactions today',
        icon: Icons.point_of_sale_rounded,
        color: AppTheme.primary, // blue
        trend: syntheticTrend(d.todaySalesTotal),
      ),
      DashboardStatCard(
        title: compact ? 'MONTHLY' : 'MONTHLY SALES',
        value: formatDashboardPrice(d.monthlySalesTotal),
        subtitle: compact ? 'This month' : 'Accumulated this month',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF8B5CF6), // violet
        trend: syntheticTrend(d.monthlySalesTotal),
      ),
      DashboardStatCard(
        title: compact ? 'LOW STOCK' : 'LOW STOCK ITEMS',
        value: '${d.lowStockCount}',
        subtitle: d.lowStockCount > 0
            ? (compact ? 'Reorder needed' : 'Requires reordering')
            : (compact ? 'All healthy' : 'All stocks healthy'),
        icon: Icons.warning_amber_rounded,
        color: AppTheme.warning, // amber
        trend: syntheticTrend(d.lowStockCount),
        onTap: () => context.go('/stock-alerts'),
      ),
      DashboardStatCard(
        title: compact ? 'DUES' : 'OUTSTANDING DUES',
        value: formatDashboardPrice(d.outstandingDues),
        subtitle: compact ? 'Unpaid balance' : 'Unpaid invoice balance',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF0EA5E9), // sky / teal
        trend: syntheticTrend(d.outstandingDues),
      ),
    ];
  }

  Widget _branchAndSummary(BuildContext context, {required bool wide, required double width, required double spacing}) {
    final auth = context.read<AuthSession>();
    final canViewReports = auth.hasPermission(AppPermissions.reportsView);
    final header = DashboardSectionHeader(
      icon: Icons.apartment_rounded,
      title: 'Performance by Branch',
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (canViewReports) _dateRangeChip(context, compact: width < 600),
          if (canViewReports)
            OutlinedButton.icon(
              onPressed: () => context.go('/reports/sales'),
              icon: const Icon(Icons.assessment_outlined, size: 18),
              label: Text(width < 600 ? 'Report' : 'View Report'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                visualDensity: width < 600 ? VisualDensity.compact : VisualDensity.standard,
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );

    if (wide) {
      final branchCards = _branchCards(context, fillHeight: true);
      // Fixed height + stretch avoids IntrinsicHeight + Flex parentData churn that
      // trips `!semantics.parentDataDirty` during flushSemantics in debug.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 18),
          SizedBox(
            height: 360,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < branchCards.length; i++) ...[
                  if (i > 0) SizedBox(width: spacing),
                  Expanded(child: branchCards[i]),
                ],
                SizedBox(width: spacing),
                Expanded(child: _salesSummary(context, fillHeight: true)),
              ],
            ),
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

  Widget _dateRangeChip(BuildContext context, {bool compact = false}) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final label = compact
        ? DateFormat('MMM d').format(now)
        : '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, y').format(now)}';
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showAppDateRangePicker(
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
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  List<Widget> _branchCards(BuildContext context, {bool fillHeight = false}) {
    final auth = context.read<AuthSession>();
    final canViewReports = auth.hasPermission(AppPermissions.reportsView);
    final branches = d.branches ?? const <BranchDashboardStat>[];
    return [
      for (var i = 0; i < branches.length; i++)
        BranchPerformanceCard(
          branch: branches[i],
          color: kChartPalette[i % kChartPalette.length],
          onView: canViewReports ? () => context.go('/reports/sales') : null,
          fillHeight: fillHeight,
        ),
    ];
  }

  Widget _salesSummary(BuildContext context, {bool fillHeight = false}) {
    final data = _donutData();
    final total = data.fold<double>(0, (s, e) => s + e.value);
    return SalesSummaryCard(
      data: data,
      centerValue: formatDashboardPrice(total),
      fillHeight: fillHeight,
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
