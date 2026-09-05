import '../json_helpers.dart';

class SummaryReportMetrics {
  SummaryReportMetrics({
    required this.invoiceCount,
    required this.totalAmount,
    required this.cashTotal,
    required this.upiTotal,
    required this.otherTotal,
    required this.pending,
  });

  final int invoiceCount;
  final double totalAmount;
  final double cashTotal;
  final double upiTotal;
  final double otherTotal;
  final double pending;

  factory SummaryReportMetrics.fromJson(Map<String, dynamic> j) => SummaryReportMetrics(
        invoiceCount: intOrNull(j['invoice_count']) ?? 0,
        totalAmount: numOrNull(j['total_amount']) ?? 0,
        cashTotal: numOrNull(j['cash_total']) ?? 0,
        upiTotal: numOrNull(j['upi_total']) ?? 0,
        otherTotal: numOrNull(j['other_total']) ?? 0,
        pending: numOrNull(j['pending']) ?? 0,
      );
}

class SummaryReportBranch extends SummaryReportMetrics {
  SummaryReportBranch({
    required this.branchId,
    required this.branchName,
    required super.invoiceCount,
    required super.totalAmount,
    required super.cashTotal,
    required super.upiTotal,
    required super.otherTotal,
    required super.pending,
  });

  final int branchId;
  final String branchName;

  factory SummaryReportBranch.fromJson(Map<String, dynamic> j) => SummaryReportBranch(
        branchId: intOrNull(j['branch_id']) ?? 0,
        branchName: j['branch_name']?.toString() ?? '',
        invoiceCount: intOrNull(j['invoice_count']) ?? 0,
        totalAmount: numOrNull(j['total_amount']) ?? 0,
        cashTotal: numOrNull(j['cash_total']) ?? 0,
        upiTotal: numOrNull(j['upi_total']) ?? 0,
        otherTotal: numOrNull(j['other_total']) ?? 0,
        pending: numOrNull(j['pending']) ?? 0,
      );
}

class SummaryReportPeriod extends SummaryReportMetrics {
  SummaryReportPeriod({
    required this.period,
    required this.label,
    required super.invoiceCount,
    required super.totalAmount,
    required super.cashTotal,
    required super.upiTotal,
    required super.otherTotal,
    required super.pending,
  });

  final String period;
  final String label;

  factory SummaryReportPeriod.fromJson(Map<String, dynamic> j) => SummaryReportPeriod(
        period: j['period']?.toString() ?? '',
        label: j['label']?.toString() ?? j['period']?.toString() ?? '',
        invoiceCount: intOrNull(j['invoice_count']) ?? 0,
        totalAmount: numOrNull(j['total_amount']) ?? 0,
        cashTotal: numOrNull(j['cash_total']) ?? 0,
        upiTotal: numOrNull(j['upi_total']) ?? 0,
        otherTotal: numOrNull(j['other_total']) ?? 0,
        pending: numOrNull(j['pending']) ?? 0,
      );
}

class SummaryReportRow extends SummaryReportPeriod {
  SummaryReportRow({
    required super.period,
    required super.label,
    required this.branchId,
    required this.branchName,
    required super.invoiceCount,
    required super.totalAmount,
    required super.cashTotal,
    required super.upiTotal,
    required super.otherTotal,
    required super.pending,
  });

  final int branchId;
  final String branchName;

  factory SummaryReportRow.fromJson(Map<String, dynamic> j) => SummaryReportRow(
        period: j['period']?.toString() ?? '',
        label: j['label']?.toString() ?? j['period']?.toString() ?? '',
        branchId: intOrNull(j['branch_id']) ?? 0,
        branchName: j['branch_name']?.toString() ?? '',
        invoiceCount: intOrNull(j['invoice_count']) ?? 0,
        totalAmount: numOrNull(j['total_amount']) ?? 0,
        cashTotal: numOrNull(j['cash_total']) ?? 0,
        upiTotal: numOrNull(j['upi_total']) ?? 0,
        otherTotal: numOrNull(j['other_total']) ?? 0,
        pending: numOrNull(j['pending']) ?? 0,
      );
}

class SummaryReportData {
  SummaryReportData({
    required this.dateFrom,
    required this.dateTo,
    required this.groupBy,
    this.branchId,
    required this.summary,
    required this.byBranch,
    required this.byPeriod,
    required this.rows,
  });

  final String dateFrom;
  final String dateTo;
  final String groupBy;
  final int? branchId;
  final SummaryReportMetrics summary;
  final List<SummaryReportBranch> byBranch;
  final List<SummaryReportPeriod> byPeriod;
  final List<SummaryReportRow> rows;

  bool get isMonth => groupBy == 'month';

  factory SummaryReportData.fromJson(Map<String, dynamic> j) {
    return SummaryReportData(
      dateFrom: j['date_from']?.toString() ?? '',
      dateTo: j['date_to']?.toString() ?? '',
      groupBy: j['group_by']?.toString() ?? 'day',
      branchId: intOrNull(j['branch_id']),
      summary: SummaryReportMetrics.fromJson(
        Map<String, dynamic>.from(j['summary'] as Map? ?? const {}),
      ),
      byBranch: listFromData(j['by_branch'], SummaryReportBranch.fromJson),
      byPeriod: listFromData(j['by_period'], SummaryReportPeriod.fromJson),
      rows: listFromData(j['rows'], SummaryReportRow.fromJson),
    );
  }
}
