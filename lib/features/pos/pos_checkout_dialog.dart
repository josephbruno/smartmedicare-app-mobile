import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/core/messaging/app_messenger.dart';
import 'package:flutter/services.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/desktop/desktop_prefs.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/offline_invoice_queue.dart';
import '../../data/local/product_local_dao.dart';
import '../../data/models/invoice.dart';
import 'package:uuid/uuid.dart';

/// Payment-first checkout: invoice is created only when payment is confirmed.
Future<bool> showPosCheckoutDialog({
  required BuildContext context,
  required AppServices services,
  required AuthSession auth,
  required Map<String, dynamic> invoicePayload,
  required double grandTotal,
  required List<InvoiceItem> printItems,
  required bool isOnline,
  OfflineInvoiceQueue? offlineQueue,
  ProductLocalDao? productDao,
  int? branchId,
  String? customerPhone,
}) async {
  final phoneController = TextEditingController(text: customerPhone ?? '');
  final paidController = TextEditingController(text: grandTotal.toStringAsFixed(2));
  final upiRefController = TextEditingController();

  Invoice? activeInvoice;
  String paymentMode = 'cash';
  bool paymentSaved = false;
  bool recordingPayment = false;
  bool sending = false;
  var completed = false;

  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final screenHeight = MediaQuery.sizeOf(dialogContext).height;
        final largeUi = AppConfig.usesLargeUiScale;
        final dialogWidth = AppConfig.posCheckoutDialogWidth(screenWidth);
        final horizontalInset = math.max(16.0, (screenWidth - dialogWidth) / 2);

        return StatefulBuilder(
          builder: (context, setState) {
            final hPad = largeUi ? 32.0 : 24.0;
            final vPad = largeUi ? 28.0 : 24.0;
            final sectionGap = largeUi ? 24.0 : 16.0;

            double alertFs(double base) => largeUi ? base + 5 : base;
            double alertIc(double base) =>
                largeUi ? base * AppConfig.desktopIconScale : base;

            double billDue() {
              if (activeInvoice != null) {
                return activeInvoice!.dueAmount > 0
                    ? activeInvoice!.dueAmount
                    : activeInvoice!.totalAmount;
              }
              return grandTotal;
            }

            double tenderedAmount() =>
                double.tryParse(paidController.text.trim()) ?? 0;

            double paymentAmount() {
              final due = billDue();
              if (paymentMode == 'upi') return due;
              final tendered = tenderedAmount();
              if (tendered <= 0) return 0;
              return tendered >= due ? due : tendered;
            }

            double changeReturn() {
              if (paymentMode != 'cash') return 0;
              final tendered = tenderedAmount();
              final due = billDue();
              return tendered > due ? tendered - due : 0;
            }

            double balanceDue() {
              if (paymentMode != 'cash') return 0;
              final tendered = tenderedAmount();
              final due = billDue();
              return tendered < due ? due - tendered : 0;
            }

            Future<void> maybeAutoPrintReceipt() async {
              if (!paymentSaved || activeInvoice == null || printItems.isEmpty) {
                return;
              }
              final autoPrint = await DesktopPrefs.getAutoPrintReceipt();
              if (!autoPrint) return;
              await ThermalPrinterService.printReceipt(
                invoice: activeInvoice!,
                items: printItems,
                shopName: auth.currentShop?.name ?? auth.currentBranch?.name,
              );
            }

            Future<void> confirmCheckout() async {
              if (recordingPayment || paymentSaved) return;
              final amount = paymentAmount();
              if (amount <= 0) {
                AppMessenger.show(context,
                  const SnackBar(content: Text('Enter a valid payment amount')),
                );
                return;
              }
              setState(() => recordingPayment = true);
              try {
                final payload = Map<String, dynamic>.from(invoicePayload);
                payload['payments'] = [
                  {
                    'mode': paymentMode,
                    'amount': amount,
                    if (paymentMode == 'upi' &&
                        upiRefController.text.trim().isNotEmpty)
                      'reference': upiRefController.text.trim(),
                  },
                ];

                if (isOnline) {
                  final created = await services.billing.create(payload);
                  if (!context.mounted) return;
                  activeInvoice = created;
                  paymentSaved = created.dueAmount <= 0.009;
                } else {
                  const uuid = Uuid();
                  final offlineId = uuid.v4();
                  payload['offline_id'] = offlineId;
                  await offlineQueue?.enqueue(offlineId, payload);
                  if (branchId != null && productDao != null) {
                    for (final item in printItems) {
                      await productDao.adjustStock(
                        branchId,
                        item.productId,
                        -item.quantity,
                      );
                    }
                  }
                  if (!context.mounted) return;
                  activeInvoice = Invoice(
                    id: 0,
                    invoiceNumber: 'OFFLINE',
                    type: payload['type']?.toString() ?? 'tax_invoice',
                    status: 'paid',
                    invoiceDate: payload['invoice_date']?.toString() ??
                        DateTime.now().toIso8601String().substring(0, 10),
                    totalAmount: grandTotal,
                    paidAmount: amount,
                    dueAmount: 0,
                    offlineId: offlineId,
                    items: printItems,
                  );
                  paymentSaved = true;
                }

                if (!context.mounted) return;
                setState(() {});
                await maybeAutoPrintReceipt();
                if (!context.mounted) return;
                AppMessenger.show(context,
                  SnackBar(
                    content: Text(
                      isOnline
                          ? 'Invoice ${activeInvoice!.invoiceNumber} created & paid'
                          : 'Saved offline — will sync when online',
                    ),
                    backgroundColor: AppTheme.accent,
                  ),
                );
              } catch (e) {
                if (context.mounted) {
                  AppMessenger.show(context,
                    SnackBar(
                      content: Text('Checkout failed: $e'),
                      backgroundColor: AppTheme.danger,
                    ),
                  );
                }
              } finally {
                if (context.mounted) setState(() => recordingPayment = false);
              }
            }

            void closeAndNewBill() {
              if (!paymentSaved) return;
              completed = true;
              Navigator.of(dialogContext).pop();
            }

            void handleEscape() {
              if (paymentSaved) {
                closeAndNewBill();
              } else {
                Navigator.of(dialogContext).pop();
              }
            }

            Widget payModeTile(String mode, String label, IconData icon) {
              final selected = paymentMode == mode;
              return Expanded(
                child: Material(
                  color: selected
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: paymentSaved
                        ? null
                        : () => setState(() {
                              paymentMode = mode;
                              if (mode == 'cash') {
                                paidController.text =
                                    billDue().toStringAsFixed(2);
                              }
                            }),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: largeUi ? 18 : 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : const Color(0xFFE2E8F0),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: alertIc(26),
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          SizedBox(height: largeUi ? 8 : 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: alertFs(15),
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            Widget paymentSummaryRow(
              String label,
              String value, {
              Color? valueColor,
              FontWeight valueWeight = FontWeight.w700,
              double? valueSize,
            }) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: largeUi ? 6 : 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: alertFs(14),
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: valueSize ?? alertFs(17),
                        fontWeight: valueWeight,
                        color: valueColor ?? AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget buildPaymentSummary() {
              final due = billDue();
              final tendered = paymentMode == 'cash' ? tenderedAmount() : due;
              final change = changeReturn();
              final balance = balanceDue();
              final isChange = paymentMode == 'cash' && change > 0;
              final isBalance =
                  paymentMode == 'cash' && balance > 0 && !paymentSaved;

              return Container(
                padding: EdgeInsets.all(largeUi ? 20 : 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    paymentSummaryRow(
                      'Bill Total',
                      '₹${due.toStringAsFixed(2)}',
                      valueColor: AppTheme.primary,
                      valueWeight: FontWeight.w800,
                      valueSize: alertFs(18),
                    ),
                    paymentSummaryRow(
                      'Paid by Customer',
                      '₹${tendered.toStringAsFixed(2)}',
                    ),
                    if (paymentMode == 'cash') ...[
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                      paymentSummaryRow(
                        isChange
                            ? 'Change to Return'
                            : isBalance
                                ? 'Balance Due'
                                : 'Change / Balance',
                        isChange
                            ? '₹${change.toStringAsFixed(2)}'
                            : isBalance
                                ? '₹${balance.toStringAsFixed(2)}'
                                : '₹0.00',
                        valueColor: isChange
                            ? AppTheme.accent
                            : isBalance
                                ? AppTheme.warning
                                : AppTheme.textSecondary,
                        valueWeight: FontWeight.w900,
                        valueSize: alertFs(20),
                      ),
                    ],
                  ],
                ),
              );
            }

            Widget buildInvoiceCard() {
              final invoice = activeInvoice;
              final total = invoice?.totalAmount ?? grandTotal;
              final invoiceNo = invoice?.invoiceNumber ?? 'Pending payment';
              return Container(
                padding: EdgeInsets.all(largeUi ? 24 : 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.06),
                      AppTheme.accent.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: largeUi
                    ? Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invoice No.',
                                  style: TextStyle(
                                    fontSize: alertFs(13),
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  invoiceNo,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: alertFs(18),
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (invoice != null && invoice.paidAmount > 0) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'Paid: ₹${invoice.paidAmount.toStringAsFixed(2)} · Due: ₹${invoice.dueAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: alertFs(13),
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: alertFs(13),
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: alertFs(28),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Text(
                            invoice != null
                                ? 'Invoice No: $invoiceNo'
                                : 'Bill Total',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: alertFs(14),
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: alertFs(20),
                            ),
                          ),
                          if (invoice != null && invoice.paidAmount > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Paid: ₹${invoice.paidAmount.toStringAsFixed(2)} · Due: ₹${invoice.dueAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: alertFs(13),
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
              );
            }

            Widget buildPaymentFields() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: alertFs(15),
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: largeUi ? 14 : 10),
                  Row(
                    children: [
                      payModeTile('cash', 'Cash', Icons.payments_outlined),
                      SizedBox(width: largeUi ? 14 : 10),
                      payModeTile('upi', 'UPI', Icons.qr_code_2_rounded),
                    ],
                  ),
                  if (largeUi)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'F2 Cash · F3 UPI · Ctrl+Enter confirm',
                        style: TextStyle(fontSize: alertFs(11), color: AppTheme.textSecondary),
                      ),
                    ),
                  SizedBox(height: largeUi ? 18 : 14),
                  if (paymentMode == 'cash') ...[
                    TextField(
                      controller: paidController,
                      enabled: !paymentSaved,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontSize: alertFs(16),
                        fontWeight: FontWeight.w600,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Amount Paid (₹)',
                        labelStyle: TextStyle(fontSize: alertFs(14)),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(
                          Icons.currency_rupee_rounded,
                          size: alertIc(22),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: largeUi ? 18 : 14,
                          vertical: largeUi ? 20 : 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: largeUi ? 14 : 10),
                    buildPaymentSummary(),
                  ] else ...[
                    Container(
                      padding: EdgeInsets.all(largeUi ? 16 : 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'UPI Amount: ₹${billDue().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: alertFs(16),
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    SizedBox(height: largeUi ? 14 : 10),
                    TextField(
                      controller: upiRefController,
                      enabled: !paymentSaved,
                      style: TextStyle(fontSize: alertFs(14)),
                      decoration: InputDecoration(
                        labelText: 'UPI Reference (optional)',
                        labelStyle: TextStyle(fontSize: alertFs(14)),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.tag_rounded, size: alertIc(20)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: largeUi ? 14 : 10),
                    buildPaymentSummary(),
                  ],
                  SizedBox(height: largeUi ? 20 : 14),
                  if (!paymentSaved)
                    SizedBox(
                      width: double.infinity,
                      height: largeUi ? 54 : 46,
                      child: ElevatedButton.icon(
                        onPressed: recordingPayment ? null : confirmCheckout,
                        icon: recordingPayment
                            ? SizedBox(
                                width: alertIc(18),
                                height: alertIc(18),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.verified_rounded, size: alertIc(22)),
                        label: Text(
                          recordingPayment ? 'Saving…' : 'Confirm Payment',
                          style: TextStyle(
                            fontSize: alertFs(16),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }

            Widget buildWhatsAppButton() {
              if (sending) {
                return const Center(child: CircularProgressIndicator());
              }
              return SizedBox(
                width: double.infinity,
                height: largeUi ? 50 : 44,
                child: ElevatedButton.icon(
                  onPressed: paymentSaved &&
                          activeInvoice != null &&
                          activeInvoice!.id > 0
                      ? () async {
                    final phone = phoneController.text.trim();
                    if (phone.isEmpty) {
                      AppMessenger.show(context,
                        const SnackBar(
                          content: Text('Please enter a phone number'),
                        ),
                      );
                      return;
                    }
                    setState(() => sending = true);
                    try {
                      final res = await services.billing.sendWhatsApp(
                        activeInvoice!.id,
                        phone: phone,
                      );
                      if (context.mounted) {
                        AppMessenger.show(context,
                          SnackBar(
                            content: Text(
                              res
                                  ? 'WhatsApp invoice sent!'
                                  : 'Failed to send WhatsApp.',
                            ),
                            backgroundColor:
                                res ? AppTheme.accent : AppTheme.danger,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppMessenger.show(context,
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: AppTheme.danger,
                          ),
                        );
                      }
                    } finally {
                      if (context.mounted) setState(() => sending = false);
                    }
                  }
                      : null,
                  icon: Icon(Icons.send_rounded, size: alertIc(20)),
                  label: Text(
                    'Send WhatsApp Invoice',
                    style: TextStyle(
                      fontSize: alertFs(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              );
            }

            Widget buildReceiptSection() {
              return Opacity(
                opacity: paymentSaved ? 1 : 0.45,
                child: IgnorePointer(
                  ignoring: !paymentSaved,
                  child: Container(
                padding: EdgeInsets.all(largeUi ? 22 : 0),
                decoration: largeUi
                    ? BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (largeUi)
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: alertIc(22),
                            color: paymentSaved
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Receipt & Share',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: alertFs(16),
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (!paymentSaved)
                            Icon(
                              Icons.lock_outline_rounded,
                              size: alertIc(18),
                              color: AppTheme.textSecondary,
                            ),
                        ],
                      )
                    else
                      Text(
                        'WhatsApp Receipt',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: alertFs(14),
                        ),
                      ),
                    if (!paymentSaved) ...[
                      SizedBox(height: largeUi ? 10 : 6),
                      Text(
                        'Confirm payment to unlock receipt & share',
                        style: TextStyle(
                          fontSize: alertFs(12),
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    SizedBox(height: largeUi ? 16 : 8),
                    TextField(
                      controller: phoneController,
                      enabled: paymentSaved,
                      style: TextStyle(fontSize: alertFs(14)),
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter 10-digit number',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(
                          Icons.phone_iphone_rounded,
                          color: AppTheme.textSecondary,
                          size: alertIc(22),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: largeUi ? 16 : 14,
                          vertical: largeUi ? 16 : 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: largeUi ? 14 : 12),
                    buildWhatsAppButton(),
                    SizedBox(height: largeUi ? 14 : 12),
                    if (largeUi)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: !paymentSaved ||
                                      printItems.isEmpty ||
                                      activeInvoice == null
                                  ? null
                                  : () async {
                                      final invoice = activeInvoice!;
                                      final ok =
                                          await ThermalPrinterService
                                              .printReceipt(
                                        invoice: invoice,
                                        items: printItems,
                                        shopName: auth.currentShop?.name ??
                                            auth.currentBranch?.name,
                                      );
                                      if (context.mounted) {
                                        AppMessenger.show(
                                          context,
                                          SnackBar(
                                            content: Text(
                                              ok
                                                  ? 'Print dialog opened'
                                                  : 'Print failed',
                                            ),
                                            backgroundColor: ok
                                                ? AppTheme.accent
                                                : AppTheme.danger,
                                          ),
                                        );
                                      }
                                    },
                              icon: Icon(Icons.print_rounded, size: alertIc(18)),
                              label: Text(
                                'Print',
                                style: TextStyle(fontSize: alertFs(14)),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size(0, largeUi ? 48 : 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: !paymentSaved ||
                                      activeInvoice?.shareToken == null
                                  ? null
                                  : () async {
                                final shareUrl =
                                    'http://localhost:8001/share/invoice/${activeInvoice!.shareToken}';
                                await Clipboard.setData(
                                  ClipboardData(text: shareUrl),
                                );
                                if (context.mounted) {
                                  AppMessenger.show(context,
                                    const SnackBar(
                                      content: Text('Invoice link copied!'),
                                      backgroundColor: AppTheme.primary,
                                    ),
                                  );
                                }
                              },
                              icon: Icon(Icons.copy_rounded, size: alertIc(18)),
                              label: Text(
                                'Copy Link',
                                style: TextStyle(fontSize: alertFs(14)),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size(0, largeUi ? 48 : 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      OutlinedButton.icon(
                        onPressed: !paymentSaved ||
                                printItems.isEmpty ||
                                activeInvoice == null
                            ? null
                            : () async {
                                final invoice = activeInvoice!;
                                final ok =
                                    await ThermalPrinterService.printReceipt(
                                  invoice: invoice,
                                  items: printItems,
                                  shopName: auth.currentShop?.name ??
                                      auth.currentBranch?.name,
                                );
                                if (context.mounted) {
                                  AppMessenger.show(context,
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Print dialog opened'
                                            : 'Print failed',
                                      ),
                                      backgroundColor: ok
                                          ? AppTheme.accent
                                          : AppTheme.danger,
                                    ),
                                  );
                                }
                              },
                        icon: Icon(Icons.print_rounded, size: alertIc(18)),
                        label: Text(
                          'Print Receipt',
                          style: TextStyle(fontSize: alertFs(14)),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, largeUi ? 50 : 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: !paymentSaved ||
                                activeInvoice?.shareToken == null
                            ? null
                            : () async {
                          final shareUrl =
                              'http://localhost:8001/share/invoice/${activeInvoice!.shareToken}';
                          await Clipboard.setData(
                            ClipboardData(text: shareUrl),
                          );
                          if (context.mounted) {
                            AppMessenger.show(context,
                              const SnackBar(
                                content: Text('Invoice link copied!'),
                                backgroundColor: AppTheme.primary,
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.copy_rounded, size: alertIc(18)),
                        label: Text(
                          'Copy Bill Share Link',
                          style: TextStyle(fontSize: alertFs(14)),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, largeUi ? 50 : 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                  ),
                ),
              );
            }

            Widget buildBody() {
              if (largeUi) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 11,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Text(
                          //   'Invoice Created Successfully!',
                          //   style: TextStyle(
                          //     color: AppTheme.accent,
                          //     fontWeight: FontWeight.w700,
                          //     fontSize: alertFs(17),
                          //   ),
                          // ),
                          SizedBox(height: sectionGap),
                          buildInvoiceCard(),
                          SizedBox(height: sectionGap),
                          buildPaymentFields(),
                        ],
                      ),
                    ),
                    SizedBox(width: sectionGap),
                    Expanded(
                      flex: 9,
                      child: buildReceiptSection(),
                    ),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    paymentSaved
                        ? 'Invoice created successfully!'
                        : 'Review bill and confirm payment',
                    style: TextStyle(
                      color: paymentSaved ? AppTheme.accent : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: alertFs(16),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: sectionGap),
                  buildInvoiceCard(),
                  SizedBox(height: sectionGap),
                  buildPaymentFields(),
                  SizedBox(height: sectionGap),
                  const Divider(color: Color(0xFFE2E8F0)),
                  SizedBox(height: sectionGap),
                  buildReceiptSection(),
                ],
              );
            }

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) handleEscape();
              },
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.keyD, control: true):
                      closeAndNewBill,
                  const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
                    if (!paymentSaved && !recordingPayment) {
                      confirmCheckout();
                    }
                  },
                  const SingleActivator(LogicalKeyboardKey.f2): () {
                    if (!paymentSaved) {
                      setState(() {
                        paymentMode = 'cash';
                        paidController.text = billDue().toStringAsFixed(2);
                      });
                    }
                  },
                  const SingleActivator(LogicalKeyboardKey.f3): () {
                    if (!paymentSaved) {
                      setState(() => paymentMode = 'upi');
                    }
                  },
                },
                child: Focus(
                  autofocus: true,
                  child: Theme(
              data: Theme.of(context).copyWith(
                dialogTheme: DialogThemeData(
                  constraints: BoxConstraints(
                    minWidth: dialogWidth,
                    maxWidth: dialogWidth,
                    maxHeight: screenHeight * 0.92,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              child: Dialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                clipBehavior: Clip.antiAlias,
                insetPadding: EdgeInsets.symmetric(
                  horizontal: horizontalInset,
                  vertical: largeUi ? 36 : 24,
                ),
                child: SizedBox(
                  width: dialogWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: const Color(0xFFE2E8F0),
                            width: largeUi ? 1.5 : 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(largeUi ? 12 : 8),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              paymentSaved
                                  ? Icons.check_circle_rounded
                                  : Icons.point_of_sale_rounded,
                              color: paymentSaved
                                  ? AppTheme.accent
                                  : AppTheme.primary,
                              size: alertIc(30),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  paymentSaved
                                      ? 'Checkout Success'
                                      : 'Checkout',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: alertFs(22),
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (largeUi)
                                  Text(
                                    paymentSaved
                                        ? 'Send receipt or start a new bill'
                                        : 'Confirm payment to generate invoice',
                                    style: TextStyle(
                                      fontSize: alertFs(13),
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (paymentSaved)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Paid',
                                style: TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: alertFs(13),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(hPad),
                        child: buildBody(),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, vPad),
                      child: SizedBox(
                        width: double.infinity,
                        height: largeUi ? 50 : 44,
                        child: OutlinedButton(
                          onPressed: paymentSaved ? closeAndNewBill : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            disabledForegroundColor: AppTheme.textSecondary,
                            side: BorderSide(
                              color: paymentSaved
                                  ? AppTheme.primary
                                  : const Color(0xFFE2E8F0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                paymentSaved
                                    ? 'Close & New Bill'
                                    : 'Confirm payment to continue',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: alertFs(15),
                                ),
                              ),
                              if (largeUi && paymentSaved) ...[
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppTheme.primary.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Text(
                                    'Ctrl+D',
                                    style: TextStyle(
                                      fontSize: alertFs(11),
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
          },
        );
      },
    );
    return completed;
  } finally {
    phoneController.dispose();
    paidController.dispose();
    upiRefController.dispose();
  }
}
