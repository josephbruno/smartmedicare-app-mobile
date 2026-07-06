import '../../../data/json_helpers.dart';

/// Medical note for a patient
class MedicalNote {
  final int id;
  final int customerId;
  final String title;
  final String content;
  final String noteType; // consultation, diagnosis, treatment, follow-up
  final String? doctorName;
  final List<String>? tags;
  final bool isConfidential;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MedicalNote({
    required this.id,
    required this.customerId,
    required this.title,
    required this.content,
    required this.noteType,
    this.doctorName,
    this.tags,
    this.isConfidential = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory MedicalNote.fromJson(Map<String, dynamic> j) {
    return MedicalNote(
      id: intOrNull(j['id']) ?? 0,
      customerId: intOrNull(j['customer_id']) ?? 0,
      title: j['title']?.toString() ?? '',
      content: j['content']?.toString() ?? '',
      noteType: j['note_type']?.toString() ?? 'consultation',
      doctorName: j['doctor_name']?.toString(),
      tags: (j['tags'] as List?)?.map((e) => e.toString()).toList(),
      isConfidential: j['is_confidential'] as bool? ?? false,
      createdAt: j['created_at'] != null ? DateTime.parse(j['created_at'] as String) : DateTime.now(),
      updatedAt: j['updated_at'] != null ? DateTime.parse(j['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'title': title,
        'content': content,
        'note_type': noteType,
        if (doctorName != null) 'doctor_name': doctorName,
        if (tags != null) 'tags': tags,
        'is_confidential': isConfidential,
        'created_at': createdAt.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };
}

/// Vaccination record
class VaccinationRecord {
  final int id;
  final int customerId;
  final String vaccineName;
  final DateTime vaccinationDate;
  final DateTime? nextDueDate;
  final String? veterinarianName;
  final String? batchNumber;
  final String? manufacturer;
  final String status; // completed, pending, overdue
  final String? notes;
  final DateTime createdAt;

  VaccinationRecord({
    required this.id,
    required this.customerId,
    required this.vaccineName,
    required this.vaccinationDate,
    this.nextDueDate,
    this.veterinarianName,
    this.batchNumber,
    this.manufacturer,
    this.status = 'completed',
    this.notes,
    required this.createdAt,
  });

  bool get isOverdue {
    if (nextDueDate == null) return false;
    return DateTime.now().isAfter(nextDueDate!) && status != 'completed';
  }

  factory VaccinationRecord.fromJson(Map<String, dynamic> j) {
    return VaccinationRecord(
      id: intOrNull(j['id']) ?? 0,
      customerId: intOrNull(j['customer_id']) ?? 0,
      vaccineName: j['vaccine_name']?.toString() ?? '',
      vaccinationDate: j['vaccination_date'] != null
          ? DateTime.parse(j['vaccination_date'] as String)
          : DateTime.now(),
      nextDueDate: j['next_due_date'] != null ? DateTime.parse(j['next_due_date'] as String) : null,
      veterinarianName: j['veterinarian_name']?.toString(),
      batchNumber: j['batch_number']?.toString(),
      manufacturer: j['manufacturer']?.toString(),
      status: j['status']?.toString() ?? 'completed',
      notes: j['notes']?.toString(),
      createdAt: j['created_at'] != null ? DateTime.parse(j['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'vaccine_name': vaccineName,
        'vaccination_date': vaccinationDate.toIso8601String(),
        if (nextDueDate != null) 'next_due_date': nextDueDate!.toIso8601String(),
        if (veterinarianName != null) 'veterinarian_name': veterinarianName,
        if (batchNumber != null) 'batch_number': batchNumber,
        if (manufacturer != null) 'manufacturer': manufacturer,
        'status': status,
        if (notes != null) 'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Allergy record
class AllergyRecord {
  final int id;
  final int customerId;
  final String allergen;
  final String severity; // mild, moderate, severe
  final List<String> symptoms;
  final String? treatment;
  final String? notes;
  final bool isActive;
  final DateTime recordedDate;

  AllergyRecord({
    required this.id,
    required this.customerId,
    required this.allergen,
    required this.severity,
    required this.symptoms,
    this.treatment,
    this.notes,
    this.isActive = true,
    required this.recordedDate,
  });

  factory AllergyRecord.fromJson(Map<String, dynamic> j) {
    return AllergyRecord(
      id: intOrNull(j['id']) ?? 0,
      customerId: intOrNull(j['customer_id']) ?? 0,
      allergen: j['allergen']?.toString() ?? '',
      severity: j['severity']?.toString() ?? 'mild',
      symptoms: (j['symptoms'] as List?)?.map((e) => e.toString()).toList() ?? [],
      treatment: j['treatment']?.toString(),
      notes: j['notes']?.toString(),
      isActive: j['is_active'] as bool? ?? true,
      recordedDate: j['recorded_date'] != null
          ? DateTime.parse(j['recorded_date'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'allergen': allergen,
        'severity': severity,
        'symptoms': symptoms,
        if (treatment != null) 'treatment': treatment,
        if (notes != null) 'notes': notes,
        'is_active': isActive,
        'recorded_date': recordedDate.toIso8601String(),
      };
}

/// Medical appointment/consultation
class MedicalAppointment {
  final int id;
  final int customerId;
  final String title;
  final DateTime appointmentDate;
  final Duration? duration;
  final String? veterinarianName;
  final String appointmentType; // consultation, vaccination, surgery, checkup
  final String status; // scheduled, completed, cancelled, no-show
  final String? reason;
  final String? notes;
  final bool requiresFollowUp;
  final DateTime? followUpDate;
  final DateTime createdAt;

  MedicalAppointment({
    required this.id,
    required this.customerId,
    required this.title,
    required this.appointmentDate,
    this.duration,
    this.veterinarianName,
    this.appointmentType = 'consultation',
    this.status = 'scheduled',
    this.reason,
    this.notes,
    this.requiresFollowUp = false,
    this.followUpDate,
    required this.createdAt,
  });

  bool get isUpcoming => appointmentDate.isAfter(DateTime.now()) && status == 'scheduled';
  bool get isPast => appointmentDate.isBefore(DateTime.now());

  factory MedicalAppointment.fromJson(Map<String, dynamic> j) {
    return MedicalAppointment(
      id: intOrNull(j['id']) ?? 0,
      customerId: intOrNull(j['customer_id']) ?? 0,
      title: j['title']?.toString() ?? '',
      appointmentDate: j['appointment_date'] != null
          ? DateTime.parse(j['appointment_date'] as String)
          : DateTime.now(),
      duration: j['duration_minutes'] != null
          ? Duration(minutes: intOrNull(j['duration_minutes']) ?? 0)
          : null,
      veterinarianName: j['veterinarian_name']?.toString(),
      appointmentType: j['appointment_type']?.toString() ?? 'consultation',
      status: j['status']?.toString() ?? 'scheduled',
      reason: j['reason']?.toString(),
      notes: j['notes']?.toString(),
      requiresFollowUp: j['requires_follow_up'] as bool? ?? false,
      followUpDate: j['follow_up_date'] != null ? DateTime.parse(j['follow_up_date'] as String) : null,
      createdAt: j['created_at'] != null ? DateTime.parse(j['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'title': title,
        'appointment_date': appointmentDate.toIso8601String(),
        if (duration != null) 'duration_minutes': duration!.inMinutes,
        if (veterinarianName != null) 'veterinarian_name': veterinarianName,
        'appointment_type': appointmentType,
        'status': status,
        if (reason != null) 'reason': reason,
        if (notes != null) 'notes': notes,
        'requires_follow_up': requiresFollowUp,
        if (followUpDate != null) 'follow_up_date': followUpDate!.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

/// Medical treatment record
class TreatmentRecord {
  final int id;
  final int customerId;
  final String treatmentName;
  final DateTime treatmentDate;
  final String status; // ongoing, completed, suspended
  final String? medication;
  final String? dosage;
  final String? frequency;
  final int? durationDays;
  final String? notes;
  final bool requiresFollowUp;
  final DateTime? nextReviewDate;

  TreatmentRecord({
    required this.id,
    required this.customerId,
    required this.treatmentName,
    required this.treatmentDate,
    required this.status,
    this.medication,
    this.dosage,
    this.frequency,
    this.durationDays,
    this.notes,
    this.requiresFollowUp = false,
    this.nextReviewDate,
  });

  factory TreatmentRecord.fromJson(Map<String, dynamic> j) {
    return TreatmentRecord(
      id: intOrNull(j['id']) ?? 0,
      customerId: intOrNull(j['customer_id']) ?? 0,
      treatmentName: j['treatment_name']?.toString() ?? '',
      treatmentDate: j['treatment_date'] != null
          ? DateTime.parse(j['treatment_date'] as String)
          : DateTime.now(),
      status: j['status']?.toString() ?? 'ongoing',
      medication: j['medication']?.toString(),
      dosage: j['dosage']?.toString(),
      frequency: j['frequency']?.toString(),
      durationDays: intOrNull(j['duration_days']),
      notes: j['notes']?.toString(),
      requiresFollowUp: j['requires_follow_up'] as bool? ?? false,
      nextReviewDate: j['next_review_date'] != null ? DateTime.parse(j['next_review_date'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'treatment_name': treatmentName,
        'treatment_date': treatmentDate.toIso8601String(),
        'status': status,
        if (medication != null) 'medication': medication,
        if (dosage != null) 'dosage': dosage,
        if (frequency != null) 'frequency': frequency,
        if (durationDays != null) 'duration_days': durationDays,
        if (notes != null) 'notes': notes,
        'requires_follow_up': requiresFollowUp,
        if (nextReviewDate != null) 'next_review_date': nextReviewDate!.toIso8601String(),
      };
}
