import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dashboard_data.dart';
import '../../../data/models/emr.dart';
import '../../emr/visit_billing_queue_notifier.dart';
import '../../emr/widgets/visit_billing_queue_panel.dart';
import 'dashboard_widgets.dart';

/// Cashier-focused home: billing queue is the primary workspace entry.
class CashierDashboardSection extends StatefulWidget {
  const CashierDashboardSection({super.key});

  @override
  State<CashierDashboardSection> createState() => _CashierDashboardSectionState();
}

class _CashierDashboardSectionState extends State<CashierDashboardSection> {
  late Future<DashboardData> _shiftFuture;

  @override
  void initState() {
    super.initState();
    _shiftFuture = context.read<AppServices>().reports.dashboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VisitBillingQueueNotifier>().startPolling(
            context.read<AppServices>().emr,
            interval: const Duration(seconds: 25),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthSession>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<DashboardData>(
          future: _shiftFuture,
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final d = snap.data!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 200,
                    child: DashboardStatCard(
                      title: "TODAY'S SHIFT",
                      value: '₹${d.todaySalesTotal.toStringAsFixed(0)}',
                      subtitle: '${d.todaySalesCount} bills today',
                      icon: Icons.payments_rounded,
                      color: AppTheme.primary,
                      trend: const [],
                    ),
                  ),
                  if (d.todaySales.byMode.isNotEmpty)
                    SizedBox(
                      width: 200,
                      child: DashboardStatCard(
                        title: 'CASH / UPI',
                        value: '₹${(d.todaySales.byMode['cash'] ?? 0).toStringAsFixed(0)}',
                        subtitle:
                            'UPI ₹${(d.todaySales.byMode['upi'] ?? d.todaySales.byMode['card'] ?? 0).toStringAsFixed(0)}',
                        icon: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFF8B5CF6),
                        trend: const [],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        Row(
          children: [
            const Icon(Icons.point_of_sale_rounded, color: AppTheme.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              'Billing queue',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
        const SizedBox(height: 20),
        const VisitBillingQueuePanel(),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (auth.hasPermission(AppPermissions.invoicesView))
              QuickActionCard(
                icon: Icons.receipt_long_rounded,
                label: 'Invoices',
                subtitle: 'View past bills',
                color: const Color(0xFF8B5CF6),
                onTap: () => context.go('/invoices'),
              ),
            if (auth.hasPermission(AppPermissions.customersView))
              QuickActionCard(
                icon: Icons.people_rounded,
                label: 'Customers',
                subtitle: 'Lookup owner',
                color: AppTheme.primary,
                onTap: () => context.go('/customers'),
              ),
          ],
        ),
      ],
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
        Row(
          children: [
            const DashboardSectionHeader(icon: Icons.pause_circle_outline, title: 'Bills on hold'),
            const Spacer(),
            TextButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ],
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
