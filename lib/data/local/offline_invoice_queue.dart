import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class OfflineQueueEntry {
  OfflineQueueEntry({
    required this.offlineId,
    required this.payload,
    required this.createdAt,
  });

  final String offlineId;
  final Map<String, dynamic> payload;
  final String createdAt;
}

class OfflineInvoiceQueue {
  OfflineInvoiceQueue();

  Future<void> enqueue(String offlineId, Map<String, dynamic> payload) async {
    final db = await AppDatabase.instance();
    await db.insert(
      'offline_invoices',
      {
        'offline_id': offlineId,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> pendingPayloads() async {
    final db = await AppDatabase.instance();
    final rows = await db.query('offline_invoices', orderBy: 'id ASC');
    return rows
        .map((r) => jsonDecode(r['payload'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<List<OfflineQueueEntry>> pendingEntries() async {
    final db = await AppDatabase.instance();
    final rows = await db.query('offline_invoices', orderBy: 'id ASC');
    return rows
        .map(
          (r) => OfflineQueueEntry(
            offlineId: r['offline_id'] as String,
            payload: jsonDecode(r['payload'] as String) as Map<String, dynamic>,
            createdAt: r['created_at'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<int> pendingCount() async {
    final db = await AppDatabase.instance();
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM offline_invoices');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<void> clearAll() async {
    final db = await AppDatabase.instance();
    await db.delete('offline_invoices');
  }

  Future<void> removeByOfflineIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await AppDatabase.instance();
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      'offline_invoices',
      where: 'offline_id IN ($placeholders)',
      whereArgs: ids,
    );
  }
}
