import '../json_helpers.dart';
import 'api_response.dart';
import 'product.dart';

class InventoryItem {
  InventoryItem({
    required this.id,
    required this.productId,
    required this.branchId,
    required this.quantity,
    required this.reservedQuantity,
    required this.availableQuantity,
    this.product,
  });

  final int id;
  final int productId;
  final int branchId;
  final double quantity;
  final double reservedQuantity;
  final double availableQuantity;
  final Product? product;

  factory InventoryItem.fromJson(Map<String, dynamic> j) {
    Product? p;
    if (j['product'] is Map) {
      p = Product.fromJson(Map<String, dynamic>.from(j['product'] as Map));
    }
    return InventoryItem(
      id: intOrNull(j['id']) ?? 0,
      productId: intOrNull(j['product_id']) ?? 0,
      branchId: intOrNull(j['branch_id']) ?? 0,
      quantity: numOrNull(j['quantity']) ?? 0,
      reservedQuantity: numOrNull(j['reserved_quantity']) ?? 0,
      availableQuantity: numOrNull(j['available_quantity']) ??
          ((numOrNull(j['quantity']) ?? 0) - (numOrNull(j['reserved_quantity']) ?? 0)),
      product: p,
    );
  }
}

class StockMovement {
  StockMovement({
    required this.id,
    required this.productId,
    required this.branchId,
    required this.type,
    required this.quantity,
    this.referenceType,
    this.referenceId,
    this.referenceNumber,
    this.notes,
    required this.createdAt,
    this.createdById,
    this.createdByName,
    this.product,
    this.branchName,
  });

  final int id;
  final int productId;
  final int branchId;
  final String type;
  final double quantity;
  final String? referenceType;
  final int? referenceId;
  final String? referenceNumber;
  final String? notes;
  final String createdAt;
  final int? createdById;
  final String? createdByName;
  final Product? product;
  final String? branchName;

  factory StockMovement.fromJson(Map<String, dynamic> j) {
    Product? p;
    if (j['product'] is Map) {
      p = Product.fromJson(Map<String, dynamic>.from(j['product'] as Map));
    }
    final createdBy = mapOrNull(j['created_by']) ?? mapOrNull(j['createdBy']);
    final branch = mapOrNull(j['branch']);
    return StockMovement(
      id: intOrNull(j['id']) ?? 0,
      productId: intOrNull(j['product_id']) ?? 0,
      branchId: intOrNull(j['branch_id']) ?? 0,
      type: j['type']?.toString() ?? '',
      quantity: numOrNull(j['quantity']) ?? 0,
      referenceType: j['reference_type']?.toString(),
      referenceId: intOrNull(j['reference_id']),
      referenceNumber: j['reference_number']?.toString(),
      notes: j['notes']?.toString(),
      createdAt: j['created_at']?.toString() ?? '',
      createdById: intOrNull(createdBy?['id']) ?? intOrNull(j['created_by']),
      createdByName: createdBy?['name']?.toString(),
      product: p,
      branchName: branch?['name']?.toString(),
    );
  }
}

class StockAgeingItem {
  StockAgeingItem({
    required this.inventoryId,
    required this.productId,
    this.batchId,
    this.purchaseItemId,
    this.purchaseId,
    this.purchaseNumber,
    required this.name,
    this.sku,
    this.barcode,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.gstRate,
    this.reorderLevel,
    required this.trackInventory,
    required this.currentStock,
    required this.stockValue,
    this.batchNumber,
    this.manufactureDate,
    this.expiryDate,
    this.isExpired = false,
    this.isNearExpiry = false,
    this.daysToExpiry,
    this.lastSaleAt,
    this.daysSinceLastSale,
    this.categoryName,
    this.unitAbbrev,
  });

  final int inventoryId;
  final int productId;
  final int? batchId;
  final int? purchaseItemId;
  final int? purchaseId;
  final String? purchaseNumber;
  final String name;
  final String? sku;
  final String? barcode;
  final double purchasePrice;
  final double sellingPrice;
  final double gstRate;
  final int? reorderLevel;
  final bool trackInventory;
  final double currentStock;
  final double stockValue;
  final String? batchNumber;
  final String? manufactureDate;
  final String? expiryDate;
  final bool isExpired;
  final bool isNearExpiry;
  final int? daysToExpiry;
  final String? lastSaleAt;
  final int? daysSinceLastSale;
  final String? categoryName;
  final String? unitAbbrev;

