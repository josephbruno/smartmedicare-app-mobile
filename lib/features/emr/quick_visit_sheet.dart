import 'package:flutter/material.dart';
import 'package:mobile/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';

/// Compact quick-visit drawer (matches web QuickVisitDrawer).
Future<void> showQuickVisitSheet(
  BuildContext context, {
  VoidCallback? onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _QuickVisitSheet(onSaved: onSaved),
  );
}

class _QuickVisitSheet extends StatefulWidget {
  const _QuickVisitSheet({this.onSaved});

  final VoidCallback? onSaved;

  @override
  State<_QuickVisitSheet> createState() => _QuickVisitSheetState();
}

class _QuickVisitSheetState extends State<_QuickVisitSheet> {
  final _complaint = TextEditingController();
  final _notes = TextEditingController();
  final _petSearch = TextEditingController();

  PetSearchResult? _selectedPet;
  PetSummary? _petContext;
  List<PetSearchResult> _petResults = [];
  List<DoctorLite> _doctors = [];
  DoctorLite? _selectedDoctor;
  List<VisitDiagnosis> _diagnoses = [];

  String _visitType = 'consultation';
  DateTime _visitDate = DateTime.now();
  bool _searchingPets = false;
  bool _saving = false;

  static const _visitTypes = [
    'consultation',
    'followup',
    'surgery',
    'wellness',
    'emergency',
  ];

  static const _diagnosisTemplates = [
    'Gastroenteritis',
    'Bacterial Skin Infection',
    'Upper Respiratory Infection',
    'Otitis Externa',
    'Tick / Flea Infestation',
    'Conjunctivitis',
    'Dental Disease',
    'Anxiety / Stress Response',
    'Urinary Tract Infection',
    'Wound / Laceration',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final emr = context.read<AppServices>().emr;
    final auth = context.read<AuthSession>();
    try {
      _doctors = await emr.listDoctors();
      if (auth.hasRole('doctor') && auth.user != null) {
        _selectedDoctor = _doctors.where((d) => d.id == auth.user!.id).firstOrNull ??
            DoctorLite(id: auth.user!.id, name: auth.user!.name);
      }
      if (mounted) setState(() {});
    } catch (_) {}
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
      _petContext = null;
    });
    try {
      final summary = await context.read<AppServices>().emr.getPetSummary(pet.id);
      if (mounted) setState(() => _petContext = summary);
    } catch (_) {}
  }

  void _addDiagnosis(String name) {
    if (_diagnoses.any((d) => d.diagnosisName == name)) return;
    setState(() {
      _diagnoses.add(VisitDiagnosis(
        diagnosisName: name,
        severity: 'mild',
        isPrimary: _diagnoses.isEmpty,
      ));
    });
  }

  Future<int?> _saveVisit() async {
    if (_selectedPet == null) {
      AppMessenger.show(context,
        const SnackBar(content: Text('Please select a patient')),
      );
      return null;
    }
    setState(() => _saving = true);
    try {
      final visit = await context.read<AppServices>().emr.createVisit({
        'pet_id': _selectedPet!.id,
        if (_selectedDoctor != null) 'doctor_id': _selectedDoctor!.id,
        'visit_type': _visitType,
        'visit_date': _visitDate.toIso8601String().substring(0, 10),
        if (_complaint.text.trim().isNotEmpty) 'chief_complaint': _complaint.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'clinical_notes': _notes.text.trim(),
        if (_diagnoses.isNotEmpty)
          'diagnoses': _diagnoses.map((d) => d.toJson()).toList(),
      });
      return visit.id;
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForm() {
    _complaint.clear();
    _notes.clear();
    _petSearch.clear();
    setState(() {
      _selectedPet = null;
      _petContext = null;
      _diagnoses = [];
      _visitType = 'consultation';
      _visitDate = DateTime.now();
    });
    _bootstrap();
  }

  Future<void> _saveAndOpen() async {
    final id = await _saveVisit();
    if (id == null || !mounted) return;
    widget.onSaved?.call();
    Navigator.pop(context);
    context.push('/emr/visits/$id');
  }

  Future<void> _saveAnother() async {
    final id = await _saveVisit();
    if (id == null || !mounted) return;
    widget.onSaved?.call();
    AppMessenger.show(context,
      const SnackBar(content: Text('Visit saved — add another')),
    );
    _resetForm();
  }

  @override
  void dispose() {
    _complaint.dispose();
    _notes.dispose();
    _petSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: AppTheme.warning),
                    const SizedBox(width: 8),
                    Text('Quick Visit',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_selectedPet == null) ...[
                      TextField(
                        controller: _petSearch,
                        decoration: InputDecoration(
                          labelText: 'Patient (pet or owner) *',
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
                          dense: true,
                          title: Text(p.displayLabel),
                          onTap: () => _selectPet(p),
                        ),
                      ),
                    ] else
                      Card(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        child: ListTile(
                          leading: const Icon(Icons.pets, color: AppTheme.primary),
                          title: Text(_selectedPet!.name),
                          subtitle: _petContext != null
                              ? Text([
                                  if (_petContext!.weight != null)
                                    '${_petContext!.weight} kg',
                                  if (_petContext!.allergies.isNotEmpty)
                                    '⚠ ${_petContext!.allergies.join(', ')}',
                                ].join(' · '))
                              : Text(_selectedPet!.displayLabel),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _selectedPet = null;
                              _petContext = null;
                            }),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_doctors.isNotEmpty)
                      DropdownButtonFormField<int>(
                        value: _selectedDoctor?.id,
                        decoration: const InputDecoration(labelText: 'Doctor'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— None —')),
                          ..._doctors.map(
                            (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                          ),
                        ],
                        onChanged: (id) => setState(() {
                          _selectedDoctor =
                              id == null ? null : _doctors.firstWhere((d) => d.id == id);
                        }),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _visitType,
                            decoration: const InputDecoration(labelText: 'Visit type'),
                            items: _visitTypes
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _visitType = v ?? 'consultation'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _visitDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setState(() => _visitDate = d);
                            },
                            child: Text(_visitDate.toIso8601String().substring(0, 10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _complaint,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Chief complaint'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Diagnoses (optional)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _diagnosisTemplates.map((name) {
                        return ActionChip(
                          label: Text(name, style: const TextStyle(fontSize: 11)),
                          onPressed: () => _addDiagnosis(name),
                        );
                      }).toList(),
                    ),
                    if (_diagnoses.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
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
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Quick notes'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'After saving, open the visit to add treatments, medicines, and vitals.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _saveAndOpen,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save & Open'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _saving ? null : _saveAnother,
                      child: const Text('Save Another'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
