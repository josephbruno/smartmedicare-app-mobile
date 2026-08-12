import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
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
  final _observationInput = TextEditingController();
  final _investigationInput = TextEditingController();
  final _followUpNotes = TextEditingController();
  final _diagnosisInput = TextEditingController();
  final _observationFocus = FocusNode();
  final _investigationFocus = FocusNode();
  final _diagnosisFocus = FocusNode();
  final _serviceCharge = TextEditingController();

  /// Selected vitals (dropdown values; null = not set).
  double? _temperatureF;
  double? _weightKg;
  int? _heartRateBpm;
  int? _respiratoryRatePerMin;

  PetSearchResult? _selectedPet;
  DoctorLite? _selectedDoctor;
  List<DoctorLite> _doctors = [];
  List<PetSearchResult> _petResults = [];
  List<VisitDiagnosis> _diagnoses = [];
  List<String> _observations = [];
  List<String> _investigations = [];
  final List<_TreatmentRow> _treatments = [];
  final List<_MedicineRow> _medicines = [];
  final List<_VaccinationRow> _vaccinations = [];
  final List<_DewormingRow> _dewormings = [];
  final List<_SurgeryRow> _surgeries = [];
  List<String> _complaintSuggestions = [];
  List<String> _observationSuggestions = [];
  List<String> _investigationSuggestions = [];
  List<VisitDiagnosis> _diagnosisSuggestions = [];
  List<String> _defaultObservationSuggestions = [];
  List<String> _defaultInvestigationSuggestions = [];
  List<VisitDiagnosis> _defaultDiagnosisSuggestions = [];
  /// Which chip-field suggestion panel is open (`observation` / `investigation` / `diagnosis`).
  String? _openSuggestField;
  List<TreatmentSuggestion> _defaultTreatmentSuggestions = [];
  List<TreatmentSuggestion> _treatmentSuggestions = [];
  int? _treatmentSuggestForIndex;
  List<MedicineSuggestion> _defaultMedicineSuggestions = [];
  List<MedicineSuggestion> _medicineSuggestions = [];
  int? _medicineSuggestForIndex;
  int? _medicineFrequencySuggestForIndex;
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

  // UI uses °F; API stores °C (30–45). Convert on load/save.
  static final List<double> _temperatureOptions = [
    for (var t = 990; t <= 1060; t += 5) t / 10.0, // 99.0–106.0 °F by 0.5
  ];

  static double _fahrenheitToCelsius(double f) =>
      double.parse(((f - 32) * 5 / 9).toStringAsFixed(1));

  static double _celsiusToFahrenheit(double c) =>
      double.parse((c * 9 / 5 + 32).toStringAsFixed(1));

  static final List<double> _weightOptions = [
    for (var w = 5; w <= 800; w++) w / 10.0, // 0.5–80.0 kg
  ];

  static final List<int> _heartRateOptions = [
    for (var h = 40; h <= 240; h += 5) h,
  ];

  static final List<int> _respiratoryRateOptions = [
    for (var r = 20; r <= 80; r++) r,
  ];

  double _nearestDouble(double value, List<double> options) {
    var best = options.first;
    var bestDiff = (best - value).abs();
    for (final o in options) {
      final d = (o - value).abs();
      if (d < bestDiff) {
        best = o;
        bestDiff = d;
      }
    }
    return best;
  }

  int _nearestInt(int value, List<int> options) {
    var best = options.first;
    var bestDiff = (best - value).abs();
    for (final o in options) {
      final d = (o - value).abs();
      if (d < bestDiff) {
        best = o;
        bestDiff = d;
      }
    }
    return best;
  }

  List<double> _doubleOptionsWith(double? current, List<double> base) {
    if (current == null) return base;
    if (base.contains(current)) return base;
    return [...base, current]..sort();
  }

  List<int> _intOptionsWith(int? current, List<int> base) {
    if (current == null) return base;
    if (base.contains(current)) return base;
    return [...base, current]..sort();
  }

  @override
  void initState() {
    super.initState();
    _sourceAppointmentId = widget.appointmentId;
    _diagnosisFocus.addListener(() => _onChipFieldFocus(
          field: 'diagnosis',
          focus: _diagnosisFocus,
          loadSuggestions: () => _searchDiagnoses(_diagnosisInput.text),
        ));
    _observationFocus.addListener(() => _onChipFieldFocus(
          field: 'observation',
          focus: _observationFocus,
          loadSuggestions: () => _searchObservations(_observationInput.text),
        ));
    _investigationFocus.addListener(() => _onChipFieldFocus(
          field: 'investigation',
          focus: _investigationFocus,
          loadSuggestions: () => _searchInvestigations(_investigationInput.text),
        ));
    _bootstrap();
  }

  void _onChipFieldFocus({
    required String field,
    required FocusNode focus,
    required VoidCallback loadSuggestions,
  }) {
    if (!mounted) return;
    if (focus.hasFocus) {
      setState(() => _openSuggestField = field);
      loadSuggestions();
      return;
    }
    // Delay so suggestion taps can clear/add first; then commit any leftover free text.
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || focus.hasFocus) return;
      _commitPendingChipInput(field);
      if (_openSuggestField == field) {
        setState(() => _openSuggestField = null);
      }
    });
  }

  void _commitPendingChipInput(String field) {
    switch (field) {
      case 'observation':
        final t = _observationInput.text.trim();
        if (t.isNotEmpty) _addObservation(t, keepFocus: false);
      case 'investigation':
        final t = _investigationInput.text.trim();
        if (t.isNotEmpty) _addInvestigation(t, keepFocus: false);
      case 'diagnosis':
        final t = _diagnosisInput.text.trim();
        if (t.isNotEmpty) _addDiagnosis(t, keepFocus: false);
    }
  }

  void _selectObservationSuggestion(String phrase) {
    _openSuggestField = 'observation';
    _addObservation(phrase);
  }

  void _selectInvestigationSuggestion(String phrase) {
    _openSuggestField = 'investigation';
    _addInvestigation(phrase);
  }

  void _selectDiagnosisSuggestion(VisitDiagnosis d) {
    _openSuggestField = 'diagnosis';
    _addDiagnosisFromSuggestion(d);
  }

  bool _isKnownObservation(String value) {
    final key = value.toLowerCase();
    return _defaultObservationSuggestions.any((s) => s.toLowerCase() == key) ||
        _observationSuggestions.any((s) => s.toLowerCase() == key);
  }

  bool _isKnownInvestigation(String value) {
    final key = value.toLowerCase();
    return _defaultInvestigationSuggestions.any((s) => s.toLowerCase() == key) ||
        _investigationSuggestions.any((s) => s.toLowerCase() == key);
  }

  bool _isKnownDiagnosis(String value) {
    final key = value.toLowerCase();
    return _defaultDiagnosisSuggestions
            .any((s) => s.diagnosisName.toLowerCase() == key) ||
        _diagnosisSuggestions.any((s) => s.diagnosisName.toLowerCase() == key);
  }

  void _rememberObservation(String value) {
    if (_isKnownObservation(value)) return;
    _defaultObservationSuggestions = [value, ..._defaultObservationSuggestions];
    _observationSuggestions = List.of(_defaultObservationSuggestions);
  }

  void _rememberInvestigation(String value) {
    if (_isKnownInvestigation(value)) return;
    _defaultInvestigationSuggestions = [
      value,
      ..._defaultInvestigationSuggestions,
    ];
    _investigationSuggestions = List.of(_defaultInvestigationSuggestions);
  }

  void _rememberDiagnosis(String value) {
    if (_isKnownDiagnosis(value)) return;
    final item = VisitDiagnosis(
      diagnosisName: value,
      severity: 'mild',
      isPrimary: false,
    );
    _defaultDiagnosisSuggestions = [item, ..._defaultDiagnosisSuggestions];
    _diagnosisSuggestions = List.of(_defaultDiagnosisSuggestions);
  }

  Future<void> _persistNewObservation(String name) async {
    if (!mounted) return;
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission(AppPermissions.emrMasterDataManage)) return;
    try {
      await context
          .read<AppServices>()
          .emrMasterData
          .createObservation({'name': name, 'is_active': true});
    } catch (_) {
      // Duplicate / permission — local chip + visit save still keep the value.
    }
  }

  Future<void> _persistNewInvestigation(String name) async {
    if (!mounted) return;
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission(AppPermissions.emrMasterDataManage)) return;
    try {
      await context
          .read<AppServices>()
          .emrMasterData
          .createInvestigation({'name': name, 'is_active': true});
    } catch (_) {}
  }

  Future<void> _persistNewDiagnosis(String name) async {
    if (!mounted) return;
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission(AppPermissions.emrMasterDataManage)) return;
    try {
      await context
          .read<AppServices>()
          .emrMasterData
          .createDiagnosis({'name': name, 'is_active': true});
    } catch (_) {}
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final emr = context.read<AppServices>().emr;
    final auth = context.read<AuthSession>();

    try {
      // Include unavailable doctors so the logged-in doctor still appears.
      _doctors = _uniqueDoctors(await emr.listDoctors());
      _complaintSuggestions = await emr.getComplaints();
      _defaultObservationSuggestions = await emr.getObservations();
      _defaultInvestigationSuggestions = await emr.getInvestigations();
      _defaultDiagnosisSuggestions = await emr.getDiagnosisSuggestions();
      _observationSuggestions = List.of(_defaultObservationSuggestions);
      _investigationSuggestions = List.of(_defaultInvestigationSuggestions);
      _diagnosisSuggestions = List.of(_defaultDiagnosisSuggestions);
      _defaultTreatmentSuggestions = await emr.getTreatmentSuggestions();
      _defaultMedicineSuggestions = await emr.getMedicineSuggestions();
      _frequencySuggestions = await emr.getFrequencySuggestions();

      if (_isEdit) {
        final visit = await emr.getVisit(widget.visitId!);
        _applyVisit(visit);
      } else if (_sourceAppointmentId != null) {
        final appt = await emr.getAppointment(_sourceAppointmentId!);
        await _prefillFromAppointment(appt);
      } else if (widget.petId != null) {
        await _prefillFromPetId(widget.petId!);
      }

      // Doctor account: always use that login's name (not other doctors).
      // Admin / branch manager: hide Doctor field entirely.
      if (_isAdminSession(auth)) {
        _doctors = [];
        _selectedDoctor = null;
      } else {
        _lockDoctorToLoggedInUser(auth);
        if (!_isEdit) {
          _applyDoctorServiceChargeDefaults();
        }
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
    if (visit.doctor != null) _setSelectedDoctor(visit.doctor);
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
    _observations = _splitPhrases(visit.observation);
    _investigations = _splitPhrases(visit.investigation);
    _followUpNotes.text = visit.followUpNotes ?? '';
    if (visit.temperature != null) {
      // API stores °C; dropdown is °F.
      _temperatureF = _nearestDouble(
        _celsiusToFahrenheit(visit.temperature!),
        _temperatureOptions,
      );
    }
    if (visit.weight != null) {
      _weightKg = _nearestDouble(visit.weight!, _weightOptions);
    }
    if (visit.heartRate != null) {
      _heartRateBpm = _nearestInt(visit.heartRate!, _heartRateOptions);
    }
    if (visit.respiratoryRate != null) {
      _respiratoryRatePerMin =
          _nearestInt(visit.respiratoryRate!, _respiratoryRateOptions);
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
    for (final r in _vaccinations) {
      r.dispose();
    }
    _vaccinations
      ..clear()
      ..addAll((visit.vaccinations ?? []).map(_VaccinationRow.fromModel));
    for (final r in _dewormings) {
      r.dispose();
    }
    _dewormings
      ..clear()
      ..addAll((visit.dewormings ?? []).map(_DewormingRow.fromModel));
    for (final r in _surgeries) {
      r.dispose();
    }
    _surgeries
      ..clear()
      ..addAll((visit.surgeries ?? []).map(_SurgeryRow.fromModel));
    if (visit.serviceCharge > 0) {
      _serviceCharge.text = visit.serviceCharge.toString();
    } else {
      _serviceCharge.clear();
    }
    _serviceChargeProductId = visit.serviceChargeProductId;
    _serviceChargeProductName = visit.serviceChargeProduct?.name;
  }

  List<DoctorLite> _uniqueDoctors(List<DoctorLite> doctors) {
    final seen = <int>{};
    return [
      for (final d in doctors)
        if (d.id != 0 && seen.add(d.id)) d,
    ];
  }

  void _ensureDoctorInList(DoctorLite doctor) {
    if (doctor.id == 0) return;
    if (_doctors.any((d) => d.id == doctor.id)) return;
    _doctors = [..._doctors, doctor];
  }

  void _setSelectedDoctor(DoctorLite? doctor) {
    _selectedDoctor = doctor;
    if (doctor != null) _ensureDoctorInList(doctor);
  }

  /// Doctor logins: Doctor field is that user only (not the full doctor list).
  void _lockDoctorToLoggedInUser(AuthSession auth) {
    final user = auth.user;
    if (user == null || !auth.hasRole(AppRoles.doctor)) return;
    if (_isAdminSession(auth)) return;

    final fromList = _doctors.where((d) => d.id == user.id).firstOrNull;
    final doctor = fromList ??
        DoctorLite(
          id: user.id,
          name: user.name.trim().isNotEmpty ? user.name : 'Doctor #${user.id}',
        );
    _doctors = [doctor];
    _selectedDoctor = doctor;
  }

  bool _isAdminSession(AuthSession auth) =>
      auth.hasRole(AppRoles.superAdmin) || auth.hasRole(AppRoles.branchManager);

  /// Hide Doctor for admin; doctor logins see only their own name; staff get the list.
  bool get _showDoctorField {
    final auth = context.read<AuthSession>();
    if (_isAdminSession(auth)) return false;
    return _doctors.isNotEmpty || _selectedDoctor != null;
  }

  bool get _doctorLockedToLogin {
    final auth = context.read<AuthSession>();
    final user = auth.user;
    if (_isAdminSession(auth)) return false;
    return auth.hasRole(AppRoles.doctor) &&
        user != null &&
        _selectedDoctor?.id == user.id &&
        _doctors.length == 1;
  }

  /// Dropdown requires exactly one matching item; fall back to null otherwise.
  int? get _doctorDropdownValue {
    final id = _selectedDoctor?.id;
    if (id == null) return null;
    final matches = _doctors.where((d) => d.id == id).length;
    return matches == 1 ? id : null;
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
      if (summary.weight != null && _weightKg == null) {
        _weightKg = _nearestDouble(summary.weight!, _weightOptions);
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
    if (appt.doctor != null) _setSelectedDoctor(appt.doctor);
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
        if (summary.weight != null && _weightKg == null) {
          _weightKg = _nearestDouble(summary.weight!, _weightOptions);
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
        if (summary.weight != null && _weightKg == null) {
          _weightKg = _nearestDouble(summary.weight!, _weightOptions);
        }
      }
    } catch (_) {}
  }

  void _showTreatmentSuggestionsFor(int index, {String? query}) {
    final q = query ?? _treatments[index].nameCtrl.text.trim();
    setState(() {
      _treatmentSuggestForIndex = index;
      if (q.length < 2) {
        _treatmentSuggestions = _defaultTreatmentSuggestions;
      }
    });
    if (q.length >= 2) {
      _searchTreatments(q, forIndex: index);
    }
  }

  Future<void> _searchTreatments(String q, {int? forIndex}) async {
    final index = forIndex ?? _treatmentSuggestForIndex;
    if (q.length < 2) {
      if (!mounted) return;
      setState(() {
        _treatmentSuggestions = _defaultTreatmentSuggestions;
        if (index != null) _treatmentSuggestForIndex = index;
      });
      return;
    }
    try {
      final results = await context.read<AppServices>().emr.getTreatmentSuggestions(q: q);
      if (!mounted) return;
      if (index != null && _treatmentSuggestForIndex != index) return;
      setState(() {
        _treatmentSuggestions = results;
        if (index != null) _treatmentSuggestForIndex = index;
      });
    } catch (_) {}
  }

  void _clearTreatmentSuggestions({int? onlyIfIndex}) {
    if (onlyIfIndex != null && _treatmentSuggestForIndex != onlyIfIndex) return;
    setState(() {
      _treatmentSuggestForIndex = null;
      _treatmentSuggestions = [];
    });
  }

  Future<void> _addProcedureKit() async {
    final kit = await showAppDialog<ProcedureKit>(
      context: context,
      builder: (ctx) => const _ProcedureKitPickerDialog(),
    );
    if (kit == null || !mounted) return;
    if (kit.items.isEmpty) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('This kit has no products configured')),
      );
      return;
    }
    setState(() {
      for (final item in kit.items) {
        if (item.productId <= 0) continue;
        _treatments.add(_TreatmentRow(
          productId: item.productId,
          name: item.treatmentName.isNotEmpty
              ? item.treatmentName
              : (item.productName ?? kit.name),
          quantity: item.quantity,
          unitPrice: item.unitPrice,
        ));
      }
    });
    if (!mounted) return;
    AppMessenger.show(
      context,
      SnackBar(
        content: Text(
          'Added ${kit.items.where((i) => i.productId > 0).length} lines from ${kit.name}',
        ),
      ),
    );
  }

  Future<void> _addProductsMulti() async {
    final products = await showModalBottomSheet<List<Product>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _MultiProductPickerSheet(
        type: 'product',
        title: 'Add products / services',
        allowAllTypes: true,
      ),
    );
    if (products == null || products.isEmpty || !mounted) return;
    setState(() {
      for (final p in products) {
        _treatments.add(_TreatmentRow(
          productId: p.id,
          name: p.name,
          unitPrice: p.sellingPrice,
        ));
      }
    });
    if (!mounted) return;
    AppMessenger.show(
      context,
      SnackBar(content: Text('Added ${products.length} line${products.length == 1 ? '' : 's'}')),
    );
  }

  void _showMedicineSuggestionsFor(int index, {String? query}) {
    final q = query ?? _medicines[index].nameCtrl.text.trim();
    setState(() {
      _medicineSuggestForIndex = index;
      if (q.length < 2) {
        _medicineSuggestions = _defaultMedicineSuggestions;
      }
    });
    if (q.length >= 2) {
      _searchMedicines(q, forIndex: index);
    }
  }

  Future<void> _searchMedicines(String q, {int? forIndex}) async {
    final index = forIndex ?? _medicineSuggestForIndex;
    if (q.length < 2) {
      if (!mounted) return;
      setState(() {
        _medicineSuggestions = _defaultMedicineSuggestions;
        if (index != null) _medicineSuggestForIndex = index;
      });
      return;
    }
    try {
      final results = await context.read<AppServices>().emr.getMedicineSuggestions(q: q);
      if (!mounted) return;
      if (index != null && _medicineSuggestForIndex != index) return;
      setState(() {
        _medicineSuggestions = results;
        if (index != null) _medicineSuggestForIndex = index;
      });
    } catch (_) {}
  }

  void _clearMedicineSuggestions({int? onlyIfIndex}) {
    if (onlyIfIndex != null && _medicineSuggestForIndex != onlyIfIndex) return;
    setState(() {
      _medicineSuggestForIndex = null;
      _medicineSuggestions = [];
    });
  }

  Future<void> _searchDiagnoses(String q) async {
    final query = q.trim();
    try {
      final results = await context.read<AppServices>().emr.getDiagnosisSuggestions(
            q: query.isEmpty ? null : query,
          );
      if (mounted) {
        setState(() {
          _diagnosisSuggestions = results;
          if (query.isEmpty) {
            _defaultDiagnosisSuggestions = List.of(results);
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (query.isEmpty && _defaultDiagnosisSuggestions.isNotEmpty) {
        setState(() => _diagnosisSuggestions = List.of(_defaultDiagnosisSuggestions));
      }
    }
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
    final String next;
    if (q.isEmpty) {
      // No in-progress term (empty or trailing comma) — append the selection.
      final trimmed = text.trimRight();
      next = trimmed.isEmpty
          ? complaint
          : trimmed.endsWith(',')
              ? '$trimmed $complaint'
              : '$trimmed, $complaint';
    } else {
      // Always replace the typed search segment with the selected complaint
      // (not only when the suggestion is a prefix of what was typed).
      final lastComma = text.lastIndexOf(',');
      next = lastComma < 0
          ? complaint
          : '${text.substring(0, lastComma + 1).trimRight()} $complaint';
    }
    _setComplaintText('${next.trimRight()}, ');
    setState(() {});
    _searchComplaints('');
  }

  List<String> _splitPhrases(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String? _joinPhrases(List<String> items) {
    final joined = items.map((e) => e.trim()).where((e) => e.isNotEmpty).join(', ');
    return joined.isEmpty ? null : joined;
  }

  Future<void> _searchObservations(String text) async {
    final q = text.trim();
    try {
      final results = await context
          .read<AppServices>()
          .emr
          .getObservations(q: q.isEmpty ? null : q);
      if (mounted) {
        setState(() {
          _observationSuggestions = results;
          if (q.isEmpty) {
            _defaultObservationSuggestions = List.of(results);
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (q.isEmpty && _defaultObservationSuggestions.isNotEmpty) {
        setState(() =>
            _observationSuggestions = List.of(_defaultObservationSuggestions));
      }
    }
  }

  void _addObservation(String phrase, {bool keepFocus = true}) {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return;
    if (_observations.any((x) => x.toLowerCase() == trimmed.toLowerCase())) {
      _observationInput.clear();
      setState(() =>
          _observationSuggestions = List.of(_defaultObservationSuggestions));
      return;
    }
    final isNew = !_isKnownObservation(trimmed);
    setState(() {
      _observations.add(trimmed);
      _observationInput.clear();
      if (isNew) _rememberObservation(trimmed);
      _observationSuggestions = List.of(_defaultObservationSuggestions);
    });
    if (isNew) _persistNewObservation(trimmed);
    if (keepFocus) _observationFocus.requestFocus();
  }

  Future<void> _searchInvestigations(String text) async {
    final q = text.trim();
    try {
      final results = await context
          .read<AppServices>()
          .emr
          .getInvestigations(q: q.isEmpty ? null : q);
      if (mounted) {
        setState(() {
          _investigationSuggestions = results;
          if (q.isEmpty) {
            _defaultInvestigationSuggestions = List.of(results);
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (q.isEmpty && _defaultInvestigationSuggestions.isNotEmpty) {
        setState(() => _investigationSuggestions =
            List.of(_defaultInvestigationSuggestions));
      }
    }
  }

  void _addInvestigation(String phrase, {bool keepFocus = true}) {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return;
    if (_investigations.any((x) => x.toLowerCase() == trimmed.toLowerCase())) {
      _investigationInput.clear();
      setState(() => _investigationSuggestions =
          List.of(_defaultInvestigationSuggestions));
      return;
    }
    final isNew = !_isKnownInvestigation(trimmed);
    setState(() {
      _investigations.add(trimmed);
      _investigationInput.clear();
      if (isNew) _rememberInvestigation(trimmed);
      _investigationSuggestions = List.of(_defaultInvestigationSuggestions);
    });
    if (isNew) _persistNewInvestigation(trimmed);
    if (keepFocus) _investigationFocus.requestFocus();
  }

  void _addDiagnosisFromSuggestion(VisitDiagnosis d) {
    final name = d.diagnosisName.trim();
    if (name.isEmpty) return;
    if (_diagnoses.any(
      (x) => x.diagnosisName.toLowerCase() == name.toLowerCase(),
    )) {
      _diagnosisInput.clear();
      setState(() =>
          _diagnosisSuggestions = List.of(_defaultDiagnosisSuggestions));
      return;
    }
    setState(() {
      _diagnoses.add(VisitDiagnosis(
        diagnosisName: name,
        icdCode: d.icdCode,
        severity: d.severity,
        isPrimary: _diagnoses.isEmpty,
      ));
      _diagnosisInput.clear();
      _diagnosisSuggestions = List.of(_defaultDiagnosisSuggestions);
    });
    _diagnosisFocus.requestFocus();
  }

  Future<Product?> _pickProduct({
    String? initial,
    String type = 'product', // product | service | medicine
    bool allowCreateService = false,
    double? requiredQty,
  }) {
    if (!mounted) return Future.value(null);
    return showAppDialog<Product>(
      context: context,
      builder: (ctx) => _ProductPickerDialog(
        type: type,
        initialQuery: initial,
        allowCreateService: allowCreateService,
        requiredQty: requiredQty,
      ),
    );
  }

  void _addDiagnosis(String name, {bool keepFocus = true}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_diagnoses.any(
      (x) => x.diagnosisName.toLowerCase() == trimmed.toLowerCase(),
    )) {
      _diagnosisInput.clear();
      setState(() =>
          _diagnosisSuggestions = List.of(_defaultDiagnosisSuggestions));
      return;
    }
    final isNew = !_isKnownDiagnosis(trimmed);
    setState(() {
      _diagnoses.add(VisitDiagnosis(
        diagnosisName: trimmed,
        severity: 'mild',
        isPrimary: _diagnoses.isEmpty,
      ));
      _diagnosisInput.clear();
      if (isNew) _rememberDiagnosis(trimmed);
      _diagnosisSuggestions = List.of(_defaultDiagnosisSuggestions);
    });
    if (isNew) _persistNewDiagnosis(trimmed);
    if (keepFocus) _diagnosisFocus.requestFocus();
  }

  String _apiErrorMessage(Object e) {
    final text = e.toString();
    if (text.contains('Duplicate entry') || text.contains('1062')) {
      return 'This record already exists (duplicate). Try again, or pick an existing item instead of creating a new one.';
    }
    final msgMatch = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(text);
    if (msgMatch != null) return msgMatch.group(1)!;
    return text;
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
      if (_joinPhrases(_observations) case final observation?)
        'observation': observation,
      if (_joinPhrases(_investigations) case final investigation?)
        'investigation': investigation,
      if (_followUpNotes.text.trim().isNotEmpty)
        'follow_up_notes': _followUpNotes.text.trim(),
      if (_temperatureF != null)
        'temperature': _fahrenheitToCelsius(_temperatureF!),
      if (_weightKg != null) 'weight': _weightKg,
      if (_heartRateBpm != null) 'heart_rate': _heartRateBpm,
      if (_respiratoryRatePerMin != null)
        'respiratory_rate': _respiratoryRatePerMin,
      if (_followUpDate != null)
        'follow_up_date': _followUpDate!.toIso8601String().substring(0, 10),
      // Always send child collections on edit so removals sync; on create only
      // when non-empty.
      if (_isEdit || _diagnoses.isNotEmpty)
        'diagnoses': [
          for (final d in _diagnoses) d.toJson(),
        ],
      if (_isEdit || _treatments.isNotEmpty)
        'treatments': [
          for (final t in _treatments)
            if (t.nameCtrl.text.trim().isNotEmpty) t.toJson(),
        ],
      if (_isEdit || _medicines.isNotEmpty)
        'medicines': [
          for (final m in _medicines)
            if (m.nameCtrl.text.trim().isNotEmpty) m.toJson(),
        ],
      if (_isEdit || _vaccinations.isNotEmpty)
        'vaccinations': [
          for (final v in _vaccinations)
            if (v.nameCtrl.text.trim().isNotEmpty) v.toJson(),
        ],
      if (_isEdit || _dewormings.isNotEmpty)
        'dewormings': [
          for (final d in _dewormings)
            if (d.nameCtrl.text.trim().isNotEmpty) d.toJson(),
        ],
      if (_isEdit || _surgeries.isNotEmpty)
        'surgeries': [
          for (final s in _surgeries)
            if (s.nameCtrl.text.trim().isNotEmpty) s.toJson(),
        ],
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
        AppMessenger.show(context, SnackBar(content: Text(_apiErrorMessage(e))));
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
        AppMessenger.show(context, SnackBar(content: Text(_apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _complaint.dispose();
    _clinicalNotes.dispose();
    _observationInput.dispose();
    _investigationInput.dispose();
    _followUpNotes.dispose();
    _diagnosisInput.dispose();
    _observationFocus.dispose();
    _investigationFocus.dispose();
    _diagnosisFocus.dispose();
    _serviceCharge.dispose();
    for (final t in _treatments) {
      t.dispose();
    }
    for (final m in _medicines) {
      m.dispose();
    }
    for (final v in _vaccinations) {
      v.dispose();
    }
    for (final d in _dewormings) {
      d.dispose();
    }
    for (final s in _surgeries) {
      s.dispose();
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
                    icon: Icon(
                      Icons.inventory_2_outlined,
                      size: 22,
                      color: _serviceChargeProductId != null
                          ? AppTheme.accent
                          : null,
                    ),
                    tooltip: _serviceChargeProductId != null
                        ? 'Change service product'
                        : 'Link service product (for GST)',
                    onPressed: () async {
                      final p = await _pickProduct(
                        type: 'service',
                        allowCreateService: true,
                      );
                      if (p != null) {
                        setState(() {
                          _serviceChargeProductId = p.id;
                          _serviceChargeProductName = p.name;
                          _serviceCharge.text = p.sellingPrice ==
                                  p.sellingPrice.roundToDouble()
                              ? p.sellingPrice.toInt().toString()
                              : p.sellingPrice.toString();
                        });
                      }
                    },
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              );

              final petResultTiles = _selectedPet == null
                  ? _petResults
                      .map(
                        (p) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.displayLabel),
                          onTap: () => _selectPet(p),
                        ),
                      )
                      .toList()
                  : const <Widget>[];

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    patientField,
                    ...petResultTiles,
                    const SizedBox(height: 12),
                    visitTypeField,
                    const SizedBox(height: 12),
                    serviceChargeField,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: patientField),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: visitTypeField),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: serviceChargeField),
                    ],
                  ),
                  if (petResultTiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: petResultTiles,
                      ),
                    ),
                ],
              );
            },
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
          if (_showDoctorField) ...[
            const SizedBox(height: 12),
            if (_doctorLockedToLogin)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Doctor',
                  suffixIcon: Icon(Icons.lock_outline, size: 18),
                ),
                child: Text(
                  _selectedDoctor?.name ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              )
            else
              AppDropdownButtonFormField<int?>(
                value: _doctorDropdownValue,
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
                  const DropdownMenuItem<int?>(value: null, child: Text('— None —')),
                  ..._doctors.map(
                    (d) => DropdownMenuItem<int?>(
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
                      : _doctors.where((d) => d.id == id).firstOrNull;
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
              final tempOpts =
                  _doubleOptionsWith(_temperatureF, _temperatureOptions);
              final weightOpts = _doubleOptionsWith(_weightKg, _weightOptions);
              final hrOpts = _intOptionsWith(_heartRateBpm, _heartRateOptions);
              final rrOpts = _intOptionsWith(
                _respiratoryRatePerMin,
                _respiratoryRateOptions,
              );
              final fields = [
                AppSearchableDropdownField<double>(
                  label: 'Temp °F',
                  value: _temperatureF,
                  searchHint: 'Search temperature…',
                  options: [
                    for (final t in tempOpts)
                      AppSearchableOption(
                        value: t,
                        label: t.toStringAsFixed(1),
                      ),
                  ],
                  onChanged: (v) => setState(() => _temperatureF = v),
                ),
                AppSearchableDropdownField<double>(
                  label: 'Weight kg',
                  value: _weightKg,
                  searchHint: 'Search weight…',
                  options: [
                    for (final w in weightOpts)
                      AppSearchableOption(
                        value: w,
                        label: w == w.roundToDouble()
                            ? w.toStringAsFixed(0)
                            : w.toStringAsFixed(1),
                      ),
                  ],
                  onChanged: (v) => setState(() => _weightKg = v),
                ),
                AppSearchableDropdownField<int>(
                  label: 'Heart rate',
                  value: _heartRateBpm,
                  searchHint: 'Search heart rate…',
                  options: [
                    for (final h in hrOpts)
                      AppSearchableOption(value: h, label: '$h bpm'),
                  ],
                  onChanged: (v) => setState(() => _heartRateBpm = v),
                ),
                AppSearchableDropdownField<int>(
                  label: 'Resp. rate',
                  value: _respiratoryRatePerMin,
                  searchHint: 'Search resp. rate…',
                  options: [
                    for (final r in rrOpts)
                      AppSearchableOption(value: r, label: '$r /min'),
                  ],
                  onChanged: (v) => setState(() => _respiratoryRatePerMin = v),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 900;

              Widget chipField({
                required String title,
                required String emptyHint,
                required String suggestField,
                required List<String> selected,
                required TextEditingController input,
                required FocusNode focus,
                required List<String> suggestions,
                required ValueChanged<String> onChanged,
                required ValueChanged<String> onSubmitted,
                required ValueChanged<String> onSuggestionTap,
                required ValueChanged<String> onDelete,
              }) {
                final showSuggestions = _openSuggestField == suggestField;
                final visibleSuggestions = showSuggestions
                    ? suggestions
                        .where(
                          (s) => !selected.any(
                            (sel) => sel.toLowerCase() == s.toLowerCase(),
                          ),
                        )
                        .take(12)
                        .toList()
                    : const <String>[];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => focus.requestFocus(),
                      child: InputDecorator(
                        isFocused: focus.hasFocus,
                        isEmpty: selected.isEmpty && input.text.isEmpty,
                        decoration: InputDecoration(
                          hintText: selected.isEmpty ? emptyHint : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (selected.isNotEmpty) ...[
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: selected
                                    .map(
                                      (item) => InputChip(
                                        label: Text(
                                          item,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onDeleted: () => onDelete(item),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 4),
                            ],
                            TextField(
                              controller: input,
                              focusNode: focus,
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 4,
                                ),
                                hintText: selected.isEmpty ? null : 'Add another…',
                              ),
                              onChanged: (v) {
                                setState(() {});
                                onChanged(v);
                              },
                              onSubmitted: onSubmitted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (visibleSuggestions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: visibleSuggestions.map((c) {
                            // onTapDown runs before TextField blur cancels the gesture.
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (_) => onSuggestionTap(c),
                              child: Chip(
                                label: Text(
                                  c,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              }

              final observationField = chipField(
                title: 'Observation',
                emptyHint: 'Search, pick, or type & press Enter',
                suggestField: 'observation',
                selected: _observations,
                input: _observationInput,
                focus: _observationFocus,
                suggestions: _observationSuggestions,
                onChanged: _searchObservations,
                onSubmitted: _addObservation,
                onSuggestionTap: _selectObservationSuggestion,
                onDelete: (item) => setState(() => _observations.remove(item)),
              );

              final investigationField = chipField(
                title: 'Investigation',
                emptyHint: 'Search, pick, or type & press Enter',
                suggestField: 'investigation',
                selected: _investigations,
                input: _investigationInput,
                focus: _investigationFocus,
                suggestions: _investigationSuggestions,
                onChanged: _searchInvestigations,
                onSubmitted: _addInvestigation,
                onSuggestionTap: _selectInvestigationSuggestion,
                onDelete: (item) => setState(() => _investigations.remove(item)),
              );

              final diagnosisVisibleSuggestions = _openSuggestField == 'diagnosis'
                  ? _diagnosisSuggestions
                      .where(
                        (d) => !_diagnoses.any(
                          (sel) =>
                              sel.diagnosisName.toLowerCase() ==
                              d.diagnosisName.toLowerCase(),
                        ),
                      )
                      .take(12)
                      .toList()
                  : const <VisitDiagnosis>[];

              final diagnosisField = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Diagnoses', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _diagnosisFocus.requestFocus(),
                    child: InputDecorator(
                      isFocused: _diagnosisFocus.hasFocus,
                      isEmpty: _diagnoses.isEmpty && _diagnosisInput.text.isEmpty,
                      decoration: InputDecoration(
                        hintText: _diagnoses.isEmpty
                            ? 'Search, pick, or type & press Enter'
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_diagnoses.isNotEmpty) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _diagnoses
                                  .map(
                                    (d) => InputChip(
                                      label: Text(
                                        d.diagnosisName,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onDeleted: () =>
                                          setState(() => _diagnoses.remove(d)),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 4),
                          ],
                          TextField(
                            controller: _diagnosisInput,
                            focusNode: _diagnosisFocus,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 4,
                              ),
                              hintText: _diagnoses.isEmpty ? null : 'Add another…',
                            ),
                            onChanged: (v) {
                              setState(() {});
                              _searchDiagnoses(v);
                            },
                            onSubmitted: _addDiagnosis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (diagnosisVisibleSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: diagnosisVisibleSuggestions
                            .map(
                              (d) => GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (_) => _selectDiagnosisSuggestion(d),
                                child: Chip(
                                  label: Text(
                                    d.icdCode != null
                                        ? '${d.diagnosisName} (${d.icdCode})'
                                        : d.diagnosisName,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    observationField,
                    const SizedBox(height: 16),
                    investigationField,
                    const SizedBox(height: 16),
                    diagnosisField,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: observationField),
                  const SizedBox(width: 12),
                  Expanded(child: investigationField),
                  const SizedBox(width: 12),
                  Expanded(child: diagnosisField),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text('Treatments / Procedures',
                        style: Theme.of(context).textTheme.titleSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Billable',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _addProductsMulti,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
              TextButton.icon(
                onPressed: _addProcedureKit,
                icon: const Icon(Icons.medical_services_outlined, size: 18),
                label: const Text('Add kit'),
              ),
            ],
          ),
          if (_treatments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                  'Add: search & pick one or many · Add kit: insert all kit products',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ),
          ..._treatments.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            final showSuggestions =
                _treatmentSuggestForIndex == i && _treatmentSuggestions.isNotEmpty;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Focus(
                            onFocusChange: (hasFocus) {
                              if (hasFocus) {
                                _showTreatmentSuggestionsFor(i);
                              } else {
                                // Delay so ActionChip taps still register.
                                Future.delayed(const Duration(milliseconds: 180), () {
                                  if (!mounted) return;
                                  _clearTreatmentSuggestions(onlyIfIndex: i);
                                });
                              }
                            },
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Treatment name',
                                isDense: true,
                              ),
                              controller: t.nameCtrl,
                              onChanged: (q) => _searchTreatments(q, forIndex: i),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Price (₹)',
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            controller: t.priceCtrl,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          icon: const Icon(Icons.close, color: AppTheme.danger),
                          onPressed: () {
                            final row = _treatments.removeAt(i);
                            _clearTreatmentSuggestions();
                            setState(() {});
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) => row.dispose());
                          },
                        ),
                      ],
                    ),
                    if (showSuggestions)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _treatmentSuggestions.take(6).map((s) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(s.name, style: const TextStyle(fontSize: 12)),
                                  onPressed: () async {
                                    setState(() {
                                      t.nameCtrl.text = s.name;
                                      if (s.defaultPrice != null) {
                                        t.priceCtrl.text =
                                            _formatAmount(s.defaultPrice!);
                                      }
                                      _treatmentSuggestForIndex = null;
                                      _treatmentSuggestions = [];
                                    });
                                    // Prefer an existing catalog service so we
                                    // don't create a duplicate product later.
                                    try {
                                      final list = await context
                                          .read<AppServices>()
                                          .products
                                          .list(
                                        query: {
                                          'type': 'service',
                                          'search': s.name,
                                          'per_page': 20,
                                          'is_active': 1,
                                        },
                                      );
                                      if (!mounted) return;
                                      final needle = s.name.toLowerCase();
                                      Product? match;
                                      for (final p in list) {
                                        if (p.name.toLowerCase() == needle) {
                                          match = p;
                                          break;
                                        }
                                      }
                                      match ??= list.isEmpty ? null : list.first;
                                      if (match == null) return;
                                      setState(() {
                                        t.productId = match!.id;
                                        t.nameCtrl.text = match.name;
                                        t.priceCtrl.text =
                                            _formatAmount(match.sellingPrice);
                                      });
                                    } catch (_) {}
                                  },
                                ),
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
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text('Prescriptions / Medicines',
                        style: Theme.of(context).textTheme.titleSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Medicine product + stock',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
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
            final showMedicineSuggestions =
                _medicineSuggestForIndex == i && _medicineSuggestions.isNotEmpty;
            final showFrequencySuggestions =
                _medicineFrequencySuggestForIndex == i &&
                    _frequencySuggestions.isNotEmpty;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Focus(
                            onFocusChange: (hasFocus) {
                              if (hasFocus) {
                                _showMedicineSuggestionsFor(i);
                              } else {
                                Future.delayed(const Duration(milliseconds: 180), () {
                                  if (!mounted) return;
                                  _clearMedicineSuggestions(onlyIfIndex: i);
                                });
                              }
                            },
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Medicine name',
                                isDense: true,
                              ),
                              controller: m.nameCtrl,
                              onChanged: (q) => _searchMedicines(q, forIndex: i),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Price (₹)',
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            controller: m.priceCtrl,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Focus(
                            onFocusChange: (hasFocus) {
                              if (hasFocus) {
                                setState(() => _medicineFrequencySuggestForIndex = i);
                              } else {
                                Future.delayed(const Duration(milliseconds: 180), () {
                                  if (!mounted) return;
                                  if (_medicineFrequencySuggestForIndex == i) {
                                    setState(() => _medicineFrequencySuggestForIndex = null);
                                  }
                                });
                              }
                            },
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Frequency',
                                isDense: true,
                              ),
                              controller: m.freqCtrl,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppDropdownButtonFormField<int?>(
                            value: m.durationDays,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Days',
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('—'),
                              ),
                              ...List.generate(
                                15,
                                (i) => DropdownMenuItem<int?>(
                                  value: i + 1,
                                  child: Text('${i + 1}'),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => m.durationDays = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppDropdownButtonFormField<int>(
                            value: m.quantity,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                              isDense: true,
                            ),
                            items: List.generate(
                              20,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text('${i + 1}'),
                              ),
                            ),
                            onChanged: (v) =>
                                setState(() => m.quantity = v ?? 1),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          icon: Icon(
                            Icons.medication_outlined,
                            size: 20,
                            color: m.productId != null ? AppTheme.accent : AppTheme.primary,
                          ),
                          tooltip: m.productId != null
                              ? 'Medicine product linked'
                              : 'Link medicine product (stock checked)',
                          onPressed: () async {
                            final qty = m.quantity.toDouble();
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
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          icon: const Icon(Icons.close, color: AppTheme.danger),
                          onPressed: () {
                            final row = _medicines.removeAt(i);
                            _clearMedicineSuggestions();
                            setState(() {
                              if (_medicineFrequencySuggestForIndex == i) {
                                _medicineFrequencySuggestForIndex = null;
                              }
                            });
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) => row.dispose());
                          },
                        ),
                      ],
                    ),
                    if (showMedicineSuggestions)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _medicineSuggestions.take(6).map((s) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(s.name, style: const TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    setState(() {
                                      m.nameCtrl.text = s.name;
                                      if (s.defaultFrequency != null &&
                                          m.freqCtrl.text.isEmpty) {
                                        m.freqCtrl.text = s.defaultFrequency!;
                                      }
                                      if (s.defaultDurationDays != null &&
                                          m.durationDays == null) {
                                        m.durationDays = s.defaultDurationDays!
                                            .clamp(1, 15);
                                      }
                                      _medicineSuggestForIndex = null;
                                      _medicineSuggestions = [];
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    if (showFrequencySuggestions)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _frequencySuggestions.take(6).map((f) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(f, style: const TextStyle(fontSize: 11)),
                                  onPressed: () => setState(() {
                                    m.freqCtrl.text = f;
                                    _medicineFrequencySuggestForIndex = null;
                                  }),
                                ),
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
          TextField(
            controller: _clinicalNotes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Clinical notes'),
          ),
          const SizedBox(height: 20),
          _buildVaccinationSection(),
          const SizedBox(height: 20),
          _buildDewormingSection(),
          const SizedBox(height: 20),
          _buildSurgerySection(),
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

  Widget _sectionHeader(String title, VoidCallback onAdd) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
        ),
      ],
    );
  }

  Future<DateTime?> _pickDueDate(DateTime? current) {
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
  }

  Widget _buildVaccinationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Vaccinations', () {
          setState(() => _vaccinations.add(_VaccinationRow()));
        }),
        Text(
          'Set next due date to create a vaccination reminder',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        if (_vaccinations.isEmpty)
          Text(
            'No vaccinations for this visit',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ..._vaccinations.asMap().entries.map((e) {
          final i = e.key;
          final row = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: row.nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Vaccine name *',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () {
                          setState(() {
                            final removed = _vaccinations.removeAt(i);
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) => removed.dispose());
                          });
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: row.brandCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Brand',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: row.byCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Administered by',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await _pickDueDate(row.nextDueDate);
                        if (d != null) setState(() => row.nextDueDate = d);
                      },
                      icon: const Icon(Icons.notifications_active_outlined, size: 16),
                      label: Text(
                        row.nextDueDate != null
                            ? 'Next due ${row.nextDueDate!.toIso8601String().substring(0, 10)}'
                            : 'Set next due (reminder)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDewormingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Deworming', () {
          setState(() => _dewormings.add(_DewormingRow()));
        }),
        Text(
          'Set next due date to create a deworming reminder',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        if (_dewormings.isEmpty)
          Text(
            'No deworming for this visit',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ..._dewormings.asMap().entries.map((e) {
          final i = e.key;
          final row = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: row.nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Medicine *',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () {
                          setState(() {
                            final removed = _dewormings.removeAt(i);
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) => removed.dispose());
                          });
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: row.dosageCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Dosage',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: row.byCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Administered by',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await _pickDueDate(row.nextDueDate);
                        if (d != null) setState(() => row.nextDueDate = d);
                      },
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                        row.nextDueDate != null
                            ? 'Next due ${row.nextDueDate!.toIso8601String().substring(0, 10)}'
                            : 'Set next due (reminder)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSurgerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Surgery', () {
          setState(() => _surgeries.add(_SurgeryRow(
                surgeonName: _selectedDoctor?.name ?? '',
              )));
        }),
        const SizedBox(height: 8),
        if (_surgeries.isEmpty)
          Text(
            'No surgery for this visit',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ..._surgeries.asMap().entries.map((e) {
          final i = e.key;
          final row = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: row.nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Surgery name *',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () {
                          setState(() {
                            final removed = _surgeries.removeAt(i);
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) => removed.dispose());
                          });
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: row.anesthesiaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Anesthesia',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: row.surgeonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Surgeon',
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
                          controller: row.costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Cost',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await _pickDueDate(row.followUpDate);
                            if (d != null) setState(() => row.followUpDate = d);
                          },
                          icon: const Icon(Icons.event_outlined, size: 16),
                          label: Text(
                            row.followUpDate != null
                                ? row.followUpDate!.toIso8601String().substring(0, 10)
                                : 'Follow-up',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

String _formatAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

class _ProductPickerDialog extends StatefulWidget {
  const _ProductPickerDialog({
    required this.type,
    this.initialQuery,
    this.allowCreateService = false,
    this.requiredQty,
  });

  final String type;
  final String? initialQuery;
  final bool allowCreateService;
  final double? requiredQty;

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  late final TextEditingController _search;
  List<Product> _catalog = [];
  List<Product> _results = [];
  var _loadingCatalog = true;
  var _searching = false;
  var _searchSeq = 0;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCatalog());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _loadError = null;
    });
    try {
      final list = await context.read<AppServices>().products.list(
            query: {
              'per_page': 500,
              'is_active': 1,
              'type': widget.type,
            },
          );
      if (!mounted) return;
      setState(() {
        _catalog = list;
        _loadingCatalog = false;
      });
      await _runSearch(_search.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _loadError = e.toString();
      });
    }
  }

  Future<List<Product>> _fetch(String q) async {
    return context.read<AppServices>().products.list(
          query: {
            'search': q,
            'per_page': 50,
            'is_active': 1,
            'type': widget.type,
          },
        );
  }

  List<Product> _filterLocal(String q) {
    final needle = q.toLowerCase();
    return _catalog.where((p) {
      return p.name.toLowerCase().contains(needle) ||
          (p.sku?.toLowerCase().contains(needle) ?? false) ||
          (p.barcode?.toLowerCase().contains(needle) ?? false);
    }).toList();
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    final seq = ++_searchSeq;

    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = List<Product>.from(_catalog);
        _searching = false;
      });
      return;
    }

    // Short query: filter the already-loaded catalog immediately.
    if (q.length < 2) {
      if (!mounted) return;
      setState(() {
        _results = _filterLocal(q);
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    try {
      final list = await _fetch(q);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = list;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = _filterLocal(q);
        _searching = false;
      });
    }
  }

  Future<void> _createService() async {
    final created = await showAppDialog<Product>(
      context: context,
      builder: (ctx) => _CreateServiceDialog(
        initialName: _search.text.trim(),
      ),
    );
    if (created != null && mounted) {
      Navigator.pop(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
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

    final emptyMessage = _loadError != null
        ? 'Could not load products.\n$_loadError'
        : (_search.text.trim().isEmpty
            ? (type == 'medicine'
                ? 'No medicine products in catalog'
                : type == 'service'
                    ? 'No service products in catalog'
                    : 'No products in catalog')
            : 'No matching products found');

    return AppFormDialogShell(
      title: title,
      subtitle: subtitle,
      icon: icon,
      maxWidth: 520,
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            autofocus: true,
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(Icons.search, size: 22),
              suffixIcon: (_searching || _loadingCatalog)
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_search.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            _search.clear();
                            _runSearch('');
                          },
                        )
                      : null),
            ),
            onChanged: _runSearch,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: _loadingCatalog && _results.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                emptyMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              if (_loadError != null) ...[
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _loadCatalog,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: Color(0xFFE2E8F0),
                        ),
                        itemBuilder: (_, i) {
                          final p = _results[i];
                          final stock = p.currentStock;
                          final qtyNeeded = widget.requiredQty ?? 1;
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
                                : () => Navigator.pop(context, p),
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
            if (widget.allowCreateService && type == 'service') ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _createService,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add service'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateServiceDialog extends StatefulWidget {
  const _CreateServiceDialog({this.initialName = ''});

  final String initialName;

  @override
  State<_CreateServiceDialog> createState() => _CreateServiceDialogState();
}

class _CreateServiceDialogState extends State<_CreateServiceDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  var _creating = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _priceCtrl = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (name.isEmpty) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Enter a service name')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final productsApi = context.read<AppServices>().products;

      // Reuse an existing active service with the same name to avoid
      // duplicate catalog rows / unique-constraint errors.
      try {
        final existing = await productsApi.list(
          query: {
            'type': 'service',
            'search': name,
            'per_page': 20,
            'is_active': 1,
          },
        );
        final needle = name.toLowerCase();
        for (final p in existing) {
          if (p.name.toLowerCase() == needle) {
            if (mounted) Navigator.pop(context, p);
            return;
          }
        }
      } catch (_) {}

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final p = await productsApi.create({
        'name': name,
        'sku': 'SVC-$stamp',
        'barcode': 'SVC-$stamp',
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
      if (mounted) Navigator.pop(context, p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      final text = e.toString();
      final friendly = (text.contains('Duplicate entry') || text.contains('1062'))
          ? 'A product with this name or code already exists. Search and select it instead.'
          : text;
      AppMessenger.show(context, SnackBar(content: Text(friendly)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final screenH = MediaQuery.sizeOf(context).height;
    final width = 440.0.clamp(280.0, screenW - 48);

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: screenH * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add service product',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Creates a catalog service for billing',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: appFormFieldDecoration(
                  'Service name *',
                  hint: 'e.g. Consultation',
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _priceCtrl,
                decoration: appFormFieldDecoration(
                  'Price (₹)',
                  hint: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _creating ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _creating ? null : _submit,
                      child: _creating
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaccinationRow {
  _VaccinationRow({
    String name = '',
    String brand = '',
    String administeredBy = '',
    this.nextDueDate,
  })  : nameCtrl = TextEditingController(text: name),
        brandCtrl = TextEditingController(text: brand),
        byCtrl = TextEditingController(text: administeredBy);

  factory _VaccinationRow.fromModel(PetVaccination v) => _VaccinationRow(
        name: v.vaccineName,
        brand: v.vaccineBrand ?? '',
        administeredBy: v.administeredBy ?? '',
        nextDueDate: v.nextDueDate != null ? DateTime.tryParse(v.nextDueDate!) : null,
      );

  final TextEditingController nameCtrl;
  final TextEditingController brandCtrl;
  final TextEditingController byCtrl;
  DateTime? nextDueDate;

  Map<String, dynamic> toJson() => {
        'vaccine_name': nameCtrl.text.trim(),
        if (brandCtrl.text.trim().isNotEmpty) 'vaccine_brand': brandCtrl.text.trim(),
        if (byCtrl.text.trim().isNotEmpty) 'administered_by': byCtrl.text.trim(),
        if (nextDueDate != null)
          'next_due_date': nextDueDate!.toIso8601String().substring(0, 10),
        'reminder_days_before': 7,
      };

  void dispose() {
    nameCtrl.dispose();
    brandCtrl.dispose();
    byCtrl.dispose();
  }
}

class _DewormingRow {
  _DewormingRow({
    String name = '',
    String dosage = '',
    String administeredBy = '',
    this.nextDueDate,
  })  : nameCtrl = TextEditingController(text: name),
        dosageCtrl = TextEditingController(text: dosage),
        byCtrl = TextEditingController(text: administeredBy);

  factory _DewormingRow.fromModel(PetDeworming d) => _DewormingRow(
        name: d.medicineName,
        dosage: d.dosage ?? '',
        administeredBy: d.administeredBy ?? '',
        nextDueDate: d.nextDueDate != null ? DateTime.tryParse(d.nextDueDate!) : null,
      );

  final TextEditingController nameCtrl;
  final TextEditingController dosageCtrl;
  final TextEditingController byCtrl;
  DateTime? nextDueDate;

  Map<String, dynamic> toJson() => {
        'medicine_name': nameCtrl.text.trim(),
        if (dosageCtrl.text.trim().isNotEmpty) 'dosage': dosageCtrl.text.trim(),
        if (byCtrl.text.trim().isNotEmpty) 'administered_by': byCtrl.text.trim(),
        if (nextDueDate != null)
          'next_due_date': nextDueDate!.toIso8601String().substring(0, 10),
      };

  void dispose() {
    nameCtrl.dispose();
    dosageCtrl.dispose();
    byCtrl.dispose();
  }
}

class _SurgeryRow {
  _SurgeryRow({
    String name = '',
    String anesthesia = '',
    String surgeonName = '',
    String cost = '',
    this.followUpDate,
  })  : nameCtrl = TextEditingController(text: name),
        anesthesiaCtrl = TextEditingController(text: anesthesia),
        surgeonCtrl = TextEditingController(text: surgeonName),
        costCtrl = TextEditingController(text: cost);

  factory _SurgeryRow.fromModel(PetSurgery s) => _SurgeryRow(
        name: s.surgeryName,
        anesthesia: s.anesthesiaType ?? '',
        surgeonName: s.surgeonName ?? '',
        cost: s.cost > 0 ? _formatAmount(s.cost) : '',
        followUpDate: s.followUpDate != null ? DateTime.tryParse(s.followUpDate!) : null,
      );

  final TextEditingController nameCtrl;
  final TextEditingController anesthesiaCtrl;
  final TextEditingController surgeonCtrl;
  final TextEditingController costCtrl;
  DateTime? followUpDate;

  Map<String, dynamic> toJson() => {
        'surgery_name': nameCtrl.text.trim(),
        if (anesthesiaCtrl.text.trim().isNotEmpty)
          'anesthesia_type': anesthesiaCtrl.text.trim(),
        if (surgeonCtrl.text.trim().isNotEmpty)
          'surgeon_name': surgeonCtrl.text.trim(),
        if (costCtrl.text.trim().isNotEmpty)
          'cost': double.tryParse(costCtrl.text.trim()) ?? 0,
        if (followUpDate != null)
          'follow_up_date': followUpDate!.toIso8601String().substring(0, 10),
        'status': 'completed',
      };

  void dispose() {
    nameCtrl.dispose();
    anesthesiaCtrl.dispose();
    surgeonCtrl.dispose();
    costCtrl.dispose();
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
    int quantity = 1,
    double unitPrice = 0,
  })  : durationDays = durationDays?.clamp(1, 15),
        quantity = quantity.clamp(1, 20),
        nameCtrl = TextEditingController(text: name),
        dosageCtrl = TextEditingController(text: dosage),
        freqCtrl = TextEditingController(text: frequency),
        priceCtrl = TextEditingController(text: unitPrice.toString());

  factory _MedicineRow.fromModel(VisitMedicine m) => _MedicineRow(
        productId: m.productId,
        name: m.medicineName,
        dosage: m.dosage ?? '',
        frequency: m.frequency ?? '',
        durationDays: m.durationDays,
        quantity: m.quantity.round(),
        unitPrice: m.unitPrice,
      );

  int? productId;
  int? durationDays;
  int quantity;
  final TextEditingController nameCtrl;
  final TextEditingController dosageCtrl;
  final TextEditingController freqCtrl;
  final TextEditingController priceCtrl;

  Map<String, dynamic> toJson() => {
        if (productId != null) 'product_id': productId,
        'medicine_name': nameCtrl.text.trim(),
        if (dosageCtrl.text.isNotEmpty) 'dosage': dosageCtrl.text.trim(),
        if (freqCtrl.text.isNotEmpty) 'frequency': freqCtrl.text.trim(),
        if (durationDays != null) 'duration_days': durationDays,
        'quantity': quantity.toDouble(),
        'unit_price': double.tryParse(priceCtrl.text) ?? 0,
      };

  void dispose() {
    nameCtrl.dispose();
    dosageCtrl.dispose();
    freqCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _MultiProductPickerSheet extends StatefulWidget {
  const _MultiProductPickerSheet({
    required this.type,
    required this.title,
    this.allowAllTypes = false,
  });

  final String type;
  final String title;
  final bool allowAllTypes;

  @override
  State<_MultiProductPickerSheet> createState() => _MultiProductPickerSheetState();
}

class _MultiProductPickerSheetState extends State<_MultiProductPickerSheet> {
  final _search = TextEditingController();
  final _selected = <int, Product>{};
  List<Product> _results = [];
  bool _loading = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    final seq = ++_seq;
    setState(() => _loading = true);
    try {
      final query = <String, dynamic>{
        'per_page': 40,
        'is_active': 1,
        if (q.trim().isNotEmpty) 'search': q.trim(),
        if (!widget.allowAllTypes) 'type': widget.type,
      };
      final list = await context.read<AppServices>().products.list(query: query);
      if (!mounted || seq != _seq) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() => _loading = false);
    }
  }

  void _toggle(Product p) {
    setState(() {
      if (_selected.containsKey(p.id)) {
        _selected.remove(p.id);
      } else {
        _selected[p.id] = p;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) {
                  if (v.isEmpty || v.length >= 2) _runSearch(v);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Tap to select · Add selected inserts all checked items',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(child: Text('No products found'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final p = _results[i];
                            final checked = _selected.containsKey(p.id);
                            return CheckboxListTile(
                              value: checked,
                              onChanged: (_) => _toggle(p),
                              title: Text(p.name),
                              subtitle: Text('₹${p.sellingPrice.toStringAsFixed(2)}'),
                              secondary: IconButton(
                                tooltip: 'Add this only',
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => Navigator.pop(context, [p]),
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected.values.toList()),
                  child: Text('Add selected (${_selected.length})'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcedureKitPickerDialog extends StatefulWidget {
  const _ProcedureKitPickerDialog();

  @override
  State<_ProcedureKitPickerDialog> createState() =>
      _ProcedureKitPickerDialogState();
}

class _ProcedureKitPickerDialogState extends State<_ProcedureKitPickerDialog> {
  final _search = TextEditingController();
  List<ProcedureKit> _all = [];
  List<ProcedureKit> _kits = [];
  bool _loading = true;
  String? _error;
  var _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load([String? q]) async {
    final seq = ++_searchSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final kits = await context.read<AppServices>().emr.getProcedureKits(
            q: (q != null && q.trim().length >= 2) ? q.trim() : null,
          );
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        if (q == null || q.trim().isEmpty) {
          _all = kits;
          _kits = kits;
        } else if (q.trim().length < 2) {
          _kits = _filterLocal(q.trim());
        } else {
          _kits = kits;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<ProcedureKit> _filterLocal(String q) {
    final needle = q.toLowerCase();
    return _all.where((k) {
      return k.name.toLowerCase().contains(needle) ||
          (k.procedureCode?.toLowerCase().contains(needle) ?? false);
    }).toList();
  }

  void _onSearchChanged(String raw) {
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() => _kits = List<ProcedureKit>.from(_all));
      return;
    }
    if (q.length < 2) {
      setState(() => _kits = _filterLocal(q));
      return;
    }
    _load(q);
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialogShell(
      title: 'Add procedure kit',
      subtitle: 'Add all kit products to this visit in one step',
      icon: Icons.medical_services_outlined,
      maxWidth: 520,
      onClose: () => Navigator.pop(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search kits by name or code…',
              prefixIcon: const Icon(Icons.search, size: 22),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_search.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            _search.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: _loading && _kits.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.danger),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => _load(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _kits.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 30,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _search.text.trim().isEmpty
                                        ? 'No procedure kits yet'
                                        : 'No kits match your search',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _search.text.trim().isEmpty
                                        ? 'Create kits under EMR → Procedure kits, then add them here.'
                                        : 'Try another name or clear the search.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _kits.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: Color(0xFFE2E8F0),
                            ),
                            itemBuilder: (context, i) {
                              final kit = _kits[i];
                              final total = kit.itemsTotal > 0
                                  ? kit.itemsTotal
                                  : kit.defaultPrice;
                              final meta = [
                                '${kit.items.length} item${kit.items.length == 1 ? '' : 's'}',
                                if (total != null && total > 0)
                                  '₹${total.toStringAsFixed(0)}',
                                if (kit.procedureCode != null &&
                                    kit.procedureCode!.isNotEmpty)
                                  kit.procedureCode!,
                              ].join(' · ');
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      AppTheme.primary.withValues(alpha: 0.12),
                                  child: const Icon(
                                    Icons.medical_services_outlined,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                title: Text(
                                  kit.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  meta,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: AppTheme.primary,
                                ),
                                onTap: () => Navigator.pop(context, kit),
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
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }
}
