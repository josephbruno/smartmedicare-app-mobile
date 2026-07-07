import 'package:flutter/material.dart';
import 'package:mobile/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';
import '../../data/models/product.dart';

class VisitFormScreen extends StatefulWidget {
  const VisitFormScreen({super.key, this.visitId, this.appointmentId, this.petId});

  final int? visitId;
  final int? appointmentId;
  final int? petId;

  @override
  State<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends State<VisitFormScreen> {
  final _complaint = TextEditingController();
  final _clinicalNotes = TextEditingController();
  final _followUpNotes = TextEditingController();
  final _temp = TextEditingController();
  final _weight = TextEditingController();
  final _heartRate = TextEditingController();
  final _respiratoryRate = TextEditingController();
  final _diagnosisInput = TextEditingController();
  final _serviceCharge = TextEditingController();

  PetSearchResult? _selectedPet;
  DoctorLite? _selectedDoctor;
  List<DoctorLite> _doctors = [];
  List<PetSearchResult> _petResults = [];
  List<VisitDiagnosis> _diagnoses = [];
  final List<_TreatmentRow> _treatments = [];
  final List<_MedicineRow> _medicines = [];
  List<String> _complaintSuggestions = [];
  List<VisitDiagnosis> _diagnosisSuggestions = [];
  PetSummary? _petSummary;
  int? _serviceChargeProductId;
  String? _serviceChargeProductName;

  String _visitType = 'consultation';
  DateTime _visitDate = DateTime.now();
  TimeOfDay _visitTime = TimeOfDay.now();
  DateTime? _followUpDate;

  bool _loading = false;
  bool _saving = false;
  bool _searchingPets = false;
  int? _sourceAppointmentId;

  bool get _isEdit => widget.visitId != null;

  static const _visitTypes = [
    'consultation',
    'followup',
    'surgery',
    'wellness',
    'emergency',
  ];

  @override
  void initState() {
    super.initState();
    _sourceAppointmentId = widget.appointmentId;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final emr = context.read<AppServices>().emr;
    final auth = context.read<AuthSession>();

    try {
      _doctors = await emr.listDoctors();
      _complaintSuggestions = await emr.getComplaints();

      if (auth.hasRole('doctor') && auth.user != null) {
        _selectedDoctor = _doctors.where((d) => d.id == auth.user!.id).firstOrNull ??
            DoctorLite(id: auth.user!.id, name: auth.user!.name);
      }

      if (_isEdit) {
        final visit = await emr.getVisit(widget.visitId!);
        _applyVisit(visit);
      } else if (_sourceAppointmentId != null) {
        final appt = await emr.getAppointment(_sourceAppointmentId!);
        await _prefillFromAppointment(appt);
      } else if (widget.petId != null) {
        await _prefillFromPetId(widget.petId!);
      }

      if (!_isEdit) {
        _applyDoctorServiceChargeDefaults();
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyVisit(PetVisit visit) {
    _selectedPet = visit.pet ??
        PetSearchResult(
          id: visit.petId,
          customerId: visit.customerId,
          name: 'Pet #${visit.petId}',
        );
    if (visit.doctor != null) _selectedDoctor = visit.doctor;
    _visitType = visit.visitType;
    _visitDate = DateTime.tryParse(visit.visitDate) ?? DateTime.now();
    if (visit.visitTime != null && visit.visitTime!.length >= 5) {
      final parts = visit.visitTime!.substring(0, 5).split(':');
      _visitTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    _complaint.text = visit.chiefComplaint ?? '';
    _clinicalNotes.text = visit.clinicalNotes ?? '';
    _followUpNotes.text = visit.followUpNotes ?? '';
    if (visit.temperature != null) _temp.text = visit.temperature.toString();
    if (visit.weight != null) _weight.text = visit.weight.toString();
    if (visit.heartRate != null) _heartRate.text = visit.heartRate.toString();
    if (visit.respiratoryRate != null) {
      _respiratoryRate.text = visit.respiratoryRate.toString();
    }
    if (visit.followUpDate != null) {
      _followUpDate = DateTime.tryParse(visit.followUpDate!);
    }
    _diagnoses = visit.diagnoses ?? [];
    _treatments
      ..clear()
      ..addAll((visit.treatments ?? []).map(_TreatmentRow.fromModel));
    _medicines
      ..clear()
      ..addAll((visit.medicines ?? []).map(_MedicineRow.fromModel));
    if (visit.serviceCharge > 0) {
      _serviceCharge.text = visit.serviceCharge.toString();
    } else {
      _serviceCharge.clear();
    }
    _serviceChargeProductId = visit.serviceChargeProductId;
    _serviceChargeProductName = visit.serviceChargeProduct?.name;
  }

  void _applyDoctorServiceChargeDefaults() {
    final doctor = _selectedDoctor;
    if (doctor == null || _serviceCharge.text.trim().isNotEmpty) return;
    final fee = doctor.consultationFee;
    if (fee != null && fee > 0) {
      _serviceCharge.text = fee == fee.roundToDouble()
          ? fee.toInt().toString()
          : fee.toString();
    }
  }

  Future<void> _prefillFromPetId(int petId) async {
    try {
      final summary = await context.read<AppServices>().emr.getPetSummary(petId);
      _selectedPet = PetSearchResult(
        id: summary.id,
        customerId: 0,
        name: summary.name,
        species: summary.species,
        breed: summary.breed,
      );
      _petSummary = summary;
      if (summary.weight != null && _weight.text.isEmpty) {
        _weight.text = summary.weight.toString();
      }
    } catch (_) {}
  }

  Future<void> _prefillFromAppointment(PatientAppointment appt) async {
    if (appt.pet != null) {
      _selectedPet = appt.pet!.withCustomer(appt.customer);
    } else {
      _selectedPet = PetSearchResult(
        id: appt.petId,
        customerId: appt.customerId,
        name: 'Pet #${appt.petId}',
        customerName: appt.customer?.name,
        customerPhone: appt.customer?.phone,
      );
    }
    if (appt.doctor != null) _selectedDoctor = appt.doctor;
    _visitType = appt.appointmentType == 'followup'
        ? 'followup'
        : (appt.appointmentType == 'emergency' ? 'emergency' : 'consultation');
    _visitDate = DateTime.tryParse(appt.appointmentDate) ?? DateTime.now();
    if (appt.appointmentTime.length >= 5) {
      final parts = appt.appointmentTime.substring(0, 5).split(':');
      _visitTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    if (appt.chiefComplaint != null) _complaint.text = appt.chiefComplaint!;
    if (_selectedPet != null) {
      try {
        final summary = await context.read<AppServices>().emr.getPetSummary(_selectedPet!.id);
        if (mounted) setState(() => _petSummary = summary);
        if (summary.weight != null && _weight.text.isEmpty) {
          _weight.text = summary.weight.toString();
        }
      } catch (_) {}
    }
  }

  Future<void> _searchPets(String q) async {
    if (q.length < 2) {
      setState(() => _petResults = []);
      return;
    }
    setState(() => _searchingPets = true);
    try {
      final results = await context.read<AppServices>().emr.searchPets(q);
      if (mounted) setState(() => _petResults = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searchingPets = false);
    }
  }

  Future<void> _selectPet(PetSearchResult pet) async {
    setState(() {
      _selectedPet = pet;
      _petResults = [];
      _petSummary = null;
    });
    try {
      final summary = await context.read<AppServices>().emr.getPetSummary(pet.id);
      if (mounted) {
        setState(() => _petSummary = summary);
        if (summary.weight != null && _weight.text.isEmpty) {
          _weight.text = summary.weight.toString();
        }
      }
    } catch (_) {}
  }

  Future<void> _searchDiagnoses(String q) async {
    if (q.length < 2) {
      setState(() => _diagnosisSuggestions = []);
      return;
    }
    try {
      final results =
          await context.read<AppServices>().emr.getDiagnosisSuggestions(q: q);
      if (mounted) setState(() => _diagnosisSuggestions = results);
    } catch (_) {}
  }

  void _addDiagnosisFromSuggestion(VisitDiagnosis d) {
    if (_diagnoses.any((x) => x.diagnosisName == d.diagnosisName)) return;
    setState(() {
      _diagnoses.add(VisitDiagnosis(
        diagnosisName: d.diagnosisName,
        icdCode: d.icdCode,
        severity: d.severity,
        isPrimary: _diagnoses.isEmpty,
      ));
      _diagnosisInput.clear();
      _diagnosisSuggestions = [];
    });
  }

  Future<Product?> _pickProduct({String? initial, bool servicesOnly = false}) async {
    final search = TextEditingController(text: initial ?? '');
    List<Product> results = [];
    if ((initial ?? '').length >= 2) {
      try {
        results = await context.read<AppServices>().products.list(
              query: {
                'search': initial,
                'per_page': 20,
                if (servicesOnly) 'type': 'service',
              },
            );
      } catch (_) {}
    }

    if (!mounted) return null;
    return showDialog<Product>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          Future<void> runSearch(String q) async {
            if (q.length < 2) {
              setDialog(() => results = []);
              return;
            }
            try {
              final list = await context.read<AppServices>().products.list(
                    query: {
                      'search': q,
                      'per_page': 20,
                      if (servicesOnly) 'type': 'service',
                    },
                  );
              setDialog(() => results = list);
            } catch (_) {}
          }

          return AlertDialog(
            title: Text(servicesOnly ? 'Link service product' : 'Link product'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: search,
                    decoration: const InputDecoration(hintText: 'Search products...'),
                    onChanged: runSearch,
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: results
                          .map(
                            (p) => ListTile(
                              title: Text(p.name),
                              subtitle: Text('₹${p.sellingPrice}'),
                              onTap: () => Navigator.pop(ctx, p),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ],
          );
        },
      ),
    );
  }

  void _addDiagnosis(String name) {
    if (name.trim().isEmpty) return;
    setState(() {
      _diagnoses.add(VisitDiagnosis(
        diagnosisName: name.trim(),
        severity: 'mild',
        isPrimary: _diagnoses.isEmpty,
      ));
      _diagnosisInput.clear();
    });
  }

  Future<void> _save() async {
    if (_selectedPet == null) {
      AppMessenger.show(context,
        const SnackBar(content: Text('Please select a patient (pet)')),
      );
      return;
    }

    setState(() => _saving = true);
    final emr = context.read<AppServices>().emr;

    final timeStr =
        '${_visitTime.hour.toString().padLeft(2, '0')}:${_visitTime.minute.toString().padLeft(2, '0')}';

    final serviceCharge = double.tryParse(_serviceCharge.text.trim()) ?? 0;

    if (serviceCharge > 0 && _serviceChargeProductId == null) {
      try {
        final products = await context.read<AppServices>().products.list(
          query: {'type': 'service', 'per_page': 5, 'search': 'consult'},
        );
        if (products.isNotEmpty) {
          _serviceChargeProductId = products.first.id;
          _serviceChargeProductName ??= products.first.name;
        }
      } catch (_) {}
    }

    final body = <String, dynamic>{
      'pet_id': _selectedPet!.id,
      if (_selectedDoctor != null) 'doctor_id': _selectedDoctor!.id,
      'visit_type': _visitType,
      'visit_date': _visitDate.toIso8601String().substring(0, 10),
      'visit_time': timeStr,
      'service_charge': serviceCharge,
      if (serviceCharge > 0 && _serviceChargeProductId != null)
        'service_charge_product_id': _serviceChargeProductId,
      if (_complaint.text.trim().isNotEmpty) 'chief_complaint': _complaint.text.trim(),
      if (_clinicalNotes.text.trim().isNotEmpty) 'clinical_notes': _clinicalNotes.text.trim(),
      if (_followUpNotes.text.trim().isNotEmpty) 'follow_up_notes': _followUpNotes.text.trim(),
      if (_temp.text.isNotEmpty) 'temperature': double.tryParse(_temp.text),
      if (_weight.text.isNotEmpty) 'weight': double.tryParse(_weight.text),
      if (_heartRate.text.isNotEmpty) 'heart_rate': int.tryParse(_heartRate.text),
      if (_respiratoryRate.text.isNotEmpty) 'respiratory_rate': int.tryParse(_respiratoryRate.text),
      if (_followUpDate != null)
        'follow_up_date': _followUpDate!.toIso8601String().substring(0, 10),
      if (_diagnoses.isNotEmpty)
        'diagnoses': _diagnoses.map((d) => d.toJson()).toList(),
      if (_treatments.isNotEmpty)
        'treatments': _treatments.map((t) => t.toJson()).toList(),
      if (_medicines.isNotEmpty)
        'medicines': _medicines.map((m) => m.toJson()).toList(),
    };

    try {
      PetVisit visit;
      if (_isEdit) {
        visit = await emr.updateVisit(widget.visitId!, body);
      } else {
        visit = await emr.createVisit(body);
        if (_sourceAppointmentId != null) {
          try {
            await emr.updateAppointment(_sourceAppointmentId!, {
              'status': 'in_progress',
              'visit_id': visit.id,
            });
          } catch (_) {}
        }
      }
      if (mounted) {
        context.go('/emr/visits/${visit.id}');
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _complaint.dispose();
    _clinicalNotes.dispose();
    _followUpNotes.dispose();
    _temp.dispose();
    _weight.dispose();
    _heartRate.dispose();
    _respiratoryRate.dispose();
    _diagnosisInput.dispose();
    _serviceCharge.dispose();
    for (final t in _treatments) {
      t.dispose();
    }
    for (final m in _medicines) {
      m.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit visit' : 'New visit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_selectedPet == null) ...[
            TextField(
              decoration: InputDecoration(
                labelText: 'Search patient (pet or owner)',
                suffixIcon: _searchingPets
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
              ),
              onChanged: _searchPets,
            ),
            ..._petResults.map(
              (p) => ListTile(
                title: Text(p.displayLabel),
                onTap: () => _selectPet(p),
              ),
            ),
          ] else
            Card(
              color: AppTheme.primary.withValues(alpha: 0.06),
              child: ListTile(
                leading: const Icon(Icons.pets, color: AppTheme.primary),
                title: Text(_selectedPet!.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_selectedPet!.displayLabel),
                trailing: _isEdit
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _selectedPet = null;
                          _petSummary = null;
                        }),
                      ),
              ),
            ),
          if (_petSummary != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Patient context',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    if (_petSummary!.allergies.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Allergies: ${_petSummary!.allergies.join(', ')}',
                          style: const TextStyle(color: AppTheme.danger),
                        ),
                      ),
                    if (_petSummary!.medicalNotes != null &&
                        _petSummary!.medicalNotes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_petSummary!.medicalNotes!),
                      ),
                    if (_petSummary!.lastVisits.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Recent visits',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ..._petSummary!.lastVisits.take(2).map(
                            (v) => Text(
                              '${v.visitDate} · ${v.chiefComplaint ?? v.visitType}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _visitType,
            decoration: const InputDecoration(labelText: 'Visit type'),
            items: _visitTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _visitType = v ?? 'consultation'),
          ),
          const SizedBox(height: 12),
          if (_doctors.isNotEmpty)
            DropdownButtonFormField<int>(
              value: _selectedDoctor?.id,
              decoration: const InputDecoration(labelText: 'Doctor'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— None —')),
                ..._doctors.map(
                  (d) => DropdownMenuItem(
                    value: d.id,
                    child: Text(d.specialty != null ? '${d.name} (${d.specialty})' : d.name),
                  ),
                ),
              ],
              onChanged: (id) => setState(() {
                _selectedDoctor = id == null
                    ? null
                    : _doctors.firstWhere((d) => d.id == id);
                _applyDoctorServiceChargeDefaults();
              }),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Service charge',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Billable', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _serviceCharge,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.inventory_2_outlined, size: 22),
                tooltip: 'Link service product (for GST)',
                onPressed: () async {
                  final p = await _pickProduct(
                    servicesOnly: true,
                    initial: _serviceChargeProductName ?? 'consultation',
                  );
                  if (p != null) {
                    setState(() {
                      _serviceChargeProductId = p.id;
                      _serviceChargeProductName = p.name;
                      if (_serviceCharge.text.trim().isEmpty) {
                        _serviceCharge.text = p.sellingPrice.toString();
                      }
                    });
                  }
                },
              ),
            ],
          ),
          if (_serviceChargeProductName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Service product: $_serviceChargeProductName',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _visitDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _visitDate = d);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_visitDate.toIso8601String().substring(0, 10)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _visitTime,
                    );
                    if (t != null) setState(() => _visitTime = t);
                  },
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text(_visitTime.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Chief complaint',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _complaint,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Reason for visit'),
          ),
          if (_complaintSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _complaintSuggestions.take(8).map((c) {
                return ActionChip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    _complaint.text =
                        _complaint.text.isEmpty ? c : '${_complaint.text}, $c';
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          Text('Vitals', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _temp,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Temp °F',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Weight kg',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heartRate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Heart rate',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _respiratoryRate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Resp. rate',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Diagnoses', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _diagnosisInput,
                  decoration: const InputDecoration(hintText: 'Search or add diagnosis'),
                  onChanged: _searchDiagnoses,
                  onSubmitted: _addDiagnosis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _addDiagnosis(_diagnosisInput.text),
              ),
            ],
          ),
          if (_diagnosisSuggestions.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _diagnosisSuggestions
                  .map(
                    (d) => ActionChip(
                      label: Text(
                        d.icdCode != null ? '${d.diagnosisName} (${d.icdCode})' : d.diagnosisName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _addDiagnosisFromSuggestion(d),
                    ),
                  )
                  .toList(),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _diagnoses
                .map(
                  (d) => Chip(
                    label: Text(d.diagnosisName),
                    onDeleted: () =>
                        setState(() => _diagnoses.remove(d)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Treatments / Procedures',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Billable', style: TextStyle(fontSize: 11)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _treatments.add(_TreatmentRow())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_treatments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No treatments added',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ),
          ..._treatments.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Treatment name',
                              isDense: true,
                            ),
                            controller: t.nameCtrl,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.inventory_2_outlined, size: 20),
                          tooltip: 'Link product',
                          onPressed: () async {
                            final p = await _pickProduct(initial: t.nameCtrl.text);
                            if (p != null) {
                              setState(() {
                                t.productId = p.id;
                                t.nameCtrl.text = p.name;
                                t.priceCtrl.text = p.sellingPrice.toString();
                              });
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.danger),
                          onPressed: () => setState(() => _treatments.removeAt(i)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                            keyboardType: TextInputType.number,
                            controller: t.qtyCtrl,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(labelText: 'Price', isDense: true),
                            keyboardType: TextInputType.number,
                            controller: t.priceCtrl,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Prescriptions / Medicines',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _medicines.add(_MedicineRow())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_medicines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No medicines added',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ),
          ..._medicines.asMap().entries.map((e) {
            final i = e.key;
            final m = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Medicine name',
                              isDense: true,
                            ),
                            controller: m.nameCtrl,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.inventory_2_outlined, size: 20),
                          onPressed: () async {
                            final p = await _pickProduct(initial: m.nameCtrl.text);
                            if (p != null) {
                              setState(() {
                                m.productId = p.id;
                                m.nameCtrl.text = p.name;
                                m.priceCtrl.text = p.sellingPrice.toString();
                              });
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.danger),
                          onPressed: () => setState(() => _medicines.removeAt(i)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(labelText: 'Dosage', isDense: true),
                            controller: m.dosageCtrl,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(labelText: 'Frequency', isDense: true),
                            controller: m.freqCtrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(labelText: 'Days', isDense: true),
                            keyboardType: TextInputType.number,
                            controller: m.daysCtrl,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                            keyboardType: TextInputType.number,
                            controller: m.qtyCtrl,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(labelText: 'Price', isDense: true),
                            keyboardType: TextInputType.number,
                            controller: m.priceCtrl,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          TextField(
            controller: _clinicalNotes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Clinical notes'),
          ),
          const SizedBox(height: 16),
          Text('Follow-up', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _followUpDate = d);
            },
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(_followUpDate != null
                ? _followUpDate!.toIso8601String().substring(0, 10)
                : 'Set follow-up date'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _followUpNotes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Follow-up instructions'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEdit ? 'Update visit' : 'Create visit'),
          ),
        ],
      ),
    );
  }
}

class _TreatmentRow {
  _TreatmentRow({
    this.productId,
    String name = '',
    double quantity = 1,
    double unitPrice = 0,
  })  : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: quantity.toString()),
        priceCtrl = TextEditingController(text: unitPrice.toString());

  factory _TreatmentRow.fromModel(VisitTreatment t) => _TreatmentRow(
        productId: t.productId,
        name: t.treatmentName,
        quantity: t.quantity,
        unitPrice: t.unitPrice,
      );

  int? productId;
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  Map<String, dynamic> toJson() => {
        if (productId != null) 'product_id': productId,
        'treatment_name': nameCtrl.text.trim(),
        'quantity': double.tryParse(qtyCtrl.text) ?? 1,
        'unit_price': double.tryParse(priceCtrl.text) ?? 0,
      };

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _MedicineRow {
  _MedicineRow({
    this.productId,
    String name = '',
    String dosage = '',
    String frequency = '',
    int? durationDays,
    double quantity = 1,
    double unitPrice = 0,
  })  : nameCtrl = TextEditingController(text: name),
        dosageCtrl = TextEditingController(text: dosage),
        freqCtrl = TextEditingController(text: frequency),
        daysCtrl = TextEditingController(text: durationDays?.toString() ?? ''),
        qtyCtrl = TextEditingController(text: quantity.toString()),
        priceCtrl = TextEditingController(text: unitPrice.toString());

  factory _MedicineRow.fromModel(VisitMedicine m) => _MedicineRow(
        productId: m.productId,
        name: m.medicineName,
        dosage: m.dosage ?? '',
        frequency: m.frequency ?? '',
        durationDays: m.durationDays,
        quantity: m.quantity,
        unitPrice: m.unitPrice,
      );

  int? productId;
  final TextEditingController nameCtrl;
  final TextEditingController dosageCtrl;
  final TextEditingController freqCtrl;
  final TextEditingController daysCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  Map<String, dynamic> toJson() => {
        if (productId != null) 'product_id': productId,
        'medicine_name': nameCtrl.text.trim(),
        if (dosageCtrl.text.isNotEmpty) 'dosage': dosageCtrl.text.trim(),
        if (freqCtrl.text.isNotEmpty) 'frequency': freqCtrl.text.trim(),
        if (daysCtrl.text.isNotEmpty) 'duration_days': int.tryParse(daysCtrl.text),
        'quantity': double.tryParse(qtyCtrl.text) ?? 1,
        'unit_price': double.tryParse(priceCtrl.text) ?? 0,
      };

  void dispose() {
    nameCtrl.dispose();
    dosageCtrl.dispose();
    freqCtrl.dispose();
    daysCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}
