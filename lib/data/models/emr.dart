import '../json_helpers.dart';
import 'product.dart';

class CustomerLite {
  CustomerLite({
    required this.id,
    required this.name,
    this.phone,
  });

  final int id;
  final String name;
  final String? phone;

  factory CustomerLite.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return CustomerLite(id: 0, name: '');
    }
    return CustomerLite(
      id: intOrNull(j['id']) ?? 0,
      name: j['name']?.toString() ?? '',
      phone: j['phone']?.toString(),
    );
  }
}

class PetSearchResult {
  PetSearchResult({
    required this.id,
    required this.customerId,
    required this.name,
    this.species,
    this.breed,
    this.gender,
    this.customerName,
    this.customerPhone,
  });

  final int id;
  final int customerId;
  final String name;
  final String? species;
  final String? breed;
  final String? gender;
  final String? customerName;
  final String? customerPhone;

  String get displayLabel {
    final owner = customerName ?? 'Owner';
    final details = [species, breed].where((e) => e != null && e.isNotEmpty).join(', ');
    return details.isEmpty ? '$name ($owner)' : '$name — $details ($owner)';
  }

  PetSearchResult withCustomer(CustomerLite? customer) {
    if (customer == null) return this;
    return PetSearchResult(
      id: id,
      customerId: customerId != 0 ? customerId : customer.id,
      name: name,
      species: species,
      breed: breed,
      gender: gender,
      customerName: customerName ?? customer.name,
      customerPhone: customerPhone ?? customer.phone,
    );
  }

  factory PetSearchResult.fromJson(
    Map<String, dynamic> j, {
    CustomerLite? customerOverride,
  }) {
    final customer = customerOverride ?? CustomerLite.fromJson(mapOrNull(j['customer']));
    return PetSearchResult(
      id: intOrNull(j['id']) ?? 0,
      customerId: intOrNull(j['customer_id']) ?? customer.id,
      name: j['name']?.toString() ?? '',
      species: j['species']?.toString(),
      breed: j['breed']?.toString(),
      gender: j['gender']?.toString(),
      customerName: customer.name.isNotEmpty ? customer.name : null,
      customerPhone: customer.phone,
    );
  }
}

class PetSummary {
  PetSummary({
    required this.id,
    required this.name,
    this.species,
    this.breed,
    this.age,
    this.weight,
    required this.allergies,
    this.medicalNotes,
    required this.lastVisits,
    required this.upcomingReminders,
  });

  final int id;
  final String name;
  final String? species;
  final String? breed;
  final String? age;
  final double? weight;
  final List<String> allergies;
  final String? medicalNotes;
  final List<PetLastVisit> lastVisits;
  final List<PetUpcomingReminder> upcomingReminders;

  factory PetSummary.fromJson(Map<String, dynamic> j) {
    List<String> allergies = [];
    if (j['allergies'] is List) {
      allergies = (j['allergies'] as List).map((e) => e.toString()).toList();
    }
    return PetSummary(
      id: intOrNull(j['id']) ?? 0,
      name: j['name']?.toString() ?? '',
      species: j['species']?.toString(),
      breed: j['breed']?.toString(),
      age: j['age']?.toString(),
      weight: numOrNull(j['weight']),
      allergies: allergies,
      medicalNotes: j['medical_notes']?.toString(),
      lastVisits: listFromData(j['last_visits'], PetLastVisit.fromJson),
      upcomingReminders:
          listFromData(j['upcoming_reminders'], PetUpcomingReminder.fromJson),
    );
  }
}

class PetLastVisit {
  PetLastVisit({
    required this.id,
    required this.visitDate,
    required this.visitType,
    this.chiefComplaint,
    required this.diagnoses,
  });

  final int id;
  final String visitDate;
  final String visitType;
  final String? chiefComplaint;
  final List<String> diagnoses;

