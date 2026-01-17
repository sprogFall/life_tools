import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'models/app_message.dart';

class MessageRepository {
  final Future<Database> _database;

  MessageRepository({DatabaseHelper? dbHelper})
    : _database = (dbHelper ?? DatabaseHelper.instance).database;

  MessageRepository.withDatabase(Database database)
    : _database = Future.value(database);

  Future<int?> createMessage({
    required String toolId,
    required String title,
    required String body,
    String? dedupeKey,
    DateTime? createdAt,
  }) async {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      throw ArgumentError('createMessage 需要 body');
    }
    final db = await _database;
    final id = await db.insert(
      'app_messages',
      {
        'tool_id': toolId,
        'title': title,
        'body': trimmedBody,
        'dedupe_key': dedupeKey,
        'created_at': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (id <= 0) return null;
    return id;
  }

  Future<List<AppMessage>> listMessages({int limit = 20}) async {
    final db = await _database;
    final rows = await db.query(
      'app_messages',
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map((e) => AppMessage.fromMap(e)).toList();
  }
}

