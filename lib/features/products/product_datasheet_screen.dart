import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../data/models/product_datasheet.dart';

/// Excel-like product bulk entry sheet.
class ProductDatasheetScreen extends StatefulWidget {
  const ProductDatasheetScreen({super.key});

  @override
  State<ProductDatasheetScreen> createState() => _ProductDatasheetScreenState();
}

class _ProductDatasheetScreenState extends State<ProductDatasheetScreen> {
  static const _headerBg = Color(0xFFE7E6E6);
  static const _gridLine = Color(0xFFB4B4B4);
  static const _excelGreen = Color(0xFF217346);
  static const _rowHeight = 32.0;
  static const _headerHeight = 36.0;
  static const _rowNumWidth = 44.0;

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
  final Map<int, Timer?> _nameSearchDebounce = {};
  final Map<int, bool> _saving = {};
  final Map<int, List<Product>> _nameSuggestions = {};
  final Map<int, bool> _nameSearching = {};
  final LayerLink _nameLink = LayerLink();
  OverlayEntry? _nameOverlay;
  int? _overlayRowId;

  int? _activeRowId;
  String? _activeColKey;
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();
  final _headerScroll = ScrollController();
  final _rowNumScroll = ScrollController();

  static const _columns = <_SheetCol>[
    _SheetCol('name', 'A', 'Name *', 220),
    _SheetCol('type', 'B', 'Product type', 120),
    _SheetCol('category', 'C', 'Category', 150),
    _SheetCol('brand', 'D', 'Brand', 140),
    _SheetCol('unit', 'E', 'Unit', 80),
    _SheetCol('barcode', 'F', 'Barcode', 130),
    _SheetCol('mrp', 'G', 'MRP', 100),
    _SheetCol('selling', 'H', 'Selling *', 100),
    _SheetCol('stock', 'I', 'Stock QTY', 90),
    _SheetCol('status', 'J', 'Status', 56),
  ];

