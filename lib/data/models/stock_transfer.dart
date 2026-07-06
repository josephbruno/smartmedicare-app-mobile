import 'product.dart';

class StockTransferItem {
  StockTransferItem({
    required this.id,
    required this.productId,
    required this.requestedQuantity,
    this.acceptedQuantity,
    this.product,
  });

  final int id;
  final int productId;
  final double requestedQuantity;
  final double? acceptedQuantity;
  final Product? product;

  factory StockTransferItem.fromJson(Map<String, dynamic> j) {
    Product? p;
    if (j['product'] is Map) {
      p = Product.fromJson(Map<String, dynamic>.from(j['product'] as Map));
    }
    return StockTransferItem(
      id: (j['id'] as num?)?.toInt() ?? 0,
      productId: (j['product_id'] as num?)?.toInt() ?? 0,
      requestedQuantity: (j['requested_quantity'] as num?)?.toDouble() ?? 0,
      acceptedQuantity: (j['accepted_quantity'] as num?)?.toDouble(),
      product: p,
    );
  }
}

class StockTransfer {
  StockTransfer({
    required this.id,
    required this.transferNumber,
    required this.fromBranchId,
    required this.toBranchId,
    required this.status,
    this.notes,
    this.reviewNotes,
    required this.createdAt,
    this.fromBranchName,
    this.toBranchName,
    this.requestedByName,
    this.items = const [],
  });

  final int id;
  final String transferNumber;
  final int fromBranchId;
  final int toBranchId;
  final String status;
  final String? notes;
  final String? reviewNotes;
  final String createdAt;
  final String? fromBranchName;
  final String? toBranchName;
  final String? requestedByName;
  final List<StockTransferItem> items;

  factory StockTransfer.fromJson(Map<String, dynamic> j) {
    String? nameOf(dynamic v) =>
        v is Map ? v['name']?.toString() : null;

    final rawItems = j['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => StockTransferItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <StockTransferItem>[];

    return StockTransfer(
      id: (j['id'] as num?)?.toInt() ?? 0,
      transferNumber: j['transfer_number']?.toString() ?? '',
      fromBranchId: (j['from_branch_id'] as num?)?.toInt() ?? 0,
      toBranchId: (j['to_branch_id'] as num?)?.toInt() ?? 0,
      status: j['status']?.toString() ?? 'pending',
      notes: j['notes']?.toString(),
      reviewNotes: j['review_notes']?.toString(),
      createdAt: j['created_at']?.toString() ?? '',
      fromBranchName: nameOf(j['from_branch']),
      toBranchName: nameOf(j['to_branch']),
      requestedByName: nameOf(j['requested_by_user']),
      items: items,
    );
  }
}
