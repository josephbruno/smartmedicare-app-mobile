import '../json_helpers.dart';

class Supplier {
  Supplier({
    required this.id,
    required this.name,
    this.companyName,
    this.email,
    required this.phone,
    this.gstin,
    this.creditLimit,
    this.creditDays,
    required this.isActive,
  });

  final int id;
  final String name;
  final String? companyName;
  final String? email;
  final String phone;
  final String? gstin;
  final double? creditLimit;
  final int? creditDays;
  final bool isActive;

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: intOrNull(j['id']) ?? 0,
        name: j['name']?.toString() ?? '',
        companyName: j['company_name']?.toString(),
        email: j['email']?.toString(),
        phone: j['phone']?.toString() ?? '',
        gstin: j['gstin']?.toString(),
        creditLimit: numOrNull(j['credit_limit']),
        creditDays: intOrNull(j['credit_days']),
        isActive: j['is_active'] as bool? ?? true,
      );
}

class PurchaseItem {
  PurchaseItem({
    required this.id,
    required this.productId,
    this.batchNumber,
    this.expiryDate,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    this.sellingPrice,
    this.mrp,
    this.productName,
    this.productSku,
    this.productBarcode,
  });

  final int id;
  final int productId;
  final String? batchNumber;
  final String? expiryDate;
  final double quantity;
  final double unitPrice;
  final double totalAmount;
  final double? sellingPrice;
  final double? mrp;
  final String? productName;
  final String? productSku;
  final String? productBarcode;

  factory PurchaseItem.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? product;
    final raw = j['product'];
    if (raw is Map) product = Map<String, dynamic>.from(raw);

    return PurchaseItem(
      id: intOrNull(j['id']) ?? 0,
      productId: intOrNull(j['product_id']) ?? intOrNull(product?['id']) ?? 0,
      batchNumber: j['batch_number']?.toString(),
      expiryDate: j['expiry_date']?.toString(),
      quantity: numOrNull(j['quantity']) ?? 0,
      unitPrice: numOrNull(j['unit_price']) ?? 0,
      totalAmount: numOrNull(j['total_amount']) ?? 0,
      sellingPrice: numOrNull(j['selling_price']) ?? numOrNull(product?['selling_price']),
      mrp: numOrNull(j['mrp']) ?? numOrNull(product?['mrp']),
      productName: product?['name']?.toString(),
      productSku: product?['sku']?.toString(),
      productBarcode: product?['barcode']?.toString(),
    );
  }
}

class Purchase {
  Purchase({
    required this.id,
    required this.purchaseNumber,
    required this.supplierId,
    required this.status,
    required this.purchaseDate,
    required this.totalAmount,
    this.subtotal,
    this.paidAmount,
    this.dueAmount,
    this.paymentStatus,
    this.notes,
    this.branchName,
    this.supplier,
    this.items = const [],
  });

  final int id;
  final String purchaseNumber;
  final int supplierId;
  final String status;
  final String purchaseDate;
  final double totalAmount;
  final double? subtotal;
  final double? paidAmount;
  final double? dueAmount;
  final String? paymentStatus;
  final String? notes;
  final String? branchName;
  final Supplier? supplier;
  final List<PurchaseItem> items;

  String get dateOnly {
    final d = purchaseDate;
    return d.length >= 10 ? d.substring(0, 10) : d;
  }

  factory Purchase.fromJson(Map<String, dynamic> j) {
    Supplier? s;
    if (j['supplier'] is Map) {
      s = Supplier.fromJson(Map<String, dynamic>.from(j['supplier'] as Map));
    }

    String? branchName;
    if (j['branch'] is Map) {
      branchName = (j['branch'] as Map)['name']?.toString();
    }

    final items = <PurchaseItem>[];
    if (j['items'] is List) {
      for (final e in j['items'] as List) {
        if (e is Map) {
          items.add(PurchaseItem.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    return Purchase(
      id: intOrNull(j['id']) ?? 0,
      purchaseNumber: j['purchase_number']?.toString() ?? '',
      supplierId: intOrNull(j['supplier_id']) ?? 0,
      status: j['status']?.toString() ?? 'draft',
      purchaseDate: j['purchase_date']?.toString() ?? '',
      totalAmount: numOrNull(j['total_amount']) ?? 0,
      subtotal: numOrNull(j['subtotal']),
      paidAmount: numOrNull(j['paid_amount']),
      dueAmount: numOrNull(j['due_amount']),
      paymentStatus: j['payment_status']?.toString(),
      notes: j['notes']?.toString(),
      branchName: branchName,
      supplier: s,
      items: items,
    );
  }
}
