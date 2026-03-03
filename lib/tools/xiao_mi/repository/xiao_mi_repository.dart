import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../models/xiao_mi_conversation.dart';
import '../models/xiao_mi_message.dart';

class XiaoMiRepository {
  final Future<Database> _database;

  XiaoMiRepository({DatabaseHelper? dbHelper})
    : _database = (dbHelper ?? DatabaseHelper.instance).database;

  XiaoMiRepository.withDatabase(Database database)
    : _database = Future.value(database);

  Future<int> createConversation(XiaoMiConversation conversation) async {
    final db = await _database;
    return db.insert(
      'xiao_mi_conversations',
      conversation.toMap(includeId: false),
    );
  }

  Future<XiaoMiConversation?> getConversation(int id) async {
    final db = await _database;
    final rows = await db.query(
      'xiao_mi_conversations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return XiaoMiConversation.fromMap(rows.single);
  }

  Future<List<XiaoMiConversation>> listConversations({
    int? limit,
    int? offset,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'xiao_mi_conversations',
      orderBy: 'updated_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(XiaoMiConversation.fromMap).toList(growable: false);
  }

  Future<void> updateConversationTitle({
    required int conversationId,
    required String title,
    required DateTime now,
  }) async {
    final db = await _database;
    await db.update(
      'xiao_mi_conversations',
      <String, Object?>{
        'title': title,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> touchConversationUpdatedAt({
    required int conversationId,
    required DateTime now,
  }) async {
    final db = await _database;
    await db.update(
      'xiao_mi_conversations',
      <String, Object?>{'updated_at': now.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> deleteConversation(int conversationId) async {
    final db = await _database;
    await db.delete(
      'xiao_mi_conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<int> addMessage(XiaoMiMessage message) async {
    final db = await _database;
    return db.transaction((txn) async {
      final messageId = await txn.insert(
        'xiao_mi_messages',
        message.toMap(includeId: false),
      );
      await txn.update(
        'xiao_mi_conversations',
        <String, Object?>{
          'updated_at': message.createdAt.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [message.conversationId],
      );
      return messageId;
    });
  }

  Future<List<XiaoMiMessage>> listMessages(int conversationId) async {
    final db = await _database;
    final rows = await db.query(
      'xiao_mi_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(XiaoMiMessage.fromMap).toList(growable: false);
  }

  Future<int> deleteMessages({
    required int conversationId,
    required Iterable<int> messageIds,
    required DateTime now,
  }) async {
    final ids = messageIds.toSet();
    if (ids.isEmpty) return 0;

    final db = await _database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return db.transaction((txn) async {
      final deletedCount = await txn.delete(
        'xiao_mi_messages',
        where: 'conversation_id = ? AND id IN ($placeholders)',
        whereArgs: [conversationId, ...ids],
      );
      await txn.update(
        'xiao_mi_conversations',
        <String, Object?>{'updated_at': now.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [conversationId],
      );
      return deletedCount;
    });
  }
}
