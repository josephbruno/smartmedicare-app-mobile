import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/ist.dart';
import '../../core/utils/save_file.dart';
import '../../core/widgets/app_date_range_picker.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../core/widgets/web_page.dart';
import '../../data/models/api_response.dart';
import '../../data/models/invoice.dart';

/// Invoice list — mirrors `frontend/src/pages/billing/InvoiceListPage.vue`:
/// KPIs (total / paid / due / count), search + status + date range, sortable
/// table with payment-mode lines and cash change under Paid, CSV export.
class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({
    super.key,
    this.initialDateFrom,
    this.initialDateTo,
    this.initialSearch,
  });

  /// Optional `YYYY-MM-DD` from payment report day drill-down.
  final String? initialDateFrom;
  final String? initialDateTo;

  /// Prefilled search (customer detail → "View Billing").
  final String? initialSearch;

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _appliedSearch = '';
  String _status = 'all';
  String? _dateFrom;
  String? _dateTo;
  String? _sortBy;
  bool _sortAsc = false;
  int _reloadToken = 0;
  PaginationMetaView _meta = const PaginationMetaView();
  bool _exporting = false;

  static const _statusOptions = {
    'paid': 'Paid',
    'partial': 'Partial',
    'confirmed': 'Confirmed',
    'draft': 'Draft',
    'on_hold': 'On Hold',
    'cancelled': 'Cancelled',
  };
  static const _modeLabels = {
    'cash': 'Cash',
    'upi': 'UPI',
    'advance': 'Advance',
    'card': 'Card',
    'bank_transfer': 'Bank',
    'cheque': 'Cheque',
    'loyalty_points': 'Points',
    'credit': 'Credit',
    'other': 'Other',
  };

  static final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _inrCompact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.initialDateFrom;
    _dateTo = widget.initialDateTo;
    _appliedSearch = widget.initialSearch?.trim() ?? '';
    _search.text = _appliedSearch;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _reloadToken++);

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _appliedSearch = v.trim();
      _reload();
    });
  }

  bool get _hasFilters =>
      _appliedSearch.isNotEmpty || _status != 'all' || _dateFrom != null || _sortBy != null;

  void _reset() {
    _search.clear();
    _appliedSearch = '';
    _status = 'all';
    _dateFrom = null;
    _dateTo = null;
    _sortBy = null;
    _sortAsc = false;
    _reload();
  }

  void _onSort(String key) {
    if (_sortBy == key) {
      _sortAsc = !_sortAsc;
    } else {
      _sortBy = key;
      _sortAsc = false;
    }
    _reload();
  }

  Future<void> _pickRange() async {
    final today = nowIst();
    final range = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: _dateFrom == null
          ? null
          : DateTimeRange(start: DateTime.parse(_dateFrom!), end: DateTime.parse(_dateTo ?? _dateFrom!)),
    );
    if (range == null) return;
    final f = DateFormat('yyyy-MM-dd');
    _dateFrom = f.format(range.start);
    _dateTo = f.format(range.end);
    _reload();
  }

  void _onMore(String key) {
    switch (key) {
      case 'due':
        _status = 'partial';
      case 'today':
        _dateFrom = todayIst();
        _dateTo = todayIst();
      case 'refresh':
        break;
    }
    _reload();
  }

  Future<({List<Invoice> items, PaginationMeta? meta})> _load({
    required int page,
    required int perPage,
    bool withStats = true,
  }) {
    final auth = context.read<AuthSession>();
    return context.read<AppServices>().billing.listPaginated(
          page: page,
          perPage: perPage,
          status: _status,
          search: _appliedSearch,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
          branchId: auth.currentBranchId,
          sortBy: _sortBy,
          sortAsc: _sortAsc,
          withStats: withStats,
        );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final res = await _load(page: 1, perPage: 1000, withStats: false);
      if (res.items.isEmpty) {
        if (mounted) AppMessenger.error(context, 'Nothing to export');
        return;
      }
      final saved = await saveCsv(
        'invoices-${todayIst()}.csv',
        const ['Invoice #', 'Date', 'Customer', 'Phone', 'Type', 'Amount', 'Paid', 'Due', 'Status'],
        res.items.map((i) => [
              i.invoiceNumber,
              i.invoiceDate.length >= 10 ? i.invoiceDate.substring(0, 10) : i.invoiceDate,
              i.customer?.name ?? 'Walk-in',
              i.customer?.phone,
              _title(i.type),
              i.totalAmount.toStringAsFixed(2),
              i.paidAmount.toStringAsFixed(2),
              i.dueAmount.toStringAsFixed(2),
              _title(i.status),
            ]),
      );
      if (mounted && saved != null) AppMessenger.success(context, 'Exported ${res.items.length} invoices');
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _printPdf(Invoice inv) async {
    try {
      final bytes = await context.read<AppServices>().billing.getPdfBytes(inv.id);
      if (bytes.isEmpty) throw Exception('empty PDF');
      await Printing.layoutPdf(
        name: inv.invoiceNumber,
        onLayout: (_) async => Uint8List.fromList(bytes),
      );
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Could not load the invoice PDF: $e');
    }
  }

  void _rowMenu(String key, Invoice inv) {
    switch (key) {
      case 'return':
        context.push('/invoices/${inv.id}/return');
      case 'pdf':
        _printPdf(inv);
      case 'call':
        launchUrl(Uri.parse('tel:${inv.customer?.phone}'));
      case 'customer':
        context.push('/customers/${inv.customer?.id}');
      default:
        context.go('/invoices/${inv.id}');
    }
  }

  static String _title(String s) => s
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// One line per payment mode (merged), with cash change-return.
  List<({String label, double change})> _paymentLines(Invoice inv) {
    final byMode = <String, double>{};
    for (final p in inv.payments ?? const <InvoicePayment>[]) {
      if (p.status == 'cancelled') continue;
      byMode[p.paymentMode] = (byMode[p.paymentMode] ?? 0) + (p.changeReturn ?? 0);
    }
    return [
      for (final e in byMode.entries) (label: _modeLabels[e.key] ?? _title(e.key), change: e.value),
    ];
  }

  List<KpiData> _kpis() {
    final total = _meta.summaryNum('total_amount');
    final paid = _meta.summaryNum('paid_amount', fallback: 'total_paid');
    final due = _meta.summaryNum('due_amount', fallback: 'total_outstanding');
    int pct(double part) => total == 0 ? 0 : (part / total * 100).round();
    String change(String k) {
      final c = _meta.change(k);
      return c == null ? '— vs last month' : '${c >= 0 ? '▲' : '▼'} ${c.abs()}% vs last month';
    }

    return [
      KpiData(
          label: 'Total Amount',
          value: _inrCompact.format(total),
          icon: Icons.shopping_bag_outlined,
          tone: KpiTone.purple,
          sub: change('total'),
          subUp: (_meta.change('total') ?? 0) > 0,
          series: _meta.series('total', last: 7)),
      KpiData(
          label: 'Paid Amount',
          value: _inrCompact.format(paid),
          icon: Icons.event_available_outlined,
          tone: KpiTone.green,
          sub: '${pct(paid)}% of total amount',
          series: _meta.series('paid')),
      KpiData(
          label: 'Due Amount',
          value: _inrCompact.format(due),
          icon: Icons.schedule_outlined,
          tone: KpiTone.orange,
          sub: '${pct(due)}% of total amount',
          series: _meta.series('due')),
      KpiData(
          label: 'Total Invoices',
          value: '${_meta.total}',
          icon: Icons.description,
          tone: KpiTone.blue,
          sub: change('invoices'),
          subUp: (_meta.change('invoices') ?? 0) > 0,
          series: _meta.series('invoices', last: 7)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.invoicesCreate);
    final rangeLabel = _dateFrom == null
        ? 'Start Date → End Date'
        : '${formatDateIst(_dateFrom)} → ${formatDateIst(_dateTo ?? _dateFrom)}';

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: 'Invoices',
        subtitle:
            'Manage and track all clinic invoices · ${auth.currentShop?.name ?? 'Clinic'} - ${auth.currentBranch?.name ?? 'Main Branch'}',
        icon: Icons.description_outlined,
        actions: [
          OutlinedButton.icon(
            onPressed: _exporting ? null : _export,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(_exporting ? 'Exporting…' : 'Export'),
          ),
          if (canCreate) FilledButton(onPressed: () => context.go('/pos'), child: const Text('New Invoice')),
        ],
        kpis: _kpis(),
        filters: FilterCard(
          searchController: _search,
          searchHint: 'Search invoice #, customer name or phone...',
          onSearchChanged: _onSearch,
          filters: [
            FilterSelect<String>(
              hint: 'All Status',
              options: _statusOptions,
              value: _status == 'all' ? null : _status,
              onChanged: (v) {
                _status = v ?? 'all';
                _reload();
              },
            ),
          ],
          trailing: [
            SizedBox(
              width: 260,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _pickRange,
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.date_range_outlined, size: 18),
                    suffixIcon: _dateFrom == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              _dateFrom = null;
                              _dateTo = null;
                              _reload();
                            },
                          ),
                  ),
                  child: Text(rangeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, color: _dateFrom == null ? AppTokens.placeholder : AppTokens.text1)),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More options',
              onSelected: _onMore,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'due', child: Text('Only unpaid / due')),
                PopupMenuItem(value: 'today', child: Text('Only today')),
                PopupMenuDivider(),
                PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              ],
              child: const TableIconButton(icon: Icons.more_vert, plain: true, onPressed: null),
            ),
          ],
          onReset: _reset,
          resetEnabled: _hasFilters,
        ),
        body: AppPaginatedTable<Invoice>(
          key: ValueKey('invoices-$_reloadToken-${auth.currentBranchId}'),
          perPage: 10,
          emptyMessage: 'No invoices found',
          loadPage: ({required page, required perPage}) => _load(page: page, perPage: perPage),
          onLoaded: (m) {
            if (mounted) setState(() => _meta = PaginationMetaView(m));
          },
          sortKey: _sortBy,
          sortAsc: _sortAsc,
          onSort: _onSort,
          onRowTap: (inv) => context.go('/invoices/${inv.id}'),
          mobileItemBuilder: (context, inv) => _InvoiceTile(
            invoice: inv,
            money: _inr.format,
            onTap: () => context.go('/invoices/${inv.id}'),
          ),
          columns: [
            TableColumnDef(
              label: 'Invoice #',
              flex: 1.4,
              minWidth: 140,
              sortKey: 'invoice_number',
              cellBuilder: (_, inv) => Text(inv.invoiceNumber,
                  style: const TextStyle(color: AppTokens.primary, fontWeight: FontWeight.w600)),
            ),
            TableColumnDef(
              label: 'Date',
              flex: 1.1,
              minWidth: 110,
              sortKey: 'invoice_date',
              cellBuilder: (_, inv) => Text(formatDateIst(inv.invoiceDate)),
            ),
            TableColumnDef(
              label: 'Customer',
              flex: 2,
              minWidth: 190,
              sortKey: 'customer',
              cellBuilder: (_, inv) => Row(children: [
                InitialsAvatar(inv.customer?.name ?? 'Walk In', size: 34),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(inv.customer?.name ?? 'Walk-in',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if ((inv.customer?.phone ?? '').isNotEmpty)
                        Text(inv.customer!.phone, style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                    ],
                  ),
                ),
              ]),
            ),
            TableColumnDef(
              label: 'Amount (₹)',
              flex: 1.2,
              minWidth: 120,
              align: TextAlign.right,
              sortKey: 'total_amount',
              cellBuilder: (_, inv) =>
                  Text(_inr.format(inv.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            TableColumnDef(
              label: 'Paid (₹)',
              flex: 1.4,
              minWidth: 140,
              align: TextAlign.right,
              sortKey: 'paid_amount',
              cellBuilder: (_, inv) => Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_inr.format(inv.paidAmount),
                      style: const TextStyle(color: AppTokens.success, fontWeight: FontWeight.w600)),
                  for (final line in _paymentLines(inv))
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: line.label, style: const TextStyle(color: AppTokens.text3)),
                        if (line.change > 0)
                          TextSpan(
                              text: '  Change ${_inr.format(line.change)}',
                              style: const TextStyle(color: AppTokens.warning, fontWeight: FontWeight.w600)),
                      ]),
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
            ),
            TableColumnDef(
              label: 'Due (₹)',
              flex: 1.1,
              minWidth: 110,
              align: TextAlign.right,
              sortKey: 'due_amount',
              cellBuilder: (_, inv) {
                final cancelled = inv.status == 'cancelled';
                return Text(
                  cancelled ? '—' : _inr.format(inv.dueAmount),
                  style: TextStyle(
                    color: !cancelled && inv.dueAmount > 0 ? AppTokens.error : AppTokens.text3,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
            TableColumnDef(
              label: 'Status',
              flex: 1.1,
              minWidth: 120,
              sortKey: 'status',
              cellBuilder: (_, inv) => _statusPill(inv.status),
            ),
            TableColumnDef(
              label: 'Actions',
              flex: 1,
              minWidth: 100,
              cellBuilder: (_, inv) => Row(mainAxisSize: MainAxisSize.min, children: [
                TableIconButton(
                    icon: Icons.visibility_outlined, tooltip: 'View', onPressed: () => context.go('/invoices/${inv.id}')),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'More actions for ${inv.invoiceNumber}',
                  onSelected: (k) => _rowMenu(k, inv),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'view', child: Text('View details')),
                    if (inv.type == 'tax_invoice' &&
                        const ['paid', 'partial', 'confirmed'].contains(inv.status) &&
                        canCreate)
                      const PopupMenuItem(value: 'return', child: Text('Sale return')),
                    const PopupMenuItem(value: 'pdf', child: Text('Print / PDF')),
                    if ((inv.customer?.phone ?? '').isNotEmpty) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'call', child: Text('Call customer')),
                    ],
                    if (inv.customer != null) const PopupMenuItem(value: 'customer', child: Text('Open customer')),
                  ],
                  child: const TableIconButton(icon: Icons.more_vert, plain: true, onPressed: null),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _statusPill(String status) {
  final (tone, icon) = switch (status) {
    'paid' => (PillTone.green, Icons.check_circle),
    'partial' => (PillTone.amber, Icons.timelapse),
    'confirmed' => (PillTone.blue, Icons.verified_outlined),
    'cancelled' => (PillTone.red, Icons.cancel),
    'on_hold' => (PillTone.purple, Icons.pause_circle_outline),
    _ => (PillTone.grey, Icons.edit_note),
  };
  final label = status.replaceAll('_', ' ');
  return StatusPill(label.isEmpty ? '—' : '${label[0].toUpperCase()}${label.substring(1)}', tone: tone, icon: icon);
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice, required this.money, required this.onTap});

  final Invoice invoice;
  final String Function(num) money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final cancelled = inv.status == 'cancelled';
    Widget amount(String label, String value, Color color) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTokens.text3)),
            Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppTokens.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Text(inv.invoiceNumber,
                      style: const TextStyle(color: AppTokens.primary, fontWeight: FontWeight.w700)),
                ),
                _statusPill(inv.status),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                InitialsAvatar(inv.customer?.name ?? 'Walk In', size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(inv.customer?.name ?? 'Walk-in', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(formatDateIst(inv.invoiceDate), style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                  ]),
                ),
              ]),
              const Divider(height: 20),
              Row(children: [
                amount('Amount', money(inv.totalAmount), AppTokens.text1),
                amount('Paid', money(inv.paidAmount), AppTokens.success),
                amount('Due', cancelled ? '—' : money(inv.dueAmount),
                    !cancelled && inv.dueAmount > 0 ? AppTokens.error : AppTokens.text3),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
