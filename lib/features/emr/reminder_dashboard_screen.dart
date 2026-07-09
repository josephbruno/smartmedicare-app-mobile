import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';

class ReminderDashboardScreen extends StatefulWidget {
  const ReminderDashboardScreen({super.key});

  @override
  State<ReminderDashboardScreen> createState() =>
      _ReminderDashboardScreenState();
}

class _ReminderDashboardScreenState extends State<ReminderDashboardScreen> {
  late Future<ReminderSummary> _summaryFuture;
  late Future<List<PetReminder>> _dueFuture;
  String _typeFilter = 'all';
  String _statusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final emr = context.read<AppServices>().emr;
    _summaryFuture = emr.reminderDashboard();
    final query = <String, dynamic>{'per_page': 30};
    if (_statusFilter != 'all') query['status'] = _statusFilter;
    if (_typeFilter != 'all') query['type'] = _typeFilter;
    _dueFuture = emr.dueReminders(query: query);
  }

  Future<void> _sendNow(PetReminder r) async {
    try {
      await context.read<AppServices>().emr.sendReminderNow(r.id);
      if (mounted) {
        AppMessenger.show(context,
          const SnackBar(content: Text('Reminder sent')),
        );
        setState(_reload);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _dismiss(PetReminder r) async {
    try {
      await context.read<AppServices>().emr.dismissReminder(r.id);
      if (mounted) {
        AppMessenger.show(context,
          const SnackBar(content: Text('Reminder dismissed')),
        );
        setState(_reload);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Reminders',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<ReminderSummary>(
              future: _summaryFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final s = snap.data!;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatChip(label: 'Vaccination', count: s.vaccinationDue),
                    _StatChip(label: 'Deworming', count: s.dewormingDue),
                    _StatChip(label: 'Follow-up', count: s.followupDue),
                    _StatChip(
                      label: 'Overdue',
                      count: s.overdue,
                      color: AppTheme.danger,
                    ),
                    _StatChip(label: 'Sent today', count: s.sentToday),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in ['all', 'vaccination', 'deworming', 'followup'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(t == 'all' ? 'All types' : t),
                        selected: _typeFilter == t,
                        onSelected: (_) => setState(() {
                          _typeFilter = t;
                          _reload();
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in ['pending', 'sent', 'all'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(s == 'all' ? 'All status' : s),
                        selected: _statusFilter == s,
                        onSelected: (_) => setState(() {
                          _statusFilter = s;
                          _reload();
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Due reminders',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<PetReminder>>(
              future: _dueFuture,
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
                    child: Center(child: Text('No pending reminders')),
                  );
                }
                return Column(
                  children: items
                      .map(
                        (r) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(_iconForType(r.reminderType),
                                        color: AppTheme.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(r.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${r.pet?.name ?? 'Pet'}${r.customer != null ? ' · ${r.customer!.name}' : ''} · Due ${r.displayDueDate}',
                                ),
                                if (r.message.isNotEmpty) Text(r.message),
                                if (r.status == 'pending')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Wrap(
                                      spacing: 8,
                                      children: [
                                        FilledButton.tonal(
                                          onPressed: () => _sendNow(r),
                                          child: const Text('Send now'),
                                        ),
                                        OutlinedButton(
                                          onPressed: () => _dismiss(r),
                                          child: const Text('Dismiss'),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'vaccination':
        return Icons.vaccines_outlined;
      case 'deworming':
        return Icons.medication_outlined;
      case 'followup':
      case 'surgery_followup':
        return Icons.event_note_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    this.color,
  });

  final String label;
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c, fontSize: 12)),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}
