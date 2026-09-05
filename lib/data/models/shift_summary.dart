import '../json_helpers.dart';

class ShiftSummaryMetrics {
  ShiftSummaryMetrics({
    required this.shifts,
    required this.openShifts,
    required this.closedShifts,
    required this.openingAmount,
    required this.cashCollected,
    required this.cashInTotal,
    required this.cashOutTotal,
    required this.expectedClosing,
    required this.countedAmount,
    required this.variance,
    required this.daysClosed,
  });

  final int shifts;
  final int openShifts;
  final int closedShifts;
  final double openingAmount;
  final double cashCollected;
  final double cashInTotal;
  final double cashOutTotal;
  final double expectedClosing;
  final double countedAmount;
  final double variance;
  final int daysClosed;

  factory ShiftSummaryMetrics.fromJson(Map<String, dynamic> j) => ShiftSummaryMetrics(
        shifts: intOrNull(j['shifts']) ?? 0,
        openShifts: intOrNull(j['open_shifts']) ?? 0,
        closedShifts: intOrNull(j['closed_shifts']) ?? 0,
        openingAmount: numOrNull(j['opening_amount']) ?? 0,
        cashCollected: numOrNull(j['cash_collected']) ?? 0,
        cashInTotal: numOrNull(j['cash_in_total']) ?? 0,
        cashOutTotal: numOrNull(j['cash_out_total']) ?? 0,
        expectedClosing: numOrNull(j['expected_closing']) ?? 0,
        countedAmount: numOrNull(j['counted_amount']) ?? 0,
        variance: numOrNull(j['variance']) ?? 0,
        daysClosed: intOrNull(j['days_closed']) ?? 0,
      );
}

class ShiftSummaryBranch extends ShiftSummaryMetrics {
  ShiftSummaryBranch({
    required this.branchId,
    required this.branchName,
    required super.shifts,
    required super.openShifts,
    required super.closedShifts,
    required super.openingAmount,
    required super.cashCollected,
    required super.cashInTotal,
    required super.cashOutTotal,
    required super.expectedClosing,
    required super.countedAmount,
    required super.variance,
    required super.daysClosed,
  });

  final int branchId;
  final String branchName;

  factory ShiftSummaryBranch.fromJson(Map<String, dynamic> j) => ShiftSummaryBranch(
        branchId: intOrNull(j['branch_id']) ?? 0,
        branchName: j['branch_name']?.toString() ?? '',
        shifts: intOrNull(j['shifts']) ?? 0,
        openShifts: intOrNull(j['open_shifts']) ?? 0,
        closedShifts: intOrNull(j['closed_shifts']) ?? 0,
        openingAmount: numOrNull(j['opening_amount']) ?? 0,
        cashCollected: numOrNull(j['cash_collected']) ?? 0,
        cashInTotal: numOrNull(j['cash_in_total']) ?? 0,
        cashOutTotal: numOrNull(j['cash_out_total']) ?? 0,
        expectedClosing: numOrNull(j['expected_closing']) ?? 0,
        countedAmount: numOrNull(j['counted_amount']) ?? 0,
        variance: numOrNull(j['variance']) ?? 0,
        daysClosed: intOrNull(j['days_closed']) ?? 0,
      );
}

class ShiftSummaryPeriod extends ShiftSummaryMetrics {
  ShiftSummaryPeriod({
    required this.period,
    required this.label,
    required super.shifts,
    required super.openShifts,
    required super.closedShifts,
    required super.openingAmount,
    required super.cashCollected,
    required super.cashInTotal,
    required super.cashOutTotal,
    required super.expectedClosing,
    required super.countedAmount,
    required super.variance,
    required super.daysClosed,
  });

  final String period;
  final String label;

  factory ShiftSummaryPeriod.fromJson(Map<String, dynamic> j) => ShiftSummaryPeriod(
        period: j['period']?.toString() ?? '',
        label: j['label']?.toString() ?? j['period']?.toString() ?? '',
        shifts: intOrNull(j['shifts']) ?? 0,
        openShifts: intOrNull(j['open_shifts']) ?? 0,
        closedShifts: intOrNull(j['closed_shifts']) ?? 0,
        openingAmount: numOrNull(j['opening_amount']) ?? 0,
        cashCollected: numOrNull(j['cash_collected']) ?? 0,
        cashInTotal: numOrNull(j['cash_in_total']) ?? 0,
        cashOutTotal: numOrNull(j['cash_out_total']) ?? 0,
        expectedClosing: numOrNull(j['expected_closing']) ?? 0,
        countedAmount: numOrNull(j['counted_amount']) ?? 0,
        variance: numOrNull(j['variance']) ?? 0,
        daysClosed: intOrNull(j['days_closed']) ?? 0,
      );
}

class ShiftSummaryRow extends ShiftSummaryPeriod {
  ShiftSummaryRow({
    required super.period,
    required super.label,
    required this.branchId,
    required this.branchName,
    required this.dayClosed,
    required super.shifts,
    required super.openShifts,
    required super.closedShifts,
    required super.openingAmount,
    required super.cashCollected,
    required super.cashInTotal,
    required super.cashOutTotal,
    required super.expectedClosing,
    required super.countedAmount,
    required super.variance,
    required super.daysClosed,
  });

  final int branchId;
  final String branchName;
  final bool dayClosed;

  factory ShiftSummaryRow.fromJson(Map<String, dynamic> j) => ShiftSummaryRow(
        period: j['period']?.toString() ?? '',
        label: j['label']?.toString() ?? j['period']?.toString() ?? '',
        branchId: intOrNull(j['branch_id']) ?? 0,
        branchName: j['branch_name']?.toString() ?? '',
        dayClosed: j['day_closed'] == true,
        shifts: intOrNull(j['shifts']) ?? 0,
        openShifts: intOrNull(j['open_shifts']) ?? 0,
        closedShifts: intOrNull(j['closed_shifts']) ?? 0,
        openingAmount: numOrNull(j['opening_amount']) ?? 0,
        cashCollected: numOrNull(j['cash_collected']) ?? 0,
        cashInTotal: numOrNull(j['cash_in_total']) ?? 0,
        cashOutTotal: numOrNull(j['cash_out_total']) ?? 0,
        expectedClosing: numOrNull(j['expected_closing']) ?? 0,
        countedAmount: numOrNull(j['counted_amount']) ?? 0,
        variance: numOrNull(j['variance']) ?? 0,
        daysClosed: intOrNull(j['days_closed']) ?? 0,
      );
}

class ShiftSummaryData {
  ShiftSummaryData({
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
  final ShiftSummaryMetrics summary;
  final List<ShiftSummaryBranch> byBranch;
  final List<ShiftSummaryPeriod> byPeriod;
  final List<ShiftSummaryRow> rows;

  bool get isMonth => groupBy == 'month';

  factory ShiftSummaryData.fromJson(Map<String, dynamic> j) {
    return ShiftSummaryData(
      dateFrom: j['date_from']?.toString() ?? '',
      dateTo: j['date_to']?.toString() ?? '',
      groupBy: j['group_by']?.toString() ?? 'day',
      branchId: intOrNull(j['branch_id']),
      summary: ShiftSummaryMetrics.fromJson(
        Map<String, dynamic>.from(j['summary'] as Map? ?? const {}),
      ),
      byBranch: listFromData(j['by_branch'], ShiftSummaryBranch.fromJson),
      byPeriod: listFromData(j['by_period'], ShiftSummaryPeriod.fromJson),
      rows: listFromData(j['rows'], ShiftSummaryRow.fromJson),
    );
  }
}
