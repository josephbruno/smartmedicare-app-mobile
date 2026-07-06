import 'package:flutter/material.dart';
import 'package:mobile/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';
import 'emr_pet_hub.dart';
import 'visit_pdf.dart';

class VisitDetailScreen extends StatefulWidget {
  const VisitDetailScreen({super.key, required this.visitId});

  final int visitId;

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  late Future<PetVisit> _future;
  bool _billing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AppServices>().emr.getVisit(widget.visitId);
  }

  Future<void> _billVisit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Bill this visit?'),
        content: const Text(
          'Creates an invoice from billable treatments and medicines with linked products.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Bill')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _billing = true);
    try {
      final invoice =
          await context.read<AppServices>().emr.billVisit(widget.visitId);
      if (mounted) {
        AppMessenger.show(context,
          SnackBar(content: Text('Invoice ${invoice.invoiceNumber} created')),
        );
        context.push('/invoices/${invoice.id}');
        setState(_reload);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _billing = false);
    }
  }

  Future<void> _deleteVisit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete visit?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().emr.deleteVisit(widget.visitId);
      if (mounted) {
        AppMessenger.show(context,
          const SnackBar(content: Text('Visit deleted')),
        );
        context.go('/emr/visits');
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'billed':
      case 'completed':
        return AppTheme.accent;
      case 'open':
        return AppTheme.primary;
      case 'cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final canEdit = auth.hasPermission('emr.visits.edit');
    final canBill = auth.hasPermission('emr.visits.bill');

    return Scaffold(
      body: FutureBuilder<PetVisit>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          final v = snap.data!;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: Text(v.visitNumber),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.print_outlined),
                    tooltip: 'Print',
                    onPressed: () => VisitPdf.printVisit(v),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_outlined),
                    tooltip: 'Download PDF',
                    onPressed: () => VisitPdf.downloadVisit(v),
                  ),
                  if (canEdit && v.status == 'open')
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () =>
                          context.push('/emr/visits/${v.id}/edit'),
                    ),
                  if (canBill && v.status == 'open')
                    TextButton(
                      onPressed: _billing ? null : _billVisit,
                      child: _billing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Bill'),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pets, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              v.pet?.name ?? 'Pet #${v.petId}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _statusColor(v.status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              v.status,
                              style: TextStyle(color: _statusColor(v.status)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${v.visitDate}${v.visitTime != null ? ' · ${v.visitTime!.substring(0, 5)}' : ''} · ${v.visitType}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      if (v.doctor != null)
                        Text('Dr. ${v.doctor!.name}'),
                      const SizedBox(height: 20),
                      if (v.chiefComplaint != null &&
                          v.chiefComplaint!.isNotEmpty)
                        _section('Chief complaint', v.chiefComplaint!),
                      _vitalsGrid(v),
                      if (v.diagnoses != null && v.diagnoses!.isNotEmpty)
                        _section(
                          'Diagnoses',
                          v.diagnoses!.map((d) => d.diagnosisName).join(', '),
                        ),
                      if (v.treatments != null && v.treatments!.isNotEmpty)
                        _section(
                          'Treatments',
                          v.treatments!
                              .map((t) =>
                                  '${t.treatmentName} × ${t.quantity} @ ${t.unitPrice}')
                              .join('\n'),
                        ),
                      if (v.medicines != null && v.medicines!.isNotEmpty)
                        _section(
                          'Medicines',
                          v.medicines!
                              .map((m) =>
                                  '${m.medicineName}${m.dosage != null ? ' — ${m.dosage}' : ''}')
                              .join('\n'),
                        ),
                      if (v.clinicalNotes != null &&
                          v.clinicalNotes!.isNotEmpty)
                        _section('Clinical notes', v.clinicalNotes!),
                      if (v.followUpDate != null)
                        _section(
                          'Follow-up',
                          [
                            v.followUpDate!,
                            if (v.followUpNotes != null) v.followUpNotes!,
                          ].join('\n'),
                        ),
                      const SizedBox(height: 8),
                      EmrPetHub(petId: v.petId, petName: v.pet?.name),
                      if (v.invoiceId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/invoices/${v.invoiceId}'),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('View invoice'),
                          ),
                        ),
                      if (canEdit && v.status == 'open')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton.icon(
                            onPressed: _deleteVisit,
                            icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                            label: const Text('Delete visit',
                                style: TextStyle(color: AppTheme.danger)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }

  Widget _vitalsGrid(PetVisit v) {
    final items = <String, String>{};
    if (v.temperature != null) items['Temp'] = '${v.temperature} °F';
    if (v.weight != null) items['Weight'] = '${v.weight} kg';
    if (v.heartRate != null) items['HR'] = '${v.heartRate} bpm';
    if (v.respiratoryRate != null) items['RR'] = '${v.respiratoryRate}';
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vitals',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.entries
                .map(
                  (e) => Chip(
                    label: Text('${e.key}: ${e.value}'),
                    backgroundColor: AppTheme.background,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
