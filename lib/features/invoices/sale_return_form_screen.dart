import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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

      final returnable = invoice.returnableItems.where((i) => i.returnableQty > 0.0005).toList();
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

  double get _exchangeTotal =>
      _exchangeLines.fold(0.0, (s, l) => s + l.amount);

  double get _net => _exchangeTotal - _returnCredit;

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
        msg.write(' · Refund ₹${result.refundAmount.toStringAsFixed(2)}');
      }
      if (result.exchangeInvoice != null) {
        msg.write(' · Exchange ${result.exchangeInvoice!.invoiceNumber}');
      }
      if (result.amountDue > 0.009) {
        msg.write(' · Due ₹${result.amountDue.toStringAsFixed(2)}');
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

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Return · ${inv.invoiceNumber}'),
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
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Return'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            title: 'Against invoice',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Date: ${_ymd(DateTime.tryParse(inv.invoiceDate) ?? DateTime.now())}'
                  '${inv.customer != null ? '  ·  ${inv.customer!.name}' : ''}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: ₹${inv.totalAmount.toStringAsFixed(2)}'
                  '${inv.dueAmount > 0.009 ? '  ·  Due: ₹${inv.dueAmount.toStringAsFixed(2)}' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This return is linked to the invoice above. Items must come from that bill.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            title: 'Settle as',
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'cash_refund',
                  groupValue: _settleMode,
                  title: const Text('Cash / refund'),
                  subtitle: const Text('Return stock and refund money'),
                  onChanged: (v) => setState(() => _settleMode = v!),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  value: 'exchange',
                  groupValue: _settleMode,
                  title: const Text('Exchange — buy another product'),
                  subtitle: const Text('Return value applied to a new sale'),
                  onChanged: (v) {
                    setState(() {
                      _settleMode = v!;
                      if (_exchangeLines.isEmpty) _exchangeLines.add(_ExchangeLine());
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                AppDropdownButtonFormField<String>(
                  value: _refundMode,
                  decoration: _dec('Refund mode'),
                  items: _refundModes
                      .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _refundMode = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _securityCode,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _dec('Security code *', hint: '6-digit branch code'),
                ),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: _dec('Notes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            title: 'Items to return',
            child: _lines.isEmpty
                ? const Text(
                    'No returnable items on this invoice.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  )
                : Column(
                    children: [
                      for (final line in _lines) ...[
                        CheckboxListTile(
                          value: line.selected,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            line.item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Sold ${line.item.quantity} · Returnable ${line.item.returnableQty} · '
                            '₹${line.item.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onChanged: (v) {
                            setState(() {
                              line.selected = v ?? false;
                              if (line.selected && line.quantity <= 0) {
                                line.qty.text = line.item.returnableQty
                                    .toStringAsFixed(
                                  line.item.returnableQty ==
                                          line.item.returnableQty.roundToDouble()
                                      ? 0
                                      : 3,
                                    );
                              }
                            });
                          },
                        ),
                        if (line.selected)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: line.qty,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                    ],
                                    decoration: _dec('Qty'),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Credit ≈ ₹${line.lineCredit.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        const Divider(height: 1),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Return credit: ₹${_returnCredit.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
          ),
          if (_settleMode == 'exchange') ...[
            const SizedBox(height: 16),
            _card(
              title: 'Replacement products',
              trailing: TextButton.icon(
                onPressed: _addExchangeLine,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _exchangeLines.length; i++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: AppDropdownButtonFormField<int>(
                            value: _exchangeLines[i].productId,
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
                                _exchangeLines[i].productId = v;
                                if (p != null) {
                                  _exchangeLines[i].rate.text =
                                      p.sellingPrice.toStringAsFixed(2);
                                  _exchangeLines[i].gstRate = p.gstRate;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _exchangeLines[i].qty,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _dec('Qty'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _exchangeLines[i].rate,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _dec('Rate'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          onPressed: _exchangeLines.length <= 1
                              ? null
                              : () => _removeExchangeLine(i),
                          icon: const Icon(Icons.delete_outline),
                          color: AppTheme.danger,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Exchange total: ₹${_exchangeTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _net >= 0
                          ? 'Customer pays: ₹${_net.toStringAsFixed(2)}'
                          : 'Refund leftover: ₹${(-_net).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _net >= 0 ? AppTheme.primary : AppTheme.danger,
                      ),
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
                            decoration: _dec(
                              'Amount to collect',
                              hint: _net.toStringAsFixed(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          child,
        ],
      ),
    );
  }
}
