import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../data/models/product.dart';
import '../../data/models/purchase.dart';
import '../../data/models/shop.dart';

class _LineItem {
  int? productId;
  final TextEditingController qty = TextEditingController(text: '1');
  final TextEditingController rate = TextEditingController(text: '0');

  double get quantity => double.tryParse(qty.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(rate.text.trim()) ?? 0;
  double get amount => quantity * unitPrice;

  void dispose() {
    qty.dispose();
    rate.dispose();
  }
}

class PurchaseReturnFormScreen extends StatefulWidget {
  const PurchaseReturnFormScreen({super.key});

  @override
  State<PurchaseReturnFormScreen> createState() => _PurchaseReturnFormScreenState();
}

class _PurchaseReturnFormScreenState extends State<PurchaseReturnFormScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  List<Branch> _branches = [];

  bool _isSuperAdmin = false;
  int? _branchId;
  int? _supplierId;
  String _reason = 'expired';
  DateTime _returnDate = DateTime.now();
  final _notes = TextEditingController();
  final List<_LineItem> _items = [];

  static const _reasons = <(String, String)>[
    ('expired', 'Expired'),
    ('damaged', 'Damaged'),
    ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _items.add(_LineItem());
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthSession>();
      final svc = context.read<AppServices>();
      _isSuperAdmin = auth.isSuperAdmin;

      if (_isSuperAdmin) {
        _branchId = auth.currentBranchId;
      } else {
        _branchId = auth.user?.branchId ?? auth.currentBranchId;
      }

      final futures = <Future>[
        svc.suppliers.list(query: {'per_page': 200}),
        svc.products.list(query: {'per_page': 200, 'is_active': true}),
      ];
      if (_isSuperAdmin) {
        futures.add(svc.branches.list());
      }

      final results = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _suppliers = (results[0] as List<Supplier>).where((s) => s.isActive).toList();
        _products = (results[1] as List<Product>)
            .where((p) => p.isActive && !p.isService)
            .toList();
        if (_isSuperAdmin && results.length > 2) {
          _branches = (results[2] as List<Branch>).where((b) => b.isActive).toList();
          if (_branchId != null && !_branches.any((b) => b.id == _branchId)) {
            _branchId = _branches.isNotEmpty ? _branches.first.id : null;
          }
          _branchId ??= _branches.isNotEmpty ? _branches.first.id : null;
        }
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

  double get _totalAmount => _items.fold(0.0, (sum, item) => sum + item.amount);

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _productLabel(Product p) {
    final code = p.sku ?? p.barcode;
    return code == null || code.isEmpty ? p.name : '${p.name} ($code)';
  }

  List<Product> _productsForRow(int rowIdx) {
    final currentId = _items[rowIdx].productId;
    final used = _items
        .asMap()
        .entries
        .where((e) => e.key != rowIdx && e.value.productId != null)
        .map((e) => e.value.productId!)
        .toSet();
    return _products.where((p) => !used.contains(p.id) || p.id == currentId).toList();
  }

  void _onProductSelect(int rowIdx, int? productId) {
    if (productId == null) {
      setState(() => _items[rowIdx].productId = null);
      return;
    }
    final product = _products.where((p) => p.id == productId).firstOrNull;
    setState(() {
      final item = _items[rowIdx];
      item.productId = productId;
      if (product != null) {
        item.rate.text = product.purchasePrice.toStringAsFixed(2);
      }
    });
  }

  void _addItem() => setState(() => _items.add(_LineItem()));

  void _removeItem(int idx) {
    if (_items.length <= 1) return;
    setState(() => _items.removeAt(idx).dispose());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _returnDate = picked);
  }

  Future<void> _save() async {
    if (_supplierId == null) {
      _snack('Supplier is required');
      return;
    }

    final auth = context.read<AuthSession>();
    final int? branchId;
    if (_isSuperAdmin) {
      branchId = _branchId;
      if (branchId == null) {
        _snack('Please select a branch');
        return;
      }
    } else {
      branchId = auth.user?.branchId ?? auth.currentBranchId;
      if (branchId == null) {
        _snack('No branch mapped to your account. Contact admin.');
        return;
      }
    }

    final payloadItems = <Map<String, dynamic>>[];
    for (final item in _items) {
      if (item.productId == null) {
        _snack('Please select a product for every row');
        return;
      }
      if (item.quantity <= 0) {
        _snack('Quantity must be greater than zero');
        return;
      }
      if (item.unitPrice < 0) {
        _snack('Rate cannot be negative');
        return;
      }
      final product = _products.where((p) => p.id == item.productId).firstOrNull;
      payloadItems.add({
        'product_id': item.productId,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        if (product != null) 'gst_rate': product.gstRate,
      });
    }

    setState(() => _saving = true);
    try {
      final ret = await context.read<AppServices>().purchaseReturns.create({
        'supplier_id': _supplierId,
        'branch_id': branchId,
        'return_date': _ymd(_returnDate),
        'reason': _reason,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'items': payloadItems,
      });
      if (!mounted) return;
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Supplier return recorded')),
      );
      context.go('/purchase-returns/${ret.id}');
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

  InputDecoration _fieldDec(String label) {
    return InputDecoration(
      labelText: label,
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

  InputDecoration _cellDec({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Supplier Return')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _bootstrap, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('New Supplier Return'),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Return details',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Standalone return — not linked to a purchase order.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 280,
                      child: AppDropdownButtonFormField<int>(
                        value: _supplierId,
                        decoration: _fieldDec('Supplier *'),
                        items: _suppliers
                            .map(
                              (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _supplierId = v),
                      ),
                    ),
                    if (_isSuperAdmin)
                      SizedBox(
                        width: 220,
                        child: AppDropdownButtonFormField<int>(
                          value: _branchId,
                          decoration: _fieldDec('Branch *'),
                          items: _branches
                              .map(
                                (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _branchId = v),
                        ),
                      ),
                    SizedBox(
                      width: 180,
                      child: AppDropdownButtonFormField<String>(
                        value: _reason,
                        decoration: _fieldDec('Reason *'),
                        items: _reasons
                            .map(
                              (r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _reason = v);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: _fieldDec('Return date *'),
                          child: Text(_ymd(_returnDate)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: _fieldDec('Notes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
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
                    const Expanded(
                      child: Text(
                        'Items',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add item'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_items.length, (idx) {
                  final item = _items[idx];
                  final products = _productsForRow(idx);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: AppDropdownButtonFormField<int>(
                            value: item.productId,
                            decoration: _cellDec(hint: 'Product'),
                            items: products
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(_productLabel(p), overflow: TextOverflow.ellipsis),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => _onProductSelect(idx, v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: item.qty,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            decoration: _cellDec(hint: 'Qty'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: item.rate,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            decoration: _cellDec(hint: 'Rate'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '₹${item.amount.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _items.length <= 1 ? null : () => _removeItem(idx),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: AppTheme.danger,
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total: ₹${_totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
