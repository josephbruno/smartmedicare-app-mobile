import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/widgets/table_column_def.dart';
import '../../data/models/inventory.dart';
import '../../data/models/product.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  final _logSearch = TextEditingController();
  final _stockTableKey = GlobalKey<AppPaginatedTableState<InventoryItem>>();
  final _logTableKey = GlobalKey<AppPaginatedTableState<StockMovement>>();
  Timer? _searchDebounce;
  Timer? _logSearchDebounce;

  int? _categoryId;
  String _stockFilter = 'all'; // all | low
  String _logTypeFilter = 'all'; // all | adjustment | damage | expiry
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _logSearchDebounce?.cancel();
    _tabs.dispose();
    _search.dispose();
    _logSearch.dispose();
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

  /// Rebuilds so [loadPage] closes over latest filters, then refetches.
  void _reloadStock() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_stockTableKey.currentState?.refresh() ?? Future<void>.value());
    });
  }

  void _reloadLog() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_logTableKey.currentState?.refresh() ?? Future<void>.value());
    });
  }

  Future<void> _refreshAfterAdjust() async {
    // Yield so the adjust dialog is fully dismissed, then refetch both tabs.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await Future.wait([
      _stockTableKey.currentState?.refresh() ?? Future<void>.value(),
      _logTableKey.currentState?.refresh() ?? Future<void>.value(),
    ]);
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _reloadStock();
    });
  }

  void _onLogSearchChanged(String _) {
    _logSearchDebounce?.cancel();
    _logSearchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _reloadLog();
    });
  }

  InputDecoration get _filterDec => const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  Future<void> _openAdjust(InventoryItem item) async {
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission(AppPermissions.inventoryAdjust)) return;

    final zeroStock = item.quantity <= 0;
    final qtyCtrl = TextEditingController(text: zeroStock ? '' : '1');
    // New / zero-stock products default to Set (opening stock).
    var type = zeroStock ? 'set' : 'add';
    final reasonCtrl = TextEditingController(
      text: zeroStock ? 'Opening stock' : 'Physical stock count',
    );
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
              title: Text(
                item.quantity <= 0
                    ? 'Set opening stock — ${item.product?.name ?? 'Product #${item.productId}'}'
                    : 'Adjust stock — ${item.product?.name ?? 'Product #${item.productId}'}',
              ),
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
                      decoration: InputDecoration(
                        labelText: type == 'set' ? 'Opening / stock quantity' : 'Quantity',
                      ),
                      autofocus: item.quantity <= 0,
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

    final qtyText = qtyCtrl.text.trim();
    final reasonText = reasonCtrl.text.trim();
    qtyCtrl.dispose();
    reasonCtrl.dispose();

    if (confirmed != true || !mounted) return;

    final qty = double.tryParse(qtyText) ?? 0;
    if (qty < 0 || (type != 'set' && qty <= 0)) {
      AppMessenger.show(context, const SnackBar(content: Text('Enter a valid quantity')));
      return;
    }

    try {
      await context.read<AppServices>().inventory.adjust({
        if (item.id > 0) 'inventory_id': item.id,
        'product_id': item.productId,
        'branch_id': branchId,
        'quantity': qty,
        'type': type,
        'reason': reasonText.isEmpty
            ? (item.quantity <= 0 ? 'Opening stock' : 'Stock adjustment')
            : reasonText,
      });
      if (!mounted) return;
      AppMessenger.show(context, const SnackBar(content: Text('Stock updated & logged')));
      await _refreshAfterAdjust();
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show(context, SnackBar(content: Text('$e')));
    }
  }

  Widget _buildStockFilters() {
    final search = _search.text.trim();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search by name, SKU, or barcode…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reloadStock(),
              onChanged: _onSearchChanged,
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
              onChanged: (v) {
                _categoryId = v;
                _reloadStock();
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: AppDropdownButtonFormField<String>(
              value: _stockFilter,
              isDense: true,
              decoration: _filterDec.copyWith(labelText: 'Stock'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All stock')),
                DropdownMenuItem(value: 'low', child: Text('Low stock')),
              ],
              onChanged: (v) {
                if (v == null) return;
                _stockFilter = v;
                _reloadStock();
              },
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _reloadStock,
            child: const Text('Search'),
          ),
          if (search.isNotEmpty || _categoryId != null || _stockFilter != 'all') ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _search.clear();
                _categoryId = null;
                _stockFilter = 'all';
                _reloadStock();
              },
              child: const Text('Clear'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogFilters() {
    final search = _logSearch.text.trim();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _logSearch,
              decoration: const InputDecoration(
                hintText: 'Search product in log…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reloadLog(),
              onChanged: _onLogSearchChanged,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 160,
            child: AppDropdownButtonFormField<String>(
              value: _logTypeFilter,
              isDense: true,
              decoration: _filterDec.copyWith(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All types')),
                DropdownMenuItem(value: 'adjustment', child: Text('Adjustment')),
                DropdownMenuItem(value: 'damage', child: Text('Damage')),
                DropdownMenuItem(value: 'expiry', child: Text('Expiry')),
              ],
              onChanged: (v) {
                if (v == null) return;
                _logTypeFilter = v;
                _reloadLog();
              },
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _reloadLog,
            child: const Text('Search'),
          ),
          if (search.isNotEmpty || _logTypeFilter != 'all') ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _logSearch.clear();
                _logTypeFilter = 'all';
                _reloadLog();
              },
              child: const Text('Clear'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = context.watch<AuthSession>();
    final canAdjust = auth.hasPermission(AppPermissions.inventoryAdjust);
    final search = _search.text.trim();
    final logSearch = _logSearch.text.trim();
    final hasStockFilters =
        search.length >= 2 || _categoryId != null || _stockFilter != 'all';
    final hasLogFilters = logSearch.length >= 2 || _logTypeFilter != 'all';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(text: 'Stock'),
                Tab(text: 'Adjustment log'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                Column(
                  children: [
                    _buildStockFilters(),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Expanded(
                      child: AppPaginatedTable<InventoryItem>(
                        key: _stockTableKey,
                        emptyMessage: hasStockFilters
                            ? 'No products match your filters.'
                            : 'No stockable products for this branch.',
                        headerFontSize: 9,
                        cellFontSize: 12,
                        loadPage: ({required page, required perPage}) =>
                            services.inventory.listPaginated(
                              page: page,
                              perPage: perPage,
                              search: search.length >= 2 ? search : null,
                              categoryId: _categoryId,
                              lowStock: _stockFilter == 'low' ? true : null,
                            ),
                        onRowTap: canAdjust ? _openAdjust : null,
                        columns: [
                          const TableColumnDef(label: 'Product', flex: 2, cellBuilder: _productCell),
                          const TableColumnDef(label: 'SKU', flex: 1, cellBuilder: _skuCell),
                          const TableColumnDef(
                            label: 'MRP',
                            flex: 0.9,
                            align: TextAlign.right,
                            cellBuilder: _mrpCell,
                          ),
                          const TableColumnDef(
                            label: 'Selling Price',
                            flex: 1.1,
                            align: TextAlign.right,
                            cellBuilder: _sellingPriceCell,
                          ),
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
                    ),
                  ],
                ),
                Column(
                  children: [
                    _buildLogFilters(),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Expanded(
                      child: AppPaginatedTable<StockMovement>(
                        key: _logTableKey,
                        emptyMessage: hasLogFilters
                            ? 'No adjustment logs match your filters.'
                            : 'No stock adjustments logged yet.',
                        headerFontSize: 9,
                        cellFontSize: 12,
                        loadPage: ({required page, required perPage}) =>
                            services.inventory.movementsPaginated(
                              page: page,
                              perPage: perPage,
                              manualOnly: true,
                              search: logSearch.length >= 2 ? logSearch : null,
                              type: _logTypeFilter == 'all' ? null : _logTypeFilter,
                            ),
                        columns: const [
                          TableColumnDef(label: 'When', flex: 1.2, cellBuilder: _logWhenCell),
                          TableColumnDef(label: 'Product', flex: 1.6, cellBuilder: _logProductCell),
                          TableColumnDef(
                            label: 'Change',
                            flex: 0.8,
                            align: TextAlign.center,
                            cellBuilder: _logQtyCell,
                          ),
                          TableColumnDef(label: 'Type', flex: 0.9, cellBuilder: _logTypeCell),
                          TableColumnDef(label: 'User', flex: 1.1, cellBuilder: _logUserCell),
                          TableColumnDef(label: 'Notes', flex: 2.2, cellBuilder: _logNotesCell),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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

  static String _money(double? value) {
    if (value == null) return '—';
    return '₹${value.toStringAsFixed(2)}';
  }

  static Widget _mrpCell(BuildContext context, InventoryItem it) => Text(
        _money(it.product?.mrp),
        style: const TextStyle(color: AppTheme.textSecondary),
      );

  static Widget _sellingPriceCell(BuildContext context, InventoryItem it) => Text(
        _money(it.product?.sellingPrice),
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary),
      );

  static Widget _qtyCell(BuildContext context, InventoryItem it) =>
      Text(it.quantity.toStringAsFixed(0));

  static Widget _reservedCell(BuildContext context, InventoryItem it) =>
      Text(it.reservedQuantity.toStringAsFixed(0));

  static Widget _availableCell(BuildContext context, InventoryItem it) => Text(
        it.availableQuantity.toStringAsFixed(0),
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary),
      );

  static Widget _logWhenCell(BuildContext context, StockMovement m) {
    final raw = m.createdAt;
    DateTime? dt;
    try {
      dt = DateTime.tryParse(raw);
    } catch (_) {}
    final text = dt != null ? DateFormat('dd MMM yyyy HH:mm').format(dt.toLocal()) : raw;
    return Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary));
  }

  static Widget _logProductCell(BuildContext context, StockMovement m) => Text(
        m.product?.name ?? 'Product #${m.productId}',
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );

  static Widget _logQtyCell(BuildContext context, StockMovement m) {
    final q = m.quantity;
    final sign = q > 0 ? '+' : '';
    final color = q > 0 ? AppTheme.accent : (q < 0 ? AppTheme.danger : AppTheme.textSecondary);
    return Text(
      '$sign${q.toStringAsFixed(q.abs() % 1 == 0 ? 0 : 2)}',
      style: TextStyle(fontWeight: FontWeight.w700, color: color),
    );
  }

  static Widget _logTypeCell(BuildContext context, StockMovement m) => Text(
        m.type,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      );

  static Widget _logUserCell(BuildContext context, StockMovement m) => Text(
        m.createdByName ?? (m.createdById != null ? 'User #${m.createdById}' : '—'),
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );

  static Widget _logNotesCell(BuildContext context, StockMovement m) => Text(
        m.notes?.isNotEmpty == true ? m.notes! : '—',
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
}
