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
  });
}
