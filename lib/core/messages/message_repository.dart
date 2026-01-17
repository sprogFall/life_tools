import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'models/app_message.dart';

class MessageRepository {
  final Future<Database> _database;

  MessageRepository({DatabaseHelper? dbHelper})
      : _database = (dbHelper ?? DatabaseHelper.instance).database;

  MessageRepository.withDatabase(Database database)
      : _database = Future.value(database);

  Future<int?> upsertMessage({
    required String toolId,
    required String title,
    required String body,
    String? dedupeKey,
    String? route,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool markUnreadOnUpdate = true,
  }) async {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      throw ArgumentError('upsertMessage: body 不能为空');
    }

    final db = await _database;
    final time = createdAt ?? DateTime.now();

    final baseValues = <String, Object?>{
      'tool_id': toolId,
      'title': title,
      'body': trimmedBody,
      'route': route,
      'dedupe_key': dedupeKey,
      'created_at': time.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
    };

    if (dedupeKey == null) {
      final id = await db.insert('app_messages', {
        ...baseValues,
        'is_read': 0,
        'read_at': null,
      });
      if (id <= 0) return null;
      return id;
    }

    final existing = await db.query(
      'app_messages',
      columns: const ['id'],
      where: 'dedupe_key = ?',
      whereArgs: [dedupeKey],
      limit: 1,
    );

    if (existing.isEmpty) {
      final id = await db.insert('app_messages', {
        ...baseValues,
        'is_read': 0,
        'read_at': null,
      });
      if (id <= 0) return null;
      return id;
    }

    final id = existing.first['id'] as int;
    final updateValues = <String, Object?>{...baseValues};
    if (markUnreadOnUpdate) {
      updateValues['is_read'] = 0;
      updateValues['read_at'] = null;
    }

    await db.update(
      'app_messages',
      updateValues,
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<List<AppMessage>> listMessages({
    int limit = 20,
    bool includeRead = true,
    DateTime? now,
  }) async {
    final db = await _database;
    final where = <String>[];
    final whereArgs = <Object?>[];

    if (!includeRead) {
      where.add('is_read = 0');
    }
    if (now != null) {
      where.add('(expires_at IS NULL OR expires_at > ?)');
      whereArgs.add(now.millisecondsSinceEpoch);
    }

    final rows = await db.query(
      'app_messages',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map((e) => AppMessage.fromMap(e)).toList();
  }

  Future<void> markRead(int id, {DateTime? readAt}) async {
    final db = await _database;
    await db.update(
      'app_messages',
      {
        'is_read': 1,
        'read_at': (readAt ?? DateTime.now()).millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteById(int id) async {
    final db = await _database;
    await db.delete('app_messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByDedupeKey(String dedupeKey) async {
    final db = await _database;
    await db.delete(
      'app_messages',
      where: 'dedupe_key = ?',
      whereArgs: [dedupeKey],
    );
  }

  Future<int> deleteExpired(DateTime now) async {
    final db = await _database;
    return db.delete(
      'app_messages',
      where: 'expires_at IS NOT NULL AND expires_at <= ?',
      whereArgs: [now.millisecondsSinceEpoch],
    );
  }
}

