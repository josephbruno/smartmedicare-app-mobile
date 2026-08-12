import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../data/models/product.dart';
import '../../data/models/product_datasheet.dart';

class ProductDatasheetScreen extends StatefulWidget {
  const ProductDatasheetScreen({super.key});

  @override
  State<ProductDatasheetScreen> createState() => _ProductDatasheetScreenState();
}

class _ProductDatasheetScreenState extends State<ProductDatasheetScreen> {
  ProductDatasheet? _sheet;
  List<Category> _categories = [];
  List<Brand> _brands = [];
  List<Unit> _units = [];
  bool _loading = true;
  String? _error;
  String? _lastSavedAt;
  bool _syncingAll = false;

  final Map<int, _RowEditors> _editors = {};
  final Map<int, Timer?> _debounce = {};
  final Map<int, bool> _saving = {};

  static const _gstRates = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    for (final t in _debounce.values) {
      t?.cancel();
    }
    for (final e in _editors.values) {
      e.dispose();
    }
    super.dispose();
  }

  AppServices get _services => context.read<AppServices>();

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = _services.products;
      final results = await Future.wait([
        _services.productDatasheets.current(),
        products.listCategories(),
        products.listBrands(),
        products.listUnits(),
      ]);
      final sheet = results[0] as ProductDatasheet;
      if (!mounted) return;
      setState(() {
        _sheet = sheet;
        _categories = (results[1] as List<Category>).where((c) => c.isActive).toList();
        _brands = (results[2] as List<Brand>).where((b) => b.isActive).toList();
        _units = (results[3] as List<Unit>).where((u) => u.isActive).toList();
        _syncEditors(sheet.rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _syncEditors(List<ProductDatasheetRow> rows) {
    final ids = rows.map((r) => r.id).toSet();
    for (final id in _editors.keys.toList()) {
      if (!ids.contains(id)) {
        _editors.remove(id)?.dispose();
        _debounce.remove(id)?.cancel();
        _saving.remove(id);
      }
    }
    for (final row in rows) {
      final existing = _editors[row.id];
      if (existing == null) {
        _editors[row.id] = _RowEditors.fromRow(row);
      } else if (!(_saving[row.id] ?? false)) {
        existing.syncFromRow(row);
      }
    }
  }

  void _scheduleSave(ProductDatasheetRow row, {bool forceMatch = false}) {
    _debounce[row.id]?.cancel();
    _debounce[row.id] = Timer(const Duration(milliseconds: 700), () {
      _saveRow(row, forceMatch: forceMatch);
    });
  }

  void _applyEditorsToRow(ProductDatasheetRow row) {
    final e = _editors[row.id];
    if (e == null) return;
    row.name = e.name.text.trim().isEmpty ? null : e.name.text.trim();
    row.sku = e.sku.text.trim().isEmpty ? null : e.sku.text.trim();
    row.barcode = e.barcode.text.trim().isEmpty ? null : e.barcode.text.trim();
    row.hsnCode = e.hsn.text.trim().isEmpty ? null : e.hsn.text.trim();
    row.purchasePrice = double.tryParse(e.purchase.text.trim());
    row.sellingPrice = double.tryParse(e.selling.text.trim());
    row.mrp = double.tryParse(e.mrp.text.trim());
    row.gstRate = e.gstRate;
    row.gstType = e.gstType;
    row.categoryId = e.categoryId;
    row.brandId = e.brandId;
    row.unitId = e.unitId;
    row.categoryName = e.categoryName;
    row.brandName = e.brandName;
    row.unitName = e.unitName;
    row.isMedicine = e.isMedicine;
    row.isService = e.isService;
    row.hasBatch = e.hasBatch;
  }

  Future<void> _saveRow(ProductDatasheetRow row, {bool forceMatch = false}) async {
    final sheet = _sheet;
    if (sheet == null) return;
    _applyEditorsToRow(row);

    setState(() => _saving[row.id] = true);
    try {
      if (forceMatch &&
          ((row.barcode != null && row.barcode!.isNotEmpty) ||
              (row.sku != null && row.sku!.isNotEmpty))) {
        try {
          final matched = await _services.productDatasheets.applyMatch(
            datasheetId: sheet.id,
            rowId: row.id,
            barcode: row.barcode,
            sku: row.sku,
          );
          row.applyFrom(matched);
          _editors[row.id]?.syncFromRow(matched);
        } catch (_) {
          // No existing product — continue with normal save/create.
        }
      }

      final updated = await _services.productDatasheets.updateRow(
        sheet.id,
        row.id,
        row.toPayload(autoSync: true),
      );
      if (!mounted) return;
      row.applyFrom(updated);
      _editors[row.id]?.syncFromRow(updated);
      setState(() {
        _saving[row.id] = false;
        _lastSavedAt = TimeOfDay.now().format(context);
        _recomputeCounts();
      });
      await _refreshCatalogIfNeeded(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving[row.id] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed (row ${row.rowNo}): $e')),
      );
    }
  }

  Future<void> _refreshCatalogIfNeeded(ProductDatasheetRow row) async {
    var changed = false;
    if (row.categoryId != null &&
        !_categories.any((c) => c.id == row.categoryId) &&
        row.categoryName != null) {
      _categories = [
        ..._categories,
        Category(id: row.categoryId!, name: row.categoryName!, isActive: true),
      ]..sort((a, b) => a.name.compareTo(b.name));
      changed = true;
    }
    if (row.brandId != null &&
        !_brands.any((b) => b.id == row.brandId) &&
        row.brandName != null) {
      _brands = [
        ..._brands,
        Brand(id: row.brandId!, name: row.brandName!, isActive: true),
      ]..sort((a, b) => a.name.compareTo(b.name));
      changed = true;
    }
    if (row.unitId != null && !_units.any((u) => u.id == row.unitId)) {
      try {
        _units = await _services.products.listUnits();
        changed = true;
      } catch (_) {}
    }
    if (changed && mounted) setState(() {});
  }

  void _recomputeCounts() {
    final sheet = _sheet;
    if (sheet == null) return;
    // counts come from server on reload; local display uses row statuses
  }

  Future<void> _addRows() async {
    final sheet = _sheet;
    if (sheet == null) return;
    try {
      final updated = await _services.productDatasheets.addRows(sheet.id, count: 5);
      if (!mounted) return;
      setState(() {
        _sheet = updated;
        _syncEditors(updated.rows);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _syncAll() async {
    final sheet = _sheet;
    if (sheet == null) return;
    setState(() => _syncingAll = true);
    try {
      final result = await _services.productDatasheets.syncAll(sheet.id);
      if (!mounted) return;
      setState(() {
        _sheet = result.sheet;
        _syncEditors(result.sheet.rows);
        _syncingAll = false;
      });
      final synced = result.result['synced'] ?? 0;
      final failed = result.result['failed'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced $synced row(s), $failed failed.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _newSheet() async {
    try {
      final sheet = await _services.productDatasheets.create(emptyRows: 10);
      if (!mounted) return;
      for (final e in _editors.values) {
        e.dispose();
      }
      _editors.clear();
      setState(() {
        _sheet = sheet;
        _syncEditors(sheet.rows);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _onCategoryChanged(ProductDatasheetRow row, int? id) async {
    final e = _editors[row.id];
    if (e == null) return;
    if (id == null) {
      e.categoryId = null;
      e.categoryName = null;
      row.categoryId = null;
      row.categoryName = null;
      setState(() {});
      _scheduleSave(row);
      return;
    }
    final cat = _categories.cast<Category?>().firstWhere(
          (c) => c?.id == id,
          orElse: () => null,
        );
    e.categoryId = id;
    e.categoryName = cat?.name;
    row.categoryId = id;
    row.categoryName = cat?.name;
    setState(() {});
    _scheduleSave(row);
  }

  Future<void> _createCategoryForRow(ProductDatasheetRow row, String name) async {
    final sheet = _sheet;
    if (sheet == null || name.trim().isEmpty) return;
    try {
      final updated = await _services.productDatasheets.resolveCatalog(
        datasheetId: sheet.id,
        rowId: row.id,
        type: 'category',
        name: name.trim(),
      );
      if (!mounted) return;
      row.applyFrom(updated);
      _editors[row.id]?.syncFromRow(updated);
      await _refreshCatalogIfNeeded(updated);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _onBrandChanged(ProductDatasheetRow row, int? id) async {
    final e = _editors[row.id];
    if (e == null) return;
    if (id == null) {
      e.brandId = null;
      e.brandName = null;
      row.brandId = null;
      row.brandName = null;
      setState(() {});
      _scheduleSave(row);
      return;
    }
    final brand = _brands.cast<Brand?>().firstWhere(
          (b) => b?.id == id,
          orElse: () => null,
        );
    e.brandId = id;
    e.brandName = brand?.name;
    row.brandId = id;
    row.brandName = brand?.name;
    setState(() {});
    _scheduleSave(row);
  }

  Future<void> _createBrandForRow(ProductDatasheetRow row, String name) async {
    final sheet = _sheet;
    if (sheet == null || name.trim().isEmpty) return;
    try {
      final updated = await _services.productDatasheets.resolveCatalog(
        datasheetId: sheet.id,
        rowId: row.id,
        type: 'brand',
        name: name.trim(),
      );
      if (!mounted) return;
      row.applyFrom(updated);
      _editors[row.id]?.syncFromRow(updated);
      await _refreshCatalogIfNeeded(updated);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _promptCreateCatalog({
    required ProductDatasheetRow row,
    required String type,
  }) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'category' ? 'New category' : 'New brand'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: type == 'category' ? 'Category name' : 'Brand name',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (type == 'category') {
      await _createCategoryForRow(row, name);
    } else {
      await _createBrandForRow(row, name);
    }
  }

  Color _rowTint(String status) {
    switch (status) {
      case 'synced':
        return AppTheme.accent.withValues(alpha: 0.08);
      case 'matched':
        return AppTheme.primary.withValues(alpha: 0.08);
      case 'ready':
        return AppTheme.primary.withValues(alpha: 0.05);
      case 'incomplete':
        return AppTheme.warning.withValues(alpha: 0.10);
      case 'error':
        return AppTheme.danger.withValues(alpha: 0.10);
      default:
        return Colors.transparent;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'synced':
        return AppTheme.accent;
      case 'matched':
      case 'ready':
        return AppTheme.primary;
      case 'incomplete':
        return AppTheme.warning;
      case 'error':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _statusLabel(ProductDatasheetRow row) {
    if (_saving[row.id] == true) return 'Saving…';
    switch (row.status) {
      case 'synced':
        return row.action == 'update' ? 'Synced (update)' : 'Synced (create)';
      case 'matched':
        return 'Matched';
      case 'ready':
        return 'Ready';
      case 'incomplete':
        return 'Incomplete';
      case 'error':
        return 'Error';
      default:
        return 'Draft';
    }
  }

  Map<String, int> get _localCounts {
    final rows = _sheet?.rows ?? [];
    final map = {
      'synced': 0,
      'matched': 0,
      'ready': 0,
      'incomplete': 0,
      'error': 0,
      'draft': 0,
    };
    for (final r in rows) {
      map[r.status] = (map[r.status] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_sheet?.title ?? 'Product datasheet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/products'),
        ),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _newSheet,
            icon: const Icon(Icons.note_add_outlined, size: 18),
            label: const Text('New sheet'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _bootstrap, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildSummaryBar(),
                    Expanded(child: _buildGrid()),
                    _buildFooter(),
                  ],
                ),
    );
  }

  Widget _buildSummaryBar() {
    final c = _localCounts;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _chip('Synced ${c['synced']}', AppTheme.accent),
                _chip('Matched ${c['matched']}', AppTheme.primary),
                _chip('Ready ${c['ready']}', AppTheme.primary),
                _chip('Incomplete ${c['incomplete']}', AppTheme.warning),
                _chip('Error ${c['error']}', AppTheme.danger),
                _chip('Draft ${c['draft']}', AppTheme.textSecondary),
                if (_lastSavedAt != null)
                  Text(
                    'Last saved $_lastSavedAt',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _syncingAll ? null : _syncAll,
            icon: _syncingAll
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: const Text('Sync all ready'),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _addRows,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add 5 rows'),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Fill required fields (name, purchase, selling, GST) — auto-saves & syncs to products. '
              'New category/brand names are created automatically. Barcode/SKU matches existing products.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final rows = _sheet?.rows ?? [];
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 24),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                headingRowHeight: 40,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                columnSpacing: 12,
                horizontalMargin: 8,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Name *')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Brand')),
                  DataColumn(label: Text('Unit')),
                  DataColumn(label: Text('Barcode')),
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('Purchase *')),
                  DataColumn(label: Text('Selling *')),
                  DataColumn(label: Text('GST % *')),
                  DataColumn(label: Text('GST type *')),
                  DataColumn(label: Text('Flags')),
                  DataColumn(label: Text('Status')),
                ],
                rows: [
                  for (final row in rows) _buildDataRow(row),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildDataRow(ProductDatasheetRow row) {
    final e = _editors[row.id]!;
    return DataRow(
      color: WidgetStateProperty.all(_rowTint(row.status)),
      cells: [
        DataCell(Text('${row.rowNo}', style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(
          SizedBox(
            width: 180,
            child: TextField(
              controller: e.name,
              decoration: _cellDec('Name'),
              onChanged: (_) => _scheduleSave(row),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Row(
              children: [
                Expanded(
                  child: AppDropdownButtonFormField<int?>(
                    value: _categories.any((c) => c.id == e.categoryId) ? e.categoryId : null,
                    isDense: true,
                    decoration: _cellDec('Category'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('—')),
                      ..._categories.map(
                        (c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (v) => _onCategoryChanged(row, v),
                  ),
                ),
                IconButton(
                  tooltip: 'New category',
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  onPressed: () => _promptCreateCatalog(row: row, type: 'category'),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Row(
              children: [
                Expanded(
                  child: AppDropdownButtonFormField<int?>(
                    value: _brands.any((b) => b.id == e.brandId) ? e.brandId : null,
                    isDense: true,
                    decoration: _cellDec('Brand'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('—')),
                      ..._brands.map(
                        (b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name)),
                      ),
                    ],
                    onChanged: (v) => _onBrandChanged(row, v),
                  ),
                ),
                IconButton(
                  tooltip: 'New brand',
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  onPressed: () => _promptCreateCatalog(row: row, type: 'brand'),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 90,
            child: AppDropdownButtonFormField<int?>(
              value: _units.any((u) => u.id == e.unitId) ? e.unitId : null,
              isDense: true,
              decoration: _cellDec('Unit'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('—')),
                ..._units.map(
                  (u) => DropdownMenuItem<int?>(
                    value: u.id,
                    child: Text(u.abbreviation.isNotEmpty ? u.abbreviation : u.name),
                  ),
                ),
              ],
              onChanged: (v) {
                e.unitId = v;
                final unit = _units.cast<Unit?>().firstWhere(
                      (u) => u?.id == v,
                      orElse: () => null,
                    );
                e.unitName = unit?.abbreviation.isNotEmpty == true
                    ? unit!.abbreviation
                    : unit?.name;
                row.unitId = v;
                row.unitName = e.unitName;
                setState(() {});
                _scheduleSave(row);
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 130,
            child: TextField(
              controller: e.barcode,
              decoration: _cellDec('Barcode'),
              onChanged: (_) => _scheduleSave(row),
              onEditingComplete: () => _saveRow(row, forceMatch: true),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 110,
            child: TextField(
              controller: e.sku,
              decoration: _cellDec('SKU'),
              onChanged: (_) => _scheduleSave(row),
              onEditingComplete: () => _saveRow(row, forceMatch: true),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 90,
            child: TextField(
              controller: e.purchase,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: _cellDec('0.00'),
              onChanged: (_) => _scheduleSave(row),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 90,
            child: TextField(
              controller: e.selling,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: _cellDec('0.00'),
              onChanged: (_) => _scheduleSave(row),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 80,
            child: AppDropdownButtonFormField<double?>(
              value: e.gstRate != null && _gstRates.contains(e.gstRate) ? e.gstRate : null,
              isDense: true,
              decoration: _cellDec('GST'),
              items: [
                const DropdownMenuItem<double?>(value: null, child: Text('—')),
                ..._gstRates.map(
                  (r) => DropdownMenuItem<double?>(
                    value: r,
                    child: Text(r.toStringAsFixed(0)),
                  ),
                ),
              ],
              onChanged: (v) {
                e.gstRate = v;
                row.gstRate = v;
                setState(() {});
                _scheduleSave(row);
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 110,
            child: AppDropdownButtonFormField<String?>(
              value: e.gstType,
              isDense: true,
              decoration: _cellDec('Type'),
              items: const [
                DropdownMenuItem(value: 'exclusive', child: Text('Exclusive')),
                DropdownMenuItem(value: 'inclusive', child: Text('Inclusive')),
              ],
              onChanged: (v) {
                e.gstType = v ?? 'exclusive';
                row.gstType = e.gstType;
                setState(() {});
                _scheduleSave(row);
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Wrap(
              spacing: 4,
              children: [
                _flagChip('Med', e.isMedicine, (v) {
                  e.isMedicine = v;
                  row.isMedicine = v;
                  if (v) {
                    e.isService = false;
                    row.isService = false;
                  }
                  setState(() {});
                  _scheduleSave(row);
                }),
                _flagChip('Svc', e.isService, (v) {
                  e.isService = v;
                  row.isService = v;
                  if (v) {
                    e.isMedicine = false;
                    row.isMedicine = false;
                  }
                  setState(() {});
                  _scheduleSave(row);
                }),
                _flagChip('Batch', e.hasBatch, (v) {
                  e.hasBatch = v;
                  row.hasBatch = v;
                  setState(() {});
                  _scheduleSave(row);
                }),
              ],
            ),
          ),
        ),
        DataCell(
          Tooltip(
            message: (row.validationErrors ?? []).join('\n'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(row.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusLabel(row),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _statusColor(row.status),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _flagChip(String label, bool? value, ValueChanged<bool> onChanged) {
    final on = value == true;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      selected: on,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: onChanged,
    );
  }

  InputDecoration _cellDec(String hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _RowEditors {
  _RowEditors({
    required this.name,
    required this.sku,
    required this.barcode,
    required this.hsn,
    required this.purchase,
    required this.selling,
    required this.mrp,
    this.gstRate,
    this.gstType = 'exclusive',
    this.categoryId,
    this.brandId,
    this.unitId,
    this.categoryName,
    this.brandName,
    this.unitName,
    this.isMedicine = false,
    this.isService = false,
    this.hasBatch = false,
  });

  final TextEditingController name;
  final TextEditingController sku;
  final TextEditingController barcode;
  final TextEditingController hsn;
  final TextEditingController purchase;
  final TextEditingController selling;
  final TextEditingController mrp;
  double? gstRate;
  String? gstType;
  int? categoryId;
  int? brandId;
  int? unitId;
  String? categoryName;
  String? brandName;
  String? unitName;
  bool isMedicine;
  bool isService;
  bool hasBatch;

  factory _RowEditors.fromRow(ProductDatasheetRow row) {
    return _RowEditors(
      name: TextEditingController(text: row.name ?? ''),
      sku: TextEditingController(text: row.sku ?? ''),
      barcode: TextEditingController(text: row.barcode ?? ''),
      hsn: TextEditingController(text: row.hsnCode ?? ''),
      purchase: TextEditingController(
        text: row.purchasePrice != null ? _fmt(row.purchasePrice!) : '',
      ),
      selling: TextEditingController(
        text: row.sellingPrice != null ? _fmt(row.sellingPrice!) : '',
      ),
      mrp: TextEditingController(text: row.mrp != null ? _fmt(row.mrp!) : ''),
      gstRate: row.gstRate,
      gstType: row.gstType ?? 'exclusive',
      categoryId: row.categoryId,
      brandId: row.brandId,
      unitId: row.unitId,
      categoryName: row.categoryName,
      brandName: row.brandName,
      unitName: row.unitName,
      isMedicine: row.isMedicine ?? false,
      isService: row.isService ?? false,
      hasBatch: row.hasBatch ?? false,
    );
  }

  void syncFromRow(ProductDatasheetRow row) {
    _setIfChanged(name, row.name ?? '');
    _setIfChanged(sku, row.sku ?? '');
    _setIfChanged(barcode, row.barcode ?? '');
    _setIfChanged(hsn, row.hsnCode ?? '');
    _setIfChanged(purchase, row.purchasePrice != null ? _fmt(row.purchasePrice!) : '');
    _setIfChanged(selling, row.sellingPrice != null ? _fmt(row.sellingPrice!) : '');
    _setIfChanged(mrp, row.mrp != null ? _fmt(row.mrp!) : '');
    gstRate = row.gstRate;
    gstType = row.gstType ?? 'exclusive';
    categoryId = row.categoryId;
    brandId = row.brandId;
    unitId = row.unitId;
    categoryName = row.categoryName;
    brandName = row.brandName;
    unitName = row.unitName;
    isMedicine = row.isMedicine ?? false;
    isService = row.isService ?? false;
    hasBatch = row.hasBatch ?? false;
  }

  static void _setIfChanged(TextEditingController c, String value) {
    if (c.text != value) {
      c.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  void dispose() {
    name.dispose();
    sku.dispose();
    barcode.dispose();
    hsn.dispose();
    purchase.dispose();
    selling.dispose();
    mrp.dispose();
  }
}
