import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/purchase_return.dart';

class PurchaseReturnDetailScreen extends StatefulWidget {
  const PurchaseReturnDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<PurchaseReturnDetailScreen> createState() => _PurchaseReturnDetailScreenState();
}

class _PurchaseReturnDetailScreenState extends State<PurchaseReturnDetailScreen> {
  static final _moneyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final _dateFmt = DateFormat('d MMM yyyy');

  bool _loading = true;
  String? _error;
  PurchaseReturn? _return;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context.read<AppServices>().purchaseReturns.get(widget.id);
      if (!mounted) return;
      setState(() {
        _return = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _money(num n) => _moneyFmt.format(n);

  String _prettyDate(String raw) {
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
    return _dateFmt.format(parsed);
  }

  Color _reasonColor(String reason) {
    return switch (reason.toLowerCase()) {
      'expired' => AppTheme.warning,
      'damaged' => AppTheme.danger,
      _ => AppTheme.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final r = _return;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(r?.returnNumber ?? 'Supplier Return'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : r == null
                  ? const Center(child: Text('Return not found'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.returnNumber,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _reasonColor(r.reason).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      r.reasonLabel,
                                      style: TextStyle(
                                        color: _reasonColor(r.reason),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _meta('Supplier', r.supplier?.name ?? '—'),
                              _meta('Branch', r.branchName ?? '—'),
                              _meta('Date', _prettyDate(r.returnDate)),
                              _meta('Status', r.status),
                              _meta('Total', _money(r.totalAmount)),
                              if (r.notes != null && r.notes!.trim().isNotEmpty)
                                _meta('Notes', r.notes!.trim()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Items',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              const SizedBox(height: 12),
                              if (r.items.isEmpty)
                                const Text(
                                  'No items',
                                  style: TextStyle(color: AppTheme.textSecondary),
                                )
                              else
                                ...r.items.map((item) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.productName ?? 'Product #${item.productId}',
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                              if (item.batchNumber != null &&
                                                  item.batchNumber!.isNotEmpty)
                                                Text(
                                                  'Batch: ${item.batchNumber}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${item.quantity} × ${_money(item.unitPrice)}',
                                          style: const TextStyle(color: AppTheme.textSecondary),
                                        ),
                                        const SizedBox(width: 16),
                                        SizedBox(
                                          width: 100,
                                          child: Text(
                                            _money(item.totalAmount),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
