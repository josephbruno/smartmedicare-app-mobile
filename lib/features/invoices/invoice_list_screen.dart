import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
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
    final isSuperAdmin = context.watch<AuthSession>().isSuperAdmin;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Search invoice #, customer name or mobile…',
                      hintStyle: TextStyle(fontSize: 13),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: Icon(Icons.search, size: 18),
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
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: AppDropdownButtonFormField<String>(
                    value: _selectedFilter,
                    isDense: true,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      labelStyle: TextStyle(fontSize: 12),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range_outlined, size: 16),
                  label: Text(
                    _dateFrom != null && _dateTo != null
                        ? '${_dateFromStr!} – ${_dateToStr!}'
                        : 'Date range',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                if (_dateFrom != null)
                  IconButton(
                    tooltip: 'Clear dates',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => setState(() {
                      _dateFrom = null;
                      _dateTo = null;
                    }),
                    icon: const Icon(Icons.clear, size: 18),
                  ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: () => setState(() {}),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Search', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: AppPaginatedTable<Invoice>(
                  key: ValueKey('$_selectedFilter-${_search.text}-$_dateFromStr-$_dateToStr'),
                  emptyMessage: 'No invoices found for this filter.',
                  headerFontSize: 9,
                  cellFontSize: 12,
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
                        inv.displayInvoiceNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TableColumnDef(
                      label: 'Customer',
                      flex: 1.4,
                      cellBuilder: (c, inv) => Text(
                        inv.customer?.name ?? 'Walk-in',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (isSuperAdmin)
                      TableColumnDef(
                        label: 'Branch',
                        flex: 1.3,
                        cellBuilder: (c, inv) => Text(
                          inv.branchName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    TableColumnDef(
                      label: 'Date',
                      flex: 1,
                      cellBuilder: (c, inv) => Text(
                        inv.displayDate,
                        style: const TextStyle(fontSize: 12),
                      ),
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
                              fontSize: 8,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
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
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          );
                        }
                        return Text(
                          breakdown,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
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
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          );
                        }
                        return Text(
                          '₹${cash.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
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
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          );
                        }
                        return Text(
                          '₹${change.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                            fontSize: 12,
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
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          );
                        }
                        return Text(
                          '₹${inv.dueAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.warning,
                            fontSize: 12,
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
