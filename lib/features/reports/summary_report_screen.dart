import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_date_range_picker.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../data/models/shop.dart';
import '../../data/models/summary_report.dart';
import 'report_date_range.dart';
import 'report_formatters.dart';
import 'widgets/report_charts.dart';

/// Super-admin invoice summary: count, total, cash, UPI, pending.
/// Filterable day-wise or month-wise, with optional branch filter.
class SummaryReportScreen extends StatefulWidget {
  const SummaryReportScreen({super.key});

  @override
  State<SummaryReportScreen> createState() => _SummaryReportScreenState();
}

class _SummaryReportScreenState extends State<SummaryReportScreen> {
  static final _ymd = DateFormat('yyyy-MM-dd');

  String _preset = 'month';
  ReportDateRange _range = ReportDateRange.preset('month');
  String _groupBy = 'day';
  int? _branchId;

  bool _loading = true;
  String? _error;
  SummaryReportData? _data;
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
      final data = await context.read<AppServices>().reports.summary(
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

  void _openInvoices(String period) {
    late final String from;
    late final String to;
    if (_groupBy == 'month') {
      final parsed = DateTime.tryParse('$period-01');
      if (parsed == null) return;
      from = _ymd.format(DateTime(parsed.year, parsed.month, 1));
      to = _ymd.format(DateTime(parsed.year, parsed.month + 1, 0));
    } else {
      from = period;
      to = period;
    }
    context.go('/invoices?date_from=$from&date_to=$to');
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
                                  onOpen: (row) => _openInvoices(row.period),
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  List<Widget> _kpiRow(SummaryReportMetrics s, int crossCount) {
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
            title: 'Invoices',
            value: '${s.invoiceCount}',
            subtitle: _range.label,
            icon: Icons.receipt_long_outlined,
            color: AppTheme.primary,
          ),
          ReportKpiCard(
            title: 'Total',
            value: formatReportCurrencyCompact(s.totalAmount),
            subtitle: formatReportCurrency(s.totalAmount),
            icon: Icons.payments_outlined,
            color: const Color(0xFF0F766E),
          ),
          ReportKpiCard(
            title: 'Cash',
            value: formatReportCurrencyCompact(s.cashTotal),
            subtitle: formatReportCurrency(s.cashTotal),
            icon: Icons.payments_outlined,
            color: const Color(0xFF2563EB),
          ),
          ReportKpiCard(
            title: 'UPI',
            value: formatReportCurrencyCompact(s.upiTotal),
            subtitle: formatReportCurrency(s.upiTotal),
            icon: Icons.qr_code_2_outlined,
            color: const Color(0xFF7C3AED),
          ),
          ReportKpiCard(
            title: 'Pending',
            value: formatReportCurrencyCompact(s.pending),
            subtitle: formatReportCurrency(s.pending),
            icon: Icons.hourglass_bottom_outlined,
            color: AppTheme.warning,
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
            'Summary Report',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Invoice count, total, cash, UPI and pending · Super admin',
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

  final SummaryReportData data;

  @override
  Widget build(BuildContext context) {
    final periods = data.byPeriod;
    final labels = periods.map((e) => e.label).toList();
    final visible = labels.length > 14 ? periods.sublist(periods.length - 14) : periods;
    final visibleLabels = visible.map((e) => e.label).toList();

    return ReportSectionCard(
      title: data.isMonth ? 'Sales by month' : 'Sales by day',
      subtitle: 'Cash, UPI and pending',
      height: 280,
      child: visible.isEmpty
          ? const ReportEmptyChart(message: 'No invoices in this range')
          : ReportBarChart(
              labels: visibleLabels,
              series: [
                (
                  name: 'Cash',
                  color: const Color(0xFF2563EB),
                  values: visible.map((e) => e.cashTotal).toList(),
                ),
                (
                  name: 'UPI',
                  color: const Color(0xFF7C3AED),
                  values: visible.map((e) => e.upiTotal).toList(),
                ),
                if (visible.any((e) => e.pending > 0.009))
                  (
                    name: 'Pending',
                    color: AppTheme.warning,
                    values: visible.map((e) => e.pending).toList(),
                  ),
              ],
            ),
    );
  }
}

class _BranchTotalsTable extends StatelessWidget {
  const _BranchTotalsTable({required this.branches, required this.money});

  final List<SummaryReportBranch> branches;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    return ReportSectionCard(
      title: 'Branch totals',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 760 ? 760.0 : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  const _TableHeader(showBranch: true, periodLabel: 'Branch'),
                  const SizedBox(height: 6),
                  for (final b in branches)
                    _MetricRow(
                      label: b.branchName,
                      count: b.invoiceCount,
                      total: b.totalAmount,
                      cash: b.cashTotal,
                      upi: b.upiTotal,
                      pending: b.pending,
                      money: money,
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
    required this.onOpen,
  });

  final SummaryReportData data;
  final String Function(double) money;
  final bool showBranch;
  final ValueChanged<SummaryReportRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = data.rows;
    final s = data.summary;

    return ReportSectionCard(
      title: data.isMonth ? 'Month-wise breakdown' : 'Day-wise breakdown',
      subtitle: rows.isEmpty ? null : 'Tap a row to open invoices',
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: ReportEmptyChart(message: 'No invoices in this range'),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth < 760 ? 760.0 : constraints.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        _TableHeader(
                          showBranch: showBranch,
                          periodLabel: data.isMonth ? 'Month' : 'Day',
                        ),
                        const SizedBox(height: 6),
                        for (final row in rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: () => onOpen(row),
                                borderRadius: BorderRadius.circular(10),
                                child: _MetricRow(
                                  label: showBranch ? '${row.branchName}  ·  ${row.label}' : row.label,
                                  count: row.invoiceCount,
                                  total: row.totalAmount,
                                  cash: row.cashTotal,
                                  upi: row.upiTotal,
                                  pending: row.pending,
                                  money: money,
                                  padded: true,
                                ),
                              ),
                            ),
                          ),
                        const Divider(height: 20),
                        _MetricRow(
                          label: 'Total',
                          count: s.invoiceCount,
                          total: s.totalAmount,
                          cash: s.cashTotal,
                          upi: s.upiTotal,
                          pending: s.pending,
                          money: money,
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
  const _TableHeader({required this.showBranch, required this.periodLabel});

  final bool showBranch;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(showBranch ? 'Branch / $periodLabel' : periodLabel, style: style)),
          const SizedBox(
            width: 56,
            child: Text('Bills', style: style, textAlign: TextAlign.right),
          ),
          Expanded(child: Text('Total', style: style, textAlign: TextAlign.right)),
          Expanded(child: Text('Cash', style: style, textAlign: TextAlign.right)),
          Expanded(child: Text('UPI', style: style, textAlign: TextAlign.right)),
          Expanded(child: Text('Pending', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.count,
    required this.total,
    required this.cash,
    required this.upi,
    required this.pending,
    required this.money,
    this.emphasize = false,
    this.padded = false,
  });

  final String label;
  final int count;
  final double total;
  final double cash;
  final double upi;
  final double pending;
  final String Function(double) money;
  final bool emphasize;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 12,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
      color: AppTheme.textPrimary,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padded ? 12 : 12, vertical: padded ? 10 : 6),
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
          SizedBox(
            width: 56,
            child: Text('$count', style: valueStyle, textAlign: TextAlign.right),
          ),
          Expanded(child: Text(money(total), style: valueStyle, textAlign: TextAlign.right)),
          Expanded(
            child: Text(
              money(cash),
              style: valueStyle.copyWith(color: const Color(0xFF2563EB)),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              money(upi),
              style: valueStyle.copyWith(color: const Color(0xFF7C3AED)),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              money(pending),
              style: valueStyle.copyWith(color: pending > 0 ? AppTheme.warning : AppTheme.textPrimary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
