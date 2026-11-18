import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/ist.dart';
import '../../core/utils/save_file.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../core/widgets/web_page.dart';
import '../../data/models/product.dart';
import '../subscription/plan_guard.dart';

/// Products — mirrors `frontend/src/pages/inventory/ProductListPage.vue`:
/// Import / Sample / Datasheet / Add, 5 stat cards, search + category /
/// stock / type filters, table with edit & delete.
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _appliedSearch = '';
  int? _categoryId;
  String? _stockStatus;
  String? _type;
  int _reloadToken = 0;
  List<Category> _categories = [];
  Map<String, int> _stats = const {};
  bool _importing = false;
  bool _downloadingTemplate = false;
  List<Product> _pageItems = const [];

  static const _stockOptions = {'in_stock': 'In Stock', 'low_stock': 'Low Stock', 'out_of_stock': 'Out of Stock'};
  static const _typeOptions = {'product': 'Product', 'medicine': 'Medicine', 'service': 'Service'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
      _loadStats();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await context.read<AppServices>().products.listCategories();
      if (mounted) setState(() => _categories = list.where((c) => c.isActive).toList());
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final s = await context.read<AppServices>().products.stats();
      if (mounted) setState(() => _stats = s);
    } catch (_) {
      // Cards fall back to 0; the table still loads.
    }
  }

  void _reload() => setState(() => _reloadToken++);

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _appliedSearch = v.trim();
      _reload();
    });
  }

  void _reset() {
    _search.clear();
    _appliedSearch = '';
    _categoryId = null;
    _stockStatus = null;
    _type = null;
    _reload();
  }

  Future<void> _addProduct() async {
    if (await ensurePlanAllows(context, limitResource: 'products') && mounted) {
      await context.push('/products/new');
      if (mounted) {
        _reload();
        _loadStats();
      }
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null || !mounted) return;
    setState(() => _importing = true);
    try {
      final r = await context.read<AppServices>().products.importFile(
            fileName: file.name,
            bytes: file.bytes,
            path: file.path,
          );
      if (!mounted) return;
      final failed = (r['failed'] as num?)?.toInt() ?? 0;
      if (failed == 0) {
        AppMessenger.success(context, 'Import complete: ${r['created'] ?? 0} created, ${r['updated'] ?? 0} updated');
      } else {
        AppMessenger.error(context, 'Import finished with $failed failed row(s)');
        final errors = (r['errors'] as List?) ?? const [];
        if (errors.isNotEmpty) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Import errors'),
              content: SizedBox(
                width: 480,
                child: ListView(shrinkWrap: true, children: [
                  for (final e in errors)
                    ListTile(
                      dense: true,
                      title: Text(e is Map ? 'Row ${e['row'] ?? '?'}' : '$e'),
                      subtitle: e is Map ? Text('${e['message'] ?? e['errors'] ?? ''}') : null,
                    ),
                ]),
              ),
              actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
            ),
          );
        }
      }
      _reload();
      _loadStats();
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Failed to import products: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _downloadTemplate() async {
    setState(() => _downloadingTemplate = true);
    try {
      final bytes = await context.read<AppServices>().products.importTemplateBytes();
      await saveBytesAs('products-import-template.xlsx', Uint8List.fromList(bytes));
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Failed to download template: $e');
    } finally {
      if (mounted) setState(() => _downloadingTemplate = false);
    }
  }

  Future<void> _export() async {
    if (_pageItems.isEmpty) {
      AppMessenger.error(context, 'No products to export');
      return;
    }
    await saveCsv(
      'products-${todayIst()}.csv',
      const ['Name', 'SKU', 'Barcode', 'Category', 'Selling Price', 'MRP', 'GST%', 'Stock', 'Type', 'Status'],
      _pageItems.map((p) => [
            p.name,
            p.sku,
            p.barcode,
            p.categoryName,
            p.sellingPrice,
            p.mrp,
            p.gstRate,
            p.trackInventory ? p.currentStock ?? 0 : '',
            _typeLabel(p),
            p.isActive ? 'Active' : 'Inactive',
          ]),
    );
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product'),
        content: Text('Are you sure you want to delete "${p.name}"? This cannot be undone.'),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppServices>().products.delete(p.id);
      if (!mounted) return;
      AppMessenger.success(context, 'Product deleted');
      _reload();
      _loadStats();
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Failed to delete product: $e');
    }
  }

  static String _typeLabel(Product p) => p.isService ? 'Service' : p.isMedicine ? 'Medicine' : 'Product';

  static PillTone _typeTone(Product p) => p.isService ? PillTone.purple : p.isMedicine ? PillTone.blue : PillTone.green;

  static Color _stockColor(Product p) {
    final stock = p.currentStock ?? 0;
    if (stock <= 0) return AppTokens.error;
    if (stock <= p.reorderLevel) return const Color(0xFFF97316);
    return AppTokens.success;
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.watch<AuthSession>();
    final canCreate = auth.hasPermission(AppPermissions.productsCreate);
    final canEdit = auth.hasPermission(AppPermissions.productsEdit);
    final canDelete = auth.hasPermission(AppPermissions.productsDelete);

    int st(String k) => _stats[k] ?? 0;
    final kpis = [
      KpiData(label: 'Total Products', value: '${st('total')}', icon: Icons.inventory_2_outlined, sub: 'All products in system'),
      KpiData(label: 'In Stock', value: '${st('in_stock')}', icon: Icons.layers_outlined, tone: KpiTone.green, sub: 'Available for sale'),
      KpiData(label: 'Low Stock', value: '${st('low_stock')}', icon: Icons.warning_amber_outlined, tone: KpiTone.orange, sub: 'Products need attention'),
      KpiData(label: 'Out of Stock', value: '${st('out_of_stock')}', icon: Icons.archive_outlined, tone: KpiTone.red, sub: 'Currently unavailable'),
      KpiData(label: 'Categories', value: '${_categories.length}', icon: Icons.sell_outlined, tone: KpiTone.purple, sub: 'Total product categories'),
    ];

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: 'Products',
        subtitle: 'Manage products, services, prices, categories, and import data.',
        icon: Icons.inventory_2_outlined,
        actions: [
          if (canCreate)
            OutlinedButton.icon(
              onPressed: _importing ? null : _import,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(_importing ? 'Importing…' : 'Import'),
            ),
          OutlinedButton.icon(
            onPressed: _downloadingTemplate ? null : _downloadTemplate,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Sample'),
          ),
          if (canEdit && auth.hasCapability('inventory'))
            OutlinedButton.icon(
              onPressed: () => context.go('/products/datasheet'),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Datasheet'),
            ),
          if (canCreate) FilledButton(onPressed: _addProduct, child: const Text('Add Product')),
        ],
        kpis: kpis,
        filters: FilterCard(
          searchController: _search,
          searchHint: 'Search products by name, SKU or barcode...',
          onSearchChanged: _onSearch,
          filters: [
            FilterSelect<int>(
              hint: 'All Categories',
              options: {for (final c in _categories) c.id: c.name},
              value: _categoryId,
              onChanged: (v) {
                _categoryId = v;
                _reload();
              },
            ),
            FilterSelect<String>(
              hint: 'All Stock Status',
              options: _stockOptions,
              value: _stockStatus,
              onChanged: (v) {
                _stockStatus = v;
                _reload();
              },
            ),
            FilterSelect<String>(
              hint: 'All Types',
              options: _typeOptions,
              value: _type,
              onChanged: (v) {
                _type = v;
                _reload();
              },
            ),
          ],
          trailing: [
            OutlinedButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Export'),
            ),
          ],
          onReset: _reset,
          resetEnabled: _appliedSearch.isNotEmpty || _categoryId != null || _stockStatus != null || _type != null,
        ),
        body: AppPaginatedTable<Product>(
          key: ValueKey('products-$_reloadToken'),
          perPage: 10,
          emptyMessage: 'No products found.',
          loadPage: ({required page, required perPage}) async {
            final res = await services.products.listPaginated(
              page: page,
              perPage: perPage,
              search: _appliedSearch,
              categoryId: _categoryId,
              type: _type,
              filters: {'stock_status': _stockStatus},
            );
            // Rows on screen, for "Export" (same as the web: current page).
            _pageItems = res.items;
            return res;
          },
          onRowTap: canEdit ? (p) => context.push('/products/${p.id}/edit').then((_) => _reload()) : null,
          mobileItemBuilder: (context, p) => _ProductTile(
            product: p,
            onEdit: canEdit ? () => context.push('/products/${p.id}/edit').then((_) => _reload()) : null,
            onDelete: canDelete ? () => _delete(p) : null,
          ),
          columns: [
            TableColumnDef(
              label: 'Product Name',
              flex: 2.6,
              minWidth: 260,
              cellBuilder: (_, p) {
                return Row(children: [
                  _ProductAvatar(product: p),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if ((p.sku ?? '').isNotEmpty || (p.barcode ?? '').isNotEmpty)
                          Text(
                            [
                              if ((p.sku ?? '').isNotEmpty) 'SKU: ${p.sku}',
                              if ((p.barcode ?? '').isNotEmpty) 'Barcode: ${p.barcode}',
                            ].join(' | '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTokens.text3),
                          ),
                      ],
                    ),
                  ),
                ]);
              },
            ),
            TableColumnDef(
              label: 'Category',
              flex: 1.3,
              minWidth: 130,
              cellBuilder: (_, p) => (p.categoryName ?? '').isEmpty
                  ? const Text('—', style: TextStyle(color: AppTokens.text3))
                  : StatusPill(p.categoryName!, tone: PillTone.blue),
            ),
            TableColumnDef(
              label: 'Selling Price',
              flex: 1.1,
              minWidth: 110,
              cellBuilder: (_, p) =>
                  Text('₹${p.sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            TableColumnDef(
              label: 'MRP',
              flex: 1,
              minWidth: 100,
              cellBuilder: (_, p) => Text('₹${p.mrp.toStringAsFixed(2)}', style: const TextStyle(color: AppTokens.text3)),
            ),
            TableColumnDef(
              label: 'GST%',
              flex: 0.7,
              minWidth: 70,
              cellBuilder: (_, p) => Text('${p.gstRate % 1 == 0 ? p.gstRate.toInt() : p.gstRate}%'),
            ),
            TableColumnDef(
              label: 'Stock',
              flex: 0.8,
              minWidth: 80,
              cellBuilder: (_, p) => !p.trackInventory
                  ? const Text('—', style: TextStyle(color: AppTokens.placeholder))
                  : Text(
                      '${(p.currentStock ?? 0) % 1 == 0 ? (p.currentStock ?? 0).toInt() : p.currentStock}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: _stockColor(p)),
                    ),
            ),
            TableColumnDef(
              label: 'Type',
              flex: 1,
              minWidth: 100,
              cellBuilder: (_, p) => StatusPill(_typeLabel(p), tone: _typeTone(p)),
            ),
            TableColumnDef(
              label: 'Status',
              flex: 0.9,
              minWidth: 100,
              cellBuilder: (_, p) => p.isActive
                  ? const StatusPill('● Active', tone: PillTone.green)
                  : const StatusPill('● Inactive', tone: PillTone.grey),
            ),
            TableColumnDef(
              label: 'Actions',
              flex: 1,
              minWidth: 100,
              cellBuilder: (_, p) => Row(mainAxisSize: MainAxisSize.min, children: [
                if (canEdit)
                  TableIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    onPressed: () => context.push('/products/${p.id}/edit').then((_) => _reload()),
                  ),
                if (canDelete) ...[
                  const SizedBox(width: 8),
                  TableIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    plain: true,
                    color: AppTokens.error,
                    onPressed: () => _delete(p),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductAvatar extends StatelessWidget {
  const _ProductAvatar({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final (bg, fg, icon) = p.isService
        ? (const Color(0xFFF3E8FF), AppTokens.purple, Icons.medical_services_outlined)
        : p.isMedicine
            ? (const Color(0xFFDBEAFE), AppTokens.info, Icons.medication_outlined)
            : (const Color(0xFFDCFCE7), AppTokens.success, Icons.inventory_2_outlined);
    return Container(
      width: 38,
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: (p.imageUrl ?? '').isNotEmpty
          ? Image.network(p.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(icon, color: fg, size: 20))
          : Icon(icon, color: fg, size: 20),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, this.onEdit, this.onDelete});

  final Product product;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppTokens.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _ProductAvatar(product: p),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTokens.text1)),
                    if ((p.sku ?? '').isNotEmpty)
                      Text('SKU: ${p.sku}', style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                  ]),
                ),
                StatusPill(_ProductListScreenState._typeLabel(p), tone: _ProductListScreenState._typeTone(p)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Selling Price', style: TextStyle(fontSize: 11, color: AppTokens.text3)),
                    Text('₹${p.sellingPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTokens.primary)),
                  ]),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('MRP', style: TextStyle(fontSize: 11, color: AppTokens.text3)),
                    Text('₹${p.mrp.toStringAsFixed(2)}', style: const TextStyle(color: AppTokens.text2)),
                  ]),
                ),
                if (p.trackInventory)
                  Text('${(p.currentStock ?? 0) % 1 == 0 ? (p.currentStock ?? 0).toInt() : p.currentStock} in stock',
                      style: TextStyle(fontWeight: FontWeight.w700, color: _ProductListScreenState._stockColor(p)))
                else
                  const Text('No inventory', style: TextStyle(color: AppTokens.text3, fontSize: 12)),
              ]),
              if (onEdit != null || onDelete != null) ...[
                const Divider(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (onEdit != null) OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AppTokens.error),
                      onPressed: onDelete,
                      child: const Text('Delete'),
                    ),
                  ],
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