  factory PetLastVisit.fromJson(Map<String, dynamic> j) {
    List<String> diagnoses = [];
    if (j['diagnoses'] is List) {
      diagnoses = (j['diagnoses'] as List).map((e) => e.toString()).toList();
    }
    return PetLastVisit(
      id: intOrNull(j['id']) ?? 0,
      visitDate: j['visit_date']?.toString() ?? '',
      visitType: j['visit_type']?.toString() ?? '',
      chiefComplaint: j['chief_complaint']?.toString(),
      diagnoses: diagnoses,
    );
  }
}

class PetUpcomingReminder {
  PetUpcomingReminder({
    required this.type,
    required this.name,
    required this.dueDate,
  });

  final String type;
  final String name;
  final String dueDate;

  factory PetUpcomingReminder.fromJson(Map<String, dynamic> j) => PetUpcomingReminder(
        type: j['type']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        dueDate: j['due_date']?.toString() ?? '',
      );
}

class DoctorLite {
  DoctorLite({
    required this.id,
    required this.name,
    this.specialty,
    this.consultationFee,
  });

  final int id;
  final String name;
  final String? specialty;
  final double? consultationFee;

  String get displayLabel =>
      specialty != null && specialty!.isNotEmpty ? '$name ($specialty)' : name;

  factory DoctorLite.fromJson(Map<String, dynamic> j) => DoctorLite(
        id: intOrNull(j['id']) ?? 0,
        name: j['name']?.toString() ?? '',
        specialty: j['specialty']?.toString(),
        consultationFee: numOrNull(j['consultation_fee']),
      );
}

class PatientAppointment {
  PatientAppointment({
    required this.id,
    required this.petId,
    required this.customerId,
    this.doctorId,
    this.appointmentNumber,
    required this.appointmentType,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.status,
    this.chiefComplaint,
    this.notes,
    this.visitId,
    this.pet,
    this.customer,
    this.doctor,
  });

  final int id;
  final int petId;
  final int customerId;
  final int? doctorId;
  final String? appointmentNumber;
  final String appointmentType;
  final String appointmentDate;
  final String appointmentTime;
  final String status;
  final String? chiefComplaint;
  final String? notes;
  final int? visitId;
  final PetSearchResult? pet;
  final CustomerLite? customer;
  final DoctorLite? doctor;

  String get displayDate => formatApiDate(appointmentDate);
  String get displayTime => formatApiTime(appointmentTime);

  factory PatientAppointment.fromJson(Map<String, dynamic> j) {
    final customer = CustomerLite.fromJson(mapOrNull(j['customer']));
    final petMap = mapOrNull(j['pet']);
    final doctorMap = mapOrNull(j['doctor']);
    return PatientAppointment(
      id: intOrNull(j['id']) ?? 0,
      petId: intOrNull(j['pet_id']) ?? 0,
      customerId: intOrNull(j['customer_id']) ?? customer.id,
      doctorId: intOrNull(j['doctor_id']),
      appointmentNumber: j['appointment_number']?.toString(),
      appointmentType: j['appointment_type']?.toString() ?? 'consultation',
      appointmentDate: formatApiDate(j['appointment_date']?.toString()),
      appointmentTime: j['appointment_time']?.toString() ?? '',
      status: j['status']?.toString() ?? 'scheduled',
      chiefComplaint: j['chief_complaint']?.toString(),
      notes: j['notes']?.toString(),
      visitId: intOrNull(j['visit_id']),
      pet: petMap != null
          ? PetSearchResult.fromJson(petMap, customerOverride: customer)
          : null,
      customer: customer.id > 0 ? customer : null,
      doctor: doctorMap != null ? DoctorLite.fromJson(doctorMap) : null,
    );
  }
}

/// One selected investigation on a visit, with optional notes.
///
/// Stored in [PetVisit.investigation] as one item per line:
/// `Name` or `Name | notes`. Legacy comma-separated names (no notes) still parse.
class VisitInvestigationItem {
  const VisitInvestigationItem({required this.name, this.notes = ''});

