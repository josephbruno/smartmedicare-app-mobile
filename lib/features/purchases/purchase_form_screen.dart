import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../data/models/purchase.dart';
import '../../data/models/shop.dart';
import '../../core/widgets/app_dropdown.dart';
class _LineItem {
  int? productId;
  final TextEditingController batch = TextEditingController();
  final TextEditingController qty = TextEditingController(text: '1');
  final TextEditingController rate = TextEditingController(text: '0');
  DateTime? expiry;
  double sellingPrice = 0;
  double mrp = 0;

  double get quantity => double.tryParse(qty.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(rate.text.trim()) ?? 0;
  double get amount => quantity * unitPrice;

  void dispose() {
    batch.dispose();
    qty.dispose();
    rate.dispose();
  }
}

class PurchaseFormScreen extends StatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  List<Branch> _branches = [];

  bool _isSuperAdmin = false;
  int? _branchId;
  int? _supplierId;
  DateTime _purchaseDate = DateTime.now();
  final _notes = TextEditingController();
  final List<_LineItem> _items = [];

  String _paymentMode = 'cash';
  final _paidAmount = TextEditingController(text: '0');
  final _paymentRef = TextEditingController();

  static const _paymentModes = <(String, String)>[
    ('cash', 'Cash'),
    ('bank_transfer', 'Bank Transfer'),
    ('cheque', 'Cheque'),
    ('upi', 'UPI'),
    ('credit', 'Credit (Pay Later)'),
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
    _paidAmount.dispose();
    _paymentRef.dispose();
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

      // Non–super-admin: always use mapped branch. Super Admin: selectable.
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

  String? get _branchSubtitle {
    if (_isSuperAdmin) {
      final match = _branches.where((b) => b.id == _branchId);
      if (match.isNotEmpty) return match.first.name;
      return null;
    }
    final auth = context.read<AuthSession>();
    return auth.currentBranch?.name ?? auth.user?.branch?.name;
  }

  double get _totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.amount);

  String _formatMoney(double n) => n.toStringAsFixed(2);

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Product> _productsForRow(int rowIdx) {
    final currentId = _items[rowIdx].productId;
    final used = _items
        .asMap()
        .entries
        .where((e) => e.key != rowIdx && e.value.productId != null)
        .map((e) => e.value.productId!)
        .toSet();
    return _products
        .where((p) => !used.contains(p.id) || p.id == currentId)
        .toList();
  }

  String _productLabel(Product p) {
    final code = p.sku ?? p.barcode;
    return code == null || code.isEmpty ? p.name : '${p.name} ($code)';
  }

  void _onProductSelect(int rowIdx, int? productId) {
    if (productId == null) {
      setState(() => _items[rowIdx].productId = null);
      return;
    }
    final duplicate = _items.asMap().entries.any(
          (e) => e.key != rowIdx && e.value.productId == productId,
        );
    if (duplicate) {
      _snack('This product is already in the list');
      return;
    }
    final product = _products.where((p) => p.id == productId).firstOrNull;
    setState(() {
      final item = _items[rowIdx];
      item.productId = productId;
      if (product != null) {
        item.rate.text = product.purchasePrice.toStringAsFixed(2);
        item.sellingPrice = product.sellingPrice;
        item.mrp = product.mrp;
      }
    });
  }

  void _addItem() => setState(() => _items.add(_LineItem()));

