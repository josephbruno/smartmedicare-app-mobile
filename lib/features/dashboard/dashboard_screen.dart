import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
import '../subscription/plan_guard.dart';

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
        padding: EdgeInsets.fromLTRB(
            mobile ? 12 : 16, mobile ? 12 : 16, mobile ? 12 : 16, 28),
        child: const DoctorDashboardSection(),
      );
    }

    if (auth.hasRole(AppRoles.branchManager) &&
        !auth.hasRole(AppRoles.superAdmin)) {
      final mobile = ResponsiveLayout.isMobile(context);
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            mobile ? 12 : 24, mobile ? 16 : 24, mobile ? 12 : 24, 36),
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
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.danger, size: 48),
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
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
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
Widget _wrapGrid(
    double maxWidth, int columns, double spacing, List<Widget> children) {
  final itemWidth = columns <= 1
      ? maxWidth
      : (maxWidth - spacing * (columns - 1)) / columns - 0.5;
  return Wrap(
    spacing: spacing,
    runSpacing: spacing,
    children: [
      for (final child in children) SizedBox(width: itemWidth, child: child)
    ],
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
      padding: EdgeInsets.fromLTRB(
          mobile ? 12 : 24, mobile ? 16 : 24, mobile ? 12 : 24, 36),
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
        if (w >= 900) {
          return _ReferenceDesktopDashboard(data: d, auth: auth);
        }
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
              const DashboardSectionHeader(
                  icon: Icons.bolt_rounded, title: 'Quick Actions'),
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
            Icon(Icons.insights_rounded,
                color: AppTheme.primary, size: compact ? 20 : 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Business Overview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary),
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
        subtitle: compact
            ? '${d.todaySalesCount} bills'
            : '${d.todaySalesCount} transactions today',
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

  Widget _branchAndSummary(BuildContext context,
      {required bool wide, required double width, required double spacing}) {
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
                visualDensity: width < 600
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
      DonutDatum(
          label: 'Monthly Sales',
          value: d.monthlySalesTotal,
          color: AppTheme.primary),
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
        onTap: () async {
          if (await ensurePlanAllows(context, limitResource: 'products') &&
              context.mounted) {
            context.go('/products/new');
          }
        },
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

/// Desktop composition modelled on the production web dashboard. Narrow
/// layouts continue using the wrap-based manager dashboard above.
class _ReferenceDesktopDashboard extends StatelessWidget {
  const _ReferenceDesktopDashboard({required this.data, required this.auth});
  final DashboardData data;
  final AuthSession auth;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: const Color(0xFFE8F1FF),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.dashboard_customize_outlined,
                color: AppTheme.primary, size: 20)),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          SizedBox(height: 2),
          Text('👋 Welcome back, Super!',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          SizedBox(height: 2),
          Text("Here’s what’s happening with your clinic today.",
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
        const Spacer(),
        OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.calendar_month_outlined, size: 15),
            label: Text(DateFormat('MMM d, y').format(DateTime.now())),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 28),
      Row(children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(24)),
            child: const Text('All Branches Overview',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700))),
        const SizedBox(width: 16),
        Text(
            data.branches != null && data.branches!.isNotEmpty
                ? 'Combined totals + per-branch chart (${data.branches!.length} branches)'
                : 'Combined totals + per-branch chart',
            style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 13)),
      ]),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        const gap = 14.0;
        final width = (constraints.maxWidth - gap * 3) / 4;
        return Row(children: [
          SizedBox(
              width: width,
              child: _WebMetricCard(
                  icon: Icons.shopping_bag_outlined,
                  iconColor: AppTheme.accent,
                  iconFill: const Color(0xFFD9F8E5),
                  title: "Today's Sales",
                  value: formatDashboardPrice(data.todaySalesTotal),
                  detail: '${data.todaySalesCount} invoices',
                  lineColor: AppTheme.accent)),
          const SizedBox(width: gap),
          SizedBox(
              width: width,
              child: _WebMetricCard(
                  icon: Icons.bar_chart_rounded,
                  iconColor: const Color(0xFF9333EA),
                  iconFill: const Color(0xFFF0E3FF),
                  title: 'Monthly Sales',
                  value: formatDashboardPrice(data.monthlySalesTotal),
                  detail: '${data.monthlySales.count} invoices')),
          const SizedBox(width: gap),
          SizedBox(
              width: width,
              child: _WebMetricCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppTheme.warning,
                  iconFill: const Color(0xFFFFECD1),
                  title: 'Outstanding Dues',
                  value: formatDashboardPrice(data.outstandingDues),
                  detail: data.outstandingDues == 0
                      ? '0 customers'
                      : 'Customers with dues',
                  lineColor: AppTheme.warning)),
          const SizedBox(width: gap),
          SizedBox(
              width: width,
              child: _WebMetricCard(
                  icon: Icons.priority_high_rounded,
                  iconColor: AppTheme.danger,
                  iconFill: const Color(0xFFFFE2E7),
                  title: 'Low Stock Items',
                  value: '${data.lowStockCount}',
                  detail: data.lowStockCount == 0
                      ? 'No open alerts'
                      : 'Needs attention',
                  lineColor: const Color(0xFFFF4164))),
        ]);
      }),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: _WebMetricCard(
                icon: Icons.vaccines_outlined,
                iconColor: const Color(0xFF2563EB),
                iconFill: const Color(0xFFE0ECFF),
                title: 'Vaccination Due (7d)',
                value: '${data.upcomingVaccines}',
                detail: 'Pets due for vaccination',
                lineColor: const Color(0xFF4E8CFF))),
        const SizedBox(width: 14),
        Expanded(
            child: _WebMetricCard(
                icon: Icons.inventory_2_outlined,
                iconColor: const Color(0xFF475569),
                iconFill: const Color(0xFFF0F3F7),
                title: 'Dead Stock Value',
                value: formatDashboardPrice(data.deadStockValue),
                detail: 'Items not moving')),
        const SizedBox(width: 14),
        Expanded(flex: 2, child: _WebQuickActions()),
      ]),
      const SizedBox(height: 18),
      if (data.branches != null && data.branches!.isNotEmpty)
        _WebBranchCharts(branches: data.branches!)
      else
        const _WebSalesTrend(),
    ]);
  }
}