  final String name;
  final String notes;

  static const _noteSep = ' | ';

  static List<VisitInvestigationItem> parse(String? raw) {
    if (raw == null) return const [];
    final text = raw.trim();
    if (text.isEmpty) return const [];

    final useLined = text.contains('\n') || text.contains(_noteSep);
    final parts = useLined
        ? text.split(RegExp(r'\r?\n'))
        : text.split(',');

    final items = <VisitInvestigationItem>[];
    for (final part in parts) {
      final line = part.trim();
      if (line.isEmpty) continue;
      final sep = line.indexOf(_noteSep);
      if (sep >= 0) {
        final name = line.substring(0, sep).trim();
        final notes = line.substring(sep + _noteSep.length).trim();
        if (name.isEmpty) continue;
        items.add(VisitInvestigationItem(name: name, notes: notes));
      } else {
        items.add(VisitInvestigationItem(name: line));
      }
    }
    return items;
  }

  static String? encode(Iterable<VisitInvestigationItem> items) {
    final lines = <String>[];
    for (final item in items) {
      final name = item.name.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (name.isEmpty) continue;
      final notes = item.notes.replaceAll(RegExp(r'\s+'), ' ').trim();
      lines.add(notes.isEmpty ? name : '$name$_noteSep$notes');
    }
    if (lines.isEmpty) return null;
    return lines.join('\n');
  }
}

class VisitDiagnosis {
  VisitDiagnosis({
    required this.diagnosisName,
    this.icdCode,
    this.severity = 'mild',
    this.isPrimary = false,
  });

  final String diagnosisName;
  final String? icdCode;
  final String severity;
  final bool isPrimary;

  Map<String, dynamic> toJson() => {
        'diagnosis_name': diagnosisName,
        if (icdCode != null && icdCode!.isNotEmpty) 'icd_code': icdCode,
        'severity': severity,
        'is_primary': isPrimary,
      };

  factory VisitDiagnosis.fromJson(Map<String, dynamic> j) => VisitDiagnosis(
        diagnosisName: j['diagnosis_name']?.toString() ?? '',
        icdCode: j['icd_code']?.toString(),
        severity: j['severity']?.toString() ?? 'mild',
        isPrimary: j['is_primary'] as bool? ?? false,
      );
}

class PetVisit {
  PetVisit({
    required this.id,
    required this.petId,
    required this.customerId,
    this.doctorId,
    this.invoiceId,
    required this.visitNumber,
    required this.visitType,
    required this.visitDate,
    this.visitTime,
    this.chiefComplaint,
    this.temperature,
    this.weight,
    this.heartRate,
    this.respiratoryRate,
    this.clinicalNotes,
    this.observation,
    this.investigation,
    this.followUpDate,
    this.followUpNotes,
    this.serviceCharge = 0,
    this.serviceChargeProductId,
    this.serviceChargeProduct,
    required this.status,
    this.pet,
    this.doctor,
    this.diagnoses,
    this.treatments,
    this.medicines,
    this.vaccinations,
    this.dewormings,
    this.surgeries,
    this.invoice,
  });

  final int id;
  final int petId;
  final int customerId;
  final int? doctorId;
  final int? invoiceId;
  final String visitNumber;
  final String visitType;
  final String visitDate;
  final String? visitTime;
  final String? chiefComplaint;
  final double? temperature;
  final double? weight;
  final int? heartRate;
  final int? respiratoryRate;
  final String? clinicalNotes;
  final String? observation;
  final String? investigation;
  final String? followUpDate;
  final String? followUpNotes;
  final double serviceCharge;
  final int? serviceChargeProductId;
  final Product? serviceChargeProduct;
  final String status;
  final PetSearchResult? pet;
  final DoctorLite? doctor;
  final List<VisitDiagnosis>? diagnoses;
  final List<VisitTreatment>? treatments;
  final List<VisitMedicine>? medicines;
  final List<PetVaccination>? vaccinations;
  final List<PetDeworming>? dewormings;
  final List<PetSurgery>? surgeries;
  final Map<String, dynamic>? invoice;

