import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dashboard_data.dart';
import '../../../data/models/emr.dart';
import '../../../data/models/invoice.dart';
import '../../emr/visit_billing_queue_notifier.dart';
import '../../emr/widgets/visit_billing_queue_panel.dart';
import 'dashboard_widgets.dart';

/// Cashier-focused home: branch shift KPIs, billing queue, recent bills.
class CashierDashboardSection extends StatefulWidget {
  const CashierDashboardSection({super.key});

  @override
  State<CashierDashboardSection> createState() => _CashierDashboardSectionState();
}

class _CashierDashboardSectionState extends State<CashierDashboardSection> {
  Future<DashboardData>? _shiftFuture;
  Future<List<Invoice>>? _recentInvoicesFuture;

  void _loadBranchData() {
    final auth = context.read<AuthSession>();
    final services = context.read<AppServices>();
    final branchId = auth.currentBranchId;
    setState(() {
      _shiftFuture = services.reports.dashboard(branchId: branchId);
      if (auth.hasPermission(AppPermissions.invoicesView)) {
        _recentInvoicesFuture = services.billing
            .listPaginated(page: 1, perPage: 6)
            .then((r) => r.items);
      } else {
        _recentInvoicesFuture = Future.value(const <Invoice>[]);
      }
    });
  }

