import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../app_services.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/receipt_branch_store.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/invoice.dart';
import '../reports/report_formatters.dart';

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  static final _moneyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final _dateFmt = DateFormat('d MMM yyyy');
  static final _dateTimeFmt = DateFormat('d MMM yyyy • h:mm a');

  late Future<Invoice> _future;
  bool _downloadingPdf = false;
  bool _cancelling = false;

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

  String _money(num n) => _moneyFmt.format(n);

  String _prettyDate(String raw) {
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _dateFmt.format(parsed);
  }

  /// Invoice date with time from created_at when available.
  String _invoiceDateWithTime(Invoice inv) {
    final created = inv.createdAt;
    if (created != null && created.isNotEmpty) {
      final parsed = DateTime.tryParse(created)?.toLocal();
      if (parsed != null) return _dateTimeFmt.format(parsed);
    }
    return _prettyDate(inv.invoiceDate);
  }

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

  String _statusLabel(String status) => titleCaseStatus(status);

  InvoicePayment? _primaryPayment(Invoice inv) {
    final payments = inv.payments;
    if (payments == null || payments.isEmpty) return null;
    return payments.first;
  }

  double _taxableAmount(Invoice inv) {
    final items = inv.items;
    if (items != null && items.isNotEmpty) {
      final sum = items.fold<double>(0, (s, i) => s + i.taxableAmount);
      if (sum > 0) return sum;
    }
    final sub = inv.subtotal > 0 ? inv.subtotal : inv.totalAmount;
    return (sub - inv.discountAmount).clamp(0, double.infinity);
  }

  double? _uniformGstRate(Invoice inv) {
    final items = inv.items;
    if (items == null || items.isEmpty) return null;
    final rates = items.map((i) => i.gstRate).toSet();
    if (rates.length != 1) return null;
    final rate = rates.first;
    return rate > 0 ? rate : null;
  }

  String _ratePct(double rate) {
    return rate == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : rate.toStringAsFixed(1);
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
    final header = await ReceiptBranchStore.resolveForPrint(auth);
    final result = await ThermalPrinterService.printReceipt(
      invoice: inv,
      items: inv.items!,
      shopName: header.name,
      companyName: header.shopName,
      shopPhone: header.phone,
      shopGstin: header.gstin,
      shopAddress: header.address,
      billerName: auth.user?.name,
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

  Future<void> _handleShareLink(Invoice inv) async {
    final token = inv.shareToken;
    if (token == null || token.isEmpty) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Share link is not available for this invoice.')),
      );
      return;
    }
    final shareUrl = '${AppConfig.webAppUrl}/share/invoice/$token';
    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (!mounted) return;
    AppMessenger.show(
      context,
      const SnackBar(content: Text('Share link copied!')),
    );
  }

  bool _canCancelInvoice(Invoice inv) {
    final auth = context.read<AuthSession>();
    return auth.isSuperAdmin &&
        auth.hasPermission(AppPermissions.invoicesCancel) &&
        inv.canCancel;
  }

  Future<void> _handleCancel(Invoice inv) async {
    if (_cancelling || !_canCancelInvoice(inv)) return;

    final billing = context.read<AppServices>().billing;
    final codeController = TextEditingController();
    var submitting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final code = codeController.text.trim();
              if (code.length != 6) {
                AppMessenger.error(context, 'Enter the 6-digit invoice security code');
                return;
              }
              setDialogState(() => submitting = true);
              try {
                await billing.cancel(inv.id, code: code);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (context.mounted) {
                  AppMessenger.error(context, '$e');
                }
                if (ctx.mounted) setDialogState(() => submitting = false);
              }
            }

            return AlertDialog(
              title: const Text('Cancel invoice'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cancel ${inv.displayInvoiceNumber}? Stock will be restored, payments will be voided, and this invoice will be excluded from sales and payment totals.',
                      style: const TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController,
                      enabled: !submitting,
                      autofocus: true,
                      obscureText: true,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSubmitted: (_) {
                        if (!submitting) submit();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Security code *',
                        hintText: '••••••',
                        helperText: '6-digit branch invoice code',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Keep invoice'),
                ),
                FilledButton(
                  onPressed: submitting ? null : submit,
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Cancel invoice'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await _reload();
      if (!mounted) return;
      AppMessenger.success(context, 'Invoice cancelled successfully.');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _handleDownloadPdf(Invoice inv) async {
    if (_downloadingPdf) return;
    setState(() => _downloadingPdf = true);
    try {
      final bytes = await context.read<AppServices>().billing.getPdfBytes(inv.id);
      if (!mounted) return;
      if (bytes.isEmpty) {
        AppMessenger.show(
          context,
          const SnackBar(content: Text('PDF could not be downloaded.')),
        );
        return;
      }
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: '${inv.invoiceNumber}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(content: Text('Failed to download PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _buildPageHeader(inv),
              const SizedBox(height: 14),
              _buildSummaryCard(inv),
              const SizedBox(height: 14),
              _buildItemsCard(items),
              const SizedBox(height: 14),
              _buildNotesAndTotals(inv),
              if (inv.returns.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildReturnsCard(inv),
              ],
              if (inv.hasCashPaymentSummary) ...[
                const SizedBox(height: 14),
                _buildCashSummaryCard(inv),
              ],
              if (inv.payments != null && inv.payments!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildPaymentsCard(inv.payments!),
              ],
              const SizedBox(height: 18),
              _buildActionButtons(inv),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageHeader(Invoice inv) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Invoice Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'More',
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onSelected: (value) {
            if (value == 'share_link') _handleShareLink(inv);
            if (value == 'whatsapp') _handleWhatsApp(inv);
            if (value == 'cancel') _handleCancel(inv);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'whatsapp', child: Text('Send WhatsApp')),
            const PopupMenuItem(value: 'share_link', child: Text('Copy share link')),
            if (_canCancelInvoice(inv))
              const PopupMenuItem(
                value: 'cancel',
                child: Text(
                  'Cancel invoice',
                  style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600),
                ),
              ),
          ],
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              color: Colors.white,
            ),
            child: const Icon(Icons.more_vert_rounded, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(Invoice inv) {
    final payment = _primaryPayment(inv);
    final statusColor = _statusColor(inv.status);
    final statusLabel = _statusLabel(inv.status);
    final customer = inv.customer;
    final customerName =
        customer?.name.isNotEmpty == true ? customer!.name : 'Walk-in';
    final canViewCustomer = customer != null && customer.id > 0;

    final leftMeta = <(String, Widget)>[
      ('Invoice No.', Text(inv.displayInvoiceNumber, style: _metaValueStyle)),
      if (inv.isReturnInvoice || inv.againstInvoiceNumber != null)
        (
          'Against Invoice',
          inv.returnOfInvoiceId != null
              ? InkWell(
                  onTap: () => context.push('/invoices/${inv.returnOfInvoiceId}'),
                  child: Text(
                    inv.againstInvoiceNumber ?? '—',
                    style: _metaValueStyle.copyWith(
                      color: AppTheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(inv.againstInvoiceNumber ?? '—', style: _metaValueStyle),
        ),
      ('Invoice Date', Text(_invoiceDateWithTime(inv), style: _metaValueStyle)),
      if (inv.dueDate != null && inv.dueDate!.isNotEmpty)
        ('Due Date', Text(_prettyDate(inv.dueDate!), style: _metaValueStyle)),
      (
        'Status',
        _statusBadge(statusLabel, statusColor, compact: true),
      ),
      (
        'Customer',
        Row(
          children: [
            Flexible(
              child: Text(
                customerName,
                style: _metaValueStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (canViewCustomer) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'View customer',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: Color(0xFF2563EB),
                ),
                onPressed: () => context.push('/customers/${customer.id}'),
              ),
            ],
          ],
        ),
      ),
      if (!inv.hasPayments && payment != null) ...[
        (
          'Payment Method',
          Text(paymentModeLabel(payment.paymentMode), style: _metaValueStyle),
        ),
        if (payment.referenceNumber != null && payment.referenceNumber!.isNotEmpty)
          (
            'Payment Ref No.',
            Text(payment.referenceNumber!, style: _metaValueStyle),
          ),
      ],
    ];

    final rightMeta = <(String, Widget)>[
      if (inv.branchName.isNotEmpty && inv.branchName != '—')
        ('Branch', Text(inv.branchName, style: _metaValueStyle)),
      if (inv.hasPayments)
        (
          'Payments',
          Text(
            inv.paymentBreakdownSummary(modeLabel: paymentModeLabel),
            style: _metaValueStyle,
          ),
        ),
      if (inv.creatorName != '—')
        ('Created by', Text(inv.creatorName, style: _metaValueStyle)),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoCol = constraints.maxWidth >= 640 && rightMeta.isNotEmpty;
          if (!twoCol) {
            return _metaGrid([...leftMeta, ...rightMeta], columns: 1);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _metaGrid(leftMeta, columns: 1)),
              const SizedBox(width: 24),
              Expanded(child: _metaGrid(rightMeta, columns: 1)),
            ],
          );
        },
      ),
    );
  }
  Widget _buildItemsCard(List<InvoiceItem> items) {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 9,
      color: AppTheme.textSecondary,
      letterSpacing: 0.4,
    );
    const cellStyle = TextStyle(fontSize: 12, color: AppTheme.textPrimary);
    const productStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
    );

    Widget headerCell(String label, {TextAlign align = TextAlign.left}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Text(label, textAlign: align, style: headerStyle),
      );
    }

    Widget bodyCell(
      String text, {
      TextAlign align = TextAlign.left,
      TextStyle style = cellStyle,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Text(text, textAlign: align, style: style),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(Icons.shopping_cart_outlined, 'Invoice Items'),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No line items',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final minWidth = 780.0;
                final tableWidth =
                    constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(0.5),
                        1: FlexColumnWidth(2.8),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(0.7),
                        4: FlexColumnWidth(1.2),
                        5: FlexColumnWidth(1.1),
                        6: FlexColumnWidth(0.8),
                        7: FlexColumnWidth(1.2),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: const Color(0xFFE2E8F0).withValues(alpha: 0.9),
                        ),
                        bottom: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                          children: [
                            headerCell('#'),
                            headerCell('Product'),
                            headerCell('HSN / SKU'),
                            headerCell('Qty', align: TextAlign.right),
                            headerCell('Unit Price', align: TextAlign.right),
                            headerCell('Discount', align: TextAlign.right),
                            headerCell('Tax', align: TextAlign.right),
                            headerCell('Total', align: TextAlign.right),
                          ],
                        ),
                        for (var i = 0; i < items.length; i++)
                          TableRow(
                            children: [
                              bodyCell('${i + 1}'),
                              bodyCell(items[i].productName, style: productStyle),
                              bodyCell(
                                (items[i].hsnCode != null && items[i].hsnCode!.isNotEmpty)
                                    ? items[i].hsnCode!
                                    : '—',
                                style: cellStyle.copyWith(color: AppTheme.textSecondary),
                              ),
                              bodyCell(_qty(items[i].quantity), align: TextAlign.right),
                              bodyCell(_money(items[i].unitPrice), align: TextAlign.right),
                              bodyCell(_money(items[i].discountAmount), align: TextAlign.right),
                              bodyCell(
                                items[i].gstRate > 0
                                    ? '${items[i].gstRate.toStringAsFixed(0)}%'
                                    : '—',
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
          const SizedBox(height: 12),
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Thank you for your purchase!',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.favorite, size: 14, color: Color(0xFFEC4899)),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildNotesAndTotals(Invoice inv) {
    final notes = inv.notes?.trim();
    final gstRate = _uniformGstRate(inv);
    final halfRate = gstRate != null ? gstRate / 2 : null;
    final isPaid = !inv.isCancelled &&
        (inv.status.toLowerCase() == 'paid' || inv.dueAmount <= 0.009);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final notesCard = Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle(Icons.description_outlined, 'Notes'),
              const SizedBox(height: 12),
              Text(
                (notes != null && notes.isNotEmpty) ? notes : '—',
                style: TextStyle(
                  color: (notes != null && notes.isNotEmpty)
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );

        final totalsCard = Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              _summaryRow(
                'Subtotal',
                _money(inv.subtotal > 0 ? inv.subtotal : inv.totalAmount),
              ),
              if (inv.discountAmount > 0) ...[
                const SizedBox(height: 8),
                _summaryRow(
                  'Discount',
                  '- ${_money(inv.discountAmount)}',
                  valueColor: AppTheme.danger,
                ),
              ],
              const SizedBox(height: 8),
              _summaryRow('Taxable Amount', _money(_taxableAmount(inv))),
              if (inv.isIgst && inv.igstAmount > 0) ...[
                const SizedBox(height: 8),
                _summaryRow(
                  gstRate != null ? 'IGST (${_ratePct(gstRate)}%)' : 'IGST',
                  _money(inv.igstAmount),
                ),
              ] else ...[
                if (inv.cgstAmount > 0) ...[
                  const SizedBox(height: 8),
                  _summaryRow(
                    halfRate != null ? 'CGST (${_ratePct(halfRate)}%)' : 'CGST',
                    _money(inv.cgstAmount),
                  ),
                ],
                if (inv.sgstAmount > 0) ...[
                  const SizedBox(height: 8),
                  _summaryRow(
                    halfRate != null ? 'SGST (${_ratePct(halfRate)}%)' : 'SGST',
                    _money(inv.sgstAmount),
                  ),
                ],
                if (inv.cgstAmount <= 0 &&
                    inv.sgstAmount <= 0 &&
                    inv.totalGst > 0) ...[
                  const SizedBox(height: 8),
                  _summaryRow('GST', _money(inv.totalGst)),
                ],
              ],
              if (inv.roundOff != 0) ...[
                const SizedBox(height: 8),
                _summaryRow('Round Off', _money(inv.roundOff)),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
              _summaryRow(
                'Grand Total',
                _money(inv.totalAmount),
                bold: true,
                valueColor: const Color(0xFF2563EB),
                large: true,
              ),
              if (inv.isCancelled) ...[
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '(Cancelled)',
                    style: TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ] else if (isPaid) ...[
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '(Paid)',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ] else if (inv.dueAmount > 0) ...[
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

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: notesCard),
              const SizedBox(width: 14),
              Expanded(child: totalsCard),
            ],
          );
        }

        return Column(
          children: [
            notesCard,
            const SizedBox(height: 14),
            totalsCard,
          ],
        );
      },
    );
  }

  Widget _buildReturnsCard(Invoice inv) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(Icons.assignment_return_outlined, 'Sale Returns'),
          const SizedBox(height: 8),
          const Text(
            'Returns recorded against this invoice',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final r in inv.returns) ...[
            InkWell(
              onTap: () => context.push('/invoices/${r.id}'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.invoiceNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                          if (r.invoiceDate != null && r.invoiceDate!.isNotEmpty)
                            Text(
                              _prettyDate(r.invoiceDate!),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      _money(r.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
            if (r != inv.returns.last) const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ],
        ],
      ),
    );
  }

  Widget _buildCashSummaryCard(Invoice inv) {
    final cash = inv.cashReceivedTotal;
    final change = inv.changeReturnTotal;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(Icons.payments_rounded, 'Cash Summary'),
          const SizedBox(height: 12),
          if (cash != null) ...[
            _summaryRow('Cash received', _money(cash)),
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
    final activeTotal = payments
        .where((p) => !p.isCancelled)
        .fold<double>(0, (s, p) => s + p.amount);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(Icons.account_balance_wallet_outlined, 'Payments'),
          const SizedBox(height: 4),
          Text(
            'How this bill was collected (split payments listed separately).',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < payments.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              paymentModeLabel(payments[i].paymentMode),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: payments[i].isCancelled
                                    ? AppTheme.textSecondary
                                    : AppTheme.textPrimary,
                                decoration: payments[i].isCancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          if (payments[i].isCancelled) ...[
                            const SizedBox(width: 8),
                            _statusBadge('Cancelled', AppTheme.danger, compact: true),
                          ],
                        ],
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
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: payments[i].isCancelled
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                    decoration: payments[i].isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ],
            ),
          ],
          if (payments.length > 1 || payments.any((p) => p.isCancelled)) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total paid',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  _money(activeTotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(Invoice inv) {
    final canPrint = inv.items != null && inv.items!.isNotEmpty;
    final canReturn = context.watch<AuthSession>().hasPermission(AppPermissions.invoicesCreate) &&
        inv.canReturn;
    final canCancel = _canCancelInvoice(inv);

    return LayoutBuilder(
      builder: (context, constraints) {
        final extra = (canReturn ? 1 : 0) + (canCancel ? 1 : 0);
        final wrap = constraints.maxWidth < 640 + extra * 120;
        final buttons = [
          if (canReturn)
            _actionButton(
              label: 'Sale Return',
              icon: Icons.assignment_return_outlined,
              color: const Color(0xFFB45309),
              onPressed: () => context.push('/invoices/${inv.id}/return'),
            ),
          if (canCancel)
            _actionButton(
              label: 'Cancel Invoice',
              icon: Icons.cancel_outlined,
              color: AppTheme.danger,
              onPressed: _cancelling ? null : () => _handleCancel(inv),
              loading: _cancelling,
            ),
          _actionButton(
            label: 'Print Invoice',
            icon: Icons.print_outlined,
            color: const Color(0xFF2563EB),
            onPressed: canPrint ? () => _handlePrint(inv) : null,
          ),
          _actionButton(
            label: 'Share Invoice',
            icon: Icons.share_outlined,
            color: const Color(0xFF16A34A),
            onPressed: () => _handleWhatsApp(inv),
          ),
          _actionButton(
            label: 'Download PDF',
            icon: Icons.picture_as_pdf_outlined,
            color: const Color(0xFFEF4444),
            onPressed: _downloadingPdf ? null : () => _handleDownloadPdf(inv),
            loading: _downloadingPdf,
          ),
        ];

        if (wrap) {
          return Column(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: buttons[i]),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: buttons[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, size: 18, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String label, Color color, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.toLowerCase() == 'paid') ...[
            Icon(Icons.check_circle, size: compact ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaGrid(List<(String, Widget)> rows, {int columns = 2}) {
    if (columns <= 1) {
      return Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(row.$1, style: _metaLabelStyle),
                  ),
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: row.$2)),
                ],
              ),
            ),
        ],
      );
    }

    final left = <(String, Widget)>[];
    final right = <(String, Widget)>[];
    for (var i = 0; i < rows.length; i++) {
      (i.isEven ? left : right).add(rows[i]);
    }

    Widget col(List<(String, Widget)> items) {
      return Column(
        children: [
          for (final row in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(row.$1, style: _metaLabelStyle),
                  ),
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: row.$2)),
                ],
              ),
            ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: col(left)),
        const SizedBox(width: 16),
        Expanded(child: col(right)),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [
        BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
      ],
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    bool large = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: large ? 15 : 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: large ? 20 : 14,
          ),
        ),
      ],
    );
  }

  String _qty(double q) {
    if (q == q.roundToDouble()) return q.toStringAsFixed(0);
    return q.toStringAsFixed(2);
  }

  static const _metaLabelStyle = TextStyle(
    color: AppTheme.textSecondary,
    fontWeight: FontWeight.w500,
    fontSize: 13,
  );

  static const _metaValueStyle = TextStyle(
    color: AppTheme.textPrimary,
    fontWeight: FontWeight.w600,
    fontSize: 13.5,
  );
}
