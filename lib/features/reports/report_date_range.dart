import 'package:intl/intl.dart';

/// Date range presets for sales/GST reports.
class ReportDateRange {
  const ReportDateRange({required this.from, required this.to, required this.label});

  final DateTime from;
  final DateTime to;
  final String label;

  String get fromYmd => _ymd(from);
  String get toYmd => _ymd(to);

  static String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static ReportDateRange preset(String key) {
    final now = _dateOnly(DateTime.now());
    switch (key) {
      case 'today':
        return ReportDateRange(from: now, to: now, label: 'Today');
      case 'yesterday':
        final y = now.subtract(const Duration(days: 1));
        return ReportDateRange(from: y, to: y, label: 'Yesterday');
      case 'week':
        final start = now.subtract(Duration(days: now.weekday - 1));
        return ReportDateRange(from: start, to: now, label: 'This week');
      case 'month':
        return ReportDateRange(
          from: DateTime(now.year, now.month, 1),
          to: now,
          label: 'This month',
        );
      case 'last_month':
        final firstThisMonth = DateTime(now.year, now.month, 1);
        final lastMonthEnd = firstThisMonth.subtract(const Duration(days: 1));
        return ReportDateRange(
          from: DateTime(lastMonthEnd.year, lastMonthEnd.month, 1),
          to: lastMonthEnd,
          label: 'Last month',
        );
      case 'year':
        return ReportDateRange(
          from: DateTime(now.year, 1, 1),
          to: now,
          label: 'This year',
        );
      case 'q1':
        return ReportDateRange(
          from: DateTime(now.year, 4, 1),
          to: DateTime(now.year, 6, 30),
          label: 'Q1 (Apr–Jun)',
        );
      case 'q2':
        return ReportDateRange(
          from: DateTime(now.year, 7, 1),
          to: DateTime(now.year, 9, 30),
          label: 'Q2 (Jul–Sep)',
        );
      case 'q3':
        return ReportDateRange(
          from: DateTime(now.year, 10, 1),
          to: DateTime(now.year, 12, 31),
          label: 'Q3 (Oct–Dec)',
        );
      case 'q4':
        return ReportDateRange(
          from: DateTime(now.year, 1, 1),
          to: DateTime(now.year, 3, 31),
          label: 'Q4 (Jan–Mar)',
        );
      default:
        return preset('month');
    }
  }

  static ReportDateRange previousPeriod(ReportDateRange current) {
    final days = current.to.difference(current.from).inDays + 1;
    final prevTo = current.from.subtract(const Duration(days: 1));
    final prevFrom = prevTo.subtract(Duration(days: days - 1));
    return ReportDateRange(
      from: prevFrom,
      to: prevTo,
      label: 'Previous period',
    );
  }

  static const presetOptions = <String, String>{
    'today': 'Today',
    'yesterday': 'Yesterday',
    'week': 'This week',
    'month': 'This month',
    'last_month': 'Last month',
    'year': 'This year',
  };

  static const gstPresetOptions = <String, String>{
    'month': 'This month',
    'last_month': 'Last month',
    'q1': 'Q1 (Apr–Jun)',
    'q2': 'Q2 (Jul–Sep)',
    'q3': 'Q3 (Oct–Dec)',
    'q4': 'Q4 (Jan–Mar)',
    'year': 'This year',
  };
}
