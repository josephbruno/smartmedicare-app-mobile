import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/responsive/desktop_layout_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/inventory.dart';

/// Low stock + expiry alerts (7 / 15 / 30 days) — desktop & mobile.
class StockAlertsScreen extends StatefulWidget {
  const StockAlertsScreen({super.key});

  @override
  State<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends State<StockAlertsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = false;
  String? _error;
  List<InventoryItem> _lowStock = [];
  List<StockAgeingItem> _expiry = [];
  int _expiryDays = 30;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final inv = context.read<AppServices>().inventory;
      final low = await inv.list(query: {
        'low_stock': 'true',
        'per_page': 100,
      });
      final expiry = await inv.ageing(query: {
        'expiry_within_days': _expiryDays,
        'per_page': 100,
      });
      if (mounted) {
        setState(() {
          _lowStock = low.items;
          _expiry = expiry;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text(_error!))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TabBar(
                    controller: _tabs,
                    tabs: [
                      Tab(text: 'Low Stock (${_lowStock.length})'),
                      Tab(text: 'Expiry (${_expiry.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _lowStockTab(),
                        _expiryTab(compact: compact),
                      ],
                    ),
                  ),
                ],
              );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Alerts'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: padded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: body,
            )
          : body,
    );
  }

  Widget _lowStockTab() {
    if (_lowStock.isEmpty) {
      return const Center(child: Text('No low stock items'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _lowStock.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final item = _lowStock[i];
          final p = item.product;
          final reorder = p?.reorderLevel ?? 0;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.warning.withValues(alpha: 0.15),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.warning),
            ),
            title: Text(p?.name ?? 'Product #${item.productId}'),
            subtitle: Text(
              'Stock ${item.quantity.toStringAsFixed(0)} ≤ reorder $reorder',
            ),
            trailing: Text(
              p?.sku ?? '',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            onTap: () => context.push('/products'),
          );
        },
      ),
    );
  }

  Widget _expiryTab({required bool compact}) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 12, compact ? 12 : 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 15, label: Text('15 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
              ],
              selected: {_expiryDays},
              onSelectionChanged: (s) {
                setState(() => _expiryDays = s.first);
                _load();
              },
            ),
          ),
        ),
        Expanded(
          child: _expiry.isEmpty
              ? const Center(child: Text('No items near expiry'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _expiry.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = _expiry[i];
                      final days = item.daysToExpiry;
                      final color = item.isExpired
                          ? AppTheme.danger
                          : ((days ?? 99) <= 7
                              ? AppTheme.danger
                              : AppTheme.warning);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(Icons.event_busy, color: color),
                        ),
                        title: Text(item.name),
                        subtitle: Text([
                          if (item.batchNumber != null)
                            'Batch ${item.batchNumber}',
                          if (item.expiryDate != null)
                            'Exp ${item.expiryDate}',
                          if (days != null) '$days days left',
                          if (item.isExpired) 'EXPIRED',
                        ].where((e) => e.isNotEmpty).join(' · ')),
                        trailing: Text(
                          'Qty ${item.currentStock.toStringAsFixed(0)}',
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
