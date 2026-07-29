import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_date_range_picker.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/invoice.dart';
import '../../data/models/shop.dart';
import 'report_date_range.dart';
import 'report_formatters.dart';
import 'widgets/report_charts.dart';
import '../../core/widgets/app_dropdown.dart';
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
  List<Branch> _branches = [];
  /// `null` = overall (all branches).
  int? _selectedBranchId;
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
      final results = await Future.wait([
        services.billing.listForReport(
          dateFrom: _range.fromYmd,
          dateTo: _range.toYmd,
          withItems: true,
          withPayments: true,
        ),
        services.branches.list(),
      ]);
      if (!mounted) return;
      final result = results[0] as InvoiceListResult;
      final branches = results[1] as List<Branch>;
      setState(() {
        _invoices = result.items
            .where((i) => i.status != 'cancelled' && i.status != 'draft')
            .toList();
        _branches = branches.where((b) => b.isActive).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
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

  List<Invoice> get _scopedInvoices {
    if (_selectedBranchId == null) return _invoices;
    return _invoices.where((i) => i.branchId == _selectedBranchId).toList();
  }

  List<({int? id, String name})> get _branchOptions {
    final map = <int, String>{};
    for (final b in _branches) {
      map[b.id] = b.name;
    }
    for (final inv in _invoices) {
      final id = inv.branchId;
      if (id != null && id > 0) {
        map.putIfAbsent(id, () => inv.branch?.name ?? 'Branch #$id');
      }
    }
    final list = <({int? id, String name})>[
      for (final e in map.entries) (id: e.key, name: e.value),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return [(id: null, name: 'Overall (all branches)'), ...list];
  }

  List<Invoice> get _filteredTable {
    final q = _search.text.trim().toLowerCase();
    return _scopedInvoices.where((inv) {
      if (_invoiceTab == 'paid' && !(inv.paidAmount >= inv.totalAmount && inv.totalAmount > 0)) {
        return false;
      }
      if (_invoiceTab == 'unpaid' && inv.dueAmount <= 0) return false;
      if (q.isEmpty) return true;
      final hay =
          '${inv.invoiceNumber} ${inv.customer?.name ?? 'Walk-in'} ${inv.branchName} ${inv.status}'
              .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  String get _scopeLabel {
    if (_selectedBranchId == null) return 'All branches';
    final match = _branchOptions.where((b) => b.id == _selectedBranchId);
    return match.isEmpty ? 'Selected branch' : match.first.name;
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
    final branchValue = _branchOptions.any((b) => b.id == _selectedBranchId)
        ? _selectedBranchId
        : null;

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
          AppDropdownButton<String>(
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
          AppDropdownButton<int?>(
            value: branchValue,
            items: _branchOptions
                .map(
                  (b) => DropdownMenuItem<int?>(
                    value: b.id,
                    child: Text(b.name),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedBranchId = v),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final invoices = _scopedInvoices;
    final totalSales = invoices.fold<double>(0, (s, i) => s + i.totalAmount);
    final totalPaid = invoices.fold<double>(0, (s, i) => s + i.paidAmount);
    final totalDue = invoices.fold<double>(0, (s, i) => s + i.dueAmount);
    final avg = invoices.isEmpty ? 0.0 : totalSales / invoices.length;

    final byMode = <String, double>{};
    for (final inv in invoices) {
      for (final p in inv.payments ?? const []) {
        byMode[p.paymentMode] = (byMode[p.paymentMode] ?? 0) + p.amount;
      }
    }

    final byStatus = <String, double>{};
    for (final inv in invoices) {
      byStatus[inv.status] = (byStatus[inv.status] ?? 0) + inv.totalAmount;
    }

    final byDay = <String, double>{};
    final paidByDay = <String, double>{};
    for (final inv in invoices) {
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

    final branchSeries = <({String label, double total, double paid, double due})>[];
    {
      final map = <String, ({String label, double total, double paid, double due})>{};
      for (final inv in invoices) {
        final key = inv.branchId != null ? 'id:${inv.branchId}' : 'unknown';
        final label = inv.branch?.name ?? (inv.branchId != null ? 'Branch #${inv.branchId}' : 'Unknown');
        final prev = map[key];
        map[key] = (
          label: label,
          total: (prev?.total ?? 0) + inv.totalAmount,
          paid: (prev?.paid ?? 0) + inv.paidAmount,
          due: (prev?.due ?? 0) + inv.dueAmount,
        );
      }
      branchSeries.addAll(map.values);
      branchSeries.sort((a, b) => b.total.compareTo(a.total));
    }

    final showBranchChart = _selectedBranchId == null && branchSeries.length > 1;
    final crossCount = ResponsiveLayout.isMobile(context) ? 1 : 2;
    final isOverall = _selectedBranchId == null;

    // Product type sales (Product / Service / Medicine) for the selected date range.
    const typeOrder = ['product', 'service', 'medicine'];
    final byProductType = <String, double>{
      for (final t in typeOrder) t: 0,
    };
    for (final inv in invoices) {
      for (final item in inv.items ?? const <InvoiceItem>[]) {
        final key = typeOrder.contains(item.productType) ? item.productType : 'product';
        byProductType[key] = (byProductType[key] ?? 0) + item.totalAmount;
      }
    }
    final productTypeEntries = typeOrder
        .map((t) => MapEntry(t, byProductType[t] ?? 0))
        .where((e) => e.value > 0)
        .toList();
    final hasProductTypeSales = productTypeEntries.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: ResponsiveLayout.getResponsivePadding(context),
        children: [
          if (isOverall)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Overall · $_scopeLabel',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Branch · $_scopeLabel',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
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
                subtitle: '${invoices.length} invoices · $_scopeLabel',
                icon: Icons.bar_chart_rounded,
                color: AppTheme.primary,
              ),
              ReportKpiCard(
                title: 'Total paid',
                value: formatReportCurrency(totalPaid),
                subtitle:
                    '${invoices.where((i) => i.paidAmount >= i.totalAmount && i.totalAmount > 0).length} paid',
                icon: Icons.account_balance_wallet_outlined,
                color: AppTheme.accent,
              ),
              ReportKpiCard(
                title: 'Outstanding',
                value: formatReportCurrency(totalDue),
                subtitle: '${invoices.where((i) => i.dueAmount > 0).length} due',
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
          if (showBranchChart) ...[
            const SizedBox(height: 16),
            ReportSectionCard(
              title: 'Sales by branch',
              height: 280,
              child: ReportBarChart(
                labels: branchSeries.take(8).map((e) => e.label).toList(),
                series: [
                  (
                    name: 'Sales',
                    color: AppTheme.primary,
                    values: branchSeries.take(8).map((e) => e.total).toList(),
                  ),
                  (
                    name: 'Paid',
                    color: AppTheme.accent,
                    values: branchSeries.take(8).map((e) => e.paid).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _BranchSummaryTable(rows: branchSeries),
          ],
          const SizedBox(height: 16),
          ReportSectionCard(
            title: 'Product type sales',
            trailing: Text(
              _range.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            height: 280,
            child: hasProductTypeSales
                ? ReportBarChart(
                    labels: productTypeEntries.map((e) => productTypeLabel(e.key)).toList(),
                    series: [
                      (
                        name: 'Sales',
                        color: AppTheme.primary,
                        values: productTypeEntries.map((e) => e.value).toList(),
                      ),
                    ],
                    barColors: [
                      for (var i = 0; i < productTypeEntries.length; i++) chartColorAt(i),
                    ],
                  )
                : const ReportEmptyChart(message: 'No line-item sales in this period.'),
          ),
          if (hasProductTypeSales) ...[
            const SizedBox(height: 12),
            _ProductTypeSummaryTable(rows: productTypeEntries),
          ],
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
                    (
                      name: 'Total sales',
                      color: AppTheme.primary,
                      values: days.map((d) => byDay[d] ?? 0).toList(),
                    ),
                    (
                      name: 'Paid',
                      color: AppTheme.accent,
                      values: days.map((d) => paidByDay[d] ?? 0).toList(),
                    ),
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
                  barColors: [
                    for (var i = 0; i < statusEntries.length; i++) chartColorAt(i),
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
                  barColors: const [AppTheme.accent, AppTheme.danger],
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
                          hintText: 'Search invoice, customer, branch...',
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
                    key: ValueKey('$_invoiceTab-$_selectedBranchId-${_search.text}'),
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
                        label: 'Branch',
                        flex: 1.2,
                        cellBuilder: (c, inv) => Text(inv.branchName),
                      ),
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
                          style: TextStyle(
                            color: inv.dueAmount > 0 ? AppTheme.danger : AppTheme.textSecondary,
                          ),
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

class _BranchSummaryTable extends StatelessWidget {
  const _BranchSummaryTable({required this.rows});

  final List<({String label, double total, double paid, double due})> rows;

  @override
  Widget build(BuildContext context) {
    return ReportSectionCard(
      title: 'Branch summary',
      child: Column(
        children: [
          const _BranchSummaryHeader(),
          const Divider(height: 1),
          for (final row in rows) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      row.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      formatReportCurrency(row.total),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      formatReportCurrency(row.paid),
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppTheme.accent),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      formatReportCurrency(row.due),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: row.due > 0 ? AppTheme.danger : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ProductTypeSummaryTable extends StatelessWidget {
  const _ProductTypeSummaryTable({required this.rows});

  final List<MapEntry<String, double>> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(0, (s, e) => s + e.value);
    return ReportSectionCard(
      title: 'Product type summary',
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Sales',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Share',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final row in rows) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      productTypeLabel(row.key),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      formatReportCurrency(row.value),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      total <= 0
                          ? '—'
                          : formatReportPercent((row.value / total) * 100),
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _BranchSummaryHeader extends StatelessWidget {
  const _BranchSummaryHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Branch',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Sales',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Paid',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Due',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
