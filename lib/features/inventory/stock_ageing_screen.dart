import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/widgets/paginated_data_table.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/inventory.dart';

class StockAgeingScreen extends StatefulWidget {
  const StockAgeingScreen({super.key});

  @override
  State<StockAgeingScreen> createState() => _StockAgeingScreenState();
}

class _StockAgeingScreenState extends State<StockAgeingScreen> {
  List<StockAgeingItem> _items = [];
  bool _loading = false;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<AppServices>().inventory.ageing();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<StockAgeingItem> get _filtered {
    if (_filter == 'all') return _items;
    return _items.where((item) {
      final days = item.daysSinceLastSale ?? 0;
      if (_filter == 'critical') return days > 60;
      if (_filter == 'warning') return days > 30 && days <= 60;
      if (_filter == 'normal') return days <= 30;
      return true;
    }).toList();
  }

  Color _urgencyColor(StockAgeingItem item) {
    final days = item.daysSinceLastSale ?? 0;
    if (days > 60) return AppTheme.danger;
    if (days > 30) return AppTheme.warning;
    return AppTheme.accent;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobileBuilder: (_) => _buildScaffold(compact: true),
      tabletBuilder: (_) => _buildScaffold(compact: false),
      desktopBuilder: (_) => _buildScaffold(compact: false, padded: true),
    );
  }

  Widget _buildScaffold({required bool compact, bool padded = false}) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilters(),
        Expanded(child: _buildBody(compact: compact)),
      ],
    );

    if (padded) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: body,
        ),
      );
    }
    return body;
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _filterChip('All', 'all'),
          const SizedBox(width: 8),
          _filterChip('Critical (>60d)', 'critical'),
          const SizedBox(width: 8),
          _filterChip('Warning (>30d)', 'warning'),
          const SizedBox(width: 8),
          _filterChip('Normal', 'normal'),
          const SizedBox(width: 16),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _buildBody({required bool compact}) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final items = _filtered;
    if (items.isEmpty) {
      return const Center(child: Text('No stock ageing data'));
    }

    if (compact) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (_, i) => _mobileTile(items[i]),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = ResponsiveTableMetrics.fromFlexWidths(
          context,
          flexes: const [3, 1, 1, 1],
          maxWidth: constraints.maxWidth,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.horizontalPadding,
            vertical: 16,
          ),
          child: ResponsiveTableContainer(
            metrics: metrics,
            child: _dataTable(items, metrics.tableWidth),
          ),
        );
      },
    );
  }

  Widget _mobileTile(StockAgeingItem item) {
    final color = _urgencyColor(item);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Stock ${item.currentStock.toStringAsFixed(0)} · ${item.daysSinceLastSale ?? 0} days',
          style: TextStyle(color: color),
        ),
        trailing: Text(
          '₹${item.stockValue.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _dataTable(List<StockAgeingItem> items, double tableWidth) {
    return SizedBox(
      width: tableWidth,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
        },
        border: TableBorder.all(color: const Color(0xFFE2E8F0)),
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade100),
            children: [
              _headerCell('Product'),
              _headerCell('Stock', align: TextAlign.center),
              _headerCell('Days idle', align: TextAlign.center),
              _headerCell('Value', align: TextAlign.right),
            ],
          ),
          ...items.map((item) {
            final color = _urgencyColor(item);
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (item.sku != null)
                        Text(item.sku!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(child: Text(item.currentStock.toStringAsFixed(0))),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: Text(
                      '${item.daysSinceLastSale ?? 0}',
                      style: TextStyle(color: color, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '₹${item.stockValue.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text, textAlign: align, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