  List<VisitInvestigationItem> get investigationItems =>
      VisitInvestigationItem.parse(investigation);

  factory PetVisit.fromJson(Map<String, dynamic> j) {
    final petMap = mapOrNull(j['pet']);
    final doctorMap = mapOrNull(j['doctor']);
    final serviceProductMap = mapOrNull(j['service_charge_product']);
    List<VisitDiagnosis>? diagnoses;
    if (j['diagnoses'] is List) {
      diagnoses = listFromData(j['diagnoses'], VisitDiagnosis.fromJson);
    }
    List<VisitTreatment>? treatments;
    if (j['treatments'] is List) {
      treatments = listFromData(j['treatments'], VisitTreatment.fromJson);
    }
    List<VisitMedicine>? medicines;
    if (j['medicines'] is List) {
      medicines = listFromData(j['medicines'], VisitMedicine.fromJson);
    }
    List<PetVaccination>? vaccinations;
    if (j['vaccinations'] is List) {
      vaccinations = listFromData(j['vaccinations'], PetVaccination.fromJson);
    }
    List<PetDeworming>? dewormings;
    if (j['dewormings'] is List) {
      dewormings = listFromData(j['dewormings'], PetDeworming.fromJson);
    }
    List<PetSurgery>? surgeries;
    if (j['surgeries'] is List) {
      surgeries = listFromData(j['surgeries'], PetSurgery.fromJson);
    }
    return PetVisit(
      id: intOrNull(j['id']) ?? 0,
      petId: intOrNull(j['pet_id']) ?? 0,
      customerId: intOrNull(j['customer_id']) ?? 0,
      doctorId: intOrNull(j['doctor_id']),
      invoiceId: intOrNull(j['invoice_id']),
      visitNumber: j['visit_number']?.toString() ?? '',
      visitType: j['visit_type']?.toString() ?? 'consultation',
      visitDate: formatApiDate(j['visit_date']?.toString()),
      visitTime: j['visit_time']?.toString(),
      chiefComplaint: j['chief_complaint']?.toString(),
      temperature: numOrNull(j['temperature']),
      weight: numOrNull(j['weight']),
      heartRate: intOrNull(j['heart_rate']),
      respiratoryRate: intOrNull(j['respiratory_rate']),
      clinicalNotes: j['clinical_notes']?.toString(),
      observation: j['observation']?.toString(),
      investigation: j['investigation']?.toString(),
      followUpDate: formatApiDate(j['follow_up_date']?.toString()),
      followUpNotes: j['follow_up_notes']?.toString(),
      serviceCharge: numOrNull(j['service_charge']) ?? 0,
      serviceChargeProductId: intOrNull(j['service_charge_product_id']),
      serviceChargeProduct: serviceProductMap != null
          ? Product.fromJson(Map<String, dynamic>.from(serviceProductMap))
          : null,
      status: j['status']?.toString() ?? 'open',
      pet: petMap != null ? PetSearchResult.fromJson(petMap) : null,
      doctor: doctorMap != null ? DoctorLite.fromJson(doctorMap) : null,
      diagnoses: diagnoses,
      treatments: treatments,
      medicines: medicines,
      vaccinations: vaccinations,
      dewormings: dewormings,
      surgeries: surgeries,
      invoice: mapOrNull(j['invoice']),
    );
  }