class _WebMetricCard extends StatelessWidget {
  const _WebMetricCard(
      {required this.icon,
      required this.iconColor,
      required this.iconFill,
      required this.title,
      required this.value,
      required this.detail,
      this.lineColor});
  final IconData icon;
  final Color iconColor;
  final Color iconFill;
  final String title;
  final String value;
  final String detail;
  final Color? lineColor;
  @override
  Widget build(BuildContext context) => Container(
        height: 210,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EAF2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                    color: iconFill, borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: iconColor, size: 29)),
            const Spacer(),
            const Icon(Icons.more_horiz_rounded, color: Color(0xFF94A3B8))
          ]),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
          const Spacer(),
          Row(children: [
            Expanded(
                child: Text(detail,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis)),
            if (lineColor != null)
              Container(width: 74, height: 2, color: lineColor)
          ]),
        ]),
      );
}

class _WebQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 210,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EAF2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.bolt_rounded, color: AppTheme.warning, size: 21),
            SizedBox(width: 8),
            Text('Quick Actions',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))
          ]),
          const SizedBox(height: 16),
          Expanded(
              child: FilledButton.icon(
                  onPressed: () => context.go('/pos'),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 19),
                  label: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Open POS'),
                        Icon(Icons.arrow_forward_rounded, size: 19)
                      ]))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _WebActionButton(
                    label: 'Add Customer',
                    icon: Icons.person_add_alt_1_outlined,
                    path: '/customers/new')),
            const SizedBox(width: 10),
            Expanded(
                child: _WebActionButton(
                    label: 'New Purchase',
                    icon: Icons.inventory_2_outlined,
                    path: '/purchases/new'))
          ]),
        ]),
      );
}

class _WebActionButton extends StatelessWidget {
  const _WebActionButton(
      {required this.label, required this.icon, required this.path});
  final String label;
  final IconData icon;
  final String path;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
      onPressed: () => context.go(path),
      icon: Icon(icon, size: 17),
      label: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label),
        const Icon(Icons.arrow_forward_rounded, size: 17)
      ]),
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: AppTheme.textPrimary,
          side: const BorderSide(color: Color(0xFFDCE5EF)),
          textStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)));
}

class _WebSalesTrend extends StatelessWidget {
  const _WebSalesTrend();
  @override
  Widget build(BuildContext context) => Container(
        height: 270,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EAF2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.trending_up_rounded,
                color: AppTheme.primary, size: 21),
            const SizedBox(width: 10),
            const Text('Sales Trend (Last 30 Days)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const Spacer(),
            OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.calendar_month_outlined, size: 15),
                label: const Text('Last 30 Days'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    textStyle: const TextStyle(fontSize: 12)))
          ]),
          const Expanded(
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inventory_2_outlined,
                size: 36, color: Color(0xFFCBD5E1)),
            SizedBox(height: 8),
            Text('No sales data yet',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
          ]))),
          Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FC),
                  borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Expanded(
                    child: _WebTrendFooter(
                        label: 'Peak Day',
                        amount: '—',
                        color: AppTheme.accent)),
                VerticalDivider(indent: 12, endIndent: 12),
                Expanded(
                    child: _WebTrendFooter(
                        label: 'Lowest Day',
                        amount: '—',
                        color: AppTheme.danger)),
                VerticalDivider(indent: 12, endIndent: 12),
                Expanded(
                    child: _WebTrendFooter(
                        label: 'Total Sales (30 Days)',
                        amount: '₹0',
                        color: AppTheme.accent))
              ])),
        ]),
      );
}

