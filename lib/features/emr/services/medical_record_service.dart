import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/medical_record_model.dart';

/// Service for medical records and EMR operations.
class MedicalRecordService {
  final ApiClient _apiClient;

  MedicalRecordService(this._apiClient);

  // ============ MEDICAL NOTES ============

  /// Get all medical notes for a customer.
  Future<List<MedicalNote>> getMedicalNotes(
    int customerId, {
    String? noteType,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final params = <String, dynamic>{
        if (noteType != null) 'note_type': noteType,
        if (fromDate != null) 'from_date': fromDate.toIso8601String(),
        if (toDate != null) 'to_date': toDate.toIso8601String(),
      };

      final response = await _apiClient.get(
        '/emr/customers/$customerId/notes',
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] ?? data['notes'] ?? []) as List;
      return items.map((e) => MedicalNote.fromJson(Map<String, dynamic>.from(e))).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Create a new medical note.
  Future<MedicalNote> createMedicalNote({
    required int customerId,
    required String title,
    required String content,
    required String noteType,
    String? doctorName,
    List<String>? tags,
    bool isConfidential = false,
  }) async {
    try {
      final response = await _apiClient.post(
        '/emr/customers/$customerId/notes',
        data: {
          'title': title,
          'content': content,
          'note_type': noteType,
          if (doctorName != null) 'doctor_name': doctorName,
          if (tags != null) 'tags': tags,
          'is_confidential': isConfidential,
        },
      );

      return MedicalNote.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Update a medical note.
  Future<MedicalNote> updateMedicalNote({
    required int customerId,
    required int noteId,
    required String title,
    required String content,
    String? noteType,
    String? doctorName,
    List<String>? tags,
  }) async {
    try {
      final response = await _apiClient.put(
        '/emr/customers/$customerId/notes/$noteId',
        data: {
          'title': title,
          'content': content,
          if (noteType != null) 'note_type': noteType,
          if (doctorName != null) 'doctor_name': doctorName,
          if (tags != null) 'tags': tags,
        },
      );

      return MedicalNote.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Delete a medical note.
  Future<void> deleteMedicalNote(int customerId, int noteId) async {
    try {
      await _apiClient.delete('/emr/customers/$customerId/notes/$noteId');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // ============ VACCINATIONS ============

  /// Get vaccination records for a customer.
  Future<List<VaccinationRecord>> getVaccinationRecords(int customerId) async {
    try {
      final response = await _apiClient.get(
        '/emr/customers/$customerId/vaccinations',
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] ?? data['vaccinations'] ?? []) as List;
      return items.map((e) => VaccinationRecord.fromJson(Map<String, dynamic>.from(e))).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get overdue vaccinations.
  Future<List<VaccinationRecord>> getOverdueVaccinations(int customerId) async {
    try {
      final response = await _apiClient.get(
        '/emr/customers/$customerId/vaccinations/overdue',
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] ?? []) as List;
      return items.map((e) => VaccinationRecord.fromJson(Map<String, dynamic>.from(e))).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Add a vaccination record.
  Future<VaccinationRecord> addVaccinationRecord({
    required int customerId,
    required String vaccineName,
    required DateTime vaccinationDate,
    DateTime? nextDueDate,
    String? veterinarianName,
    String? batchNumber,
    String? manufacturer,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.post(
        '/emr/customers/$customerId/vaccinations',
        data: {
          'vaccine_name': vaccineName,
          'vaccination_date': vaccinationDate.toIso8601String(),
          if (nextDueDate != null) 'next_due_date': nextDueDate.toIso8601String(),
          if (veterinarianName != null) 'veterinarian_name': veterinarianName,
          if (batchNumber != null) 'batch_number': batchNumber,
          if (manufacturer != null) 'manufacturer': manufacturer,
          if (notes != null) 'notes': notes,
        },
      );

      return VaccinationRecord.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Update vaccination record.
  Future<VaccinationRecord> updateVaccinationRecord({
    required int customerId,
    required int vaccinationId,
    required String vaccineName,
    required DateTime vaccinationDate,
    DateTime? nextDueDate,
    String? status,
  }) async {
    try {
      final response = await _apiClient.put(
        '/emr/customers/$customerId/vaccinations/$vaccinationId',
        data: {
          'vaccine_name': vaccineName,
          'vaccination_date': vaccinationDate.toIso8601String(),
          if (nextDueDate != null) 'next_due_date': nextDueDate.toIso8601String(),
          if (status != null) 'status': status,
        },
      );

      return VaccinationRecord.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Delete vaccination record.
  Future<void> deleteVaccinationRecord(int customerId, int vaccinationId) async {
    try {
      await _apiClient.delete('/emr/customers/$customerId/vaccinations/$vaccinationId');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // ============ ALLERGIES ============

  /// Get allergy records for a customer.
  Future<List<AllergyRecord>> getAllergyRecords(int customerId) async {
    try {
      final response = await _apiClient.get(
        '/emr/customers/$customerId/allergies',
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] ?? data['allergies'] ?? []) as List;
      return items.map((e) => AllergyRecord.fromJson(Map<String, dynamic>.from(e))).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get active allergies only.
  Future<List<AllergyRecord>> getActiveAllergies(int customerId) async {
    final allergies = await getAllergyRecords(customerId);
    return allergies.where((a) => a.isActive).toList();
  }

  /// Add allergy record.
  Future<AllergyRecord> addAllergyRecord({
    required int customerId,
    required String allergen,
    required String severity,
    required List<String> symptoms,
    String? treatment,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.post(
        '/emr/customers/$customerId/allergies',
        data: {
          'allergen': allergen,
          'severity': severity,
          'symptoms': symptoms,
          if (treatment != null) 'treatment': treatment,
          if (notes != null) 'notes': notes,
        },
      );

      return AllergyRecord.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Update allergy record.
  Future<AllergyRecord> updateAllergyRecord({
    required int customerId,
    required int allergyId,
    required String allergen,
    required String severity,
    required List<String> symptoms,
    String? treatment,
    bool? isActive,
  }) async {
    try {
      final response = await _apiClient.put(
        '/emr/customers/$customerId/allergies/$allergyId',
        data: {
          'allergen': allergen,
          'severity': severity,
          'symptoms': symptoms,
          if (treatment != null) 'treatment': treatment,
          if (isActive != null) 'is_active': isActive,
        },
      );

      return AllergyRecord.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Delete allergy record.
  Future<void> deleteAllergyRecord(int customerId, int allergyId) async {
    try {
      await _apiClient.delete('/emr/customers/$customerId/allergies/$allergyId');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // ============ APPOINTMENTS ============

  /// Get appointments for a customer.
  Future<List<MedicalAppointment>> getAppointments(
    int customerId, {
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final params = <String, dynamic>{
        if (status != null) 'status': status,
        if (fromDate != null) 'from_date': fromDate.toIso8601String(),
        if (toDate != null) 'to_date': toDate.toIso8601String(),
      };

      final response = await _apiClient.get(
        '/emr/customers/$customerId/appointments',
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] ?? data['appointments'] ?? []) as List;
      return items.map((e) => MedicalAppointment.fromJson(Map<String, dynamic>.from(e))).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get upcoming appointments.
  Future<List<MedicalAppointment>> getUpcomingAppointments(int customerId) async {
    return getAppointments(customerId, status: 'scheduled');
  }

  /// Create appointment.
  Future<MedicalAppointment> createAppointment({
    required int customerId,
    required String title,
    required DateTime appointmentDate,
    int? durationMinutes,
    String? veterinarianName,
    String? appointmentType,
    String? reason,
    String? notes,
    bool requiresFollowUp = false,
  }) async {
    try {
      final response = await _apiClient.post(
        '/emr/customers/$customerId/appointments',
        data: {
          'title': title,
          'appointment_date': appointmentDate.toIso8601String(),
          if (durationMinutes != null) 'duration_minutes': durationMinutes,
          if (veterinarianName != null) 'veterinarian_name': veterinarianName,
          if (appointmentType != null) 'appointment_type': appointmentType,
          if (reason != null) 'reason': reason,
          if (notes != null) 'notes': notes,
          'requires_follow_up': requiresFollowUp,
        },
      );

      return MedicalAppointment.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Update appointment.
  Future<MedicalAppointment> updateAppointment({
    required int customerId,
    required int appointmentId,
    required String title,
    required DateTime appointmentDate,
    String? status,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.put(
        '/emr/customers/$customerId/appointments/$appointmentId',
        data: {
          'title': title,
          'appointment_date': appointmentDate.toIso8601String(),
          if (status != null) 'status': status,
          if (notes != null) 'notes': notes,
        },
      );

      return MedicalAppointment.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Cancel appointment.
  Future<void> cancelAppointment(int customerId, int appointmentId) async {
    try {
      await _apiClient.post(
        '/emr/customers/$customerId/appointments/$appointmentId/cancel',
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // ============ TREATMENTS ============

  /// Get treatment records for a customer.
  Future<List<TreatmentRecord>> getTreatmentRecords(int customerId) async {
    try {
      final response = await _apiClient.get(
        '/emr/customers/$customerId/treatments',
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] ?? data['treatments'] ?? []) as List;
      return items.map((e) => TreatmentRecord.fromJson(Map<String, dynamic>.from(e))).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get ongoing treatments.
  Future<List<TreatmentRecord>> getOngoingTreatments(int customerId) async {
    final treatments = await getTreatmentRecords(customerId);
    return treatments.where((t) => t.status == 'ongoing').toList();
  }

  /// Create treatment record.
  Future<TreatmentRecord> createTreatmentRecord({
    required int customerId,
    required String treatmentName,
    required DateTime treatmentDate,
    String? medication,
    String? dosage,
    String? frequency,
    int? durationDays,
    String? notes,
    bool requiresFollowUp = false,
  }) async {
    try {
      final response = await _apiClient.post(
        '/emr/customers/$customerId/treatments',
        data: {
          'treatment_name': treatmentName,
          'treatment_date': treatmentDate.toIso8601String(),
          if (medication != null) 'medication': medication,
          if (dosage != null) 'dosage': dosage,
          if (frequency != null) 'frequency': frequency,
          if (durationDays != null) 'duration_days': durationDays,
          if (notes != null) 'notes': notes,
          'requires_follow_up': requiresFollowUp,
        },
      );

      return TreatmentRecord.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Update treatment record.
  Future<TreatmentRecord> updateTreatmentRecord({
    required int customerId,
    required int treatmentId,
    required String status,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.put(
        '/emr/customers/$customerId/treatments/$treatmentId',
        data: {
          'status': status,
          if (notes != null) 'notes': notes,
        },
      );

      return TreatmentRecord.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
