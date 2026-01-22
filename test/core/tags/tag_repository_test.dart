import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('TagRepository', () {
    late TagRepository tagRepository;
    late WorkLogRepository workLogRepository;
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      tagRepository = TagRepository.withDatabase(db);
      workLogRepository = WorkLogRepository.withDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('创建标签后可按工具查询', () async {
      final id = await tagRepository.createTag(
        name: '紧急',
        toolIds: const ['work_log'],
      );

      final workLogTags = await tagRepository.listTagsForTool('work_log');
      expect(workLogTags.map((t) => t.id), contains(id));

      final incomeTags = await tagRepository.listTagsForTool('income');
      expect(incomeTags, isEmpty);
    });

    test('按工具查询可包含分类信息（默认分类/自定义分类）', () async {
      final priorityId = await tagRepository.createTagForToolCategory(
        name: '紧急',
        toolId: 'work_log',
        categoryId: 'priority',
      );
      final defaultId = await tagRepository.createTag(
        name: '例行',
        toolIds: const ['work_log'],
      );

      final items = await tagRepository.listTagsForToolWithCategory('work_log');
      final byId = {for (final it in items) it.tag.id!: it.categoryId};

      expect(byId[priorityId], 'priority');
      expect(byId[defaultId], TagRepository.defaultCategoryId);
    });

    test('标签可关联多个工具并可更新', () async {
      final id = await tagRepository.createTag(
        name: '复盘',
        toolIds: const ['work_log', 'review'],
      );

      var tags = await tagRepository.listAllTagsWithTools();
      final before = tags.singleWhere((t) => t.tag.id == id);
      expect(before.toolIds.toSet(), {'work_log', 'review'});

      await tagRepository.updateTag(
        tagId: id,
        name: '复盘&总结',
        toolIds: const ['review'],
      );

      tags = await tagRepository.listAllTagsWithTools();
      final after = tags.singleWhere((t) => t.tag.id == id);
      expect(after.tag.name, '复盘&总结');
      expect(after.toolIds.toSet(), {'review'});
    });

    test('updateTag 更新关联工具时应保留已有分类', () async {
      final id = await tagRepository.createTagForToolCategory(
        name: '紧急',
        toolId: 'work_log',
        categoryId: 'priority',
      );

      await tagRepository.updateTag(
        tagId: id,
        name: '紧急',
        toolIds: const ['work_log', 'review'],
      );

      final links = await db.query(
        'tool_tags',
        where: 'tag_id = ?',
        whereArgs: [id],
        orderBy: 'tool_id ASC',
      );
      final byTool = {
        for (final row in links)
          row['tool_id'] as String: row['category_id'] as String?,
      };

      expect(byTool['work_log'], 'priority');
      expect(byTool['review'], TagRepository.defaultCategoryId);
    });

    test('任务可设置标签并可查询', () async {
      final urgentId = await tagRepository.createTag(
        name: '紧急',
        toolIds: const ['work_log'],
      );
      final routineId = await tagRepository.createTag(
        name: '例行',
        toolIds: const ['work_log'],
      );

      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );

      await tagRepository.setTagsForWorkTask(taskId, [urgentId, routineId]);
      final tagIds = await tagRepository.listTagIdsForWorkTask(taskId);
      expect(tagIds.toSet(), {urgentId, routineId});
    });

    test('删除标签会级联清理任务关联', () async {
      final urgentId = await tagRepository.createTag(
        name: '紧急',
        toolIds: const ['work_log'],
      );

      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );

      await tagRepository.setTagsForWorkTask(taskId, [urgentId]);
      await tagRepository.deleteTag(urgentId);

      final tagIds = await tagRepository.listTagIdsForWorkTask(taskId);
      expect(tagIds, isEmpty);
    });

    test('创建新标签应自动追加到排序末尾', () async {
      final firstId = await tagRepository.createTag(
        name: 'B',
        toolIds: const ['work_log'],
        now: DateTime(2026, 1, 1, 10),
      );
      await tagRepository.createTag(
        name: 'A',
        toolIds: const ['work_log'],
        now: DateTime(2026, 1, 1, 11),
      );

      // 先手动设置排序（模拟用户拖拽过）
      await tagRepository.reorderTags([firstId], now: DateTime(2026, 1, 1, 12));

      final newId = await tagRepository.createTag(
        name: 'C',
        toolIds: const ['work_log'],
        now: DateTime(2026, 1, 1, 13),
      );

      final tags = await tagRepository.listAllTagsWithTools();
      final byId = {for (final t in tags) t.tag.id!: t.tag};

      final maxExisting = [
        for (final entry in byId.entries)
          if (entry.key != newId) entry.value.sortIndex,
      ].reduce((a, b) => a > b ? a : b);

      expect(byId[newId]!.sortIndex, maxExisting + 1);
    });

    test('reorderTags 应更新 sortIndex 和 updatedAt', () async {
      final t1 = DateTime(2026, 1, 1, 10);
      final t2 = DateTime(2026, 1, 2, 10);

      final a = await tagRepository.createTag(
        name: 'A',
        toolIds: const ['work_log'],
        now: t1,
      );
      final b = await tagRepository.createTag(
        name: 'B',
        toolIds: const ['work_log'],
        now: t1,
      );
      final c = await tagRepository.createTag(
        name: 'C',
        toolIds: const ['work_log'],
        now: t1,
      );

      await tagRepository.reorderTags([c, a, b], now: t2);

      final tags = await tagRepository.listAllTagsWithTools();
      expect(tags.map((t) => t.tag.id), [c, a, b]);
      expect(tags.map((t) => t.tag.sortIndex), [0, 1, 2]);
      expect(tags.map((t) => t.tag.updatedAt), [t2, t2, t2]);
    });
  });
}
