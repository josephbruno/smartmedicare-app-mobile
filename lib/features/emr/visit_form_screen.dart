import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/emr.dart';
import '../../data/models/product.dart';
import '../../data/services/emr_master_data_service.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_form_dialog.dart';
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
  List<TreatmentSuggestion> _treatmentSuggestions = [];
  List<MedicineSuggestion> _medicineSuggestions = [];
  List<String> _dosageSuggestions = [];
  List<String> _frequencySuggestions = [];
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
      _treatmentSuggestions = await emr.getTreatmentSuggestions();
      _medicineSuggestions = await emr.getMedicineSuggestions();
      _dosageSuggestions = await emr.getDosageSuggestions();
      _frequencySuggestions = await emr.getFrequencySuggestions();

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
      _ensureServiceChargeProductLinked();
    }
  }

  /// Prefer a consultation-like service product; otherwise any active service.
  Future<void> _ensureServiceChargeProductLinked() async {
    if (_serviceChargeProductId != null) return;
    final charge = double.tryParse(_serviceCharge.text.trim()) ?? 0;
    if (charge <= 0) return;

    try {
      final products = await context.read<AppServices>().products.list(
        query: {'type': 'service', 'per_page': 20, 'is_active': true},
      );
      if (products.isEmpty || !mounted) return;

      Product pick = products.first;
      for (final p in products) {
        final name = p.name.toLowerCase();
        if (name.contains('consult') || name.contains('service charge')) {
          pick = p;
          break;
        }
      }

      setState(() {
        _serviceChargeProductId = pick.id;
        _serviceChargeProductName = pick.name;
      });
    } catch (_) {}
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

  Future<void> _searchTreatments(String q) async {
    if (q.length < 2) {
      setState(() => _treatmentSuggestions = []);
      return;
    }
    try {
      final results = await context.read<AppServices>().emr.getTreatmentSuggestions(q: q);
      if (mounted) setState(() => _treatmentSuggestions = results);
    } catch (_) {}
  }

  Future<void> _searchMedicines(String q) async {
    if (q.length < 2) {
      setState(() => _medicineSuggestions = []);
      return;
    }
    try {
      final results = await context.read<AppServices>().emr.getMedicineSuggestions(q: q);
      if (mounted) setState(() => _medicineSuggestions = results);
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

  /// Search uses the last comma-separated segment so multi-select typing works.
  String _complaintSearchTerm(String text) {
    final parts = text.split(',');
    return parts.isEmpty ? '' : parts.last.trim();
  }

  void _setComplaintText(String value) {
    _complaint.text = value;
    _complaint.selection =
        TextSelection.collapsed(offset: _complaint.text.length);
  }

  /// Comma-separated complaints ready for the API (no trailing empty segment).
  String get _complaintForApi => _complaint.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .join(', ');

  /// Finalize current term and append `, ` so the next complaint can be typed.
  void _commitComplaintTerm([String? _]) {
    final text = _complaint.text.trimRight();
    if (text.isEmpty) return;

    final q = _complaintSearchTerm(text);
    if (q.isEmpty) {
      // Already ends with a comma — keep a trailing space for the next term.
      _setComplaintText(text.endsWith(',') ? '$text ' : '$text, ');
    } else {
      final lastComma = text.lastIndexOf(',');
      final committed = lastComma < 0
          ? q
          : '${text.substring(0, lastComma + 1).trimRight()} $q';
      _setComplaintText('$committed, ');
    }
    setState(() {});
    _searchComplaints('');
  }

  Future<void> _searchComplaints(String text) async {
    final q = _complaintSearchTerm(text);
    try {
      final results =
          await context.read<AppServices>().emr.getComplaints(q: q.isEmpty ? null : q);
      if (mounted) setState(() => _complaintSuggestions = results);
    } catch (_) {}
  }

  void _applyComplaintSuggestion(String complaint) {
    final text = _complaint.text;
    final q = _complaintSearchTerm(text);
    String next;
    if (text.trim().isEmpty) {
      next = complaint;
    } else if (q.isNotEmpty &&
        complaint.toLowerCase().startsWith(q.toLowerCase())) {
      // Replace the in-progress typed segment with the selected template.
      final lastComma = text.lastIndexOf(',');
      if (lastComma < 0) {
        next = complaint;
      } else {
        next = '${text.substring(0, lastComma + 1).trimRight()} $complaint';
      }
    } else if (q.isEmpty) {
      next = '${text.trimRight()} $complaint';
    } else {
      next = '${text.trimRight()}, $complaint';
    }
    _setComplaintText('${next.trimRight()}, ');
    setState(() {});
    _searchComplaints('');
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

  Future<Product?> _pickProduct({
    String? initial,
    String type = 'product', // product | service | medicine
    bool allowCreateService = false,
    double? requiredQty,
  }) async {
    final search = TextEditingController(text: initial ?? '');
    List<Product> results = [];
    var searching = false;

    Future<List<Product>> fetch(String q) async {
      if (q.trim().length < 2) return [];
      return context.read<AppServices>().products.list(
            query: {
              'search': q.trim(),
              'per_page': 20,
              'is_active': 1,
              'type': type,
            },
          );
    }

    if ((initial ?? '').length >= 2) {
      try {
        results = await fetch(initial!);
      } catch (_) {}
    }

    if (!mounted) {
      search.dispose();
      return null;
    }

    final title = switch (type) {
      'service' => 'Select service product',
      'medicine' => 'Select medicine product',
      _ => 'Select product',
    };
    final subtitle = switch (type) {
      'service' => 'Link a billable service for GST and invoicing',
      'medicine' => 'Link inventory so stock and billing stay in sync',
      _ => 'Search the catalog and pick an item',
    };
    final icon = switch (type) {
      'service' => Icons.medical_services_outlined,
      'medicine' => Icons.medication_outlined,
      _ => Icons.inventory_2_outlined,
    };
    final searchHint = switch (type) {
      'medicine' => 'Search medicines...',
      'service' => 'Search services...',
      _ => 'Search products...',
    };

    try {
      return await showAppDialog<Product>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) {
            Future<void> runSearch(String q) async {
              if (q.length < 2) {
                setDialog(() {
                  results = [];
                  searching = false;
                });
                return;
              }
              setDialog(() => searching = true);
              try {
                final list = await fetch(q);
                setDialog(() {
                  results = list;
                  searching = false;
                });
              } catch (_) {
                setDialog(() => searching = false);
              }
            }

            Future<void> createService() async {
              final nameCtrl = TextEditingController(text: search.text.trim());
              final priceCtrl = TextEditingController(text: '0');
              final creating = ValueNotifier<bool>(false);

              try {
                final created = await showAppAlertForm<Product>(
                  context: ctx,
                  title: 'Add service product',
                  subtitle: 'Creates a catalog service for billing',
                  icon: Icons.add_business_outlined,
                  maxWidth: 440,
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: appFormFieldDecoration(
                          'Service name *',
                          hint: 'e.g. Consultation',
                        ),
                        textCapitalization: TextCapitalization.words,
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: priceCtrl,
                        decoration: appFormFieldDecoration(
                          'Price (₹)',
                          hint: '0.00',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    ValueListenableBuilder<bool>(
                      valueListenable: creating,
                      builder: (_, busy, __) => OutlinedButton(
                        onPressed: busy
                            ? null
                            : () =>
                                Navigator.of(ctx, rootNavigator: true).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: creating,
                      builder: (_, busy, __) => FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final price =
                                    double.tryParse(priceCtrl.text.trim()) ?? 0;
                                if (name.isEmpty) {
                                  AppMessenger.show(
                                    ctx,
                                    const SnackBar(
                                      content: Text('Enter a service name'),
                                    ),
                                  );
                                  return;
                                }
                                creating.value = true;
                                try {
                                  final p = await context
                                      .read<AppServices>()
                                      .products
                                      .create({
                                    'name': name,
                                    'purchase_price': 0,
                                    'selling_price': price,
                                    'mrp': price,
                                    'gst_rate': 0,
                                    'gst_type': 'exclusive',
                                    'is_service': true,
                                    'is_medicine': false,
                                    'product_type': 'service',
                                    'track_inventory': false,
                                    'is_active': true,
                                  });
                                  if (ctx.mounted) {
                                    Navigator.of(ctx, rootNavigator: true)
                                        .pop(p);
                                  }
                                } catch (e) {
                                  creating.value = false;
                                  if (ctx.mounted) {
                                    AppMessenger.show(
                                      ctx,
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                }
                              },
                        child: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create'),
                      ),
                    ),
                  ],
                );
                if (created != null && ctx.mounted) {
                  Navigator.pop(ctx, created);
                }
              } finally {
                creating.dispose();
                nameCtrl.dispose();
                priceCtrl.dispose();
              }
            }

            return AppFormDialogShell(
              title: title,
              subtitle: subtitle,
              icon: icon,
              maxWidth: 520,
              onClose: () => Navigator.pop(ctx),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: search,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: searchHint,
                      prefixIcon: const Icon(Icons.search, size: 22),
                      suffixIcon: searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (search.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear',
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    search.clear();
                                    setDialog(() {
                                      results = [];
                                      searching = false;
                                    });
                                  },
                                )
                              : null),
                    ),
                    onChanged: runSearch,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 320,
                    child: searching && results.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : results.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    search.text.trim().length < 2
                                        ? 'Type at least 2 characters to search'
                                        : 'No matching products found',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: results.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: Color(0xFFE2E8F0),
                                ),
                                itemBuilder: (_, i) {
                                  final p = results[i];
                                  final stock = p.currentStock;
                                  final qtyNeeded = requiredQty ?? 1;
                                  final out = type == 'medicine' &&
                                      p.trackInventory &&
                                      (stock == null || stock < qtyNeeded);
                                  final subtitleText = type == 'medicine'
                                      ? '₹${p.sellingPrice.toStringAsFixed(2)}'
                                          '${p.trackInventory ? ' · Stock: ${stock?.toStringAsFixed(0) ?? '0'}' : ''}'
                                          '${out ? ' · Out of stock' : ''}'
                                      : '₹${p.sellingPrice.toStringAsFixed(2)}'
                                          '${p.isService ? ' · Service' : ''}';
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    enabled: !out,
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: (out
                                              ? AppTheme.danger
                                              : AppTheme.primary)
                                          .withValues(alpha: 0.12),
                                      child: Icon(
                                        out
                                            ? Icons.block
                                            : (type == 'medicine'
                                                ? Icons.medication_outlined
                                                : Icons.inventory_2_outlined),
                                        size: 18,
                                        color: out
                                            ? AppTheme.danger
                                            : AppTheme.primary,
                                      ),
                                    ),
                                    title: Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: out
                                            ? AppTheme.textSecondary
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      subtitleText,
                                      style: TextStyle(
                                        color: out
                                            ? AppTheme.danger
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                    onTap: out
                                        ? null
                                        : () => Navigator.pop(ctx, p),
                                  );
                                },
                              ),
                  ),
                ],
              ),
              footer: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    if (allowCreateService && type == 'service') ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: createService,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add service'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      search.dispose();
    }
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

  Future<Map<String, dynamic>?> _buildVisitBody() async {
    if (_selectedPet == null) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Please select a patient (pet)')),
      );
      return null;
    }

    for (final t in _treatments) {
      if (t.nameCtrl.text.trim().isEmpty) continue;
      if (t.productId == null) {
        AppMessenger.show(
          context,
          SnackBar(
            content: Text(
              'Link a service product for treatment "${t.nameCtrl.text.trim()}" (use the inventory icon or Add service).',
            ),
          ),
        );
        return null;
      }
    }

    for (final m in _medicines) {
      if (m.nameCtrl.text.trim().isEmpty) continue;
      if (m.productId == null) {
        AppMessenger.show(
          context,
          SnackBar(
            content: Text(
              'Link a medicine product for "${m.nameCtrl.text.trim()}" so it can be billed and stock-checked.',
            ),
          ),
        );
        return null;
      }
    }

    final timeStr =
        '${_visitTime.hour.toString().padLeft(2, '0')}:${_visitTime.minute.toString().padLeft(2, '0')}';

    final serviceCharge = double.tryParse(_serviceCharge.text.trim()) ?? 0;

    if (serviceCharge > 0 && _serviceChargeProductId == null) {
      await _ensureServiceChargeProductLinked();
    }

    return <String, dynamic>{
      'pet_id': _selectedPet!.id,
      if (_selectedDoctor != null) 'doctor_id': _selectedDoctor!.id,
      'visit_type': _visitType,
      'visit_date': _visitDate.toIso8601String().substring(0, 10),
      'visit_time': timeStr,
      'service_charge': serviceCharge,
      if (serviceCharge > 0 && _serviceChargeProductId != null)
        'service_charge_product_id': _serviceChargeProductId,
      if (_complaintForApi.isNotEmpty) 'chief_complaint': _complaintForApi,
      if (_clinicalNotes.text.trim().isNotEmpty)
        'clinical_notes': _clinicalNotes.text.trim(),
      if (_followUpNotes.text.trim().isNotEmpty)
        'follow_up_notes': _followUpNotes.text.trim(),
      if (_temp.text.isNotEmpty) 'temperature': double.tryParse(_temp.text),
      if (_weight.text.isNotEmpty) 'weight': double.tryParse(_weight.text),
      if (_heartRate.text.isNotEmpty) 'heart_rate': int.tryParse(_heartRate.text),
      if (_respiratoryRate.text.isNotEmpty)
        'respiratory_rate': int.tryParse(_respiratoryRate.text),
      if (_followUpDate != null)
        'follow_up_date': _followUpDate!.toIso8601String().substring(0, 10),
      if (_diagnoses.isNotEmpty)
        'diagnoses': _diagnoses.map((d) => d.toJson()).toList(),
      if (_treatments.isNotEmpty)
        'treatments': _treatments.map((t) => t.toJson()).toList(),
      if (_medicines.isNotEmpty)
        'medicines': _medicines.map((m) => m.toJson()).toList(),
    };
  }

  Future<PetVisit?> _persistVisit(Map<String, dynamic> body) async {
    final emr = context.read<AppServices>().emr;
    if (_isEdit) {
      return emr.updateVisit(widget.visitId!, body);
    }
    final visit = await emr.createVisit(body);
    if (_sourceAppointmentId != null) {
      try {
        await emr.updateAppointment(_sourceAppointmentId!, {
          'status': 'in_progress',
          'visit_id': visit.id,
        });
      } catch (_) {}
    }
    return visit;
  }

  /// Saves progress as an open visit so the doctor can leave and resume later.
  Future<void> _hold() async {
    final body = await _buildVisitBody();
    if (body == null) return;

    setState(() => _saving = true);
    try {
      final visit = await _persistVisit(body);
      if (!mounted || visit == null) return;
      AppMessenger.show(
        context,
        const SnackBar(
          content: Text('Visit held — resume anytime from Visit Records (open).'),
        ),
      );
      context.go('/emr/visits/${visit.id}');
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final body = await _buildVisitBody();
    if (body == null) return;

    setState(() => _saving = true);
    try {
      final visit = await _persistVisit(body);
      if (mounted && visit != null) {
        context.go('/emr/visits/${visit.id}');
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context, SnackBar(content: Text('$e')));
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
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 640;
              final patientField = _selectedPet == null
                  ? TextField(
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
                    )
                  : InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Patient',
                        suffixIcon: _isEdit
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                tooltip: 'Clear patient',
                                onPressed: () => setState(() {
                                  _selectedPet = null;
                                  _petSummary = null;
                                }),
                              ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pets, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedPet!.displayLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );

              final visitTypeField = AppDropdownButtonFormField<String>(
                value: _visitType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Visit type'),
                selectedItemBuilder: (context) => _visitTypes
                    .map(
                      (t) => Text(
                        t,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                    .toList(),
                items: _visitTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, overflow: TextOverflow.ellipsis, maxLines: 1),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _visitType = v ?? 'consultation'),
              );

              final serviceChargeField = TextField(
                controller: _serviceCharge,
                decoration: InputDecoration(
                  labelText: 'Service charge (₹)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.inventory_2_outlined, size: 22),
                    tooltip: 'Link service product (for GST)',
                    onPressed: () async {
                      final p = await _pickProduct(
                        type: 'service',
                        allowCreateService: true,
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
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    patientField,
                    const SizedBox(height: 12),
                    visitTypeField,
                    const SizedBox(height: 12),
                    serviceChargeField,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: patientField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: visitTypeField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: serviceChargeField),
                ],
              );
            },
          ),
          if (_selectedPet == null)
            ..._petResults.map(
              (p) => ListTile(
                dense: true,
                title: Text(p.displayLabel),
                onTap: () => _selectPet(p),
              ),
            ),
          if (_serviceChargeProductName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Service product: $_serviceChargeProductName',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
          if (_doctors.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppDropdownButtonFormField<int>(
              value: _selectedDoctor?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Doctor'),
              selectedItemBuilder: (context) => [
                const Text('— None —', overflow: TextOverflow.ellipsis, maxLines: 1),
                ..._doctors.map(
                  (d) => Text(
                    d.displayLabel,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
              items: [
                const DropdownMenuItem(value: null, child: Text('— None —')),
                ..._doctors.map(
                  (d) => DropdownMenuItem(
                    value: d.id,
                    child: Text(
                      d.displayLabel,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
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
          ],
          const SizedBox(height: 16),
          Text('Chief complaint',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey != LogicalKeyboardKey.enter &&
                  event.logicalKey != LogicalKeyboardKey.numpadEnter) {
                return KeyEventResult.ignored;
              }
              _commitComplaintTerm();
              return KeyEventResult.handled;
            },
            child: TextField(
              controller: _complaint,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Type to search or add complaints...',
              ),
              onChanged: _searchComplaints,
              onSubmitted: _commitComplaintTerm,
            ),
          ),
          if (_complaintSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _complaintSuggestions.take(12).map((c) {
                return ActionChip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  onPressed: () => _applyComplaintSuggestion(c),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          Text('Vitals', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 520;
              final fields = [
                TextField(
                  controller: _temp,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Temp °F',
                    isDense: true,
                  ),
                ),
                TextField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Weight kg',
                    isDense: true,
                  ),
                ),
                TextField(
                  controller: _heartRate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Heart rate',
                    isDense: true,
                  ),
                ),
                TextField(
                  controller: _respiratoryRate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Resp. rate',
                    isDense: true,
                  ),
                ),
              ];
              if (narrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 8),
                        Expanded(child: fields[1]),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: fields[2]),
                        const SizedBox(width: 8),
                        Expanded(child: fields[3]),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: fields[i]),
                  ],
                ],
              );
            },
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
                onPressed: () async {
                  final p = await _pickProduct(
                    type: 'service',
                    allowCreateService: true,
                  );
                  if (p == null) return;
                  setState(() {
                    _treatments.add(_TreatmentRow(
                      productId: p.id,
                      name: p.name,
                      unitPrice: p.sellingPrice,
                    ));
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_treatments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No treatments — add a service product to bill',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            onChanged: _searchTreatments,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            controller: t.priceCtrl,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.inventory_2_outlined,
                            size: 20,
                            color: t.productId != null ? AppTheme.accent : AppTheme.primary,
                          ),
                          tooltip: t.productId != null
                              ? 'Service product linked'
                              : 'Link / add service product',
                          onPressed: () async {
                            final p = await _pickProduct(
                              initial: t.nameCtrl.text,
                              type: 'service',
                              allowCreateService: true,
                            );
                            if (p != null) {
                              setState(() {
                                t.productId = p.id;
                                t.nameCtrl.text = p.name;
                                t.priceCtrl.text = _formatAmount(p.sellingPrice);
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
                    if (_treatmentSuggestions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            alignment: WrapAlignment.start,
                            spacing: 6,
                            runSpacing: 6,
                            children: _treatmentSuggestions.take(6).map((s) {
                              return ActionChip(
                                label: Text(s.name, style: const TextStyle(fontSize: 12)),
                                onPressed: () {
                                  setState(() {
                                    t.nameCtrl.text = s.name;
                                    // Always apply template price on pick. New rows
                                    // start as "0.0", which the old empty/'0' check missed.
                                    if (s.defaultPrice != null) {
                                      t.priceCtrl.text =
                                          _formatAmount(s.defaultPrice!);
                                    }
                                    _treatmentSuggestions = [];
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Medicine product + stock', style: TextStyle(fontSize: 11)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final p = await _pickProduct(type: 'medicine', requiredQty: 1);
                  if (p == null) return;
                  setState(() {
                    final row = _MedicineRow(
                      productId: p.id,
                      name: p.name,
                      unitPrice: p.sellingPrice,
                    );
                    _medicines.add(row);
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_medicines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No medicines added — pick medicine products with stock',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Medicine name',
                              isDense: true,
                            ),
                            controller: m.nameCtrl,
                            onChanged: _searchMedicines,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            controller: m.priceCtrl,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.medication_outlined,
                            size: 20,
                            color: m.productId != null ? AppTheme.accent : AppTheme.primary,
                          ),
                          tooltip: m.productId != null
                              ? 'Medicine product linked'
                              : 'Link medicine product (stock checked)',
                          onPressed: () async {
                            final qty = double.tryParse(m.qtyCtrl.text) ?? 1;
                            final p = await _pickProduct(
                              initial: m.nameCtrl.text,
                              type: 'medicine',
                              requiredQty: qty,
                            );
                            if (p != null) {
                              setState(() {
                                m.productId = p.id;
                                m.nameCtrl.text = p.name;
                                m.priceCtrl.text = _formatAmount(p.sellingPrice);
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
                    if (_medicineSuggestions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _medicineSuggestions.take(6).map((s) {
                            return ActionChip(
                              label: Text(s.name, style: const TextStyle(fontSize: 12)),
                              onPressed: () {
                                setState(() {
                                  m.nameCtrl.text = s.name;
                                  if (s.defaultDosage != null && m.dosageCtrl.text.isEmpty) {
                                    m.dosageCtrl.text = s.defaultDosage!;
                                  }
                                  if (s.defaultFrequency != null && m.freqCtrl.text.isEmpty) {
                                    m.freqCtrl.text = s.defaultFrequency!;
                                  }
                                  if (s.defaultDurationDays != null && m.daysCtrl.text.isEmpty) {
                                    m.daysCtrl.text = s.defaultDurationDays.toString();
                                  }
                                  _medicineSuggestions = [];
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 8),
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
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 88,
                          child: TextField(
                            decoration: const InputDecoration(labelText: 'Days', isDense: true),
                            keyboardType: TextInputType.number,
                            controller: m.daysCtrl,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 88,
                          child: TextField(
                            decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            controller: m.qtyCtrl,
                          ),
                        ),
                      ],
                    ),
                    if (_dosageSuggestions.isNotEmpty || _frequencySuggestions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ..._dosageSuggestions.take(4).map(
                                  (d) => ActionChip(
                                    label: Text(d, style: const TextStyle(fontSize: 11)),
                                    onPressed: () => setState(() => m.dosageCtrl.text = d),
                                  ),
                                ),
                            ..._frequencySuggestions.take(4).map(
                                  (f) => ActionChip(
                                    label: Text(f, style: const TextStyle(fontSize: 11)),
                                    onPressed: () => setState(() => m.freqCtrl.text = f),
                                  ),
                                ),
                          ],
                        ),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _hold,
                  icon: const Icon(Icons.pause_circle_outline, size: 20),
                  label: const Text('Hold'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Update visit' : 'Create visit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hold saves your progress as an open visit so you can leave and resume later.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

class _TreatmentRow {
  _TreatmentRow({
    this.productId,
    String name = '',
    double quantity = 1,
    double unitPrice = 0,
  })  : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: quantity.toString()),
        priceCtrl = TextEditingController(
          text: unitPrice == 0 ? '' : _formatAmount(unitPrice),
        );

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