  @override
  void initState() {
    super.initState();
    _hScroll.addListener(_syncHeaderScroll);
    _vScroll.addListener(_syncRowNumScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _syncHeaderScroll() {
    if (_headerScroll.hasClients &&
        _headerScroll.offset != _hScroll.offset) {
      _headerScroll.jumpTo(_hScroll.offset);
    }
  }

  void _syncRowNumScroll() {
    if (_rowNumScroll.hasClients &&
        _rowNumScroll.offset != _vScroll.offset) {
      _rowNumScroll.jumpTo(_vScroll.offset);
    }
  }

  @override
  void dispose() {
    _removeNameOverlay();
    _hScroll.removeListener(_syncHeaderScroll);
    _vScroll.removeListener(_syncRowNumScroll);
    _hScroll.dispose();
    _vScroll.dispose();
    _headerScroll.dispose();
    _rowNumScroll.dispose();
    for (final t in _debounce.values) {
      t?.cancel();
    }
    for (final t in _nameSearchDebounce.values) {
      t?.cancel();
    }
    for (final e in _editors.values) {
      e.dispose();
    }
    super.dispose();
  }

  void _removeNameOverlay() {
    _nameOverlay?.remove();
    _nameOverlay = null;
    _overlayRowId = null;
  }

  void _showNameOverlay(ProductDatasheetRow row) {
    final suggestions = _nameSuggestions[row.id] ?? const <Product>[];
    if (suggestions.isEmpty) {
      _removeNameOverlay();
      return;
    }
    _removeNameOverlay();
    _overlayRowId = row.id;
    _nameOverlay = OverlayEntry(
      builder: (ctx) => Positioned.fill(
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeNameOverlay,
              child: const SizedBox.expand(),
            ),
            CompositedTransformFollower(
              link: _nameLink,
              showWhenUnlinked: false,
              offset: const Offset(0, _rowHeight),
              child: Material(
                elevation: 8,
                color: Colors.white,
                borderRadius: BorderRadius.zero,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320, maxHeight: 240),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: suggestions.length,
                    itemBuilder: (_, i) {
                      final p = suggestions[i];
                      return InkWell(
                        onTap: () {
                          _removeNameOverlay();
                          _selectProductMatch(row, p);
                        },
                        child: Container(
                          width: 320,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (p.categoryName != null) p.categoryName!,
                                  if (p.brandName != null) p.brandName!,
                                  if (p.sku != null && p.sku!.isNotEmpty) 'SKU ${p.sku}',
                                  if (p.barcode != null && p.barcode!.isNotEmpty)
                                    p.barcode!,
                                  '₹${p.sellingPrice.toStringAsFixed(0)}',
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_nameOverlay!);
  }

  AppServices get _services => context.read<AppServices>();

  double get _sheetWidth =>
      _columns.fold<double>(0, (s, c) => s + c.width);

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
        _categories =
            (results[1] as List<Category>).where((c) => c.isActive).toList();
        _brands =
            (results[2] as List<Brand>).where((b) => b.isActive).toList();
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
        _nameSearchDebounce.remove(id)?.cancel();
        _saving.remove(id);
        _nameSuggestions.remove(id);
        _nameSearching.remove(id);
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

  void _focusCell(int rowId, String colKey) {
    setState(() {
      _activeRowId = rowId;
      _activeColKey = colKey;
    });
  }

  void _scheduleSave(ProductDatasheetRow row, {bool forceMatch = false}) {
    _debounce[row.id]?.cancel();
    _debounce[row.id] = Timer(const Duration(milliseconds: 650), () {
      _saveRow(row, forceMatch: forceMatch);
    });
  }

  void _scheduleNameSearch(ProductDatasheetRow row, String query) {
    _nameSearchDebounce[row.id]?.cancel();
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _nameSuggestions[row.id] = [];
        _nameSearching[row.id] = false;
      });
      _removeNameOverlay();
      return;
    }
    setState(() => _nameSearching[row.id] = true);
    _nameSearchDebounce[row.id] = Timer(const Duration(milliseconds: 280), () async {
      try {
        final results = await _services.products.search(q);
        if (!mounted) return;
        setState(() {
          _nameSuggestions[row.id] = results.take(12).toList();
          _nameSearching[row.id] = false;
        });
        if (_activeRowId == row.id && _activeColKey == 'name') {
          _showNameOverlay(row);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _nameSuggestions[row.id] = [];
          _nameSearching[row.id] = false;
        });
        _removeNameOverlay();
      }
    });
  }

  void _applyEditorsToRow(ProductDatasheetRow row) {
    final e = _editors[row.id];
    if (e == null) return;
    row.name = e.name.text.trim().isEmpty ? null : e.name.text.trim();
    final barcode = e.barcode.text.trim().isEmpty ? null : e.barcode.text.trim();
    row.barcode = barcode;
    // SKU mirrors barcode (SKU column hidden in sheet).
    row.sku = barcode;
    e.sku.text = barcode ?? '';
    row.hsnCode = e.hsn.text.trim().isEmpty ? null : e.hsn.text.trim();
    row.purchasePrice = double.tryParse(e.purchase.text.trim());
    row.sellingPrice = double.tryParse(e.selling.text.trim());
    row.mrp = double.tryParse(e.mrp.text.trim());
    row.stockQty = double.tryParse(e.stock.text.trim());
    // Purchase column hidden — default from selling (or 0) when empty.
    if (row.purchasePrice == null) {
      row.purchasePrice = row.sellingPrice ?? 0;
      if (row.sellingPrice != null) {
        e.purchase.text = _RowEditors._fmt(row.purchasePrice!);
      }
    }
    row.gstRate = e.gstRate ?? 5;
    row.gstType =
        (e.gstType == null || e.gstType!.isEmpty) ? 'exclusive' : e.gstType;
    row.categoryId = e.categoryId;
    row.brandId = e.brandId;
    row.unitId = e.unitId;
    row.categoryName = e.categoryName;
    row.brandName = e.brandName;
    row.unitName = e.unitName;
    switch (e.productType) {
      case 'service':
        row.isService = true;
        row.isMedicine = false;
        row.trackInventory = false;
        row.hasBatch = false;
        break;
      case 'medicine':
        row.isService = false;
        row.isMedicine = true;
        row.trackInventory = true;
        row.hasBatch = e.hasBatch;
        break;
      case 'product':
        row.isService = false;
        row.isMedicine = false;
        row.trackInventory = true;
        row.hasBatch = e.hasBatch;
        break;
      default:
        // No type selected yet — leave flags unset.
        row.isService = null;
        row.isMedicine = null;
    }
  }

  void _setProductType(ProductDatasheetRow row, String? type) {
    final e = _editors[row.id];
    if (e == null) return;
    e.productType = type;
    e.isService = type == 'service';
    e.isMedicine = type == 'medicine';
    if (type == 'service') e.hasBatch = false;
    if (type == null) {
      e.isService = false;
      e.isMedicine = false;
    }
    setState(() {});
    _scheduleSave(row);
  }

  Future<void> _selectProductMatch(ProductDatasheetRow row, Product product) async {
    final sheet = _sheet;
    if (sheet == null) return;
    setState(() {
      _nameSuggestions[row.id] = [];
      _saving[row.id] = true;
    });
    try {
      final matched = await _services.productDatasheets.applyMatch(
        datasheetId: sheet.id,
        rowId: row.id,
        productId: product.id,
      );
      if (!mounted) return;
      row.applyFrom(matched);
      _editors[row.id]?.syncFromRow(matched);
      // Immediately sync so product stays linked; later edits update product.
      final synced = await _services.productDatasheets.updateRow(
        sheet.id,
        row.id,
        row.toPayload(autoSync: true),
      );
      if (!mounted) return;
      row.applyFrom(synced);
      _editors[row.id]?.syncFromRow(synced);
      await _refreshCatalogIfNeeded(synced);
      setState(() {
        _saving[row.id] = false;
        _lastSavedAt = TimeOfDay.now().format(context);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded "${product.name}" — edits will update this product.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving[row.id] = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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
        } catch (_) {}
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

  Future<void> _addRows() async {
    final sheet = _sheet;
    if (sheet == null) return;
    try {
      final updated =
          await _services.productDatasheets.addRows(sheet.id, count: 10);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Synced ${result.result['synced'] ?? 0} row(s), ${result.result['failed'] ?? 0} failed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _newSheet() async {
    try {
      final sheet = await _services.productDatasheets.create(emptyRows: 20);
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
    } else {
      final cat = _categories.cast<Category?>().firstWhere(
            (c) => c?.id == id,
            orElse: () => null,
          );
      e.categoryId = id;
      e.categoryName = cat?.name;
      row.categoryId = id;
      row.categoryName = cat?.name;
    }
    setState(() {});
    _scheduleSave(row);
  }

  Future<void> _onBrandChanged(ProductDatasheetRow row, int? id) async {
    final e = _editors[row.id];
    if (e == null) return;
    if (id == null) {
      e.brandId = null;
      e.brandName = null;
      row.brandId = null;
      row.brandName = null;
    } else {
      final brand = _brands.cast<Brand?>().firstWhere(
            (b) => b?.id == id,
            orElse: () => null,
          );
      e.brandId = id;
      e.brandName = brand?.name;
      row.brandId = id;
      row.brandName = brand?.name;
    }
    setState(() {});
    _scheduleSave(row);
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
    if (name == null || name.isEmpty || _sheet == null) return;
    try {
      final updated = await _services.productDatasheets.resolveCatalog(
        datasheetId: _sheet!.id,
        rowId: row.id,
        type: type,
        name: name,
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

  Map<String, int> get _localCounts {
    final rows = _sheet?.rows ?? [];
    final map = <String, int>{
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

  String get _formulaBarText {
    final rows = _sheet?.rows;
    if (rows == null || _activeRowId == null || _activeColKey == null) {
      return '';
    }
    final row = rows.cast<ProductDatasheetRow?>().firstWhere(
          (r) => r?.id == _activeRowId,
          orElse: () => null,
        );
    if (row == null) return '';
    final e = _editors[row.id];
    if (e == null) return '';
    final col = _columns.cast<_SheetCol?>().firstWhere(
          (c) => c?.key == _activeColKey,
          orElse: () => null,
        );
    final ref = '${col?.letter ?? '?'}${row.rowNo}';
    switch (_activeColKey) {
      case 'name':
        return '$ref  ${e.name.text}';
      case 'type':
        return '$ref  ${e.productType ?? ''}';
      case 'category':
        return '$ref  ${e.categoryName ?? ''}';
      case 'brand':
        return '$ref  ${e.brandName ?? ''}';
      case 'unit':
        return '$ref  ${e.unitName ?? ''}';
      case 'barcode':
        return '$ref  ${e.barcode.text}';
      case 'mrp':
        return '$ref  ${e.mrp.text}';
      case 'selling':
        return '$ref  ${e.selling.text}';
      case 'stock':
        return '$ref  ${e.stock.text}';
      case 'status':
        return '$ref  ${row.status}';
      default:
        return ref;
    }
  }

  Color _rowTint(String status) {
    switch (status) {
      case 'synced':
        return const Color(0xFFE8F5E9);
      case 'matched':
        return const Color(0xFFE3F2FD);
      case 'ready':
        return const Color(0xFFF1F8E9);
      case 'incomplete':
        return const Color(0xFFFFF8E1);
      case 'error':
        return const Color(0xFFFFEBEE);
      default:
        return Colors.white;
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
        return row.action == 'update' ? 'Updated' : 'Created';
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

  IconData _statusIcon(ProductDatasheetRow row) {
    if (_saving[row.id] == true) return Icons.sync;
    switch (row.status) {
      case 'synced':
        return Icons.check_circle;
      case 'matched':
        return Icons.link;
      case 'ready':
        return Icons.play_circle_outline;
      case 'incomplete':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
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
                    _buildRibbon(),
                    _buildFormulaBar(),
                    Expanded(child: _buildExcelGrid()),
                    _buildFooter(),
                  ],
                ),
    );
  }

  Widget _buildRibbon() {
    final c = _localCounts;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to products',
            onPressed: () => context.go('/products'),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sheet?.title ?? 'Product datasheet',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _countPill('Synced', c['synced']!, const Color(0xFF217346)),
                    _countPill('Matched', c['matched']!, AppTheme.primary),
                    _countPill('Ready', c['ready']!, AppTheme.primary),
                    _countPill('Incomplete', c['incomplete']!, AppTheme.warning),
                    _countPill('Error', c['error']!, AppTheme.danger),
                    if (_lastSavedAt != null)
                      Text(
                        'Autosaved $_lastSavedAt',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _loading ? null : _newSheet,
            icon: const Icon(Icons.note_add_outlined, size: 18),
            label: const Text('New sheet'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _addRows,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Insert rows'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _excelGreen),
            onPressed: _syncingAll ? null : _syncAll,
            icon: _syncingAll
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: const Text('Sync all'),
          ),
        ],
      ),
    );
  }

  Widget _countPill(String label, int n, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label $n',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildFormulaBar() {
    return Container(
      height: 34,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _gridLine),
          bottom: BorderSide(color: _gridLine),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _headerBg,
              border: Border.all(color: _gridLine),
            ),
            child: Text(
              _activeRowId == null
                  ? ''
                  : '${_columns.cast<_SheetCol?>().firstWhere((c) => c?.key == _activeColKey, orElse: () => null)?.letter ?? ''}${_sheet?.rows.cast<ProductDatasheetRow?>().firstWhere((r) => r?.id == _activeRowId, orElse: () => null)?.rowNo ?? ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.functions, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _formulaBarText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const Text(
            'Type name to search products · select to load · edits update product',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _gridLine)),
      ),
      child: const Text(
        'Excel-style sheet: click a cell to edit. Name search matches products — select one to fill the row. '
        'Stock QTY sets branch inventory on sync. Status icons show row state (hover for details).',
        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildExcelGrid() {
    final rows = _sheet?.rows ?? [];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _gridLine),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: const InputDecorationTheme(
              filled: false,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
          ),
          child: Column(
          children: [
            // Header row
            SizedBox(
              height: _headerHeight,
              child: Row(
                children: [
                  _cornerCell(),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _headerScroll,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: _sheetWidth,
                        child: Row(
                          children: [
                            for (final col in _columns) _headerCell(col),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Frozen row numbers
                  SizedBox(
                    width: _rowNumWidth,
                    child: ListView.builder(
                      controller: _rowNumScroll,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rows.length,
                      itemExtent: _rowHeight,
                      itemBuilder: (_, i) => _rowNumberCell(rows[i]),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _hScroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: _sheetWidth,
                        child: ListView.builder(
                          controller: _vScroll,
                          itemCount: rows.length,
                          itemExtent: _rowHeight,
                          itemBuilder: (_, i) => _buildSheetRow(rows[i]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _cornerCell() {
    return Container(
      width: _rowNumWidth,
      height: _headerHeight,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(
          right: BorderSide(color: _gridLine),
          bottom: BorderSide(color: _gridLine),
        ),
      ),
      child: const Icon(Icons.select_all, size: 14, color: AppTheme.textSecondary),
    );
  }

  Widget _headerCell(_SheetCol col) {
    return Container(
      width: col.width,
      height: _headerHeight,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(
          right: BorderSide(color: _gridLine),
          bottom: BorderSide(color: _gridLine),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              col.letter,
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, height: 1),
            ),
            Text(
              col.title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowNumberCell(ProductDatasheetRow row) {
    final active = _activeRowId == row.id;
    return Container(
      width: _rowNumWidth,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFDDE8F7) : _headerBg,
        border: const Border(
          right: BorderSide(color: _gridLine),
          bottom: BorderSide(color: _gridLine),
        ),
      ),
      child: Text(
        '${row.rowNo}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSheetRow(ProductDatasheetRow row) {
    final e = _editors[row.id];
    if (e == null) return const SizedBox(height: _rowHeight);
    final tint = _rowTint(row.status);
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          _nameCell(row, e, tint),
          _typeCell(row, e, tint),
          _dropdownCell(
            row: row,
            colKey: 'category',
            tint: tint,
            width: 150,
            value: _categories.any((c) => c.id == e.categoryId) ? e.categoryId : null,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('')),
              ..._categories.map(
                (c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
              ),
            ],
            onChanged: (v) => _onCategoryChanged(row, v),
            onAdd: () => _promptCreateCatalog(row: row, type: 'category'),
          ),
          _dropdownCell(
            row: row,
            colKey: 'brand',
            tint: tint,
            width: 140,
            value: _brands.any((b) => b.id == e.brandId) ? e.brandId : null,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('')),
              ..._brands.map(
                (b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis)),
              ),
            ],
            onChanged: (v) => _onBrandChanged(row, v),
            onAdd: () => _promptCreateCatalog(row: row, type: 'brand'),
          ),
          _dropdownCell(
            row: row,
            colKey: 'unit',
            tint: tint,
            width: 80,
            value: _units.any((u) => u.id == e.unitId) ? e.unitId : null,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('')),
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
          _textCell(
            row: row,
            colKey: 'barcode',
            controller: e.barcode,
            tint: tint,
            width: 130,
            onEditingComplete: () => _saveRow(row, forceMatch: true),
          ),
          _textCell(
            row: row,
            colKey: 'mrp',
            controller: e.mrp,
            tint: tint,
            width: 100,
            numeric: true,
          ),
          _textCell(
            row: row,
            colKey: 'selling',
            controller: e.selling,
            tint: tint,
            width: 100,
            numeric: true,
          ),
          _textCell(
            row: row,
            colKey: 'stock',
            controller: e.stock,
            tint: tint,
            width: 90,
            numeric: true,
          ),
          _statusCell(row, tint),
        ],
      ),
    );
  }

  BoxDecoration _cellBox({
    required Color tint,
    required bool active,
  }) {
    return BoxDecoration(
      color: tint,
      border: Border(
        right: const BorderSide(color: _gridLine),
        bottom: const BorderSide(color: _gridLine),
        top: active
            ? const BorderSide(color: Color(0xFF217346), width: 2)
            : BorderSide.none,
        left: active
            ? const BorderSide(color: Color(0xFF217346), width: 2)
            : BorderSide.none,
      ),
    );
  }

  Widget _nameCell(ProductDatasheetRow row, _RowEditors e, Color tint) {
    final active = _activeRowId == row.id && _activeColKey == 'name';
    final searching = _nameSearching[row.id] == true;
    final linked = row.matchedProductId != null || row.productId != null;

    Widget field = Container(
      decoration: _cellBox(tint: tint, active: active),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: e.name,
        style: const TextStyle(fontSize: 12, height: 1.1),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          hintText: 'Type to search…',
          hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          suffixIcon: searching
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : linked
                  ? const Icon(Icons.link, size: 14, color: Color(0xFF217346))
                  : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        ),
        onTap: () {
          _focusCell(row.id, 'name');
          if ((_nameSuggestions[row.id] ?? []).isNotEmpty) {
            _showNameOverlay(row);
          }
        },
        onChanged: (v) {
          _focusCell(row.id, 'name');
          _scheduleNameSearch(row, v);
          _scheduleSave(row);
        },
      ),
    );

    if (active) {
      field = CompositedTransformTarget(link: _nameLink, child: field);
    }

    return SizedBox(
      width: 220,
      height: _rowHeight,
      child: field,
    );
  }

  Widget _typeCell(ProductDatasheetRow row, _RowEditors e, Color tint) {
    final active = _activeRowId == row.id && _activeColKey == 'type';
    return Container(
      width: 120,
      height: _rowHeight,
      decoration: _cellBox(tint: tint, active: active),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: e.productType,
          isExpanded: true,
          isDense: true,
          hint: const Text('', style: TextStyle(fontSize: 12)),
          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          items: const [
            DropdownMenuItem<String?>(value: null, child: Text('')),
            DropdownMenuItem<String?>(value: 'product', child: Text('Product')),
            DropdownMenuItem<String?>(value: 'medicine', child: Text('Medicine')),
            DropdownMenuItem<String?>(value: 'service', child: Text('Service')),
          ],
          onTap: () => _focusCell(row.id, 'type'),
          onChanged: (v) {
            _focusCell(row.id, 'type');
            _setProductType(row, v);
          },
        ),
      ),
    );
  }

  Widget _dropdownCell({
    required ProductDatasheetRow row,
    required String colKey,
    required Color tint,
    required double width,
    required int? value,
    required List<DropdownMenuItem<int?>> items,
    required ValueChanged<int?> onChanged,
    VoidCallback? onAdd,
  }) {
    final active = _activeRowId == row.id && _activeColKey == colKey;
    return Container(
      width: width,
      height: _rowHeight,
      decoration: _cellBox(tint: tint, active: active),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: value,
                isExpanded: true,
                isDense: true,
                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                items: items,
                onTap: () => _focusCell(row.id, colKey),
                onChanged: (v) {
                  _focusCell(row.id, colKey);
                  onChanged(v);
                },
              ),
            ),
          ),
          if (onAdd != null)
            InkWell(
              onTap: onAdd,
              child: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.add, size: 14, color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _textCell({
    required ProductDatasheetRow row,
    required String colKey,
    required TextEditingController controller,
    required Color tint,
    required double width,
    bool numeric = false,
    VoidCallback? onEditingComplete,
  }) {
    final active = _activeRowId == row.id && _activeColKey == colKey;
    return Container(
      width: width,
      height: _rowHeight,
      decoration: _cellBox(tint: tint, active: active),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 12, height: 1.1),
        textAlign: numeric ? TextAlign.right : TextAlign.left,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: numeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        ),
        onTap: () => _focusCell(row.id, colKey),
        onChanged: (_) {
          _focusCell(row.id, colKey);
          _scheduleSave(row);
        },
        onEditingComplete: onEditingComplete,
      ),
    );
  }

  Widget _statusCell(ProductDatasheetRow row, Color tint) {
    final active = _activeRowId == row.id && _activeColKey == 'status';
    final label = _statusLabel(row);
    final saving = _saving[row.id] == true;
    return Container(
      width: 56,
      height: _rowHeight,
      decoration: _cellBox(tint: tint, active: active),
      alignment: Alignment.center,
      child: Tooltip(
        message: [
          label,
          if ((row.validationErrors ?? []).isNotEmpty)
            ...(row.validationErrors ?? []),
        ].join('\n'),
        child: saving
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _statusColor(row.status),
                ),
              )
            : Icon(
                _statusIcon(row),
                size: 18,
                color: _statusColor(row.status),
              ),
      ),
    );
  }
}

class _SheetCol {
  const _SheetCol(this.key, this.letter, this.title, this.width);
  final String key;
  final String letter;
  final String title;
  final double width;
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
    required this.stock,
    this.gstRate = 5,
    this.gstType = 'exclusive',
    this.productType,
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
  final TextEditingController stock;
  double? gstRate;
  String? gstType;
  String? productType;
  int? categoryId;
  int? brandId;
  int? unitId;
  String? categoryName;
  String? brandName;
  String? unitName;
  bool isMedicine;
  bool isService;
  bool hasBatch;

  static String? _typeFromFlags({
    bool? isService,
    bool? isMedicine,
    bool linked = false,
  }) {
    if (isService == true) return 'service';
    if (isMedicine == true) return 'medicine';
    // Explicit product flags or an existing linked product → Product.
    if (linked || isService == false || isMedicine == false) return 'product';
    // New/empty row — leave unselected.
    return null;
  }

  factory _RowEditors.fromRow(ProductDatasheetRow row) {
    final linked = row.productId != null || row.matchedProductId != null;
    return _RowEditors(
      name: TextEditingController(text: row.name ?? ''),
      sku: TextEditingController(text: row.barcode ?? row.sku ?? ''),
      barcode: TextEditingController(text: row.barcode ?? ''),
      hsn: TextEditingController(text: row.hsnCode ?? ''),
      purchase: TextEditingController(
        text: row.purchasePrice != null ? _fmt(row.purchasePrice!) : '',
      ),
      selling: TextEditingController(
        text: row.sellingPrice != null ? _fmt(row.sellingPrice!) : '',
      ),
      mrp: TextEditingController(text: row.mrp != null ? _fmt(row.mrp!) : ''),
      stock: TextEditingController(text: row.stockQty != null ? _fmt(row.stockQty!) : ''),
      gstRate: row.gstRate ?? 5,
      gstType: row.gstType ?? 'exclusive',
      productType: _typeFromFlags(
        isService: row.isService,
        isMedicine: row.isMedicine,
        linked: linked,
      ),
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
    final linked = row.productId != null || row.matchedProductId != null;
    _setIfChanged(name, row.name ?? '');
    _setIfChanged(sku, row.barcode ?? row.sku ?? '');
    _setIfChanged(barcode, row.barcode ?? '');
    _setIfChanged(hsn, row.hsnCode ?? '');
    _setIfChanged(purchase, row.purchasePrice != null ? _fmt(row.purchasePrice!) : '');
    _setIfChanged(selling, row.sellingPrice != null ? _fmt(row.sellingPrice!) : '');
    _setIfChanged(mrp, row.mrp != null ? _fmt(row.mrp!) : '');
    _setIfChanged(stock, row.stockQty != null ? _fmt(row.stockQty!) : '');
    gstRate = row.gstRate ?? 5;
    gstType = row.gstType ?? 'exclusive';
    productType = _typeFromFlags(
      isService: row.isService,
      isMedicine: row.isMedicine,
      linked: linked,
    );
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
    stock.dispose();
  }
}
