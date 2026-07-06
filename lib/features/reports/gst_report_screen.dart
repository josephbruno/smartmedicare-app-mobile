import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../data/models/invoice.dart';

/// Client-side GST summary (similar to web GST report using invoice list).
class GstReportScreen extends StatefulWidget {
  const GstReportScreen({super.key});

  @override
  State<GstReportScreen> createState() => _GstReportScreenState();
}

class _GstReportScreenState extends State<GstReportScreen> {
  late Future<List<Invoice>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().billing.listSimple();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Invoice>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        final invoices = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('GST report (from invoices)', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text('Invoices: ${invoices.length}'),
            const Text(
              'For full HSN/GST breakdown, extend this screen to aggregate InvoiceItem taxable amounts and tax fields from the API.',
            ),
          ],
        );
      },
    );
  }
}
