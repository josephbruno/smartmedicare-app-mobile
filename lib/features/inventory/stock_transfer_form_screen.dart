import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../data/models/inventory.dart';
import '../../data/models/shop.dart';

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
  List<InventoryItem> _stock = [];
  int? _toBranchId;
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
        services.inventory.listSimple(query: {'per_page': 500}),
      ]);
      setState(() {
        _branches = (results[0] as List<Branch>)
            .where((b) => b.id != branchId)
            .toList();
        _stock = results[1] as List<InventoryItem>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  int _availableFor(int? productId) {
    if (productId == null) return 0;
    final item =
        _stock.where((s) => s.productId == productId).cast<InventoryItem?>();
    final first = item.isEmpty ? null : item.first;
    if (first == null) return 0;
    return first.availableQuantity > 0 ? first.availableQuantity.floor() : first.quantity.floor();
  }

  Future<void> _submit() async {
    if (_toBranchId == null) {
      _snack('Select a target branch');
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final qty = double.tryParse(r.qty.text.trim()) ?? 0;
      if (r.productId == null || qty <= 0) continue;
      if (qty > _availableFor(r.productId)) {
        _snack('Quantity exceeds available stock for one of the items');
        return;
      }
      items.add({'product_id': r.productId, 'quantity': qty});
    }
    if (items.isEmpty) {
      _snack('Add at least one item with a quantity');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<AppServices>().inventory.createTransfer({
        'to_branch_id': _toBranchId,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'items': items,
      });
      if (!mounted) return;
      _snack('Transfer request sent. Awaiting receiver acceptance.');
      context.pop();
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    AppMessenger.show(context,SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Stock Transfer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<int>(
                      value: _toBranchId,
                      decoration:
                          const InputDecoration(labelText: 'Send to branch'),
                      items: [
                        for (final b in _branches)
                          DropdownMenuItem(value: b.id, child: Text(b.name)),
                      ],
                      onChanged: (v) => setState(() => _toBranchId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      decoration: const InputDecoration(
                          labelText: 'Notes (optional)'),
                    ),
                    const Divider(height: 32),
                    const Text('Items',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (int i = 0; i < _rows.length; i++) _buildRow(i),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _rows.add(_LineRow())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add item'),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Send Request'),
                    ),
                  ],
                ),
    );
  }

  Widget _buildRow(int i) {
    final row = _rows[i];
    final chosen = _rows
        .asMap()
        .entries
        .where((e) => e.key != i)
        .map((e) => e.value.productId)
        .toSet();
    final options = _stock
        .where((s) =>
            (_availableFor(s.productId) > 0) && !chosen.contains(s.productId))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<int>(
              value: row.productId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Product'),
              items: [
                for (final s in options)
                  DropdownMenuItem(
                    value: s.productId,
                    child: Text(
                      '${s.product?.name ?? 'Product #${s.productId}'} (${_availableFor(s.productId)})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() {
                row.productId = v;
                row.qty.clear();
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextField(
              controller: row.qty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Qty'),
            ),
          ),
          IconButton(
            onPressed: _rows.length == 1
                ? null
                : () => setState(() => _rows.removeAt(i)),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
