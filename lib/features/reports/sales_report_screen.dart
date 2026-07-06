import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/dashboard_data.dart';

class SalesReportScreen extends StatelessWidget {
  const SalesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: context.read<AppServices>().reports.dashboard(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        final d = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Sales overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Today total'),
              trailing: Text('₹${d.todaySalesTotal.toStringAsFixed(2)}'),
            ),
            ListTile(
              title: const Text('Today invoices'),
              trailing: Text('${d.todaySalesCount}'),
            ),
            ListTile(
              title: const Text('Monthly total'),
              trailing: Text('₹${d.monthlySalesTotal.toStringAsFixed(2)}'),
            ),
          ],
        );
      },
    );
  }
}
