import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/investigation_under.dart';
import '../models/product.dart';
import '../models/prescription_under.dart';
import '../models/treatment_under.dart';
import '../models/vaccination_category.dart';

class EmrTemplateItem {
  EmrTemplateItem({
    required this.id,
    this.name,
    this.label,
    this.icdCode,
    this.procedureCode,
    this.defaultPrice,
    this.category,
    this.defaultDosage,
    this.defaultFrequency,
    this.defaultDurationDays,
    this.days,
    this.isActive = true,
  });

  final int id;
  final String? name;
  final String? label;
  final String? icdCode;
  final String? procedureCode;
  final double? defaultPrice;
  final String? category;
  final String? defaultDosage;
  final String? defaultFrequency;
  final int? defaultDurationDays;
  final int? days;
  final bool isActive;

  String get displayName => name ?? label ?? '';

  factory EmrTemplateItem.fromJson(Map<String, dynamic> json) => EmrTemplateItem(
        id: json['id'] is num
            ? (json['id'] as num).toInt()
            : int.tryParse(json['id']?.toString() ?? '') ?? 0,
        name: json['name']?.toString(),
        label: json['label']?.toString(),
        icdCode: json['icd_code']?.toString(),
        procedureCode: json['procedure_code']?.toString(),
        defaultPrice: json['default_price'] != null
            ? double.tryParse(json['default_price'].toString())
            : null,
        category: json['category']?.toString(),
        defaultDosage: json['default_dosage']?.toString(),
        defaultFrequency: json['default_frequency']?.toString(),
        defaultDurationDays: json['default_duration_days'] != null
            ? int.tryParse(json['default_duration_days'].toString())
            : null,
        days: json['days'] != null ? int.tryParse(json['days'].toString()) : null,
        isActive: json['is_active'] != false,
      );
}

class TreatmentSuggestion {
  TreatmentSuggestion({
    required this.name,
    this.procedureCode,
    this.defaultPrice,
    this.category,
  });

  final String name;
  final String? procedureCode;
  final double? defaultPrice;
  final String? category;

  factory TreatmentSuggestion.fromJson(Map<String, dynamic> json) => TreatmentSuggestion(
        name: json['name']?.toString() ?? '',
        procedureCode: json['procedure_code']?.toString(),
        defaultPrice: json['default_price'] != null
            ? double.tryParse(json['default_price'].toString())
            : null,
        category: json['category']?.toString(),
      );
}

/// Procedure kit that expands into multiple visit treatment lines.
class ProcedureKit {
  ProcedureKit({
    required this.id,
    required this.name,
    this.procedureCode,
    this.defaultPrice,
    this.notes,
    this.isActive = true,
    this.itemsCount = 0,
    this.itemsTotal = 0,
    this.items = const [],
  });

  final int id;
  final String name;
  final String? procedureCode;
  final double? defaultPrice;
  final String? notes;
  final bool isActive;
  final int itemsCount;
  final double itemsTotal;
  final List<ProcedureKitItem> items;

  factory ProcedureKit.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ProcedureKit(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      procedureCode: json['procedure_code']?.toString(),
      defaultPrice: json['default_price'] != null
          ? double.tryParse(json['default_price'].toString())
          : null,
      notes: json['notes']?.toString(),
      isActive: json['is_active'] != false,
      itemsCount: (json['items_count'] as num?)?.toInt() ??
          (rawItems is List ? rawItems.length : 0),
      itemsTotal: json['items_total'] != null
          ? (double.tryParse(json['items_total'].toString()) ?? 0)
          : 0,
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => ProcedureKitItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class ProcedureKitItem {
  ProcedureKitItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.treatmentName,
    this.procedureCode,
    this.productName,
    this.unitPriceOverride,
  });

  final int productId;
  final double quantity;
  final double unitPrice;
  final String treatmentName;
  final String? procedureCode;
  final String? productName;
  final double? unitPriceOverride;

  Map<String, dynamic> toBody() => {
        'product_id': productId,
        'quantity': quantity,
        if (unitPriceOverride != null) 'unit_price_override': unitPriceOverride,
      };

