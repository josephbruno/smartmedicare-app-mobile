import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';

/// Minimal product form (JSON API). Image upload can be added later.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final int? productId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _purchase = TextEditingController(text: '0');
  final _selling = TextEditingController(text: '0');
  final _mrp = TextEditingController(text: '0');
  final _gst = TextEditingController(text: '18');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final id = widget.productId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final p = await context.read<AppServices>().products.get(id);
          if (!mounted) return;
          setState(() {
            _name.text = p.name;
            _sku.text = p.sku ?? '';
            _barcode.text = p.barcode ?? '';
            _purchase.text = p.purchasePrice.toString();
            _selling.text = p.sellingPrice.toString();
            _mrp.text = p.mrp.toString();
            _gst.text = p.gstRate.toString();
          });
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _purchase.dispose();
    _selling.dispose();
    _mrp.dispose();
    _gst.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final svc = context.read<AppServices>().products;
      final body = {
        'name': _name.text.trim(),
        'sku': _sku.text.trim().isEmpty ? null : _sku.text.trim(),
        'barcode': _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        'purchase_price': double.tryParse(_purchase.text) ?? 0,
        'selling_price': double.tryParse(_selling.text) ?? 0,
        'mrp': double.tryParse(_mrp.text) ?? 0,
        'gst_rate': double.tryParse(_gst.text) ?? 0,
        'gst_type': 'exclusive',
        'reorder_level': 0,
        'track_inventory': true,
        'has_batch': false,
        'has_expiry': false,
        'is_pet_food': false,
        'is_service': false,
        'is_active': true,
      };
      if (widget.productId == null) {
        await svc.create(Map<String, dynamic>.from(body));
      } else {
        await svc.update(widget.productId!, Map<String, dynamic>.from(body));
      }
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
      appBar: AppBar(title: Text(widget.productId == null ? 'New product' : 'Edit product')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU')),
          TextField(controller: _barcode, decoration: const InputDecoration(labelText: 'Barcode')),
          TextField(controller: _purchase, decoration: const InputDecoration(labelText: 'Purchase price'), keyboardType: TextInputType.number),
          TextField(controller: _selling, decoration: const InputDecoration(labelText: 'Selling price'), keyboardType: TextInputType.number),
          TextField(controller: _mrp, decoration: const InputDecoration(labelText: 'MRP'), keyboardType: TextInputType.number),
          TextField(controller: _gst, decoration: const InputDecoration(labelText: 'GST %'), keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const CircularProgressIndicator() : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