  void _removeItem(int idx) {
    if (_items.length <= 1) return;
    setState(() {
      _items.removeAt(idx).dispose();
    });
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _pickExpiry(int idx) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _items[idx].expiry ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _items[idx].expiry = picked);
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
      if (item.quantity <= 0 || item.unitPrice <= 0) {
        _snack('Please fill all item fields correctly');
        return;
      }
      payloadItems.add({
        'product_id': item.productId,
        if (item.batch.text.trim().isNotEmpty) 'batch_number': item.batch.text.trim(),
        if (item.expiry != null) 'expiry_date': _ymd(item.expiry!),
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        if (item.sellingPrice > 0) 'selling_price': item.sellingPrice,
        if (item.mrp > 0) 'mrp': item.mrp,
      });
    }

    final productIds = payloadItems.map((i) => i['product_id']).toList();
    if (productIds.toSet().length != productIds.length) {
      _snack('Each product can only appear once in the purchase');
      return;
    }

    final paid = double.tryParse(_paidAmount.text.trim()) ?? 0;
    if (paid < 0 || paid > _totalAmount + 0.001) {
      _snack('Amount paid cannot exceed total');
      return;
    }

    setState(() => _saving = true);
    try {
      final purchase = await context.read<AppServices>().purchases.create({
        'supplier_id': _supplierId,
        'branch_id': branchId,
        'purchase_date': _ymd(_purchaseDate),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (paid > 0) 'paid_amount': paid,
        'items': payloadItems,
      });
      if (!mounted) return;
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Purchase order created')),
      );
      context.go('/purchases/${purchase.id}');
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

  InputDecoration _fieldDec(String label, {String? hint}) {
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

  /// Compact decoration for item-table cells (labels live in the header row).
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

  static const _colGap = 10.0;
  static const _colNum = 36.0;
  static const _colAction = 44.0;

  @override
  Widget build(BuildContext context) {
    final subtitle = _branchSubtitle;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Purchase Order'),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _bootstrap, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          _sectionCard(
                            icon: Icons.assignment_outlined,
                            iconBg: const Color(0xFFDBEAFE),
                            iconColor: const Color(0xFF2563EB),
                            title: 'Order Details',
                            subtitle: 'Provide supplier and order information',
                            child: _buildOrderDetails(),
                          ),
                          const SizedBox(height: 16),
                          _sectionCard(
                            icon: Icons.shopping_cart_outlined,
                            iconBg: const Color(0xFFE0E7FF),
                            iconColor: const Color(0xFF4F46E5),
                            title: 'Purchase Items',
                            subtitle: 'Add products and quantities to this order',
                            child: _buildItems(),
                          ),
                          const SizedBox(height: 16),
                          _sectionCard(
                            icon: Icons.payments_outlined,
                            iconBg: const Color(0xFFEDE9FE),
                            iconColor: const Color(0xFF7C3AED),
                            title: 'Payment',
                            subtitle: 'Select payment mode and enter payment details',
                            child: _buildPayment(),
                          ),
                        ],
                      ),
                    ),
                    _buildFooter(),
                  ],
                ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildOrderDetails() {
    final wide = AppConfig.usesLargeUiScale ||
        MediaQuery.sizeOf(context).width >= AppConfig.desktopLayoutBreakpoint;

    final branch = !_isSuperAdmin
        ? null
        : AppDropdownButtonFormField<int>(
            key: ValueKey('branch-$_branchId'),
            value: _branches.any((b) => b.id == _branchId) ? _branchId : null,
            isExpanded: true,
            decoration: _fieldDec('Branch *'),
            items: [
              for (final b in _branches)
                DropdownMenuItem(
                  value: b.id,
                  child: Text(b.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _branchId = v),
          );

    final supplier = AppDropdownButtonFormField<int>(
      key: ValueKey('supplier-$_supplierId'),
      value: _supplierId,
      isExpanded: true,
      decoration: _fieldDec('Supplier *'),
      items: [
        for (final s in _suppliers)
          DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => setState(() => _supplierId = v),
    );

    final date = InkWell(
      onTap: _pickPurchaseDate,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: _fieldDec('Purchase Date *'),
        child: Row(
          children: [
            Expanded(child: Text(_ymd(_purchaseDate))),
            const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );

    final notes = TextField(
      controller: _notes,
      decoration: _fieldDec('Notes', hint: 'Optional notes'),
    );

    if (!wide) {
      return Column(
        children: [
          if (branch != null) ...[
            branch,
            const SizedBox(height: 14),
          ],
          supplier,
          const SizedBox(height: 14),
          date,
          const SizedBox(height: 14),
          notes,
        ],
      );
    }

    if (branch != null) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: branch),
              const SizedBox(width: 16),
              Expanded(child: supplier),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: date),
              const SizedBox(width: 16),
              Expanded(child: notes),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: supplier),
        const SizedBox(width: 16),
        Expanded(child: date),
        const SizedBox(width: 16),
        Expanded(child: notes),
      ],
    );
  }

  Widget _buildItems() {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide) ...[
          _itemsHeader(),
          const SizedBox(height: 4),
        ],
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) SizedBox(height: wide ? 8 : 12),
          _buildItemRow(i, wide: wide),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addItem,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Item'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: Color(0xFF93C5FD)),
            backgroundColor: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _itemsHeader() {
    const labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppTheme.textSecondary,
      letterSpacing: 0.2,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: _colNum,
            child: Text('#', textAlign: TextAlign.center, style: labelStyle),
          ),
          const SizedBox(width: _colGap),
          const Expanded(flex: 4, child: Text('Item', style: labelStyle)),
          const SizedBox(width: _colGap),
          const Expanded(flex: 2, child: Text('Batch #', style: labelStyle)),
          const SizedBox(width: _colGap),
          const Expanded(flex: 2, child: Text('Expiry', style: labelStyle)),
          const SizedBox(width: _colGap),
          const Expanded(
            flex: 1,
            child: Text('Qty', textAlign: TextAlign.right, style: labelStyle),
          ),
          const SizedBox(width: _colGap),
          const Expanded(
            flex: 2,
            child: Text('Rate (₹)', textAlign: TextAlign.right, style: labelStyle),
          ),
          const SizedBox(width: _colGap),
          const Expanded(
            flex: 2,
            child: Text('Amount (₹)', textAlign: TextAlign.right, style: labelStyle),
          ),
          const SizedBox(width: _colGap),
          const SizedBox(width: _colAction),
        ],
      ),
    );
  }

  Widget _buildItemRow(int idx, {required bool wide}) {
    final item = _items[idx];
    final options = _productsForRow(idx);

    final productField = AppSearchableDropdownField<int>(
      key: ValueKey('product-$idx-${item.productId}'),
      label: 'Item',
      value: item.productId,
      searchHint: 'Search product…',
      hint: 'Select product',
      decoration: wide
          ? _cellDec(hint: 'Select product')
          : _fieldDec('Item *'),
      options: [
        for (final p in options)
          AppSearchableOption(value: p.id, label: _productLabel(p)),
      ],
      onChanged: (v) => _onProductSelect(idx, v),
    );

    final batchField = TextField(
      controller: item.batch,
      decoration: wide ? _cellDec(hint: 'Batch #') : _fieldDec('Batch #'),
    );

    final expiryField = InkWell(
      onTap: () => _pickExpiry(idx),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: wide ? _cellDec(hint: 'Expiry') : _fieldDec('Expiry'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.expiry != null ? _ymd(item.expiry!) : (wide ? 'Select date' : 'Select'),
                style: TextStyle(
                  fontSize: 14,
                  color: item.expiry != null
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            if (item.expiry != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () => setState(() => item.expiry = null),
              )
            else
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppTheme.textSecondary,
              ),
          ],
        ),
      ),
    );

    final qtyField = TextField(
      controller: item.qty,
      textAlign: wide ? TextAlign.right : TextAlign.start,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: wide ? _cellDec(hint: '1') : _fieldDec('Qty'),
      onChanged: (_) => setState(() {}),
    );

    final rateField = TextField(
      controller: item.rate,
      textAlign: wide ? TextAlign.right : TextAlign.start,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: wide ? _cellDec(hint: '0.00') : _fieldDec('Rate (₹)'),
      onChanged: (_) => setState(() {}),
    );

    final amountCell = Container(
      height: 44,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        '₹${_formatMoney(item.amount)}',
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );

    final removeBtn = SizedBox(
      width: _colAction,
      child: IconButton(
        onPressed: _items.length <= 1 ? null : () => _removeItem(idx),
        icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 20),
        tooltip: 'Remove',
        visualDensity: VisualDensity.compact,
      ),
    );

    if (wide) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: _colNum,
              child: Text(
                '${idx + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: _colGap),
            Expanded(flex: 4, child: productField),
            const SizedBox(width: _colGap),
            Expanded(flex: 2, child: batchField),
            const SizedBox(width: _colGap),
            Expanded(flex: 2, child: expiryField),
            const SizedBox(width: _colGap),
            Expanded(flex: 1, child: qtyField),
            const SizedBox(width: _colGap),
            Expanded(flex: 2, child: rateField),
            const SizedBox(width: _colGap),
            Expanded(flex: 2, child: amountCell),
            const SizedBox(width: _colGap),
            removeBtn,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Item ${idx + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              removeBtn,
            ],
          ),
          const SizedBox(height: 8),
          productField,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: batchField),
              const SizedBox(width: 12),
              Expanded(child: expiryField),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: qtyField),
              const SizedBox(width: 12),
              Expanded(child: rateField),
            ],
          ),
          const SizedBox(height: 12),
          amountCell,
        ],
      ),
    );
  }

  Widget _buildPayment() {
    final wide = AppConfig.usesLargeUiScale ||
        MediaQuery.sizeOf(context).width >= AppConfig.desktopLayoutBreakpoint;

    final total = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Total Amount', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(
          '₹${_formatMoney(_totalAmount)}',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF16A34A),
            height: 1.2,
          ),
        ),
      ],
    );

    final mode = AppDropdownButtonFormField<String>(
      key: ValueKey('pay-$_paymentMode'),
      value: _paymentMode,
      decoration: _fieldDec('Payment Mode'),
      items: [
        for (final m in _paymentModes)
          DropdownMenuItem(value: m.$1, child: Text(m.$2)),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _paymentMode = v;
          if (v == 'credit') _paidAmount.text = '0';
        });
      },
    );

    final paid = TextField(
      controller: _paidAmount,
      enabled: _paymentMode != 'credit',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: _fieldDec('Amount Paid (₹)'),
      onChanged: (_) => setState(() {}),
    );

    final reference = TextField(
      controller: _paymentRef,
      decoration: _fieldDec('Reference #', hint: 'Cheque/UTR no.'),
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          total,
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          mode,
          const SizedBox(height: 14),
          paid,
          const SizedBox(height: 14),
          reference,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(width: 180, child: total),
        const SizedBox(width: 24),
        Expanded(child: mode),
        const SizedBox(width: 16),
        Expanded(child: paid),
        const SizedBox(width: 16),
        Expanded(child: reference),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => context.pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save Purchase Order'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
