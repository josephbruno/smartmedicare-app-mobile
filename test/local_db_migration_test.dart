import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _ensureProductColumns(Database db) async {
  final cols = await db.rawQuery('PRAGMA table_info(products)');
  if (cols.isEmpty) return;
  final names = cols.map((r) => r['name'] as String).toSet();
  if (!names.contains('is_medicine')) {
    await db.execute(
      'ALTER TABLE products ADD COLUMN is_medicine INTEGER NOT NULL DEFAULT 0',
    );
  }
}

/// Exercises SQLite upgrades used by offline POS (incl. Windows ffi).
Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('upgrades local database from v1 to v2', () async {
    final dbPath = p.join(Directory.systemTemp.path, 'maran_billing_migration_test.db');
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }

    var db = await openDatabase(dbPath, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE offline_invoices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          offline_id TEXT NOT NULL UNIQUE,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE product_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          query TEXT NOT NULL,
          json TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE customer_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          query TEXT NOT NULL,
          json TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    });
    await db.close();

    db = await openDatabase(
      dbPath,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS product_cache');
          await db.execute('DROP TABLE IF EXISTS customer_cache');
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
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sync_meta (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
      },
    );

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );
    final names = tables.map((r) => r['name'] as String).toList();

    expect(names, contains('products'));
    expect(names, contains('customers'));
    expect(names, contains('sync_meta'));
    expect(names, contains('offline_invoices'));
    expect(names, isNot(contains('product_cache')));
    expect(names, isNot(contains('customer_cache')));

    await db.close();
    await file.delete();
  });

  test('adds is_medicine to v2 products and is idempotent', () async {
    final dbPath = p.join(
      Directory.systemTemp.path,
      'maran_billing_is_medicine_repair_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final file = File(dbPath);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });

    // Historical v2 schema (no is_medicine).
    var db = await openDatabase(dbPath, version: 2, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE products (
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
    });
    await db.close();

    // Same path AppDatabase uses for v2 → v4 / onOpen repair.
    db = await openDatabase(
      dbPath,
      version: 4,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          await _ensureProductColumns(db);
        }
      },
      onOpen: _ensureProductColumns,
    );

    final cols = await db.rawQuery('PRAGMA table_info(products)');
    final names = cols.map((r) => r['name'] as String).toSet();
    expect(names, contains('is_medicine'));

    // onOpen + explicit ensure must not throw duplicate column.
    await _ensureProductColumns(db);

    await db.insert('products', {
      'id': 1,
      'branch_id': 1,
      'name': 'Dog Bone',
      'selling_price': 120,
      'mrp': 120,
      'gst_rate': 5,
      'gst_type': 'exclusive',
      'track_inventory': 1,
      'is_service': 0,
      'is_medicine': 0,
      'is_active': 1,
      'reorder_level': 0,
      'current_stock': 0,
      'json': '{}',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await db.close();
  });

  test('v1 upgrade that already created is_medicine does not crash on ensure', () async {
    final dbPath = p.join(
      Directory.systemTemp.path,
      'maran_billing_v1_dup_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final file = File(dbPath);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });

    var db = await openDatabase(dbPath, version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE product_cache (id INTEGER PRIMARY KEY)');
    });
    await db.close();

    db = await openDatabase(
      dbPath,
      version: 4,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS product_cache');
          // Current CREATE already includes is_medicine (the old bug path).
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
        }
        if (oldVersion < 4) {
          await _ensureProductColumns(db);
        }
      },
    );

    final cols = await db.rawQuery('PRAGMA table_info(products)');
    expect(cols.map((r) => r['name'] as String), contains('is_medicine'));
    await db.close();
  });
}
