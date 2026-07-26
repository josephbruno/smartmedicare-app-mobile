import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/invoice.dart';

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late Future<Invoice> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().billing.get(widget.id);
  }

  Future<void> _reload() async {
    setState(() {
      _future = context.read<AppServices>().billing.get(widget.id);
    });
    await _future;
  }

  String _money(num n) => '₹${n.toStringAsFixed(2)}';

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'paid' => const Color(0xFF16A34A),
      'partial' => const Color(0xFFF59E0B),
      'cancelled' || 'void' => AppTheme.danger,
      'draft' => AppTheme.textSecondary,
      'confirmed' => AppTheme.primary,
      _ => AppTheme.primary,
    };
  }

  Future<void> _handleWhatsApp(Invoice inv) async {
    final services = context.read<AppServices>();
    final phoneController = TextEditingController(text: inv.customer?.phone ?? '');
    bool sending = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Send WhatsApp Invoice'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Enter target phone number:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                sending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : FilledButton(
                        onPressed: () async {
                          final phone = phoneController.text.trim();
                          if (phone.isEmpty) return;
                          setDialogState(() => sending = true);
                          try {
                            final success =
                                await services.billing.sendWhatsApp(inv.id, phone: phone);
                            if (success) {
                              if (context.mounted) {
                                AppMessenger.show(
                                  context,
                                  const SnackBar(
                                    content: Text('WhatsApp message sent successfully!'),
                                  ),
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            } else if (context.mounted) {
                              AppMessenger.show(
                                context,
                                const SnackBar(
                                  content: Text('Failed to send WhatsApp message.'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppMessenger.show(
                                context,
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } finally {
                            setDialogState(() => sending = false);
                          }
                        },
                        child: const Text('Send'),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handlePrint(Invoice inv) async {
    if (inv.items == null || inv.items!.isEmpty) return;
    final auth = context.read<AuthSession>();
    final result = await ThermalPrinterService.printReceipt(
      invoice: inv,
      items: inv.items!,
      shopName: auth.currentShop?.name ?? auth.currentBranch?.name,
    );
    if (!mounted) return;
    AppMessenger.show(
      context,
      SnackBar(
        content: Text(result.userMessage),
        backgroundColor: result.isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _handleShare(Invoice inv) async {
    final token = inv.shareToken;
    if (token == null || token.isEmpty) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Share link is not available for this invoice.')),
      );
      return;
    }
    final shareUrl = 'http://localhost:8001/share/invoice/$token';
    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (!mounted) return;
    AppMessenger.show(
      context,
      const SnackBar(content: Text('Share link copied!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Invoice>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: Text('Invoice not found'));
        }

        final inv = snap.data!;
        final items = inv.items ?? const <InvoiceItem>[];

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _buildHeader(inv),
              const SizedBox(height: 12),
              _buildActions(inv),
              const SizedBox(height: 16),
              _buildDetailsCard(inv),
              const SizedBox(height: 16),
              _buildItemsCard(items),
              const SizedBox(height: 16),
              _buildSummaryCard(inv),
              if (inv.hasCashPaymentSummary) ...[
                const SizedBox(height: 16),
                _buildCashSummaryCard(inv),
              ],
              if (inv.payments != null && inv.payments!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildPaymentsCard(inv.payments!),
              ],
              if (inv.notes != null && inv.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildNotesCard(inv.notes!.trim()),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Invoice inv) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  inv.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _money(inv.totalAmount),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(inv.status, _statusColor(inv.status)),
              if (inv.type.isNotEmpty)
                _chip(inv.type.replaceAll('_', ' '), AppTheme.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Invoice inv) {
    final canPrint = inv.items != null && inv.items!.isNotEmpty;
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: AppTheme.primary,
      side: const BorderSide(color: Color(0xFFBFDBFE)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 520;
        final whatsapp = FilledButton.icon(
          onPressed: () => _handleWhatsApp(inv),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('WhatsApp'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        );
        final printBtn = OutlinedButton.icon(
          onPressed: canPrint ? () => _handlePrint(inv) : null,
          icon: const Icon(Icons.print_rounded, size: 18),
          label: const Text('Print'),
          style: buttonStyle,
        );
        final shareBtn = OutlinedButton.icon(
          onPressed: () => _handleShare(inv),
          icon: const Icon(Icons.link_rounded, size: 18),
          label: const Text('Share Link'),
          style: buttonStyle,
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              whatsapp,
              const SizedBox(height: 8),
              printBtn,
              const SizedBox(height: 8),
              shareBtn,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: whatsapp),
            const SizedBox(width: 8),
            Expanded(child: printBtn),
            const SizedBox(width: 8),
            Expanded(child: shareBtn),
          ],
        );
      },
    );
  }

  Widget _buildDetailsCard(Invoice inv) {
    final customer = inv.customer;
    return _section(
      title: 'Invoice Details',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _kv('Date', inv.displayDate),
          if (inv.dueDate != null && inv.dueDate!.isNotEmpty) _kv('Due date', inv.dueDate!),
          _kv('Branch', inv.branchName),
          const Divider(height: 24),
          _kv('Customer', customer?.name.isNotEmpty == true ? customer!.name : 'Walk-in', emphasize: true),
          if (customer?.phone != null && customer!.phone.isNotEmpty) _kv('Phone', customer.phone),
        ],
      ),
    );
  }

  Widget _buildItemsCard(List<InvoiceItem> items) {
    return _section(
      title: 'Line Items',
      icon: Icons.shopping_cart_outlined,
      trailing: Text(
        '${items.length} item${items.length == 1 ? '' : 's'}',
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No line items',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  _itemTile(i + 1, items[i]),
                ],
              ],
            ),
    );
  }

  Widget _itemTile(int index, InvoiceItem item) {
    final meta = <String>[
      if (item.hsnCode != null && item.hsnCode!.isNotEmpty) 'HSN: ${item.hsnCode}',
      if (item.gstRate > 0) 'GST ${item.gstRate.toStringAsFixed(0)}%',
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
                item.productName,
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

  Widget _buildSummaryCard(Invoice inv) {
    return _section(
      title: 'Amount Summary',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          _summaryRow('Subtotal', _money(inv.subtotal > 0 ? inv.subtotal : inv.totalAmount)),
          if (inv.discountAmount > 0) ...[
            const SizedBox(height: 8),
            _summaryRow('Discount', '- ${_money(inv.discountAmount)}'),
          ],
          if (inv.totalGst > 0) ...[
            const SizedBox(height: 8),
            _summaryRow('GST', _money(inv.totalGst)),
          ],
          if (inv.roundOff != 0) ...[
            const SizedBox(height: 8),
            _summaryRow('Round off', _money(inv.roundOff)),
          ],
          const Divider(height: 20),
          _summaryRow(
            'Total',
            _money(inv.totalAmount),
            bold: true,
            valueColor: AppTheme.textPrimary,
          ),
          const SizedBox(height: 8),
          _summaryRow(
            'Paid',
            _money(inv.paidAmount),
            valueColor: const Color(0xFF16A34A),
          ),
          if (inv.dueAmount > 0) ...[
            const SizedBox(height: 8),
            _summaryRow(
              'Due',
              _money(inv.dueAmount),
              bold: true,
              valueColor: AppTheme.danger,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCashSummaryCard(Invoice inv) {
    final cash = inv.cashReceivedTotal;
    final change = inv.changeReturnTotal;
    return _section(
      title: 'Cash Summary',
      icon: Icons.payments_rounded,
      child: Column(
        children: [
          if (cash != null) ...[
            _summaryRow(
              'Cash received',
              _money(cash),
              valueColor: AppTheme.textPrimary,
            ),
            if (change != null && change > 0) ...[
              const SizedBox(height: 8),
              _summaryRow(
                'Change return',
                _money(change),
                bold: true,
                valueColor: AppTheme.accent,
              ),
            ],
          ],
          if (inv.hasBalanceDue) ...[
            if (cash != null) const SizedBox(height: 8),
            _summaryRow(
              'Balance due',
              _money(inv.dueAmount),
              bold: true,
              valueColor: AppTheme.warning,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentsCard(List<InvoicePayment> payments) {
    return _section(
      title: 'Payments',
      icon: Icons.account_balance_wallet_outlined,
      trailing: Text(
        '${payments.length}',
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      child: Column(
        children: [
          for (var i = 0; i < payments.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payments[i].paymentMode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        payments[i].paymentDate,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      if (payments[i].referenceNumber != null &&
                          payments[i].referenceNumber!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Ref: ${payments[i].referenceNumber}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  _money(payments[i].amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
