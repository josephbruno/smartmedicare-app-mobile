import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:flutter/services.dart';

import '../../app_services.dart';
import '../../core/app_config.dart';
import '../../core/desktop/desktop_prefs.dart';
import '../../core/services/receipt_branch_store.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/offline_invoice_queue.dart';
import '../../data/local/product_local_dao.dart';
import '../../data/models/customer.dart';
import '../../data/models/invoice.dart';
import '../../data/models/shop.dart';
import 'package:uuid/uuid.dart';

/// Payment-first checkout: invoice is created only when payment is confirmed.
/// Fully paid bills print and close immediately. Split/partial payments stay open
/// until the remaining balance is collected.
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
  Customer? customer,
}) async {
  Customer? billingCustomer = customer;
  final paidController = TextEditingController(text: grandTotal.toStringAsFixed(2));
  final upiRefController = TextEditingController();
  final loyaltyController = TextEditingController();

  Invoice? activeInvoice;
  String paymentMode = 'cash';
  bool paymentSaved = false;
  bool recordingPayment = false;
  bool applyAdvance = (billingCustomer?.advanceBalance ?? 0) > 0;
  var completed = false;

  // Shop loyalty rates for redeem value preview (defaults match backend).
  var redeemPerPoint = 0.25;
  var minRedeemPoints = 100;
  var maxRedeemPercent = 10.0;

  // Refresh balances (loyalty / advance) so redeem UI has current values.
  if (isOnline && billingCustomer != null && billingCustomer.id > 0) {
    try {
      final fresh = await services.customers.get(billingCustomer.id);
      billingCustomer = fresh;
      applyAdvance = fresh.advanceBalance > 0;
    } catch (_) {}
  }
  if (isOnline) {
    try {
      final shop = await services.shop.get();
      final s = shop.settings ?? ShopSettings();
      redeemPerPoint = s.loyaltyRedeemPerPoint > 0 ? s.loyaltyRedeemPerPoint : 0.25;
      minRedeemPoints = s.loyaltyRedemptionMinPoints;
      maxRedeemPercent = s.loyaltyMaxRedeemPercent;
    } catch (_) {}
  }

  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final largeUi = AppConfig.usesLargeUiScale;

        return StatefulBuilder(
          builder: (context, setState) {
            // Compact payment dialog (receipt/share UI removed — print on settle).
            final dialogWidth = !largeUi
                ? 360.0
                : (screenWidth * 0.42).clamp(420.0, 520.0);
            final horizontalInset = math.max(16.0, (screenWidth - dialogWidth) / 2);
            final hPad = largeUi ? 14.0 : 12.0;
            final vPad = largeUi ? 10.0 : 8.0;
            final sectionGap = largeUi ? 8.0 : 6.0;

            double alertFs(double base) => largeUi ? base - 1 : base;
            double alertIc(double base) => largeUi ? base * 1.1 : base;

            double billGross() {
              if (activeInvoice != null) {
                return activeInvoice!.totalAmount;
              }
              return grandTotal;
            }

            bool hasRegisteredCustomer() =>
                billingCustomer != null && billingCustomer!.id > 0;

            int loyaltyPtsRequested() {
              if (!hasRegisteredCustomer()) return 0;
              return int.tryParse(loyaltyController.text.trim()) ?? 0;
            }

            /// Max points that can be redeemed on this bill (balance + max %).
            int maxRedeemablePoints() {
              if (!hasRegisteredCustomer()) return 0;
              final available = billingCustomer!.loyaltyPoints;
              if (available <= 0 || redeemPerPoint <= 0) return 0;
              final maxValue = billGross() * (maxRedeemPercent / 100);
              final byPercent = maxValue > 0
                  ? (maxValue / redeemPerPoint).floor()
                  : 0;
              return math.min(available, byPercent);
            }

            /// ₹ value applied when redeeming the entered points.
            double loyaltyRedeemValue() {
              final pts = loyaltyPtsRequested();
              if (pts <= 0 || redeemPerPoint <= 0) return 0;
              if (pts < minRedeemPoints) return 0;
              final cappedPts = math.min(pts, maxRedeemablePoints());
              if (cappedPts <= 0) return 0;
              final value = cappedPts * redeemPerPoint;
              return math.min(value, billGross());
            }

            /// Advance that will auto-apply against remaining after loyalty.
            double advanceApplyValue() {
              if (!hasRegisteredCustomer()) return 0;
              if (!applyAdvance || paymentMode == 'advance') return 0;
              final avail = billingCustomer?.advanceBalance ?? 0;
              if (avail <= 0) return 0;
              final remaining = math.max(0.0, billGross() - loyaltyRedeemValue());
              return math.min(avail, remaining);
            }

            double billDue() {
              if (activeInvoice != null) {
                return activeInvoice!.dueAmount > 0
                    ? activeInvoice!.dueAmount
                    : activeInvoice!.totalAmount;
              }
              // Preview credits before invoice is created.
              return math.max(
                0.0,
                billGross() - loyaltyRedeemValue() - advanceApplyValue(),
              );
            }

            bool hasOpenBalance() =>
                activeInvoice != null &&
                activeInvoice!.id > 0 &&
                activeInvoice!.dueAmount > 0.009;

            bool lockPaymentInputs() => paymentSaved && !hasOpenBalance();

            void syncPaidToDue() {
              if (lockPaymentInputs() || paymentMode != 'cash') return;
              paidController.text = billDue().toStringAsFixed(2);
            }

            double tenderedAmount() =>
                double.tryParse(paidController.text.trim()) ?? 0;

            double paymentAmount() {
              final due = billDue();
              if (paymentMode == 'upi' ||
                  paymentMode == 'card' ||
                  paymentMode == 'credit') {
                return due;
              }
              if (paymentMode == 'advance') {
                final avail = billingCustomer?.advanceBalance ?? 0;
                final afterLoyalty =
                    math.max(0.0, billGross() - loyaltyRedeemValue());
                final need = math.min(afterLoyalty, avail);
                return avail >= need ? need : avail;
              }
              final tendered = tenderedAmount();
              if (tendered <= 0) return 0;
              return tendered >= due ? due : tendered;
            }

            double changeReturn() {
              if (paymentMode != 'cash') return 0;
              final tendered = tenderedAmount();
              final due = billDue();
              // Change only when cash tendered exceeds the amount still due.
              if (tendered <= due + 0.009) return 0;
              return tendered - due;
            }

            double balanceDue() {
              // Partial cash payment leaves a balance that can be collected next
              // (UPI/card) in the same checkout — walk-in and registered alike.
              if (paymentMode != 'cash') return 0;
              final tendered = tenderedAmount();
              final due = billDue();
              if (tendered <= 0 || tendered + 0.009 >= due) return 0;
              return due - tendered;
            }

            String? creditLimitWarning() {
              if (!hasRegisteredCustomer()) return null;
              final limit = billingCustomer!.creditLimit ?? 0;
              if (limit <= 0) return null;
              final outstanding = billingCustomer!.outstandingBalance ?? 0;
              final unpaid = paymentMode == 'credit'
                  ? billDue()
                  : (paymentMode == 'cash'
                      ? balanceDue()
                      : (paymentAmount() < billDue()
                          ? billDue() - paymentAmount()
                          : 0));
              final projected = outstanding + unpaid;
              if (projected > limit) {
                return 'Credit limit ₹${limit.toStringAsFixed(0)} exceeded '
                    '(would be ₹${projected.toStringAsFixed(0)}). Collect payment or raise limit.';
              }
              if (projected > limit * 0.8) {
                return 'Approaching credit limit ₹${limit.toStringAsFixed(0)} '
                    '(outstanding will be ₹${projected.toStringAsFixed(0)}).';
              }
              return null;
            }

            Future<void> printReceiptNow() async {
              if (activeInvoice == null || printItems.isEmpty) return;
              final invoice = activeInvoice!;
              final header = await ReceiptBranchStore.resolveForPrint(auth);
              // Checkout: if USB printer is connected, print silently; otherwise
              // skip and continue — never open the system PDF dialog (blocks Saving…).
              await ThermalPrinterService.printReceipt(
                invoice: invoice,
                items: printItems,
                shopName: header.name,
                companyName: header.shopName,
                shopPhone: header.phone,
                shopGstin: header.gstin,
                shopAddress: header.address,
                billerName: auth.user?.name,
                allowSystemDialog: false,
              );
            }

            void _showRootSnack(String message, {Color? backgroundColor}) {
              // Never attach snackbars to the dialog context — popping the route
              // while MediaQuery dependents remain causes `_dependents.isEmpty`.
              final messenger = AppMessenger.rootKey.currentState;
              if (messenger == null) return;
              final rootCtx = AppMessenger.rootKey.currentContext;
              final bar = SnackBar(
                content: Text(message),
                backgroundColor: backgroundColor ?? AppTheme.accent,
                behavior: SnackBarBehavior.floating,
              );
              if (rootCtx != null && rootCtx.mounted) {
                AppMessenger.show(rootCtx, bar);
              } else {
                messenger.showSnackBar(bar);
              }
            }

            /// Fully paid / credit done → print & close. Split balance → stay open.
            Future<void> finishOrContinueSplit({required String successMessage}) async {
              if (!context.mounted) return;
              final dueLeft = activeInvoice?.dueAmount ?? 0;
              final isSplitPending =
                  dueLeft > 0.009 && paymentMode != 'credit';

              if (isSplitPending) {
                setState(() => recordingPayment = false);
                _showRootSnack(successMessage);
                return;
              }

              completed = true;
              // Close checkout first so "Saving…" never sticks on the printer.
              // If a USB printer is connected, print in the background; otherwise skip.
              final autoPrint = await DesktopPrefs.getAutoPrintReceipt();
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showRootSnack(successMessage);
              });
              if (autoPrint) {
                unawaited(printReceiptNow());
              }
            }

            Future<void> confirmCheckout() async {
              if (recordingPayment) return;
              // Fully settled invoices cannot take another payment here.
              if (paymentSaved &&
                  activeInvoice != null &&
                  activeInvoice!.dueAmount <= 0.009) {
                return;
              }

              // Credit / advance / loyalty redeem require a registered customer.
              // Walk-in may leave a cash balance due and collect the rest via UPI/card.
              if (!hasRegisteredCustomer()) {
                if (paymentMode == 'credit' || paymentMode == 'advance') {
                  AppMessenger.show(context,
                    const SnackBar(
                      content: Text(
                        'Select a registered customer for credit or advance payment',
                      ),
                    ),
                  );
                  return;
                }
                final loyaltyAttempt =
                    int.tryParse(loyaltyController.text.trim()) ?? 0;
                if (loyaltyAttempt > 0) {
                  AppMessenger.show(context,
                    const SnackBar(
                      content: Text(
                        'Select a registered customer to redeem loyalty points',
                      ),
                    ),
                  );
                  return;
                }
              }

              final warn = creditLimitWarning();
              if (warn != null && warn.contains('exceeded')) {
                AppMessenger.show(context,
                  SnackBar(content: Text(warn), backgroundColor: AppTheme.danger),
                );
                return;
              }
              if (paymentMode == 'advance' &&
                  (billingCustomer?.advanceBalance ?? 0) <= 0) {
                AppMessenger.show(context,
                  const SnackBar(content: Text('No advance balance available')),
                );
                return;
              }
              final loyaltyPtsRaw = hasRegisteredCustomer()
                  ? (int.tryParse(loyaltyController.text.trim()) ?? 0)
                  : 0;
              if (loyaltyPtsRaw > 0 && loyaltyPtsRaw < minRedeemPoints) {
                AppMessenger.show(context,
                  SnackBar(
                    content: Text(
                      'Minimum $minRedeemPoints loyalty points required to redeem',
                    ),
                  ),
                );
                return;
              }
              final loyaltyPts = loyaltyPtsRaw > 0
                  ? math.min(loyaltyPtsRaw, maxRedeemablePoints())
                  : 0;

              // Remaining cash due after loyalty/advance preview (create) or
              // invoice balance (follow-up payment on partial invoice).
              final dueBeforePay = billDue();

              // Capture cash tendered BEFORE any sync — syncPaidToDue() would
              // overwrite overpayments (e.g. ₹50 on a ₹17 bill) and drop change.
              final cashTendered =
                  paymentMode == 'cash' ? tenderedAmount() : null;
              if (paymentMode == 'cash' &&
                  (cashTendered == null || cashTendered <= 0)) {
                syncPaidToDue();
              }
              final amount = paymentAmount();
              final advanceCredit = advanceApplyValue();
              if (paymentMode != 'credit' &&
                  amount <= 0 &&
                  loyaltyPts <= 0 &&
                  advanceCredit <= 0) {
                AppMessenger.show(context,
                  const SnackBar(content: Text('Enter a valid payment amount')),
                );
                return;
              }

              // True overpay: customer handed more cash than the due being settled.
              // Never attach tendered_amount on partial pays — that created fake
              // "change" when a follow-up confirm reused the previous due.
              final tenderedToSave = paymentMode == 'cash' &&
                      cashTendered != null &&
                      cashTendered > dueBeforePay + 0.009
                  ? cashTendered
                  : null;

              setState(() => recordingPayment = true);
              try {
                // Follow-up payment on an already-created invoice (partial / credit).
                // Never create a second invoice from the same checkout session.
                if (activeInvoice != null && activeInvoice!.id > 0) {
                  if (paymentMode == 'credit' || paymentMode == 'advance') {
                    AppMessenger.show(context,
                      SnackBar(
                        content: Text(
                          paymentMode == 'credit'
                              ? 'Switch to Cash or UPI to collect the remaining balance.'
                              : 'Use cash/UPI to collect the remaining balance on this invoice.',
                        ),
                      ),
                    );
                    return;
                  }
                  if (amount <= 0.009) {
                    AppMessenger.show(context,
                      const SnackBar(content: Text('Enter a valid payment amount')),
                    );
                    return;
                  }
                  final updated = await services.billing.recordPayment(
                    activeInvoice!.id,
                    mode: paymentMode,
                    amount: amount,
                    tenderedAmount: tenderedToSave,
                    reference: (paymentMode == 'upi' || paymentMode == 'card') &&
                            upiRefController.text.trim().isNotEmpty
                        ? upiRefController.text.trim()
                        : null,
                  );
                  if (!context.mounted) return;
                  activeInvoice = updated;
                  paymentSaved = true;
                  if (updated.dueAmount > 0.009 && paymentMode == 'cash') {
                    paidController.text = updated.dueAmount.toStringAsFixed(2);
                  }
                  await finishOrContinueSplit(
                    successMessage: updated.dueAmount > 0.009
                        ? 'Payment recorded. Balance due ₹${updated.dueAmount.toStringAsFixed(2)} — collect remaining'
                        : 'Payment recorded. Invoice fully paid',
                  );
                  return;
                }

                final payload = Map<String, dynamic>.from(invoicePayload);
                if (loyaltyPts > 0) {
                  payload['loyalty_points_redeemed'] = loyaltyPts;
                }
                // Auto-apply remaining advance for visit invoices unless paying purely by advance
                if (applyAdvance &&
                    paymentMode != 'advance' &&
                    (billingCustomer?.advanceBalance ?? 0) > 0) {
                  payload['apply_advance'] = true;
                } else if (paymentMode == 'advance') {
                  payload['apply_advance'] = false;
                }

                final payments = <Map<String, dynamic>>[];
                if (paymentMode == 'advance') {
                  payments.add({'mode': 'advance', 'amount': amount});
                } else if (paymentMode == 'credit') {
                  // Leave unpaid — credit sale
                } else if (amount > 0.009) {
                  payments.add({
                    'mode': paymentMode,
                    'amount': amount,
                    if ((paymentMode == 'upi' || paymentMode == 'card') &&
                        upiRefController.text.trim().isNotEmpty)
                      'reference': upiRefController.text.trim(),
                    if (tenderedToSave != null) 'tendered_amount': tenderedToSave,
                  });
                }
                payload['payments'] = payments;

                if (isOnline) {
                  final created = await services.billing.create(payload);
                  if (!context.mounted) return;
                  activeInvoice = created;
                  // Invoice exists (paid or partial) — unlock receipt/share.
                  // Remaining due is collected via recordPayment, not a new create.
                  paymentSaved = true;
                  if (created.dueAmount > 0.009 && paymentMode == 'cash') {
                    paidController.text = created.dueAmount.toStringAsFixed(2);
                  }
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
                final dueLeft = activeInvoice?.dueAmount ?? 0;
                final invoiceNo = activeInvoice?.invoiceNumber ?? '';
                await finishOrContinueSplit(
                  successMessage: isOnline
                      ? (dueLeft > 0.009 && paymentMode != 'credit'
                          ? 'Invoice $invoiceNo created. Balance due ₹${dueLeft.toStringAsFixed(2)} — collect remaining'
                          : paymentMode == 'credit'
                              ? 'Invoice $invoiceNo created on credit'
                              : 'Invoice $invoiceNo created & paid')
                      : 'Saved offline — will sync when online',
                );
              } catch (e) {
                if (context.mounted) {
                  _showRootSnack(
                    'Checkout failed: $e',
                    backgroundColor: AppTheme.danger,
                  );
                }
              } finally {
                // Skip setState after a successful close — the dialog is gone.
                if (context.mounted && !completed) {
                  setState(() => recordingPayment = false);
                }
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
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: lockPaymentInputs()
                        ? null
                        : () => setState(() {
                              paymentMode = mode;
                              if (mode == 'cash') {
                                syncPaidToDue();
                              }
                            }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: largeUi ? 7 : 6,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : const Color(0xFFE2E8F0),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: alertIc(15),
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: alertFs(11),
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            Widget buildLoyaltyRedeemSection() {
              if (!hasRegisteredCustomer()) {
                return const SizedBox.shrink();
              }
              final pts = billingCustomer!.loyaltyPoints;
              // Hide empty loyalty card — fewer clicks / less noise at checkout.
              if (pts <= 0) return const SizedBox.shrink();

              final maxPts = maxRedeemablePoints();
              final redeemValue = loyaltyRedeemValue();
              final requested = loyaltyPtsRequested();
              final belowMin = requested > 0 && requested < minRedeemPoints;
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(largeUi ? 8 : 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.stars_rounded,
                            color: AppTheme.warning, size: alertIc(16)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Loyalty · $pts pts · ₹${redeemPerPoint.toStringAsFixed(2)}/pt'
                            '${maxPts < pts ? ' · max $maxPts' : ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: alertFs(11),
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (maxPts > 0)
                          TextButton(
                            onPressed: paymentSaved
                                ? null
                                : () {
                                    loyaltyController.text = '$maxPts';
                                    setState(() => syncPaidToDue());
                                  },
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              foregroundColor: AppTheme.warning,
                            ),
                            child: Text('Use all',
                                style: TextStyle(fontSize: alertFs(11))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: loyaltyController,
                      enabled: !paymentSaved,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => setState(() {
                        syncPaidToDue();
                      }),
                      style: TextStyle(fontSize: alertFs(12)),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Points to redeem',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    if (belowMin) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Minimum $minRedeemPoints points required',
                        style: TextStyle(
                          fontSize: alertFs(10),
                          fontWeight: FontWeight.w500,
                          color: AppTheme.danger,
                        ),
                      ),
                    ] else if (redeemValue > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Redeem −₹${redeemValue.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: alertFs(11),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ],
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
                padding: EdgeInsets.symmetric(vertical: largeUi ? 3 : 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: alertFs(13),
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: valueSize ?? alertFs(16),
                        fontWeight: valueWeight,
                        color: valueColor ?? AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget buildPaymentSummary() {
              final gross = billGross();
              final loyaltyValue = loyaltyRedeemValue();
              final advanceValue = advanceApplyValue();
              final due = billDue();
              final tendered = paymentMode == 'cash' ? tenderedAmount() : due;
              final change = changeReturn();
              final balance = balanceDue();
              final isChange = paymentMode == 'cash' && change > 0;
              final isBalance = paymentMode == 'cash' && balance > 0;

              return Container(
                padding: EdgeInsets.all(largeUi ? 12 : 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    paymentSummaryRow(
                      'Bill Total',
                      '₹${gross.toStringAsFixed(2)}',
                      valueColor: AppTheme.primary,
                      valueWeight: FontWeight.w800,
                      valueSize: alertFs(18),
                    ),
                    if (loyaltyValue > 0)
                      paymentSummaryRow(
                        'Loyalty Redeem',
                        '−₹${loyaltyValue.toStringAsFixed(2)}',
                        valueColor: AppTheme.accent,
                      ),
                    if (advanceValue > 0)
                      paymentSummaryRow(
                        'Advance Applied',
                        '−₹${advanceValue.toStringAsFixed(2)}',
                        valueColor: AppTheme.accent,
                      ),
                    if (loyaltyValue > 0 || advanceValue > 0)
                      paymentSummaryRow(
                        'Amount Due',
                        '₹${due.toStringAsFixed(2)}',
                        valueWeight: FontWeight.w800,
                      ),
                    paymentSummaryRow(
                      'Paid by Customer',
                      '₹${tendered.toStringAsFixed(2)}',
                    ),
                    if (paymentMode == 'cash') ...[
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
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
                      if (isBalance && !paymentSaved)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Confirm cash, then switch to UPI/Card to collect the remaining balance.',
                            style: TextStyle(
                              fontSize: alertFs(12),
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            }

            Widget buildInvoiceCard() {
              final invoice = activeInvoice;
              final total = invoice?.totalAmount ?? billDue();
              final invoiceNo = invoice?.invoiceNumber ?? 'Pending payment';
              final loyaltyValue =
                  invoice == null ? loyaltyRedeemValue() : 0.0;
              final advanceValue =
                  invoice == null ? advanceApplyValue() : 0.0;
              return Container(
                padding: EdgeInsets.all(largeUi ? 10 : 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.06),
                      AppTheme.accent.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
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
                                    fontSize: alertFs(10),
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  invoiceNo,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: alertFs(13),
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (invoice != null && invoice.paidAmount > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Paid: ₹${invoice.paidAmount.toStringAsFixed(2)} · Due: ₹${invoice.dueAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: alertFs(10),
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
                                  fontSize: alertFs(10),
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: alertFs(18),
                                ),
                              ),
                              if (loyaltyValue > 0 || advanceValue > 0)
                                Text(
                                  loyaltyValue > 0 && advanceValue > 0
                                      ? 'After loyalty & advance'
                                      : loyaltyValue > 0
                                          ? 'After loyalty redeem'
                                          : 'After advance',
                                  style: TextStyle(
                                    fontSize: alertFs(10),
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w500,
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
                          if (loyaltyValue > 0 || advanceValue > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              loyaltyValue > 0 && advanceValue > 0
                                  ? 'After loyalty & advance'
                                  : loyaltyValue > 0
                                      ? 'After loyalty redeem'
                                      : 'After advance',
                              style: TextStyle(
                                fontSize: alertFs(11),
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
              final registered = hasRegisteredCustomer();
              // Fall back if credit/advance was somehow selected without a customer.
              if (!registered &&
                  (paymentMode == 'credit' || paymentMode == 'advance')) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!paymentSaved) {
                    setState(() {
                      paymentMode = 'cash';
                      loyaltyController.clear();
                      syncPaidToDue();
                    });
                  }
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: alertFs(12),
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: largeUi ? 5 : 4),
                  Row(
                    children: [
                      payModeTile('cash', 'Cash', Icons.payments_outlined),
                      const SizedBox(width: 6),
                      payModeTile('upi', 'UPI', Icons.qr_code_2_rounded),
                      if (registered) ...[
                        const SizedBox(width: 6),
                        payModeTile('credit', 'Credit', Icons.schedule_outlined),
                      ],
                    ],
                  ),
                  if (registered &&
                      (billingCustomer?.advanceBalance ?? 0) > 0) ...[
                    SizedBox(height: largeUi ? 5 : 4),
                    Row(
                      children: [
                        payModeTile(
                          'advance',
                          'Advance ₹${billingCustomer!.advanceBalance.toStringAsFixed(0)}',
                          Icons.account_balance_wallet_outlined,
                        ),
                      ],
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                        'Also auto-apply advance on this bill',
                        style: TextStyle(fontSize: alertFs(11)),
                      ),
                      value: applyAdvance && paymentMode != 'advance',
                      onChanged: paymentSaved || paymentMode == 'advance'
                          ? null
                          : (v) => setState(() {
                                applyAdvance = v;
                                syncPaidToDue();
                              }),
                    ),
                  ],
                  if (registered) ...[
                    SizedBox(height: largeUi ? 5 : 4),
                    buildLoyaltyRedeemSection(),
                  ],
                  if (creditLimitWarning() != null) ...[
                    SizedBox(height: largeUi ? 5 : 4),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: creditLimitWarning()!.contains('exceeded')
                            ? AppTheme.danger.withValues(alpha: 0.1)
                            : AppTheme.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        creditLimitWarning()!,
                        style: TextStyle(
                          fontSize: alertFs(10),
                          color: creditLimitWarning()!.contains('exceeded')
                              ? AppTheme.danger
                              : AppTheme.warning,
                        ),
                      ),
                    ),
                  ],
                  if (largeUi)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'F2 Cash · F3 UPI · Ctrl+Enter confirm',
                        style: TextStyle(fontSize: alertFs(10), color: AppTheme.textSecondary),
                      ),
                    ),
                  SizedBox(height: largeUi ? 8 : 6),
                  if (paymentMode == 'cash') ...[
                    TextField(
                      controller: paidController,
                      enabled: !lockPaymentInputs(),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if ((!paymentSaved || hasOpenBalance()) && !recordingPayment) {
                          confirmCheckout();
                        }
                      },
                      style: TextStyle(
                        fontSize: alertFs(14),
                        fontWeight: FontWeight.w500,
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
                        isDense: true,
                        labelText: hasOpenBalance()
                            ? 'Pay remaining (₹)'
                            : 'Amount Paid (₹)',
                        labelStyle: TextStyle(fontSize: alertFs(12)),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(
                          Icons.currency_rupee_rounded,
                          size: alertIc(18),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: largeUi ? 12 : 10,
                          vertical: largeUi ? 10 : 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: largeUi ? 10 : 8),
                    buildPaymentSummary(),
                  ] else if (paymentMode == 'credit') ...[
                    Container(
                      padding: EdgeInsets.all(largeUi ? 12 : 10),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Credit sale — full amount ₹${billDue().toStringAsFixed(2)} due later',
                        style: TextStyle(
                          fontSize: alertFs(14),
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warning,
                        ),
                      ),
                    ),
                  ] else if (paymentMode == 'advance') ...[
                    Container(
                      padding: EdgeInsets.all(largeUi ? 12 : 10),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Apply advance ₹${paymentAmount().toStringAsFixed(2)} '
                        '(available ₹${(billingCustomer?.advanceBalance ?? 0).toStringAsFixed(2)})',
                        style: TextStyle(
                          fontSize: alertFs(14),
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: EdgeInsets.all(largeUi ? 16 : 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${paymentMode.toUpperCase()} Amount: ₹${billDue().toStringAsFixed(2)}',
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
                      enabled: !lockPaymentInputs(),
                      style: TextStyle(fontSize: alertFs(14)),
                      decoration: InputDecoration(
                        labelText: 'Reference (optional)',
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
                ],
              );
            }

            Widget buildBody() {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildInvoiceCard(),
                  SizedBox(height: sectionGap),
                  buildPaymentFields(),
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
                    if ((!paymentSaved || hasOpenBalance()) && !recordingPayment) {
                      confirmCheckout();
                    }
                  },
                  const SingleActivator(LogicalKeyboardKey.f2): () {
                    if (!lockPaymentInputs()) {
                      setState(() {
                        paymentMode = 'cash';
                        syncPaidToDue();
                      });
                    }
                  },
                  const SingleActivator(LogicalKeyboardKey.f3): () {
                    if (!lockPaymentInputs()) {
                      setState(() => paymentMode = 'upi');
                    }
                  },
                },
                child: Focus(
                  autofocus: true,
                  child: Theme(
              data: Theme.of(context).copyWith(
                dialogTheme: DialogThemeData(
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
                      padding: EdgeInsets.fromLTRB(hPad, vPad, hPad * 0.5, 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(largeUi ? 8 : 6),
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
                              size: alertIc(20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasOpenBalance()
                                      ? 'Collect remaining balance'
                                      : 'Checkout',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: alertFs(16),
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (largeUi)
                                  Text(
                                    hasOpenBalance()
                                        ? 'Switch to UPI/Cash and pay the balance'
                                        : 'Confirm payment to print invoice',
                                    style: TextStyle(
                                      fontSize: alertFs(11),
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (hasOpenBalance())
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Due ₹${activeInvoice!.dueAmount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: AppTheme.warning,
                                  fontWeight: FontWeight.w500,
                                  fontSize: alertFs(11),
                                ),
                              ),
                            )
                          else
                            IconButton(
                              tooltip: 'Cancel — back to cart',
                              onPressed: recordingPayment ? null : handleEscape,
                              icon: Icon(
                                Icons.close_rounded,
                                size: alertIc(20),
                                color: AppTheme.textSecondary,
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
                        height: largeUi ? 42 : 40,
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    recordingPayment ? null : handleEscape,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.textPrimary,
                                  side: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  hasOpenBalance() ? 'Close' : 'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: alertFs(13),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: recordingPayment
                                    ? null
                                    : confirmCheckout,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  recordingPayment
                                      ? 'Saving…'
                                      : hasOpenBalance()
                                          ? 'Pay Remaining Balance'
                                          : 'Confirm Payment',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: alertFs(13),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    paidController.dispose();
    upiRefController.dispose();
    loyaltyController.dispose();
  }
}
