import 'dart:convert';

import 'package:intl/intl.dart';

import '../json_helpers.dart';
import 'api_response.dart';
import 'customer.dart';
import 'user.dart';

class InvoiceCustomerLite {
  InvoiceCustomerLite({
    required this.id,
    required this.name,
    this.phone,
  });

  final int id;
  final String name;
  final String? phone;

  factory InvoiceCustomerLite.fromJson(Map<String, dynamic>? j) {
    if (j == null) return InvoiceCustomerLite(id: 0, name: '');
    return InvoiceCustomerLite(
      id: intOrNull(j['id']) ?? 0,
      name: j['name']?.toString() ?? '',
      phone: j['phone']?.toString(),
    );
  }

  Customer toCustomer() => Customer(
        id: id,
        name: name,
        phone: phone ?? '',
        isActive: true,
      );
}

class InvoiceItem {
  InvoiceItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productType = 'product',
    this.hsnCode,
    this.batchId,
    required this.quantity,
    required this.unitPrice,
    this.mrp = 0,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.taxableAmount = 0,
    this.gstRate = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    required this.totalAmount,
  });

  final int id;
  final int productId;
  final String productName;
  /// One of: product | service | medicine
  final String productType;
  final String? hsnCode;
  final int? batchId;
  final double quantity;
  /// Selling price charged on this line.
  final double unitPrice;
  /// Catalog MRP (for receipt display).
  final double mrp;
  final double discountPercent;
  final double discountAmount;
  final double taxableAmount;
  final double gstRate;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalAmount;

  String get productTypeLabel {
    switch (productType) {
      case 'service':
        return 'Service';
      case 'medicine':
        return 'Medicine';
      default:
        return 'Product';
    }
  }

  factory InvoiceItem.fromJson(Map<String, dynamic> j) {
    String type = j['product_type']?.toString() ?? '';
    Map<String, dynamic>? product;
    if (j['product'] is Map) {
      product = Map<String, dynamic>.from(j['product'] as Map);
    }
    if (type.isEmpty && product != null) {
      type = product['product_type']?.toString() ?? '';
      if (type.isEmpty) {
        if (product['is_service'] == true) {
          type = 'service';
        } else if (product['is_medicine'] == true) {
          type = 'medicine';
        }
      }
    }
    if (type.isEmpty) type = 'product';

    final mrp = numOrNull(j['mrp']) ??
        (product != null ? numOrNull(product['mrp']) : null) ??
        0;

    return InvoiceItem(
        id: intOrNull(j['id']) ?? 0,
        productId: intOrNull(j['product_id']) ?? 0,
        productName: j['product_name']?.toString() ?? '',
        productType: type,
        hsnCode: j['hsn_code']?.toString(),
        batchId: intOrNull(j['batch_id']),
        quantity: numOrNull(j['quantity']) ?? 0,
        unitPrice: numOrNull(j['unit_price']) ?? 0,
        mrp: mrp,
        discountPercent: numOrNull(j['discount_percent']) ?? 0,
        discountAmount: numOrNull(j['discount_amount']) ?? 0,
        taxableAmount: numOrNull(j['taxable_amount']) ?? 0,
        gstRate: numOrNull(j['gst_rate']) ?? 0,
        cgstAmount: numOrNull(j['cgst_amount']) ?? 0,
        sgstAmount: numOrNull(j['sgst_amount']) ?? 0,
        igstAmount: numOrNull(j['igst_amount']) ?? 0,
        totalAmount: numOrNull(j['total_amount']) ?? 0,
      );
  }
}

class InvoicePayment {
  InvoicePayment({
    required this.id,
    required this.paymentMode,
    required this.amount,
    required this.paymentDate,
    this.referenceNumber,
    this.notes,
    this.tenderedAmount,
    this.changeReturn,
  });

  final int id;
  final String paymentMode;
  final double amount;
  final String paymentDate;
  final String? referenceNumber;
  final String? notes;
  /// Cash received from customer (when tendered > applied amount).
  final double? tenderedAmount;
  /// Change handed back by cashier.
  final double? changeReturn;

  bool get hasCashTenderDetail =>
      tenderedAmount != null &&
      tenderedAmount! > 0 &&
      (changeReturn ?? 0) > 0;

