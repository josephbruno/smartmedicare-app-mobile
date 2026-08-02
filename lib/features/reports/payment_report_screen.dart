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

  @override
  Widget build(BuildContext context) {
    final summary = _data?.summary;
    final days = _data?.days ?? const <PaymentReportDay>[];
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Report',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cash · UPI · Credit · Advance · Due — ${_range.label}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final key in const ['today', 'yesterday', 'week', 'month'])
                      ChoiceChip(
                        label: Text(ReportDateRange.preset(key).label),
                        selected: _preset == key,
                        onSelected: (_) => _applyPreset(key),
                      ),
                    OutlinedButton.icon(
                      onPressed: _pickCustomRange,
                      icon: const Icon(Icons.date_range_outlined, size: 18),
                      label: Text(
                        _preset == 'custom'
                            ? '${_range.fromYmd} – ${_range.toYmd}'
                            : 'Custom dates',
                      ),
                    ),
                    if (context.watch<AuthSession>().isSuperAdmin && _branches.isNotEmpty)
                      SizedBox(
                        width: 200,
                        child: AppDropdownButtonFormField<int?>(
                          value: _selectedBranchId,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Branch',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('All branches')),
                            ..._branches.map(
                              (b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name)),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedBranchId = v);
                            _load();
                          },
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (summary != null) _buildKpiRow(summary, wide),
                          const SizedBox(height: 16),
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
        ],
      ),
    );
  }

  Widget _buildKpiRow(PaymentReportSummary s, bool wide) {
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
        subtitle: 'Outstanding on invoices',
        icon: Icons.schedule_outlined,
        color: AppTheme.danger,
      ),
    ];

    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in cards)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 44) / 2,
            child: c,
          ),
      ],
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
      title: 'Mix (selected range)',
      height: 240,
      child: data.isEmpty ? const ReportEmptyChart() : ReportPieChart(data: data),
    );
  }

  Widget _buildBarCard(List<PaymentReportDay> days) {
    final labels = days.map((d) {
      final parsed = DateTime.tryParse(d.date);
      return parsed != null ? _shortFmt.format(parsed) : d.date;
    }).toList();
    final collected = days.map((d) => d.collected).toList();
    final dues = days.map((d) => d.due).toList();

    return ReportSectionCard(
      title: 'Daily collected vs due',
      height: 260,
      child: days.isEmpty
          ? const ReportEmptyChart()
          : ReportBarChart(
              labels: labels,
              series: [
                (
                  name: 'Collected',
                  color: const Color(0xFF2563EB),
                  values: collected,
                ),
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
      trailing: Text(
        'Tap a day to open invoices',
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.9)),
      ),
      child: days.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: ReportEmptyChart(message: 'No payments or invoices in this range'),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Cash'), numeric: true),
                  DataColumn(label: Text('UPI'), numeric: true),
                  DataColumn(label: Text('Credit'), numeric: true),
                  DataColumn(label: Text('Advance'), numeric: true),
                  DataColumn(label: Text('Due'), numeric: true),
                  DataColumn(label: Text('Invoices'), numeric: true),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final d in days)
                    DataRow(
                      onSelectChanged: (_) => _openInvoicesForDay(d.date),
                      cells: [
                        DataCell(Text(
                          () {
                            final parsed = DateTime.tryParse(d.date);
                            return parsed != null ? _dayFmt.format(parsed) : d.date;
                          }(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )),
                        DataCell(Text(_money(d.cash))),
                        DataCell(Text(_money(d.upi))),
                        DataCell(Text(_money(d.credit))),
                        DataCell(Text(_money(d.advance))),
                        DataCell(Text(
                          _money(d.due),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: d.due > 0.009 ? AppTheme.danger : AppTheme.textPrimary,
                          ),
                        )),
                        DataCell(Text('${d.invoiceCount}')),
                        const DataCell(Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary)),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}
