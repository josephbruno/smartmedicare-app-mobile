import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/product.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _search = TextEditingController();
  String? _typeFilter;
  int? _categoryId;
  String _statusFilter = 'all';
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await context.read<AppServices>().products.listCategories();
      if (!mounted) return;
      setState(() => _categories = list.where((c) => c.isActive).toList());
    } catch (_) {
      // Filters still work without categories.
    }
  }

  bool? get _isActiveFilter {
    return switch (_statusFilter) {
      'active' => true,
      'inactive' => false,
      _ => null,
    };
  }

  InputDecoration get _filterDec => const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.productsCreate);
    final canEdit = auth.hasPermission(AppPermissions.productsEdit);
    final search = _search.text.trim();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or SKU…',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => setState(() {}),
                    onChanged: (_) {
                      if (_search.text.trim().isEmpty) setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 140,
                  child: AppDropdownButtonFormField<String?>(
                    value: _typeFilter,
                    isDense: true,
                    decoration: _filterDec.copyWith(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All types')),
                      DropdownMenuItem(value: 'product', child: Text('Product')),
                      DropdownMenuItem(value: 'medicine', child: Text('Medicine')),
                      DropdownMenuItem(value: 'service', child: Text('Service')),
                    ],
                    onChanged: (v) => setState(() => _typeFilter = v),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 170,
                  child: AppDropdownButtonFormField<int?>(
                    value: _categoryId,
                    isDense: true,
                    decoration: _filterDec.copyWith(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All categories')),
                      for (final c in _categories)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 130,
                  child: AppDropdownButtonFormField<String>(
                    value: _statusFilter,
                    isDense: true,
                    decoration: _filterDec.copyWith(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _statusFilter = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Search'),
                ),
                if (canCreate) ...[
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => context.go('/products/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Product'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: AppPaginatedTable<Product>(
              key: ValueKey(
                '$search-$_typeFilter-$_categoryId-$_statusFilter',
              ),
              emptyMessage: search.length >= 2 ||
                      _typeFilter != null ||
                      _categoryId != null ||
                      _statusFilter != 'all'
                  ? 'No products match your filters.'
                  : 'No products yet. Click New Product to add your first product.',
              headerFontSize: 9,
              cellFontSize: 12,
              loadPage: ({required page, required perPage}) =>
                  services.products.listPaginated(
                    page: page,
                    perPage: perPage,
                    search: search.length >= 2 ? search : null,
                    type: _typeFilter,
                    categoryId: _categoryId,
                    isActive: _isActiveFilter,
                  ),
              onRowTap: canEdit ? (p) => context.go('/products/${p.id}/edit') : null,
              columns: const [
                TableColumnDef(label: 'Product', flex: 2, cellBuilder: _nameCell),
                TableColumnDef(label: 'Type', flex: 1, cellBuilder: _typeCell),
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

  static Widget _typeCell(BuildContext context, Product p) => Text(
        p.productTypeLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.isService
              ? AppTheme.accent
              : p.isMedicine
                  ? const Color(0xFFA21CAF)
                  : AppTheme.primary,
        ),
      );

  static Widget _skuCell(BuildContext context, Product p) =>
      Text(p.sku ?? '—', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12));

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