  factory InvoicePayment.fromJson(Map<String, dynamic> j) {
    double? tendered = numOrNull(j['tendered_amount']);
    double? change = numOrNull(j['change_return']);
    String? notesRaw;

    final rawNotes = j['notes'];
    if (rawNotes is Map) {
      final meta = Map<String, dynamic>.from(rawNotes);
      tendered ??= numOrNull(meta['tendered_amount']);
      change ??= numOrNull(meta['change_return']);
    } else if (rawNotes != null) {
      final text = rawNotes.toString().trim();
      if (text.startsWith('{')) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map) {
            final meta = Map<String, dynamic>.from(decoded);
            tendered ??= numOrNull(meta['tendered_amount']);
            change ??= numOrNull(meta['change_return']);
          } else {
            notesRaw = text;
          }
        } catch (_) {
          notesRaw = text;
        }
      } else if (text.isNotEmpty) {
        notesRaw = text;
      }
    }

    return InvoicePayment(
      id: intOrNull(j['id']) ?? 0,
      paymentMode: j['payment_mode']?.toString() ?? '',
      amount: numOrNull(j['amount']) ?? 0,
      paymentDate: formatApiDate(j['payment_date']?.toString()),
      referenceNumber: j['reference_number']?.toString(),
      notes: notesRaw,
      tenderedAmount: tendered,
      changeReturn: change,
    );
  }
}

class ReturnableInvoiceItem {
  ReturnableInvoiceItem({
    required this.invoiceItemId,
    required this.productId,
    required this.productName,
    this.batchId,
    required this.quantity,
    required this.returnedQuantity,
    required this.returnableQty,
    required this.unitPrice,
    required this.gstRate,
    required this.totalAmount,
  });

  final int invoiceItemId;
  final int productId;
  final String productName;
  final int? batchId;
  final double quantity;
  final double returnedQuantity;
  final double returnableQty;
  final double unitPrice;
  final double gstRate;
  final double totalAmount;

  factory ReturnableInvoiceItem.fromJson(Map<String, dynamic> j) =>
      ReturnableInvoiceItem(
        invoiceItemId: intOrNull(j['invoice_item_id']) ?? 0,
        productId: intOrNull(j['product_id']) ?? 0,
        productName: j['product_name']?.toString() ?? '',
        batchId: intOrNull(j['batch_id']),
        quantity: numOrNull(j['quantity']) ?? 0,
        returnedQuantity: numOrNull(j['returned_quantity']) ?? 0,
        returnableQty: numOrNull(j['returnable_qty']) ?? 0,
        unitPrice: numOrNull(j['unit_price']) ?? 0,
        gstRate: numOrNull(j['gst_rate']) ?? 0,
        totalAmount: numOrNull(j['total_amount']) ?? 0,
      );
}

class InvoiceReturnSummary {
  InvoiceReturnSummary({
    required this.id,
    required this.invoiceNumber,
    required this.type,
    required this.status,
    required this.totalAmount,
    this.invoiceDate,
  });

  final int id;
  final String invoiceNumber;
  final String type;
  final String status;
  final double totalAmount;
  final String? invoiceDate;

  factory InvoiceReturnSummary.fromJson(Map<String, dynamic> j) =>
      InvoiceReturnSummary(
        id: intOrNull(j['id']) ?? 0,
        invoiceNumber: j['invoice_number']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        totalAmount: numOrNull(j['total_amount']) ?? 0,
        invoiceDate: j['invoice_date']?.toString(),
      );
}

