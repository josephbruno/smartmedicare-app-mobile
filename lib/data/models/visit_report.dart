import '../json_helpers.dart';

class VisitReportSummary {
  VisitReportSummary({
    required this.visits,
    required this.billed,
    required this.open,
    required this.onHold,
    required this.completed,
    required this.cancelled,
    required this.uniquePatients,
    required this.serviceChargeTotal,
    required this.treatmentTotal,
    required this.medicineTotal,
    required this.foodTotal,
    required this.billableTotal,
  });

  final int visits;
  final int billed;
  final int open;
  final int onHold;
  final int completed;
  final int cancelled;
  final int uniquePatients;
  final double serviceChargeTotal;
  final double treatmentTotal;
  final double medicineTotal;
  final double foodTotal;
  final double billableTotal;

  factory VisitReportSummary.fromJson(Map<String, dynamic> j) => VisitReportSummary(
        visits: intOrNull(j['visits']) ?? 0,
        billed: intOrNull(j['billed']) ?? 0,
        open: intOrNull(j['open']) ?? 0,
        onHold: intOrNull(j['on_hold']) ?? 0,
        completed: intOrNull(j['completed']) ?? 0,
        cancelled: intOrNull(j['cancelled']) ?? 0,
        uniquePatients: intOrNull(j['unique_patients']) ?? 0,
        serviceChargeTotal: numOrNull(j['service_charge_total']) ?? 0,
        treatmentTotal: numOrNull(j['treatment_total']) ?? 0,
        medicineTotal: numOrNull(j['medicine_total']) ?? 0,
        foodTotal: numOrNull(j['food_total']) ?? 0,
        billableTotal: numOrNull(j['billable_total']) ?? 0,
      );
}

class VisitReportPeriodRow {
  VisitReportPeriodRow({
    required this.period,
    required this.label,
    required this.visits,
    required this.serviceCharge,
  });

  final String period;
  final String label;
  final int visits;
  final double serviceCharge;

  factory VisitReportPeriodRow.fromJson(Map<String, dynamic> j) => VisitReportPeriodRow(
        period: j['period']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        visits: intOrNull(j['visits']) ?? 0,
        serviceCharge: numOrNull(j['service_charge']) ?? 0,
      );
}

class VisitReportNamedCount {
  VisitReportNamedCount({required this.key, required this.count});

  final String key;
  final int count;

  factory VisitReportNamedCount.fromJson(Map<String, dynamic> j, String keyField) =>
      VisitReportNamedCount(
        key: j[keyField]?.toString() ?? '',
        count: intOrNull(j['count']) ?? 0,
      );
}

class VisitReportDoctorRow {
  VisitReportDoctorRow({
    required this.doctorId,
    required this.doctorName,
    required this.visits,
    required this.billed,
    required this.serviceCharge,
    required this.treatmentTotal,
    required this.medicineTotal,
    required this.foodTotal,
    required this.billableTotal,
  });

  final int? doctorId;
  final String doctorName;
  final int visits;
  final int billed;
  final double serviceCharge;
  final double treatmentTotal;
  final double medicineTotal;
  final double foodTotal;
  final double billableTotal;

  factory VisitReportDoctorRow.fromJson(Map<String, dynamic> j) => VisitReportDoctorRow(
        doctorId: intOrNull(j['doctor_id']),
        doctorName: j['doctor_name']?.toString() ?? 'Unassigned',
        visits: intOrNull(j['visits']) ?? 0,
        billed: intOrNull(j['billed']) ?? 0,
        serviceCharge: numOrNull(j['service_charge']) ?? 0,
        treatmentTotal: numOrNull(j['treatment_total']) ?? 0,
        medicineTotal: numOrNull(j['medicine_total']) ?? 0,
        foodTotal: numOrNull(j['food_total']) ?? 0,
        billableTotal: numOrNull(j['billable_total']) ?? 0,
      );
}

class VisitReportLineRow {
  VisitReportLineRow({
    required this.name,
    required this.qty,
    required this.amount,
    required this.visits,
    this.count,
  });

