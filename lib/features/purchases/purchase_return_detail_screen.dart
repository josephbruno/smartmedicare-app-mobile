import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/purchase.dart';
import '../../data/models/purchase_return.dart';

class PurchaseReturnDetailScreen extends StatefulWidget {
  const PurchaseReturnDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<PurchaseReturnDetailScreen> createState() =>
      _PurchaseReturnDetailScreenState();
}

class _PurchaseReturnDetailScreenState
    extends State<PurchaseReturnDetailScreen> {
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

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  Color _reasonColor(String reason) {
    return switch (reason.toLowerCase()) {
      'expired' => AppTheme.warning,
      'damaged' => AppTheme.danger,
      _ => AppTheme.textSecondary,
    };
  }

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'completed' || 'posted' => const Color(0xFF16A34A),
      'draft' => AppTheme.textSecondary,
      'cancelled' || 'void' => AppTheme.danger,
      'pending' => AppTheme.warning,
      _ => AppTheme.primary,
    };
  }

  IconData _reasonIcon(String reason) {
    return switch (reason.toLowerCase()) {
      'expired' => Icons.schedule_outlined,
      'damaged' => Icons.broken_image_outlined,
      _ => Icons.assignment_return_outlined,
    };
  }

  String _qtyLabel(double q) =>
      q.toStringAsFixed(q == q.roundToDouble() ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    final r = _return;
    final wide = MediaQuery.sizeOf(context).width >= 960;

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
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
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
                        Icon(
                          Icons.error_outline_rounded,
                          size: 40,
                          color: AppTheme.danger.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : r == null
                  ? const Center(child: Text('Return not found'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 24 : 16,
                          16,
                          wide ? 24 : 16,
                          32,
                        ),
                        children: [
                          _buildHero(r),
                          const SizedBox(height: 16),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _buildDetailsCard(r)),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: _buildSummaryCard(r)),
                              ],
                            )
                          else ...[
                            _buildDetailsCard(r),
                            const SizedBox(height: 16),
                            _buildSummaryCard(r),
                          ],
                          const SizedBox(height: 16),
                          _buildItemsCard(r),
                          if (r.notes != null && r.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildNotesCard(r.notes!.trim()),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildHero(PurchaseReturn r) {
    final supplierName = r.supplier?.name ?? 'Unknown supplier';
    final reasonColor = _reasonColor(r.reason);

    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: reasonColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _reasonIcon(r.reason),
                        color: reasonColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.returnNumber,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_prettyDate(r.returnDate)} · $supplierName',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(
                      _titleCase(r.status),
                      _statusColor(r.status),
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    _chip(
                      r.reasonLabel,
                      reasonColor,
                      icon: _reasonIcon(r.reason),
                      prefix: 'Reason',
                    ),
                    if (r.branchName != null && r.branchName!.isNotEmpty)
                      _chip(
                        r.branchName!,
                        AppTheme.textSecondary,
                        icon: Icons.storefront_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: _metricTile(
                    label: 'RETURN TOTAL',
                    value: _money(r.totalAmount),
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricTile(
                    label: 'ITEMS',
                    value: '${r.items.length}',
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricTile(
                    label: 'QTY RETURNED',
                    value: _qtyLabel(
                      r.items.fold<double>(0, (s, i) => s + i.quantity),
                    ),
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    Color color, {
    IconData? icon,
    String? prefix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          if (prefix != null) ...[
            Text(
              '$prefix · ',
              style: TextStyle(
                color: color.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(PurchaseReturn r) {
    return _section(
      title: 'Return Details',
      icon: Icons.assignment_return_outlined,
      child: Column(
        children: [
          _infoGrid([
            ('Return #', r.returnNumber),
            ('Date', _prettyDate(r.returnDate)),
            ('Status', _titleCase(r.status)),
            ('Reason', r.reasonLabel),
            if (r.branchName != null && r.branchName!.isNotEmpty)
              ('Branch', r.branchName!),
          ]),
          const SizedBox(height: 16),
          _buildSupplierBlock(r.supplier),
        ],
      ),
    );
  }

  Widget _buildSupplierBlock(Supplier? supplier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.business_outlined,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SUPPLIER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  supplier?.name ?? '—',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (supplier?.companyName != null &&
                    supplier!.companyName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    supplier.companyName!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if (supplier != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      if (supplier.phone.isNotEmpty)
                        _contactChip(Icons.phone_outlined, supplier.phone),
                      if (supplier.email != null && supplier.email!.isNotEmpty)
                        _contactChip(
                          Icons.mail_outline_rounded,
                          supplier.email!,
                        ),
                      if (supplier.gstin != null && supplier.gstin!.isNotEmpty)
                        _contactChip(Icons.badge_outlined, supplier.gstin!),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _infoGrid(List<(String, String)> rows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 420;
        if (!twoCol) {
          return Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _kv(rows[i].$1, rows[i].$2),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final row in rows)
              SizedBox(
                width: (constraints.maxWidth - 16) / 2,
                child: _kv(row.$1, row.$2),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(PurchaseReturn r) {
    final subtotal = r.subtotal ?? r.totalAmount;

    return _section(
      title: 'Amount Summary',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          _summaryRow('Subtotal', _money(subtotal)),
          const SizedBox(height: 10),
          _summaryRow(
            'Return Total',
            _money(r.totalAmount),
            bold: true,
            valueColor: AppTheme.textPrimary,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _reasonColor(r.reason).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _reasonColor(r.reason).withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _reasonIcon(r.reason),
                  size: 18,
                  color: _reasonColor(r.reason),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Returned for ${r.reasonLabel.toLowerCase()}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _reasonColor(r.reason),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(PurchaseReturn r) {
    return _section(
      title: 'Returned Items',
      icon: Icons.inventory_2_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${r.items.length} item${r.items.length == 1 ? '' : 's'}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ),
      child: r.items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No line items on this return',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          : _buildItemsTable(r.items),
    );
  }

  Widget _buildItemsTable(List<PurchaseReturnItem> items) {
    const headerStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w800,
      color: AppTheme.textSecondary,
      letterSpacing: 0.4,
    );
    const cellStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppTheme.textPrimary,
    );
    const productStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppTheme.textPrimary,
    );

    Widget headerCell(String text, {TextAlign align = TextAlign.left}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(text, textAlign: align, style: headerStyle),
      );
    }

    Widget bodyCell(
      String text, {
      TextAlign align = TextAlign.left,
      TextStyle style = cellStyle,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text(text, textAlign: align, style: style),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minWidth = 720.0;
          final tableWidth =
              constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(0.45),
                  1: FlexColumnWidth(2.4),
                  2: FlexColumnWidth(1.1),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(1.1),
                  5: FlexColumnWidth(0.8),
                  6: FlexColumnWidth(1.2),
                  7: FlexColumnWidth(1.2),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: const Color(0xFFE2E8F0).withValues(alpha: 0.95),
                  ),
                ),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                    children: [
                      headerCell('#'),
                      headerCell('Product'),
                      headerCell('SKU'),
                      headerCell('Batch'),
                      headerCell('Expiry'),
                      headerCell('Qty', align: TextAlign.right),
                      headerCell('Unit Price', align: TextAlign.right),
                      headerCell('Total', align: TextAlign.right),
                    ],
                  ),
                  for (var i = 0; i < items.length; i++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: i.isOdd ? const Color(0xFFFCFDFE) : Colors.white,
                      ),
                      children: [
                        bodyCell('${i + 1}'),
                        bodyCell(
                          items[i].productName ??
                              'Product #${items[i].productId}',
                          style: productStyle,
                        ),
                        bodyCell(
                          (items[i].productSku != null &&
                                  items[i].productSku!.isNotEmpty)
                              ? items[i].productSku!
                              : '—',
                          style: cellStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        bodyCell(
                          (items[i].batchNumber != null &&
                                  items[i].batchNumber!.isNotEmpty)
                              ? items[i].batchNumber!
                              : '—',
                          style: cellStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        bodyCell(
                          (items[i].expiryDate != null &&
                                  items[i].expiryDate!.isNotEmpty)
                              ? _prettyDate(items[i].expiryDate!)
                              : '—',
                          style: cellStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        bodyCell(
                          _qtyLabel(items[i].quantity),
                          align: TextAlign.right,
                        ),
                        bodyCell(
                          _money(items[i].unitPrice),
                          align: TextAlign.right,
                        ),
                        bodyCell(
                          _money(items[i].totalAmount),
                          align: TextAlign.right,
                          style: productStyle,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotesCard(String notes) {
    return _section(
      title: 'Notes',
      icon: Icons.notes_outlined,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Text(
          notes,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            height: 1.45,
            fontSize: 14,
          ),
        ),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  Widget _kv(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 1.3,
          ),
        ),
      ],
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
            fontSize: bold ? 17 : 14,
          ),
        ),
      ],
    );
  }
}
