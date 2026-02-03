import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_exceptions.dart';
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
      final id = await tagRepository.createTagForToolCategory(
        name: '紧急',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );

      final workLogTags = await tagRepository.listTagsForTool('work_log');
      expect(workLogTags.map((t) => t.id), contains(id));

      final incomeTags = await tagRepository.listTagsForTool('income');
      expect(incomeTags, isEmpty);
    });

    test('按工具查询可包含分类信息', () async {
      final priorityId = await tagRepository.createTagForToolCategory(
        name: '紧急',
        toolId: 'work_log',
        categoryId: 'priority',
      );
      final affiliationId = await tagRepository.createTagForToolCategory(
        name: '例行',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );

      final items = await tagRepository.listTagsForToolWithCategory('work_log');
      final byId = {for (final it in items) it.tag.id!: it.categoryId};

      expect(byId[priorityId], 'priority');
      expect(byId[affiliationId], 'affiliation');
    });

    test('任务可设置标签并可查询', () async {
      final urgentId = await tagRepository.createTagForToolCategory(
        name: '紧急',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );
      final routineId = await tagRepository.createTagForToolCategory(
        name: '例行',
        toolId: 'work_log',
        categoryId: 'affiliation',
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
      final urgentId = await tagRepository.createTagForToolCategory(
        name: '紧急',
        toolId: 'work_log',
        categoryId: 'affiliation',
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
      final firstId = await tagRepository.createTagForToolCategory(
        name: 'B',
        toolId: 'work_log',
        categoryId: 'affiliation',
        now: DateTime(2026, 1, 1, 10),
      );
      await tagRepository.createTagForToolCategory(
        name: 'A',
        toolId: 'work_log',
        categoryId: 'affiliation',
        now: DateTime(2026, 1, 1, 11),
      );

      // 先手动设置排序（模拟用户拖拽过）
      await tagRepository.reorderTags([firstId], now: DateTime(2026, 1, 1, 12));

      final newId = await tagRepository.createTagForToolCategory(
        name: 'C',
        toolId: 'work_log',
        categoryId: 'affiliation',
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

      final a = await tagRepository.createTagForToolCategory(
        name: 'A',
        toolId: 'work_log',
        categoryId: 'affiliation',
        now: t1,
      );
      final b = await tagRepository.createTagForToolCategory(
        name: 'B',
        toolId: 'work_log',
        categoryId: 'affiliation',
        now: t1,
      );
      final c = await tagRepository.createTagForToolCategory(
        name: 'C',
        toolId: 'work_log',
        categoryId: 'affiliation',
        now: t1,
      );

      await tagRepository.reorderTags([c, a, b], now: t2);

      final tags = await tagRepository.listAllTagsWithTools();
      expect(tags.map((t) => t.tag.id), [c, a, b]);
      expect(tags.map((t) => t.tag.sortIndex), [0, 1, 2]);
      expect(tags.map((t) => t.tag.updatedAt), [t2, t2, t2]);
    });

    test('reorderToolCategoryTags 应仅影响该工具分类下的展示顺序', () async {
      final t = DateTime(2026, 1, 1, 10);
      final a = await tagRepository.createTagForToolCategory(
        name: 'A',
        toolId: 'work_log',
        categoryId: 'priority',
        now: t,
      );
      final b = await tagRepository.createTagForToolCategory(
        name: 'B',
        toolId: 'work_log',
        categoryId: 'priority',
        now: t,
      );
      final c = await tagRepository.createTagForToolCategory(
        name: 'C',
        toolId: 'work_log',
        categoryId: 'priority',
        now: t,
      );

      await tagRepository.reorderToolCategoryTags(
        toolId: 'work_log',
        categoryId: 'priority',
        tagIds: [c, a, b],
        now: DateTime(2026, 1, 2, 10),
      );

      final items = await tagRepository.listTagsForToolWithCategory('work_log');
      final ordered = items
          .where((e) => e.categoryId == 'priority')
          .map((e) => e.tag.id)
          .toList();
      expect(ordered, [c, a, b]);
    });

    test('允许不同工具下同名标签', () async {
      final id1 = await tagRepository.createTagForToolCategory(
        name: '紧急',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );
      final id2 = await tagRepository.createTagForToolCategory(
        name: '紧急',
        toolId: 'stockpile_assistant',
        categoryId: 'item_type',
      );
      expect(id2, isNot(id1));

      final workLogTags = await tagRepository.listTagsForTool('work_log');
      final stockpileTags = await tagRepository.listTagsForTool(
        'stockpile_assistant',
      );
      expect(workLogTags.where((t) => t.name == '紧急').length, 1);
      expect(stockpileTags.where((t) => t.name == '紧急').length, 1);
    });

    test('同工具同分类下标签名应唯一（创建时）', () async {
      await tagRepository.createTagForToolCategory(
        name: '紧急',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );

      await expectLater(
        () => tagRepository.createTagForToolCategory(
          name: '紧急',
          toolId: 'work_log',
          categoryId: 'affiliation',
        ),
        throwsA(isA<TagNameConflictException>()),
      );
    });

    test('同工具不同分类允许同名标签', () async {
      final id1 = await tagRepository.createTagForToolCategory(
        name: '紧急',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );
      final id2 = await tagRepository.createTagForToolCategory(
        name: '紧急',
        toolId: 'work_log',
        categoryId: 'priority',
      );
      expect(id2, isNot(id1));
    });

    test('同工具同分类下标签名应唯一（重命名时）', () async {
      final a = await tagRepository.createTagForToolCategory(
        name: 'A',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );
      final b = await tagRepository.createTagForToolCategory(
        name: 'B',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );

      await expectLater(
        () => tagRepository.renameTag(tagId: b, name: 'A'),
        throwsA(isA<TagNameConflictException>()),
      );

      // 原标签不受影响
      final tags = await tagRepository.listTagsForTool('work_log');
      expect(tags.any((t) => t.id == a && t.name == 'A'), isTrue);
      expect(tags.any((t) => t.id == b && t.name == 'B'), isTrue);
    });
  });
}
