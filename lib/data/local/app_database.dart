import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Local persistence for offline POS (products, customers, invoice queue).
///
/// One database file per organization, so cached customers/products and
/// queued offline invoices never surface (or sync) under another
/// organization's login on the same device.
class AppDatabase {
  AppDatabase._();

  static const _legacyFileName = 'maran_billing.db';

  static Database? _db;
  static int? _shopId;

  /// Switch the local store to [shopId]'s database (null = signed out).
  /// Call on login, session restore and logout.
  static Future<void> useShop(int? shopId) async {
    if (shopId == _shopId) return;
    final previous = _db;
    _db = null;
    _shopId = shopId;
    await previous?.close();
  }

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final shopId = _shopId;
    final path = p.join(
      dir.path,
      shopId == null ? 'maran_billing_no_shop.db' : 'maran_billing_shop_$shopId.db',
    );
    if (shopId != null) {
      await _adoptLegacyDatabase(dir.path, path);
    }
    final db = await openDatabase(
      path,
      version: 4,
      onCreate: _createV3,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS product_cache');
          await db.execute('DROP TABLE IF EXISTS customer_cache');
          await _createV2Tables(db);
        }
        // v3+: is_medicine (idempotent — safe if CREATE already included it)
        if (oldVersion < 4) {
          await _ensureProductColumns(db);
        }
      },
      onOpen: (db) async {
        // Repair drifted Windows DBs where user_version advanced without ALTER.
        await _ensureProductColumns(db);
      },
    );
    // The organization changed while opening: this file is no longer current.
    if (_shopId != shopId) {
      await db.close();
      return instance();
    }
    _db = db;
    return db;
  }

  /// Pre-isolation installs kept one shared file. Hand it to the first
  /// organization that signs in so its unsynced offline invoices are kept.
  static Future<void> _adoptLegacyDatabase(String dir, String target) async {
    final legacy = File(p.join(dir, _legacyFileName));
    if (!await legacy.exists() || await File(target).exists()) return;
    try {
      await legacy.rename(target);
    } catch (_) {
      // Leave it in place; the organization starts with an empty cache.
    }
  }

  static Future<void> _createV3(Database db, int version) async {
    await _createV2Tables(db);
  }

  /// Adds missing product columns without failing on duplicates.
  static Future<void> _ensureProductColumns(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(products)');
    if (cols.isEmpty) return;
    final names = cols.map((r) => r['name'] as String).toSet();
    if (!names.contains('is_medicine')) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN is_medicine INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  static Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        offline_id TEXT NOT NULL UNIQUE,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        sku TEXT,
        barcode TEXT,
        selling_price REAL NOT NULL DEFAULT 0,
        mrp REAL NOT NULL DEFAULT 0,
        gst_rate REAL NOT NULL DEFAULT 0,
        gst_type TEXT NOT NULL DEFAULT 'exclusive',
        track_inventory INTEGER NOT NULL DEFAULT 0,
        is_service INTEGER NOT NULL DEFAULT 0,
        is_medicine INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        reorder_level INTEGER NOT NULL DEFAULT 0,
        current_stock REAL,
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (id, branch_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_branch_name ON products(branch_id, name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_branch_barcode ON products(branch_id, barcode)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_branch_sku ON products(branch_id, sku)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
