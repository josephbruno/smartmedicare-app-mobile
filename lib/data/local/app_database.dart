import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Local persistence for offline POS (products, customers, invoice queue).
class AppDatabase {
  AppDatabase._();

  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'maran_billing.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: _createV2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS product_cache');
          await db.execute('DROP TABLE IF EXISTS customer_cache');
          await _createV2Tables(db);
        }
      },
    );
    return _db!;
  }

  static Future<void> _createV2(Database db, int version) async {
    await _createV2Tables(db);
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
