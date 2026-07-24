import 'dart:convert';

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
  final double unitPrice;
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
    if (type.isEmpty) {
      final product = j['product'];
      if (product is Map) {
        type = product['product_type']?.toString() ?? '';
        if (type.isEmpty) {
          if (product['is_service'] == true) {
            type = 'service';
          } else if (product['is_medicine'] == true) {
            type = 'medicine';
          }
        }
      }
    }
    if (type.isEmpty) type = 'product';

    return InvoiceItem(
        id: intOrNull(j['id']) ?? 0,
        productId: intOrNull(j['product_id']) ?? 0,
        productName: j['product_name']?.toString() ?? '',
        productType: type,
        hsnCode: j['hsn_code']?.toString(),
        batchId: intOrNull(j['batch_id']),
        quantity: numOrNull(j['quantity']) ?? 0,
        unitPrice: numOrNull(j['unit_price']) ?? 0,
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

  String get displayDate => formatApiDate(invoiceDate);
  String get branchName => branch?.name ?? '—';

  bool get isPaid => status == 'paid';
  bool get isUnpaid => status == 'partial' || status == 'confirmed' || status == 'draft';

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
