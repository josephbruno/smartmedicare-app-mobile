import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Key/value store for last-sync timestamps and counters.
class SyncMetaDao {
  Future<String?> get(String key) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final db = await AppDatabase.instance();
    await db.insert(
      'sync_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