  Map<String, dynamic> toCreatePayload() => {
        'pet_id': petId,
        if (doctorId != null) 'doctor_id': doctorId,
        'visit_type': visitType,
        'visit_date': visitDate,
        if (visitTime != null) 'visit_time': visitTime,
        if (chiefComplaint != null) 'chief_complaint': chiefComplaint,
        if (temperature != null) 'temperature': temperature,
        if (weight != null) 'weight': weight,
        if (heartRate != null) 'heart_rate': heartRate,
        if (respiratoryRate != null) 'respiratory_rate': respiratoryRate,
        if (clinicalNotes != null) 'clinical_notes': clinicalNotes,
        if (observation != null) 'observation': observation,
        if (investigation != null) 'investigation': investigation,
        if (followUpDate != null) 'follow_up_date': followUpDate,
        if (followUpNotes != null) 'follow_up_notes': followUpNotes,
        if (diagnoses != null && diagnoses!.isNotEmpty)
          'diagnoses': diagnoses!.map((d) => d.toJson()).toList(),
      };
}

class ReminderSummary {
  ReminderSummary({
    required this.vaccinationDue,
    required this.dewormingDue,
    required this.followupDue,
    required this.overdue,
    required this.sentToday,
  });

  final int vaccinationDue;
  final int dewormingDue;
  final int followupDue;
  final int overdue;
  final int sentToday;

  factory ReminderSummary.fromJson(Map<String, dynamic> j) => ReminderSummary(
        vaccinationDue: intOrNull(j['vaccination_due']) ?? 0,
        dewormingDue: intOrNull(j['deworming_due']) ?? 0,
        followupDue: intOrNull(j['followup_due']) ?? 0,
        overdue: intOrNull(j['overdue']) ?? 0,
        sentToday: intOrNull(j['sent_today']) ?? 0,
      );
}

class PetReminder {
  PetReminder({
    required this.id,
    required this.reminderType,
    required this.dueDate,
    required this.title,
    required this.message,
    required this.status,
    this.pet,
    this.customer,
    this.createdAt,
  });

  final int id;
  final String reminderType;
  final String dueDate;
  final String title;
  final String message;
  final String status;
  final PetSearchResult? pet;
  final CustomerLite? customer;
  final DateTime? createdAt;

  String get displayDueDate => formatApiDate(dueDate);

  factory PetReminder.fromJson(Map<String, dynamic> j) {
    final customer = CustomerLite.fromJson(mapOrNull(j['customer']));
    final petMap = mapOrNull(j['pet']);
    DateTime? createdAt;
    final rawCreated = j['created_at']?.toString();
    if (rawCreated != null && rawCreated.isNotEmpty) {
      createdAt = DateTime.tryParse(rawCreated);
    }
    return PetReminder(
      id: intOrNull(j['id']) ?? 0,
      reminderType: j['reminder_type']?.toString() ?? '',
      dueDate: formatApiDate(j['due_date']?.toString()),
      title: j['title']?.toString() ?? '',
      message: j['message']?.toString() ?? '',
      status: j['status']?.toString() ?? 'pending',
      pet: petMap != null
          ? PetSearchResult.fromJson(petMap, customerOverride: customer)
          : null,
      customer: customer.id > 0 ? customer : null,
      createdAt: createdAt,
    );
  }
}

class VisitTreatment {
  VisitTreatment({
    required this.treatmentName,
    this.productId,
    this.product,
    this.quantity = 1,
    this.unitPrice = 0,
    this.notes,
  });

  final String treatmentName;
  final int? productId;
  final Product? product;
  final double quantity;
  final double unitPrice;
  final String? notes;

