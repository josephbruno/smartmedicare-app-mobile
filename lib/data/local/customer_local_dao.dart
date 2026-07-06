import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/customer.dart';
import 'app_database.dart';

class CustomerLocalDao {
  Future<void> upsertAll(List<Customer> customers) async {
    if (customers.isEmpty) return;
    final db = await AppDatabase.instance();
    final batch = db.batch();
    final now = DateTime.now().toUtc().toIso8601String();
    for (final c in customers) {
      batch.insert(
        'customers',
        {
          'id': c.id,
          'name': c.name,
          'phone': c.phone,
          'email': c.email,
          'is_active': c.isActive ? 1 : 0,
          'json': jsonEncode(c.toJson()),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Customer>> search(String term, {int limit = 20}) async {
    final q = term.trim();
    if (q.isEmpty) return listRecent(limit: limit);

    final db = await AppDatabase.instance();
    final like = '%$q%';
    final rows = await db.query(
      'customers',
      where: '''
        is_active = 1 AND (
          name LIKE ? COLLATE NOCASE OR
          phone LIKE ? OR
          IFNULL(email, '') LIKE ? COLLATE NOCASE
        )
      ''',
      whereArgs: [like, like, like],
      orderBy: 'name COLLATE NOCASE ASC',
      limit: limit,
    );
    return _rowsToCustomers(rows);
  }

  Future<List<Customer>> listRecent({int limit = 30}) async {
    final db = await AppDatabase.instance();
    final rows = await db.query(
      'customers',
      where: 'is_active = 1',
      orderBy: 'name COLLATE NOCASE ASC',
      limit: limit,
    );
    return _rowsToCustomers(rows);
  }

  List<Customer> _rowsToCustomers(List<Map<String, Object?>> rows) {
    return rows
        .map((r) {
          final raw = jsonDecode(r['json'] as String);
          if (raw is! Map) return null;
          return Customer.fromJson(Map<String, dynamic>.from(raw));
        })
        .whereType<Customer>()
        .toList();
  }
}
