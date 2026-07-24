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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final branchName = auth.currentBranch?.name ?? 'Your branch';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branchName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Branch shift overview — sales, queue, and recent bills.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FutureBuilder<DashboardData>(
              future: _shiftFuture,
              builder: (context, snap) {
                if (_shiftFuture == null ||
                    snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.danger),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Could not load branch stats: ${snap.error}',
                                style: const TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadBranchData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                if (!snap.hasData) return const SizedBox.shrink();
                return _buildKpiSection(context, auth, snap.data!);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.point_of_sale_rounded, color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Billing queue',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (auth.hasPermission(AppPermissions.invoicesCreate))
                  FilledButton.icon(
                    onPressed: () => context.go('/pos'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Open POS'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Visits released by doctors appear here. Select one to load the cart at POS.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const VisitBillingQueuePanel(),
            if (auth.hasPermission(AppPermissions.invoicesView)) ...[
              const SizedBox(height: 28),
              _buildRecentInvoices(context),
            ],
            const SizedBox(height: 28),
            const DashboardSectionHeader(
              icon: Icons.bolt_rounded,
              title: 'Quick actions',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (auth.hasPermission(AppPermissions.invoicesCreate))
                  SizedBox(
                    width: 220,
                    child: QuickActionCard(
                      icon: Icons.point_of_sale_rounded,
                      label: 'POS',
                      subtitle: 'New sale',
                      color: AppTheme.primary,
                      onTap: () => context.go('/pos'),
                    ),
                  ),
                if (auth.hasPermission(AppPermissions.invoicesView))
                  SizedBox(
                    width: 220,
                    child: QuickActionCard(
                      icon: Icons.receipt_long_rounded,
                      label: 'Invoices',
                      subtitle: 'Branch bills',
                      color: const Color(0xFF8B5CF6),
                      onTap: () => context.go('/invoices'),
                    ),
                  ),
                if (auth.hasPermission(AppPermissions.customersView))
                  SizedBox(
                    width: 220,
                    child: QuickActionCard(
                      icon: Icons.people_rounded,
                      label: 'Customers',
                      subtitle: 'Lookup owner',
                      color: AppTheme.primary,
                      onTap: () => context.go('/customers'),
                    ),
                  ),
                if (auth.hasPermission(AppPermissions.patientAppointmentsView))
                  SizedBox(
                    width: 220,
                    child: QuickActionCard(
                      icon: Icons.event_available_rounded,
                      label: 'Appointments',
                      subtitle: "Today's schedule",
                      color: const Color(0xFF0EA5E9),
                      onTap: () => context.go('/emr/appointments'),
                    ),
                  ),
                if (auth.hasPermission(AppPermissions.productsView))
                  SizedBox(
                    width: 220,
                    child: QuickActionCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Products',
                      subtitle: 'Catalog lookup',
                      color: const Color(0xFF14B8A6),
                      onTap: () => context.go('/products'),
                    ),
                  ),
                if (auth.hasPermission(AppPermissions.inventoryView))
                  SizedBox(
                    width: 220,
                    child: QuickActionCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Stock alerts',
                      subtitle: 'Low stock items',
                      color: AppTheme.warning,
                      onTap: () => context.go('/stock-alerts'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSection(BuildContext context, AuthSession auth, DashboardData d) {
    final byMode = d.todaySales.byMode;
    final cash = _modeAmount(byMode, const ['cash']);
    final upi = _modeAmount(byMode, const ['upi']);
    final card = _modeAmount(byMode, const ['card']);
    final otherModes = byMode.entries
        .where((e) => !const {'cash', 'upi', 'card'}.contains(e.key) && e.value > 0)
        .toList();

    final cards = <Widget>[
      SizedBox(
        width: 200,
        child: DashboardStatCard(
          title: "TODAY'S SALES",
          value: '₹${d.todaySalesTotal.toStringAsFixed(0)}',
          subtitle: '${d.todaySalesCount} bills today',
          icon: Icons.payments_rounded,
          color: AppTheme.primary,
          trend: const [],
          onTap: auth.hasPermission(AppPermissions.invoicesView)
              ? () => context.go('/invoices')
              : null,
        ),
      ),
      SizedBox(
        width: 200,
        child: DashboardStatCard(
          title: 'PAID TODAY',
          value: '₹${d.todaySales.paid.toStringAsFixed(0)}',
          subtitle: d.todaySales.due > 0
              ? 'Due ₹${d.todaySales.due.toStringAsFixed(0)}'
              : 'All collected',
          icon: Icons.check_circle_outline_rounded,
          color: AppTheme.accent,
          trend: const [],
        ),
      ),
      if (d.outstandingDues > 0)
        SizedBox(
          width: 200,
          child: DashboardStatCard(
            title: 'OUTSTANDING',
            value: '₹${d.outstandingDues.toStringAsFixed(0)}',
            subtitle: 'Open dues at branch',
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.danger,
            trend: const [],
            onTap: auth.hasPermission(AppPermissions.invoicesView)
                ? () => context.go('/invoices')
                : null,
          ),
        ),
      SizedBox(
        width: 200,
        child: DashboardStatCard(
          title: 'THIS MONTH',
          value: '₹${d.monthlySalesTotal.toStringAsFixed(0)}',
          subtitle: '${d.monthlySales.count} bills',
          icon: Icons.calendar_month_rounded,
          color: const Color(0xFF6366F1),
          trend: const [],
        ),
      ),
      if (auth.hasPermission(AppPermissions.patientAppointmentsView))
        SizedBox(
          width: 200,
          child: DashboardStatCard(
            title: 'APPOINTMENTS',
            value: '${d.todayAppointments.count}',
            subtitle: 'Scheduled today',
            icon: Icons.event_rounded,
            color: const Color(0xFF0EA5E9),
            trend: const [],
            onTap: () => context.go('/emr/appointments'),
          ),
        ),
      if (auth.hasPermission(AppPermissions.inventoryView))
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
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 12, runSpacing: 12, children: cards),
          if (byMode.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment mix today',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _PaymentModeChip(
                        label: 'Cash',
                        amount: cash,
                        color: AppTheme.accent,
                      ),
                      _PaymentModeChip(
                        label: 'UPI',
                        amount: upi,
                        color: const Color(0xFF8B5CF6),
                      ),
                      _PaymentModeChip(
                        label: 'Card',
                        amount: card,
                        color: AppTheme.primary,
                      ),
                      ...otherModes.map(
                        (e) => _PaymentModeChip(
                          label: e.key.replaceAll('_', ' '),
                          amount: e.value,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentInvoices(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(
          icon: Icons.receipt_long_outlined,
          title: 'Recent invoices',
          trailing: TextButton(
            onPressed: () => context.go('/invoices'),
            child: const Text('View all'),
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Invoice>>(
          future: _recentInvoicesFuture,
          builder: (context, snap) {
            if (_recentInvoicesFuture == null ||
                snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
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
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No invoices yet for this branch today.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              );
            }
            return Column(
              children: invoices.map((inv) {
                final statusColor = _invoiceStatusColor(inv.status);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => context.push('/invoices/${inv.id}'),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      inv.invoiceNumber.isNotEmpty
                          ? inv.invoiceNumber
                          : 'Invoice #${inv.id}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        if (inv.customer?.name != null && inv.customer!.name.isNotEmpty)
                          inv.customer!.name,
                        if (inv.displayDate.isNotEmpty) inv.displayDate,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${inv.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          inv.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _PaymentModeChip extends StatelessWidget {
  const _PaymentModeChip({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Doctor-focused home: today\'s schedule and visits on hold.
class DoctorDashboardSection extends StatefulWidget {
  const DoctorDashboardSection({super.key});

  @override
  State<DoctorDashboardSection> createState() => _DoctorDashboardSectionState();
}

class _DoctorDashboardSectionState extends State<DoctorDashboardSection> {
  late Future<List<PatientAppointment>> _appointmentsFuture;
  late Future<List<PetVisit>> _holdFuture;

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
    _appointmentsFuture = emr.todayAppointments();
    _holdFuture = emr.listVisitsPaginated(status: 'bill_on_hold', perPage: 15).then((r) => r.items);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthSession>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(icon: Icons.today_rounded, title: "Today's schedule"),
        const SizedBox(height: 12),
        FutureBuilder<List<PatientAppointment>>(
          future: _appointmentsFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ));
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No appointments scheduled for today.'),
                ),
              );
            }
            return Column(
              children: list.take(8).map((a) {
                final time = a.appointmentTime.length >= 5
                    ? a.appointmentTime.substring(0, 5)
                    : a.appointmentTime;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      child: Text(time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(a.pet?.name ?? 'Pet #${a.petId}'),
                    subtitle: Text('${a.status} · ${a.appointmentType}'),
                    trailing: a.visitId != null
                        ? TextButton(
                            onPressed: () => context.push('/emr/visits/${a.visitId}'),
                            child: const Text('Visit'),
                          )
                        : TextButton(
                            onPressed: () => context.push(
                              '/emr/visits/new?appointment_id=${a.id}',
                            ),
                            child: const Text('Start'),
                          ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 28),
        DashboardSectionHeader(
          icon: Icons.pause_circle_outline,
          title: 'Bills on hold',
          trailing: TextButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
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
              return const Text(
                'No visits on hold — complete a visit to pause billing while you add items.',
                style: TextStyle(color: AppTheme.textSecondary),
              );
            }
            return Column(
              children: holds.map((v) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(v.pet?.name ?? v.visitNumber),
                    subtitle: Text('${v.visitNumber} · awaiting send to cashier'),
                    trailing: FilledButton.tonal(
                      onPressed: () => context.push('/emr/visits/${v.id}/edit'),
                      child: const Text('Edit'),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        if (auth.hasPermission(AppPermissions.emrVisitsCreate)) ...[
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              QuickActionCard(
                icon: Icons.add_circle_outline,
                label: 'New visit',
                subtitle: 'Start consultation',
                color: AppTheme.accent,
                onTap: () => context.push('/emr/visits/new'),
              ),
              QuickActionCard(
                icon: Icons.event_available_rounded,
                label: 'Appointments',
                subtitle: 'Full calendar',
                color: AppTheme.primary,
                onTap: () => context.go('/emr/appointments'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
