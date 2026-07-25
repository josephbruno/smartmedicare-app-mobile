import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';

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
  final bool isActive;

  String get displayName => name ?? label ?? '';

  factory EmrTemplateItem.fromJson(Map<String, dynamic> json) => EmrTemplateItem(
        id: json['id'] as int,
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
    this.itemsTotal = 0,
    this.items = const [],
  });

  final int id;
  final String name;
  final String? procedureCode;
  final double? defaultPrice;
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
  });

  final int productId;
  final double quantity;
  final double unitPrice;
  final String treatmentName;
  final String? procedureCode;
  final String? productName;

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

  Future<List<EmrTemplateItem>> listComplaints({String? search}) =>
      _list('$_base/complaints', search);

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

  Future<EmrTemplateItem> createComplaint(Map<String, dynamic> body) =>
      _create('$_base/complaints', body);

  Future<EmrTemplateItem> updateComplaint(int id, Map<String, dynamic> body) =>
      _update('$_base/complaints/$id', body);

  Future<void> deleteComplaint(int id) => _delete('$_base/complaints/$id');

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

  Future<List<EmrTemplateItem>> _list(String path, String? search) async {
    try {
      final res = await _client.get(
        path,
        queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
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
