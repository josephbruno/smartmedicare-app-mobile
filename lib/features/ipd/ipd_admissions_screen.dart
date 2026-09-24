import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/messaging/app_messenger.dart';
import '../../core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _admit,
        icon: const Icon(Icons.add),
        label: const Text('Admit Patient'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _admissions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final admission = _admissions[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.local_hospital_outlined),
                      ),
                      title: Text(
                        admission.patient?.name ?? admission.admissionNumber,
                      ),
                      subtitle: Text(
                        '${admission.ward?.name ?? 'Ward'} / Bed ${admission.bed?.bedNumber ?? '—'}\n${admission.admissionNumber}',
                      ),
                      isThreeLine: true,
                      trailing: admission.status == 'admitted'
                          ? TextButton(
                              onPressed: () => _discharge(admission),
                              child: const Text('Discharge'),
                            )
                          : Text(admission.status),
                    ),
                  );
                },
              ),
            ),
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
