import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/shop.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  late Future<List<Branch>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().branches.list();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Branch>>(
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
              _future = context.read<AppServices>().branches.list();
            });
            await _future;
          },
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (c, i) {
              final b = list[i];
              return ListTile(
                title: Text(b.name),
                subtitle: Text(b.code ?? ''),
                trailing: b.isMain ? const Chip(label: Text('Main')) : null,
              );
            },
          ),
        );
      },
    );
  }
}