class Invoice {
  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.type,
    required this.status,
    required this.invoiceDate,
    this.dueDate,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.totalGst = 0,
    this.roundOff = 0,
    required this.totalAmount,
    required this.paidAmount,
    required this.dueAmount,
    this.loyaltyPointsEarned = 0,
    this.loyaltyPointsRedeemed = 0,
    this.isIgst = false,
    this.notes,
    this.offlineId,
    this.shareToken,
    this.branchId,
    this.branch,
    this.customer,
    this.items,
    this.payments,
    this.createdAt,
    this.createdById,
    this.createdByName,
    this.returnOfInvoiceId,
    this.originalInvoice,
    this.returns = const [],
    this.returnableItems = const [],
  });

  final int id;
  final String invoiceNumber;
  final String type;
  final String status;
  final String invoiceDate;
  final String? dueDate;
  final double subtotal;
  final double discountAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalGst;
  final double roundOff;
  final double totalAmount;
  final double paidAmount;
  final double dueAmount;
  final int loyaltyPointsEarned;
  final int loyaltyPointsRedeemed;
  final bool isIgst;
  final String? notes;
  final String? offlineId;
  final String? shareToken;
  final int? branchId;
  final BranchLite? branch;
  final Customer? customer;
  final List<InvoiceItem>? items;
  final List<InvoicePayment>? payments;
  final String? createdAt;
  final int? createdById;
  final String? createdByName;
  final int? returnOfInvoiceId;
  final InvoiceReturnSummary? originalInvoice;
  final List<InvoiceReturnSummary> returns;
  final List<ReturnableInvoiceItem> returnableItems;

  bool get canReturn =>
      type == 'tax_invoice' &&
      status.toLowerCase() != 'cancelled' &&
      returnableItems.any((i) => i.returnableQty > 0.0005);

  bool get isReturnInvoice => type == 'return_invoice';

  /// Previous invoice this return/credit is against.
  String? get againstInvoiceNumber =>
      originalInvoice?.invoiceNumber ??
      (returnOfInvoiceId != null ? '#$returnOfInvoiceId' : null);

  /// Display as `dd-MM-yy`, e.g. `03-08-26`.
  String get displayDate {
    final raw = formatApiDate(invoiceDate);
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd-MM-yy').format(parsed);
  }

  /// Strips legacy `INV-` prefix for display (`INV-260803-0001` → `260803-0001`).
  String get displayInvoiceNumber {
    final n = invoiceNumber.trim();
    if (n.toUpperCase().startsWith('INV-')) {
      return n.substring(4);
    }
    return n;
  }

  String get branchName => branch?.name ?? '—';

  String get creatorName {
    final name = createdByName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (createdById != null && createdById! > 0) return 'User #$createdById';
    return '—';
  }

  bool get isPaid => status == 'paid';
  bool get isUnpaid => status == 'partial' || status == 'confirmed' || status == 'draft';

  /// Cash payments that recorded tendered amount + change (tendered > applied).
  Iterable<InvoicePayment> get cashTenderPayments =>
      (payments ?? const <InvoicePayment>[]).where((p) => p.hasCashTenderDetail);

  Iterable<InvoicePayment> get cashPayments => (payments ?? const <InvoicePayment>[])
      .where((p) => p.paymentMode.toLowerCase() == 'cash' && p.amount > 0.009);

  /// Cash received for list/UI:
  /// - Overpay with change on a settled bill → tendered amount
  /// - Exact / partial cash → amount applied to the invoice
  /// Balance due always comes from [dueAmount], not this field.
  double? get cashReceivedTotal {
    final list = cashPayments.toList();
    if (list.isEmpty) return null;
    var total = 0.0;
    for (final p in list) {
      if (p.hasCashTenderDetail && dueAmount <= 0.009) {
        total += p.tenderedAmount ?? p.amount;
      } else {
        total += p.amount;
      }
    }
    return total;
  }

  /// Total change returned; only when the invoice has no remaining due.
  /// Partial invoices never show change (avoids fake tender notes).
  double? get changeReturnTotal {
    if (dueAmount > 0.009) return null;
    final list = cashTenderPayments.toList();
    if (list.isEmpty) return null;
    final total = list.fold<double>(0, (s, p) => s + (p.changeReturn ?? 0));
    return total > 0.009 ? total : null;
  }

  bool get hasChangeReturn => (changeReturnTotal ?? 0) > 0.009;

  bool get hasBalanceDue => dueAmount > 0.009;

  /// Separate cash summary: only when change was given and/or balance remains.
  bool get hasCashPaymentSummary => hasChangeReturn || hasBalanceDue;

  bool get hasPayments =>
      (payments ?? const <InvoicePayment>[]).any((p) => p.amount > 0.009);

  /// Sums applied amounts by `payment_mode` (lowercase keys).
  Map<String, double> get paymentsByMode {
    final map = <String, double>{};
    for (final p in payments ?? const <InvoicePayment>[]) {
      if (p.amount <= 0.009) continue;
      final key = p.paymentMode.toLowerCase().trim();
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0) + p.amount;
    }
    return map;
  }

  /// e.g. "Cash ₹1,000 · UPI ₹2,500" for list/detail/receipts.
  String paymentBreakdownSummary({
    String Function(String mode)? modeLabel,
    bool compact = true,
  }) {
    final map = paymentsByMode;
    if (map.isEmpty) return '';
    String label(String mode) {
      if (modeLabel != null) return modeLabel(mode);
      return switch (mode) {
        'cash' => 'Cash',
        'upi' => 'UPI',
        'card' => 'Card',
        'bank_transfer' => 'Bank',
        'cheque' => 'Cheque',
        'credit' => 'Credit',
        'loyalty_points' => 'Loyalty',
        'advance' => 'Advance',
        'other' => 'Other',
        _ => mode.replaceAll('_', ' '),
      };
    }

    String money(double v) {
      if (compact && v == v.roundToDouble()) {
        return v.toStringAsFixed(0);
      }
      return v.toStringAsFixed(2);
    }

    return map.entries
        .map((e) => '${label(e.key)} ₹${money(e.value)}')
        .join(' · ');
  }

  factory Invoice.fromJson(Map<String, dynamic> j) {
    Customer? c;
    if (j['customer'] is Map) {
      final cm = Map<String, dynamic>.from(j['customer'] as Map);
      if (cm.containsKey('email') || cm.containsKey('is_active')) {
        c = Customer.fromJson(cm);
      } else {
        c = InvoiceCustomerLite.fromJson(cm).toCustomer();
      }
    }
    List<InvoiceItem>? items;
    if (j['items'] is List) {
      items = listFromData(j['items'], InvoiceItem.fromJson);
    }
    List<InvoicePayment>? payments;
    if (j['payments'] is List) {
      payments = listFromData(j['payments'], InvoicePayment.fromJson);
    }
    BranchLite? branch;
    if (j['branch'] is Map) {
      branch = BranchLite.fromJson(Map<String, dynamic>.from(j['branch'] as Map));
    }
    final branchId = intOrNull(j['branch_id']) ?? branch?.id;
    final returns = <InvoiceReturnSummary>[];
    if (j['returns'] is List) {
      for (final e in j['returns'] as List) {
        if (e is Map) {
          returns.add(InvoiceReturnSummary.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    InvoiceReturnSummary? originalInvoice;
    if (j['original_invoice'] is Map) {
      originalInvoice = InvoiceReturnSummary.fromJson(
        Map<String, dynamic>.from(j['original_invoice'] as Map),
      );
    }
    final returnable = <ReturnableInvoiceItem>[];
    if (j['returnable_items'] is List) {
      for (final e in j['returnable_items'] as List) {
        if (e is Map) {
          returnable.add(
            ReturnableInvoiceItem.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return Invoice(
      id: intOrNull(j['id']) ?? 0,
      invoiceNumber: j['invoice_number']?.toString() ?? '',
      type: j['type']?.toString() ?? 'tax_invoice',
      status: j['status']?.toString() ?? 'draft',
      invoiceDate: formatApiDate(j['invoice_date']?.toString()),
      dueDate: j['due_date'] != null ? formatApiDate(j['due_date']?.toString()) : null,
      subtotal: numOrNull(j['subtotal']) ?? 0,
      discountAmount: numOrNull(j['discount_amount']) ?? 0,
      cgstAmount: numOrNull(j['cgst_amount']) ?? 0,
      sgstAmount: numOrNull(j['sgst_amount']) ?? 0,
      igstAmount: numOrNull(j['igst_amount']) ?? 0,
      totalGst: numOrNull(j['total_gst']) ?? 0,
      roundOff: numOrNull(j['round_off']) ?? 0,
      totalAmount: numOrNull(j['total_amount']) ?? 0,
      paidAmount: numOrNull(j['paid_amount']) ?? 0,
      dueAmount: numOrNull(j['due_amount']) ?? 0,
      loyaltyPointsEarned: intOrNull(j['loyalty_points_earned']) ?? 0,
      loyaltyPointsRedeemed: intOrNull(j['loyalty_points_redeemed']) ?? 0,
      isIgst: j['is_igst'] as bool? ?? false,
      notes: j['notes']?.toString(),
      offlineId: j['offline_id']?.toString(),
      shareToken: j['share_token']?.toString(),
      branchId: branchId,
      branch: branch,
      customer: c,
      items: items,
      payments: payments,
      createdAt: j['created_at']?.toString(),
      createdById: intOrNull(j['created_by']) ??
          intOrNull(mapOrNull(j['created_by_user'])?['id']),
      createdByName: j['created_by_name']?.toString() ??
          mapOrNull(j['created_by_user'])?['name']?.toString(),
      returnOfInvoiceId: intOrNull(j['return_of_invoice_id']) ?? originalInvoice?.id,
      originalInvoice: originalInvoice,
      returns: returns,
      returnableItems: returnable,
    );
  }
}

class SaleReturnResult {
  SaleReturnResult({
    required this.returnInvoice,
    this.exchangeInvoice,
    required this.refundAmount,
    required this.amountDue,
    required this.advanceCredited,
  });

  final Invoice returnInvoice;
  final Invoice? exchangeInvoice;
  final double refundAmount;
  final double amountDue;
  final double advanceCredited;

  factory SaleReturnResult.fromJson(Map<String, dynamic> j) {
    final ret = j['return_invoice'];
    final exch = j['exchange_invoice'];
    return SaleReturnResult(
      returnInvoice: Invoice.fromJson(
        Map<String, dynamic>.from(ret as Map),
      ),
      exchangeInvoice: exch is Map
          ? Invoice.fromJson(Map<String, dynamic>.from(exch))
          : null,
      refundAmount: numOrNull(j['refund_amount']) ?? 0,
      amountDue: numOrNull(j['amount_due']) ?? 0,
      advanceCredited: numOrNull(j['advance_credited']) ?? 0,
    );
  }
}

class InvoiceListSummary {
  InvoiceListSummary({
    required this.totalAmount,
    required this.paidAmount,
    required this.dueAmount,
  });

  final double totalAmount;
  final double paidAmount;
  final double dueAmount;

  factory InvoiceListSummary.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return InvoiceListSummary(totalAmount: 0, paidAmount: 0, dueAmount: 0);
    }
    return InvoiceListSummary(
      totalAmount: numOrNull(j['total_amount']) ?? 0,
      paidAmount: numOrNull(j['paid_amount']) ?? 0,
      dueAmount: numOrNull(j['due_amount']) ?? 0,
    );
  }
}

class InvoiceListResult {
  InvoiceListResult({
    required this.items,
    this.pagination,
    this.summary,
  });

  final List<Invoice> items;
  final PaginationMeta? pagination;
  final InvoiceListSummary? summary;
}

class CartItem {
  CartItem({
    required this.productId,
    required this.productName,
    this.barcode,
    this.hsnCode,
    this.batchId,
    required this.quantity,
    required this.unitPrice,
    this.mrp = 0,
    this.unitPriceTaxable,
    required this.discountPercent,
    required this.discountAmount,
    required this.taxableAmount,
    required this.gstType,
    required this.gstRate,
    required this.cgstRate,
    required this.sgstRate,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.totalAmount,
    required this.availableStock,
    required this.trackInventory,
    this.isServiceCharge = false,
  });

  final int productId;
  final String productName;
  final String? barcode;
  final String? hsnCode;
  final int? batchId;
  int quantity;
  double unitPrice;
  double mrp;
  double? unitPriceTaxable;
  double discountPercent;
  double discountAmount;
  double taxableAmount;
  String gstType;
  double gstRate;
  double cgstRate;
  double sgstRate;
  double cgstAmount;
  double sgstAmount;
  double totalAmount;
  double availableStock;
  bool trackInventory;
  final bool isServiceCharge;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        if (barcode != null) 'barcode': barcode,
        if (hsnCode != null) 'hsn_code': hsnCode,
        // Only real catalog batches — visit service-charge uses a negative
        // sentinel locally and must not be sent to the invoices API.
        if (batchId != null && batchId! > 0) 'batch_id': batchId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'mrp': mrp,
        'discount_percent': discountPercent,
        'discount_amount': discountAmount,
        'taxable_amount': taxableAmount,
        'gst_type': gstType,
        'gst_rate': gstRate,
        'cgst_rate': cgstRate,
        'sgst_rate': sgstRate,
        'cgst_amount': cgstAmount,
        'sgst_amount': sgstAmount,
        'total_amount': totalAmount,
        if (isServiceCharge) 'is_service_charge': true,
      };
}

class CartPayment {
  CartPayment({
    required this.mode,
    required this.amount,
    this.reference,
    this.upiId,
  });

  final String mode;
  final double amount;
  final String? reference;
  final String? upiId;

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'amount': amount,
        if (reference != null) 'reference': reference,
        if (upiId != null) 'upi_id': upiId,
      };
}
