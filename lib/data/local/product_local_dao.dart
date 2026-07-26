import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/product.dart';
import 'app_database.dart';

class ProductLocalDao {
  Future<int> countForBranch(int branchId) async {
    final db = await AppDatabase.instance();
    final r = await db.rawQuery(
      'SELECT COUNT(*) as c FROM products WHERE branch_id = ? AND is_active = 1',
      [branchId],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<void> upsertAll(List<Product> products, int branchId) async {
    if (products.isEmpty) return;
    final db = await AppDatabase.instance();
    final batch = db.batch();
    final now = DateTime.now().toUtc().toIso8601String();
    for (final p in products) {
      final json = jsonEncode(_productToStorageJson(p));
      batch.insert(
        'products',
        {
          'id': p.id,
          'branch_id': branchId,
          'name': p.name,
          'sku': p.sku,
          'barcode': p.barcode,
          'selling_price': p.sellingPrice,
          'mrp': p.mrp,
          'gst_rate': p.gstRate,
          'gst_type': p.gstType,
          'track_inventory': p.trackInventory ? 1 : 0,
          'is_service': p.isService ? 1 : 0,
          'is_medicine': p.isMedicine ? 1 : 0,
          'is_active': p.isActive ? 1 : 0,
          'reorder_level': p.reorderLevel,
          'current_stock': p.currentStock,
          'json': json,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Product>> listRecent(int branchId, {int limit = 50}) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'products',
      where: 'branch_id = ? AND is_active = 1',
      whereArgs: [branchId],
      orderBy: 'name COLLATE NOCASE ASC',
      limit: limit,
    );
    return _rowsToProducts(rows);
  }

  Future<List<Product>> search(
    int branchId,
    String term, {
    int limit = 30,
  }) async {
    final q = term.trim();
    if (q.isEmpty) return listRecent(branchId, limit: limit);

    final db = await AppDatabase.instance();
    final isShort = q.length <= 2;
    final like = isShort ? '$q%' : '%$q%';

    final rows = await db.query(
      'products',
      where: '''
        branch_id = ? AND is_active = 1 AND (
          name LIKE ? COLLATE NOCASE OR
          barcode = ? OR
          sku = ? COLLATE NOCASE
        )
      ''',
      whereArgs: [branchId, like, q, q],
      orderBy: 'name COLLATE NOCASE ASC',
      limit: limit,
    );
    return _rowsToProducts(rows);
  }

  Future<Product?> findByBarcode(int branchId, String barcode) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'products',
      where: 'branch_id = ? AND barcode = ? AND is_active = 1',
      whereArgs: [branchId, barcode],
      limit: 1,
    );
    final list = _rowsToProducts(rows);
    return list.isEmpty ? null : list.first;
  }

  Future<Product?> findById(int branchId, int productId) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'products',
      where: 'branch_id = ? AND id = ? AND is_active = 1',
      whereArgs: [branchId, productId],
      limit: 1,
    );
    final list = _rowsToProducts(rows);
    return list.isEmpty ? null : list.first;
  }

  /// Removes local products for [branchId] that are not in [keepIds].
  /// Used after a full catalog sync so deleted/replaced products disappear.
  Future<int> pruneBranchExcept(int branchId, Set<int> keepIds) async {
    final db = await AppDatabase.instance();
    if (keepIds.isEmpty) {
      return db.delete('products', where: 'branch_id = ?', whereArgs: [branchId]);
    }

    // SQLite variable limit ~999; chunk the NOT IN list.
    const chunkSize = 400;
    final keep = keepIds.toList();
    var deleted = 0;

    // Delete in one pass when small enough.
    if (keep.length <= chunkSize) {
      final placeholders = List.filled(keep.length, '?').join(',');
      deleted = await db.delete(
        'products',
        where: 'branch_id = ? AND id NOT IN ($placeholders)',
        whereArgs: [branchId, ...keep],
      );
      return deleted;
    }

    // Large catalogs: load local ids then delete missing.
    final rows = await db.query(
      'products',
      columns: ['id'],
      where: 'branch_id = ?',
      whereArgs: [branchId],
    );
    final localIds = rows.map((r) => r['id'] as int).toSet();
    final toDelete = localIds.difference(keepIds).toList();
    for (var i = 0; i < toDelete.length; i += chunkSize) {
      final chunk = toDelete.sublist(
        i,
        i + chunkSize > toDelete.length ? toDelete.length : i + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      deleted += await db.delete(
        'products',
        where: 'branch_id = ? AND id IN ($placeholders)',
        whereArgs: [branchId, ...chunk],
      );
    }
    return deleted;
  }

  /// Marks products inactive locally (keeps row for delta continuity).
  Future<void> markInactive(int branchId, Iterable<int> productIds) async {
    final ids = productIds.toList();
    if (ids.isEmpty) return;
    final db = await AppDatabase.instance();
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE products SET is_active = 0, updated_at = ? WHERE branch_id = ? AND id IN ($placeholders)',
      [DateTime.now().toUtc().toIso8601String(), branchId, ...ids],
    );
  }

