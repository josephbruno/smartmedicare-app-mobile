import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/expense.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late Future<List<Expense>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().expenses.list();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Expense>>(
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
              _future = context.read<AppServices>().expenses.list();
            });
            await _future;
          },
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (c, i) {
              final e = list[i];
              return ListTile(
                title: Text(e.expenseNumber),
                subtitle: Text(e.category?.name ?? ''),
                trailing: Text('₹${e.amount.toStringAsFixed(2)}'),
              );
            },
          ),
        );
      },
    );
  }
}
