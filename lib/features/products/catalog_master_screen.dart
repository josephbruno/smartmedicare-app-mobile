import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../core/widgets/web_page.dart';
import '../../data/models/api_response.dart';

enum CatalogKind { categories, brands }

/// Categories / Brands masters — mirrors `frontend/src/pages/inventory/
/// CategoriesPage.vue` and `BrandsPage.vue` (categories add a product type).
class CatalogMasterScreen extends StatefulWidget {
  const CatalogMasterScreen({super.key, required this.kind});

  final CatalogKind kind;

  @override
  State<CatalogMasterScreen> createState() => _CatalogMasterScreenState();
}

/// One row in either master.
class _Row {
  _Row({
    required this.id,
    required this.name,
    required this.isActive,
    required this.productsCount,
    this.productType,
    this.description,
  });

  final int id;
  final String name;
  final bool isActive;
  final int productsCount;
  final String? productType;
  final String? description;
}

class _CatalogMasterScreenState extends State<CatalogMasterScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _appliedSearch = '';
  String? _typeFilter;
  int _reloadToken = 0;

  static const _typeOptions = {'product': 'Product', 'medicine': 'Medicine', 'service': 'Service'};

  bool get _isCategories => widget.kind == CatalogKind.categories;
  String get _singular => _isCategories ? 'Category' : 'Brand';
  String get _plural => _isCategories ? 'Categories' : 'Brands';
  String get _perm => _isCategories ? 'categories' : 'brands';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _reloadToken++);

  Future<List<_Row>> _fetch() async {
    final svc = context.read<AppServices>().products;
    final query = <String, dynamic>{
      if (_appliedSearch.isNotEmpty) 'search': _appliedSearch,
      if (_isCategories && _typeFilter != null) 'product_type': _typeFilter,
    };
    if (_isCategories) {
      final list = await svc.listCategories(query: query);
      return [
        for (final c in list)
          _Row(
            id: c.id,
            name: c.name,
            isActive: c.isActive,
            productsCount: c.productsCount,
            productType: c.productType,
            description: c.description,
          ),
      ];
    }
    final list = await svc.listBrands(query: query);
    return [
      for (final b in list)
        _Row(id: b.id, name: b.name, isActive: b.isActive, productsCount: b.productsCount, description: b.description),
    ];
  }

  Future<void> _openForm([_Row? row]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CatalogFormDialog(kind: widget.kind, row: row),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(_Row row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_singular.toLowerCase()}'),
        content: Text(_isCategories
            ? 'Delete "${row.name}"? Its products will become uncategorised.'
            : 'Delete "${row.name}"? Its products will no longer have a brand.'),
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
      final svc = context.read<AppServices>().products;
      _isCategories ? await svc.deleteCategory(row.id) : await svc.deleteBrand(row.id);
      if (!mounted) return;
      AppMessenger.success(context, '$_singular deleted');
      _reload();
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Failed to delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    bool can(String action) => auth.hasPermission('$_perm.$action');

    return Scaffold(
      backgroundColor: AppTokens.bgSecondary,
      body: WebPageScaffold(
        title: _plural,
        subtitle: _isCategories
            ? 'Group products, medicines and services for search and reports.'
            : 'Manufacturer and brand names used on products.',
        icon: _isCategories ? Icons.folder_outlined : Icons.sell_outlined,
        breadcrumbs: [const Crumb('Inventory'), Crumb(_plural)],
        actions: [
          if (can('create')) FilledButton(onPressed: () => _openForm(), child: Text('Add $_singular')),
        ],
        filters: FilterCard(
          searchController: _search,
          searchHint: 'Search ${_plural.toLowerCase()}...',
          onSearchChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              _appliedSearch = v.trim();
              _reload();
            });
          },
          filters: [
            if (_isCategories)
              FilterSelect<String>(
                hint: 'All types',
                options: _typeOptions,
                value: _typeFilter,
                onChanged: (v) {
                  _typeFilter = v;
                  _reload();
                },
              ),
          ],
        ),
        body: AppPaginatedTable<_Row>(
          key: ValueKey('${widget.kind}-$_reloadToken'),
          perPage: 20,
          emptyMessage: 'No ${_plural.toLowerCase()} found.',
          // The API returns the full list; paginate on the client.
          loadPage: ({required page, required perPage}) async {
            final all = await _fetch();
            final r = paginateList(all, page: page, perPage: perPage);
            return (items: r.items, meta: r.meta as PaginationMeta?);
          },
          columns: [
            TableColumnDef(label: '$_singular Name', flex: 2.4, minWidth: 200, cellBuilder: (_, r) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if ((r.description ?? '').isNotEmpty)
                    Text(r.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                ],
              );
            }),
            if (_isCategories)
              TableColumnDef(
                label: 'Product Type',
                flex: 1.2,
                minWidth: 120,
                cellBuilder: (_, r) => StatusPill(
                  _typeOptions[r.productType] ?? 'All types',
                  tone: r.productType == null ? PillTone.grey : PillTone.blue,
                ),
              ),
            TableColumnDef(
              label: 'Products',
              flex: 0.8,
              minWidth: 90,
              cellBuilder: (_, r) => Text('${r.productsCount}'),
            ),
            TableColumnDef(
              label: 'Status',
              flex: 0.9,
              minWidth: 100,
              cellBuilder: (_, r) => r.isActive
                  ? const StatusPill('Active', tone: PillTone.green)
                  : const StatusPill('Inactive', tone: PillTone.grey),
            ),
            TableColumnDef(
              label: 'Actions',
              flex: 1,
              minWidth: 110,
              cellBuilder: (_, r) => Row(mainAxisSize: MainAxisSize.min, children: [
                if (can('edit')) TableIconButton(icon: Icons.edit_outlined, tooltip: 'Edit', onPressed: () => _openForm(r)),
                if (can('delete')) ...[
                  const SizedBox(width: 8),
                  TableIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    plain: true,
                    color: AppTokens.error,
                    onPressed: () => _delete(r),
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

class _CatalogFormDialog extends StatefulWidget {
  const _CatalogFormDialog({required this.kind, this.row});

  final CatalogKind kind;
  final _Row? row;

  @override
  State<_CatalogFormDialog> createState() => _CatalogFormDialogState();
}

class _CatalogFormDialogState extends State<_CatalogFormDialog> {
  late final _name = TextEditingController(text: widget.row?.name ?? '');
  late final _description = TextEditingController(text: widget.row?.description ?? '');
  late String? _type = widget.row?.productType;
  late bool _active = widget.row?.isActive ?? true;
  bool _saving = false;

  bool get _isCategories => widget.kind == CatalogKind.categories;
  String get _singular => _isCategories ? 'Category' : 'Brand';

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      AppMessenger.error(context, '$_singular name is required');
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'is_active': _active,
      if (_isCategories) 'product_type': _type,
    };
    try {
      final svc = context.read<AppServices>().products;
      final id = widget.row?.id;
      if (_isCategories) {
        id == null ? await svc.createCategory(body) : await svc.updateCategory(id, body);
      } else {
        id == null ? await svc.createBrand(body) : await svc.updateBrand(id, body);
      }
      if (!mounted) return;
      AppMessenger.success(context, '$_singular saved');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'Failed to save ${_singular.toLowerCase()}: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.row == null ? 'Add $_singular' : 'Edit $_singular'),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FieldLabel('$_singular Name',
              required: true,
              child: TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(hintText: 'Enter ${_singular.toLowerCase()} name'),
              )),
          if (_isCategories) ...[
            const SizedBox(height: 12),
            FieldLabel('Product Type',
                child: FilterSelect<String>(
                  hint: 'All product types',
                  options: _CatalogMasterScreenState._typeOptions,
                  value: _type,
                  onChanged: (v) => setState(() => _type = v),
                )),
          ],
          const SizedBox(height: 12),
          FieldLabel('Description', child: TextField(controller: _description, maxLines: 3)),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Active', style: TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Switch(value: _active, onChanged: (v) => setState(() => _active = v)),
          ]),
        ]),
      ),
      actions: [
        OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
