import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_date_range_picker.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../data/models/shift_summary.dart';
import '../../data/models/shop.dart';
import 'report_date_range.dart';
import 'report_formatters.dart';
import 'widgets/report_charts.dart';

String _cashierLabel(String name, int userId) {
  final trimmed = name.trim();
  if (trimmed.isNotEmpty) return trimmed;
  return userId > 0 ? 'User #$userId' : '—';
}

/// Super-admin cashier shift summary across all branches, day-wise or month-wise.
class ShiftSummaryReportScreen extends StatefulWidget {
  const ShiftSummaryReportScreen({super.key});

  @override
  State<ShiftSummaryReportScreen> createState() => _ShiftSummaryReportScreenState();
}

class _ShiftSummaryReportScreenState extends State<ShiftSummaryReportScreen> {
  String _preset = 'month';
  ReportDateRange _range = ReportDateRange.preset('month');
  String _groupBy = 'day';
  int? _branchId;

  bool _loading = true;
  String? _error;
  ShiftSummaryData? _data;
  List<Branch> _branches = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branches = await context.read<AppServices>().branches.list();
      if (!mounted) return;
      setState(() {
        _branches = branches.where((b) => b.isActive).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppServices>().reports.shiftSummary(
            dateFrom: _range.fromYmd,
            dateTo: _range.toYmd,
            groupBy: _groupBy,
            branchId: _branchId,
          );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyPreset(String key) {
    setState(() {
      _preset = key;
      _range = ReportDateRange.preset(key);
      if (key == 'year' || key == 'last_month') {
        _groupBy = 'month';
      } else if (key == 'today' || key == 'yesterday' || key == 'week') {
        _groupBy = 'day';
      }
    });
    _load();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _range.from, end: _range.to),
    );
    if (picked == null) return;
    setState(() {
      _preset = 'custom';
      _range = ReportDateRange(
        from: picked.start,
        to: picked.end,
        label: 'Custom range',
      );
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final width = MediaQuery.sizeOf(context).width;
    final crossCount = isMobile ? 2 : (width >= 1200 ? 5 : 3);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _Toolbar(
            preset: _preset,
            range: _range,
            groupBy: _groupBy,
            branchId: _branchId,
            branches: _branches,
            onPreset: _applyPreset,
            onCustomRange: _pickCustomRange,
            onGroupBy: (v) {
              setState(() => _groupBy = v);
              _load();
            },
            onBranch: (v) {
              setState(() => _branchId = v);
              _load();
            },
            onRefresh: _load,
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.danger)),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _load, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : _data == null
                        ? const Center(child: Text('No data'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: EdgeInsets.all(isMobile ? 12 : 16),
                              children: [
                                ..._kpiRow(_data!.summary, crossCount),
                                const SizedBox(height: 16),
                                if (_data!.byBranch.length > 1) ...[
                                  _BranchTotalsTable(
                                    branches: _data!.byBranch,
                                    money: formatReportCurrency,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                _PeriodChart(data: _data!),
                                const SizedBox(height: 16),
                                _BreakdownTable(
                                  data: _data!,
                                  money: formatReportCurrency,
                                  showBranch: _branchId == null && _data!.byBranch.length > 1,
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  List<Widget> _kpiRow(ShiftSummaryMetrics s, int crossCount) {
    return [
      GridView.count(
        crossAxisCount: crossCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: ResponsiveLayout.isMobile(context) ? 1.35 : 1.55,
        children: [
          ReportKpiCard(
            title: 'Shifts',
            value: '${s.shifts}',
            subtitle: '${s.closedShifts} closed · ${s.openShifts} open',
            icon: Icons.schedule_outlined,
            color: AppTheme.primary,
          ),
          ReportKpiCard(
            title: 'Cash collected',
            value: formatReportCurrencyCompact(s.cashCollected),
            subtitle: formatReportCurrency(s.cashCollected),
            icon: Icons.payments_outlined,
            color: const Color(0xFF2563EB),
          ),
          ReportKpiCard(
            title: 'Cash out',
            value: formatReportCurrencyCompact(s.cashOutTotal),
            subtitle: formatReportCurrency(s.cashOutTotal),
            icon: Icons.outbox_outlined,
            color: const Color(0xFF0F766E),
          ),
          ReportKpiCard(
            title: 'Counted',
            value: formatReportCurrencyCompact(s.countedAmount),
            subtitle: 'Expected ${formatReportCurrency(s.expectedClosing)}',
            icon: Icons.point_of_sale_outlined,
            color: const Color(0xFF7C3AED),
          ),
          ReportKpiCard(
            title: 'Open shifts',
            value: '${s.openShifts}',
            subtitle: s.openShifts > 0 ? 'End shifts before day close' : 'All shifts ended',
            icon: Icons.lock_open_outlined,
            color: s.openShifts > 0 ? AppTheme.warning : AppTheme.accent,
          ),
        ],
      ),
    ];
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.preset,
    required this.range,
    required this.groupBy,
    required this.branchId,
    required this.branches,
    required this.onPreset,
    required this.onCustomRange,
    required this.onGroupBy,
    required this.onBranch,
    required this.onRefresh,
  });

  final String preset;
  final ReportDateRange range;
  final String groupBy;
  final int? branchId;
  final List<Branch> branches;
  final ValueChanged<String> onPreset;
  final VoidCallback onCustomRange;
  final ValueChanged<String> onGroupBy;
  final ValueChanged<int?> onBranch;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shift Summary',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cashier shifts by branch and user · opening, cash collected, counted · Super admin',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'day', label: Text('Daywise')),
                  ButtonSegment(value: 'month', label: Text('Monthwise')),
                ],
                selected: {groupBy},
                onSelectionChanged: (s) => onGroupBy(s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
                ),
              ),
              for (final key in const ['today', 'week', 'month', 'last_month', 'year'])
                ChoiceChip(
                  label: Text(_presetLabel(key), style: const TextStyle(fontSize: 12)),
                  selected: preset == key,
                  onSelected: (_) => onPreset(key),
                  visualDensity: VisualDensity.compact,
                ),
              ActionChip(
                label: Text(
                  preset == 'custom' ? range.label : 'Custom',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: onCustomRange,
                visualDensity: VisualDensity.compact,
              ),
              if (branches.length > 1)
                SizedBox(
                  width: 200,
                  child: AppDropdownButtonFormField<int?>(
                    value: branchId,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All branches')),
                      for (final b in branches)
                        DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: onBranch,
                  ),
                ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _presetLabel(String key) => switch (key) {
        'today' => 'Today',
        'week' => 'Week',
        'month' => 'Month',
        'last_month' => 'Last month',
        'year' => 'Year',
        _ => key,
      };
}

class _PeriodChart extends StatelessWidget {
  const _PeriodChart({required this.data});

  final ShiftSummaryData data;

  @override
  Widget build(BuildContext context) {
    final periods = [...data.byPeriod].reversed.toList();
    final visible = periods.length > 14 ? periods.sublist(periods.length - 14) : periods;
    final visibleLabels = visible.map((e) => e.label).toList();

    return ReportSectionCard(
      title: data.isMonth ? 'Cash collected by month' : 'Cash collected by day',
      subtitle: 'Drawer cash in vs cash taken out',
      height: 280,
      child: visible.isEmpty
          ? const ReportEmptyChart(message: 'No cashier shifts in this range')
          : ReportBarChart(
              labels: visibleLabels,
              series: [
                (
                  name: 'Cash collected',
                  color: const Color(0xFF2563EB),
                  values: visible.map((e) => e.cashCollected).toList(),
                ),
                if (visible.any((e) => e.cashOutTotal > 0.009))
                  (
                    name: 'Cash out',
                    color: const Color(0xFF0F766E),
                    values: visible.map((e) => e.cashOutTotal).toList(),
                  ),
              ],
            ),
    );
  }
}

class _BranchTotalsTable extends StatelessWidget {
  const _BranchTotalsTable({
    required this.branches,
    required this.money,
  });

  final List<ShiftSummaryBranch> branches;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    return ReportSectionCard(
      title: 'Branch / user totals',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 1080 ? 1080.0 : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  const _TableHeader(showBranch: true, periodLabel: 'Branch', isMonth: true),
                  const SizedBox(height: 6),
                  for (final b in branches)
                    _MetricRow(
                      label: b.branchName,
                      userName: _cashierLabel(b.userName, b.userId),
                      metrics: b,
                      money: money,
                      isMonth: true,
                      dayClosed: null,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BreakdownTable extends StatelessWidget {
  const _BreakdownTable({
    required this.data,
    required this.money,
    required this.showBranch,
  });

  final ShiftSummaryData data;
  final String Function(double) money;
  final bool showBranch;

  @override
  Widget build(BuildContext context) {
    final rows = data.rows;
    final s = data.summary;

    return ReportSectionCard(
      title: data.isMonth ? 'Month-wise breakdown' : 'Day-wise breakdown',
      subtitle: rows.isEmpty ? null : 'Counted is from closed shifts only',
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: ReportEmptyChart(message: 'No cashier shifts in this range'),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth < 1080 ? 1080.0 : constraints.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        _TableHeader(
                          showBranch: showBranch,
                          periodLabel: data.isMonth ? 'Month' : 'Day',
                          isMonth: data.isMonth,
                        ),
                        const SizedBox(height: 6),
                        for (final row in rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              child: _MetricRow(
                                label: showBranch ? '${row.branchName}  ·  ${row.label}' : row.label,
                                userName: _cashierLabel(row.userName, row.userId),
                                metrics: row,
                                money: money,
                                isMonth: data.isMonth,
                                dayClosed: data.isMonth ? null : row.dayClosed,
                                padded: true,
                              ),
                            ),
                          ),
                        const Divider(height: 20),
                        _MetricRow(
                          label: 'Total',
                          userName: '—',
                          metrics: s,
                          money: money,
                          isMonth: data.isMonth,
                          dayClosed: null,
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.showBranch,
    required this.periodLabel,
    required this.isMonth,
  });

  final bool showBranch;
  final String periodLabel;
  final bool isMonth;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(showBranch ? 'Branch / $periodLabel' : periodLabel, style: style)),
          const Expanded(flex: 2, child: Text('User', style: style)),
          const SizedBox(
            width: 52,
            child: Text('Shifts', style: style, textAlign: TextAlign.right),
          ),
          Expanded(child: Text('Opening', style: style, textAlign: TextAlign.right)),
          Expanded(child: Text('Cash', style: style, textAlign: TextAlign.right)),
          Expanded(child: Text('Cash out', style: style, textAlign: TextAlign.right)),
          Expanded(child: Text('Expected', style: style, textAlign: TextAlign.right)),
          Expanded(child: Text('Counted', style: style, textAlign: TextAlign.right)),
          Expanded(child: Text(isMonth ? 'Days closed' : 'Day close', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.userName,
    required this.metrics,
    required this.money,
    required this.isMonth,
    required this.dayClosed,
    this.emphasize = false,
    this.padded = false,
  });

  final String label;
  final String userName;
  final ShiftSummaryMetrics metrics;
  final String Function(double) money;
  final bool isMonth;
  final bool? dayClosed;
  final bool emphasize;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 12,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
      color: AppTheme.textPrimary,
    );
    final closeLabel = isMonth
        ? '${metrics.daysClosed}'
        : (dayClosed == true
            ? 'Closed'
            : (metrics.openShifts > 0 ? '${metrics.openShifts} open' : 'Open'));

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: padded ? 10 : 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: emphasize ? AppTheme.textSecondary : AppTheme.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              metrics.openShifts > 0 ? '${metrics.shifts} (${metrics.openShifts})' : '${metrics.shifts}',
              style: valueStyle.copyWith(
                color: metrics.openShifts > 0 ? AppTheme.warning : AppTheme.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(child: Text(money(metrics.openingAmount), style: valueStyle, textAlign: TextAlign.right)),
          Expanded(
            child: Text(
              money(metrics.cashCollected),
              style: valueStyle.copyWith(color: const Color(0xFF2563EB)),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(child: Text(money(metrics.cashOutTotal), style: valueStyle, textAlign: TextAlign.right)),
          Expanded(child: Text(money(metrics.expectedClosing), style: valueStyle, textAlign: TextAlign.right)),
          Expanded(
            child: Text(
              money(metrics.countedAmount),
              style: valueStyle.copyWith(color: const Color(0xFF7C3AED)),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              closeLabel,
              style: valueStyle.copyWith(
                color: (dayClosed == true || (isMonth && metrics.daysClosed > 0))
                    ? const Color(0xFF0F766E)
                    : (metrics.openShifts > 0 ? AppTheme.warning : AppTheme.textSecondary),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