  factory ProcedureKitItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    final productMap = product is Map ? Map<String, dynamic>.from(product) : null;
    return ProcedureKitItem(
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ??
          (json['unit_price_override'] as num?)?.toDouble() ??
          (productMap?['selling_price'] as num?)?.toDouble() ??
          0,
      treatmentName: json['treatment_name']?.toString() ??
          productMap?['name']?.toString() ??
          '',
      procedureCode: json['procedure_code']?.toString(),
      productName: productMap?['name']?.toString(),
      unitPriceOverride: json['unit_price_override'] != null
          ? double.tryParse(json['unit_price_override'].toString())
          : null,
    );
  }
}

class VaccinationTemplate {
  VaccinationTemplate({
    required this.id,
    required this.name,
    required this.species,
    this.category = VaccinationCategory.annual,
    this.scheduleType = 'booster',
    this.nextDueDays,
    this.doseDays = const [],
    this.reminderDaysBefore = 7,
    this.nextDoseNumber = 1,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String species;
  final String category;
  final String scheduleType;
  final int? nextDueDays;
  final List<int> doseDays;
  final int reminderDaysBefore;
  final int nextDoseNumber;
  final bool isActive;

  bool get isCourse => scheduleType == 'course';
  int get totalDoses => isCourse ? (doseDays.isEmpty ? 1 : doseDays.length) : 1;

  String get speciesLabel => species == 'cat' ? 'Cat' : 'Dog';

  String get categoryLabel => VaccinationCategory.labelOf(category);

  /// Duration used to set the next reminder on the visit form.
  int? get durationDays {
    if (nextDueDays != null && nextDueDays! > 0) return nextDueDays;
    if (isCourse && doseDays.length >= 2) {
      final gap = doseDays[1] - doseDays[0];
      if (gap > 0) return gap;
    }
    return null;
  }

  String get scheduleLabel {
    final days = durationDays;
    if (days != null) return 'Every ${days}d';
    if (isCourse) return 'Days ${doseDays.join(', ')}';
    return 'Booster';
  }

  DateTime? nextDueDate({required DateTime givenOn, int doseNumber = 1}) {
    final given = DateTime(givenOn.year, givenOn.month, givenOn.day);
    final days = durationDays;
    if (days == null) return null;
    return given.add(Duration(days: days));
  }

  /// Planned date for [targetDoseNumber] when [givenDoseNumber] is given on [givenOn].
  DateTime? courseDoseDate({
    required DateTime givenOn,
    required int givenDoseNumber,
    required int targetDoseNumber,
  }) {
    if (!isCourse || doseDays.length < 2) return null;
    if (targetDoseNumber <= givenDoseNumber) return null;
    final gi = (givenDoseNumber - 1).clamp(0, doseDays.length - 1);
    final ti = (targetDoseNumber - 1).clamp(0, doseDays.length - 1);
    if (ti <= gi) return null;
    final gap = doseDays[ti] - doseDays[gi];
    if (gap <= 0) return null;
    final given = DateTime(givenOn.year, givenOn.month, givenOn.day);
    return given.add(Duration(days: gap));
  }

  static String? normalizeSpecies(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    if (s.isEmpty) return null;
    if (s.contains('dog') || s == 'canine') return 'dog';
    if (s.contains('cat') || s == 'feline') return 'cat';
    return null;
  }

  factory VaccinationTemplate.fromJson(Map<String, dynamic> json) {
    final rawDays = json['dose_days'];
    final days = <int>[];
    if (rawDays is List) {
      for (final d in rawDays) {
        final n = intOrNull(d);
        if (n != null) days.add(n);
      }
    }
    final name = json['name']?.toString() ?? '';
    return VaccinationTemplate(
      id: intOrNull(json['id']) ?? 0,
      name: name,
      species: json['species']?.toString() ?? 'dog',
      category: VaccinationCategory.forVisit(
        snapshot: json['category']?.toString(),
        name: name,
      ),
      scheduleType: json['schedule_type']?.toString() ?? 'booster',
      nextDueDays: intOrNull(json['next_due_days']),
      doseDays: days,
      reminderDaysBefore: intOrNull(json['reminder_days_before']) ?? 7,
      nextDoseNumber: intOrNull(json['next_dose_number']) ?? 1,
      isActive: json['is_active'] != false,
    );
  }
}

class MedicineSuggestion {
  MedicineSuggestion({
    required this.name,
    this.defaultDosage,
    this.defaultFrequency,
    this.defaultDurationDays,
  });

  final String name;
  final String? defaultDosage;
  final String? defaultFrequency;
  final int? defaultDurationDays;

  factory MedicineSuggestion.fromJson(Map<String, dynamic> json) => MedicineSuggestion(
        name: json['name']?.toString() ?? '',
        defaultDosage: json['default_dosage']?.toString(),
        defaultFrequency: json['default_frequency']?.toString(),
        defaultDurationDays: json['default_duration_days'] != null
            ? int.tryParse(json['default_duration_days'].toString())
            : null,
      );
}

class EmrMasterDataService {
  EmrMasterDataService(this._client);

  final ApiClient _client;
  static const _base = '/emr/master-data';

  Future<List<EmrTemplateItem>> listComplaints({
    String? search,
    bool? isActive,
  }) =>
      _list('$_base/complaints', search, isActive: isActive);

  Future<List<EmrTemplateItem>> listReviewIntervals({
    String? search,
    bool? isActive,
  }) =>
      _list('$_base/review-intervals', search, isActive: isActive);

  Future<List<EmrTemplateItem>> listDiagnoses({String? search}) =>
      _list('$_base/diagnoses', search);

  Future<List<EmrTemplateItem>> listTreatments({String? search}) =>
      _list('$_base/treatments', search);

  Future<List<EmrTemplateItem>> listMedicines({String? search}) =>
      _list('$_base/medicines', search);

  Future<List<EmrTemplateItem>> listDosages({String? search}) =>
      _list('$_base/dosages', search);

  Future<List<EmrTemplateItem>> listFrequencies({String? search}) =>
      _list('$_base/frequencies', search);

  Future<List<EmrTemplateItem>> listObservations({
    String? search,
    bool? isActive,
  }) =>
      _list('$_base/observations', search, isActive: isActive);

  Future<List<EmrTemplateItem>> listInvestigations({String? search}) =>
      _list('$_base/investigations', search);

  Future<List<VaccinationTemplate>> listVaccinations({
    String? search,
    String? species,
  }) async {
    try {
      final res = await _client.get(
        '$_base/vaccinations',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (species != null && species.isNotEmpty) 'species': species,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, VaccinationTemplate.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<VaccinationTemplate> createVaccination(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('$_base/vaccinations', data: body);
      return parseEnvelopeData(
        res,
        (data) => VaccinationTemplate.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<VaccinationTemplate> updateVaccination(
    int id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client.put('$_base/vaccinations/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => VaccinationTemplate.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteVaccination(int id) => _delete('$_base/vaccinations/$id');

  Future<EmrTemplateItem> createComplaint(Map<String, dynamic> body) =>
      _create('$_base/complaints', body);

  Future<EmrTemplateItem> updateComplaint(int id, Map<String, dynamic> body) =>
      _update('$_base/complaints/$id', body);

  Future<void> deleteComplaint(int id) => _delete('$_base/complaints/$id');

  Future<EmrTemplateItem> createReviewInterval(Map<String, dynamic> body) =>
      _create('$_base/review-intervals', body);

  Future<EmrTemplateItem> updateReviewInterval(int id, Map<String, dynamic> body) =>
      _update('$_base/review-intervals/$id', body);

  Future<void> deleteReviewInterval(int id) =>
      _delete('$_base/review-intervals/$id');

  Future<EmrTemplateItem> createDiagnosis(Map<String, dynamic> body) =>
      _create('$_base/diagnoses', body);

  Future<EmrTemplateItem> updateDiagnosis(int id, Map<String, dynamic> body) =>
      _update('$_base/diagnoses/$id', body);

  Future<void> deleteDiagnosis(int id) => _delete('$_base/diagnoses/$id');

  Future<EmrTemplateItem> createTreatment(Map<String, dynamic> body) =>
      _create('$_base/treatments', body);

  Future<EmrTemplateItem> updateTreatment(int id, Map<String, dynamic> body) =>
      _update('$_base/treatments/$id', body);

  Future<void> deleteTreatment(int id) => _delete('$_base/treatments/$id');

  Future<EmrTemplateItem> createMedicine(Map<String, dynamic> body) =>
      _create('$_base/medicines', body);

  Future<EmrTemplateItem> updateMedicine(int id, Map<String, dynamic> body) =>
      _update('$_base/medicines/$id', body);

  Future<void> deleteMedicine(int id) => _delete('$_base/medicines/$id');

  Future<EmrTemplateItem> createDosage(Map<String, dynamic> body) =>
      _create('$_base/dosages', body);

  Future<EmrTemplateItem> updateDosage(int id, Map<String, dynamic> body) =>
      _update('$_base/dosages/$id', body);

  Future<void> deleteDosage(int id) => _delete('$_base/dosages/$id');

  Future<EmrTemplateItem> createFrequency(Map<String, dynamic> body) =>
      _create('$_base/frequencies', body);

  Future<EmrTemplateItem> updateFrequency(int id, Map<String, dynamic> body) =>
      _update('$_base/frequencies/$id', body);

  Future<void> deleteFrequency(int id) => _delete('$_base/frequencies/$id');

  Future<EmrTemplateItem> createObservation(Map<String, dynamic> body) =>
      _create('$_base/observations', body);

  Future<EmrTemplateItem> updateObservation(int id, Map<String, dynamic> body) =>
      _update('$_base/observations/$id', body);

  Future<void> deleteObservation(int id) => _delete('$_base/observations/$id');

  Future<EmrTemplateItem> createInvestigation(Map<String, dynamic> body) =>
      _create('$_base/investigations', body);

  Future<EmrTemplateItem> updateInvestigation(int id, Map<String, dynamic> body) =>
      _update('$_base/investigations/$id', body);

  Future<void> deleteInvestigation(int id) => _delete('$_base/investigations/$id');

  Future<List<TreatmentUnderCategoryItem>> listTreatmentUnderCategories({
    bool includeInactive = false,
  }) async {
    try {
      final res = await _client.get(
        '$_base/treatment-under-categories',
        queryParameters: {
          if (includeInactive) 'include_inactive': 1,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => listFromData(_unwrapListData(data), TreatmentUnderCategoryItem.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<TreatmentUnderCategoryItem> createTreatmentUnderCategory({
    required String label,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      final res = await _client.post(
        '$_base/treatment-under-categories',
        data: {
          'label': label,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => TreatmentUnderCategoryItem.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<TreatmentUnderCategoryItem> updateTreatmentUnderCategory(
    int id, {
    String? label,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      final res = await _client.put(
        '$_base/treatment-under-categories/$id',
        data: {
          if (label != null) 'label': label,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => TreatmentUnderCategoryItem.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteTreatmentUnderCategory(int id) async {
    try {
      await _client.delete('$_base/treatment-under-categories/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<Product>> listTreatmentUnderProducts({
    String? search,
    String? category,
    bool? isActive,
  }) async {
    try {
      final res = await _client.get(
        '$_base/treatment-under-products',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (category != null && category.isNotEmpty) 'category': category,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => listFromData(_unwrapListData(data), Product.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Product> assignTreatmentUnderProduct(
    int productId,
    String? category,
  ) async {
    try {
      final res = await _client.put(
        '$_base/treatment-under-products/$productId',
        data: {'treatment_under_category': category},
      );
      return parseEnvelopeData(
        res,
        (data) => Product.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<PrescriptionUnderCategoryItem>> listPrescriptionUnderCategories({
    bool includeInactive = false,
  }) async {
    try {
      final res = await _client.get(
        '$_base/prescription-under-categories',
        queryParameters: {
          if (includeInactive) 'include_inactive': 1,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => listFromData(_unwrapListData(data), PrescriptionUnderCategoryItem.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PrescriptionUnderCategoryItem> createPrescriptionUnderCategory({
    required String label,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      final res = await _client.post(
        '$_base/prescription-under-categories',
        data: {
          'label': label,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => PrescriptionUnderCategoryItem.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PrescriptionUnderCategoryItem> updatePrescriptionUnderCategory(
    int id, {
    String? label,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      final res = await _client.put(
        '$_base/prescription-under-categories/$id',
        data: {
          if (label != null) 'label': label,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => PrescriptionUnderCategoryItem.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deletePrescriptionUnderCategory(int id) async {
    try {
      await _client.delete('$_base/prescription-under-categories/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<Product>> listPrescriptionUnderProducts({
    String? search,
    String? category,
    bool? isActive,
  }) async {
    try {
      final res = await _client.get(
        '$_base/prescription-under-products',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (category != null && category.isNotEmpty) 'category': category,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => listFromData(_unwrapListData(data), Product.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Product> assignPrescriptionUnderProduct(
    int productId,
    String? category,
  ) async {
    try {
      final res = await _client.put(
        '$_base/prescription-under-products/$productId',
        data: {'prescription_under_category': category},
      );
      return parseEnvelopeData(
        res,
        (data) => Product.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<InvestigationUnderCategoryItem>> listInvestigationUnderCategories({
    bool includeInactive = false,
  }) async {
    try {
      final res = await _client.get(
        '$_base/investigation-under-categories',
        queryParameters: {
          if (includeInactive) 'include_inactive': 1,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => listFromData(
          _unwrapListData(data),
          InvestigationUnderCategoryItem.fromJson,
        ),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<InvestigationUnderCategoryItem> createInvestigationUnderCategory({
    required String label,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      final res = await _client.post(
        '$_base/investigation-under-categories',
        data: {
          'label': label,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => InvestigationUnderCategoryItem.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<InvestigationUnderCategoryItem> updateInvestigationUnderCategory(
    int id, {
    String? label,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      final res = await _client.put(
        '$_base/investigation-under-categories/$id',
        data: {
          if (label != null) 'label': label,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => InvestigationUnderCategoryItem.fromJson(
          Map<String, dynamic>.from(data as Map),
        ),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteInvestigationUnderCategory(int id) async {
    try {
      await _client.delete('$_base/investigation-under-categories/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<Product>> listInvestigationUnderProducts({
    String? search,
    String? category,
    bool? isActive,
  }) async {
    try {
      final res = await _client.get(
        '$_base/investigation-under-products',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (category != null && category.isNotEmpty) 'category': category,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => listFromData(_unwrapListData(data), Product.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Product> assignInvestigationUnderProduct(
    int productId,
    String? category,
  ) async {
    try {
      final res = await _client.put(
        '$_base/investigation-under-products/$productId',
        data: {'investigation_under_category': category},
      );
      return parseEnvelopeData(
        res,
        (data) => Product.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // ── Procedure / service kits ──────────────────────────────────────

  Future<List<ProcedureKit>> listProcedureKits({String? search}) async {
    try {
      final res = await _client.get(
        '$_base/procedure-kits',
        queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
      );
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, ProcedureKit.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<ProcedureKit> createProcedureKit(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('$_base/procedure-kits', data: body);
      return parseEnvelopeData(
        res,
        (data) => ProcedureKit.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<ProcedureKit> updateProcedureKit(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('$_base/procedure-kits/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => ProcedureKit.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteProcedureKit(int id) => _delete('$_base/procedure-kits/$id');

  Future<List<EmrTemplateItem>> _list(
    String path,
    String? search, {
    bool? isActive,
  }) async {
    try {
      final res = await _client.get(
        path,
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (isActive != null) 'is_active': isActive ? 1 : 0,
        },
      );
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, EmrTemplateItem.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<EmrTemplateItem> _create(String path, Map<String, dynamic> body) async {
    try {
      final res = await _client.post(path, data: body);
      return parseEnvelopeData(
        res,
        (data) => EmrTemplateItem.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<EmrTemplateItem> _update(String path, Map<String, dynamic> body) async {
    try {
      final res = await _client.put(path, data: body);
      return parseEnvelopeData(
        res,
        (data) => EmrTemplateItem.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> _delete(String path) async {
    try {
      await _client.delete(path);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

dynamic _unwrapListData(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['data'] is List) return data['data'];
  if (data is Map &&
      data.isNotEmpty &&
      data.values.every((v) => v is Map)) {
    return data.values.toList();
  }
  return data;
}
