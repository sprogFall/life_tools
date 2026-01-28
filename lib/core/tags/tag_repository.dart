import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import 'models/tag.dart';
import 'models/tag_in_tool_category.dart';
import 'models/tag_with_tools.dart';

class _ToolTagLink {
  final String toolId;
  final String categoryId;

  const _ToolTagLink({required this.toolId, required this.categoryId});
}

class TagRepository {
  final Future<Database> _database;

  static const String defaultCategoryId = 'default';

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
    return _createTagInternal(
      name: name,
      toolLinks: [
        for (final toolId in _dedupeToolIds(toolIds))
          _ToolTagLink(toolId: toolId, categoryId: defaultCategoryId),
      ],
      color: color,
      now: now,
    );
  }

  Future<int> createTagForToolCategory({
    required String name,
    required String toolId,
    required String categoryId,
    int? color,
    DateTime? now,
  }) async {
    final normalizedToolId = toolId.trim();
    if (normalizedToolId.isEmpty) {
      throw ArgumentError('createTagForToolCategory 需要 toolId');
    }
    final normalizedCategoryId = categoryId.trim().isEmpty
        ? defaultCategoryId
        : categoryId.trim();

    return _createTagInternal(
      name: name,
      toolLinks: [
        _ToolTagLink(
          toolId: normalizedToolId,
          categoryId: normalizedCategoryId,
        ),
      ],
      color: color,
      now: now,
    );
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
      final existingLinks = await txn.query(
        'tool_tags',
        columns: const ['tool_id', 'category_id', 'sort_index'],
        where: 'tag_id = ?',
        whereArgs: [tagId],
      );
      final linkByTool = <String, ({String categoryId, int sortIndex})>{};
      for (final row in existingLinks) {
        final toolId = row['tool_id'] as String;
        final raw = row['category_id'] as String?;
        final normalized = raw?.trim();
        final categoryId = (normalized == null || normalized.isEmpty)
            ? defaultCategoryId
            : normalized;
        final sortIndex = (row['sort_index'] as int?) ?? 0;
        linkByTool[toolId] = (categoryId: categoryId, sortIndex: sortIndex);
      }

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
        final existing = linkByTool[toolId];
        final categoryId = existing?.categoryId ?? defaultCategoryId;
        final sortIndex =
            existing?.sortIndex ??
            await _nextToolTagSortIndex(
              txn,
              toolId: toolId,
              categoryId: categoryId,
            );
        await txn.insert('tool_tags', {
          'tool_id': toolId,
          'tag_id': tagId,
          'category_id': categoryId,
          'sort_index': sortIndex,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> renameTag({
    required int tagId,
    required String name,
    DateTime? now,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('renameTag 需要 name');
    }

    final time = now ?? DateTime.now();
    final db = await _database;
    final updated = await db.update(
      'tags',
      {'name': trimmed, 'updated_at': time.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [tagId],
    );
    if (updated <= 0) {
      throw StateError('未找到要更新的标签: id=$tagId');
    }
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
          {'sort_index': i, 'updated_at': time.millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [tagIds[i]],
        );
      }
    });
  }

  Future<void> reorderToolCategoryTags({
    required String toolId,
    required String categoryId,
    required List<int> tagIds,
    DateTime? now,
  }) async {
    final normalizedToolId = toolId.trim();
    if (normalizedToolId.isEmpty) {
      throw ArgumentError('reorderToolCategoryTags 需要 toolId');
    }
    final normalizedCategoryId = categoryId.trim().isEmpty
        ? defaultCategoryId
        : categoryId.trim();

    final ids = _dedupeInts(tagIds).toList();
    if (ids.isEmpty) return;

    final time = now ?? DateTime.now();
    final db = await _database;
    await db.transaction((txn) async {
      for (int i = 0; i < ids.length; i++) {
        await txn.update(
          'tool_tags',
          {'sort_index': i},
          where: 'tool_id = ? AND category_id = ? AND tag_id = ?',
          whereArgs: [normalizedToolId, normalizedCategoryId, ids[i]],
        );
      }

      // 作为“变更标记”：同步更新关联 tags 的 updated_at，方便后续排查与备份一致性
      final updatedAt = time.millisecondsSinceEpoch;
      for (final id in ids) {
        await txn.update(
          'tags',
          {'updated_at': updatedAt},
          where: 'id = ?',
          whereArgs: [id],
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
ORDER BY tt.category_id ASC, tt.sort_index ASC, t.name COLLATE NOCASE ASC
''',
      [toolId],
    );
    return results.map((e) => Tag.fromMap(e)).toList();
  }

  /// 将某个工具下的标签从一个分类迁移到另一个分类（仅修改 tool_tags）。
  ///
  /// 主要用于：早期只有“默认”分类时，后续引入更明确的分类后做无感升级。
  /// 返回迁移的条数。
  Future<int> migrateToolTagCategory({
    required String toolId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {
    final normalizedToolId = toolId.trim();
    if (normalizedToolId.isEmpty) {
      throw ArgumentError('migrateToolTagCategory 需要 toolId');
    }
    final from = fromCategoryId.trim().isEmpty
        ? defaultCategoryId
        : fromCategoryId.trim();
    final to = toCategoryId.trim().isEmpty
        ? defaultCategoryId
        : toCategoryId.trim();
    if (from == to) return 0;

    final db = await _database;
    return db.transaction((txn) async {
      final maxRows = await txn.rawQuery(
        '''
SELECT MAX(sort_index) AS max_sort_index
FROM tool_tags
WHERE tool_id = ? AND category_id = ?
''',
        [normalizedToolId, to],
      );
      var nextSortIndex = ((maxRows.first['max_sort_index'] as int?) ?? -1) + 1;

      final rows = await txn.rawQuery(
        '''
SELECT tag_id, sort_index
FROM tool_tags
WHERE tool_id = ? AND category_id = ?
ORDER BY sort_index ASC, tag_id ASC
''',
        [normalizedToolId, from],
      );
      if (rows.isEmpty) return 0;

      var migrated = 0;
      for (final row in rows) {
        final tagId = row['tag_id'] as int;
        final updated = await txn.update(
          'tool_tags',
          {'category_id': to, 'sort_index': nextSortIndex++},
          where: 'tool_id = ? AND tag_id = ? AND category_id = ?',
          whereArgs: [normalizedToolId, tagId, from],
        );
        if (updated > 0) migrated += 1;
      }
      return migrated;
    });
  }

  Future<List<TagInToolCategory>> listTagsForToolWithCategory(
    String toolId,
  ) async {
    final normalized = toolId.trim();
    if (normalized.isEmpty) return const [];

    final db = await _database;
    final results = await db.rawQuery(
      '''
SELECT t.*, tt.category_id AS category_id
FROM tags t
INNER JOIN tool_tags tt ON tt.tag_id = t.id
WHERE tt.tool_id = ?
ORDER BY tt.category_id ASC, tt.sort_index ASC, t.name COLLATE NOCASE ASC
''',
      [normalized],
    );

    return results.map((row) {
      final raw = row['category_id'] as String?;
      final categoryId = (raw == null || raw.trim().isEmpty)
          ? defaultCategoryId
          : raw.trim();
      return TagInToolCategory(tag: Tag.fromMap(row), categoryId: categoryId);
    }).toList();
  }

  Future<List<Tag>> listTagsByIds(List<int> tagIds) async {
    final ids = _dedupeInts(tagIds).toList();
    if (ids.isEmpty) return const [];

    final placeholders = List.filled(ids.length, '?').join(',');
    final db = await _database;
    final rows = await db.rawQuery('''
SELECT *
FROM tags
WHERE id IN ($placeholders)
ORDER BY sort_index ASC, name COLLATE NOCASE ASC
''', ids);
    return rows.map((e) => Tag.fromMap(e)).toList();
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
    await _setTagsForEntity(
      table: 'work_task_tags',
      entityIdColumn: 'task_id',
      entityId: taskId,
      tagIds: tagIds,
    );
  }

  Future<List<int>> listTagIdsForWorkTask(int taskId) async {
    return _listTagIdsForEntity(
      table: 'work_task_tags',
      entityIdColumn: 'task_id',
      entityId: taskId,
    );
  }

  Future<Map<int, List<Tag>>> listTagsForWorkTasks(List<int> taskIds) async {
    return _listTagsForEntities(
      table: 'work_task_tags',
      entityIdColumn: 'task_id',
      entityIds: taskIds,
    );
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
    return _exportEntityTags(
      table: 'work_task_tags',
      entityIdColumn: 'task_id',
    );
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
        final normalized = Map<String, dynamic>.from(link);
        normalized['category_id'] ??= defaultCategoryId;
        normalized['sort_index'] ??= 0;
        await txn.insert(
          'tool_tags',
          normalized,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<int> _createTagInternal({
    required String name,
    required List<_ToolTagLink> toolLinks,
    int? color,
    DateTime? now,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('createTag 需要 name');
    }
    if (toolLinks.isEmpty) {
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

      for (final link in toolLinks) {
        final sortIndex = await _nextToolTagSortIndex(
          txn,
          toolId: link.toolId,
          categoryId: link.categoryId,
        );
        await txn.insert('tool_tags', {
          'tool_id': link.toolId,
          'tag_id': tagId,
          'category_id': link.categoryId,
          'sort_index': sortIndex,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      return tagId;
    });
  }

  static Future<int> _nextToolTagSortIndex(
    DatabaseExecutor txn, {
    required String toolId,
    required String categoryId,
  }) async {
    final rows = await txn.rawQuery(
      '''
SELECT MAX(sort_index) AS max_sort_index
FROM tool_tags
WHERE tool_id = ? AND category_id = ?
''',
      [toolId, categoryId],
    );
    final maxSortIndex = (rows.first['max_sort_index'] as int?) ?? -1;
    return maxSortIndex + 1;
  }

  Future<void> importWorkTaskTagsFromServer(
    List<Map<String, dynamic>> links,
  ) async {
    await _importEntityTagsFromServer(
      table: 'work_task_tags',
      entityIdColumn: 'task_id',
      entityTable: 'work_tasks',
      links: links,
    );
  }

  Future<void> setTagsForStockItem(int itemId, List<int> tagIds) async {
    await _setTagsForEntity(
      table: 'stock_item_tags',
      entityIdColumn: 'item_id',
      entityId: itemId,
      tagIds: tagIds,
    );
  }

  Future<List<int>> listTagIdsForStockItem(int itemId) async {
    return _listTagIdsForEntity(
      table: 'stock_item_tags',
      entityIdColumn: 'item_id',
      entityId: itemId,
    );
  }

  Future<Map<int, List<Tag>>> listTagsForStockItems(List<int> itemIds) async {
    return _listTagsForEntities(
      table: 'stock_item_tags',
      entityIdColumn: 'item_id',
      entityIds: itemIds,
    );
  }

  Future<List<Map<String, Object?>>> exportStockItemTags() async {
    return _exportEntityTags(
      table: 'stock_item_tags',
      entityIdColumn: 'item_id',
    );
  }

  Future<void> importStockItemTagsFromServer(
    List<Map<String, dynamic>> links,
  ) async {
    await _importEntityTagsFromServer(
      table: 'stock_item_tags',
      entityIdColumn: 'item_id',
      entityTable: 'stock_items',
      links: links,
    );
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

  Future<void> _setTagsForEntity({
    required String table,
    required String entityIdColumn,
    required int entityId,
    required List<int> tagIds,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(
        table,
        where: '$entityIdColumn = ?',
        whereArgs: [entityId],
      );

      for (final tagId in _dedupeInts(tagIds)) {
        await txn.insert(table, {
          entityIdColumn: entityId,
          'tag_id': tagId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<List<int>> _listTagIdsForEntity({
    required String table,
    required String entityIdColumn,
    required int entityId,
  }) async {
    final db = await _database;
    final rows = await db.query(
      table,
      columns: const ['tag_id'],
      where: '$entityIdColumn = ?',
      whereArgs: [entityId],
      orderBy: 'tag_id ASC',
    );
    return rows.map((e) => e['tag_id'] as int).toList();
  }

  Future<Map<int, List<Tag>>> _listTagsForEntities({
    required String table,
    required String entityIdColumn,
    required List<int> entityIds,
  }) async {
    final ids = _dedupeInts(entityIds).toList();
    if (ids.isEmpty) return {};

    final placeholders = List.filled(ids.length, '?').join(',');
    final db = await _database;
    final rows = await db.rawQuery('''
SELECT et.$entityIdColumn AS entity_id, t.*
FROM $table et
INNER JOIN tags t ON t.id = et.tag_id
WHERE et.$entityIdColumn IN ($placeholders)
ORDER BY et.$entityIdColumn ASC, t.name COLLATE NOCASE ASC
''', ids);

    final result = <int, List<Tag>>{};
    for (final row in rows) {
      final id = row['entity_id'] as int;
      result.putIfAbsent(id, () => []).add(Tag.fromMap(row));
    }
    return result;
  }

  Future<List<Map<String, Object?>>> _exportEntityTags({
    required String table,
    required String entityIdColumn,
  }) async {
    final db = await _database;
    final rows = await db.query(
      table,
      orderBy: '$entityIdColumn ASC, tag_id ASC',
    );
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<void> _importEntityTagsFromServer({
    required String table,
    required String entityIdColumn,
    required String entityTable,
    required List<Map<String, dynamic>> links,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(table);

      for (final link in links) {
        final entityId = link[entityIdColumn];
        final tagId = link['tag_id'];
        if (entityId is! int || tagId is! int) continue;

        await txn.rawInsert(
          '''
INSERT INTO $table ($entityIdColumn, tag_id)
SELECT ?, ?
WHERE EXISTS(SELECT 1 FROM $entityTable WHERE id = ?)
  AND EXISTS(SELECT 1 FROM tags WHERE id = ?)
''',
          [entityId, tagId, entityId, tagId],
        );
      }
    });
  }
}
