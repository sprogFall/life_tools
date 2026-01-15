import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../models/tag_model.dart';
import 'tag_repository_base.dart';

class TagRepository implements TagRepositoryBase {
  final Future<Database> _database;

  TagRepository({DatabaseHelper? dbHelper})
    : _database = (dbHelper ?? DatabaseHelper.instance).database;

  TagRepository.withDatabase(Database database)
    : _database = Future.value(database);

  @override
  Future<int> createTag(Tag tag) async {
    final db = await _database;
    return db.insert('tags', tag.toMap(includeId: false));
  }

  @override
  Future<Tag?> getTag(int id) async {
    final db = await _database;
    final results = await db.query(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Tag.fromMap(results.first);
  }

  @override
  Future<List<Tag>> listAllTags() async {
    final db = await _database;
    final results = await db.query('tags', orderBy: 'name ASC');
    return results.map(Tag.fromMap).toList();
  }

  @override
  Future<List<Tag>> listTagsByToolId(String toolId) async {
    final db = await _database;
    final results = await db.rawQuery('''
      SELECT t.* FROM tags t
      INNER JOIN tag_tool_associations tta ON t.id = tta.tag_id
      WHERE tta.tool_id = ?
      ORDER BY t.name ASC
    ''', [toolId]);
    return results.map(Tag.fromMap).toList();
  }

  @override
  Future<void> updateTag(Tag tag) async {
    final id = tag.id;
    if (id == null) {
      throw ArgumentError('updateTag 需要 tag.id');
    }
    final db = await _database;
    await db.update(
      'tags',
      tag.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteTag(int id) async {
    final db = await _database;
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int?> getTagIdByName(String name) async {
    final db = await _database;
    final results = await db.query(
      'tags',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['id'] as int?;
  }

  @override
  Future<void> associateTagWithTool(int tagId, String toolId) async {
    final db = await _database;
    final association = TagToolAssociation.create(
      tagId: tagId,
      toolId: toolId,
    );
    await db.insert('tag_tool_associations', association.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<void> disassociateTagFromTool(int tagId, String toolId) async {
    final db = await _database;
    await db.delete(
      'tag_tool_associations',
      where: 'tag_id = ? AND tool_id = ?',
      whereArgs: [tagId, toolId],
    );
  }

  @override
  Future<List<String>> getToolIdsForTag(int tagId) async {
    final db = await _database;
    final results = await db.query(
      'tag_tool_associations',
      columns: ['tool_id'],
      where: 'tag_id = ?',
      whereArgs: [tagId],
    );
    return results.map((row) => row['tool_id'] as String).toList();
  }

  @override
  Future<void> associateTagWithTask(int tagId, int taskId) async {
    final db = await _database;
    await db.insert(
      'work_task_tags',
      {
        'tag_id': tagId,
        'task_id': taskId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> disassociateTagFromTask(int tagId, int taskId) async {
    final db = await _database;
    await db.delete(
      'work_task_tags',
      where: 'tag_id = ? AND task_id = ?',
      whereArgs: [tagId, taskId],
    );
  }

  @override
  Future<List<Tag>> getTagsForTask(int taskId) async {
    final db = await _database;
    final results = await db.rawQuery('''
      SELECT t.* FROM tags t
      INNER JOIN work_task_tags wtt ON t.id = wtt.tag_id
      WHERE wtt.task_id = ?
      ORDER BY t.name ASC
    ''', [taskId]);
    return results.map(Tag.fromMap).toList();
  }

  @override
  Future<List<int>> getTaskIdsForTag(int tagId) async {
    final db = await _database;
    final results = await db.query(
      'work_task_tags',
      columns: ['task_id'],
      where: 'tag_id = ?',
      whereArgs: [tagId],
    );
    return results.map((row) => row['task_id'] as int).toList();
  }

  @override
  Future<void> importTagsFromServer(List<Map<String, dynamic>> tagsData) async {
    final db = await _database;

    await db.transaction((txn) async {
      for (final tagMap in tagsData) {
        await txn.insert('tags', tagMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  @override
  Future<void> importTagToolAssociationsFromServer(
    List<Map<String, dynamic>> associationsData,
  ) async {
    final db = await _database;

    await db.transaction((txn) async {
      for (final associationMap in associationsData) {
        await txn.insert(
          'tag_tool_associations',
          associationMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> importWorkTaskTagsFromServer(
    List<Map<String, dynamic>> taskTagsData,
  ) async {
    final db = await _database;

    await db.transaction((txn) async {
      for (final taskTagMap in taskTagsData) {
        await txn.insert(
          'work_task_tags',
          taskTagMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}