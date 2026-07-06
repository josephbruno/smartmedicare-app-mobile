import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/purchase.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  late Future<List<Supplier>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().suppliers.list();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Supplier>>(
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
              _future = context.read<AppServices>().suppliers.list();
            });
            await _future;
          },
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (c, i) {
              final s = list[i];
              return ListTile(
                title: Text(s.name),
                subtitle: Text(s.phone),
              );
            },
          ),
        );
      },
    );
  }
}
