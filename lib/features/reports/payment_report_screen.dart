import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_date_range_picker.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../data/models/payment_report.dart';
import '../../data/models/shop.dart';
import 'report_date_range.dart';
import 'report_formatters.dart';
import 'widgets/report_charts.dart';

class PaymentReportScreen extends StatefulWidget {
  const PaymentReportScreen({super.key});

  @override
  State<PaymentReportScreen> createState() => _PaymentReportScreenState();
}

class _PaymentReportScreenState extends State<PaymentReportScreen> {
  static final _dayFmt = DateFormat('d MMM yyyy');
  static final _shortFmt = DateFormat('d MMM');
  static final _rangeFmt = DateFormat('d MMM yyyy');

  String _preset = 'today';
  ReportDateRange _range = ReportDateRange.preset('today');
  bool _loading = true;
  String? _error;
  PaymentReportData? _data;
  List<Branch> _branches = [];
  int? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthSession>();
    if (auth.isSuperAdmin) {
      try {
        final branches = await context.read<AppServices>().branches.list();
        if (!mounted) return;
        _branches = branches.where((b) => b.isActive).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _selectedBranchId = auth.currentBranchId;
      } catch (_) {}
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppServices>().reports.payments(
            dateFrom: _range.fromYmd,
            dateTo: _range.toYmd,
            branchId: context.read<AuthSession>().isSuperAdmin ? _selectedBranchId : null,
          );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _applyPreset(String key) {
    setState(() {
      _preset = key;
      _range = ReportDateRange.preset(key);
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

  void _openInvoicesForDay(String ymd) {
    context.go('/invoices?date_from=$ymd&date_to=$ymd');
  }

  String _money(num n) => formatReportCurrency(n.toDouble());

  String get _rangeLabel {
    if (_range.fromYmd == _range.toYmd) {
      return _rangeFmt.format(_range.from);
    }
    return '${_rangeFmt.format(_range.from)} – ${_rangeFmt.format(_range.to)}';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _data?.summary;
    final days = _data?.days ?? const <PaymentReportDay>[];
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 960;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildToolbar(),
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
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _load, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: [
                            if (summary != null) ...[
                              _buildOverview(summary),
                              const SizedBox(height: 14),
                              _buildKpiGrid(summary, width),
                              const SizedBox(height: 16),
                            ],
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildPieCard(summary)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildBarCard(days)),
                                ],
                              )
                            else ...[
                              _buildPieCard(summary),
                              const SizedBox(height: 16),
                              _buildBarCard(days),
                            ],
                            const SizedBox(height: 16),
                            _buildDaysTable(days),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final isSuperAdmin = context.watch<AuthSession>().isSuperAdmin;
    final branchValue = _selectedBranchId != null &&
            _branches.any((b) => b.id == _selectedBranchId)
        ? _selectedBranchId
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: AppDropdownButtonFormField<String>(
              value: _preset == 'custom' ? null : _preset,
              isDense: true,
              decoration: _filterDecoration('Period'),
              hint: Text(_preset == 'custom' ? 'Custom dates' : 'Period'),
              items: [
                ...ReportDateRange.presetOptions.entries.map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                ),
                const DropdownMenuItem(
                  value: 'custom',
                  child: Text('Custom dates'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                if (v == 'custom') {
                  _pickCustomRange();
                } else {
                  _applyPreset(v);
                }
              },
            ),
          ),
          if (_preset == 'custom') ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickCustomRange,
              icon: const Icon(Icons.date_range, size: 18),
              label: Text('${_range.fromYmd} → ${_range.toYmd}'),
            ),
          ],
          if (isSuperAdmin && _branches.isNotEmpty) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 200,
              child: AppDropdownButtonFormField<int?>(
                value: branchValue,
                isDense: true,
                decoration: _filterDecoration('Branch'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All branches'),
                  ),
                  ..._branches.map(
                    (b) => DropdownMenuItem<int?>(
                      value: b.id,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedBranchId = v);
                  _load();
                },
              ),
            ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Text(
                  _range.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _rangeLabel,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildOverview(PaymentReportSummary s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 1)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final metrics = [
            _OverviewMetric(
              label: 'Collected',
              value: _money(s.collected),
              accent: const Color(0xFF16A34A),
              emphasize: true,
            ),
            _OverviewMetric(
              label: 'Invoice total',
              value: _money(s.invoiceTotal),
              accent: const Color(0xFF2563EB),
            ),
            _OverviewMetric(
              label: 'Outstanding',
              value: _money(s.due),
              accent: s.due > 0.009 ? AppTheme.danger : AppTheme.textSecondary,
            ),
            _OverviewMetric(
              label: 'Invoices',
              value: '${s.invoiceCount}',
              accent: AppTheme.textPrimary,
            ),
          ];

          if (compact) {
            return Wrap(
              spacing: 20,
              runSpacing: 14,
              children: [
                for (final m in metrics)
                  SizedBox(width: (constraints.maxWidth - 20) / 2, child: m),
              ],
            );
          }

          return Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(width: 12),
                  Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 12),
                ],
                Expanded(child: metrics[i]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiGrid(PaymentReportSummary s, double width) {
    final cards = [
      ReportKpiCard(
        title: 'Cash',
        value: _money(s.cash),
        subtitle: 'Collected',
        icon: Icons.payments_outlined,
        color: const Color(0xFF16A34A),
      ),
      ReportKpiCard(
        title: 'UPI',
        value: _money(s.upi),
        subtitle: 'Collected',
        icon: Icons.qr_code_2_outlined,
        color: const Color(0xFF2563EB),
      ),
      ReportKpiCard(
        title: 'Credit',
        value: _money(s.credit),
        subtitle: 'Credit payments',
        icon: Icons.credit_card_outlined,
        color: const Color(0xFF7C3AED),
      ),
      ReportKpiCard(
        title: 'Advance',
        value: _money(s.advance),
        subtitle: 'Applied',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF0891B2),
      ),
      ReportKpiCard(
        title: 'Due',
        value: _money(s.due),
        subtitle: 'Outstanding',
        icon: Icons.schedule_outlined,
        color: AppTheme.danger,
      ),
    ];

    final cols = width >= 1200
        ? 5
        : width >= 900
            ? 3
            : width >= 560
                ? 2
                : 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 12.0;
        final itemWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in cards)
              SizedBox(width: itemWidth, child: c),
          ],
        );
      },
    );
  }

  Widget _buildPieCard(PaymentReportSummary? s) {
    final data = <ChartDatum>[
      if ((s?.cash ?? 0) > 0.009)
        ChartDatum(label: 'Cash', value: s!.cash, color: const Color(0xFF16A34A)),
      if ((s?.upi ?? 0) > 0.009)
        ChartDatum(label: 'UPI', value: s!.upi, color: const Color(0xFF2563EB)),
      if ((s?.credit ?? 0) > 0.009)
        ChartDatum(label: 'Credit', value: s!.credit, color: const Color(0xFF7C3AED)),
      if ((s?.advance ?? 0) > 0.009)
        ChartDatum(label: 'Advance', value: s!.advance, color: const Color(0xFF0891B2)),
      if ((s?.due ?? 0) > 0.009)
        ChartDatum(label: 'Due', value: s!.due, color: AppTheme.danger),
      if ((s?.other ?? 0) > 0.009)
        ChartDatum(label: 'Other', value: s!.other, color: AppTheme.textSecondary),
    ];

    return ReportSectionCard(
      title: 'Payment mix',
      subtitle: 'Share of modes in selected range',
      child: data.isEmpty
          ? const SizedBox(height: 200, child: ReportEmptyChart())
          : ReportDonutChart(
              data: data,
              centerLabel: 'Collected',
              centerValue: _money(s?.collected ?? 0),
              height: 200,
            ),
    );
  }

  Widget _buildBarCard(List<PaymentReportDay> days) {
    final labels = days.map((d) {
      final parsed = DateTime.tryParse(d.date);
      return parsed != null ? _shortFmt.format(parsed) : d.date;
    }).toList();
    final collected = days.map((d) => d.collected).toList();
    final dues = days.map((d) => d.due).toList();
    final hasDue = dues.any((v) => v > 0.009);

    return ReportSectionCard(
      title: 'Daily trend',
      subtitle: hasDue ? 'Collected vs outstanding due' : 'Collected by day',
      child: days.isEmpty
          ? const SizedBox(height: 220, child: ReportEmptyChart())
          : ReportBarChart(
              labels: labels,
              height: 220,
              series: [
                (
                  name: 'Collected',
                  color: const Color(0xFF2563EB),
                  values: collected,
                ),
                if (hasDue)
                  (
                    name: 'Due',
                    color: AppTheme.danger,
                    values: dues,
                  ),
              ],
            ),
    );
  }

  Widget _buildDaysTable(List<PaymentReportDay> days) {
    return ReportSectionCard(
      title: 'Day-wise breakdown',
      subtitle: days.isEmpty ? null : 'Tap a day to open invoices',
      child: days.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: ReportEmptyChart(message: 'No payments or invoices in this range'),
            )
          : Column(
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _DayRow(
                    day: days[i],
                    money: _money,
                    dateLabel: () {
                      final parsed = DateTime.tryParse(days[i].date);
                      return parsed != null ? _dayFmt.format(parsed) : days[i].date;
                    }(),
                    onTap: () => _openInvoicesForDay(days[i].date),
                  ),
                ],
              ],
            ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.accent,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color accent;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: emphasize ? 22 : 18,
            fontWeight: FontWeight.w800,
            color: accent,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.dateLabel,
    required this.money,
    required this.onTap,
  });

  final PaymentReportDay day;
  final String dateLabel;
  final String Function(num) money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${day.invoiceCount} invoice${day.invoiceCount == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniStat(label: 'Cash', value: money(day.cash), color: const Color(0xFF16A34A)),
                  _MiniStat(label: 'UPI', value: money(day.upi), color: const Color(0xFF2563EB)),
                  _MiniStat(label: 'Credit', value: money(day.credit), color: const Color(0xFF7C3AED)),
                  _MiniStat(label: 'Advance', value: money(day.advance), color: const Color(0xFF0891B2)),
                  _MiniStat(
                    label: 'Due',
                    value: money(day.due),
                    color: day.due > 0.009 ? AppTheme.danger : AppTheme.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
