import 'package:flutter/material.dart';
import 'package:mobile/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';

class PatientAppointmentListScreen extends StatefulWidget {
  const PatientAppointmentListScreen({super.key});

  @override
  State<PatientAppointmentListScreen> createState() =>
      _PatientAppointmentListScreenState();
}

class _PatientAppointmentListScreenState
    extends State<PatientAppointmentListScreen> {
  late Future<List<PatientAppointment>> _todayFuture;
  late Future<List<PatientAppointment>> _listFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final emr = context.read<AppServices>().emr;
    _todayFuture = emr.todayAppointments();
    _listFuture = emr.listAppointments(query: {'per_page': 30});
  }

  void _refresh() => setState(_reload);

  Future<void> _confirm(PatientAppointment a) async {
    try {
      await context.read<AppServices>().emr.confirmAppointment(a.id);
      if (mounted) {
        AppMessenger.show(context,
          const SnackBar(content: Text('Appointment confirmed')),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _cancel(PatientAppointment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text('Cancel ${a.pet?.name ?? 'this patient'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().emr.cancelAppointment(a.id);
      if (mounted) {
        AppMessenger.show(context,
          const SnackBar(content: Text('Appointment cancelled')),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  void _startVisit(PatientAppointment a) {
    context.push('/emr/visits/new?appointment_id=${a.id}');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppTheme.accent;
      case 'in_progress':
        return AppTheme.primary;
      case 'completed':
        return AppTheme.textSecondary;
      case 'cancelled':
      case 'no_show':
        return AppTheme.danger;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission('emr.visits.create');
    final canCreateAppt = auth.hasPermission('patient_appointments.create');
    final canEdit = auth.hasPermission('patient_appointments.edit');
    final canCancel = auth.hasPermission('patient_appointments.cancel');

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: canCreateAppt
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/emr/appointments/new'),
              icon: const Icon(Icons.add),
              label: const Text('New appointment'),
            )
          : canCreate
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/emr/visits/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New visit'),
                )
              : null,
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Patient Appointments',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<PatientAppointment>>(
              future: _todayFuture,
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's schedule",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...snap.data!.map((a) => _AppointmentCard(
                          appointment: a,
                          statusColor: _statusColor(a.status),
                          onStartVisit: canCreate ? () => _startVisit(a) : null,
                          onConfirm: canEdit && a.status == 'scheduled'
                              ? () => _confirm(a)
                              : null,
                          onCancel: canCancel &&
                                  !['completed', 'cancelled'].contains(a.status)
                              ? () => _cancel(a)
                              : null,
                          onEdit: canEdit ? () => context.push('/emr/appointments/${a.id}/edit') : null,
                        )),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            Text('Upcoming & recent',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<PatientAppointment>>(
              future: _listFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Text('${snap.error}');
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No appointments found')),
                  );
                }
                return Column(
                  children: items
                      .map((a) => _AppointmentCard(
                            appointment: a,
                            statusColor: _statusColor(a.status),
                            onStartVisit: canCreate && a.visitId == null
                                ? () => _startVisit(a)
                                : null,
                            onConfirm: canEdit && a.status == 'scheduled'
                                ? () => _confirm(a)
                                : null,
                            onCancel: canCancel &&
                                    !['completed', 'cancelled'].contains(a.status)
                                ? () => _cancel(a)
                                : null,
                            onEdit: canEdit ? () => context.push('/emr/appointments/${a.id}/edit') : null,
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.statusColor,
    this.onStartVisit,
    this.onConfirm,
    this.onCancel,
    this.onEdit,
  });

  final PatientAppointment appointment;
  final Color statusColor;
  final VoidCallback? onStartVisit;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final time = appointment.displayTime;
    final owner = appointment.customer?.name ??
        appointment.pet?.customerName;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appointment.pet?.name ?? 'Pet #${appointment.petId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    appointment.status,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$time · ${appointment.displayDate} · ${appointment.appointmentType}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            if (owner != null && owner.isNotEmpty)
              Text('Owner: $owner',
                  style: const TextStyle(fontSize: 13)),
            if (appointment.doctor != null)
              Text('Dr. ${appointment.doctor!.name}',
                  style: const TextStyle(fontSize: 13)),
            if (appointment.chiefComplaint != null &&
                appointment.chiefComplaint!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(appointment.chiefComplaint!,
                    style: const TextStyle(fontSize: 13)),
              ),
            if (onStartVisit != null || onConfirm != null || onCancel != null || onEdit != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (onStartVisit != null)
                      FilledButton.tonal(
                        onPressed: onStartVisit,
                        child: const Text('Start visit'),
                      ),
                    if (onEdit != null)
                      OutlinedButton(
                        onPressed: onEdit,
                        child: const Text('Edit'),
                      ),
                    if (onConfirm != null)
                      OutlinedButton(
                        onPressed: onConfirm,
                        child: const Text('Confirm'),
                      ),
                    if (onCancel != null)
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('Cancel'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