  final String name;
  final double qty;
  final double amount;
  final int visits;
  final int? count;

  factory VisitReportLineRow.fromJson(Map<String, dynamic> j) => VisitReportLineRow(
        name: j['name']?.toString() ?? '',
        qty: numOrNull(j['qty']) ?? 0,
        amount: numOrNull(j['amount']) ?? 0,
        visits: intOrNull(j['visits']) ?? 0,
        count: intOrNull(j['count']),
      );
}

class VisitReportVisitRow {
  VisitReportVisitRow({
    required this.id,
    required this.visitNumber,
    required this.visitDate,
    required this.visitType,
    required this.status,
    required this.doctorName,
    required this.petName,
    required this.customerName,
    required this.serviceCharge,
    required this.treatmentTotal,
    required this.medicineTotal,
    required this.billableTotal,
    required this.invoiceId,
  });

  final int id;
  final String visitNumber;
  final String visitDate;
  final String visitType;
  final String status;
  final String? doctorName;
  final String? petName;
  final String? customerName;
  final double serviceCharge;
  final double treatmentTotal;
  final double medicineTotal;
  final double billableTotal;
  final int? invoiceId;

  factory VisitReportVisitRow.fromJson(Map<String, dynamic> j) => VisitReportVisitRow(
        id: intOrNull(j['id']) ?? 0,
        visitNumber: j['visit_number']?.toString() ?? '',
        visitDate: formatApiDate(j['visit_date']?.toString()),
        visitType: j['visit_type']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        doctorName: j['doctor_name']?.toString(),
        petName: j['pet_name']?.toString(),
        customerName: j['customer_name']?.toString(),
        serviceCharge: numOrNull(j['service_charge']) ?? 0,
        treatmentTotal: numOrNull(j['treatment_total']) ?? 0,
        medicineTotal: numOrNull(j['medicine_total']) ?? 0,
        billableTotal: numOrNull(j['billable_total']) ?? 0,
        invoiceId: intOrNull(j['invoice_id']),
      );
}

class VisitReportData {
  VisitReportData({
    required this.summary,
    required this.groupBy,
    required this.byPeriod,
    required this.byStatus,
    required this.byVisitType,
    required this.byDoctor,
    required this.treatments,
    required this.medicines,
    required this.foodLines,
    required this.serviceProducts,
    required this.visits,
  });

  final VisitReportSummary summary;
  final String groupBy;
  final List<VisitReportPeriodRow> byPeriod;
  final List<VisitReportNamedCount> byStatus;
  final List<VisitReportNamedCount> byVisitType;
  final List<VisitReportDoctorRow> byDoctor;
  final List<VisitReportLineRow> treatments;
  final List<VisitReportLineRow> medicines;
  final List<VisitReportLineRow> foodLines;
  final List<VisitReportLineRow> serviceProducts;
  final List<VisitReportVisitRow> visits;

  factory VisitReportData.fromJson(Map<String, dynamic> j) => VisitReportData(
        summary: VisitReportSummary.fromJson(
          Map<String, dynamic>.from(j['summary'] as Map? ?? const {}),
        ),
        groupBy: j['group_by']?.toString() ?? 'day',
        byPeriod: listFromData(j['by_period'], VisitReportPeriodRow.fromJson),
        byStatus: listFromData(
          j['by_status'],
          (m) => VisitReportNamedCount.fromJson(m, 'status'),
        ),
        byVisitType: listFromData(
          j['by_visit_type'],
          (m) => VisitReportNamedCount.fromJson(m, 'visit_type'),
        ),
        byDoctor: listFromData(j['by_doctor'], VisitReportDoctorRow.fromJson),
        treatments: listFromData(j['treatments'], VisitReportLineRow.fromJson),
        medicines: listFromData(j['medicines'], VisitReportLineRow.fromJson),
        foodLines: listFromData(j['food_lines'], VisitReportLineRow.fromJson),
        serviceProducts: listFromData(j['service_products'], VisitReportLineRow.fromJson),
        visits: listFromData(j['visits'], VisitReportVisitRow.fromJson),
      );
}