class _WebTrendFooter extends StatelessWidget {
  const _WebTrendFooter(
      {required this.label, required this.amount, required this.color});
  final String label;
  final String amount;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.calendar_month_outlined, size: 17, color: color)),
        const SizedBox(width: 10),
        Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              Text(amount,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color))
            ])
      ]);
}

/// Branch-aware desktop chart area. DashboardData supplies branch totals but
/// not daily points, so the trend panel deliberately uses an honest empty
/// state until the time-series API is available.
class _WebBranchCharts extends StatelessWidget {
  const _WebBranchCharts({required this.branches});
  final List<BranchDashboardStat> branches;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _WebBranchSalesCard(branches: branches)),
        const SizedBox(width: 18),
        Expanded(child: _WebBranchTrendCard(branches: branches)),
      ]);
}

class _WebBranchSalesCard extends StatelessWidget {
  const _WebBranchSalesCard({required this.branches});
  final List<BranchDashboardStat> branches;

  @override
  Widget build(BuildContext context) {
    final maximum = branches.fold<double>(1, (max, branch) {
      return [max, branch.monthlySales, branch.stockValue].reduce(
        (current, value) => current > value ? current : value,
      );
    });

    return _WebChartFrame(
      title: 'Branch Sales & Stock',
      child: Column(children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            // Keep the legend clear of the first Y-axis title.
            padding: EdgeInsets.only(bottom: 20),
            child: _ChartLegend(),
          ),
        ),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maximum * 1.12,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final branch = branches[group.x.toInt()];
                    final label =
                        rodIndex == 0 ? 'Monthly sales' : 'Stock value';
                    return BarTooltipItem(
                      '${branch.branchName}\n$label: ${formatDashboardPrice(rod.toY)}',
                      const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    );
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maximum / 4,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: Color(0xFFE6EDF5),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 54,
                    interval: maximum / 4,
                    getTitlesWidget: (value, meta) => SizedBox(
                      width: 48,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatDashboardPrice(value),
                          maxLines: 1,
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= branches.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          branches[index].branchName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < branches.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 6,
                    barRods: [
                      BarChartRodData(
                        toY: branches[i].monthlySales,
                        width: 18,
                        color: AppTheme.primary,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: branches[i].stockValue,
                        width: 18,
                        color: AppTheme.accent,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _WebChartSummary(branches: branches),
      ]),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();
  @override
  Widget build(BuildContext context) => const Wrap(spacing: 18, children: [
        _LegendItem(color: AppTheme.primary, label: 'Monthly Sales'),
        _LegendItem(color: AppTheme.accent, label: 'Stock Value'),
      ]);
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ]);
}

class _WebBranchTrendCard extends StatelessWidget {
  const _WebBranchTrendCard({required this.branches});
  final List<BranchDashboardStat> branches;
  @override
  Widget build(BuildContext context) => _WebChartFrame(
        title: 'Sales Trend by Branch (Last 30 Days)',
        child: Column(children: [
          Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 18, children: [
                for (final b in branches)
                  Text('●  ${b.branchName}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary))
              ])),
          const Expanded(
              child: Center(
                  child: Text('Sales trend data will appear here',
                      style:
                          TextStyle(color: Color(0xFF94A3B8), fontSize: 13)))),
          const SizedBox(height: 14),
          _WebChartSummary(branches: branches),
        ]),
      );
}

class _WebChartFrame extends StatelessWidget {
  const _WebChartFrame({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        height: 430,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EAF2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.trending_up_rounded,
                color: AppTheme.primary, size: 20),
            const SizedBox(width: 9),
            Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800))),
            OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.calendar_month_outlined, size: 14),
                label: const Text('Last 30 Days'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    textStyle: const TextStyle(fontSize: 11)))
          ]),
          const SizedBox(height: 14),
          Expanded(child: child),
        ]),
      );
}

class _WebChartSummary extends StatelessWidget {
  const _WebChartSummary({required this.branches});
  final List<BranchDashboardStat> branches;
  @override
  Widget build(BuildContext context) {
    final sorted = [...branches]
      ..sort((a, b) => b.monthlySales.compareTo(a.monthlySales));
    final top = sorted.first;
    final low = sorted.last;
    return Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: const Color(0xFFF5F8FC),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(
              child: _WebChartSummaryValue(
                  label: 'Top Branch',
                  value: top.branchName,
                  amount: formatDashboardPrice(top.monthlySales),
                  color: AppTheme.accent)),
          const VerticalDivider(indent: 10, endIndent: 10),
          Expanded(
              child: _WebChartSummaryValue(
                  label: 'Lowest Sales',
                  value: low.branchName,
                  amount: formatDashboardPrice(low.monthlySales),
                  color: AppTheme.warning)),
        ]));
  }
}

class _WebChartSummaryValue extends StatelessWidget {
  const _WebChartSummaryValue(
      {required this.label,
      required this.value,
      required this.amount,
      required this.color});
  final String label;
  final String value;
  final String amount;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Text(amount,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w800))
          ]));
}
