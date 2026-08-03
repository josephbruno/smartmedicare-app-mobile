import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../data/models/invoice.dart';
import '../../data/models/product.dart';

class _ReturnLine {
  _ReturnLine(this.item) : qty = TextEditingController(text: '0');

  final ReturnableInvoiceItem item;
  final TextEditingController qty;
  bool selected = false;

  double get quantity => double.tryParse(qty.text.trim()) ?? 0;

  double get lineCredit {
    if (item.quantity <= 0) return 0;
    return item.totalAmount * (quantity / item.quantity);
  }

  void dispose() => qty.dispose();
}

class _ExchangeLine {
  int? productId;
  final TextEditingController qty = TextEditingController(text: '1');
  final TextEditingController rate = TextEditingController(text: '0');
  double gstRate = 0;

  double get quantity => double.tryParse(qty.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(rate.text.trim()) ?? 0;
  double get amount => quantity * unitPrice;

  void dispose() {
    qty.dispose();
    rate.dispose();
  }
}

class SaleReturnFormScreen extends StatefulWidget {
  const SaleReturnFormScreen({super.key, required this.invoiceId});

  final int invoiceId;

  @override
  State<SaleReturnFormScreen> createState() => _SaleReturnFormScreenState();
}

class _SaleReturnFormScreenState extends State<SaleReturnFormScreen> {
  static final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  bool _loading = true;
  bool _saving = false;
  String? _error;

  Invoice? _invoice;
  List<_ReturnLine> _lines = [];
  List<Product> _products = [];
  final List<_ExchangeLine> _exchangeLines = [];

  String _settleMode = 'cash_refund';
  String _refundMode = 'cash';
  final _notes = TextEditingController();
  final _securityCode = TextEditingController();
  final _extraPayAmount = TextEditingController();
  String _extraPayMode = 'cash';