  Future<void> _refresh() async {
    _loadBranchData();
    await Future.wait([
      if (_shiftFuture != null) _shiftFuture!,
      if (_recentInvoicesFuture != null) _recentInvoicesFuture!,
    ]);
    if (!mounted) return;
    await context.read<VisitBillingQueueNotifier>().refresh();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadBranchData();
      context.read<VisitBillingQueueNotifier>().startPolling(
            context.read<AppServices>().emr,
            interval: const Duration(seconds: 90),
          );
    });
  }

  double _modeAmount(Map<String, double> byMode, List<String> keys) {
    var total = 0.0;
    for (final k in keys) {
      total += byMode[k] ?? 0;
    }
    return total;
  }

  Color _invoiceStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppTheme.accent;
      case 'partial':
      case 'confirmed':
        return AppTheme.warning;
      case 'cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  List<_CashierAction> _actions(AuthSession auth) {
    return [
      if (auth.hasPermission(AppPermissions.invoicesCreate))
        _CashierAction(
          icon: Icons.point_of_sale_rounded,
          label: 'POS',
          color: AppTheme.primary,
          onTap: () => context.go('/pos'),
        ),
      if (auth.hasPermission(AppPermissions.invoicesView))
        _CashierAction(
          icon: Icons.receipt_long_rounded,
          label: 'Invoices',
          color: const Color(0xFF8B5CF6),
          onTap: () => context.go('/invoices'),
        ),
      if (auth.hasPermission(AppPermissions.customersView))
        _CashierAction(
          icon: Icons.people_rounded,
          label: 'Customers',
          color: AppTheme.primary,
          onTap: () => context.go('/customers'),
        ),
      if (auth.hasPermission(AppPermissions.productsView))
        _CashierAction(
          icon: Icons.inventory_2_outlined,
          label: 'Products',
          color: const Color(0xFF14B8A6),
          onTap: () => context.go('/products'),
        ),
      if (auth.hasPermission(AppPermissions.inventoryView))
        _CashierAction(
          icon: Icons.warning_amber_rounded,
          label: 'Stock alerts',
          color: AppTheme.warning,
          onTap: () => context.go('/stock-alerts'),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final branchName = auth.currentBranch?.name ?? 'Your branch';
    final actions = _actions(auth);
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CashierHeader(
              branchName: branchName,
              onRefresh: _refresh,
              showPos: auth.hasPermission(AppPermissions.invoicesCreate),
              onOpenPos: () => context.go('/pos'),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions
                    .map(
                      (a) => _CashierActionChip(
                        icon: a.icon,
                        label: a.label,
                        color: a.color,
                        onTap: a.onTap,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 18),
            FutureBuilder<DashboardData>(
              future: _shiftFuture,
              builder: (context, snap) {
                if (_shiftFuture == null ||
                    snap.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 88,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                if (snap.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.danger),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Could not load branch stats: ${snap.error}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadBranchData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snap.hasData) return const SizedBox.shrink();
                return _buildKpiSection(context, auth, snap.data!);
              },
            ),
            const SizedBox(height: 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildQueueSection(context, auth)),
                  const SizedBox(width: 16),
                  if (auth.hasPermission(AppPermissions.invoicesView))
                    Expanded(flex: 5, child: _buildRecentInvoices(context)),
                ],
              )
            else ...[
              _buildQueueSection(context, auth),
              if (auth.hasPermission(AppPermissions.invoicesView)) ...[
                const SizedBox(height: 20),
                _buildRecentInvoices(context),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQueueSection(BuildContext context, AuthSession auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: AppTheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Billing queue',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Visits released by doctors appear here for checkout.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        const VisitBillingQueuePanel(),
      ],
    );
  }

  Widget _buildKpiSection(BuildContext context, AuthSession auth, DashboardData d) {
    final byMode = d.todaySales.byMode;
    final cash = _modeAmount(byMode, const ['cash']);
    final upi = _modeAmount(byMode, const ['upi']);
    final cardAmt = _modeAmount(byMode, const ['card']);
    final otherModes = byMode.entries
        .where((e) => !const {'cash', 'upi', 'card'}.contains(e.key) && e.value > 0)
        .toList();
    final mixTotal = cash + upi + cardAmt + otherModes.fold<double>(0, (s, e) => s + e.value);

    final metrics = <_CashierMetric>[
      _CashierMetric(
        label: "Today's sales",
        value: '₹${d.todaySalesTotal.toStringAsFixed(0)}',
        hint: '${d.todaySalesCount} bills',
        icon: Icons.payments_rounded,
        color: AppTheme.primary,
        onTap: auth.hasPermission(AppPermissions.invoicesView)
            ? () => context.go('/invoices')
            : null,
      ),
      _CashierMetric(
        label: 'Paid today',
        value: '₹${d.todaySales.paid.toStringAsFixed(0)}',
        hint: d.todaySales.due > 0
            ? 'Due ₹${d.todaySales.due.toStringAsFixed(0)}'
            : 'All collected',
        icon: Icons.check_circle_outline_rounded,
        color: AppTheme.accent,
      ),
      if (d.outstandingDues > 0)
        _CashierMetric(
          label: 'Outstanding',
          value: '₹${d.outstandingDues.toStringAsFixed(0)}',
          hint: 'Open dues',
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.danger,
          onTap: auth.hasPermission(AppPermissions.invoicesView)
              ? () => context.go('/invoices')
              : null,
        ),
      _CashierMetric(
        label: 'This month',
        value: '₹${d.monthlySalesTotal.toStringAsFixed(0)}',
        hint: '${d.monthlySales.count} bills',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF6366F1),
      ),
      if (auth.hasPermission(AppPermissions.inventoryView))
        _CashierMetric(
          label: 'Low stock',
          value: '${d.lowStockCount}',
          hint: 'Below reorder',
          icon: Icons.warning_amber_rounded,
          color: AppTheme.warning,
          onTap: () => context.go('/stock-alerts'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cols = width >= 1100
                ? metrics.length.clamp(3, 5)
                : width >= 720
                    ? 3
                    : 2;
            final gap = 10.0;
            final tileW = (width - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: metrics
                  .map(
                    (m) => SizedBox(
                      width: tileW,
                      child: _CashierMetricTile(metric: m),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        if (mixTotal > 0) ...[
          const SizedBox(height: 12),
          _PaymentMixBar(
            segments: [
              _PaymentSegment('Cash', cash, AppTheme.accent),
              _PaymentSegment('UPI', upi, const Color(0xFF8B5CF6)),
              _PaymentSegment('Card', cardAmt, AppTheme.primary),
              ...otherModes.map(
                (e) => _PaymentSegment(
                  e.key.replaceAll('_', ' '),
                  e.value,
                  AppTheme.textSecondary,
                ),
              ),
            ],
            total: mixTotal,
          ),
        ],
      ],
    );
  }

  Widget _buildRecentInvoices(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: Color(0xFF8B5CF6),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Recent invoices',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/invoices'),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Invoice>>(
          future: _recentInvoicesFuture,
          builder: (context, snap) {
            if (_recentInvoicesFuture == null ||
                snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (snap.hasError) {
              return Text(
                'Could not load invoices: ${snap.error}',
                style: const TextStyle(color: AppTheme.danger, fontSize: 13),
              );
            }
            final invoices = snap.data ?? const <Invoice>[];
            if (invoices.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'No invoices for this branch yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < invoices.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _CashierInvoiceRow(
                      invoice: invoices[i],
                      statusColor: _invoiceStatusColor(invoices[i].status),
                      onTap: () => context.push('/invoices/${invoices[i].id}'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CashierHeader extends StatelessWidget {
  const _CashierHeader({
    required this.branchName,
    required this.onRefresh,
    required this.showPos,
    required this.onOpenPos,
  });

  final String branchName;
  final VoidCallback onRefresh;
  final bool showPos;
  final VoidCallback onOpenPos;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      branchName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Cashier',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Shift overview for this branch',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh_rounded),
        ),
        if (showPos) ...[
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: onOpenPos,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Open POS'),
          ),
        ],
      ],
    );
  }
}

class _CashierAction {
  const _CashierAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _CashierActionChip extends StatelessWidget {
  const _CashierActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashierMetric {
  const _CashierMetric({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

class _CashierMetricTile extends StatelessWidget {
  const _CashierMetricTile({required this.metric});

  final _CashierMetric metric;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(metric.icon, color: metric.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  metric.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (metric.onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: metric.onTap,
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }
}

class _PaymentSegment {
  const _PaymentSegment(this.label, this.amount, this.color);
  final String label;
  final double amount;
  final Color color;
}

class _PaymentMixBar extends StatelessWidget {
  const _PaymentMixBar({required this.segments, required this.total});

  final List<_PaymentSegment> segments;
  final double total;

  @override
  Widget build(BuildContext context) {
    final visible = segments.where((s) => s.amount > 0).toList();
    if (visible.isEmpty || total <= 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment mix today',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  for (final s in visible)
                    Expanded(
                      flex: (s.amount / total * 1000).round().clamp(1, 1000),
                      child: Container(color: s.color),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: visible
                .map(
                  (s) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${s.label} ₹${s.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _CashierInvoiceRow extends StatelessWidget {
  const _CashierInvoiceRow({
    required this.invoice,
    required this.statusColor,
    required this.onTap,
  });

  final Invoice invoice;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final customer = invoice.customer?.name;
    final meta = [
      if (customer != null && customer.isNotEmpty) customer,
      if (invoice.displayDate.isNotEmpty) invoice.displayDate,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber.isNotEmpty
                        ? invoice.invoiceNumber
                        : 'Invoice #${invoice.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${invoice.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    invoice.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Doctor-focused home: open visits, bills on hold, and clinical shortcuts.
class DoctorDashboardSection extends StatefulWidget {
  const DoctorDashboardSection({super.key});

  @override
  State<DoctorDashboardSection> createState() => _DoctorDashboardSectionState();
}

class _DoctorDashboardSectionState extends State<DoctorDashboardSection> {
  late Future<List<PetVisit>> _openFuture;
  late Future<List<PetVisit>> _holdFuture;
  late Future<List<PetVisit>> _readyFuture;

  @override
  void initState() {
    super.initState();
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VisitBillingQueueNotifier>().startPolling(
            context.read<AppServices>().emr,
          );
    });
  }

  void _reload() {
    final emr = context.read<AppServices>().emr;
    _openFuture = emr.listVisitsPaginated(status: 'open', perPage: 15).then((r) => r.items);
    _holdFuture = emr.listVisitsPaginated(status: 'bill_on_hold', perPage: 15).then((r) => r.items);
    _readyFuture =
        emr.listVisitsPaginated(status: 'completed', perPage: 10).then((r) => r.items);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthSession>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clinical workspace',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Open visits, held bills, and shortcuts for your day.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<List<PetVisit>>>(
          future: Future.wait([_openFuture, _holdFuture, _readyFuture]),
          builder: (context, snap) {
            final open = snap.data?[0] ?? const <PetVisit>[];
            final holds = snap.data?[1] ?? const <PetVisit>[];
            final ready = snap.data?[2] ?? const <PetVisit>[];
            final loading = snap.connectionState != ConnectionState.done;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DoctorStatChip(
                  label: 'Open visits',
                  value: loading ? '…' : '${open.length}',
                  icon: Icons.medical_services_outlined,
                  color: AppTheme.primary,
                  onTap: auth.hasPermission(AppPermissions.emrVisitsView)
                      ? () => context.go('/emr/visits')
                      : null,
                ),
                _DoctorStatChip(
                  label: 'On hold',
                  value: loading ? '…' : '${holds.length}',
                  icon: Icons.pause_circle_outline,
                  color: AppTheme.warning,
                ),
                _DoctorStatChip(
                  label: 'Sent to cashier',
                  value: loading ? '…' : '${ready.length}',
                  icon: Icons.receipt_long_outlined,
                  color: AppTheme.accent,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        DashboardSectionHeader(
          icon: Icons.pending_actions_outlined,
          title: 'Open visits',
          trailing: TextButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<PetVisit>>(
          future: _openFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator(minHeight: 2);
            }
            final visits = snap.data ?? [];
            if (visits.isEmpty) {
              return _DoctorEmptyCard(
                icon: Icons.medical_services_outlined,
                message: 'No open visits — start a new consultation when ready.',
              );
            }
            return Column(
              children: visits.take(8).map((v) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.pets_rounded, color: AppTheme.primary, size: 20),
                    ),
                    title: Text(
                      v.pet?.name ?? v.visitNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        v.visitNumber,
                        if (v.chiefComplaint != null && v.chiefComplaint!.isNotEmpty)
                          v.chiefComplaint!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: TextButton(
                      onPressed: () => context.push('/emr/visits/${v.id}/edit'),
                      child: const Text('Continue'),
                    ),
                    onTap: () => context.push('/emr/visits/${v.id}'),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 28),
        const DashboardSectionHeader(
          icon: Icons.pause_circle_outline,
          title: 'Bills on hold',
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<PetVisit>>(
          future: _holdFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator(minHeight: 2);
            }
            final holds = snap.data ?? [];
            if (holds.isEmpty) {
              return _DoctorEmptyCard(
                icon: Icons.pause_circle_outline,
                message:
                    'No visits on hold — complete a visit to pause billing while you add items.',
              );
            }
            return Column(
              children: holds.map((v) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(v.pet?.name ?? v.visitNumber),
                    subtitle: Text('${v.visitNumber} · awaiting send to cashier'),
                    trailing: TextButton(
                      onPressed: () => context.push('/emr/visits/${v.id}/edit'),
                      child: const Text('Edit'),
                    ),
                    onTap: () => context.push('/emr/visits/${v.id}'),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (auth.hasPermission(AppPermissions.emrVisitsCreate))
              QuickActionCard(
                icon: Icons.add_circle_outline,
                label: 'New visit',
                subtitle: 'Start consultation',
                color: AppTheme.accent,
                onTap: () => context.push('/emr/visits/new'),
              ),
            if (auth.hasPermission(AppPermissions.emrVisitsView))
              QuickActionCard(
                icon: Icons.medical_services_outlined,
                label: 'Visit records',
                subtitle: 'All visits',
                color: AppTheme.primary,
                onTap: () => context.go('/emr/visits'),
              ),
            if (auth.hasPermission(AppPermissions.customersView))
              QuickActionCard(
                icon: Icons.pets_outlined,
                label: 'Patients',
                subtitle: 'Pet directory',
                color: const Color(0xFF8B5CF6),
                onTap: () => context.go('/patients'),
              ),
            if (auth.hasPermission(AppPermissions.emrRemindersView))
              QuickActionCard(
                icon: Icons.notifications_outlined,
                label: 'Reminders',
                subtitle: 'Follow-ups due',
                color: AppTheme.warning,
                onTap: () => context.go('/emr/reminders'),
              ),
          ],
        ),
      ],
    );
  }
}

class _DoctorStatChip extends StatelessWidget {
  const _DoctorStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 160,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorEmptyCard extends StatelessWidget {
  const _DoctorEmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
