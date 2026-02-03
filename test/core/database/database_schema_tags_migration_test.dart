import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('DatabaseSchema - 标签迁移', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('从 v16 升级时应修复默认分类并移除 tags.name 全局唯一约束', () async {
      final tmp = await Directory.systemTemp.createTemp('life_tools_db_test_');
      addTearDown(() async {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      });

      final path = '${tmp.path}/life_tools_test.db';

      final oldDb = await openDatabase(
        path,
        version: 16,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: (db, version) async {
          // v16（旧版）仍包含 work_tasks（供 work_task_tags 外键引用）
          await db.execute('''
CREATE TABLE IF NOT EXISTS work_tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  start_at INTEGER,
  end_at INTEGER,
  status INTEGER NOT NULL,
  estimated_minutes INTEGER NOT NULL DEFAULT 0,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  sort_index INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');

          // v16（旧版）：tags.name 为全局 UNIQUE；tool_tags.category_id 默认 'default'
          await db.execute('''
CREATE TABLE IF NOT EXISTS tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  color INTEGER,
  sort_index INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(name)
)
''');
          await db.execute('''
CREATE TABLE IF NOT EXISTS tool_tags (
  tool_id TEXT NOT NULL,
  tag_id INTEGER NOT NULL,
  category_id TEXT NOT NULL DEFAULT 'default',
  sort_index INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (tool_id, tag_id),
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
)
''');
        },
      );

      final now = DateTime(2026, 1, 1).millisecondsSinceEpoch;
      final workLogTagId = await oldDb.insert('tags', {
        'name': '项目A',
        'color': null,
        'sort_index': 0,
        'created_at': now,
        'updated_at': now,
      });
      final stockpileTagId = await oldDb.insert('tags', {
        'name': '零食',
        'color': null,
        'sort_index': 1,
        'created_at': now,
        'updated_at': now,
      });

      await oldDb.insert('tool_tags', {
        'tool_id': 'work_log',
        'tag_id': workLogTagId,
        'category_id': 'default',
        'sort_index': 0,
      });
      await oldDb.insert('tool_tags', {
        'tool_id': 'stockpile_assistant',
        'tag_id': stockpileTagId,
        'category_id': 'default',
        'sort_index': 0,
      });
      await oldDb.close();

      final db = await openDatabase(
        path,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      addTearDown(() async => db.close());

      final workLogLinks = await db.query(
        'tool_tags',
        where: 'tool_id = ? AND tag_id = ?',
        whereArgs: ['work_log', workLogTagId],
      );
      expect(workLogLinks.single['category_id'], 'affiliation');

      final stockpileLinks = await db.query(
        'tool_tags',
        where: 'tool_id = ? AND tag_id = ?',
        whereArgs: ['stockpile_assistant', stockpileTagId],
      );
      expect(stockpileLinks.single['category_id'], 'item_type');

      // 升级后应允许不同工具下创建同名标签（不再是 tags.name 全局唯一）
      final repo = TagRepository.withDatabase(db);
      final newId = await repo.createTagForToolCategory(
        name: '项目A',
        toolId: 'stockpile_assistant',
        categoryId: 'item_type',
      );
      expect(newId, greaterThan(0));
    });
  });
}