  /// Optimistic stock decrement after offline checkout.
  Future<void> adjustStock(int branchId, int productId, double delta) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'products',
      where: 'branch_id = ? AND id = ?',
      whereArgs: [branchId, productId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    final stock = (row['current_stock'] as num?)?.toDouble();
    if (stock == null) return;

    final next = (stock + delta).clamp(0.0, double.infinity).toDouble();
    final product = Product.fromJson(
      jsonDecode(row['json'] as String) as Map<String, dynamic>,
    );
    final updated = Product(
      id: product.id,
      name: product.name,
      sku: product.sku,
      barcode: product.barcode,
      hsnCode: product.hsnCode,
      description: product.description,
      imageUrl: product.imageUrl,
      purchasePrice: product.purchasePrice,
      sellingPrice: product.sellingPrice,
      mrp: product.mrp,
      gstRate: product.gstRate,
      gstType: product.gstType,
      reorderLevel: product.reorderLevel,
      trackInventory: product.trackInventory,
      hasBatch: product.hasBatch,
      hasExpiry: product.hasExpiry,
      isPetFood: product.isPetFood,
      isService: product.isService,
      isMedicine: product.isMedicine,
      isActive: product.isActive,
      currentStock: next,
      categoryName: product.categoryName,
      brandName: product.brandName,
      unitAbbrev: product.unitAbbrev,
    );
    await upsertAll([updated], branchId);
  }

  List<Product> _rowsToProducts(List<Map<String, Object?>> rows) {
    return rows
        .map((r) {
          final raw = jsonDecode(r['json'] as String);
          if (raw is! Map) return null;
          final map = Map<String, dynamic>.from(raw);
          final stock = (r['current_stock'] as num?)?.toDouble();
          if (stock != null) {
            map['current_stock'] = stock;
          }
          return Product.fromJson(map);
        })
        .whereType<Product>()
        .toList();
  }

  Map<String, dynamic> _productToStorageJson(Product p) => {
        'id': p.id,
        'name': p.name,
        if (p.sku != null) 'sku': p.sku,
        if (p.barcode != null) 'barcode': p.barcode,
        if (p.hsnCode != null) 'hsn_code': p.hsnCode,
        if (p.description != null) 'description': p.description,
        if (p.imageUrl != null) 'image_url': p.imageUrl,
        'purchase_price': p.purchasePrice,
        'selling_price': p.sellingPrice,
        'mrp': p.mrp,
        'gst_rate': p.gstRate,
        'gst_type': p.gstType,
        'reorder_level': p.reorderLevel,
        'track_inventory': p.trackInventory,
        'has_batch': p.hasBatch,
        'has_expiry': p.hasExpiry,
        'is_pet_food': p.isPetFood,
        'is_service': p.isService,
        'is_medicine': p.isMedicine,
        'is_active': p.isActive,
        if (p.currentStock != null) 'current_stock': p.currentStock,
        if (p.categoryName != null)
          'category': {'name': p.categoryName},
        if (p.brandName != null) 'brand': {'name': p.brandName},
        if (p.unitAbbrev != null)
          'unit': {'abbreviation': p.unitAbbrev},
      };
}
