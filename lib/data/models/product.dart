import '../json_helpers.dart';

class ProductRef {
  ProductRef({required this.id, required this.name});

  final int id;
  final String name;
}

class Product {
  Product({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.hsnCode,
    this.description,
    this.imageUrl,
    this.categoryId,
    this.brandId,
    this.unitId,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.mrp,
    required this.gstRate,
    required this.gstType,
    required this.reorderLevel,
    required this.trackInventory,
    required this.hasBatch,
    required this.hasExpiry,
    required this.isPetFood,
    required this.isService,
    required this.isMedicine,
    this.treatmentUnderCategory,
    this.prescriptionUnderCategory,
    required this.isActive,
    this.currentStock,
    this.categoryName,
    this.brandName,
    this.unitAbbrev,
  });

  final int id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? hsnCode;
  final String? description;
  final String? imageUrl;
  final int? categoryId;
  final int? brandId;
  final int? unitId;
  final double purchasePrice;
  final double sellingPrice;
  final double mrp;
  final double gstRate;
  final String gstType;
  final int reorderLevel;
  final bool trackInventory;
  final bool hasBatch;
  final bool hasExpiry;
  final bool isPetFood;
  final bool isService;
  final bool isMedicine;
  final String? treatmentUnderCategory;
  final bool isActive;
  final double? currentStock;
  final String? categoryName;
  final String? brandName;
  final String? unitAbbrev;

  String get productType {
    if (isService) return 'service';
    if (isMedicine) return 'medicine';
    return 'product';
  }

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

  bool get isOutOfStock =>
      trackInventory && !isService && (currentStock == null || currentStock! <= 0);

  factory Product.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? nested(String key) {
      final v = j[key];
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    final cat = nested('category');
    final brand = nested('brand');
    final unit = nested('unit');

    return Product(
      id: intOrNull(j['id']) ?? 0,
      name: j['name']?.toString() ?? '',
      sku: j['sku']?.toString(),
      barcode: j['barcode']?.toString(),
      hsnCode: j['hsn_code']?.toString(),
      description: j['description']?.toString(),
      imageUrl: j['image_url']?.toString(),
      categoryId: intOrNull(cat?['id']) ?? intOrNull(j['category_id']),
      brandId: intOrNull(brand?['id']) ?? intOrNull(j['brand_id']),
      unitId: intOrNull(unit?['id']) ?? intOrNull(j['unit_id']),
      purchasePrice: numOrNull(j['purchase_price']) ?? 0,
      sellingPrice: numOrNull(j['selling_price']) ?? 0,
      mrp: numOrNull(j['mrp']) ?? 0,
      gstRate: numOrNull(j['gst_rate']) ?? 0,
      gstType: j['gst_type']?.toString() ?? 'exclusive',
      reorderLevel: intOrNull(j['reorder_level']) ?? 0,
      trackInventory: j['track_inventory'] as bool? ?? false,
      hasBatch: j['has_batch'] as bool? ?? false,
      hasExpiry: j['has_expiry'] as bool? ?? false,
      isPetFood: j['is_pet_food'] as bool? ?? false,
      isService: j['is_service'] as bool? ?? false,
      isMedicine: j['is_medicine'] as bool? ?? false,
      treatmentUnderCategory: j['treatment_under_category']?.toString(),
      prescriptionUnderCategory: j['prescription_under_category']?.toString(),
      isActive: j['is_active'] as bool? ?? true,
      currentStock: numOrNull(j['current_stock']) ?? _stockFromInventory(j['inventory']),
      categoryName: cat?['name']?.toString(),
      brandName: brand?['name']?.toString(),
      unitAbbrev: unit?['abbreviation']?.toString(),
    );
  }

  static double? _stockFromInventory(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    var total = 0.0;
    var sawQty = false;
    for (final row in raw) {
      if (row is! Map) continue;
      final qty = numOrNull(row['quantity']);
      if (qty == null) continue;
      sawQty = true;
      total += qty;
    }
    return sawQty ? total : null;
  }
}

class Category {
  Category({
    required this.id,
    required this.name,
    this.slug,
    this.parentId,
    required this.isActive,
  });

  final int id;
  final String name;
  final String? slug;
  final int? parentId;
  final bool isActive;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: intOrNull(j['id']) ?? 0,
        name: j['name']?.toString() ?? '',
        slug: j['slug']?.toString(),
        parentId: intOrNull(j['parent_id']),
        isActive: j['is_active'] as bool? ?? true,
      );
}

class Brand {
  Brand({
    required this.id,
    required this.name,
    this.slug,
    required this.isActive,
  });

  final int id;
  final String name;
  final String? slug;
  final bool isActive;

  factory Brand.fromJson(Map<String, dynamic> j) => Brand(
        id: intOrNull(j['id']) ?? 0,
        name: j['name']?.toString() ?? '',
        slug: j['slug']?.toString(),
        isActive: j['is_active'] as bool? ?? true,
      );
}

class Unit {
  Unit({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.isActive,
  });

  final int id;
  final String name;
  final String abbreviation;
  final bool isActive;

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
        id: intOrNull(j['id']) ?? 0,
        name: j['name']?.toString() ?? '',
        abbreviation: j['abbreviation']?.toString() ?? '',
        isActive: j['is_active'] as bool? ?? true,
      );
}