  factory StockAgeingItem.fromJson(Map<String, dynamic> j) {
    final category = mapOrNull(j['category']);
    final unit = mapOrNull(j['unit']);
    return StockAgeingItem(
      inventoryId: intOrNull(j['inventory_id']) ?? intOrNull(j['id']) ?? 0,
      productId: intOrNull(j['product_id']) ?? 0,
      batchId: intOrNull(j['batch_id']),
      purchaseItemId: intOrNull(j['purchase_item_id']),
      purchaseId: intOrNull(j['purchase_id']),
      purchaseNumber: j['purchase_number']?.toString(),
      name: j['name']?.toString() ?? '',
      sku: j['sku']?.toString(),
      barcode: j['barcode']?.toString(),
      purchasePrice: numOrNull(j['purchase_price']) ?? 0,
      sellingPrice: numOrNull(j['selling_price']) ?? 0,
      gstRate: numOrNull(j['gst_rate']) ?? 0,
      reorderLevel: intOrNull(j['reorder_level']),
      trackInventory: j['track_inventory'] as bool? ?? true,
      currentStock: numOrNull(j['current_stock']) ?? 0,
      stockValue: numOrNull(j['stock_value']) ?? 0,
      batchNumber: j['batch_number']?.toString(),
      manufactureDate: formatApiDate(j['manufacture_date']?.toString()),
      expiryDate: formatApiDate(j['expiry_date']?.toString()),
      isExpired: j['is_expired'] == true || j['is_expired'] == 1,
      isNearExpiry: j['is_near_expiry'] == true || j['is_near_expiry'] == 1,
      daysToExpiry: intOrNull(j['days_to_expiry']),
      lastSaleAt: j['last_sale_at']?.toString(),
      daysSinceLastSale: intOrNull(j['days_since_last_sale']),
      categoryName: category?['name']?.toString(),
      unitAbbrev: unit?['abbreviation']?.toString(),
    );
  }
}

class MonthlyAgeingRow {
  MonthlyAgeingRow({
    required this.productId,
    required this.name,
    this.sku,
    required this.reorderLevel,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.currentStock,
    required this.openingStock,
    required this.closingStock,
    required this.totalSold,
    required this.dailyStock,
    required this.isDeadStock,
    this.categoryName,
    this.unitAbbrev,
  });

  final int productId;
  final String name;
  final String? sku;
  final double reorderLevel;
  final double purchasePrice;
  final double sellingPrice;
  final double currentStock;
  final double openingStock;
  final double closingStock;
  final double totalSold;
  final Map<String, double> dailyStock;
  final bool isDeadStock;
  final String? categoryName;
  final String? unitAbbrev;

  bool hasSnapshot(String date) => dailyStock.containsKey(date);

  double? stockOn(String date) => dailyStock[date];

  factory MonthlyAgeingRow.fromJson(Map<String, dynamic> j) {
    final category = mapOrNull(j['category']);
    final unit = mapOrNull(j['unit']);
    final dailyRaw = j['daily_stock'];
    final dailyStock = <String, double>{};
    if (dailyRaw is Map) {
      for (final entry in dailyRaw.entries) {
        final qty = numOrNull(entry.value);
        if (qty != null) {
          dailyStock[entry.key.toString()] = qty;
        }
      }
    }
    return MonthlyAgeingRow(
      productId: intOrNull(j['product_id']) ?? 0,
      name: j['name']?.toString() ?? '',
      sku: j['sku']?.toString(),
      reorderLevel: numOrNull(j['reorder_level']) ?? 0,
      purchasePrice: numOrNull(j['purchase_price']) ?? 0,
      sellingPrice: numOrNull(j['selling_price']) ?? 0,
      currentStock: numOrNull(j['current_stock']) ?? 0,
      openingStock: numOrNull(j['opening_stock']) ?? 0,
      closingStock: numOrNull(j['closing_stock']) ?? 0,
      totalSold: numOrNull(j['total_sold']) ?? 0,
      dailyStock: dailyStock,
      isDeadStock: j['is_dead_stock'] as bool? ?? false,
      categoryName: category?['name']?.toString(),
      unitAbbrev: unit?['abbreviation']?.toString(),
    );
  }
}

class MonthlySnapshotResult {
  MonthlySnapshotResult({
    required this.rows,
    required this.dateRange,
    required this.month,
    required this.monthLabel,
    this.meta,
  });

  final List<MonthlyAgeingRow> rows;
  final List<String> dateRange;
  final String month;
  final String monthLabel;
  final PaginationMeta? meta;
}

class InventoryListSummary {
  InventoryListSummary({
    required this.totalItems,
    required this.lowStockCount,
    required this.totalStockValue,
  });

  final int totalItems;
  final int lowStockCount;
  final double totalStockValue;

  factory InventoryListSummary.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return InventoryListSummary(
        totalItems: 0,
        lowStockCount: 0,
        totalStockValue: 0,
      );
    }
    return InventoryListSummary(
      totalItems: intOrNull(j['total_items']) ?? 0,
      lowStockCount: intOrNull(j['low_stock_count']) ?? 0,
      totalStockValue: numOrNull(j['total_stock_value']) ?? 0,
    );
  }
}

class InventoryListResult {
  InventoryListResult({
    required this.items,
    this.pagination,
    this.summary,
  });

  final List<InventoryItem> items;
  final PaginationMeta? pagination;
  final InventoryListSummary? summary;
}
