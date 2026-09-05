import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/router/app_route_observer.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';
import 'visit_pdf.dart';

/// All visit records for one pet, laid out like the visit print summary.
class PetVisitSummaryScreen extends StatefulWidget {
  const PetVisitSummaryScreen({super.key, required this.petId});

  final int petId;

  @override
  State<PetVisitSummaryScreen> createState() => _PetVisitSummaryScreenState();
}

class _PetVisitSummaryScreenState extends State<PetVisitSummaryScreen>
    with RouteAware {
  late Future<({List<PetVisit> visits, VisitClinicInfo clinic})> _future;
  var _busy = false;
  var _routeSubscribed = false;

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
    final services = context.read<AppServices>();
    final auth = context.read<AuthSession>();
    _future = () async {
      final visits = await services.emr.listVisitsForPet(widget.petId);
      final clinic = await VisitPdf.resolveClinic(
        auth: auth,
        branches: services.branches,
      );
      return (visits: visits, clinic: clinic);
    }();
  }

  Future<List<PetVisit>> _freshVisits(List<PetVisit> visits) {
    return context.read<AppServices>().emr.getVisitsFresh(
      visits.map((v) => v.id),
    );
  }

  Future<VisitClinicInfo> _clinicInfo() {
    final services = context.read<AppServices>();
    final auth = context.read<AuthSession>();
    return VisitPdf.resolveClinic(
      auth: auth,
      branches: services.branches,
    );
  }

  Future<void> _printAll(List<PetVisit> visits) async {
    if (visits.isEmpty) return;
    setState(() => _busy = true);
    try {
      final clinic = await _clinicInfo();
      final fresh = await _freshVisits(visits);
      await VisitPdf.printVisits(fresh, clinic: clinic);
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadAll(List<PetVisit> visits) async {
    if (visits.isEmpty) return;
    setState(() => _busy = true);
    try {
      final clinic = await _clinicInfo();
      final fresh = await _freshVisits(visits);
      await VisitPdf.downloadVisits(fresh, clinic: clinic);
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FutureBuilder<({List<PetVisit> visits, VisitClinicInfo clinic})>(
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

          final visits = snap.data?.visits ?? const <PetVisit>[];
          final clinic = snap.data?.clinic ??
              const VisitClinicInfo(name: 'Clinic');
          final petName = visits.isNotEmpty
              ? (visits.first.pet?.name ?? 'Pet #${widget.petId}')
              : 'Pet #${widget.petId}';

          return LayoutBuilder(
            builder: (context, constraints) {
              final pad = constraints.maxWidth >= 720 ? 24.0 : 16.0;
              final wide = constraints.maxWidth >= 720;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 16, pad, 8),
                    sliver: SliverToBoxAdapter(
                      child: _Toolbar(
                        petName: petName,
                        visitCount: visits.length,
                        busy: _busy,
                        onPrint: visits.isEmpty ? null : () => _printAll(visits),
                        onDownload: visits.isEmpty ? null : () => _downloadAll(visits),
                        onRefresh: () => setState(_reload),
                      ),
                    ),
                  ),
                  if (visits.isEmpty)
                    const _EmptyVisits()
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(pad, 8, pad, 40),
                      sliver: SliverList.separated(
                        itemCount: visits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, i) {
                          final v = visits[i];
                          return _VisitSummaryCard(
                            visit: v,
                            clinic: clinic,
                            wide: wide,
                            onOpen: () async {
                              await context.push('/emr/visits/${v.id}');
                              if (mounted) setState(_reload);
                            },
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyVisits extends StatelessWidget {
  const _EmptyVisits();

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.medical_services_outlined,
                  size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const Text(
                'No visit records yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Completed and open visits for this patient will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.petName,
    required this.visitCount,
    required this.busy,
    required this.onPrint,
    required this.onDownload,
    required this.onRefresh,
  });

  final String petName;
  final int visitCount;
  final bool busy;
  final VoidCallback? onPrint;
  final VoidCallback? onDownload;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_outlined, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visit summary · $petName',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  visitCount == 0
                      ? 'No records'
                      : '$visitCount visit${visitCount == 1 ? '' : 's'} · same layout as print',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : onRefresh,
            icon: const Icon(Icons.refresh, size: 20),
          ),
          IconButton(
            tooltip: 'Download PDF',
            onPressed: busy || onDownload == null ? null : onDownload,
            icon: const Icon(Icons.download_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Print all',
            onPressed: busy || onPrint == null ? null : onPrint,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}

class _VisitSummaryCard extends StatelessWidget {
  const _VisitSummaryCard({
    required this.visit,
    required this.clinic,
    required this.wide,
    required this.onOpen,
  });

  final PetVisit visit;
  final VisitClinicInfo clinic;
  final bool wide;
  final VoidCallback onOpen;

  static const _border = Color(0xFFE2E8F0);
  static const _ink = Color(0xFF0F172A);
  static const _surface = Color(0xFFF8FAFC);

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '';
    final parts = t.split(':');
    if (parts.length < 2) return t;
    return '${parts[0]}:${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final petName = visit.pet?.name ?? 'Pet #${visit.petId}';
    final time = _formatTime(visit.visitTime);
    final species = [
      visit.pet?.species,
      visit.pet?.breed,
    ].whereType<String>().where((e) => e.isNotEmpty).join(' · ');
    final owner = visit.pet?.customerName?.trim().isNotEmpty == true
        ? visit.pet!.customerName!
        : '—';
    final phone = visit.pet?.customerPhone?.trim() ?? '';
    final petLine = [
      petName,
      if (species.isNotEmpty) species,
      if (visit.doctor != null) 'Dr. ${visit.doctor!.name}',
    ].join(' · ');
    final visitMeta = [
      visit.visitNumber,
      visit.visitDate,
      if (time.isNotEmpty) time,
    ].join(' · ');
    final clinicSubtitle = [
      if (clinic.address.trim().isNotEmpty) clinic.address.trim(),
      if (clinic.phone != null && clinic.phone!.trim().isNotEmpty) clinic.phone!.trim(),
    ].join('  ·  ');

    final left = _ClinicalColumn(visit: visit);
    final right = _ProceduresColumn(visit: visit);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Match print: ~4 blank lines above clinic header.
              const SizedBox(height: 56),
              Column(
                children: [
                  Text(
                    clinic.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  if (clinicSubtitle.isNotEmpty)
                    Text(
                      clinicSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: _ink,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: _border),
              const SizedBox(height: 10),
              // Owner / Pet / Visit
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Kv('Owner', [owner, if (phone.isNotEmpty) phone].join(' · '))),
                          _vDivider(),
                          Expanded(child: _Kv('Pet', petLine)),
                          _vDivider(),
                          Expanded(child: _Kv('Visit', visitMeta)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Kv('Owner', [owner, if (phone.isNotEmpty) phone].join(' · ')),
                          const SizedBox(height: 8),
                          _Kv('Pet', petLine),
                          const SizedBox(height: 8),
                          _Kv('Visit', visitMeta),
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              if (wide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _Panel(child: left)),
                      const SizedBox(width: 10),
                      Expanded(child: _Panel(child: right)),
                    ],
                  ),
                )
              else ...[
                _Panel(child: left),
                const SizedBox(height: 10),
                _Panel(child: right),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _vDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: _border,
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text, {this.semi = false});

  final String text;
  final bool semi;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.35,
        fontWeight: semi ? FontWeight.w600 : FontWeight.w400,
        color: const Color(0xFF0F172A),
      ),
    );
  }
}

class _ClinicalColumn extends StatelessWidget {
  const _ClinicalColumn({required this.visit});

  final PetVisit visit;

  @override
  Widget build(BuildContext context) {
    final vitals = <String>[];
    if (visit.temperature != null) {
      final f = (visit.temperature! * 9 / 5) + 32;
      vitals.add('Temp ${f.toStringAsFixed(1)} °F');
    }
    if (visit.weight != null) vitals.add('Wt ${visit.weight} kg');
    if (visit.heartRate != null) vitals.add('HR ${visit.heartRate} bpm');
    if (visit.respiratoryRate != null) {
      vitals.add('RR ${visit.respiratoryRate} /min');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Complaint'),
        _BodyText(
          visit.chiefComplaint?.trim().isNotEmpty == true
              ? visit.chiefComplaint!
              : '—',
        ),
        if (vitals.isNotEmpty) ...[
          const _DividerLine(),
          const _SectionTitle('Vitals'),
          _BodyText(vitals.join(' · ')),
        ],
        const _DividerLine(),
        const _SectionTitle('Investigation'),
        if (visit.investigationItems.isEmpty)
          const _BodyText('—')
        else
          for (var i = 0; i < visit.investigationItems.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _BodyText(visit.investigationItems[i].name, semi: true),
            if (visit.investigationItems[i].notes.trim().isNotEmpty)
              _BodyText(visit.investigationItems[i].notes),
          ],
        const _DividerLine(),
        const _SectionTitle('Follow-up'),
        if (visit.followUpDate != null) ...[
          _BodyText(visit.followUpDate!, semi: true),
          if (visit.followUpNotes != null && visit.followUpNotes!.trim().isNotEmpty)
            _BodyText(visit.followUpNotes!),
        ] else
          const _BodyText('—'),
      ],
    );
  }
}

class _ProceduresColumn extends StatelessWidget {
  const _ProceduresColumn({required this.visit});

  final PetVisit visit;

  @override
  Widget build(BuildContext context) {
    final kitLines = VisitSummaryTreatmentLine.fromTreatments(
      visit.treatments ?? const <VisitTreatment>[],
    );
    final clinicMeds = VisitMedicine.clinicTreatments(visit.medicines);
    final rxMeds = VisitMedicine.prescriptionsOf(visit.medicines);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Treatments'),
        if (kitLines.isEmpty && clinicMeds.isEmpty)
          const _BodyText('—')
        else ...[
          for (var i = 0; i < kitLines.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BodyText(kitLines[i].name, semi: true),
                      if (!kitLines[i].fromKit &&
                          kitLines[i].notes != null &&
                          kitLines[i].notes!.trim().isNotEmpty)
                        _BodyText(kitLines[i].notes!),
                    ],
                  ),
                ),
                if (!kitLines[i].fromKit && kitLines[i].quantity != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '× ${kitLines[i].quantity}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (kitLines.isNotEmpty && clinicMeds.isNotEmpty)
            const SizedBox(height: 8),
          for (var i = 0; i < clinicMeds.length; i++) ...[
            if (i > 0 || kitLines.isNotEmpty) const SizedBox(height: 6),
            _summaryMedicineRow(clinicMeds[i]),
          ],
        ],
        const _DividerLine(),
        const _SectionTitle('Prescriptions'),
        if (rxMeds.isEmpty)
          const _BodyText('—')
        else
          for (var i = 0; i < rxMeds.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _summaryMedicineRow(rxMeds[i]),
          ],
      ],
    );
  }

  Widget _summaryMedicineRow(VisitMedicine med) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BodyText(med.medicineName, semi: true),
              if (_medicineMeta(med).isNotEmpty)
                _BodyText(_medicineMeta(med)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '× ${med.quantity}',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  static String _medicineMeta(VisitMedicine med) {
    return [
      if (med.frequency != null && med.frequency!.isNotEmpty) med.frequency!,
      if (med.durationDays != null) '${med.durationDays}d',
    ].join(' · ');
  }
}
