import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../data/models/shop.dart';
import '../../core/widgets/app_dropdown.dart';

class _LineRow {
  int? productId;
  final TextEditingController qty = TextEditingController();
}

class StockTransferFormScreen extends StatefulWidget {
  const StockTransferFormScreen({super.key});

  @override
  State<StockTransferFormScreen> createState() =>
      _StockTransferFormScreenState();
}

class _StockTransferFormScreenState extends State<StockTransferFormScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Branch> _branches = [];
  List<Product> _products = [];
  int? _fromBranchId;
  final TextEditingController _notes = TextEditingController();
  final List<_LineRow> _rows = [_LineRow()];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final r in _rows) {
      r.qty.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = context.read<AppServices>();
      final branchId = context.read<AuthSession>().currentBranchId;
      final results = await Future.wait([
        services.branches.list(),
        services.products.listAll(isActive: true),
      ]);
      final products = (results[1] as List<Product>).where(_isStockItem).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _branches = (results[0] as List<Branch>)
            .where((b) => b.id != branchId)
            .toList();
        _products = products;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_fromBranchId == null) {
      _snack('Select the branch to request from');
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final qty = double.tryParse(r.qty.text.trim()) ?? 0;
      if (r.productId == null || qty <= 0) continue;
      items.add({'product_id': r.productId, 'quantity': qty});
    }
    if (items.isEmpty) {
      _snack('Add at least one item with a quantity');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<AppServices>().inventory.createTransfer({
        'from_branch_id': _fromBranchId,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'items': items,
      });
      if (!mounted) return;
      _snack('Transfer request sent. Awaiting source branch approval.');
      context.pop();
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

  bool _isStockItem(Product p) => !p.isService && p.trackInventory;

  List<Product> _productsForRow(int rowIdx) {
    final currentId = _rows[rowIdx].productId;
    final used = _rows
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

  String? _productSubtitle(Product p) {
    final parts = <String>[
      if (p.brandName != null && p.brandName!.trim().isNotEmpty)
        p.brandName!.trim(),
      if (p.categoryName != null && p.categoryName!.trim().isNotEmpty)
        p.categoryName!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  AppSearchableOption<int> _optionFor(Product p) {
    return AppSearchableOption(
      value: p.id,
      label: _productLabel(p),
      subtitle: _productSubtitle(p),
    );
  }

  void _mergeProducts(Iterable<Product> incoming) {
    final byId = {for (final p in _products) p.id: p};
    var changed = false;
    for (final p in incoming) {
      if (!_isStockItem(p) || !p.isActive) continue;
      if (byId.containsKey(p.id)) continue;
      byId[p.id] = p;
      changed = true;
    }
    if (!changed) return;
    _products = byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<List<AppSearchableOption<int>>> _searchCatalog(
    int rowIdx,
    String query,
  ) async {
    final q = query.trim().replaceAll('%', '').replaceAll('_', ' ').trim();
    if (q.isEmpty) {
      return [for (final p in _productsForRow(rowIdx)) _optionFor(p)];
    }
    final result = await context.read<AppServices>().products.listPaginated(
      page: 1,
      perPage: 80,
      search: q,
      isActive: true,
    );
    final currentId = _rows[rowIdx].productId;
    final used = _rows
        .asMap()
        .entries
        .where((e) => e.key != rowIdx && e.value.productId != null)
        .map((e) => e.value.productId!)
        .toSet();
    final goods = result.items
        .where(_isStockItem)
        .where((p) => !used.contains(p.id) || p.id == currentId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _mergeProducts(goods);
    return [for (final p in goods) _optionFor(p)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('New Stock Request'),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      backgroundColor: AppTheme.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildDetailsCard(),
                    const SizedBox(height: 20),
                    _buildItemsCard(),
                    const SizedBox(height: 28),
                    _buildActions(),
                  ],
                ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Request Details',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          AppDropdownButtonFormField<int>(
            value: _fromBranchId,
            decoration: InputDecoration(
              labelText: 'Request from branch *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            items: [
              for (final b in _branches)
                DropdownMenuItem(
                  value: b.id,
                  child: Text(
                    b.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _fromBranchId = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              hintText: 'Add any special instructions or comments',
              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Items',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              Text(
                '${_rows.where((r) => r.productId != null).length} item${_rows.where((r) => r.productId != null).length != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < _rows.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < _rows.length - 1 ? 10 : 0),
              child: _buildRow(i),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _rows.add(_LineRow())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add item'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Send Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _saving ? null : () => context.pop(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildRow(int i) {
    final row = _rows[i];
    final options = _productsForRow(i);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: AppSearchableDropdownField<int>(
              key: ValueKey('product-$i-${row.productId}'),
              label: 'Product',
              value: row.productId,
              searchHint: 'Search name, SKU or barcode…',
              hint: 'Search item',
              allowClear: true,
              decoration: InputDecoration(
                labelText: 'Product',
                hintText: 'Search item',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: Colors.white,
              ),
              options: [
                for (final p in options) _optionFor(p),
              ],
              displayText: (id) {
                final match = _products.where((p) => p.id == id);
                return match.isEmpty ? 'Product #$id' : _productLabel(match.first);
              },
              asyncSearch: (q) => _searchCatalog(i, q),
              onChanged: (v) => setState(() {
                row.productId = v;
                row.qty.clear();
              }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: TextField(
              controller: row.qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Qty',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_rows.length > 1)
            IconButton(
              onPressed: () => setState(() => _rows.removeAt(i)),
              icon: const Icon(Icons.close, size: 20),
              color: AppTheme.danger,
              tooltip: 'Remove item',
            ),
        ],
      ),
    );
  }
}
