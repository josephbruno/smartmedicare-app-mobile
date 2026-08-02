import '../json_helpers.dart';
import 'purchase.dart';

class PurchaseReturnItem {
  PurchaseReturnItem({
    required this.id,
    required this.productId,
    this.batchId,
    this.batchNumber,
    this.expiryDate,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    this.gstRate,
    this.productName,
    this.productSku,
  });

  final int id;
  final int productId;
  final int? batchId;
  final String? batchNumber;
  final String? expiryDate;
  final double quantity;
  final double unitPrice;
  final double totalAmount;
  final double? gstRate;
  final String? productName;
  final String? productSku;

  factory PurchaseReturnItem.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? product;
    final raw = j['product'];
    if (raw is Map) product = Map<String, dynamic>.from(raw);

    Map<String, dynamic>? batch;
    final rawBatch = j['batch'];
    if (rawBatch is Map) batch = Map<String, dynamic>.from(rawBatch);

    return PurchaseReturnItem(
      id: intOrNull(j['id']) ?? 0,
      productId: intOrNull(j['product_id']) ?? intOrNull(product?['id']) ?? 0,
      batchId: intOrNull(j['batch_id']) ?? intOrNull(batch?['id']),
      batchNumber: j['batch_number']?.toString() ?? batch?['batch_number']?.toString(),
      expiryDate: j['expiry_date']?.toString() ?? batch?['expiry_date']?.toString(),
      quantity: numOrNull(j['quantity']) ?? 0,
      unitPrice: numOrNull(j['unit_price']) ?? 0,
      totalAmount: numOrNull(j['total_amount']) ?? 0,
      gstRate: numOrNull(j['gst_rate']),
      productName: product?['name']?.toString(),
      productSku: product?['sku']?.toString(),
    );
  }
}

class PurchaseReturn {
  PurchaseReturn({
    required this.id,
    required this.returnNumber,
    required this.supplierId,
    required this.reason,
    required this.status,
    required this.returnDate,
    required this.totalAmount,
    this.subtotal,
    this.notes,
    this.branchName,
    this.supplier,
    this.items = const [],
  });

  final int id;
  final String returnNumber;
  final int supplierId;
  final String reason;
  final String status;
  final String returnDate;
  final double totalAmount;
  final double? subtotal;
  final String? notes;
  final String? branchName;
  final Supplier? supplier;
  final List<PurchaseReturnItem> items;

  String get dateOnly {
    final d = returnDate;
    return d.length >= 10 ? d.substring(0, 10) : d;
  }

  String get reasonLabel {
    switch (reason.toLowerCase()) {
      case 'expired':
        return 'Expired';
      case 'damaged':
        return 'Damaged';
      default:
        return 'Other';
    }
  }

  factory PurchaseReturn.fromJson(Map<String, dynamic> j) {
    Supplier? s;
    if (j['supplier'] is Map) {
      s = Supplier.fromJson(Map<String, dynamic>.from(j['supplier'] as Map));
    }

    String? branchName;
    if (j['branch'] is Map) {
      branchName = (j['branch'] as Map)['name']?.toString();
    }

    final items = <PurchaseReturnItem>[];
    if (j['items'] is List) {
      for (final e in j['items'] as List) {
        if (e is Map) {
          items.add(PurchaseReturnItem.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    return PurchaseReturn(
      id: intOrNull(j['id']) ?? 0,
      returnNumber: j['return_number']?.toString() ?? '',
      supplierId: intOrNull(j['supplier_id']) ?? 0,
      reason: j['reason']?.toString() ?? 'other',
      status: j['status']?.toString() ?? 'completed',
      returnDate: j['return_date']?.toString() ?? '',
      totalAmount: numOrNull(j['total_amount']) ?? 0,
      subtotal: numOrNull(j['subtotal']),
      notes: j['notes']?.toString(),
      branchName: branchName,
      supplier: s,
      items: items,
    );
  }
}
