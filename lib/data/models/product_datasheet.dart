import '../json_helpers.dart';

class ProductDatasheetCounts {
  ProductDatasheetCounts({
    this.total = 0,
    this.draft = 0,
    this.incomplete = 0,
    this.matched = 0,
    this.ready = 0,
    this.synced = 0,
    this.error = 0,
  });

  final int total;
  final int draft;
  final int incomplete;
  final int matched;
  final int ready;
  final int synced;
  final int error;

  factory ProductDatasheetCounts.fromJson(Map<String, dynamic>? j) {
    if (j == null) return ProductDatasheetCounts();
    return ProductDatasheetCounts(
      total: intOrNull(j['total']) ?? 0,
      draft: intOrNull(j['draft']) ?? 0,
      incomplete: intOrNull(j['incomplete']) ?? 0,
      matched: intOrNull(j['matched']) ?? 0,
      ready: intOrNull(j['ready']) ?? 0,
      synced: intOrNull(j['synced']) ?? 0,
      error: intOrNull(j['error']) ?? 0,
    );
  }
}

class ProductDatasheet {
  ProductDatasheet({
    required this.id,
    this.title,
    required this.status,
    required this.counts,
    required this.rows,
  });

  final int id;
  final String? title;
  final String status;
  final ProductDatasheetCounts counts;
  final List<ProductDatasheetRow> rows;

  factory ProductDatasheet.fromJson(Map<String, dynamic> j) {
    final rawRows = j['rows'];
    final rows = <ProductDatasheetRow>[];
    if (rawRows is List) {
      for (final r in rawRows) {
        if (r is Map) {
          rows.add(ProductDatasheetRow.fromJson(Map<String, dynamic>.from(r)));
        }
      }
    }
    return ProductDatasheet(
      id: intOrNull(j['id']) ?? 0,
      title: j['title']?.toString(),
      status: j['status']?.toString() ?? 'draft',
      counts: ProductDatasheetCounts.fromJson(
        j['counts'] is Map ? Map<String, dynamic>.from(j['counts'] as Map) : null,
      ),
      rows: rows,
    );
  }
}

class ProductDatasheetRow {
  ProductDatasheetRow({
    required this.id,
    required this.datasheetId,
    required this.rowNo,
    this.name,
    this.categoryName,
    this.brandName,
    this.unitName,
    this.sku,
    this.barcode,
    this.hsnCode,
    this.description,
    this.purchasePrice,
    this.sellingPrice,
    this.mrp,
    this.stockQty,
    this.gstRate,
    this.gstType,
    this.reorderLevel,
    this.trackInventory,
    this.hasBatch,
    this.hasExpiry,
    this.isPetFood,
    this.isService,
    this.isMedicine,
    this.isActive,
    this.categoryId,
    this.brandId,
    this.unitId,
    this.matchedProductId,
    this.productId,
    required this.status,
    required this.action,
    this.validationErrors,
    this.syncedAt,
  });

  final int id;
  final int datasheetId;
  final int rowNo;
  String? name;
  String? categoryName;
  String? brandName;
  String? unitName;
  String? sku;
  String? barcode;
  String? hsnCode;
  String? description;
  double? purchasePrice;
  double? sellingPrice;
  double? mrp;
  double? stockQty;
  double? gstRate;
  String? gstType;
  double? reorderLevel;
  bool? trackInventory;
  bool? hasBatch;
  bool? hasExpiry;
  bool? isPetFood;
  bool? isService;
  bool? isMedicine;
  bool? isActive;
  int? categoryId;
  int? brandId;
  int? unitId;
  int? matchedProductId;
  int? productId;
  String status;
  String action;
  List<String>? validationErrors;
  String? syncedAt;