  factory VisitTreatment.fromJson(Map<String, dynamic> j) {
    final productMap = mapOrNull(j['product']);
    return VisitTreatment(
      treatmentName: j['treatment_name']?.toString() ?? '',
      productId: intOrNull(j['product_id']),
      product: productMap != null
          ? Product.fromJson(Map<String, dynamic>.from(productMap))
          : null,
      quantity: numOrNull(j['quantity']) ?? 1,
      unitPrice: numOrNull(j['unit_price']) ?? 0,
      notes: j['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (productId != null) 'product_id': productId,
        'treatment_name': treatmentName,
        'quantity': quantity,
        'unit_price': unitPrice,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

class VisitMedicine {
  VisitMedicine({
    required this.medicineName,
    this.productId,
    this.product,
    this.treatmentUnderCategory,
    this.prescriptionUnderCategory,
    this.dosage,
    this.frequency,
    this.durationDays,
    this.quantity = 1,
    this.unitPrice = 0,
    this.isDispensed = false,
  });

  final String medicineName;
  final int? productId;
  final Product? product;
  final String? treatmentUnderCategory;
  final String? prescriptionUnderCategory;
  final String? dosage;
  final String? frequency;
  final int? durationDays;
  final double quantity;
  final double unitPrice;
  final bool isDispensed;

  factory VisitMedicine.fromJson(Map<String, dynamic> j) {
    final productMap = mapOrNull(j['product']);
    return VisitMedicine(
      medicineName: j['medicine_name']?.toString() ?? '',
      productId: intOrNull(j['product_id']),
      product: productMap != null
          ? Product.fromJson(Map<String, dynamic>.from(productMap))
          : null,
      treatmentUnderCategory: j['treatment_under_category']?.toString() ??
          productMap?['treatment_under_category']?.toString(),
      prescriptionUnderCategory: j['prescription_under_category']?.toString() ??
          productMap?['prescription_under_category']?.toString(),
      dosage: j['dosage']?.toString(),
      frequency: j['frequency']?.toString(),
      durationDays: intOrNull(j['duration_days']),
      quantity: numOrNull(j['quantity']) ?? 1,
      unitPrice: numOrNull(j['unit_price']) ?? 0,
      isDispensed: j['is_dispensed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        if (productId != null) 'product_id': productId,
        'medicine_name': medicineName,
        if (treatmentUnderCategory != null && treatmentUnderCategory!.isNotEmpty)
          'treatment_under_category': treatmentUnderCategory,
        if (prescriptionUnderCategory != null && prescriptionUnderCategory!.isNotEmpty)
          'prescription_under_category': prescriptionUnderCategory,
        if (dosage != null && dosage!.isNotEmpty) 'dosage': dosage,
        if (frequency != null && frequency!.isNotEmpty) 'frequency': frequency,
        if (durationDays != null) 'duration_days': durationDays,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
}

class Doctor {
  Doctor({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.specialty,
    this.licenseNumber,
    this.licenseYear,
    this.experienceYears,
    this.consultationFee,
    this.bio,
    required this.availableDays,
    this.availableFrom,
    this.availableTo,
    required this.isAvailable,
    required this.isActive,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? specialty;
  final String? licenseNumber;
  final int? licenseYear;
  final int? experienceYears;
  final double? consultationFee;
  final String? bio;
  final List<String> availableDays;
  final String? availableFrom;
  final String? availableTo;
  final bool isAvailable;
  final bool isActive;

  factory Doctor.fromJson(Map<String, dynamic> j) {
    List<String> days = [];
    if (j['available_days'] is List) {
      days = (j['available_days'] as List).map((e) => e.toString()).toList();
    }
    return Doctor(
      id: intOrNull(j['id']) ?? 0,
      name: j['name']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      phone: j['phone']?.toString(),
      specialty: j['specialty']?.toString(),
      licenseNumber: j['license_number']?.toString(),
      licenseYear: intOrNull(j['license_year']),
      experienceYears: intOrNull(j['experience_years']),
      consultationFee: numOrNull(j['consultation_fee']),
      bio: j['bio']?.toString(),
      availableDays: days,
      availableFrom: j['available_from']?.toString(),
      availableTo: j['available_to']?.toString(),
      isAvailable: j['is_available'] as bool? ?? true,
      isActive: j['is_active'] as bool? ?? true,
    );
  }
}

class PetVaccination {
  PetVaccination({
    required this.id,
    required this.petId,
    this.visitId,
    required this.vaccineName,
    this.category,
    this.vaccineBrand,
    this.batchNumber,
    required this.administeredDate,
    this.nextDueDate,
    this.reminderDaysBefore = 7,
    this.administeredBy,
    this.notes,
    this.status = 'completed',
    this.vaccinationTemplateId,
    this.doseNumber,
  });

  final int id;
  final int petId;
  final int? visitId;
  final String vaccineName;
  final String? category;
  final String? vaccineBrand;
  final String? batchNumber;
  final String administeredDate;
  final String? nextDueDate;
  final int reminderDaysBefore;
  final String? administeredBy;
  final String? notes;
  final String status;
  final int? vaccinationTemplateId;
  final int? doseNumber;

  factory PetVaccination.fromJson(Map<String, dynamic> j) => PetVaccination(
        id: intOrNull(j['id']) ?? 0,
        petId: intOrNull(j['pet_id']) ?? 0,
        visitId: intOrNull(j['visit_id']),
        vaccineName: j['vaccine_name']?.toString() ?? '',
        category: j['category']?.toString(),
        vaccineBrand: j['vaccine_brand']?.toString(),
        batchNumber: j['batch_number']?.toString(),
        administeredDate: formatApiDate(j['administered_date']?.toString()),
        nextDueDate: j['next_due_date'] != null
            ? formatApiDate(j['next_due_date']?.toString())
            : null,
        reminderDaysBefore: intOrNull(j['reminder_days_before']) ?? 7,
        administeredBy: j['administered_by']?.toString(),
        notes: j['notes']?.toString(),
        status: j['status']?.toString() ?? 'completed',
        vaccinationTemplateId: intOrNull(j['vaccination_template_id']),
        doseNumber: intOrNull(j['dose_number']),
      );
}

class PetDeworming {
  PetDeworming({
    required this.id,
    required this.petId,
    this.visitId,
    required this.medicineName,
    required this.administeredDate,
    this.nextDueDate,
    this.dosage,
    this.weightAtTime,
    this.administeredBy,
    this.notes,
  });

  final int id;
  final int petId;
  final int? visitId;
  final String medicineName;
  final String administeredDate;
  final String? nextDueDate;
  final String? dosage;
  final double? weightAtTime;
  final String? administeredBy;
  final String? notes;

  factory PetDeworming.fromJson(Map<String, dynamic> j) => PetDeworming(
        id: intOrNull(j['id']) ?? 0,
        petId: intOrNull(j['pet_id']) ?? 0,
        visitId: intOrNull(j['visit_id']),
        medicineName: j['medicine_name']?.toString() ?? '',
        administeredDate: formatApiDate(j['administered_date']?.toString()),
        nextDueDate: j['next_due_date'] != null
            ? formatApiDate(j['next_due_date']?.toString())
            : null,
        dosage: j['dosage']?.toString(),
        weightAtTime: numOrNull(j['weight_at_time']),
        administeredBy: j['administered_by']?.toString(),
        notes: j['notes']?.toString(),
      );
}

class PetSurgery {
  PetSurgery({
    required this.id,
    required this.petId,
    this.visitId,
    required this.surgeryName,
    required this.surgeryDate,
    this.surgeonId,
    this.surgeonName,
    this.anesthesiaType,
    this.preOpNotes,
    this.postOpNotes,
    this.followUpDate,
    this.followUpNotes,
    this.cost = 0,
    required this.status,
  });

  final int id;
  final int petId;
  final int? visitId;
  final String surgeryName;
  final String surgeryDate;
  final int? surgeonId;
  final String? surgeonName;
  final String? anesthesiaType;
  final String? preOpNotes;
  final String? postOpNotes;
  final String? followUpDate;
  final String? followUpNotes;
  final double cost;
  final String status;

  factory PetSurgery.fromJson(Map<String, dynamic> j) => PetSurgery(
        id: intOrNull(j['id']) ?? 0,
        petId: intOrNull(j['pet_id']) ?? 0,
        visitId: intOrNull(j['visit_id']),
        surgeryName: j['surgery_name']?.toString() ?? '',
        surgeryDate: formatApiDate(j['surgery_date']?.toString()),
        surgeonId: intOrNull(j['surgeon_id']),
        surgeonName: j['surgeon_name']?.toString(),
        anesthesiaType: j['anesthesia_type']?.toString(),
        preOpNotes: j['pre_op_notes']?.toString(),
        postOpNotes: j['post_op_notes']?.toString(),
        followUpDate: j['follow_up_date'] != null
            ? formatApiDate(j['follow_up_date']?.toString())
            : null,
        followUpNotes: j['follow_up_notes']?.toString(),
        cost: numOrNull(j['cost']) ?? 0,
        status: j['status']?.toString() ?? 'scheduled',
      );
}

class PetLabReport {
  PetLabReport({
    required this.id,
    required this.petId,
    required this.reportType,
    required this.reportTitle,
    required this.reportDate,
    this.labName,
    this.fileUrl,
    this.notes,
  });

  final int id;
  final int petId;
  final String reportType;
  final String reportTitle;
  final String reportDate;
  final String? labName;
  final String? fileUrl;
  final String? notes;

  factory PetLabReport.fromJson(Map<String, dynamic> j) => PetLabReport(
        id: intOrNull(j['id']) ?? 0,
        petId: intOrNull(j['pet_id']) ?? 0,
        reportType: j['report_type']?.toString() ?? 'other',
        reportTitle: j['report_title']?.toString() ?? '',
        reportDate: formatApiDate(j['report_date']?.toString()),
        labName: j['lab_name']?.toString(),
        fileUrl: j['file_url']?.toString(),
        notes: j['notes']?.toString(),
      );
}

class PetDocument {
  PetDocument({
    required this.id,
    required this.petId,
    required this.docType,
    required this.title,
    this.issuedDate,
    this.expiryDate,
    this.issuingAuthority,
    this.fileUrl,
    this.notes,
  });

  final int id;
  final int petId;
  final String docType;
  final String title;
  final String? issuedDate;
  final String? expiryDate;
  final String? issuingAuthority;
  final String? fileUrl;
  final String? notes;

  factory PetDocument.fromJson(Map<String, dynamic> j) => PetDocument(
        id: intOrNull(j['id']) ?? 0,
        petId: intOrNull(j['pet_id']) ?? 0,
        docType: j['doc_type']?.toString() ?? 'other',
        title: j['title']?.toString() ?? '',
        issuedDate: j['issued_date'] != null
            ? formatApiDate(j['issued_date']?.toString())
            : null,
        expiryDate: j['expiry_date'] != null
            ? formatApiDate(j['expiry_date']?.toString())
            : null,
        issuingAuthority: j['issuing_authority']?.toString(),
        fileUrl: j['file_url']?.toString(),
        notes: j['notes']?.toString(),
      );
}

class TimelineEvent {
  TimelineEvent({
    required this.id,
    required this.type,
    required this.date,
    required this.title,
    this.subtitle,
    required this.status,
    this.color,
  });

  final String id;
  final String type;
  final String date;
  final String title;
  final String? subtitle;
  final String status;
  final String? color;

  factory TimelineEvent.fromJson(Map<String, dynamic> j) => TimelineEvent(
        id: j['id']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        date: formatApiDate(j['date']?.toString()),
        title: j['title']?.toString() ?? '',
        subtitle: j['subtitle']?.toString(),
        status: j['status']?.toString() ?? '',
        color: j['color']?.toString(),
      );
}

class TimelineResponse {
  TimelineResponse({
    required this.pet,
    required this.timeline,
  });

  final PetSearchResult pet;
  final List<TimelineEvent> timeline;

  factory TimelineResponse.fromJson(Map<String, dynamic> j) {
    final petMap = mapOrNull(j['pet']);
    return TimelineResponse(
      pet: petMap != null
          ? PetSearchResult.fromJson(petMap)
          : PetSearchResult(id: 0, customerId: 0, name: ''),
      timeline: listFromData(j['timeline'], TimelineEvent.fromJson),
    );
  }
}
