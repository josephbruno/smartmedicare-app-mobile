import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/router/app_route_observer.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';
import '../../data/models/treatment_under.dart';
import '../../data/models/vaccination_category.dart';
import 'emr_pet_hub.dart';
import 'visit_pdf.dart';
import 'visit_print_preview_screen.dart';
import 'widgets/visit_card.dart';

class VisitDetailScreen extends StatefulWidget {
  const VisitDetailScreen({super.key, required this.visitId});

  final int visitId;

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> with RouteAware {
  late Future<PetVisit> _future;
  bool _billing = false;
  bool _routeSubscribed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route != null) {
      appShellRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void dispose() {
    appShellRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (!mounted) return;
    setState(_reload);
  }

  void _reload() {
    _future = context.read<AppServices>().emr.getVisit(widget.visitId);
  }

  Future<PetVisit> _freshVisit() {
    return context.read<AppServices>().emr.getVisit(widget.visitId);
  }

  Future<VisitClinicInfo> _clinicInfo() {
    final auth = context.read<AuthSession>();
    final services = context.read<AppServices>();
    return VisitPdf.resolveClinic(
      auth: auth,
      branches: services.branches,
    );
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
      await services.emr.completeVisit(widget.visitId);
      if (!mounted) return;
      final visit = await _freshVisit();
      final clinic = await _clinicInfo();
      if (!mounted) return;
      await VisitPrintPreviewScreen.open(
        context,
        visit: visit,
        clinic: clinic,
      );
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
                      onPreview: () async {
                        try {
                          final visit = await _freshVisit();
                          final clinic = await _clinicInfo();
                          if (!context.mounted) return;
                          await VisitPrintPreviewScreen.open(
                            context,
                            visit: visit,
                            clinic: clinic,
                          );
                          if (mounted) setState(_reload);
                        } catch (e) {
                          if (context.mounted) {
                            AppMessenger.show(context, SnackBar(content: Text('$e')));
                          }
                        }
                      },
                      onDownload: () async {
                        try {
                          final visit = await _freshVisit();
                          final clinic = await _clinicInfo();
                          await VisitPdf.downloadVisit(visit, clinic: clinic);
                          if (mounted) setState(_reload);
                        } catch (e) {
                          if (context.mounted) {
                            AppMessenger.show(context, SnackBar(content: Text('$e')));
                          }
                        }
                      },
                      onEdit: canEdit &&
                              (v.status == 'open' || v.status == 'bill_on_hold')
                          ? () async {
                              await context.push('/emr/visits/${v.id}/edit');
                              if (mounted) setState(_reload);
                            }
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
      if (v.investigationItems.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.biotech_outlined,
          iconColor: const Color(0xFF0F766E),
          iconBg: const Color(0xFFF0FDFA),
          title: 'Investigation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < v.investigationItems.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                Text(
                  v.investigationItems[i].name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (v.investigationItems[i].notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    v.investigationItems[i].notes,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
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
          title: 'Prescriptions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in TreatmentUnderCategory.groupBy(
                v.medicines!,
                (m) => m.treatmentUnderCategory ?? m.product?.treatmentUnderCategory,
              ).asMap().entries) ...[
                if (entry.key > 0) const SizedBox(height: 12),
                Text(
                  TreatmentUnderCategory.labelOf(entry.value.key),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < entry.value.value.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  _MedicineRow(medicine: entry.value.value[i]),
                ],
              ],
            ],
          ),
        ),
      ],
      if (v.vaccinations != null && v.vaccinations!.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.vaccines_outlined,
          iconColor: const Color(0xFF059669),
          iconBg: const Color(0xFFECFDF5),
          title: 'Vaccinations',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final group in VaccinationCategory.groupBy(
                v.vaccinations!,
                (PetVaccination item) => VaccinationCategory.forVisit(
                  snapshot: item.category,
                  name: item.vaccineName,
                ),
              )) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    VaccinationCategory.labelOf(group.key),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                for (var i = 0; i < group.value.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  _VaccinationRow(vaccination: group.value[i]),
                ],
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
      if (v.dewormings != null && v.dewormings!.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.bug_report_outlined,
          iconColor: const Color(0xFFD97706),
          iconBg: const Color(0xFFFFFBEB),
          title: 'Deworming',
          child: Column(
            children: [
              for (var i = 0; i < v.dewormings!.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _DewormingRow(record: v.dewormings![i]),
              ],
            ],
          ),
        ),
      ],
      if (v.surgeries != null && v.surgeries!.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.local_hospital_outlined,
          iconColor: const Color(0xFFDC2626),
          iconBg: const Color(0xFFFEF2F2),
          title: 'Surgery',
          child: Column(
            children: [
              for (var i = 0; i < v.surgeries!.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _SurgeryRow(surgery: v.surgeries![i]),
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
    required this.onPreview,
    required this.onDownload,
    this.onEdit,
    this.primaryAction,
  });

  final PetVisit visit;
  final Color statusColor;
  final String statusLabel;
  final String visitTypeLabel;
  final String timeLabel;
  final VoidCallback onPreview;
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
                      icon: Icons.preview_outlined,
                      label: 'Preview',
                      onPressed: onPreview,
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
        _VitalItem(
          'Temperature',
          '${((visit.temperature! * 9 / 5) + 32).toStringAsFixed(1)} °F',
          Icons.thermostat_outlined,
          const Color(0xFFEF4444),
          const Color(0xFFFEF2F2),
        ),
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

class _VaccinationRow extends StatelessWidget {
  const _VaccinationRow({required this.vaccination});

  final PetVaccination vaccination;

  @override
  Widget build(BuildContext context) {
    final subtitle = vaccination.nextDueDate != null
        ? 'Next reminder ${vaccination.nextDueDate}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          vaccination.vaccineName,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _DewormingRow extends StatelessWidget {
  const _DewormingRow({required this.record});

  final PetDeworming record;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (record.dosage != null && record.dosage!.isNotEmpty) record.dosage!,
      if (record.nextDueDate != null) 'Next due ${record.nextDueDate}',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          record.medicineName,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _SurgeryRow extends StatelessWidget {
  const _SurgeryRow({required this.surgery});

  final PetSurgery surgery;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (surgery.surgeonName != null && surgery.surgeonName!.isNotEmpty)
        surgery.surgeonName!,
      if (surgery.anesthesiaType != null && surgery.anesthesiaType!.isNotEmpty)
        surgery.anesthesiaType!,
      if (surgery.followUpDate != null) 'Follow-up ${surgery.followUpDate}',
      if (surgery.cost > 0) '₹${surgery.cost.toStringAsFixed(0)}',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          surgery.surgeryName,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }
}
