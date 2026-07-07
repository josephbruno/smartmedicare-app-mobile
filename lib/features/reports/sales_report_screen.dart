import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/invoice.dart';
import 'report_date_range.dart';
import 'report_formatters.dart';
import 'widgets/report_charts.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  String _preset = 'month';
  ReportDateRange _range = ReportDateRange.preset('month');
  bool _loading = true;
  String? _error;
  List<Invoice> _invoices = [];
  String _invoiceTab = 'all';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = context.read<AppServices>();
      final result = await services.billing.listForReport(
        dateFrom: _range.fromYmd,
        dateTo: _range.toYmd,
        withPayments: true,
      );
      if (!mounted) return;
      setState(() {
        _invoices = result.items
            .where((i) => i.status != 'cancelled' && i.status != 'draft')
            .toList();
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
    });
    _load();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
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

  List<Invoice> get _filteredTable {
    final q = _search.text.trim().toLowerCase();
    return _invoices.where((inv) {
      if (_invoiceTab == 'paid' && !(inv.paidAmount >= inv.totalAmount && inv.totalAmount > 0)) {
        return false;
      }
      if (_invoiceTab == 'unpaid' && inv.dueAmount <= 0) return false;
      if (q.isEmpty) return true;
      final hay = '${inv.invoiceNumber} ${inv.customer?.name ?? 'Walk-in'} ${inv.status}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _errorView()
                    : _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Sales Report',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _preset == 'custom' ? null : _preset,
            hint: Text(_preset == 'custom' ? _range.label : 'Period'),
            items: ReportDateRange.presetOptions.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              if (v != null) _applyPreset(v);
            },
          ),
          OutlinedButton.icon(
            onPressed: _pickCustomRange,
            icon: const Icon(Icons.date_range, size: 18),
            label: Text('${_range.fromYmd} → ${_range.toYmd}'),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final totalSales = _invoices.fold<double>(0, (s, i) => s + i.totalAmount);
    final totalPaid = _invoices.fold<double>(0, (s, i) => s + i.paidAmount);
    final totalDue = _invoices.fold<double>(0, (s, i) => s + i.dueAmount);
    final avg = _invoices.isEmpty ? 0.0 : totalSales / _invoices.length;

    final byMode = <String, double>{};
    for (final inv in _invoices) {
      for (final p in inv.payments ?? const []) {
        byMode[p.paymentMode] = (byMode[p.paymentMode] ?? 0) + p.amount;
      }
    }

    final byStatus = <String, double>{};
    for (final inv in _invoices) {
      byStatus[inv.status] = (byStatus[inv.status] ?? 0) + inv.totalAmount;
    }

    final byDay = <String, double>{};
    final paidByDay = <String, double>{};
    for (final inv in _invoices) {
      final day = inv.invoiceDate.length >= 10 ? inv.invoiceDate.substring(0, 10) : inv.invoiceDate;
      byDay[day] = (byDay[day] ?? 0) + inv.totalAmount;
      paidByDay[day] = (paidByDay[day] ?? 0) + inv.paidAmount;
    }
    final days = byDay.keys.toList()..sort();
    final dayLabels = days.map(shortDateLabel).toList();

    final donutData = byMode.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final statusEntries = byStatus.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final crossCount = ResponsiveLayout.isMobile(context) ? 1 : 2;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: ResponsiveLayout.getResponsivePadding(context),
        children: [
          GridView.count(
            crossAxisCount: ResponsiveLayout.isMobile(context) ? 2 : 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: ResponsiveLayout.isMobile(context) ? 1.35 : 1.8,
            children: [
              ReportKpiCard(
                title: 'Total sales',
                value: formatReportCurrency(totalSales),
                subtitle: '${_invoices.length} invoices',
                icon: Icons.bar_chart_rounded,
                color: AppTheme.primary,
              ),
              ReportKpiCard(
                title: 'Total paid',
                value: formatReportCurrency(totalPaid),
                subtitle: '${_invoices.where((i) => i.paidAmount >= i.totalAmount && i.totalAmount > 0).length} paid',
                icon: Icons.account_balance_wallet_outlined,
                color: AppTheme.accent,
              ),
              ReportKpiCard(
                title: 'Outstanding',
                value: formatReportCurrency(totalDue),
                subtitle: '${_invoices.where((i) => i.dueAmount > 0).length} due',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.danger,
              ),
              ReportKpiCard(
                title: 'Avg invoice',
                value: formatReportCurrency(avg),
                subtitle: _range.label,
                icon: Icons.receipt_long_outlined,
                color: AppTheme.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: crossCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: ResponsiveLayout.isMobile(context) ? 0.95 : 1.35,
            children: [
              ReportSectionCard(
                title: 'Sales trend',
                height: 260,
                child: ReportLineChart(
                  labels: dayLabels,
                  series: [
                    (name: 'Total sales', color: AppTheme.primary, values: days.map((d) => byDay[d] ?? 0).toList()),
                    (name: 'Paid', color: AppTheme.accent, values: days.map((d) => paidByDay[d] ?? 0).toList()),
                  ],
                ),
              ),
              ReportSectionCard(
                title: 'Payment mode breakdown',
                height: 260,
                child: ReportDonutChart(
                  data: [
                    for (var i = 0; i < donutData.length; i++)
                      ChartDatum(
                        label: paymentModeLabel(donutData[i].key),
                        value: donutData[i].value,
                        color: chartColorAt(i),
                      ),
                  ],
                  centerLabel: 'Total',
                  centerValue: formatReportCurrencyCompact(totalSales),
                ),
              ),
              ReportSectionCard(
                title: 'Sales by status',
                height: 260,
                child: ReportBarChart(
                  labels: statusEntries.map((e) => titleCaseStatus(e.key)).toList(),
                  series: [
                    (
                      name: 'Amount',
                      color: AppTheme.primary,
                      values: statusEntries.map((e) => e.value).toList(),
                    ),
                  ],
                ),
              ),
              ReportSectionCard(
                title: 'Paid vs due (bar)',
                height: 260,
                child: ReportBarChart(
                  labels: const ['Paid', 'Due'],
                  series: [
                    (name: 'Amount', color: AppTheme.accent, values: [totalPaid, totalDue]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ReportSectionCard(
            title: 'Invoice details',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          hintText: 'Search invoice or customer...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'paid', label: Text('Paid')),
                        ButtonSegment(value: 'unpaid', label: Text('Due')),
                      ],
                      selected: {_invoiceTab},
                      onSelectionChanged: (s) => setState(() => _invoiceTab = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 420,
                  child: AppPaginatedTable<Invoice>(
                    key: ValueKey('$_invoiceTab-${_search.text}'),
                    showPerPageSelector: false,
                    perPage: 15,
                    emptyMessage: 'No invoices in this period.',
                    loadPage: ({required page, required perPage}) async {
                      final rows = _filteredTable;
                      final slice = paginateList(rows, page: page, perPage: perPage);
                      return (items: slice.items, meta: slice.meta);
                    },
                    onRowTap: (inv) => context.push('/invoices/${inv.id}'),
                    columns: [
                      TableColumnDef(
                        label: 'Invoice #',
                        flex: 1.2,
                        cellBuilder: (c, inv) => Text(
                          inv.invoiceNumber,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TableColumnDef(label: 'Date', flex: 1, cellBuilder: (c, inv) => Text(inv.displayDate)),
                      TableColumnDef(
                        label: 'Customer',
                        flex: 1.3,
                        cellBuilder: (c, inv) => Text(inv.customer?.name ?? 'Walk-in'),
                      ),
                      TableColumnDef(
                        label: 'Amount',
                        flex: 1,
                        align: TextAlign.right,
                        cellBuilder: (c, inv) => Text(formatReportCurrency(inv.totalAmount)),
                      ),
                      TableColumnDef(
                        label: 'Paid',
                        flex: 1,
                        align: TextAlign.right,
                        cellBuilder: (c, inv) => Text(
                          formatReportCurrency(inv.paidAmount),
                          style: const TextStyle(color: AppTheme.accent),
                        ),
                      ),
                      TableColumnDef(
                        label: 'Due',
                        flex: 1,
                        align: TextAlign.right,
                        cellBuilder: (c, inv) => Text(
                          formatReportCurrency(inv.dueAmount),
                          style: TextStyle(color: inv.dueAmount > 0 ? AppTheme.danger : AppTheme.textSecondary),
                        ),
                      ),
                      TableColumnDef(
                        label: 'Status',
                        flex: 0.9,
                        align: TextAlign.center,
                        cellBuilder: (c, inv) => Text(titleCaseStatus(inv.status)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
