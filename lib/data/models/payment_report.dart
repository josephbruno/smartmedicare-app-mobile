import '../json_helpers.dart';

class PaymentReportSummary {
  PaymentReportSummary({
    required this.cash,
    required this.upi,
    required this.credit,
    required this.advance,
    required this.due,
    required this.other,
    required this.collected,
    required this.invoiceTotal,
    required this.invoiceCount,
  });

  final double cash;
  final double upi;
  final double credit;
  final double advance;
  final double due;
  final double other;
  final double collected;
  final double invoiceTotal;
  final int invoiceCount;

  factory PaymentReportSummary.fromJson(Map<String, dynamic> j) => PaymentReportSummary(
        cash: numOrNull(j['cash']) ?? 0,
        upi: numOrNull(j['upi']) ?? 0,
        credit: numOrNull(j['credit']) ?? 0,
        advance: numOrNull(j['advance']) ?? 0,
        due: numOrNull(j['due']) ?? 0,
        other: numOrNull(j['other']) ?? 0,
        collected: numOrNull(j['collected']) ?? 0,
        invoiceTotal: numOrNull(j['invoice_total']) ?? 0,
        invoiceCount: intOrNull(j['invoice_count']) ?? 0,
      );
}

class PaymentReportDay {
  PaymentReportDay({
    required this.date,
    required this.cash,
    required this.upi,
    required this.credit,
    required this.advance,
    required this.due,
    required this.other,
    required this.collected,
    required this.invoiceTotal,
    required this.invoiceCount,
  });

  final String date;
  final double cash;
  final double upi;
  final double credit;
  final double advance;
  final double due;
  final double other;
  final double collected;
  final double invoiceTotal;
  final int invoiceCount;

  factory PaymentReportDay.fromJson(Map<String, dynamic> j) => PaymentReportDay(
        date: j['date']?.toString() ?? '',
        cash: numOrNull(j['cash']) ?? 0,
        upi: numOrNull(j['upi']) ?? 0,
        credit: numOrNull(j['credit']) ?? 0,
        advance: numOrNull(j['advance']) ?? 0,
        due: numOrNull(j['due']) ?? 0,
        other: numOrNull(j['other']) ?? 0,
        collected: numOrNull(j['collected']) ?? 0,
        invoiceTotal: numOrNull(j['invoice_total']) ?? 0,
        invoiceCount: intOrNull(j['invoice_count']) ?? 0,
      );
}

class PaymentReportData {
  PaymentReportData({
    required this.dateFrom,
    required this.dateTo,
    this.branchId,
    required this.summary,
    required this.days,
  });

  final String dateFrom;
  final String dateTo;
  final int? branchId;
  final PaymentReportSummary summary;
  final List<PaymentReportDay> days;

  factory PaymentReportData.fromJson(Map<String, dynamic> j) {
    final days = <PaymentReportDay>[];
    if (j['days'] is List) {
      for (final e in j['days'] as List) {
        if (e is Map) {
          days.add(PaymentReportDay.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return PaymentReportData(
      dateFrom: j['date_from']?.toString() ?? '',
      dateTo: j['date_to']?.toString() ?? '',
      branchId: intOrNull(j['branch_id']),
      summary: PaymentReportSummary.fromJson(
        Map<String, dynamic>.from(j['summary'] as Map? ?? const {}),
      ),
      days: days,
    );
  }
}
