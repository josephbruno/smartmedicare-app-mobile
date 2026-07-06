import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/stock_transfer.dart';

class StockTransferListScreen extends StatefulWidget {
  const StockTransferListScreen({super.key});

  @override
  State<StockTransferListScreen> createState() =>
      _StockTransferListScreenState();
}

class _StockTransferListScreenState extends State<StockTransferListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _direction = 'outgoing';
  late Future<List<StockTransfer>> _future;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() {
        _direction = _tabs.index == 0 ? 'outgoing' : 'incoming';
        _reload();
      });
    });
    _future = _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<List<StockTransfer>> _load() {
    return context
        .read<AppServices>()
        .inventory
        .listTransfers(query: {'direction': _direction});
  }

  void _reload() => _future = _load();

  Color _statusColor(String s) {
    switch (s) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/stock-transfers/new');
          if (mounted) setState(_reload);
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '📤 Outgoing'),
            Tab(text: '📥 Incoming'),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<StockTransfer>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('${snap.error}'));
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Center(child: Text('No transfers found'));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_reload);
                  await _future;
                },
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final t = list[i];
                    final other = _direction == 'outgoing'
                        ? (t.toBranchName ?? 'Branch #${t.toBranchId}')
                        : (t.fromBranchName ?? 'Branch #${t.fromBranchId}');
                    final showVerify =
                        _direction == 'incoming' && t.status == 'pending';
                    return ListTile(
                      title: Text(t.transferNumber,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '$other • ${t.items.length} item(s) • ${t.createdAt.length >= 10 ? t.createdAt.substring(0, 10) : t.createdAt}'),
                      trailing: Chip(
                        label: Text(showVerify ? 'verify' : t.status,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white)),
                        backgroundColor: _statusColor(t.status),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      onTap: () async {
                        await context.push('/stock-transfers/${t.id}');
                        if (mounted) setState(_reload);
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
      ),
    );
  }
}
