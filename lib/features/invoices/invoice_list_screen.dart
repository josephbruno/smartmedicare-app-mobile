import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_date_range_picker.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/invoice.dart';
import '../reports/report_date_range.dart';
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
  static final _dayFmt = DateFormat('d MMM yyyy');
  static final _monthFmt = DateFormat('MMM yyyy');

  String _selectedFilter = 'all';
  String _paymentFilter = 'all';
  String _period = 'all';
  final _search = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _dateFrom = DateTime.tryParse(widget.initialDateFrom ?? '');
    _dateTo = DateTime.tryParse(widget.initialDateTo ?? '');
    _period = _periodFromDates(_dateFrom, _dateTo);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _periodFromDates(DateTime? from, DateTime? to) {
    if (from == null || to == null) return 'all';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    if (a == today && b == today) return 'today';
    final monthStart = DateTime(now.year, now.month, 1);
    if (a == monthStart && (b == today || b == DateTime(now.year, now.month + 1, 0))) {
      return 'month';
    }
    if (a.day == 1 && b == DateTime(a.year, a.month + 1, 0) && a != monthStart) {
      return 'month_pick';
    }
    if (a == b) return 'date';
    return 'custom';
  }

  void _applyPeriod(String key) {
    final range = switch (key) {
      'today' => ReportDateRange.preset('today'),
      'month' => ReportDateRange.preset('month'),
      'last_month' => ReportDateRange.preset('last_month'),
      _ => null,
    };
    setState(() {
      _period = key;
      if (key == 'all') {
        _dateFrom = null;
        _dateTo = null;
      } else if (range != null) {
        _dateFrom = range.from;
        _dateTo = range.to;
      }
    });
  }

  Future<void> _onPeriodChanged(String? value) async {
    if (value == null) return;
    switch (value) {
      case 'date':
        await _pickSingleDate();
        return;
      case 'month_pick':
        await _pickMonth();
        return;
      case 'custom':
        await _pickDateRange();
        return;
      default:
        _applyPeriod(value);
    }
  }

  Future<void> _pickSingleDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Filter by date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = 'date';
      _dateFrom = DateTime(picked.year, picked.month, picked.day);
      _dateTo = _dateFrom;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _MonthPickerDialog(initial: _dateFrom ?? DateTime.now()),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = 'month_pick';
      _dateFrom = DateTime(picked.year, picked.month, 1);
      _dateTo = DateTime(picked.year, picked.month + 1, 0);
    });
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
    if (range == null || !mounted) return;
    setState(() {
      _period = 'custom';
      _dateFrom = range.start;
      _dateTo = range.end;
    });
  }

  void _clearDates() {
    setState(() {
      _period = 'all';
      _dateFrom = null;
      _dateTo = null;
    });
  }

  String? get _dateFromStr => _ymd(_dateFrom);

  String? get _dateToStr => _ymd(_dateTo);

  String? _ymd(DateTime? d) {
    if (d == null) return null;
    return DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));
  }

  InputDecoration _filterDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      );

  Widget _filterDropdown<T>({
    required double width,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required String label,
  }) {
    return SizedBox(
      width: width,
      child: AppDropdownButtonFormField<T>(
        value: value,
        isDense: true,
        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        decoration: _filterDec(label),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget? _periodSummaryButton() {
    if (_dateFrom == null || _dateTo == null) return null;
    if (_period == 'today' || _period == 'month' || _period == 'last_month') {
      return null;
    }
    final VoidCallback onPressed;
    final String label;
    if (_period == 'date' || _dateFromStr == _dateToStr) {
      onPressed = _pickSingleDate;
      label = _dayFmt.format(_dateFrom!);
    } else if (_period == 'month_pick') {
      onPressed = _pickMonth;
      label = _monthFmt.format(_dateFrom!);
    } else {
      onPressed = _pickDateRange;
      label = '${_dayFmt.format(_dateFrom!)} – ${_dayFmt.format(_dateTo!)}';
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.date_range_outlined, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

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

  Color _paymentModeColor(String mode) {
    switch (mode.toLowerCase().trim()) {
      case 'cash':
        return AppTheme.primary;
      case 'upi':
        return const Color(0xFFEA580C);
      default:
        return AppTheme.textPrimary;
    }
  }

  Widget _buildPaymentsCell(Invoice inv) {
    if (inv.isCancelled) {
      return const Text(
        'Cancelled',
        style: TextStyle(
          color: AppTheme.danger,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final map = inv.paymentsByMode;
    if (map.isEmpty) {
      return const Text(
        '—',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      );
    }

    String money(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

    final entries = map.entries.toList();
    final spans = <InlineSpan>[];
    for (var i = 0; i < entries.length; i++) {
      final mode = entries[i].key;
      if (i > 0) {
        spans.add(const TextSpan(
          text: ' · ',
          style: TextStyle(color: AppTheme.textSecondary),
        ));
      }
      spans.add(TextSpan(
        text: '${paymentModeLabel(mode)} ₹${money(entries[i].value)}',
        style: TextStyle(
          color: _paymentModeColor(mode),
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final isSuperAdmin = context.watch<AuthSession>().isSuperAdmin;
    final periodSummary = _periodSummaryButton();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                          if (_search.text.trim().isEmpty) setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _filterDropdown<String>(
                      width: 130,
                      label: 'Status',
                      value: _selectedFilter,
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
                    _filterDropdown<String>(
                      width: 120,
                      label: 'Payment',
                      value: _paymentFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _paymentFilter = v);
                      },
                    ),
                    _filterDropdown<String>(
                      width: 150,
                      label: 'Period',
                      value: _period,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All dates')),
                        DropdownMenuItem(value: 'today', child: Text('Today')),
                        DropdownMenuItem(value: 'month', child: Text('This month')),
                        DropdownMenuItem(value: 'last_month', child: Text('Last month')),
                        DropdownMenuItem(value: 'date', child: Text('Pick date')),
                        DropdownMenuItem(value: 'month_pick', child: Text('Pick month')),
                        DropdownMenuItem(value: 'custom', child: Text('Custom range')),
                      ],
                      onChanged: _onPeriodChanged,
                    ),
                    if (periodSummary != null) periodSummary,
                    if (_dateFrom != null)
                      IconButton(
                        tooltip: 'Clear dates',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: _clearDates,
                        icon: const Icon(Icons.clear, size: 18),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: AppPaginatedTable<Invoice>(
                  key: ValueKey(
                    '$_selectedFilter-$_paymentFilter-$_period-${_search.text}-$_dateFromStr-$_dateToStr',
                  ),
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
                        paymentMode: _paymentFilter,
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
                      cellBuilder: (c, inv) => _buildPaymentsCell(inv),
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

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial});

  final DateTime initial;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
  }

  bool _isFuture(int month) {
    final now = DateTime.now();
    return DateTime(_year, month, 1).isAfter(DateTime(now.year, now.month, 1));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter by month'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous year',
                  onPressed: _year <= 2020
                      ? null
                      : () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next year',
                  onPressed: _year >= DateTime.now().year
                      ? null
                      : () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              itemCount: 12,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemBuilder: (context, i) {
                final month = i + 1;
                final selected = month == _month;
                final disabled = _isFuture(month);
                return OutlinedButton(
                  onPressed: disabled
                      ? null
                      : () => setState(() => _month = month),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selected
                        ? AppTheme.primary.withValues(alpha: 0.12)
                        : null,
                    foregroundColor: selected ? AppTheme.primary : null,
                    side: BorderSide(
                      color: selected ? AppTheme.primary : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Text(_months[i]),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isFuture(_month)
              ? null
              : () => Navigator.pop(context, DateTime(_year, _month, 1)),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
