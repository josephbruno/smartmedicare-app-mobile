import '../json_helpers.dart';

class SalesSummary {
  SalesSummary({
    required this.total,
    required this.count,
    this.paid = 0,
    this.due = 0,
    this.byMode = const {},
  });

  final double total;
  final int count;
  final double paid;
  final double due;
  final Map<String, double> byMode;

  factory SalesSummary.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return SalesSummary(total: 0, count: 0);
    }
    final byMode = <String, double>{};
    if (j['by_mode'] is Map) {
      (j['by_mode'] as Map).forEach((k, v) {
        byMode[k.toString()] = (v as num?)?.toDouble() ?? 0;
      });
    }
    return SalesSummary(
      total: numOrNull(j['total']) ?? 0,
      count: intOrNull(j['count']) ?? 0,
      paid: numOrNull(j['paid']) ?? 0,
      due: numOrNull(j['due']) ?? 0,
      byMode: byMode,
    );
  }
}

class TodayAppointmentsSummary {
  const TodayAppointmentsSummary({
    required this.count,
    this.list = const [],
  });

  final int count;
  final List<Map<String, dynamic>> list;

  factory TodayAppointmentsSummary.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return TodayAppointmentsSummary(count: 0);
    }
    final list = <Map<String, dynamic>>[];
    if (j['list'] is List) {
      for (final item in j['list'] as List) {
        final map = mapOrNull(item);
        if (map != null) list.add(map);
      }
    }
    return TodayAppointmentsSummary(
      count: intOrNull(j['count']) ?? list.length,
      list: list,
    );
  }
}

class DashboardData {
  DashboardData({
    required this.todaySales,
    required this.monthlySales,
    required this.lowStockCount,
    this.deadStockValue = 0,
    this.todayAppointments = const TodayAppointmentsSummary(count: 0, list: []),
    this.upcomingVaccines = 0,
    this.outstandingDues = 0,
    this.alertsCount = 0,
    this.branches,
    this.branchCount,
    this.multiBranch = false,
  });

  final SalesSummary todaySales;
  final SalesSummary monthlySales;
  final int lowStockCount;
  final double deadStockValue;
  final TodayAppointmentsSummary todayAppointments;
  final int upcomingVaccines;
  final double outstandingDues;
  final int alertsCount;
  final List<BranchDashboardStat>? branches;
  final int? branchCount;
  final bool multiBranch;

  double get todaySalesTotal => todaySales.total;
  int get todaySalesCount => todaySales.count;
  double get monthlySalesTotal => monthlySales.total;

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    List<BranchDashboardStat>? br;
    if (j['branches'] is List) {
      br = (j['branches'] as List)
          .whereType<Map>()
          .map((e) =>
              BranchDashboardStat.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return DashboardData(
      todaySales: SalesSummary.fromJson(mapOrNull(j['today_sales'])),
      monthlySales: SalesSummary.fromJson(mapOrNull(j['monthly_sales'])),
      lowStockCount: intOrNull(j['low_stock_count']) ?? 0,
      deadStockValue: numOrNull(j['dead_stock_value']) ?? 0,
      todayAppointments: TodayAppointmentsSummary.fromJson(
        mapOrNull(j['today_appointments']),
      ),
      upcomingVaccines: intOrNull(j['upcoming_vaccines']) ?? 0,
      outstandingDues: numOrNull(j['outstanding_dues']) ?? 0,
      alertsCount: intOrNull(j['alerts_count']) ?? 0,
      branches: br,
      branchCount: intOrNull(j['branch_count']),
      multiBranch: j['multi_branch'] as bool? ?? false,
    );
  }
}

class BranchDashboardStat {
  BranchDashboardStat({
    required this.branchId,
    required this.branchName,
    this.branchCode,
    required this.todaySales,
    required this.monthlySales,
    this.stockValue = 0,
    this.lowStockCount = 0,
  });

  final int branchId;
  final String branchName;
  final String? branchCode;
  final double todaySales;
  final double monthlySales;
  final double stockValue;
  final int lowStockCount;

  factory BranchDashboardStat.fromJson(Map<String, dynamic> j) =>
      BranchDashboardStat(
        branchId: intOrNull(j['branch_id']) ?? 0,
        branchName: j['branch_name']?.toString() ?? '',
        branchCode: j['branch_code']?.toString(),
        todaySales: numOrNull(j['today_sales']) ?? 0,
        monthlySales: numOrNull(j['monthly_sales']) ?? 0,
        stockValue: numOrNull(j['stock_value']) ?? 0,
        lowStockCount: intOrNull(j['low_stock_count']) ?? 0,
      );
}
