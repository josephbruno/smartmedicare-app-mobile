import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/inventory.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();

    return Scaffold(
      body: AppPaginatedTable<InventoryItem>(
        loadPage: ({required page, required perPage}) =>
            services.inventory.listPaginated(page: page, perPage: perPage),
        columns: const [
          TableColumnDef(label: 'Product', flex: 2, cellBuilder: _productCell),
          TableColumnDef(label: 'SKU', flex: 1, cellBuilder: _skuCell),
          TableColumnDef(
            label: 'Qty',
            flex: 0.7,
            align: TextAlign.center,
            cellBuilder: _qtyCell,
          ),
          TableColumnDef(
            label: 'Reserved',
            flex: 0.8,
            align: TextAlign.center,
            cellBuilder: _reservedCell,
          ),
          TableColumnDef(
            label: 'Available',
            flex: 0.8,
            align: TextAlign.center,
            cellBuilder: _availableCell,
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
