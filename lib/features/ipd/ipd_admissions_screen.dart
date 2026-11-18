import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/messaging/app_messenger.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/ist.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../core/widgets/web_page.dart';
import '../../data/models/api_response.dart';
import '../../data/models/emr.dart';
import '../../data/models/ipd.dart';

class IpdAdmissionsScreen extends StatefulWidget {
  const IpdAdmissionsScreen({super.key});

  @override
  State<IpdAdmissionsScreen> createState() => _IpdAdmissionsScreenState();
}

class _IpdAdmissionsScreenState extends State<IpdAdmissionsScreen> {
  List<IpdAdmission> _admissions = [];
  List<IpdWard> _wards = [];
  List<PetSearchResult> _patients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final services = context.read<AppServices>();
      final admissions = await services.ipd.admissions(perPage: 100);
      final wards = await services.ipd.wards();
      final patients = await services.emr.listPatientsPaginated(perPage: 100);
      if (!mounted) return;
      setState(() {
        _admissions = admissions.items;
        _wards = wards;
        _patients = patients.items;
      });
    } catch (error) {
      if (mounted) AppMessenger.error(context, 'Unable to load IPD: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _admit() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AdmissionDialog(
        patients: _patients,
        wards: _wards,
      ),
    );
    if (!mounted || result == null) return;
    try {
      await context.read<AppServices>().ipd.admit(result);
      if (mounted) AppMessenger.success(context, 'Patient admitted');
      await _load();
    } catch (error) {
      if (mounted) AppMessenger.error(context, 'Admission failed: $error');
    }
  }

  Future<void> _discharge(IpdAdmission admission) async {
    final controller = TextEditingController();
    final summary = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discharge Patient'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Discharge summary *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Discharge'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || summary == null || summary.isEmpty) return;
    try {
      await context.read<AppServices>().ipd.discharge(
        admission.id,
        {'discharge_summary': summary},
      );
      if (mounted) AppMessenger.success(context, 'Patient discharged');
      await _load();
    } catch (error) {
      if (mounted) AppMessenger.error(context, 'Discharge failed: $error');
    }
  }

  Future<void> _createWard() async {
    final created = await showDialog<bool>(context: context, builder: (_) => const _WardDialog());
    if (created == true && mounted) {
      AppMessenger.success(context, 'Ward and beds created');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: 'Inpatient Admissions',
        subtitle: 'Manage wards, beds, active admissions, nursing care, and discharge.',
        icon: Icons.local_hospital_outlined,
        breadcrumbs: const [Crumb('Medical Records'), Crumb('IPD Admissions')],
        actions: [
          OutlinedButton(onPressed: _createWard, child: const Text('Create Ward')),
          FilledButton(onPressed: _admit, child: const Text('Admit Patient')),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : AppPaginatedTable<IpdAdmission>(
                key: ValueKey(_admissions.length.toString() + _admissions.map((a) => a.status).join()),
                perPage: 20,
                emptyMessage: 'No admissions yet',
                loadPage: ({required page, required perPage}) async {
                  final r = paginateList(_admissions, page: page, perPage: perPage);
                  return (items: r.items, meta: r.meta as PaginationMeta?);
                },
                columns: [
                  TableColumnDef(
                    label: 'Admission #',
                    flex: 1.2,
                    minWidth: 130,
                    cellBuilder: (_, a) =>
                        Text(a.admissionNumber, style: const TextStyle(color: AppTokens.primary, fontWeight: FontWeight.w600)),
                  ),
                  TableColumnDef(label: 'Patient', flex: 1.6, minWidth: 160, cellBuilder: (_, a) => Text(a.patient?.name ?? '—')),
                  TableColumnDef(
                    label: 'Ward / Bed',
                    flex: 1.4,
                    minWidth: 140,
                    cellBuilder: (_, a) => Text('${a.ward?.name ?? '—'} / ${a.bed?.bedNumber ?? '—'}'),
                  ),
                  TableColumnDef(label: 'Admitted', flex: 1.4, minWidth: 150, cellBuilder: (_, a) => Text(formatDateTimeIst(a.admittedAt))),
                  TableColumnDef(
                    label: 'Status',
                    flex: 1,
                    minWidth: 100,
                    cellBuilder: (_, a) => StatusPill(a.status, tone: a.status == 'admitted' ? PillTone.green : PillTone.grey),
                  ),
                  TableColumnDef(
                    label: 'Action',
                    flex: 1,
                    minWidth: 110,
                    cellBuilder: (_, a) => a.status == 'admitted'
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)),
                            onPressed: () => _discharge(a),
                            child: const Text('Discharge'),
                          )
                        : const Text('—', style: TextStyle(color: AppTokens.text3)),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WardDialog extends StatefulWidget {
  const _WardDialog();

  @override
  State<_WardDialog> createState() => _WardDialogState();
}

class _WardDialogState extends State<_WardDialog> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _beds = TextEditingController();
  final _rate = TextEditingController(text: '0');
  String _type = 'general';
  bool _saving = false;

  static const _types = ['general', 'icu', 'emergency', 'maternity', 'pediatric', 'private', 'other'];

  @override
  void dispose() {
    for (final c in [_name, _code, _beds, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final beds = _beds.text.split(',').map((b) => b.trim()).where((b) => b.isNotEmpty).toList();
    if (_name.text.trim().isEmpty || _code.text.trim().isEmpty || beds.isEmpty) {
      AppMessenger.error(context, 'Ward name, code, and at least one bed are required');
      return;
    }
    final rate = double.tryParse(_rate.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      await context.read<AppServices>().ipd.createWard({
        'name': _name.text.trim(),
        'code': _code.text.trim().toUpperCase(),
        'type': _type,
        'beds': [for (final b in beds) {'bed_number': b, 'daily_rate': rate}],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Failed to create ward: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Ward & Beds'),
      content: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FieldLabel('Ward Name', child: TextField(controller: _name)),
          const SizedBox(height: 12),
          FieldLabel('Ward Code', child: TextField(controller: _code, textCapitalization: TextCapitalization.characters)),
          const SizedBox(height: 12),
          FieldLabel(
            'Ward Type',
            child: FilterSelect<String>(
              hint: 'Ward type',
              options: {for (final t in _types) t: t.toUpperCase()},
              value: _type,
              onChanged: (v) => setState(() => _type = v ?? 'general'),
            ),
          ),
          const SizedBox(height: 12),
          FieldLabel('Bed Numbers (comma separated)',
              child: TextField(controller: _beds, decoration: const InputDecoration(hintText: 'G-01, G-02, G-03'))),
          const SizedBox(height: 12),
          FieldLabel('Daily Bed Rate',
              child: TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
        ]),
      ),
      actions: [
        OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Create Ward')),
      ],
    );
  }
}

class _AdmissionDialog extends StatefulWidget {
  const _AdmissionDialog({required this.patients, required this.wards});

  final List<PetSearchResult> patients;
  final List<IpdWard> wards;

  @override
  State<_AdmissionDialog> createState() => _AdmissionDialogState();
}

class _AdmissionDialogState extends State<_AdmissionDialog> {
  int? _patientId;
  int? _bedId;
  final _reason = TextEditingController();
  final _diagnosis = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    _diagnosis.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beds = widget.wards
        .expand((ward) => ward.beds.map((bed) => (ward: ward, bed: bed)))
        .where((item) => item.bed.status == 'available')
        .toList();
    return AlertDialog(
      title: const Text('Admit Patient'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _patientId,
                decoration: const InputDecoration(labelText: 'Patient'),
                items: widget.patients
                    .where((patient) => patient.patientType == 'human')
                    .map((patient) => DropdownMenuItem(
                          value: patient.id,
                          child: Text(patient.name),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _patientId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _bedId,
                decoration: const InputDecoration(labelText: 'Available Bed'),
                items: beds
                    .map((item) => DropdownMenuItem(
                          value: item.bed.id,
                          child: Text(
                            '${item.ward.name} / ${item.bed.bedNumber}',
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _bedId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Admission reason *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _diagnosis,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Provisional diagnosis'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_patientId == null ||
                _bedId == null ||
                _reason.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(context, {
              'patient_id': _patientId,
              'bed_id': _bedId,
              'admission_reason': _reason.text.trim(),
              if (_diagnosis.text.trim().isNotEmpty)
                'provisional_diagnosis': _diagnosis.text.trim(),
            });
          },
          child: const Text('Admit'),
        ),
      ],
    );
  }
}
