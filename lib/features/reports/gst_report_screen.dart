import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/gst_utils.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/invoice.dart';
import 'report_date_range.dart';
import 'report_formatters.dart';
import 'widgets/report_charts.dart';
import '../../core/widgets/app_dropdown.dart';
class GstReportScreen extends StatefulWidget {
  const GstReportScreen({super.key});

  @override
  State<GstReportScreen> createState() => _GstReportScreenState();
}

class _GstReportScreenState extends State<GstReportScreen> with SingleTickerProviderStateMixin {
  String _preset = 'month';
  ReportDateRange _range = ReportDateRange.preset('month');
  bool _loading = true;
  String? _error;
  List<Invoice> _invoices = [];
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<AppServices>().billing.listForReport(
            dateFrom: _range.fromYmd,
            dateTo: _range.toYmd,
            withItems: true,
          );
      if (!mounted) return;
      setState(() {
        _invoices = result.items.where((i) => i.status != 'cancelled').toList();
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

  List<GstItemInput> get _allItems {
    return _invoices.expand((inv) => inv.items ?? const <InvoiceItem>[]).map((item) {
      return GstItemInput(
        hsnCode: item.hsnCode,
        taxableAmount: item.taxableAmount,
        gstRate: item.gstRate,
        cgstAmount: item.cgstAmount,
        sgstAmount: item.sgstAmount,
        igstAmount: item.igstAmount,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildToolbar(),
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

  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('GST Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          AppDropdownButton<String>(
            value: _preset,
            items: ReportDateRange.gstPresetOptions.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              if (v != null) _applyPreset(v);
            },
          ),
          Text(
            '${_range.fromYmd} → ${_range.toYmd}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final hsnSummary = GstUtils.generateGSTSummary(_allItems);
    final slabs = GstUtils.slabBreakdown(hsnSummary);

    final taxable = hsnSummary.fold<double>(0, (s, r) => s + r.taxableValue);
    final cgst = hsnSummary.fold<double>(0, (s, r) => s + r.cgst);
    final sgst = hsnSummary.fold<double>(0, (s, r) => s + r.sgst);
    final igst = hsnSummary.fold<double>(0, (s, r) => s + r.igst);
    final totalGst = cgst + sgst + igst;

    final b2b = _invoices.where((i) => (i.customer?.gstin ?? '').isNotEmpty).toList();
    final b2c = _invoices.where((i) => (i.customer?.gstin ?? '').isEmpty).toList();
    final tableInvoices = _tabs.index == 1 ? b2b : _tabs.index == 2 ? b2c : _invoices;

    final topHsn = [...hsnSummary]..sort((a, b) => b.taxableValue.compareTo(a.taxableValue));
    final hsnChart = topHsn.take(6).toList();

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
                title: 'Taxable value',
                value: formatReportCurrency(taxable),
                subtitle: '${hsnSummary.length} HSN lines',
                icon: Icons.receipt_outlined,
                color: AppTheme.primary,
              ),
              ReportKpiCard(
                title: 'Total CGST',
                value: formatReportCurrency(cgst),
                subtitle: 'Central GST',
                icon: Icons.pie_chart_outline,
                color: const Color(0xFF8B5CF6),
              ),
              ReportKpiCard(
                title: 'Total SGST',
                value: formatReportCurrency(sgst),
                subtitle: 'State GST',
                icon: Icons.pie_chart,
                color: const Color(0xFF0EA5E9),
              ),
              ReportKpiCard(
                title: 'Total GST',
                value: formatReportCurrency(totalGst),
                subtitle: igst > 0 ? 'Includes IGST ${formatReportCurrency(igst)}' : 'CGST + SGST',
                icon: Icons.account_balance_outlined,
                color: AppTheme.accent,
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
                title: 'GST composition (pie)',
                height: 240,
                child: ReportPieChart(
                  data: [
                    if (cgst > 0) const ChartDatum(label: 'CGST', value: 0, color: Color(0xFF8B5CF6)),
                    if (sgst > 0) const ChartDatum(label: 'SGST', value: 0, color: Color(0xFF0EA5E9)),
                    if (igst > 0) const ChartDatum(label: 'IGST', value: 0, color: Color(0xFFF59E0B)),
                  ].map((d) {
                    final value = d.label == 'CGST'
                        ? cgst
                        : d.label == 'SGST'
                            ? sgst
                            : igst;
                    return ChartDatum(label: d.label, value: value, color: d.color);
                  }).where((d) => d.value > 0).toList(),
                ),
              ),
              ReportSectionCard(
                title: 'GST by rate slab (donut)',
                height: 240,
                child: ReportDonutChart(
                  data: [
                    for (var i = 0; i < slabs.length; i++)
                      ChartDatum(
                        label: '${slabs[i].rate.toStringAsFixed(0)}% GST',
                        value: slabs[i].totalGst,
                        color: chartColorAt(i),
                      ),
                  ],
                  centerLabel: 'Total GST',
                  centerValue: formatReportCurrencyCompact(totalGst),
                ),
              ),
              ReportSectionCard(
                title: 'Tax slab taxable value (bar)',
                height: 240,
                child: ReportBarChart(
                  labels: slabs.map((s) => '${s.rate.toStringAsFixed(0)}%').toList(),
                  series: [
                    (
                      name: 'Taxable',
                      color: AppTheme.primary,
                      values: slabs.map((s) => s.taxableValue).toList(),
                    ),
                    (
                      name: 'GST',
                      color: AppTheme.accent,
                      values: slabs.map((s) => s.totalGst).toList(),
                    ),
                  ],
                ),
              ),
              ReportSectionCard(
                title: 'Top HSN codes',
                height: 240,
                child: ReportHorizontalBarChart(
                  data: [
                    for (var i = 0; i < hsnChart.length; i++)
                      ChartDatum(
                        label: hsnChart[i].hsn,
                        value: hsnChart[i].taxableValue,
                        color: chartColorAt(i),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ReportSectionCard(
            title: 'HSN-wise GST summary (GSTR-1 style)',
            child: SizedBox(
              height: 320,
              child: AppPaginatedTable<GstSummaryLine>(
                showPerPageSelector: false,
                perPage: 10,
                emptyMessage: 'No GST data for this period.',
                loadPage: ({required page, required perPage}) async {
                  final slice = paginateList(hsnSummary, page: page, perPage: perPage);
                  return (items: slice.items, meta: slice.meta);
                },
                columns: [
                  TableColumnDef(label: 'HSN', flex: 1, cellBuilder: (c, r) => Text(r.hsn)),
                  TableColumnDef(
                    label: 'Rate',
                    flex: 0.7,
                    align: TextAlign.center,
                    cellBuilder: (c, r) => Text('${r.gstRate.toStringAsFixed(0)}%'),
                  ),
                  TableColumnDef(
                    label: 'Taxable',
                    flex: 1,
                    align: TextAlign.right,
                    cellBuilder: (c, r) => Text(formatReportCurrency(r.taxableValue)),
                  ),
                  TableColumnDef(
                    label: 'CGST',
                    flex: 1,
                    align: TextAlign.right,
                    cellBuilder: (c, r) => Text(formatReportCurrency(r.cgst)),
                  ),
                  TableColumnDef(
                    label: 'SGST',
                    flex: 1,
                    align: TextAlign.right,
                    cellBuilder: (c, r) => Text(formatReportCurrency(r.sgst)),
                  ),
                  TableColumnDef(
                    label: 'IGST',
                    flex: 1,
                    align: TextAlign.right,
                    cellBuilder: (c, r) => Text(r.igst > 0 ? formatReportCurrency(r.igst) : '—'),
                  ),
                  TableColumnDef(
                    label: 'Total GST',
                    flex: 1,
                    align: TextAlign.right,
                    cellBuilder: (c, r) => Text(
                      formatReportCurrency(r.totalGst),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ReportSectionCard(
            title: 'Invoice breakdown',
            child: Column(
              children: [
                TabBar(
                  controller: _tabs,
                  onTap: (_) => setState(() {}),
                  tabs: [
                    Tab(text: 'All (${_invoices.length})'),
                    Tab(text: 'B2B (${b2b.length})'),
                    Tab(text: 'B2C (${b2c.length})'),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 380,
                  child: AppPaginatedTable<Invoice>(
                    key: ValueKey(_tabs.index),
                    showPerPageSelector: false,
                    perPage: 12,
                    emptyMessage: 'No invoices.',
                    loadPage: ({required page, required perPage}) async {
                      final slice = paginateList(tableInvoices, page: page, perPage: perPage);
                      return (items: slice.items, meta: slice.meta);
                    },
                    onRowTap: (inv) => context.push('/invoices/${inv.id}'),
                    columns: [
                      TableColumnDef(
                        label: 'Invoice #',
                        flex: 1.1,
                        cellBuilder: (c, inv) => Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      TableColumnDef(label: 'Date', flex: 1, cellBuilder: (c, inv) => Text(inv.displayDate)),
                      TableColumnDef(
                        label: 'Customer',
                        flex: 1.2,
                        cellBuilder: (c, inv) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(inv.customer?.name ?? 'Walk-in'),
                            if ((inv.customer?.gstin ?? '').isNotEmpty)
                              Text(
                                inv.customer!.gstin!,
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      TableColumnDef(
                        label: 'Taxable',
                        flex: 1,
                        align: TextAlign.right,
                        cellBuilder: (c, inv) {
                          final t = (inv.items ?? const []).fold<double>(0, (s, i) => s + i.taxableAmount);
                          return Text(formatReportCurrency(t));
                        },
                      ),
                      TableColumnDef(
                        label: 'CGST',
                        flex: 0.9,
                        align: TextAlign.right,
                        cellBuilder: (c, inv) => Text(formatReportCurrency(inv.cgstAmount)),
                      ),
                      TableColumnDef(
                        label: 'SGST',
                        flex: 0.9,
                        align: TextAlign.right,
                        cellBuilder: (c, inv) => Text(formatReportCurrency(inv.sgstAmount)),
                      ),
                      TableColumnDef(
                        label: 'Total',
                        flex: 1,
                        align: TextAlign.right,
                        cellBuilder: (c, inv) => Text(
                          formatReportCurrency(inv.totalAmount),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
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
