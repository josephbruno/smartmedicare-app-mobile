import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../data/models/purchase.dart';

class PurchaseDetailScreen extends StatefulWidget {
  const PurchaseDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  static final _moneyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final _dateFmt = DateFormat('d MMM yyyy');

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

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'received' => const Color(0xFF16A34A),
      'partial' => const Color(0xFFF59E0B),
      'cancelled' => AppTheme.danger,
      'ordered' => AppTheme.primary,
      _ => AppTheme.textSecondary,
    };
  }

  Color _paymentColor(String? status) {
    return switch (status?.toLowerCase()) {
      'paid' => const Color(0xFF16A34A),
      'partial' => const Color(0xFFF59E0B),
      'unpaid' => AppTheme.danger,
      _ => AppTheme.textSecondary,
    };
  }

  double _dueOf(Purchase p) {
    final paid = p.paidAmount ?? 0;
    final due = p.dueAmount ?? (p.totalAmount - paid);
    return due < 0 ? 0 : due;
  }

  Future<void> _openRecordPayment(Purchase p) async {
    final due = _dueOf(p);
    if (due <= 0) return;

    final updated = await showDialog<Purchase>(
      context: context,
      builder: (ctx) => _RecordPurchasePaymentDialog(
        purchase: p,
        dueAmount: due,
      ),
    );
    if (updated != null && mounted) {
      setState(() => _purchase = updated);
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Payment recorded successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _purchase;
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final auth = context.watch<AuthSession>();
    final canPay = auth.hasPermission(AppPermissions.purchasesEdit);
    final due = p == null ? 0.0 : _dueOf(p);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(p?.purchaseNumber ?? 'Purchase Detail'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        actions: [
          if (p != null && canPay && due > 0)
            TextButton.icon(
              onPressed: _loading ? null : () => _openRecordPayment(p),
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Record Payment'),
            ),
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
                        Icon(Icons.error_outline_rounded,
                            size: 40, color: AppTheme.danger.withValues(alpha: 0.8)),
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
              : p == null
                  ? const Center(child: Text('Purchase not found'))
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
                          _buildHero(p),
                          const SizedBox(height: 16),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _buildDetailsCard(p)),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: _buildSummaryCard(p)),
                              ],
                            )
                          else ...[
                            _buildDetailsCard(p),
                            const SizedBox(height: 16),
                            _buildSummaryCard(p),
                          ],
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

  Widget _buildHero(Purchase p) {
    final paid = p.paidAmount ?? 0;
    final due = p.dueAmount ?? (p.totalAmount - paid);
    final supplierName = p.supplier?.name ?? 'Unknown supplier';

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
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.purchaseNumber,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_prettyDate(p.purchaseDate)} · $supplierName',
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
                    _chip(_titleCase(p.status), _statusColor(p.status)),
                    if (p.paymentStatus != null && p.paymentStatus!.isNotEmpty)
                      _chip(
                        _titleCase(p.paymentStatus!),
                        _paymentColor(p.paymentStatus),
                      ),
                    if (p.branchName != null && p.branchName!.isNotEmpty)
                      _chip(
                        p.branchName!,
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
                    label: 'TOTAL',
                    value: _money(p.totalAmount),
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricTile(
                    label: 'PAID',
                    value: _money(paid),
                    color: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metricTile(
                    label: 'DUE',
                    value: _money(due < 0 ? 0 : due),
                    color: due > 0 ? AppTheme.danger : AppTheme.textSecondary,
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

  Widget _chip(String label, Color color, {IconData? icon}) {
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

  Widget _buildDetailsCard(Purchase p) {
    final supplier = p.supplier;
    return _section(
      title: 'Purchase Details',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _infoGrid([
            ('Purchase #', p.purchaseNumber),
            ('Date', _prettyDate(p.purchaseDate)),
            ('Status', _titleCase(p.status)),
            if (p.branchName != null && p.branchName!.isNotEmpty)
              ('Branch', p.branchName!),
          ]),
          const SizedBox(height: 16),
          Container(
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
                              _contactChip(Icons.mail_outline_rounded, supplier.email!),
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

  Widget _buildSummaryCard(Purchase p) {
    final paid = p.paidAmount ?? 0;
    final due = _dueOf(p);
    final subtotal = p.subtotal ?? p.totalAmount;
    final canPay = context.read<AuthSession>().hasPermission(AppPermissions.purchasesEdit);

    return _section(
      title: 'Amount Summary',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          _summaryRow('Subtotal', _money(subtotal)),
          const SizedBox(height: 10),
          _summaryRow(
            'Grand Total',
            _money(p.totalAmount),
            bold: true,
            valueColor: AppTheme.textPrimary,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          _summaryRow(
            'Paid',
            _money(paid),
            valueColor: const Color(0xFF16A34A),
          ),
          const SizedBox(height: 10),
          _summaryRow(
            'Balance Due',
            _money(due),
            bold: due > 0,
            valueColor: due > 0 ? AppTheme.danger : AppTheme.textSecondary,
          ),
          if (due > 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppTheme.danger.withValues(alpha: 0.9)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Outstanding balance of ${_money(due)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (canPay) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openRecordPayment(p),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Record Payment'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard(Purchase p) {
    return _section(
      title: 'Purchase Items',
      icon: Icons.inventory_2_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${p.items.length} item${p.items.length == 1 ? '' : 's'}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ),
      child: p.items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No line items on this purchase',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          : _buildItemsTable(p.items),
    );
  }

  Widget _buildItemsTable(List<PurchaseItem> items) {
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

    String qtyLabel(double q) =>
        q.toStringAsFixed(q == q.roundToDouble() ? 0 : 2);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minWidth = 860.0;
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
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.1),
                  4: FlexColumnWidth(1.2),
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
                          items[i].productName ?? 'Product #${items[i].productId}',
                          style: productStyle,
                        ),
                        bodyCell(
                          (items[i].productSku != null &&
                                  items[i].productSku!.isNotEmpty)
                              ? items[i].productSku!
                              : '—',
                          style: cellStyle.copyWith(color: AppTheme.textSecondary),
                        ),
                        bodyCell(
                          (items[i].batchNumber != null &&
                                  items[i].batchNumber!.isNotEmpty)
                              ? items[i].batchNumber!
                              : '—',
                          style: cellStyle.copyWith(color: AppTheme.textSecondary),
                        ),
                        bodyCell(
                          (items[i].expiryDate != null &&
                                  items[i].expiryDate!.isNotEmpty)
                              ? _prettyDate(items[i].expiryDate!)
                              : '—',
                          style: cellStyle.copyWith(color: AppTheme.textSecondary),
                        ),
                        bodyCell(
                          qtyLabel(items[i].quantity),
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

class _RecordPurchasePaymentDialog extends StatefulWidget {
  const _RecordPurchasePaymentDialog({
    required this.purchase,
    required this.dueAmount,
  });

  final Purchase purchase;
  final double dueAmount;

  @override
  State<_RecordPurchasePaymentDialog> createState() =>
      _RecordPurchasePaymentDialogState();
}

class _RecordPurchasePaymentDialogState
    extends State<_RecordPurchasePaymentDialog> {
  static const _modes = <(String, String)>[
    ('cash', 'Cash'),
    ('upi', 'UPI'),
    ('card', 'Card'),
    ('bank_transfer', 'Bank Transfer'),
    ('cheque', 'Cheque'),
    ('other', 'Other'),
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String _mode = 'cash';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.dueAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) return;

    setState(() => _saving = true);
    try {
      final updated = await context.read<AppServices>().purchases.recordPayment(
            widget.purchase.id,
            amount: amount,
            paymentMode: _mode,
            currentPaidAmount: widget.purchase.paidAmount ?? 0,
            paymentDate: DateFormat('yyyy-MM-dd').format(_date),
            referenceNumber: _reference.text.trim().isEmpty
                ? null
                : _reference.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueLabel = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(widget.dueAmount);

    return AlertDialog(
      title: const Text('Record Payment'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppTheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Due on ${widget.purchase.purchaseNumber}: $dueLabel',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount *',
                    prefixText: '₹ ',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    if (n > widget.dueAmount + 0.001) {
                      return 'Cannot exceed due $dueLabel';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppDropdownButtonFormField<String>(
                  value: _mode,
                  decoration: const InputDecoration(labelText: 'Payment Mode *'),
                  items: [
                    for (final m in _modes)
                      DropdownMenuItem(value: m.$1, child: Text(m.$2)),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) {
                          if (v != null) setState(() => _mode = v);
                        },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _saving ? null : _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Payment Date',
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(DateFormat('d MMM yyyy').format(_date)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reference,
                  decoration: const InputDecoration(
                    labelText: 'Reference (optional)',
                    hintText: 'UPI / cheque / txn id',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_saving ? 'Saving…' : 'Save Payment'),
        ),
      ],
    );
  }
}
