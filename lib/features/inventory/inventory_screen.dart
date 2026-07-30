import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/inventory.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int _reloadToken = 0;

  Future<void> _openAdjust(InventoryItem item) async {
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission(AppPermissions.inventoryAdjust)) return;

    final qtyCtrl = TextEditingController(text: '1');
    final reasonCtrl = TextEditingController(text: 'Physical stock count');
    var type = 'add';
    final branchId = auth.currentBranchId;
    if (branchId == null) {
      AppMessenger.show(context, const SnackBar(content: Text('Select a branch first')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text('Adjust stock — ${item.product?.name ?? 'Product #${item.productId}'}'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Current qty: ${item.quantity.toStringAsFixed(0)}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'add', label: Text('Add')),
                        ButtonSegment(value: 'remove', label: Text('Remove')),
                        ButtonSegment(value: 'set', label: Text('Set')),
                      ],
                      selected: {type},
                      onSelectionChanged: (s) => setLocal(() => type = s.first),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(labelText: 'Reason'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
    if (qty < 0 || (type != 'set' && qty <= 0)) {
      AppMessenger.show(context, const SnackBar(content: Text('Enter a valid quantity')));
      return;
    }

    try {
      await context.read<AppServices>().inventory.adjust({
        'product_id': item.productId,
        'branch_id': branchId,
        'quantity': qty,
        'type': type,
        'reason': reasonCtrl.text.trim().isEmpty ? 'Stock adjustment' : reasonCtrl.text.trim(),
      });
      if (!mounted) return;
      AppMessenger.show(context, const SnackBar(content: Text('Stock updated')));
      setState(() => _reloadToken++);
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.watch<AuthSession>();
    final canAdjust = auth.hasPermission(AppPermissions.inventoryAdjust);
    final branchId = auth.currentBranchId;

    return Scaffold(
      body: AppPaginatedTable<InventoryItem>(
        key: ValueKey('inventory-$branchId-$_reloadToken'),
        loadPage: ({required page, required perPage}) =>
            services.inventory.listPaginated(page: page, perPage: perPage),
        onRowTap: canAdjust ? _openAdjust : null,
        columns: [
          const TableColumnDef(label: 'Product', flex: 2, cellBuilder: _productCell),
          const TableColumnDef(label: 'SKU', flex: 1, cellBuilder: _skuCell),
          const TableColumnDef(
            label: 'Qty',
            flex: 0.7,
            align: TextAlign.center,
            cellBuilder: _qtyCell,
          ),
          const TableColumnDef(
            label: 'Reserved',
            flex: 0.8,
            align: TextAlign.center,
            cellBuilder: _reservedCell,
          ),
          const TableColumnDef(
            label: 'Available',
            flex: 0.8,
            align: TextAlign.center,
            cellBuilder: _availableCell,
          ),
          if (canAdjust)
            TableColumnDef(
              label: 'Action',
              flex: 0.9,
              align: TextAlign.center,
              cellBuilder: (context, item) => TextButton(
                onPressed: () => _openAdjust(item),
                child: const Text('Adjust'),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _productCell(BuildContext context, InventoryItem it) => Text(
        it.product?.name ?? 'Product #${it.productId}',
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );

  static Widget _skuCell(BuildContext context, InventoryItem it) =>
      Text(it.product?.sku ?? '—', style: const TextStyle(color: AppTheme.textSecondary));

  static Widget _qtyCell(BuildContext context, InventoryItem it) =>
      Text(it.quantity.toStringAsFixed(0));

  static Widget _reservedCell(BuildContext context, InventoryItem it) =>
      Text(it.reservedQuantity.toStringAsFixed(0));

  static Widget _availableCell(BuildContext context, InventoryItem it) => Text(
        it.availableQuantity.toStringAsFixed(0),
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary),
      );
}
