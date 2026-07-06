import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises the v1 → v2 SQLite upgrade used by offline POS.
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
}
