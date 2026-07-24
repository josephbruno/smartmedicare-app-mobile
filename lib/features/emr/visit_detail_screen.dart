import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';
import 'emr_pet_hub.dart';
import 'visit_pdf.dart';
import 'widgets/visit_card.dart';

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

  Future<void> _completeVisit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Complete visit?'),
        content: const Text(
          'Marks clinical work done and holds the bill so you can add or edit items before sending to the cashier.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Complete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _billing = true);
    final services = context.read<AppServices>();
    try {
      final visit = await services.emr.completeVisit(widget.visitId);
      if (!mounted) return;
      await VisitPdf.printVisit(visit);
      if (!mounted) return;
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Visit completed. Bill is on hold.')),
      );
      setState(_reload);
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _billing = false);
    }
  }

  Future<void> _releaseForBilling() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Send to cashier?'),
        content: const Text(
          'Releases the bill for cashier billing. Cashiers at this branch will be notified.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _billing = true);
    try {
      await context.read<AppServices>().emr.releaseVisitForBilling(widget.visitId);
      if (mounted) {
        AppMessenger.show(
          context,
          const SnackBar(content: Text('Visit sent to cashier for billing.')),
        );
        setState(_reload);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _billing = false);
    }
  }

  void _billAtPos() {
    context.push('/pos?visit_id=${widget.visitId}');
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
        AppMessenger.show(
          context,
          const SnackBar(content: Text('Visit deleted')),
        );
        context.go('/emr/visits');
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'billed':
      case 'completed':
        return AppTheme.accent;
      case 'bill_on_hold':
        return Colors.orange;
      case 'open':
        return AppTheme.primary;
      case 'cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _statusLabel(String status) => VisitRecordCard.statusLabel(status);

  String _visitTypeLabel(String type) {
    if (type.isEmpty) return '—';
    return type
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '';
    final parts = t.split(':');
    if (parts.length < 2) return t;
    return '${parts[0]}:${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final canEdit = auth.hasPermission('emr.visits.edit');
    final canBill = auth.hasPermission('emr.visits.bill');
    final canComplete = canEdit;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FutureBuilder<PetVisit>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: AppTheme.danger),
                    const SizedBox(height: 12),
                    Text('${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(_reload),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final v = snap.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final pad = constraints.maxWidth >= 720 ? 24.0 : 16.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderCard(
                      visit: v,
                      statusColor: _statusColor(v.status),
                      statusLabel: _statusLabel(v.status),
                      visitTypeLabel: _visitTypeLabel(v.visitType),
                      timeLabel: _formatTime(v.visitTime),
                      onPrint: () => VisitPdf.printVisit(v),
                      onDownload: () => VisitPdf.downloadVisit(v),
                      onEdit: canEdit &&
                              (v.status == 'open' || v.status == 'bill_on_hold')
                          ? () => context.push('/emr/visits/${v.id}/edit')
                          : null,
                      primaryAction: _primaryAction(
                        v: v,
                        canComplete: canComplete,
                        canBill: canBill,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                ..._clinicalSections(v),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                ..._sideSections(v, canEdit),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      ..._clinicalSections(v),
                      ..._sideSections(v, canEdit),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget? _primaryAction({
    required PetVisit v,
    required bool canComplete,
    required bool canBill,
  }) {
    if (canComplete && v.status == 'open') {
      return FilledButton.icon(
        onPressed: _billing ? null : _completeVisit,
        icon: _billing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check_circle_outline, size: 18),
        label: Text(_billing ? 'Working…' : 'Complete'),
      );
    }
    if (canComplete && v.status == 'bill_on_hold') {
      return FilledButton.icon(
        onPressed: _billing ? null : _releaseForBilling,
        icon: _billing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.send_outlined, size: 18),
        label: Text(_billing ? 'Working…' : 'Send to cashier'),
      );
    }
    if (canBill && v.status == 'completed' && AppConfig.isCashierPlatform) {
      return FilledButton.icon(
        onPressed: _billing ? null : _billAtPos,
        icon: const Icon(Icons.point_of_sale_outlined, size: 18),
        label: const Text('Bill at POS'),
      );
    }
    return null;
  }

  List<Widget> _clinicalSections(PetVisit v) {
    return [
      if (v.chiefComplaint != null && v.chiefComplaint!.isNotEmpty)
        _SectionCard(
          icon: Icons.chat_bubble_outline_rounded,
          iconColor: const Color(0xFFEA580C),
          iconBg: const Color(0xFFFFF7ED),
          title: 'Chief complaint',
          child: Text(
            v.chiefComplaint!,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
              height: 1.45,
            ),
          ),
        ),
      if (_hasVitals(v)) ...[
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.monitor_heart_outlined,
          iconColor: const Color(0xFFDC2626),
          iconBg: const Color(0xFFFEF2F2),
          title: 'Vitals',
          child: _VitalsGrid(visit: v),
        ),
      ],
      if (v.diagnoses != null && v.diagnoses!.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.medical_information_outlined,
          iconColor: const Color(0xFF16A34A),
          iconBg: const Color(0xFFF0FDF4),
          title: 'Diagnoses',
          child: Column(
            children: [
              for (var i = 0; i < v.diagnoses!.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _DiagnosisRow(diagnosis: v.diagnoses![i]),
              ],
            ],
          ),
        ),
      ],
      if (v.treatments != null && v.treatments!.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.healing_outlined,
          iconColor: const Color(0xFF7C3AED),
          iconBg: const Color(0xFFF5F3FF),
          title: 'Treatments',
          child: Column(
            children: [
              for (var i = 0; i < v.treatments!.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _TreatmentRow(treatment: v.treatments![i]),
              ],
            ],
          ),
        ),
      ],
      if (v.medicines != null && v.medicines!.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.medication_outlined,
          iconColor: const Color(0xFFA21CAF),
          iconBg: const Color(0xFFFDF4FF),
          title: 'Medicines',
          child: Column(
            children: [
              for (var i = 0; i < v.medicines!.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _MedicineRow(medicine: v.medicines![i]),
              ],
            ],
          ),
        ),
      ],
      if (v.clinicalNotes != null && v.clinicalNotes!.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.notes_outlined,
          iconColor: AppTheme.primary,
          iconBg: const Color(0xFFEFF6FF),
          title: 'Clinical notes',
          child: Text(
            v.clinicalNotes!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _sideSections(PetVisit v, bool canEdit) {
    return [
      if (v.serviceCharge > 0) ...[
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.payments_outlined,
          iconColor: const Color(0xFF0F766E),
          iconBg: const Color(0xFFF0FDFA),
          title: 'Service charge',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹${v.serviceCharge.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (v.serviceChargeProduct != null) ...[
                const SizedBox(height: 4),
                Text(
                  v.serviceChargeProduct!.name,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
      if (v.followUpDate != null) ...[
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.event_outlined,
          iconColor: const Color(0xFFEA580C),
          iconBg: const Color(0xFFFFF7ED),
          title: 'Follow-up',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                v.followUpDate!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (v.followUpNotes != null && v.followUpNotes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  v.followUpNotes!,
                  style: const TextStyle(fontSize: 13, height: 1.45, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      EmrPetHub(petId: v.petId, petName: v.pet?.name),
      if (v.invoiceId != null) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push('/invoices/${v.invoiceId}'),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('View invoice'),
        ),
      ],
      if (canEdit && v.status == 'open') ...[
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _deleteVisit,
          icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 18),
          label: const Text('Delete visit', style: TextStyle(color: AppTheme.danger)),
        ),
      ],
    ];
  }

  bool _hasVitals(PetVisit v) =>
      v.temperature != null ||
      v.weight != null ||
      v.heartRate != null ||
      v.respiratoryRate != null;
}

// ── Header ──────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.visit,
    required this.statusColor,
    required this.statusLabel,
    required this.visitTypeLabel,
    required this.timeLabel,
    required this.onPrint,
    required this.onDownload,
    this.onEdit,
    this.primaryAction,
  });

  final PetVisit visit;
  final Color statusColor;
  final String statusLabel;
  final String visitTypeLabel;
  final String timeLabel;
  final VoidCallback onPrint;
  final VoidCallback onDownload;
  final VoidCallback? onEdit;
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) {
    final petName = visit.pet?.name ?? 'Pet #${visit.petId}';
    final meta = [
      visit.visitDate,
      if (timeLabel.isNotEmpty) timeLabel,
      visitTypeLabel,
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand strip
          Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              gradient: LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primary, statusColor],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top meta row: visit # + status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        visit.visitNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _StatusPill(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 16),
                // Pet identity
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pets_rounded, color: AppTheme.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            petName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            meta,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppTheme.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          if (visit.doctor != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 15, color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Dr. ${visit.doctor!.name}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (visit.pet?.species != null || visit.pet?.breed != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              [visit.pet?.species, visit.pet?.breed]
                                  .where((e) => e != null && e.isNotEmpty)
                                  .join(' · '),
                              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                // Actions
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ActionChipButton(
                      icon: Icons.print_outlined,
                      label: 'Print',
                      onPressed: onPrint,
                    ),
                    _ActionChipButton(
                      icon: Icons.download_outlined,
                      label: 'Download',
                      onPressed: onDownload,
                    ),
                    if (onEdit != null)
                      _ActionChipButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onPressed: onEdit!,
                      ),
                    if (primaryAction != null) ...[
                      const SizedBox(width: 4),
                      primaryAction!,
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        backgroundColor: Colors.white,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── Section card ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Vitals ──────────────────────────────────────────────────────────────────

class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid({required this.visit});

  final PetVisit visit;

  @override
  Widget build(BuildContext context) {
    final items = <_VitalItem>[
      if (visit.temperature != null)
        _VitalItem('Temperature', '${visit.temperature} °F', Icons.thermostat_outlined, const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
      if (visit.weight != null)
        _VitalItem('Weight', '${visit.weight} kg', Icons.monitor_weight_outlined, const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
      if (visit.heartRate != null)
        _VitalItem('Heart rate', '${visit.heartRate} bpm', Icons.favorite_outline, const Color(0xFFEC4899), const Color(0xFFFDF2F8)),
      if (visit.respiratoryRate != null)
        _VitalItem('Resp. rate', '${visit.respiratoryRate} /min', Icons.air_outlined, const Color(0xFF10B981), const Color(0xFFECFDF5)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 480 ? (items.length.clamp(1, 4)) : (items.length > 1 ? 2 : 1);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            final width = cols == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - (10 * (cols - 1))) / cols;
            return SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: item.color.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, size: 18, color: item.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: item.color.withValues(alpha: 0.85),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.value,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _VitalItem {
  const _VitalItem(this.label, this.value, this.icon, this.color, this.bg);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;
}

// ── Diagnosis / treatment / medicine rows ───────────────────────────────────

class _DiagnosisRow extends StatelessWidget {
  const _DiagnosisRow({required this.diagnosis});

  final VisitDiagnosis diagnosis;

  Color get _severityColor {
    switch (diagnosis.severity) {
      case 'severe':
        return AppTheme.danger;
      case 'moderate':
        return AppTheme.warning;
      default:
        return AppTheme.accent;
    }
  }

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
                  if (diagnosis.isPrimary) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Primary',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      diagnosis.diagnosisName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (diagnosis.icdCode != null && diagnosis.icdCode!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  diagnosis.icdCode!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          diagnosis.severity[0].toUpperCase() + diagnosis.severity.substring(1),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _severityColor,
          ),
        ),
      ],
    );
  }
}

class _TreatmentRow extends StatelessWidget {
  const _TreatmentRow({required this.treatment});

  final VisitTreatment treatment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                treatment.treatmentName,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (treatment.notes != null && treatment.notes!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  treatment.notes!,
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '× ${treatment.quantity}  ·  ₹${treatment.unitPrice.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MedicineRow extends StatelessWidget {
  const _MedicineRow({required this.medicine});

  final VisitMedicine medicine;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (medicine.dosage != null && medicine.dosage!.isNotEmpty) medicine.dosage!,
      if (medicine.frequency != null && medicine.frequency!.isNotEmpty) medicine.frequency!,
      if (medicine.durationDays != null) '${medicine.durationDays}d',
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medicine.medicineName,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  details,
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (medicine.isDispensed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Dispensed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF16A34A),
              ),
            ),
          ),
      ],
    );
  }
}
