import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_date_range_picker.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/invoice.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  String _selectedFilter = 'all';
  final _search = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                  _FilterChip(
                    label: 'All',
                    selected: _selectedFilter == 'all',
                    onSelected: () => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Paid',
                    selected: _selectedFilter == 'paid',
                    onSelected: () => setState(() => _selectedFilter = 'paid'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Unpaid',
                    selected: _selectedFilter == 'unpaid',
                    onSelected: () => setState(() => _selectedFilter = 'unpaid'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Cancelled',
                    selected: _selectedFilter == 'cancelled',
                    onSelected: () => setState(() => _selectedFilter = 'cancelled'),
                  ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          hintText: 'Invoice #…',
                          isDense: true,
                          prefixIcon: Icon(Icons.search, size: 20),
                        ),
                        onSubmitted: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                  ],
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
                  flex: 1.5,
                  cellBuilder: (c, inv) =>
                      Text(inv.customer?.name ?? 'Walk-in'),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.textSecondary,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      ),
      showCheckmark: false,
    );
  }
}
