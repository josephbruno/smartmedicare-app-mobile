import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';

class PurchaseFormScreen extends StatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  final _supplierId = TextEditingController();
  final _branchId = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _supplierId.dispose();
    _branchId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AppServices>().purchases.create({
        'supplier_id': int.tryParse(_supplierId.text) ?? 0,
        'branch_id': int.tryParse(_branchId.text) ?? 0,
        'purchase_date': DateTime.now().toIso8601String().split('T').first,
        'items': <Map<String, dynamic>>[],
      });
      if (mounted && context.canPop()) context.pop();
    } catch (e) {
      if (mounted) {
        AppMessenger.show(context,SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New purchase')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Minimal stub — extend with line items UI as needed.'),
          TextField(
            controller: _supplierId,
            decoration: const InputDecoration(labelText: 'Supplier ID'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _branchId,
            decoration: const InputDecoration(labelText: 'Branch ID'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const CircularProgressIndicator() : const Text('Create draft'),
          ),
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
        ],
      ),
    );
  }
}
