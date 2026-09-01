import 'product.dart';

class StockTransferItem {
  StockTransferItem({
    required this.id,
    required this.productId,
    required this.requestedQuantity,
    this.dispatchedQuantity,
    this.acceptedQuantity,
    this.product,
  });

  final int id;
  final int productId;
  final double requestedQuantity;
  final double? dispatchedQuantity;
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
      dispatchedQuantity: (j['dispatched_quantity'] as num?)?.toDouble(),
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
    this.approvedByName,
    this.dispatchedByName,
    this.reviewedByName,
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
  final String? approvedByName;
  final String? dispatchedByName;
  final String? reviewedByName;
  final List<StockTransferItem> items;

  bool get isRequested => status == 'requested' || status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDispatched => status == 'dispatched';
  bool get isReceived => status == 'received' || status == 'accepted';

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
      status: j['status']?.toString() ?? 'requested',
      notes: j['notes']?.toString(),
      reviewNotes: j['review_notes']?.toString(),
      createdAt: j['created_at']?.toString() ?? '',
      fromBranchName: nameOf(j['from_branch']),
      toBranchName: nameOf(j['to_branch']),
      requestedByName: nameOf(j['requested_by_user']),
      approvedByName: nameOf(j['approved_by_user']),
      dispatchedByName: nameOf(j['dispatched_by_user']),
      reviewedByName: nameOf(j['reviewed_by_user']),
      items: items,
    );
  }
}
