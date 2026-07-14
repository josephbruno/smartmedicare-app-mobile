import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/product.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.productsCreate);
    final canEdit = auth.hasPermission(AppPermissions.productsEdit);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Products',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: () => context.go('/products/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Product'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AppPaginatedTable<Product>(
              emptyMessage: 'No products yet. Click New Product to add your first product.',
              loadPage: ({required page, required perPage}) =>
                  services.products.listPaginated(page: page, perPage: perPage),
              onRowTap: canEdit ? (p) => context.go('/products/${p.id}/edit') : null,
              columns: const [
                TableColumnDef(label: 'Product', flex: 2, cellBuilder: _nameCell),
                TableColumnDef(label: 'SKU', flex: 1, cellBuilder: _skuCell),
                TableColumnDef(label: 'Category', flex: 1.2, cellBuilder: _categoryCell),
                TableColumnDef(
                  label: 'Stock',
                  flex: 0.8,
                  align: TextAlign.center,
                  cellBuilder: _stockCell,
                ),
                TableColumnDef(
                  label: 'Price',
                  flex: 1,
                  align: TextAlign.right,
                  cellBuilder: _priceCell,
                ),
                TableColumnDef(
                  label: 'MRP',
                  flex: 1,
                  align: TextAlign.right,
                  cellBuilder: _mrpCell,
                ),
                TableColumnDef(
                  label: 'Status',
                  flex: 0.8,
                  align: TextAlign.center,
                  cellBuilder: _statusCell,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _nameCell(BuildContext context, Product p) => Text(
        p.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );

  static Widget _skuCell(BuildContext context, Product p) =>
      Text(p.sku ?? '—', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13));

  static Widget _categoryCell(BuildContext context, Product p) =>
      Text(p.categoryName ?? '—', style: const TextStyle(color: AppTheme.textSecondary));

  static Widget _stockCell(BuildContext context, Product p) {
    if (!p.trackInventory) {
      return const Text('—', style: TextStyle(color: AppTheme.textSecondary));
    }
    final stock = p.currentStock ?? 0;
    final color = stock <= 0
        ? AppTheme.danger
        : stock <= p.reorderLevel
            ? AppTheme.warning
            : AppTheme.accent;
    return Text(
      stock.toStringAsFixed(0),
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }

  static Widget _priceCell(BuildContext context, Product p) => Text(
        '₹${p.sellingPrice.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary),
      );

  static Widget _mrpCell(BuildContext context, Product p) => Text(
        '₹${p.mrp.toStringAsFixed(2)}',
        style: const TextStyle(color: AppTheme.textSecondary),
      );

  static Widget _statusCell(BuildContext context, Product p) => Text(
        p.isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: p.isActive ? AppTheme.accent : AppTheme.danger,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      );
}
