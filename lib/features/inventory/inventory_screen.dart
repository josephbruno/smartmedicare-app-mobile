import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/inventory.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late Future<InventoryListResult> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().inventory.list(
          query: {'include_summary': true},
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InventoryListResult>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        final result = snap.data!;
        final list = result.items;
        final summary = result.summary;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _future = context.read<AppServices>().inventory.list(
                    query: {'include_summary': true},
                  );
            });
            await _future;
          },
          child: ListView.builder(
            itemCount: list.length + (summary != null ? 1 : 0),
            itemBuilder: (c, i) {
              if (summary != null && i == 0) {
                return ListTile(
                  title: const Text('Stock summary'),
                  subtitle: Text(
                    '${summary.totalItems} items · ${summary.lowStockCount} low stock · value ₹${summary.totalStockValue.toStringAsFixed(0)}',
                  ),
                );
              }
              final idx = summary != null ? i - 1 : i;
              final it = list[idx];
              return ListTile(
                title: Text(it.product?.name ?? 'Product #${it.productId}'),
                subtitle: Text(
                  'Qty ${it.quantity.toStringAsFixed(0)} · available ${it.availableQuantity.toStringAsFixed(0)}',
                ),
              );
            },
          ),
        );
      },
    );
  }
}
