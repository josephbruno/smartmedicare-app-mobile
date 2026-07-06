import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/purchase.dart';

class PurchaseDetailScreen extends StatefulWidget {
  const PurchaseDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  late Future<Purchase> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().purchases.get(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Purchase>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: Text('Not found'));
        }
        final p = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(p.purchaseNumber, style: Theme.of(context).textTheme.headlineSmall),
            Text('Status: ${p.status}'),
            Text('Date: ${p.purchaseDate}'),
            if (p.supplier != null) Text('Supplier: ${p.supplier!.name}'),
            const Divider(),
            Text('Total: ₹${p.totalAmount.toStringAsFixed(2)}'),
          ],
        );
      },
    );
  }
}