  static const _refundModes = <(String, String)>[
    ('cash', 'Cash'),
    ('upi', 'UPI'),
    ('card', 'Card'),
    ('bank_transfer', 'Bank Transfer'),
    ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _notes.dispose();
    _securityCode.dispose();
    _extraPayAmount.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    for (final l in _exchangeLines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = context.read<AppServices>();
      final invoice = await svc.billing.get(widget.invoiceId);
      final products = await svc.products.list(query: {'per_page': 200, 'is_active': true});
      if (!mounted) return;

      final returnable =
          invoice.returnableItems.where((i) => i.returnableQty > 0.0005).toList();
      setState(() {
        _invoice = invoice;
        _products = products.where((p) => p.isActive && !p.isService).toList();
        _lines = returnable.map(_ReturnLine.new).toList();
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

  double get _returnCredit => _lines
      .where((l) => l.selected && l.quantity > 0)
      .fold(0.0, (s, l) => s + l.lineCredit);

  int get _selectedCount =>
      _lines.where((l) => l.selected && l.quantity > 0).length;

  double get _exchangeTotal => _exchangeLines.fold(0.0, (s, l) => s + l.amount);

  double get _net => _exchangeTotal - _returnCredit;

  bool get _allSelected =>
      _lines.isNotEmpty && _lines.every((l) => l.selected);

  void _toggleSelectAll(bool? value) {
    final select = value ?? false;
    setState(() {
      for (final line in _lines) {
        line.selected = select;
        if (select) {
          line.qty.text = _fmtQty(line.item.returnableQty);
        } else {
          line.qty.text = '0';
        }
      }
    });
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(3);

  String _fmtMoney(num n) => _money.format(n);

  void _setSettleMode(String mode) {
    setState(() {
      _settleMode = mode;
      if (mode == 'exchange' && _exchangeLines.isEmpty) {
        _exchangeLines.add(_ExchangeLine());
      }
      _syncCollectAmount();
    });
  }

  void _addExchangeLine() => setState(() => _exchangeLines.add(_ExchangeLine()));

  void _removeExchangeLine(int idx) {
    setState(() => _exchangeLines.removeAt(idx).dispose());
  }

  Future<void> _save() async {
    final selected = _lines.where((l) => l.selected && l.quantity > 0).toList();
    if (selected.isEmpty) {
      _snack('Select at least one item to return');
      return;
    }
    for (final l in selected) {
      if (l.quantity > l.item.returnableQty + 0.0005) {
        _snack('Qty for ${l.item.productName} exceeds returnable ${l.item.returnableQty}');
        return;
      }
    }
    if (_securityCode.text.trim().length != 6) {
      _snack('Enter the 6-digit invoice security code');
      return;
    }
    if (_settleMode == 'exchange') {
      if (_exchangeLines.isEmpty) {
        _snack('Add at least one replacement product');
        return;
      }
      for (final l in _exchangeLines) {
        if (l.productId == null || l.quantity <= 0 || l.unitPrice < 0) {
          _snack('Fill all exchange item fields');
          return;
        }
      }
    }

    final body = <String, dynamic>{
      'code': _securityCode.text.trim(),
      'settle_mode': _settleMode,
      'refund_mode': _refundMode,
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      'items': selected
          .map((l) => {
                'invoice_item_id': l.item.invoiceItemId,
                'quantity': l.quantity,
              })
          .toList(),
    };

    if (_settleMode == 'exchange') {
      body['exchange_items'] = _exchangeLines.map((l) {
        final p = _products.where((x) => x.id == l.productId).firstOrNull;
        return {
          'product_id': l.productId,
          'product_name': p?.name ?? 'Product',
          'quantity': l.quantity,
          'unit_price': l.unitPrice,
          'gst_rate': l.gstRate,
          if (p?.hsnCode != null) 'hsn_code': p!.hsnCode,
        };
      }).toList();

      if (_net > 0.009) {
        final extra = double.tryParse(_extraPayAmount.text.trim()) ?? _net;
        if (extra > 0.009) {
          body['exchange_payments'] = [
            {'mode': _extraPayMode, 'amount': extra},
          ];
        }
      }
      body['refund_leftover'] = true;
    }

    setState(() => _saving = true);
    try {
      final result = await context.read<AppServices>().billing.createReturn(
            widget.invoiceId,
            body,
          );
      if (!mounted) return;

      final msg = StringBuffer('Sale return recorded');
      if (result.refundAmount > 0.009) {
        msg.write(' · Refund ${_fmtMoney(result.refundAmount)}');
      }
      if (result.exchangeInvoice != null) {
        msg.write(' · Exchange ${result.exchangeInvoice!.invoiceNumber}');
      }
      if (result.amountDue > 0.009) {
        msg.write(' · Due ${_fmtMoney(result.amountDue)}');
      }
      AppMessenger.show(context, SnackBar(content: Text(msg.toString())));

      if (result.exchangeInvoice != null) {
        context.go('/invoices/${result.exchangeInvoice!.id}');
      } else {
        context.go('/invoices/${result.returnInvoice.id}');
      }
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    AppMessenger.show(context, SnackBar(content: Text(msg)));
  }

  String _ymd(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  InputDecoration _dec(String label, {String? hint, String? helper}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sale Return')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Invoice not found', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _bootstrap, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final inv = _invoice!;
    final canSave = _selectedCount > 0 && !_saving;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Return · ${inv.invoiceNumber}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              _settleMode == 'exchange' ? 'Exchange flow' : 'Cash refund flow',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: canSave ? _save : null,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_settleMode == 'exchange' ? 'Complete exchange' : 'Save return'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedCount > 0) _buildLiveSummaryBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _buildAgainstInvoice(inv),
                const SizedBox(height: 14),
                _buildStepsHint(),
                const SizedBox(height: 14),
                _buildItemsCard(),
                const SizedBox(height: 14),
                _buildSettleCard(),
                if (_settleMode == 'exchange') ...[
                  const SizedBox(height: 14),
                  _buildExchangeCard(),
                ],
                const SizedBox(height: 14),
                _buildAuthorizeCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSummaryBar() {
    final isExchange = _settleMode == 'exchange';
    final Color tone;
    final String title;
    final String detail;

    if (!isExchange) {
      tone = AppTheme.accent;
      title = 'Refund ${_fmtMoney(_returnCredit)}';
      detail = '$_selectedCount item(s) · via ${_labelMode(_refundMode)}';
    } else if (_net.abs() < 0.01) {
      tone = AppTheme.primary;
      title = 'Even exchange';
      detail = 'Return ${_fmtMoney(_returnCredit)} = new sale ${_fmtMoney(_exchangeTotal)}';
    } else if (_net > 0) {
      tone = AppTheme.warning;
      title = 'Collect ${_fmtMoney(_net)}';
      detail = 'Exchange ${_fmtMoney(_exchangeTotal)} − credit ${_fmtMoney(_returnCredit)}';
    } else {
      tone = AppTheme.danger;
      title = 'Refund leftover ${_fmtMoney(-_net)}';
      detail = 'Credit ${_fmtMoney(_returnCredit)} − exchange ${_fmtMoney(_exchangeTotal)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: tone.withValues(alpha: 0.25))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isExchange ? Icons.swap_horiz_rounded : Icons.payments_outlined,
              color: tone,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: tone,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgainstInvoice(Invoice inv) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_outlined, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Against invoice',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () => context.push('/invoices/${inv.id}'),
                  borderRadius: BorderRadius.circular(6),
                  child: Text(
                    inv.invoiceNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(
                      Icons.calendar_today_outlined,
                      _ymd(DateTime.tryParse(inv.invoiceDate) ?? DateTime.now()),
                    ),
                    if (inv.customer != null)
                      _chip(Icons.person_outline, inv.customer!.name),
                    _chip(Icons.payments_outlined, _fmtMoney(inv.totalAmount)),
                    if (inv.dueAmount > 0.009)
                      _chip(Icons.schedule_outlined, 'Due ${_fmtMoney(inv.dueAmount)}',
                          color: AppTheme.danger),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Only items from this bill can be returned.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsHint() {
    final step1Done = _selectedCount > 0;
    final step2Done = step1Done &&
        (_settleMode == 'cash_refund' ||
            (_settleMode == 'exchange' &&
                _exchangeLines.any((l) => l.productId != null && l.amount > 0)));
    return Row(
      children: [
        _stepDot(1, 'Items', step1Done),
        _stepLine(step1Done),
        _stepDot(2, 'Settle', step2Done),
        _stepLine(step2Done),
        _stepDot(3, 'Authorize', _securityCode.text.length == 6),
      ],
    );
  }

  Widget _stepDot(int n, String label, bool done) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? AppTheme.accent : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$n',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: done ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine(bool active) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(right: 6),
      color: active ? AppTheme.accent.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildItemsCard() {
    return _card(
      title: '1. Items to return',
      trailing: _lines.isEmpty
          ? null
          : TextButton(
              onPressed: () => _toggleSelectAll(!_allSelected),
              child: Text(_allSelected ? 'Clear all' : 'Select all'),
            ),
      child: _lines.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No returnable items left on this invoice.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < _lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _buildReturnItemTile(_lines[i]),
                ],
                if (_selectedCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$_selectedCount selected',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Return credit  ${_fmtMoney(_returnCredit)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildReturnItemTile(_ReturnLine line) {
    final item = line.item;
    final selected = line.selected;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppTheme.primary.withValues(alpha: 0.45) : const Color(0xFFE2E8F0),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                line.selected = !line.selected;
                if (line.selected && line.quantity <= 0) {
                  line.qty.text = _fmtQty(item.returnableQty);
                } else if (!line.selected) {
                  line.qty.text = '0';
                }
              });
            },
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (v) {
                    setState(() {
                      line.selected = v ?? false;
                      if (line.selected && line.quantity <= 0) {
                        line.qty.text = _fmtQty(item.returnableQty);
                      } else if (!line.selected) {
                        line.qty.text = '0';
                      }
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sold ${_fmtQty(item.quantity)} · Returnable ${_fmtQty(item.returnableQty)} · ${_fmtMoney(item.totalAmount)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 8),
                _qtyButton(
                  icon: Icons.remove,
                  onTap: () {
                    final next = (line.quantity - 1).clamp(0.0, item.returnableQty);
                    setState(() {
                      line.qty.text = _fmtQty(next);
                      _syncCollectAmount();
                    });
                  },
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: TextField(
                    controller: line.qty,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: _dec('Qty'),
                    onChanged: (_) => setState(_syncCollectAmount),
                  ),
                ),
                const SizedBox(width: 8),
                _qtyButton(
                  icon: Icons.add,
                  onTap: () {
                    final next = (line.quantity + 1).clamp(0.0, item.returnableQty);
                    setState(() {
                      line.qty.text = _fmtQty(next);
                      _syncCollectAmount();
                    });
                  },
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Credit',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    Text(
                      _fmtMoney(line.lineCredit),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  line.qty.text = _fmtQty(item.returnableQty);
                }),
                child: const Text('Return full qty'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: AppTheme.textPrimary),
        ),
      ),
    );
  }

  Widget _buildSettleCard() {
    return _card(
      title: '2. Settle as',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _settleOption(
                  value: 'cash_refund',
                  icon: Icons.payments_outlined,
                  title: 'Cash / refund',
                  subtitle: 'Return stock & refund money',
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _settleOption(
                  value: 'exchange',
                  icon: Icons.swap_horiz_rounded,
                  title: 'Exchange',
                  subtitle: 'Buy another product',
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          if (_settleMode == 'cash_refund') ...[
            const SizedBox(height: 14),
            AppDropdownButtonFormField<String>(
              value: _refundMode,
              decoration: _dec('Refund via'),
              items: _refundModes
                  .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _refundMode = v);
              },
            ),
            if (_returnCredit > 0) ...[
              const SizedBox(height: 10),
              _infoBanner(
                icon: Icons.info_outline,
                color: AppTheme.accent,
                text:
                    'Customer will be refunded ${_fmtMoney(_returnCredit)} via ${_labelMode(_refundMode)}.',
              ),
            ],
          ],
          if (_settleMode == 'exchange') ...[
            const SizedBox(height: 12),
            _infoBanner(
              icon: Icons.swap_horiz_rounded,
              color: AppTheme.primary,
              text:
                  'Return credit ${_fmtMoney(_returnCredit)} will be applied to the new products below.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _settleOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final selected = _settleMode == value;
    return InkWell(
      onTap: () => _setSettleMode(value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: selected ? color : AppTheme.textSecondary, size: 22),
                const Spacer(),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? color : AppTheme.textSecondary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: selected ? color : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  void _syncCollectAmount() {
    if (_settleMode != 'exchange' || _net <= 0.009) return;
    final typed = double.tryParse(_extraPayAmount.text.trim());
    if (_extraPayAmount.text.trim().isEmpty || typed == null) {
      _extraPayAmount.text = _net.toStringAsFixed(2);
    }
  }

  Widget _buildExchangeCard() {
    return _card(
      title: '3. Replacement products',
      trailing: TextButton.icon(
        onPressed: _addExchangeLine,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add item'),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _exchangeLines.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildExchangeRow(i),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _kv('Return credit', _fmtMoney(_returnCredit)),
                const SizedBox(height: 6),
                _kv('Exchange total', _fmtMoney(_exchangeTotal)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                _kv(
                  _net >= 0 ? 'Customer pays' : 'Refund leftover',
                  _fmtMoney(_net.abs()),
                  bold: true,
                  valueColor: _net > 0.009
                      ? AppTheme.warning
                      : (_net < -0.009 ? AppTheme.danger : AppTheme.accent),
                ),
              ],
            ),
          ),
          if (_net > 0.009) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppDropdownButtonFormField<String>(
                    value: _extraPayMode,
                    decoration: _dec('Collect via'),
                    items: _refundModes
                        .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _extraPayMode = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _extraPayAmount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Amount to collect', hint: _net.toStringAsFixed(2)),
                  ),
                ),
              ],
            ),
          ],
          if (_net < -0.009) ...[
            const SizedBox(height: 12),
            AppDropdownButtonFormField<String>(
              value: _refundMode,
              decoration: _dec('Refund leftover via'),
              items: _refundModes
                  .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _refundMode = v);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExchangeRow(int i) {
    final line = _exchangeLines[i];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppDropdownButtonFormField<int>(
                  value: line.productId,
                  decoration: _dec('Product'),
                  items: _products
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    final p = _products.where((x) => x.id == v).firstOrNull;
                    setState(() {
                      line.productId = v;
                      if (p != null) {
                        line.rate.text = p.sellingPrice.toStringAsFixed(2);
                        line.gstRate = p.gstRate;
                      }
                    });
                  },
                ),
              ),
              IconButton(
                onPressed: _exchangeLines.length <= 1 ? null : () => _removeExchangeLine(i),
                icon: const Icon(Icons.delete_outline),
                color: AppTheme.danger,
                tooltip: 'Remove',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: line.qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Qty'),
                  onChanged: (_) => setState(_syncCollectAmount),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: line.rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Rate'),
                  onChanged: (_) => setState(_syncCollectAmount),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Line', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(
                      _fmtMoney(line.amount),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorizeCard() {
    final stepLabel = _settleMode == 'exchange' ? '4. Authorize' : '3. Authorize';
    return _card(
      title: stepLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _securityCode,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dec(
              'Security code *',
              hint: '••••••',
              helper: '6-digit branch invoice code',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: _dec('Notes (optional)'),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: color.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false, Color? valueColor}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          v,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ?? AppTheme.textPrimary,
            fontSize: bold ? 15 : 14,
          ),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label, {Color? color}) {
    final c = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
  }

  String _labelMode(String mode) {
    for (final m in _refundModes) {
      if (m.$1 == mode) return m.$2;
    }
    return mode;
  }

  Widget _card({String? title, required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
