import 'package:dio/dio.dart';

import '../../core/app_config.dart';
import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/api_response.dart';
import '../models/emr.dart';
import '../models/invoice.dart';
import 'emr_master_data_service.dart';

class EmrService {
  EmrService(this._client);

  final ApiClient _client;

  // ── Pets ──────────────────────────────────────────────────────────

  Future<List<PetSearchResult>> searchPets(String query) async {
    try {
      final res = await _client.get(
        '/pets',
        queryParameters: {'search': query, 'per_page': 20},
      );
      return parseEnvelopeData(res, (data) => listFromData(data, PetSearchResult.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetSummary> getPetSummary(int petId) async {
    try {
      final res = await _client.get('/pets/$petId/summary');
      return parseEnvelopeData(
        res,
        (data) => PetSummary.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<DoctorLite>> listDoctors({bool? available}) async {
    try {
      final query = <String, dynamic>{};
      if (available != null) query['available'] = available;
      final res = await _client.get('/doctors', queryParameters: query);
      return parseEnvelopeData(res, (data) => listFromData(data, DoctorLite.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<PetSearchResult>> listPets({Map<String, dynamic>? query}) async {
    final result = await listPetsPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 20,
      search: query?['search']?.toString(),
    );
    return result.items;
  }

  Future<({List<PetSearchResult> items, PaginationMeta? meta})> listPetsPaginated({
    int page = 1,
    int perPage = 20,
    String? search,
    String? species,
    String? gender,
    bool? isActive,
  }) async {
    try {
      final res = await _client.get('/pets', queryParameters: {
        'page': page,
        'per_page': perPage,
        if (search != null && search.isNotEmpty) 'search': search,
        if (species != null && species.isNotEmpty) 'species': species,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (isActive != null) 'is_active': isActive,
      });
      return parseEnvelopeList(res, PetSearchResult.fromJson);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> addPetNote(int petId, Map<String, dynamic> body) async {
    try {
      await _client.post('/pets/$petId/notes', data: body);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // ── Patient appointments ──────────────────────────────────────────

  Future<List<PatientAppointment>> todayAppointments() async {
    try {
      final res = await _client.get('/patient-appointments/today');
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, PatientAppointment.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<PatientAppointment>> listAppointments({
    Map<String, dynamic>? query,
  }) async {
    final result = await listAppointmentsPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 20,
      status: query?['status']?.toString(),
      search: query?['search']?.toString(),
    );
    return result.items;
  }

  Future<({List<PatientAppointment> items, PaginationMeta? meta})>
      listAppointmentsPaginated({
    int page = 1,
    int perPage = 20,
    String? status,
    String? search,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final res = await _client.get('/patient-appointments', queryParameters: {
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
        if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      });
      return parseEnvelopeList(res, PatientAppointment.fromJson);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PatientAppointment> getAppointment(int id) async {
    try {
      final res = await _client.get('/patient-appointments/$id');
      return parseEnvelopeData(
        res,
        (data) => PatientAppointment.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PatientAppointment> createAppointment(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/patient-appointments', data: body);
      return parseEnvelopeData(
        res,
        (data) => PatientAppointment.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PatientAppointment> updateAppointment(
    int id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client.put('/patient-appointments/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => PatientAppointment.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> confirmAppointment(int id) async {
    try {
      await _client.post('/patient-appointments/$id/confirm');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> cancelAppointment(int id) async {
    try {
      await _client.post('/patient-appointments/$id/cancel');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // ── Visits ────────────────────────────────────────────────────────

  Future<List<PetVisit>> listVisits({Map<String, dynamic>? query}) async {
    final result = await listVisitsPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 20,
      status: query?['status']?.toString(),
      search: query?['search']?.toString(),
      petId: int.tryParse(query?['pet_id']?.toString() ?? ''),
    );
    return result.items;
  }

  Future<({List<PetVisit> items, PaginationMeta? meta})> listVisitsPaginated({
    int page = 1,
    int perPage = 20,
    String? status,
    String? search,
    int? petId,
  }) async {
    try {
      final res = await _client.get('/visits', queryParameters: {
        'page': page,
        'per_page': perPage,
        if (status != null && status.isNotEmpty && status != 'all') 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
        if (petId != null) 'pet_id': petId,
      });
      return parseEnvelopeList(res, PetVisit.fromJson);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// All visits for one pet (paginates until exhausted). Includes clinical lines.
  Future<List<PetVisit>> listVisitsForPet(int petId, {int perPage = 100}) async {
    final all = <PetVisit>[];
    var page = 1;
    while (true) {
      final result = await listVisitsPaginated(
        page: page,
        perPage: perPage,
        petId: petId,
      );
      all.addAll(result.items);
      final last = result.meta?.lastPage ?? 1;
      if (page >= last || result.items.isEmpty) break;
      page++;
    }
    return all;
  }

  Future<PetVisit> getVisit(int id) async {
    try {
      final res = await _client.get('/visits/$id');
      return parseEnvelopeData(
        res,
        (data) => PetVisit.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetVisit> createVisit(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/visits', data: body);
      return parseEnvelopeData(
        res,
        (data) => PetVisit.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetVisit> updateVisit(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/visits/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => PetVisit.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteVisit(int id) async {
    try {
      await _client.delete('/visits/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Invoice> billVisit(int id) async {
    try {
      final res = await _client.post('/visits/$id/bill');
      return parseEnvelopeData(
        res,
        (data) => Invoice.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetVisit> completeVisit(int id) async {
    try {
      final res = await _client.post('/visits/$id/complete');
      return parseEnvelopeData(
        res,
        (data) => PetVisit.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetVisit> releaseVisitForBilling(int id) async {
    try {
      final res = await _client.post('/visits/$id/release-billing');
      return parseEnvelopeData(
        res,
        (data) => PetVisit.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<String>> getComplaints({String? q}) async {
    try {
      final res = await _client.get(
        '/visits/complaints',
        queryParameters: q != null && q.isNotEmpty ? {'q': q} : null,
      );
      return parseEnvelopeData(res, (data) {
        if (data is List) return data.map((e) => e.toString()).toList();
        return <String>[];
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<String>> getObservations({String? q}) async {
    try {
      final res = await _client.get(
        '/visits/observations',
        queryParameters: q != null && q.isNotEmpty ? {'q': q} : null,
      );
      return parseEnvelopeData(res, (data) {
        if (data is List) return data.map((e) => e.toString()).toList();
        return <String>[];
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<String>> getInvestigations({String? q}) async {
    try {
      final res = await _client.get(
        '/visits/investigations',
        queryParameters: q != null && q.isNotEmpty ? {'q': q} : null,
      );
      return parseEnvelopeData(res, (data) {
        if (data is List) return data.map((e) => e.toString()).toList();
        return <String>[];
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Persist free-typed EMR terms into templates for future suggestions.
  Future<void> rememberTemplates({
    List<String>? complaints,
    List<String>? observations,
    List<String>? investigations,
    List<String>? diagnoses,
  }) async {
    final body = <String, dynamic>{
      if (complaints != null && complaints.isNotEmpty) 'complaints': complaints,
      if (observations != null && observations.isNotEmpty)
        'observations': observations,
      if (investigations != null && investigations.isNotEmpty)
        'investigations': investigations,
      if (diagnoses != null && diagnoses.isNotEmpty) 'diagnoses': diagnoses,
    };
    if (body.isEmpty) return;
    try {
      await _client.post('/visits/templates/remember', data: body);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<VisitDiagnosis>> getDiagnosisSuggestions({String? q}) async {
    try {
      final res = await _client.get(
        '/visits/diagnoses',
        queryParameters: q != null && q.isNotEmpty ? {'q': q} : null,
      );
      return parseEnvelopeData(res, (data) {
        if (data is! List) return <VisitDiagnosis>[];
        return data
            .whereType<Map>()
            .map((e) => VisitDiagnosis(
                  diagnosisName: e['name']?.toString() ?? '',
                  icdCode: e['icd_code']?.toString(),
                  severity: 'mild',
                  isPrimary: false,
                ))
            .toList();
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<TreatmentSuggestion>> getTreatmentSuggestions({String? q}) async {
    try {
      final res = await _client.get(
        '/visits/treatments',
        queryParameters: q != null && q.isNotEmpty ? {'q': q} : null,
      );
      return parseEnvelopeData(res, (data) {
        if (data is! List) return <TreatmentSuggestion>[];
        return data
            .whereType<Map>()
            .map((e) => TreatmentSuggestion.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<ProcedureKit>> getProcedureKits({String? q}) async {
    try {
      final res = await _client.get(
        '/visits/procedure-kits',
        queryParameters: q != null && q.isNotEmpty ? {'q': q} : null,
      );
      return parseEnvelopeData(res, (data) {
        if (data is! List) return <ProcedureKit>[];
        return data
            .whereType<Map>()
            .map((e) => ProcedureKit.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<MedicineSuggestion>> getMedicineSuggestions({String? q}) async {
    try {
      final res = await _client.get(
        '/visits/medicines',
        queryParameters: q != null && q.isNotEmpty ? {'q': q} : null,
      );
      return parseEnvelopeData(res, (data) {
        if (data is! List) return <MedicineSuggestion>[];
        return data
            .whereType<Map>()
            .map((e) => MedicineSuggestion.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<String>> getDosageSuggestions({String? q}) async {
    try {
      final res = await _client.get(
        '/visits/dosages',
        queryParameters: q != null && q.isNotEmpty ? {'q': q} : null,
      );
      return parseEnvelopeData(res, (data) {
        if (data is List) return data.map((e) => e.toString()).toList();
        return <String>[];
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<String>> getFrequencySuggestions({String? q}) async {
    try {
      final res = await _client.get(
        '/visits/frequencies',
        queryParameters: q != null && q.isNotEmpty ? {'q': q} : null,
      );
      return parseEnvelopeData(res, (data) {
        if (data is List) return data.map((e) => e.toString()).toList();
        return <String>[];
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // ── Timeline & pet records ────────────────────────────────────────

  Future<TimelineResponse> getTimeline(int petId, {Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/pets/$petId/timeline', queryParameters: query);
      return parseEnvelopeData(
        res,
        (data) => TimelineResponse.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<PetDeworming>> listDeworming(int petId) async {
    try {
      final res = await _client.get('/pets/$petId/deworming');
      return parseEnvelopeData(res, (data) => listFromData(data, PetDeworming.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetDeworming> addDeworming(int petId, Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/pets/$petId/deworming', data: body);
      return parseEnvelopeData(
        res,
        (data) => PetDeworming.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteDeworming(int petId, int id) async {
    try {
      await _client.delete('/pets/$petId/deworming/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<PetSurgery>> listSurgeries(int petId) async {
    try {
      final res = await _client.get('/pets/$petId/surgeries');
      return parseEnvelopeData(res, (data) => listFromData(data, PetSurgery.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetSurgery> addSurgery(int petId, Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/pets/$petId/surgeries', data: body);
      return parseEnvelopeData(
        res,
        (data) => PetSurgery.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<PetLabReport>> listLabReports(int petId) async {
    try {
      final res = await _client.get('/pets/$petId/lab-reports');
      return parseEnvelopeData(res, (data) => listFromData(data, PetLabReport.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetLabReport> uploadLabReport(int petId, FormData formData) async {
    try {
      final res = await _client.post('/pets/$petId/lab-reports', data: formData);
      return parseEnvelopeData(
        res,
        (data) => PetLabReport.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteLabReport(int petId, int id) async {
    try {
      await _client.delete('/pets/$petId/lab-reports/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  String labReportDownloadUrl(int id) => '${AppConfig.apiBaseUrl}/lab-reports/$id/download';

  Future<List<PetDocument>> listDocuments(int petId) async {
    try {
      final res = await _client.get('/pets/$petId/documents');
      return parseEnvelopeData(res, (data) => listFromData(data, PetDocument.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetDocument> uploadDocument(int petId, FormData formData) async {
    try {
      final res = await _client.post('/pets/$petId/documents', data: formData);
      return parseEnvelopeData(
        res,
        (data) => PetDocument.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteDocument(int petId, int id) async {
    try {
      await _client.delete('/pets/$petId/documents/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  String documentDownloadUrl(int id) => '${AppConfig.apiBaseUrl}/documents/$id/download';

  // ── Reminders ───────────────────────────────────────────────────

  Future<ReminderSummary> reminderDashboard() async {
    try {
      final res = await _client.get('/reminders/dashboard');
      return parseEnvelopeData(
        res,
        (data) => ReminderSummary.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<PetReminder>> dueReminders({Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/reminders/due', queryParameters: query);
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, PetReminder.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> dismissReminder(int id) async {
    try {
      await _client.post('/reminders/$id/dismiss');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> sendReminderNow(int id) async {
    try {
      await _client.post('/reminders/$id/send-now');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
