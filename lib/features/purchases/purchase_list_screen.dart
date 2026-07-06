import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/purchase.dart';

class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  late Future<List<Purchase>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().purchases.list();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/purchases/new'),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Purchase>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          final list = snap.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = context.read<AppServices>().purchases.list();
              });
              await _future;
            },
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (c, i) {
                final p = list[i];
                return ListTile(
                  title: Text(p.purchaseNumber),
                  subtitle: Text(p.supplier?.name ?? ''),
                  trailing: Text('₹${p.totalAmount.toStringAsFixed(2)}'),
                  onTap: () => context.go('/purchases/${p.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
