import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/navigation/shell_back.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../data/models/emr.dart';
import '../../data/models/product.dart';
import '../../data/models/prescription_under.dart';
import '../../data/models/treatment_under.dart';
import '../../data/models/vaccination_category.dart';
import '../../data/services/emr_master_data_service.dart';

/// Which visit form section owns a medicine row (not persisted to API).
enum _MedicineContext { treatmentUnder, prescription, freeForm }

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
  final _investigationInput = TextEditingController();
  final _followUpNotes = TextEditingController();
  final _investigationFocus = FocusNode();
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
  final List<_InvestigationRow> _investigations = [];
  final List<_TreatmentRow> _treatments = [];
  final List<_MedicineRow> _medicines = [];
  final List<_VaccinationRow> _vaccinations = [];
  List<String> _complaintSuggestions = [];
  List<String> _defaultComplaintSuggestions = [];
  List<String> _investigationSuggestions = [];
  List<String> _defaultInvestigationSuggestions = [];
  /// Which chip-field suggestion panel is open (`investigation`).
  String? _openSuggestField;
  List<TreatmentSuggestion> _defaultTreatmentSuggestions = [];
  List<TreatmentSuggestion> _treatmentSuggestions = [];
  int? _treatmentSuggestForIndex;
  List<MedicineSuggestion> _defaultMedicineSuggestions = [];
  List<MedicineSuggestion> _medicineSuggestions = [];
  int? _medicineSuggestForIndex;
  List<VaccinationTemplate> _defaultVaccinationSuggestions = [];
  List<VaccinationTemplate> _vaccinationSuggestions = [];
  int? _vaccinationSuggestForIndex;
  String? _vaccinationTab;
  String? _treatmentUnderTab;
  String? _prescriptionTab;
  List<TreatmentUnderCategoryItem> _treatmentUnderCategories = [];
  List<PrescriptionUnderCategoryItem> _prescriptionUnderCategories = [];
  final Map<String, List<Product>> _treatmentUnderMapped = {};
  final Map<String, List<Product>> _prescriptionUnderMapped = {};
  bool _loadingTreatmentUnderMapped = false;
  bool _loadingPrescriptionUnderMapped = false;
  PetSummary? _petSummary;
  int? _serviceChargeProductId;
  String? _serviceChargeProductName;
  Timer? _complaintLearnDebounce;
  Timer? _investigationLearnDebounce;

  static const int _emrLearnMinChars = 6;
  static const Duration _emrLearnDebounce = Duration(milliseconds: 450);

  String _visitType = 'consultation';
  DateTime _visitDate = DateTime.now();
  TimeOfDay _visitTime = TimeOfDay.now();
  DateTime? _followUpDate;

  bool _loading = false;
  bool _saving = false;
  bool _searchingPets = false;
  int? _sourceAppointmentId;

  bool get _isEdit => widget.visitId != null;

  /// Phone/tablet native app only. Windows/web keep the current wide layout.
  bool get _compactUi => AppConfig.isNativeMobile;

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
      case 'investigation':
        final t = _investigationInput.text.trim();
        if (t.isNotEmpty) _addInvestigation(t, keepFocus: false);
    }
  }

  void _selectInvestigationSuggestion(String phrase) {
    _openSuggestField = 'investigation';
    _addInvestigation(phrase);
  }

  bool _isKnownComplaint(String value) {
    final key = value.toLowerCase();
    return _defaultComplaintSuggestions.any((s) => s.toLowerCase() == key) ||
        _complaintSuggestions.any((s) => s.toLowerCase() == key);
  }

  bool _isKnownInvestigation(String value) {
    final key = value.toLowerCase();
    return _defaultInvestigationSuggestions.any((s) => s.toLowerCase() == key) ||
        _investigationSuggestions.any((s) => s.toLowerCase() == key);
  }

  void _rememberComplaint(String value) {
    if (_isKnownComplaint(value)) return;
    _defaultComplaintSuggestions = [value, ..._defaultComplaintSuggestions];
    _complaintSuggestions = List.of(_defaultComplaintSuggestions);
  }

  void _rememberInvestigation(String value) {
    if (_isKnownInvestigation(value)) return;
    _defaultInvestigationSuggestions = [
      value,
      ..._defaultInvestigationSuggestions,
    ];
    _investigationSuggestions = List.of(_defaultInvestigationSuggestions);
  }

  Future<void> _persistNewComplaint(String name) async {
    if (!mounted) return;
    try {
      await context.read<AppServices>().emr.rememberTemplates(
            complaints: [name],
          );
      _rememberComplaint(name);
    } catch (_) {}
  }

  Future<void> _persistNewInvestigation(String name) async {
    if (!mounted) return;
    try {
      await context.read<AppServices>().emr.rememberTemplates(
            investigations: [name],
          );
      _rememberInvestigation(name);
    } catch (_) {}
  }

  /// Typing: learn only when term is longer than [_emrLearnMinChars].
  /// Enter (`force: true`): learn any unknown non-empty term.
  void _scheduleLearnComplaint(String raw, {required bool force}) {
    final term = raw.trim();
    if (term.isEmpty || _isKnownComplaint(term)) return;
    if (!force && term.length <= _emrLearnMinChars) return;

    _complaintLearnDebounce?.cancel();
    if (force) {
      _rememberComplaint(term);
      unawaited(_persistNewComplaint(term));
      return;
    }
    _complaintLearnDebounce = Timer(_emrLearnDebounce, () {
      if (!mounted) return;
      final current = _complaintSearchTerm(_complaint.text).trim();
      if (current != term) return;
      if (_isKnownComplaint(term) || term.length <= _emrLearnMinChars) return;
      unawaited(_persistNewComplaint(term));
    });
  }

  void _scheduleLearnInvestigation(String raw, {required bool force}) {
    final term = raw.trim();
    if (term.isEmpty || _isKnownInvestigation(term)) return;
    if (!force && term.length <= _emrLearnMinChars) return;

    _investigationLearnDebounce?.cancel();
    if (force) {
      unawaited(_persistNewInvestigation(term));
      return;
    }
    _investigationLearnDebounce = Timer(_emrLearnDebounce, () {
      if (!mounted) return;
      final current = _investigationInput.text.trim();
      if (current != term) return;
      if (_isKnownInvestigation(term) || term.length <= _emrLearnMinChars) return;
      unawaited(_persistNewInvestigation(term));
    });
  }

  void _onComplaintChanged(String text) {
    _searchComplaints(text);
    _scheduleLearnComplaint(_complaintSearchTerm(text), force: false);
  }

  void _onInvestigationChanged(String text) {
    _searchInvestigations(text);
    _scheduleLearnInvestigation(text, force: false);
  }

  /// Persist any free-typed terms from the current form into EMR templates.
  Future<void> _persistAllNewEmrTerms() async {
    if (!mounted) return;
    final complaints = _complaintForApi
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !_isKnownComplaint(e))
        .toList();
    final investigations = _investigations
        .map((e) => e.name.trim())
        .where((e) => e.isNotEmpty && !_isKnownInvestigation(e))
        .toList();

    if (complaints.isEmpty && investigations.isEmpty) {
      return;
    }

    try {
      await context.read<AppServices>().emr.rememberTemplates(
            complaints: complaints.isEmpty ? null : complaints,
            investigations: investigations.isEmpty ? null : investigations,
          );
      for (final c in complaints) {
        _rememberComplaint(c);
      }
      for (final i in investigations) {
        _rememberInvestigation(i);
      }
    } catch (_) {}
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final emr = context.read<AppServices>().emr;
    final auth = context.read<AuthSession>();

    try {
      // Include unavailable doctors so the logged-in doctor still appears.
      _doctors = _uniqueDoctors(await emr.listDoctors());
      _defaultComplaintSuggestions = await emr.getComplaints();
      _complaintSuggestions = List.of(_defaultComplaintSuggestions);
      _defaultInvestigationSuggestions = await emr.getInvestigations();
      _investigationSuggestions = List.of(_defaultInvestigationSuggestions);
      _defaultTreatmentSuggestions = await emr.getTreatmentSuggestions();
      _defaultMedicineSuggestions = await emr.getMedicineSuggestions();

      if (_isEdit) {
        final visit = await emr.getVisit(widget.visitId!);
        _applyVisit(visit);
      } else if (_sourceAppointmentId != null) {
        final appt = await emr.getAppointment(_sourceAppointmentId!);
        await _prefillFromAppointment(appt);
      } else if (widget.petId != null) {
        await _prefillFromPetId(widget.petId!);
      }

      await _loadVaccinationSuggestions();
      await _loadCategoryCatalogs();

      // Doctor login: bind doctor_id from session (Doctor UI is hidden).
      // Admin / branch manager: no doctor_id.
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
    for (final row in _investigations) {
      row.dispose();
    }
    _investigations
      ..clear()
      ..addAll(
        VisitInvestigationItem.parse(visit.investigation)
            .map(_InvestigationRow.fromItem),
      );
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
    _treatments
      ..clear()
      ..addAll((visit.treatments ?? []).map(_TreatmentRow.fromModel));
    _medicines
      ..clear()
      ..addAll((visit.medicines ?? []).map(_MedicineRow.fromModel));
    final firstUnder = _medicines.where(
      (m) =>
          m.context == _MedicineContext.treatmentUnder &&
          m.treatmentUnderCategory != null,
    );
    if (firstUnder.isNotEmpty) {
      _treatmentUnderTab = TreatmentUnderCategory.forVisit(
        snapshot: firstUnder.first.treatmentUnderCategory,
      );
    }
    final firstRx = _medicines.where(
      (m) =>
          m.context == _MedicineContext.prescription &&
          m.prescriptionUnderCategory != null,
    );
    if (firstRx.isNotEmpty) {
      _prescriptionTab = PrescriptionUnderCategory.forVisit(
        snapshot: firstRx.first.prescriptionUnderCategory,
      );
    }
    for (final r in _vaccinations) {
      r.dispose();
    }
    _vaccinations
      ..clear()
      ..addAll((visit.vaccinations ?? []).map(_VaccinationRow.fromModel));
    _vaccinationTab = null;
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
    await _loadVaccinationSuggestions();
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

  String? get _petVaccinationSpecies => VaccinationTemplate.normalizeSpecies(
        _selectedPet?.species ?? _petSummary?.species,
      );

  Future<void> _loadVaccinationSuggestions({String? query}) async {
    final species = _petVaccinationSpecies;
    if (species == null) {
      if (!mounted) return;
      setState(() {
        _defaultVaccinationSuggestions = [];
        _vaccinationSuggestions = [];
      });
      return;
    }
    try {
      final results = await context.read<AppServices>().emr.getVaccinationSuggestions(
            species: species,
            petId: _selectedPet?.id,
            q: query,
          );
      if (!mounted) return;
      setState(() {
        if (query == null || query.isEmpty) {
          _defaultVaccinationSuggestions = results;
        }
        _vaccinationSuggestions = results;
        _attachVaccinationTemplates();
      });
    } catch (_) {}
  }

  VaccinationTemplate? _templateForName(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    VaccinationTemplate? any;
    for (final t in _defaultVaccinationSuggestions) {
      if (t.name.toLowerCase() != n) continue;
      if (_vaccinationTab != null &&
          VaccinationCategory.forVisit(snapshot: t.category, name: t.name) ==
              _vaccinationTab) {
        return t;
      }
      any ??= t;
    }
    return any;
  }

  void _attachVaccinationTemplates() {
    for (final row in _vaccinations) {
      if (row.template != null) {
        row.category = row.template!.category;
        _fillVaccinationNextDue(row, overwrite: false);
        continue;
      }
      VaccinationTemplate? match;
      for (final t in _defaultVaccinationSuggestions) {
        if (row.templateId != null && t.id == row.templateId) {
          match = t;
          break;
        }
      }
      match ??= _templateForName(row.nameCtrl.text);
      if (match != null) {
        row.template = match;
        row.templateId = match.id;
        row.category = match.category;
        _fillVaccinationNextDue(row, overwrite: false);
      } else {
        row.category ??= VaccinationCategory.inferFromName(row.nameCtrl.text);
      }
    }
  }

  String _rowCategory(_VaccinationRow row) => VaccinationCategory.forVisit(
        snapshot: row.category ?? row.template?.category,
        name: row.nameCtrl.text,
      );

  List<VaccinationTemplate> _vaccinesForTab(String tab) {
    return _defaultVaccinationSuggestions
        .where(
          (t) =>
              VaccinationCategory.forVisit(snapshot: t.category, name: t.name) ==
              tab,
        )
        .toList();
  }

  int _vaccinationCount(String tab) =>
      _vaccinations.where((r) => _rowCategory(r) == tab).length;

  bool _isVaccineSelected(VaccinationTemplate t) =>
      _vaccinations.any((r) => r.templateId == t.id);

  void _showVaccinationSuggestionsFor(int index, {String? query}) {
    final q = (query ?? _vaccinations[index].nameCtrl.text).trim();
    final tabVaccines = _vaccinationTab == null
        ? List<VaccinationTemplate>.from(_defaultVaccinationSuggestions)
        : _vaccinesForTab(_vaccinationTab!);
    setState(() {
      _vaccinationSuggestForIndex = index;
      if (q.length < 2) {
        _vaccinationSuggestions = tabVaccines;
      }
    });
    if (q.length >= 2) {
      final lower = q.toLowerCase();
      setState(() {
        _vaccinationSuggestions =
            tabVaccines.where((t) => t.name.toLowerCase().contains(lower)).toList();
      });
    }
  }

  void _clearVaccinationSuggestions({int? onlyIfIndex}) {
    if (onlyIfIndex != null && _vaccinationSuggestForIndex != onlyIfIndex) return;
    setState(() {
      _vaccinationSuggestForIndex = null;
      _vaccinationSuggestions = [];
    });
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _removeVaccinationAt(int index) {
    if (index < 0 || index >= _vaccinations.length) return;
    final row = _vaccinations.removeAt(index);
    _vaccinationSuggestForIndex = null;
    _vaccinationSuggestions = [];
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  void _fillVaccinationNextDue(_VaccinationRow row, {bool overwrite = true}) {
    if (row.nextDueManual) return;
    if (!overwrite && row.nextDueDate != null) return;
    final days = row.template?.durationDays;
    if (days == null || days <= 0) {
      if (overwrite) row.nextDueDate = null;
      return;
    }
    row.nextDueDate =
        _dateOnly(row.administeredDate ?? _visitDate).add(Duration(days: days));
  }

  void _addVaccineTemplate(VaccinationTemplate t) {
    if (_isVaccineSelected(t)) {
      AppMessenger.show(
        context,
        SnackBar(content: Text('${t.name} is already added')),
      );
      return;
    }
    setState(() {
      final row = _VaccinationRow(
        name: t.name,
        templateId: t.id,
        template: t,
        category: t.category,
        doseNumber: t.nextDoseNumber,
        administeredDate: _dateOnly(_visitDate),
      );
      _fillVaccinationNextDue(row);
      _vaccinations.add(row);
    });
  }

  Future<void> _pickVaccinationFromEmr(String category) async {
    if (_petVaccinationSpecies == null) {
      AppMessenger.show(
        context,
        const SnackBar(
          content: Text('Select a pet first to load dog or cat vaccines'),
        ),
      );
      return;
    }
    if (_defaultVaccinationSuggestions.isEmpty) {
      await _loadVaccinationSuggestions();
      if (!mounted) return;
    }
    final templates = _vaccinesForTab(category);
    if (templates.isEmpty) {
      AppMessenger.show(
        context,
        SnackBar(
          content: Text(
            'No ${VaccinationCategory.labelOf(category)} items in EMR master data',
          ),
        ),
      );
      return;
    }
    final picked = await showAppDialog<VaccinationTemplate>(
      context: context,
      builder: (ctx) => _VaccinationTemplatePickerDialog(
        category: category,
        templates: templates,
        selectedIds: {
          for (final r in _vaccinations)
            if (r.templateId != null) r.templateId!,
        },
      ),
    );
    if (picked == null || !mounted) return;
    _addVaccineTemplate(picked);
  }

  void _addCustomVaccination() {
    if (_petVaccinationSpecies == null) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Select a pet first to load dog or cat vaccines')),
      );
      return;
    }
    setState(() {
      _vaccinations.add(
        _VaccinationRow(
          category: _vaccinationTab,
          administeredDate: _dateOnly(_visitDate),
        ),
      );
      _vaccinationSuggestForIndex = _vaccinations.length - 1;
      _vaccinationSuggestions = _vaccinationTab == null
          ? List<VaccinationTemplate>.from(_defaultVaccinationSuggestions)
          : _vaccinesForTab(_vaccinationTab!);
    });
  }

  void _applyVaccineTemplate(_VaccinationRow row, VaccinationTemplate t) {
    final index = _vaccinations.indexOf(row);
    if (index < 0) return;
    if (row.templateId == t.id) {
      _fillVaccinationNextDue(row);
      return;
    }
    if (_vaccinations.any((r) => r != row && r.templateId == t.id)) {
      AppMessenger.show(
        context,
        SnackBar(content: Text('${t.name} is already added')),
      );
      return;
    }

    row.nameCtrl.text = t.name;
    row.template = t;
    row.templateId = t.id;
    row.category = t.category;
    row.status = 'completed';
    row.administeredDate = _dateOnly(_visitDate);
    row.nextDueManual = false;
    row.doseNumber = t.nextDoseNumber;
    _fillVaccinationNextDue(row);
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
      // Enter: always check and save unknown terms (any length).
      _scheduleLearnComplaint(q, force: true);
    }
    setState(() {});
    _searchComplaints('');
  }

  Future<void> _searchComplaints(String text) async {
    final q = _complaintSearchTerm(text);
    try {
      final results =
          await context.read<AppServices>().emr.getComplaints(q: q.isEmpty ? null : q);
      if (mounted) {
        setState(() {
          _complaintSuggestions = results;
          if (q.isEmpty) {
            _defaultComplaintSuggestions = List.of(results);
          }
        });
      }
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
    if (_investigations.any((x) => x.name.toLowerCase() == trimmed.toLowerCase())) {
      _investigationInput.clear();
      setState(() => _investigationSuggestions =
          List.of(_defaultInvestigationSuggestions));
      return;
    }
    final isNew = !_isKnownInvestigation(trimmed);
    setState(() {
      _investigations.add(_InvestigationRow(name: trimmed));
      _investigationInput.clear();
      if (isNew) _rememberInvestigation(trimmed);
      _investigationSuggestions = List.of(_defaultInvestigationSuggestions);
    });
    if (isNew) _scheduleLearnInvestigation(trimmed, force: true);
    if (keepFocus) _investigationFocus.requestFocus();
  }

  void _removeInvestigationAt(int index) {
    if (index < 0 || index >= _investigations.length) return;
    final row = _investigations.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  int _categoryMedicineCount(String category, _MedicineContext context) {
    return _medicines
        .where((m) => m.context == context && _medicineMatchesCategory(m, category, context))
        .length;
  }

  bool _medicineMatchesCategory(
    _MedicineRow m,
    String category,
    _MedicineContext context,
  ) {
    if (m.context != context) return false;
    if (context == _MedicineContext.prescription) {
      final slug = m.prescriptionUnderCategory;
      if (slug == null) return false;
      return PrescriptionUnderCategory.forVisit(snapshot: slug) == category;
    }
    final slug = m.treatmentUnderCategory;
    if (slug == null) return false;
    return TreatmentUnderCategory.forVisit(snapshot: slug) == category;
  }

  Future<void> _loadCategoryCatalogs() async {
    await Future.wait([
      _loadTreatmentUnderCategories(),
      _loadPrescriptionUnderCategories(),
    ]);
  }

  Future<void> _loadTreatmentUnderCategories() async {
    try {
      final list = await context
          .read<AppServices>()
          .emrMasterData
          .listTreatmentUnderCategories();
      if (!mounted) return;
      setState(() => _treatmentUnderCategories = list);
      // Prefetch mapped medicines for every active tab.
      await Future.wait([
        for (final c in list) _loadMappedMedicinesFor(c.slug, _MedicineContext.treatmentUnder),
      ]);
      if (!mounted) return;
      if (_treatmentUnderTab == null && list.isNotEmpty) {
        setState(() => _treatmentUnderTab = list.first.slug);
      }
    } catch (_) {
      await Future.wait([
        for (final key in TreatmentUnderCategory.keys) _loadMappedMedicinesFor(key, _MedicineContext.treatmentUnder),
      ]);
      if (!mounted) return;
      if (_treatmentUnderTab == null) {
        setState(() => _treatmentUnderTab = TreatmentUnderCategory.antibiotics);
      }
    }
  }

  Future<void> _loadPrescriptionUnderCategories() async {
    try {
      final list = await context
          .read<AppServices>()
          .emrMasterData
          .listPrescriptionUnderCategories();
      if (!mounted) return;
      setState(() => _prescriptionUnderCategories = list);
      await Future.wait([
        for (final c in list) _loadMappedMedicinesFor(c.slug, _MedicineContext.prescription),
      ]);
      if (!mounted) return;
      if (_prescriptionTab == null && list.isNotEmpty) {
        setState(() => _prescriptionTab = list.first.slug);
      }
    } catch (_) {
      await Future.wait([
        for (final key in PrescriptionUnderCategory.keys)
          _loadMappedMedicinesFor(key, _MedicineContext.prescription),
      ]);
      if (!mounted) return;
      if (_prescriptionTab == null) {
        setState(() => _prescriptionTab = PrescriptionUnderCategory.oral);
      }
    }
  }

  List<String> _categoryKeys(_MedicineContext context) {
    if (context == _MedicineContext.prescription) {
      final keys = PrescriptionUnderCategory.keysOf(_prescriptionUnderCategories);
      return keys.isNotEmpty ? keys : PrescriptionUnderCategory.keys;
    }
    final keys = TreatmentUnderCategory.keysOf(_treatmentUnderCategories);
    return keys.isNotEmpty ? keys : TreatmentUnderCategory.keys;
  }

  String _categoryLabel(String key, _MedicineContext context) {
    if (context == _MedicineContext.prescription) {
      return PrescriptionUnderCategory.labelOf(key, _prescriptionUnderCategories);
    }
    return TreatmentUnderCategory.labelOf(key, _treatmentUnderCategories);
  }

  List<Product> _mappedForTab(String tab, _MedicineContext context) {
    final map = context == _MedicineContext.prescription
        ? _prescriptionUnderMapped
        : _treatmentUnderMapped;
    return List<Product>.from(map[tab] ?? const []);
  }

  bool _isCategoryLoading(_MedicineContext context) =>
      context == _MedicineContext.prescription
          ? _loadingPrescriptionUnderMapped
          : _loadingTreatmentUnderMapped;

  List<String> get _treatmentUnderKeys => _categoryKeys(_MedicineContext.treatmentUnder);

  String _treatmentUnderLabel(String key) =>
      _categoryLabel(key, _MedicineContext.treatmentUnder);

  List<Product> _mappedForTreatmentTab(String tab) =>
      _mappedForTab(tab, _MedicineContext.treatmentUnder);

  bool _isMappedMedicineSelected(
    Product p,
    String category,
    _MedicineContext context,
  ) {
    return _medicines.any(
      (m) =>
          m.context == context &&
          m.productId == p.id &&
          _medicineMatchesCategory(m, category, context),
    );
  }

  Future<void> _loadMappedMedicinesFor(
    String category,
    _MedicineContext section,
  ) async {
    try {
      List<Product> list = [];
      try {
        list = section == _MedicineContext.prescription
            ? await context
                .read<AppServices>()
                .emrMasterData
                .listPrescriptionUnderProducts(category: category)
            : await context
                .read<AppServices>()
                .emrMasterData
                .listTreatmentUnderProducts(category: category);
      } catch (_) {}
      if (list.isEmpty) {
        final filterKey = section == _MedicineContext.prescription
            ? 'prescription_under_category'
            : 'treatment_under_category';
        list = await context.read<AppServices>().products.list(
              query: {
                'type': 'medicine',
                'per_page': 200,
                'is_active': 1,
                filterKey: category,
              },
            );
      }
      if (!mounted) return;
      final target = section == _MedicineContext.prescription
          ? _prescriptionUnderMapped
          : _treatmentUnderMapped;
      setState(() => target[category] = list);
    } catch (_) {
      if (!mounted) return;
      if (section == _MedicineContext.prescription) {
        setState(() => _prescriptionUnderMapped[category] = []);
      } else {
        setState(() => _treatmentUnderMapped[category] = []);
      }
    }
  }

  Future<void> _selectCategoryTab(
    String category,
    _MedicineContext section,
  ) async {
    final map = section == _MedicineContext.prescription
        ? _prescriptionUnderMapped
        : _treatmentUnderMapped;
    setState(() {
      if (section == _MedicineContext.treatmentUnder) {
        _treatmentUnderTab = category;
        _loadingTreatmentUnderMapped = !map.containsKey(category);
      } else {
        _prescriptionTab = category;
        _loadingPrescriptionUnderMapped = !map.containsKey(category);
      }
    });
    if (!map.containsKey(category)) {
      await _loadMappedMedicinesFor(category, section);
    }
    if (!mounted) return;
    setState(() {
      if (section == _MedicineContext.treatmentUnder) {
        _loadingTreatmentUnderMapped = false;
      } else {
        _loadingPrescriptionUnderMapped = false;
      }
    });
  }

  void _toggleMappedMedicine(
    Product p,
    String category,
    _MedicineContext section,
  ) {
    final existing = _medicines.indexWhere(
      (m) =>
          m.context == section &&
          m.productId == p.id &&
          _medicineMatchesCategory(m, category, section),
    );
    if (existing >= 0) {
      final row = _medicines.removeAt(existing);
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
      return;
    }
    setState(() {
      if (section == _MedicineContext.treatmentUnder) {
        _treatmentUnderTab = category;
      } else {
        _prescriptionTab = category;
      }
      _medicines.add(
        _MedicineRow(
          productId: p.id,
          name: p.name,
          unitPrice: p.sellingPrice,
          treatmentUnderCategory:
              section == _MedicineContext.treatmentUnder ? category : null,
          prescriptionUnderCategory:
              section == _MedicineContext.prescription ? category : null,
          context: section,
        ),
      );
    });
  }

  Future<void> _addCategoryMedicine(
    String category,
    _MedicineContext section,
  ) async {
    final p = await _pickProduct(
      type: 'medicine',
      requiredQty: 1,
      treatmentUnderCategory:
          section == _MedicineContext.treatmentUnder ? category : null,
      prescriptionUnderCategory:
          section == _MedicineContext.prescription ? category : null,
    );
    if (p == null || !mounted) return;
    setState(() {
      if (section == _MedicineContext.treatmentUnder) {
        _treatmentUnderTab = category;
      } else {
        _prescriptionTab = category;
      }
      _medicines.add(
        _MedicineRow(
          productId: p.id,
          name: p.name,
          unitPrice: p.sellingPrice,
          treatmentUnderCategory:
              section == _MedicineContext.treatmentUnder ? category : null,
          prescriptionUnderCategory:
              section == _MedicineContext.prescription ? category : null,
          context: section,
        ),
      );
    });
    final map = section == _MedicineContext.prescription
        ? _prescriptionUnderMapped
        : _treatmentUnderMapped;
    final cached = map[category];
    if (cached != null && !cached.any((x) => x.id == p.id)) {
      setState(() => map[category] = [...cached, p]);
    }
  }

  /// Category chips + settings-mapped medicines + selected rows for the active tab.
  Widget _buildCategoryMedicineBlock({
    required bool compact,
    required String? activeTab,
    required _MedicineContext context,
    required ValueChanged<String> onSelectTab,
  }) {
    final tab = activeTab;
    final mapped = tab == null ? const <Product>[] : _mappedForTab(tab, context);
    final selectedUnder = tab == null
        ? const <MapEntry<int, _MedicineRow>>[]
        : _medicines.asMap().entries
            .where(
              (e) =>
                  e.value.context == context &&
                  _medicineMatchesCategory(e.value, tab, context),
            )
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final key in _categoryKeys(context))
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: Icon(
                      _categoryIcon(key, context),
                      size: 14,
                      color: activeTab == key
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    label: Text(
                      _categoryMedicineCount(key, context) == 0
                          ? _categoryLabel(key, context)
                          : '${_categoryLabel(key, context)} (${_categoryMedicineCount(key, context)})',
                      style: const TextStyle(fontSize: 14.5),
                    ),
                    selected: activeTab == key,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(
                      color: activeTab == key
                          ? AppTheme.primary
                          : const Color(0xFFCBD5E1),
                    ),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.12),
                    backgroundColor: Colors.white,
                    onSelected: (_) => onSelectTab(key),
                  ),
                ),
            ],
          ),
        ),
        if (tab != null) ...[
          const SizedBox(height: 8),
          if (_isCategoryLoading(context))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (mapped.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'No medicines mapped to ${_categoryLabel(tab, context).toLowerCase()} in settings',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in mapped)
                    FilterChip(
                      label: Text(p.name, style: const TextStyle(fontSize: 12)),
                      selected: _isMappedMedicineSelected(p, tab, context),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) => _toggleMappedMedicine(p, tab, context),
                    ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addCategoryMedicine(tab, context),
              icon: const Icon(Icons.search, size: 16),
              label: Text(
                'Browse ${_categoryLabel(tab, context).toLowerCase()}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Tap a category to see mapped medicines',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.5),
            ),
          ),
        ...selectedUnder.map(
          (e) => _buildMedicineCard(
            index: e.key,
            compact: compact,
            treatmentUnderCategory:
                context == _MedicineContext.treatmentUnder ? tab : null,
            prescriptionUnderCategory:
                context == _MedicineContext.prescription ? tab : null,
          ),
        ),
      ],
    );
  }

  Future<Product?> _pickProduct({
    String? initial,
    String type = 'product', // product | service | medicine
    bool allowCreateService = false,
    double? requiredQty,
    String? treatmentUnderCategory,
    String? prescriptionUnderCategory,
  }) {
    if (!mounted) return Future.value(null);
    return showAppDialog<Product>(
      context: context,
      builder: (ctx) => _ProductPickerDialog(
        type: type,
        initialQuery: initial,
        allowCreateService: allowCreateService,
        requiredQty: requiredQty,
        treatmentUnderCategory: treatmentUnderCategory,
        prescriptionUnderCategory: prescriptionUnderCategory,
      ),
    );
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

    // Commit any in-progress complaint term, then learn new EMR suggestions.
    final pendingComplaint = _complaintSearchTerm(_complaint.text);
    if (pendingComplaint.isNotEmpty &&
        !_complaint.text.trimRight().endsWith(',')) {
      _commitComplaintTerm();
    }
    await _persistAllNewEmrTerms();

    return <String, dynamic>{
      'pet_id': _selectedPet!.id,
      if (_selectedDoctor != null) 'doctor_id': _selectedDoctor!.id,
      'visit_type': _visitType,
      'visit_date': _formatYmd(_visitDate),
      'visit_time': timeStr,
      'service_charge': serviceCharge,
      if (serviceCharge > 0 && _serviceChargeProductId != null)
        'service_charge_product_id': _serviceChargeProductId,
      if (_complaintForApi.isNotEmpty) 'chief_complaint': _complaintForApi,
      if (_clinicalNotes.text.trim().isNotEmpty)
        'clinical_notes': _clinicalNotes.text.trim(),
      if (_isEdit || _investigations.isNotEmpty)
        'investigation':
            VisitInvestigationItem.encode(_investigations.map((e) => e.toItem())) ??
                '',
      if (_followUpNotes.text.trim().isNotEmpty)
        'follow_up_notes': _followUpNotes.text.trim(),
      if (_temperatureF != null)
        'temperature': _fahrenheitToCelsius(_temperatureF!),
      if (_weightKg != null) 'weight': _weightKg,
      if (_heartRateBpm != null) 'heart_rate': _heartRateBpm,
      if (_respiratoryRatePerMin != null)
        'respiratory_rate': _respiratoryRatePerMin,
      if (_followUpDate != null)
        'follow_up_date': _formatYmd(_followUpDate!),
      // Always send child collections on edit so removals sync; on create only
      // when non-empty.
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
    _complaintLearnDebounce?.cancel();
    _investigationLearnDebounce?.cancel();
    _complaint.dispose();
    _clinicalNotes.dispose();
    _investigationInput.dispose();
    _followUpNotes.dispose();
    _investigationFocus.dispose();
    _serviceCharge.dispose();
    for (final row in _investigations) {
      row.dispose();
    }
    for (final t in _treatments) {
      t.dispose();
    }
    for (final m in _medicines) {
      m.dispose();
    }
    for (final v in _vaccinations) {
      v.dispose();
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

    final compact = _compactUi;
    final listPadding = compact
        ? EdgeInsets.fromLTRB(
            12,
            10,
            12,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          )
        : const EdgeInsets.fromLTRB(14, 10, 14, 14);

    // Desktop uses a global 1.35× text scale — cap this dense clinical form
    // so fields and tabs fit like the screenshot layout.
    final media = MediaQuery.of(context);
    final baseScale = media.textScaler.scale(1);
    final formScale = AppConfig.usesLargeUiScale
        ? (baseScale / AppConfig.desktopTextScale).clamp(0.9, 1.0)
        : baseScale.clamp(0.9, 1.05);

    final denseTheme = Theme.of(context).copyWith(
      visualDensity: VisualDensity.compact,
      textTheme: Theme.of(context).textTheme.copyWith(
            titleLarge: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
            titleSmall: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
            bodyMedium: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                ),
            bodySmall: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 14.5,
                ),
            labelLarge: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
          ),
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            hintStyle: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
            ),
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
            floatingLabelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
      chipTheme: Theme.of(context).chipTheme.copyWith(
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            secondaryLabelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          ),
    );

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(formScale)),
      child: Theme(
        data: denseTheme,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 12,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit visit' : 'New visit',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.15,
                  ),
                ),
                Text(
                  _isEdit
                      ? 'Update the details of this visit'
                      : 'Create a new visit record',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () => navigateShellBack(
                  context,
                  GoRouterState.of(context).uri.path,
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text(
                  'Back to visits',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: listPadding,
            children: [
              _buildVisitFormBody(compact: compact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisitFormBody({required bool compact}) {
    // Body content continues with the previous ListView children.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = compact || constraints.maxWidth < 640;
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
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Clear patient',
                                onPressed: () {
                                  setState(() {
                                    _selectedPet = null;
                                    _petSummary = null;
                                    _defaultVaccinationSuggestions = [];
                                    _vaccinationSuggestions = [];
                                    _vaccinationSuggestForIndex = null;
                                  });
                                },
                              ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pets, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedPet!.displayLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

              final visitTypeField = AppDropdownButtonFormField<String>(
                value: _visitType,
                isExpanded: true,
                isDense: true,
                alignment: AlignmentDirectional.centerStart,
                decoration: const InputDecoration(
                  labelText: 'Visit type',
                  contentPadding: EdgeInsets.fromLTRB(12, 18, 12, 18),
                ),
                selectedItemBuilder: (context) => _visitTypes
                    .map(
                      (t) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          t,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                items: _visitTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textPrimary,
                          ),
                        ),
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
          const SizedBox(height: 12),
          _formSectionHeader(
            'Chief complaint',
            Icons.chat_bubble_outline_rounded,
          ),
          const SizedBox(height: 6),
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
              onChanged: _onComplaintChanged,
              onSubmitted: _commitComplaintTerm,
            ),
          ),
          if (_complaintSuggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Quick add',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _complaintSuggestions.take(12).map((c) {
                return ActionChip(
                  avatar: const Icon(
                    Icons.add,
                    size: 14,
                    color: AppTheme.primaryDark,
                  ),
                  label: Text(
                    c,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  labelStyle: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: const Color(0xFFEFF6FF),
                  surfaceTintColor: Colors.transparent,
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  onPressed: () => _applyComplaintSuggestion(c),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          _formSectionHeader('Vitals', Icons.monitor_heart_outlined),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = compact || constraints.maxWidth < 520;
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
          const SizedBox(height: 12),
          _formSectionHeader('Investigation', Icons.biotech_outlined),
          const SizedBox(height: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _investigationFocus.requestFocus(),
            child: InputDecorator(
              isFocused: _investigationFocus.hasFocus,
              isEmpty:
                  _investigations.isEmpty && _investigationInput.text.isEmpty,
              decoration: InputDecoration(
                hintText: _investigations.isEmpty
                    ? 'Search, pick, or type & press Enter'
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              child: TextField(
                controller: _investigationInput,
                focusNode: _investigationFocus,
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
                  hintText: _investigations.isEmpty
                      ? null
                      : 'Add another…',
                ),
                onChanged: (v) {
                  setState(() {});
                  _onInvestigationChanged(v);
                },
                onSubmitted: _addInvestigation,
              ),
            ),
          ),
          if (_openSuggestField == 'investigation' &&
              _investigationSuggestions.any(
                (s) => !_investigations.any(
                  (sel) => sel.name.toLowerCase() == s.toLowerCase(),
                ),
              ))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _investigationSuggestions
                    .where(
                      (s) => !_investigations.any(
                        (sel) => sel.name.toLowerCase() == s.toLowerCase(),
                      ),
                    )
                    .take(12)
                    .map((c) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _selectInvestigationSuggestion(c),
                    child: Chip(
                      label: Text(
                        c,
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }).toList(),
              ),
            ),
          if (_investigations.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Pick an investigation, then add notes against it',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            )
          else
            ..._investigations.asMap().entries.map((e) {
              final i = e.key;
              final row = e.value;
              return Card(
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          row.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: TextField(
                            controller: row.notesCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              isDense: true,
                            ),
                            minLines: 1,
                            maxLines: 3,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: const Icon(Icons.close, color: AppTheme.danger),
                        onPressed: () => _removeInvestigationAt(i),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          _responsiveSectionHeader(
            title: _formSectionHeader(
              'Treatments',
              Icons.all_inclusive_rounded,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Billable',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: _addProcedureKit,
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add kit',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildCategoryMedicineBlock(
            compact: compact,
            activeTab: _treatmentUnderTab,
            context: _MedicineContext.treatmentUnder,
            onSelectTab: (key) =>
                _selectCategoryTab(key, _MedicineContext.treatmentUnder),
          ),
          if (_treatments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Add kit: insert all kit products as billable treatment lines',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.5),
              ),
            ),
          ..._treatments.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            final showSuggestions =
                _treatmentSuggestForIndex == i && _treatmentSuggestions.isNotEmpty;
            final nameField = Focus(
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
            );
            final priceField = TextField(
              decoration: const InputDecoration(
                labelText: 'Price (₹)',
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              controller: t.priceCtrl,
            );
            final linkBtn = IconButton(
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
            );
            final removeBtn = IconButton(
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
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: nameField),
                                  linkBtn,
                                  removeBtn,
                                ],
                              ),
                              const SizedBox(height: 8),
                              priceField,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: nameField),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: priceField),
                              linkBtn,
                              removeBtn,
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
          const SizedBox(height: 12),
          _responsiveSectionHeader(
            title: _formSectionHeader(
              'Prescriptions',
              Icons.medication_outlined,
            ),
            actions: [
              TextButton.icon(
                onPressed: () => setState(
                  () => _medicines.add(
                    _MedicineRow(context: _MedicineContext.freeForm),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildCategoryMedicineBlock(
            compact: compact,
            activeTab: _prescriptionTab,
            context: _MedicineContext.prescription,
            onSelectTab: (key) =>
                _selectCategoryTab(key, _MedicineContext.prescription),
          ),
          if (!_medicines.any((m) => m.context == _MedicineContext.freeForm))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Or tap Add for a free-form prescription',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14.5),
              ),
            ),
          ..._medicines.asMap().entries
              .where((e) => e.value.context == _MedicineContext.freeForm)
              .map((e) {
            return _buildMedicineCard(
              index: e.key,
              compact: compact,
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
          const SizedBox(height: 12),
          _formSectionHeader('Follow-up', Icons.event_outlined),
          const SizedBox(height: 6),
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
                ? _formatYmd(_followUpDate!)
                : 'Set follow-up date'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _followUpNotes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Follow-up instructions'),
          ),
          const SizedBox(height: 24),
          if (compact) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _hold,
                icon: const Icon(Icons.pause_circle_outline, size: 20),
                label: const Text('Hold'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
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
          ] else
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
    );
  }

  Widget _formSectionHeader(
    String title,
    IconData icon, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: AppTheme.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  IconData _categoryIcon(String key, _MedicineContext context) {
    if (context == _MedicineContext.prescription) {
      switch (key) {
        case PrescriptionUnderCategory.oral:
          return Icons.medication_liquid_outlined;
        case PrescriptionUnderCategory.topical:
          return Icons.spa_outlined;
        case PrescriptionUnderCategory.injectable:
          return Icons.vaccines_outlined;
        case PrescriptionUnderCategory.supplements:
          return Icons.eco_outlined;
        case PrescriptionUnderCategory.chronic:
          return Icons.schedule_outlined;
        case PrescriptionUnderCategory.unique:
          return Icons.star_outline_rounded;
        default:
          return Icons.category_outlined;
      }
    }
    return _treatmentUnderIcon(key);
  }

  IconData _treatmentUnderIcon(String key) {
    switch (key) {
      case TreatmentUnderCategory.antibiotics:
        return Icons.shield_outlined;
      case TreatmentUnderCategory.fluids:
        return Icons.water_drop_outlined;
      case TreatmentUnderCategory.nsaids:
        return Icons.medication_outlined;
      case TreatmentUnderCategory.supportive:
        return Icons.health_and_safety_outlined;
      case TreatmentUnderCategory.anesthetics:
        return Icons.vaccines_outlined;
      case TreatmentUnderCategory.unique:
        return Icons.star_outline_rounded;
      default:
        return Icons.category_outlined;
    }
  }

  Widget _responsiveSectionHeader({
    required Widget title,
    List<Widget> actions = const [],
  }) {
    if (actions.isEmpty) return title;
    if (!_compactUi) {
      return Row(
        children: [
          Expanded(child: title),
          ...actions,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 4),
        Wrap(spacing: 4, runSpacing: 4, children: actions),
      ],
    );
  }

  Widget _buildMedicineCard({
    required int index,
    required bool compact,
    String? treatmentUnderCategory,
    String? prescriptionUnderCategory,
  }) {
    final m = _medicines[index];
    final showMedicineSuggestions =
        _medicineSuggestForIndex == index && _medicineSuggestions.isNotEmpty;
    final nameField = Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _showMedicineSuggestionsFor(index);
        } else {
          Future.delayed(const Duration(milliseconds: 180), () {
            if (!mounted) return;
            _clearMedicineSuggestions(onlyIfIndex: index);
          });
        }
      },
      child: TextField(
        decoration: const InputDecoration(
          labelText: 'Medicine name',
          isDense: true,
        ),
        controller: m.nameCtrl,
        onChanged: (q) => _searchMedicines(q, forIndex: index),
      ),
    );
    final priceField = TextField(
      decoration: const InputDecoration(
        labelText: 'Price (₹)',
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      controller: m.priceCtrl,
    );
    final linkBtn = IconButton(
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
          treatmentUnderCategory: treatmentUnderCategory,
          prescriptionUnderCategory: prescriptionUnderCategory,
        );
        if (p != null) {
          setState(() {
            m.productId = p.id;
            m.nameCtrl.text = p.name;
            m.priceCtrl.text = _formatAmount(p.sellingPrice);
            if (treatmentUnderCategory != null) {
              m.treatmentUnderCategory = treatmentUnderCategory;
            }
            if (prescriptionUnderCategory != null) {
              m.prescriptionUnderCategory = prescriptionUnderCategory;
            }
          });
        }
      },
    );
    final removeBtn = IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: const Icon(Icons.close, color: AppTheme.danger),
      onPressed: () {
        final row = _medicines.removeAt(index);
        _clearMedicineSuggestions();
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
      },
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _medicineFieldsLayout(
              compact: compact,
              nameField: nameField,
              priceField: priceField,
              linkBtn: linkBtn,
              removeBtn: removeBtn,
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
                          label: Text(s.name,
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              m.nameCtrl.text = s.name;
                              if (s.defaultFrequency != null &&
                                  m.freqCtrl.text.isEmpty) {
                                m.freqCtrl.text = s.defaultFrequency!;
                              }
                              if (s.defaultDurationDays != null &&
                                  m.durationDays == null) {
                                m.durationDays =
                                    s.defaultDurationDays!.clamp(1, 15);
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
          ],
        ),
      ),
    );
  }

  /// Desktop: name + price in one row. Mobile stacks price under name.
  Widget _medicineFieldsLayout({
    required bool compact,
    required Widget nameField,
    required Widget priceField,
    required Widget linkBtn,
    required Widget removeBtn,
  }) {
    if (!compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: nameField),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: priceField),
          linkBtn,
          removeBtn,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: nameField),
            linkBtn,
            removeBtn,
          ],
        ),
        const SizedBox(height: 8),
        priceField,
      ],
    );
  }

  Widget _nextDueButton({
    required DateTime? date,
    required Future<void> Function() onPick,
    IconData icon = Icons.notifications_active_outlined,
  }) {
    String label = 'Set next due (reminder)';
    if (date != null) {
      final days = DateTime(date.year, date.month, date.day)
          .difference(DateTime(_visitDate.year, _visitDate.month, _visitDate.day))
          .inDays;
      label = days > 0
          ? 'Next due ${_formatYmd(date)} ($days days)'
          : 'Next due ${_formatYmd(date)}';
    }
    final filled = date != null;
    final button = OutlinedButton.icon(
      onPressed: onPick,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: filled ? const Color(0xFF047857) : const Color(0xFF2563EB),
        side: BorderSide(
          color: filled ? const Color(0xFF6EE7B7) : const Color(0xFFBFDBFE),
        ),
        backgroundColor: filled ? const Color(0xFFECFDF5) : null,
      ),
    );
    if (!_compactUi) {
      return Align(alignment: Alignment.centerLeft, child: button);
    }
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _sectionHeader(String title, VoidCallback onAdd) {
    final icon = switch (title) {
      'Vaccinations' => Icons.vaccines_outlined,
      'Deworming' => Icons.bug_report_outlined,
      'Surgery' => Icons.local_hospital_outlined,
      _ => Icons.medical_services_outlined,
    };
    return _responsiveSectionHeader(
      title: _formSectionHeader(title, icon),
      actions: [
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: const Text(
            'Add',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Future<DateTime?> _pickDueDate(DateTime? current) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final currentDate = current == null
        ? null
        : DateTime(current.year, current.month, current.day);
    final initial = currentDate ?? todayDate.add(const Duration(days: 30));
    final first = currentDate != null && currentDate.isBefore(todayDate)
        ? currentDate
        : todayDate;
    return showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(2100),
    );
  }

  Widget _buildVaccinationSection() {
    final species = _petVaccinationSpecies;
    final selected = _vaccinations.asMap().entries.where((e) {
      if (_vaccinationTab == null) return true;
      return _rowCategory(e.value) == _vaccinationTab;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Vaccinations', _addCustomVaccination),
        Text(
          species == null
              ? 'Select a pet to load that species vaccination list from EMR'
              : 'Tap a category to pick vaccines from EMR master data',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final key in VaccinationCategory.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      _vaccinationCount(key) == 0
                          ? VaccinationCategory.labelOf(key)
                          : '${VaccinationCategory.labelOf(key)} (${_vaccinationCount(key)})',
                      style: const TextStyle(fontSize: 14.5),
                    ),
                    selected: _vaccinationTab == key,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(
                      color: _vaccinationTab == key
                          ? AppTheme.primary
                          : const Color(0xFFCBD5E1),
                    ),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.12),
                    backgroundColor: Colors.white,
                    onSelected: (_) async {
                      setState(() {
                        _vaccinationTab = key;
                        _vaccinationSuggestForIndex = null;
                        _vaccinationSuggestions = [];
                      });
                      await _pickVaccinationFromEmr(key);
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (selected.isEmpty)
          Text(
            _vaccinationTab == null
                ? 'No vaccines selected'
                : 'No ${VaccinationCategory.labelOf(_vaccinationTab)} selected',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          )
        else
          ...selected.map((e) => _selectedVaccinationTile(e.key, e.value)),
      ],
    );
  }

  Widget _selectedVaccinationTile(int i, _VaccinationRow row) {
    final fromList = row.template != null;
    final days = row.template?.durationDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: fromList
                      ? Text(
                          row.nameCtrl.text,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Focus(
                          onFocusChange: (hasFocus) {
                            if (hasFocus) {
                              _showVaccinationSuggestionsFor(i);
                            } else {
                              final match = _templateForName(row.nameCtrl.text);
                              if (match != null) {
                                setState(() => _applyVaccineTemplate(row, match));
                              }
                              Future.delayed(const Duration(milliseconds: 180), () {
                                if (!mounted) return;
                                _clearVaccinationSuggestions(onlyIfIndex: i);
                              });
                            }
                          },
                          child: TextField(
                            controller: row.nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Vaccine name *',
                              isDense: true,
                            ),
                            onChanged: (q) {
                              final match = _templateForName(q);
                              if (match != null) {
                                setState(() {
                                  _applyVaccineTemplate(row, match);
                                  _vaccinationSuggestForIndex = null;
                                  _vaccinationSuggestions = [];
                                });
                                return;
                              }
                              _showVaccinationSuggestionsFor(i, query: q);
                            },
                            onSubmitted: (v) {
                              final match = _templateForName(v);
                              if (match != null) {
                                setState(() {
                                  _applyVaccineTemplate(row, match);
                                  _vaccinationSuggestForIndex = null;
                                  _vaccinationSuggestions = [];
                                });
                              }
                            },
                          ),
                        ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => setState(() => _removeVaccinationAt(i)),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            if (!fromList &&
                _vaccinationSuggestForIndex == i &&
                _vaccinationSuggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _vaccinationSuggestions.map((s) {
                    return Listener(
                      onPointerDown: (_) {
                        setState(() {
                          _applyVaccineTemplate(row, s);
                          _vaccinationSuggestForIndex = null;
                          _vaccinationSuggestions = [];
                        });
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      child: Chip(
                        label: Text(s.name, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 8),
            if (row.nextDueDate != null)
              Text(
                days != null
                    ? 'Next reminder ${_formatYmd(row.nextDueDate!)} ($days days)'
                    : 'Next reminder ${_formatYmd(row.nextDueDate!)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF047857),
                ),
              )
            else
              _nextDueButton(
                date: row.nextDueDate,
                icon: Icons.notifications_active_outlined,
                onPick: () async {
                  final d = await _pickDueDate(row.nextDueDate);
                  if (d != null) {
                    setState(() {
                      row.nextDueDate = d;
                      row.nextDueManual = true;
                    });
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

String _formatYmd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String _formatAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

class _VaccinationTemplatePickerDialog extends StatefulWidget {
  const _VaccinationTemplatePickerDialog({
    required this.category,
    required this.templates,
    required this.selectedIds,
  });

  final String category;
  final List<VaccinationTemplate> templates;
  final Set<int> selectedIds;

  @override
  State<_VaccinationTemplatePickerDialog> createState() =>
      _VaccinationTemplatePickerDialogState();
}

class _VaccinationTemplatePickerDialogState
    extends State<_VaccinationTemplatePickerDialog> {
  late final TextEditingController _search;
  late List<VaccinationTemplate> _filtered;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _filtered = List<VaccinationTemplate>.from(widget.templates);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applyFilter(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      if (lower.isEmpty) {
        _filtered = List<VaccinationTemplate>.from(widget.templates);
      } else {
        _filtered = widget.templates
            .where((t) => t.name.toLowerCase().contains(lower))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Pick ${VaccinationCategory.labelOf(widget.category)}',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search EMR vaccines…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: _applyFilter,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching vaccines in EMR master data',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final t = _filtered[i];
                        final already = widget.selectedIds.contains(t.id);
                        return ListTile(
                          dense: true,
                          enabled: !already,
                          title: Text(
                            t.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: already ? AppTheme.textSecondary : null,
                            ),
                          ),
                          subtitle: Text(
                            already
                                ? 'Already added'
                                : [
                                    t.speciesLabel,
                                    if (t.durationDays != null)
                                      'Next due ${t.durationDays}d',
                                    if (t.nextDoseNumber > 1)
                                      'Dose ${t.nextDoseNumber}',
                                  ].join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: already
                              ? const Icon(Icons.check, color: AppTheme.accent)
                              : const Icon(Icons.add_circle_outline),
                          onTap: already
                              ? null
                              : () => Navigator.of(context).pop(t),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ProductPickerDialog extends StatefulWidget {
  const _ProductPickerDialog({
    required this.type,
    this.initialQuery,
    this.allowCreateService = false,
    this.requiredQty,
    this.treatmentUnderCategory,
    this.prescriptionUnderCategory,
  });

  final String type;
  final String? initialQuery;
  final bool allowCreateService;
  final double? requiredQty;
  final String? treatmentUnderCategory;
  final String? prescriptionUnderCategory;

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
              if (widget.treatmentUnderCategory != null)
                'treatment_under_category': widget.treatmentUnderCategory,
              if (widget.prescriptionUnderCategory != null)
                'prescription_under_category': widget.prescriptionUnderCategory,
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
            if (widget.treatmentUnderCategory != null)
              'treatment_under_category': widget.treatmentUnderCategory,
            if (widget.prescriptionUnderCategory != null)
              'prescription_under_category': widget.prescriptionUnderCategory,
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
      'medicine' => widget.treatmentUnderCategory != null
          ? 'Link a ${TreatmentUnderCategory.labelOf(widget.treatmentUnderCategory).toLowerCase()} medicine'
          : 'Link inventory so stock and billing stay in sync',
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
                ? (widget.treatmentUnderCategory != null
                    ? 'No ${TreatmentUnderCategory.labelOf(widget.treatmentUnderCategory).toLowerCase()} medicines mapped yet'
                    : 'No medicine products in catalog')
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
    this.nextDueDate,
    this.templateId,
    this.doseNumber = 1,
    this.template,
    this.status = 'completed',
    this.administeredDate,
    this.category,
  }) : nameCtrl = TextEditingController(text: name);

  factory _VaccinationRow.fromModel(PetVaccination v) => _VaccinationRow(
        name: v.vaccineName,
        nextDueDate: v.nextDueDate != null ? DateTime.tryParse(v.nextDueDate!) : null,
        templateId: v.vaccinationTemplateId,
        doseNumber: v.doseNumber ?? 1,
        status: v.status,
        administeredDate: DateTime.tryParse(v.administeredDate),
        category: VaccinationCategory.forVisit(
          snapshot: v.category,
          name: v.vaccineName,
        ),
      );

  final TextEditingController nameCtrl;
  DateTime? nextDueDate;
  int? templateId;
  int doseNumber;
  VaccinationTemplate? template;
  bool nextDueManual = false;
  String status;
  DateTime? administeredDate;
  String? category;

  Map<String, dynamic> toJson() => {
        'vaccine_name': nameCtrl.text.trim(),
        if (category != null && category!.isNotEmpty) 'category': category,
        if (templateId != null) 'vaccination_template_id': templateId,
        'dose_number': doseNumber,
        'status': status,
        if (administeredDate != null)
          'administered_date': _formatYmd(administeredDate!),
        if (nextDueDate != null) 'next_due_date': _formatYmd(nextDueDate!),
        'reminder_days_before': template?.reminderDaysBefore ?? 7,
      };

  void dispose() {
    nameCtrl.dispose();
  }
}

class _InvestigationRow {
  _InvestigationRow({required this.name, String notes = ''})
      : notesCtrl = TextEditingController(text: notes);

  factory _InvestigationRow.fromItem(VisitInvestigationItem item) =>
      _InvestigationRow(name: item.name, notes: item.notes);

  final String name;
  final TextEditingController notesCtrl;

  VisitInvestigationItem toItem() => VisitInvestigationItem(
        name: name,
        notes: notesCtrl.text,
      );

  void dispose() {
    notesCtrl.dispose();
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
    this.treatmentUnderCategory,
    this.prescriptionUnderCategory,
    this.context = _MedicineContext.freeForm,
  })  : durationDays = durationDays?.clamp(1, 15),
        quantity = quantity.clamp(1, 20),
        nameCtrl = TextEditingController(text: name),
        dosageCtrl = TextEditingController(text: dosage),
        freqCtrl = TextEditingController(text: frequency),
        priceCtrl = TextEditingController(text: unitPrice.toString());

  factory _MedicineRow.fromModel(VisitMedicine m) {
    final tuRaw = m.treatmentUnderCategory ?? m.product?.treatmentUnderCategory;
    final puRaw = m.prescriptionUnderCategory ?? m.product?.prescriptionUnderCategory;
    final hasTu = tuRaw != null && tuRaw.isNotEmpty;
    final hasPu = puRaw != null && puRaw.isNotEmpty;
    return _MedicineRow(
      productId: m.productId,
      name: m.medicineName,
      dosage: m.dosage ?? '',
      frequency: m.frequency ?? '',
      durationDays: m.durationDays,
      quantity: m.quantity.round(),
      unitPrice: m.unitPrice,
      treatmentUnderCategory: hasTu ? tuRaw : null,
      prescriptionUnderCategory: hasPu ? puRaw : null,
      context: hasPu
          ? _MedicineContext.prescription
          : hasTu
              ? _MedicineContext.treatmentUnder
              : _MedicineContext.freeForm,
    );
  }

  int? productId;
  String? treatmentUnderCategory;
  String? prescriptionUnderCategory;
  _MedicineContext context;
  int? durationDays;
  int quantity;
  final TextEditingController nameCtrl;
  final TextEditingController dosageCtrl;
  final TextEditingController freqCtrl;
  final TextEditingController priceCtrl;

  Map<String, dynamic> toJson() => {
        if (productId != null) 'product_id': productId,
        'medicine_name': nameCtrl.text.trim(),
        if (treatmentUnderCategory != null)
          'treatment_under_category': treatmentUnderCategory,
        if (prescriptionUnderCategory != null)
          'prescription_under_category': prescriptionUnderCategory,
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
