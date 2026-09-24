import '../json_helpers.dart';
import 'emr.dart';

class IpdBed {
  IpdBed({
    required this.id,
    required this.wardId,
    required this.bedNumber,
    required this.status,
    required this.dailyRate,
  });

  final int id;
  final int wardId;
  final String bedNumber;
  final String status;
  final double dailyRate;

  factory IpdBed.fromJson(Map<String, dynamic> json) => IpdBed(
        id: intOrNull(json['id']) ?? 0,
        wardId: intOrNull(json['ward_id']) ?? 0,
        bedNumber: json['bed_number']?.toString() ?? '',
        status: json['status']?.toString() ?? 'available',
        dailyRate: numOrNull(json['daily_rate']) ?? 0,
      );
}

class IpdWard {
  IpdWard({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.beds,
  });

  final int id;
  final String name;
  final String code;
  final String type;
  final List<IpdBed> beds;

  factory IpdWard.fromJson(Map<String, dynamic> json) => IpdWard(
        id: intOrNull(json['id']) ?? 0,
        name: json['name']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        type: json['type']?.toString() ?? 'general',
        beds: json['beds'] is List
            ? listFromData(json['beds'], IpdBed.fromJson)
            : const [],
      );
}

class IpdAdmission {
  IpdAdmission({
    required this.id,
    required this.admissionNumber,
    required this.patientId,
    required this.status,
    required this.admittedAt,
    this.patient,
    this.ward,
    this.bed,
  });

  final int id;
  final String admissionNumber;
  final int patientId;
  final String status;
  final String admittedAt;
  final PetSearchResult? patient;
  final IpdWard? ward;
  final IpdBed? bed;

  factory IpdAdmission.fromJson(Map<String, dynamic> json) {
    final patient = mapOrNull(json['patient']);
    final ward = mapOrNull(json['ward']);
    final bed = mapOrNull(json['bed']);
    return IpdAdmission(
      id: intOrNull(json['id']) ?? 0,
      admissionNumber: json['admission_number']?.toString() ?? '',
      patientId: intOrNull(json['patient_id']) ?? 0,
      status: json['status']?.toString() ?? 'admitted',
      admittedAt: json['admitted_at']?.toString() ?? '',
      patient: patient != null ? PetSearchResult.fromJson(patient) : null,
      ward: ward != null ? IpdWard.fromJson(ward) : null,
      bed: bed != null ? IpdBed.fromJson(bed) : null,
    );
  }
}
