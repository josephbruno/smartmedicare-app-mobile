import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_form_dialog.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/invoice.dart';

/// Collect remaining balance on open (partial / unpaid) invoices for a customer.
Future<bool> showCollectDueSheet(
  BuildContext context, {
  required Customer customer,
  List<Invoice>? openInvoices,
  Invoice? initialInvoice,
}) async {
  final bool? result;
  if (useCenteredFormDialog(context)) {
    result = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => _CollectDueDialog(
        customer: customer,
        openInvoices: openInvoices,
        initialInvoice: initialInvoice,
      ),
    );
  } else {
    result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CollectDueBottomSheet(
        customer: customer,
        openInvoices: openInvoices,
        initialInvoice: initialInvoice,
      ),
    );
  }
  return result == true;
}

class _CollectDueDialog extends StatelessWidget {
  const _CollectDueDialog({
    required this.customer,
    this.openInvoices,
    this.initialInvoice,
  });

  final Customer customer;
  final List<Invoice>? openInvoices;
  final Invoice? initialInvoice;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final dialogH = (screenH * 0.88).clamp(480.0, 720.0);

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 520,
        height: dialogH,
        child: _CollectDueBody(
          customer: customer,
          openInvoices: openInvoices,
          initialInvoice: initialInvoice,
          showHandle: false,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

class _CollectDueBottomSheet extends StatelessWidget {
  const _CollectDueBottomSheet({
    required this.customer,
    this.openInvoices,
    this.initialInvoice,
  });

  final Customer customer;
  final List<Invoice>? openInvoices;
  final Invoice? initialInvoice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: _CollectDueBody(
          customer: customer,
          openInvoices: openInvoices,
          initialInvoice: initialInvoice,
          showHandle: true,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

class _CollectDueBody extends StatefulWidget {
  const _CollectDueBody({
    required this.customer,
    required this.onClose,
    this.openInvoices,
    this.initialInvoice,
    this.showHandle = false,
  });

  final Customer customer;
  final List<Invoice>? openInvoices;
  final Invoice? initialInvoice;
  final VoidCallback onClose;
  final bool showHandle;

  @override
  State<_CollectDueBody> createState() => _CollectDueBodyState();
}

class _CollectDueBodyState extends State<_CollectDueBody> {
  late Future<List<Invoice>> _future;
  Invoice? _selected;
  String _mode = 'cash';
  final _amount = TextEditingController();
  final _tendered = TextEditingController();
  final _reference = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _loadOpenInvoices();
  }

  @override
  void dispose() {
    _amount.dispose();
    _tendered.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<List<Invoice>> _loadOpenInvoices() async {
    final seeded = widget.openInvoices;
    List<Invoice> list;
    if (seeded != null) {
      list = seeded.where((i) => i.dueAmount > 0.009).toList();
    } else {
      final result = await context.read<AppServices>().billing.listPaginated(
            page: 1,
            perPage: 50,
            customerId: widget.customer.id,
          );
      list = result.items.where((i) => i.dueAmount > 0.009).toList();
    }
    list.sort((a, b) => b.id.compareTo(a.id));

    Invoice? initial = widget.initialInvoice;
    if (initial != null && initial.dueAmount <= 0.009) {
      initial = list.cast<Invoice?>().firstWhere(
            (i) => i?.id == initial!.id,
            orElse: () => null,
          );
    }
    initial ??= list.isNotEmpty ? list.first : null;

    if (mounted) {
      setState(() {
        _selected = initial;
        _syncAmountFields();
      });
    }
    return list;
  }

  void _selectInvoice(Invoice inv) {
    setState(() {
      _selected = inv;
      _syncAmountFields();
    });
  }

  void _syncAmountFields() {
    final due = _selected?.dueAmount ?? 0;
    _amount.text = due > 0 ? due.toStringAsFixed(2) : '';
    _tendered.text = due > 0 ? due.toStringAsFixed(2) : '';
  }

  double get _due => _selected?.dueAmount ?? 0;

  double get _payAmount {
    final raw = double.tryParse(_amount.text.trim()) ?? 0;
    if (raw <= 0) return 0;
    return raw > _due ? _due : raw;
  }

  double get _tenderedAmount {
    if (_mode != 'cash') return _payAmount;
    return double.tryParse(_tendered.text.trim()) ?? 0;
  }

  double get _change {
    if (_mode != 'cash') return 0;
    final t = _tenderedAmount;
    final duePay = _payAmount;
    if (t <= duePay + 0.009) return 0;
    // Change only when settling full remaining due on this invoice.
    if (_payAmount + 0.009 < _due) return 0;
    return t - _due;
  }

  double get _stillDueAfter {
    return (_due - _payAmount).clamp(0, double.infinity);
  }

  Future<void> _submit() async {
    final inv = _selected;
    if (inv == null) return;
    final amount = _payAmount;
    if (amount <= 0.009) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Enter a valid payment amount')),
      );
      return;
    }
    if (amount > _due + 0.009) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Amount cannot exceed balance due')),
      );
      return;
    }
    if (_mode == 'cash') {
      final tendered = _tenderedAmount;
      if (tendered + 0.009 < amount) {
        AppMessenger.show(
          context,
          const SnackBar(
            content: Text('Cash received cannot be less than payment amount'),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final tenderedToSave = _mode == 'cash' &&
              _tenderedAmount > _due + 0.009 &&
              amount >= _due - 0.009
          ? _tenderedAmount
          : null;

      await context.read<AppServices>().billing.recordPayment(
            inv.id,
            mode: _mode,
            amount: amount,
            tenderedAmount: tenderedToSave,
            reference: _mode == 'upi' && _reference.text.trim().isNotEmpty
                ? _reference.text.trim()
                : null,
          );
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(
          content: Text(
            _stillDueAfter > 0.009
                ? 'Payment recorded. Remaining due ₹${_stillDueAfter.toStringAsFixed(2)}'
                : 'Payment recorded. Invoice fully paid',
          ),
          backgroundColor: AppTheme.accent,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHandle)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Collect due payment',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      widget.customer.name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<Invoice>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${snap.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => setState(() {
                            _future = _loadOpenInvoices();
                          }),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final list = snap.data ?? const <Invoice>[];
              if (list.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No open balance for this customer.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                children: [
                  Text(
                    'Open invoices (${list.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...list.map(_invoiceChoice),
                  const SizedBox(height: 16),
                  if (_selected != null) ...[
                    _paymentForm(),
                  ],
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : widget.onClose,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving || _selected == null ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(_saving ? 'Saving…' : 'Record payment'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _invoiceChoice(Invoice inv) {
    final selected = _selected?.id == inv.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _selectInvoice(inv),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppTheme.primary : AppTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.invoiceNumber,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${inv.displayDate} · ${inv.status.toUpperCase()} · Total ₹${inv.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Due ₹${inv.dueAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.warning,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Payment',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _modeChip('cash', 'Cash', Icons.payments_outlined),
            const SizedBox(width: 8),
            _modeChip('upi', 'UPI', Icons.qr_code_2_rounded),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText: 'Amount to apply (₹)',
            helperText: 'Max due ₹${_due.toStringAsFixed(2)}',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
        ),
        if (_mode == 'cash') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _tendered,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Cash received (₹)',
              helperText: 'Enter higher amount if giving change',
              filled: true,
              fillColor: Color(0xFFF8FAFC),
            ),
          ),
        ],
        if (_mode == 'upi') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'UPI reference (optional)',
              filled: true,
              fillColor: Color(0xFFF8FAFC),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _kv('Invoice due', '₹${_due.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _kv('Applying now', '₹${_payAmount.toStringAsFixed(2)}'),
              if (_change > 0.009) ...[
                const SizedBox(height: 6),
                _kv(
                  'Change to return',
                  '₹${_change.toStringAsFixed(2)}',
                  valueColor: AppTheme.accent,
                ),
              ],
              const Divider(height: 16),
              _kv(
                'Balance after',
                '₹${_stillDueAfter.toStringAsFixed(2)}',
                bold: true,
                valueColor:
                    _stillDueAfter > 0.009 ? AppTheme.warning : AppTheme.accent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeChip(String mode, String label, IconData icon) {
    final selected = _mode == mode;
    return Expanded(
      child: Material(
        color: selected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() {
            _mode = mode;
            if (mode == 'cash') {
              _tendered.text = _amount.text;
            }
          }),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppTheme.primary : AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: bold ? 15 : 13,
          ),
        ),
      ],
    );
  }
}
