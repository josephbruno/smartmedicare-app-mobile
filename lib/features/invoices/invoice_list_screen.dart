import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_date_range_picker.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/invoice.dart';
import '../reports/report_formatters.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({
    super.key,
    this.initialDateFrom,
    this.initialDateTo,
  });

  /// Optional `YYYY-MM-DD` from payment report day drill-down.
  final String? initialDateFrom;
  final String? initialDateTo;

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  String _selectedFilter = 'all';
  final _search = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _dateFrom = DateTime.tryParse(widget.initialDateFrom ?? '');
    _dateTo = DateTime.tryParse(widget.initialDateTo ?? '');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: now,
            ),
    );
    if (range != null) {
      setState(() {
        _dateFrom = range.start;
        _dateTo = range.end;
      });
    }
  }

  String? get _dateFromStr =>
      _dateFrom != null ? _dateFrom!.toIso8601String().substring(0, 10) : null;

  String? get _dateToStr =>
      _dateTo != null ? _dateTo!.toIso8601String().substring(0, 10) : null;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppTheme.accent;
      case 'pending':
      case 'unpaid':
        return AppTheme.warning;
      case 'cancelled':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search invoice #, customer name or mobile…',
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => setState(() {}),
                    onChanged: (_) {
                      // Remount table when user finishes typing via search action;
                      // keep live clear when emptied.
                      if (_search.text.trim().isEmpty) setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: AppDropdownButtonFormField<String>(
                    value: _selectedFilter,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                      DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedFilter = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(
                    _dateFrom != null && _dateTo != null
                        ? '${_dateFromStr!} – ${_dateToStr!}'
                        : 'Date range',
                  ),
                ),
                if (_dateFrom != null)
                  IconButton(
                    tooltip: 'Clear dates',
                    onPressed: () => setState(() {
                      _dateFrom = null;
                      _dateTo = null;
                    }),
                    icon: const Icon(Icons.clear),
                  ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: AppPaginatedTable<Invoice>(
              key: ValueKey('$_selectedFilter-${_search.text}-$_dateFromStr-$_dateToStr'),
              emptyMessage: 'No invoices found for this filter.',
              loadPage: ({required page, required perPage}) =>
                  services.billing.listPaginated(
                    page: page,
                    perPage: perPage,
                    status: _selectedFilter,
                    search: _search.text.trim().isNotEmpty ? _search.text.trim() : null,
                    dateFrom: _dateFromStr,
                    dateTo: _dateToStr,
                  ),
              onRowTap: (inv) => context.go('/invoices/${inv.id}'),
              columns: [
                TableColumnDef(
                  label: 'Invoice #',
                  flex: 1.2,
                  cellBuilder: (c, inv) => Text(
                    inv.invoiceNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TableColumnDef(
                  label: 'Customer',
                  flex: 1.4,
                  cellBuilder: (c, inv) =>
                      Text(inv.customer?.name ?? 'Walk-in'),
                ),
                TableColumnDef(
                  label: 'Branch',
                  flex: 1.3,
                  cellBuilder: (c, inv) => Text(
                    inv.branchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                TableColumnDef(
                  label: 'Date',
                  flex: 1,
                  cellBuilder: (c, inv) => Text(inv.displayDate),
                ),
                TableColumnDef(
                  label: 'Status',
                  flex: 0.9,
                  align: TextAlign.center,
                  cellBuilder: (c, inv) {
                    final color = _getStatusColor(inv.status);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        inv.status.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                TableColumnDef(
                  label: 'Amount',
                  flex: 1,
                  align: TextAlign.right,
                  cellBuilder: (c, inv) => Text(
                    '₹${inv.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TableColumnDef(
                  label: 'Payments',
                  flex: 1.5,
                  cellBuilder: (c, inv) {
                    final breakdown = inv.paymentBreakdownSummary(
                      modeLabel: paymentModeLabel,
                    );
                    if (breakdown.isEmpty) {
                      return const Text(
                        '—',
                        style: TextStyle(color: AppTheme.textSecondary),
                      );
                    }
                    return Text(
                      breakdown,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
                TableColumnDef(
                  label: 'Cash recv',
                  flex: 1,
                  align: TextAlign.right,
                  cellBuilder: (c, inv) {
                    final cash = inv.cashReceivedTotal;
                    if (cash == null || cash <= 0.009) {
                      return const Text(
                        '',
                        style: TextStyle(color: AppTheme.textSecondary),
                      );
                    }
                    return Text(
                      '₹${cash.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    );
                  },
                ),
                TableColumnDef(
                  label: 'Change',
                  flex: 0.9,
                  align: TextAlign.right,
                  cellBuilder: (c, inv) {
                    final change = inv.changeReturnTotal;
                    if (change == null || change <= 0.009) {
                      return const Text(
                        '',
                        style: TextStyle(color: AppTheme.textSecondary),
                      );
                    }
                    return Text(
                      '₹${change.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent,
                      ),
                    );
                  },
                ),
                TableColumnDef(
                  label: 'Balance due',
                  flex: 1,
                  align: TextAlign.right,
                  cellBuilder: (c, inv) {
                    if (!inv.hasBalanceDue) {
                      return const Text(
                        '',
                        style: TextStyle(color: AppTheme.textSecondary),
                      );
                    }
                    return Text(
                      '₹${inv.dueAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warning,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
