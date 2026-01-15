import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'models/tag.dart';
import 'models/tag_with_tools.dart';

class TagRepository {
  final Future<Database> _database;

  TagRepository({DatabaseHelper? dbHelper})
    : _database = (dbHelper ?? DatabaseHelper.instance).database;

  TagRepository.withDatabase(Database database)
    : _database = Future.value(database);

  Future<int> createTag({
    required String name,
    required List<String> toolIds,
    int? color,
    DateTime? now,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('createTag 需要 name');
    }
    if (toolIds.isEmpty) {
      throw ArgumentError('createTag 需要至少选择 1 个工具');
    }

    final time = now ?? DateTime.now();
    final db = await _database;
    return db.transaction((txn) async {
      final maxSortIndexRows = await txn.rawQuery(
        'SELECT MAX(sort_index) AS max_sort_index FROM tags',
      );
      final maxSortIndex =
          (maxSortIndexRows.first['max_sort_index'] as int?) ?? -1;

      final tagId = await txn.insert('tags', {
        'name': trimmed,
        'color': color,
        'sort_index': maxSortIndex + 1,
        'created_at': time.millisecondsSinceEpoch,
        'updated_at': time.millisecondsSinceEpoch,
      });

      for (final toolId in _dedupeToolIds(toolIds)) {
        await txn.insert('tool_tags', {
          'tool_id': toolId,
          'tag_id': tagId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      return tagId;
    });
  }

  Future<void> updateTag({
    required int tagId,
    required String name,
    required List<String> toolIds,
    int? color,
    DateTime? now,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('updateTag 需要 name');
    }
    if (toolIds.isEmpty) {
      throw ArgumentError('updateTag 需要至少选择 1 个工具');
    }

    final time = now ?? DateTime.now();
    final db = await _database;
    await db.transaction((txn) async {
      final updated = await txn.update(
        'tags',
        {
          'name': trimmed,
          'color': color,
          'updated_at': time.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [tagId],
      );
      if (updated <= 0) {
        throw StateError('未找到要更新的标签: id=$tagId');
      }

      await txn.delete('tool_tags', where: 'tag_id = ?', whereArgs: [tagId]);
      for (final toolId in _dedupeToolIds(toolIds)) {
        await txn.insert('tool_tags', {
          'tool_id': toolId,
          'tag_id': tagId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> deleteTag(int tagId) async {
    final db = await _database;
    await db.delete('tags', where: 'id = ?', whereArgs: [tagId]);
  }

  Future<void> reorderTags(List<int> tagIds, {DateTime? now}) async {
    final time = now ?? DateTime.now();
    final db = await _database;
    await db.transaction((txn) async {
      for (int i = 0; i < tagIds.length; i++) {
        await txn.update(
          'tags',
          {
            'sort_index': i,
            'updated_at': time.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [tagIds[i]],
        );
      }
    });
  }

  Future<List<Tag>> listTagsForTool(String toolId) async {
    final db = await _database;
    final results = await db.rawQuery(
      '''
SELECT t.*
FROM tags t
INNER JOIN tool_tags tt ON tt.tag_id = t.id
WHERE tt.tool_id = ?
ORDER BY t.sort_index ASC, t.name COLLATE NOCASE ASC
''',
      [toolId],
    );
    return results.map((e) => Tag.fromMap(e)).toList();
  }

  Future<List<TagWithTools>> listAllTagsWithTools() async {
    final db = await _database;
    final rows = await db.rawQuery('''
SELECT
  t.id AS id,
  t.name AS name,
  t.color AS color,
  t.sort_index AS sort_index,
  t.created_at AS created_at,
  t.updated_at AS updated_at,
  tt.tool_id AS tool_id
FROM tags t
LEFT JOIN tool_tags tt ON tt.tag_id = t.id
ORDER BY t.sort_index ASC, t.name COLLATE NOCASE ASC
''');

    final byId = <int, TagWithTools>{};
    for (final row in rows) {
      final tagId = row['id'] as int;
      final existing = byId[tagId];
      if (existing == null) {
        final tag = Tag.fromMap(row);
        byId[tagId] = TagWithTools(tag: tag, toolIds: []);
      }
      final toolId = row['tool_id'] as String?;
      if (toolId != null && toolId.trim().isNotEmpty) {
        byId[tagId]!.toolIds.add(toolId);
      }
    }
    return byId.values.toList();
  }

  Future<void> setTagsForWorkTask(int taskId, List<int> tagIds) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(
        'work_task_tags',
        where: 'task_id = ?',
        whereArgs: [taskId],
      );

      for (final tagId in _dedupeInts(tagIds)) {
        await txn.insert('work_task_tags', {
          'task_id': taskId,
          'tag_id': tagId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<List<int>> listTagIdsForWorkTask(int taskId) async {
    final db = await _database;
    final rows = await db.query(
      'work_task_tags',
      columns: const ['tag_id'],
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'tag_id ASC',
    );
    return rows.map((e) => e['tag_id'] as int).toList();
  }

  Future<Map<int, List<Tag>>> listTagsForWorkTasks(List<int> taskIds) async {
    final ids = _dedupeInts(taskIds).toList();
    if (ids.isEmpty) return {};

    final placeholders = List.filled(ids.length, '?').join(',');
    final db = await _database;
    final rows = await db.rawQuery('''
SELECT wtt.task_id AS task_id, t.*
FROM work_task_tags wtt
INNER JOIN tags t ON t.id = wtt.tag_id
WHERE wtt.task_id IN ($placeholders)
ORDER BY wtt.task_id ASC, t.name COLLATE NOCASE ASC
''', ids);

    final result = <int, List<Tag>>{};
    for (final row in rows) {
      final taskId = row['task_id'] as int;
      result.putIfAbsent(taskId, () => []).add(Tag.fromMap(row));
    }
    return result;
  }

  Future<List<Map<String, Object?>>> exportTags() async {
    final db = await _database;
    final rows = await db.query('tags', orderBy: 'id ASC');
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<List<Map<String, Object?>>> exportToolTags() async {
    final db = await _database;
    final rows = await db.query(
      'tool_tags',
      orderBy: 'tool_id ASC, tag_id ASC',
    );
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<List<Map<String, Object?>>> exportWorkTaskTags() async {
    final db = await _database;
    final rows = await db.query(
      'work_task_tags',
      orderBy: 'task_id ASC, tag_id ASC',
    );
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<void> importTagsFromServer({
    required List<Map<String, dynamic>> tags,
    required List<Map<String, dynamic>> toolTags,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('tool_tags');
      await txn.delete('tags');

      for (final tag in tags) {
        await txn.insert('tags', tag);
      }
      for (final link in toolTags) {
        await txn.insert(
          'tool_tags',
          link,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<void> importWorkTaskTagsFromServer(
    List<Map<String, dynamic>> links,
  ) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('work_task_tags');

      for (final link in links) {
        final taskId = link['task_id'];
        final tagId = link['tag_id'];
        if (taskId is! int || tagId is! int) continue;

        // 仅插入有效引用，避免 FK 报错导致整个导入失败
        await txn.rawInsert(
          '''
INSERT INTO work_task_tags (task_id, tag_id)
SELECT ?, ?
WHERE EXISTS(SELECT 1 FROM work_tasks WHERE id = ?)
  AND EXISTS(SELECT 1 FROM tags WHERE id = ?)
''',
          [taskId, tagId, taskId, tagId],
        );
      }
    });
  }

  static Iterable<String> _dedupeToolIds(Iterable<String> ids) sync* {
    final seen = <String>{};
    for (final raw in ids) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed)) yield trimmed;
    }
  }

  static Iterable<int> _dedupeInts(Iterable<int> values) sync* {
    final seen = <int>{};
    for (final v in values) {
      if (seen.add(v)) yield v;
    }
  }
}
