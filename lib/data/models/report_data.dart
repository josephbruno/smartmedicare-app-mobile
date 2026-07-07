import '../json_helpers.dart';

class SalesTrendPoint {
  SalesTrendPoint({
    required this.date,
    required this.total,
    required this.count,
  });

  final String date;
  final double total;
  final int count;

  factory SalesTrendPoint.fromJson(Map<String, dynamic> j) => SalesTrendPoint(
        date: formatApiDate(j['invoice_date']?.toString() ?? j['date']?.toString()),
        total: numOrNull(j['total']) ?? 0,
        count: intOrNull(j['count']) ?? 0,
      );
}

class SalesTrendBranchSeries {
  SalesTrendBranchSeries({
    required this.branchId,
    required this.branchName,
    required this.points,
  });

  final int branchId;
  final String branchName;
  final List<SalesTrendPoint> points;

  factory SalesTrendBranchSeries.fromJson(Map<String, dynamic> j) {
    final data = <SalesTrendPoint>[];
    if (j['data'] is List) {
      for (final row in j['data'] as List) {
        if (row is Map) {
          data.add(SalesTrendPoint.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    return SalesTrendBranchSeries(
      branchId: intOrNull(j['branch_id']) ?? 0,
      branchName: j['branch_name']?.toString() ?? '',
      points: data,
    );
  }
}

class SalesTrendData {
  SalesTrendData({
    required this.points,
    this.multiBranch = false,
    this.branches = const [],
    this.days = 30,
  });

  final List<SalesTrendPoint> points;
  final bool multiBranch;
  final List<SalesTrendBranchSeries> branches;
  final int days;

  factory SalesTrendData.fromJson(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['multi_branch'] == true) {
        final branches = <SalesTrendBranchSeries>[];
        if (map['branches'] is List) {
          for (final b in map['branches'] as List) {
            if (b is Map) {
              branches.add(SalesTrendBranchSeries.fromJson(Map<String, dynamic>.from(b)));
            }
          }
        }
        return SalesTrendData(
          multiBranch: true,
          branches: branches,
          days: intOrNull(map['days']) ?? 30,
          points: const [],
        );
      }
    }

    final points = <SalesTrendPoint>[];
    if (data is List) {
      for (final row in data) {
        if (row is Map) {
          points.add(SalesTrendPoint.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    return SalesTrendData(points: points);
  }
}