  factory ProductDatasheetRow.fromJson(Map<String, dynamic> j) {
    List<String>? errors;
    final rawErr = j['validation_errors'];
    if (rawErr is List) {
      errors = rawErr.map((e) => e.toString()).toList();
    }

    return ProductDatasheetRow(
      id: intOrNull(j['id']) ?? 0,
      datasheetId: intOrNull(j['datasheet_id']) ?? 0,
      rowNo: intOrNull(j['row_no']) ?? 0,
      name: j['name']?.toString(),
      categoryName: j['category_name']?.toString(),
      brandName: j['brand_name']?.toString(),
      unitName: j['unit_name']?.toString(),
      sku: j['sku']?.toString(),
      barcode: j['barcode']?.toString(),
      hsnCode: j['hsn_code']?.toString(),
      description: j['description']?.toString(),
      purchasePrice: numOrNull(j['purchase_price'])?.toDouble(),
      sellingPrice: numOrNull(j['selling_price'])?.toDouble(),
      mrp: numOrNull(j['mrp'])?.toDouble(),
      stockQty: numOrNull(j['stock_qty'])?.toDouble(),
      gstRate: numOrNull(j['gst_rate'])?.toDouble(),
      gstType: j['gst_type']?.toString(),
      reorderLevel: numOrNull(j['reorder_level'])?.toDouble(),
      trackInventory: j['track_inventory'] as bool?,
      hasBatch: j['has_batch'] as bool?,
      hasExpiry: j['has_expiry'] as bool?,
      isPetFood: j['is_pet_food'] as bool?,
      isService: j['is_service'] as bool?,
      isMedicine: j['is_medicine'] as bool?,
      isActive: j['is_active'] as bool?,
      categoryId: intOrNull(j['category_id']),
      brandId: intOrNull(j['brand_id']),
      unitId: intOrNull(j['unit_id']),
      matchedProductId: intOrNull(j['matched_product_id']),
      productId: intOrNull(j['product_id']),
      status: j['status']?.toString() ?? 'draft',
      action: j['action']?.toString() ?? 'none',
      validationErrors: errors,
      syncedAt: j['synced_at']?.toString(),
    );
  }

  void applyFrom(ProductDatasheetRow other) {
    name = other.name;
    categoryName = other.categoryName;
    brandName = other.brandName;
    unitName = other.unitName;
    sku = other.sku;
    barcode = other.barcode;
    hsnCode = other.hsnCode;
    description = other.description;
    purchasePrice = other.purchasePrice;
    sellingPrice = other.sellingPrice;
    mrp = other.mrp;
    stockQty = other.stockQty;
    gstRate = other.gstRate;
    gstType = other.gstType;
    reorderLevel = other.reorderLevel;
    trackInventory = other.trackInventory;
    hasBatch = other.hasBatch;
    hasExpiry = other.hasExpiry;
    isPetFood = other.isPetFood;
    isService = other.isService;
    isMedicine = other.isMedicine;
    isActive = other.isActive;
    categoryId = other.categoryId;
    brandId = other.brandId;
    unitId = other.unitId;
    matchedProductId = other.matchedProductId;
    productId = other.productId;
    status = other.status;
    action = other.action;
    validationErrors = other.validationErrors;
    syncedAt = other.syncedAt;
  }

  Map<String, dynamic> toPayload({bool autoSync = true, bool autoMatch = false}) {
    return {
      'name': name,
      'category_name': categoryName,
      'brand_name': brandName,
      'unit_name': unitName,
      'sku': sku,
      'barcode': barcode,
      'hsn_code': hsnCode,
      'description': description,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'mrp': mrp,
      'stock_qty': stockQty,
      'gst_rate': gstRate,
      'gst_type': gstType,
      'reorder_level': reorderLevel,
      'track_inventory': trackInventory,
      'has_batch': hasBatch,
      'has_expiry': hasExpiry,
      'is_pet_food': isPetFood,
      'is_service': isService,
      'is_medicine': isMedicine,
      'is_active': isActive,
      'category_id': categoryId,
      'brand_id': brandId,
      'unit_id': unitId,
      'auto_sync': autoSync,
      'auto_match': autoMatch,
    };
  }
}
