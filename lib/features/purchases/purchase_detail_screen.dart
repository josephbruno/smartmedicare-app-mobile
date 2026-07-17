import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/purchase.dart';

class PurchaseDetailScreen extends StatefulWidget {
  const PurchaseDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  bool _loading = true;
  String? _error;
  Purchase? _purchase;

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
      final p = await context.read<AppServices>().purchases.get(widget.id);
      if (!mounted) return;
      setState(() {
        _purchase = p;
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

  String _money(num n) => '₹${n.toStringAsFixed(2)}';

  Color _statusColor(String status) {
    return switch (status) {
      'received' => const Color(0xFF16A34A),
      'partial' => const Color(0xFFF59E0B),
      'cancelled' => AppTheme.danger,
      'ordered' => AppTheme.primary,
      _ => AppTheme.textSecondary,
    };
  }

  Color _paymentColor(String? status) {
    return switch (status) {
      'paid' => const Color(0xFF16A34A),
      'partial' => const Color(0xFFF59E0B),
      'unpaid' => AppTheme.danger,
      _ => AppTheme.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = _purchase;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(p?.purchaseNumber ?? 'Purchase Detail'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 1,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : p == null
                  ? const Center(child: Text('Purchase not found'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        children: [
                          _buildHeader(p),
                          const SizedBox(height: 16),
                          _buildDetailsCard(p),
                          const SizedBox(height: 16),
                          _buildSummaryCard(p),
                          const SizedBox(height: 16),
                          _buildItemsCard(p),
                          if (p.notes != null && p.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildNotesCard(p.notes!.trim()),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildHeader(Purchase p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.purchaseNumber,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                p.status,
                _statusColor(p.status),
              ),
              if (p.paymentStatus != null && p.paymentStatus!.isNotEmpty)
                _chip(
                  p.paymentStatus!,
                  _paymentColor(p.paymentStatus),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDetailsCard(Purchase p) {
    final supplier = p.supplier;
    return _section(
      title: 'Purchase Details',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _kv('Purchase #', p.purchaseNumber, emphasize: true),
          _kv('Date', p.dateOnly),
          _kv('Status', p.status),
          if (p.branchName != null && p.branchName!.isNotEmpty)
            _kv('Branch', p.branchName!),
          const Divider(height: 24),
          _kv('Supplier', supplier?.name ?? '—', emphasize: true),
          if (supplier?.phone != null && supplier!.phone.isNotEmpty)
            _kv('Phone', supplier.phone),
          if (supplier?.gstin != null && supplier!.gstin!.isNotEmpty)
            _kv('GSTIN', supplier.gstin!),
          if (supplier?.email != null && supplier!.email!.isNotEmpty)
            _kv('Email', supplier.email!),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Purchase p) {
    final paid = p.paidAmount ?? 0;
    final due = p.dueAmount ?? 0;
    final subtotal = p.subtotal ?? p.totalAmount;

    return _section(
      title: 'Amount Summary',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          _summaryRow('Subtotal', _money(subtotal)),
          const Divider(height: 20),
          _summaryRow(
            'Total',
            _money(p.totalAmount),
            bold: true,
            valueColor: AppTheme.textPrimary,
          ),
          const SizedBox(height: 8),
          _summaryRow(
            'Paid',
            _money(paid),
            valueColor: const Color(0xFF16A34A),
          ),
          if (due > 0) ...[
            const SizedBox(height: 8),
            _summaryRow(
              'Due',
              _money(due),
              bold: true,
              valueColor: AppTheme.danger,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard(Purchase p) {
    return _section(
      title: 'Purchase Items',
      icon: Icons.shopping_cart_outlined,
      trailing: Text(
        '${p.items.length} item${p.items.length == 1 ? '' : 's'}',
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      child: p.items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No line items',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < p.items.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  _itemTile(i + 1, p.items[i]),
                ],
              ],
            ),
    );
  }

  Widget _itemTile(int index, PurchaseItem item) {
    final name = item.productName ?? 'Product #${item.productId}';
    final meta = <String>[
      if (item.productSku != null && item.productSku!.isNotEmpty) 'SKU: ${item.productSku}',
      if (item.batchNumber != null && item.batchNumber!.isNotEmpty)
        'Batch: ${item.batchNumber}',
      if (item.expiryDate != null && item.expiryDate!.isNotEmpty)
        'Exp: ${item.expiryDate!.length >= 10 ? item.expiryDate!.substring(0, 10) : item.expiryDate}',
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '${item.quantity} × ${_money(item.unitPrice)}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        Text(
          _money(item.totalAmount),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard(String notes) {
    return _section(
      title: 'Notes',
      icon: Icons.notes_outlined,
      child: Text(
        notes,
        style: const TextStyle(color: AppTheme.textPrimary, height: 1.4),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [
        BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
      ],
    );
  }

  Widget _kv(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: bold ? 15 : 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
