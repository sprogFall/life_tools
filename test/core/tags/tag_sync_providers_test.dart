import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_sync_provider.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository.dart';
import 'package:life_tools/tools/work_log/sync/work_log_sync_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('导入/导出 - 标签与工作记录联动', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('先导入标签管理，再导入工作记录，可恢复任务标签', () async {
      // 1) 源库：创建标签 + 创建任务 + 绑定标签
      final sourceDb = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final sourceTags = TagRepository.withDatabase(sourceDb);
      final sourceWorkLog = WorkLogRepository.withDatabase(sourceDb);

      final urgentId = await sourceTags.createTagForToolCategory(
        name: '紧急',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );
      final taskId = await sourceWorkLog.createTask(
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
      await sourceTags.setTagsForWorkTask(taskId, [urgentId]);

      final tagProvider = TagSyncProvider(repository: sourceTags);
      final workLogProvider = WorkLogSyncProvider(
        repository: sourceWorkLog,
        tagRepository: sourceTags,
      );

      final tagPayload = await tagProvider.exportData();
      final workLogPayload = await workLogProvider.exportData();
      await sourceDb.close();

      // 2) 目标库：先导入标签，再导入工作记录
      final targetDb = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final targetTags = TagRepository.withDatabase(targetDb);
      final targetWorkLog = WorkLogRepository.withDatabase(targetDb);

      final tagProvider2 = TagSyncProvider(repository: targetTags);
      final workLogProvider2 = WorkLogSyncProvider(
        repository: targetWorkLog,
        tagRepository: targetTags,
      );

      await tagProvider2.importData(tagPayload);
      await workLogProvider2.importData(workLogPayload);

      final tasks = await targetWorkLog.listTasks();
      expect(tasks.length, 1);
      expect(tasks.single.title, '任务A');

      final restoredTags = await targetTags.listTagsForTool('work_log');
      expect(restoredTags.map((t) => t.id), contains(urgentId));

      final restoredTagIds = await targetTags.listTagIdsForWorkTask(
        tasks.single.id!,
      );
      expect(restoredTagIds, [urgentId]);

      await targetDb.close();
    });

    test('标签导出/导入应保留 tool_tags.category_id；缺失时应报错', () async {
      final sourceDb = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final sourceTags = TagRepository.withDatabase(sourceDb);

      final priorityId = await sourceTags.createTagForToolCategory(
        name: '紧急',
        toolId: 'work_log',
        categoryId: 'priority',
      );

      final tagProvider = TagSyncProvider(repository: sourceTags);
      final payload = await tagProvider.exportData();
      await sourceDb.close();

      final data = payload['data'] as Map<String, dynamic>;
      final toolTags = (data['tool_tags'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final priorityLink = toolTags.singleWhere(
        (e) => e['tag_id'] == priorityId && e['tool_id'] == 'work_log',
      );
      expect(priorityLink['category_id'], 'priority');

      // 兼容：模拟旧备份，去掉 category_id
      final legacyPayload = <String, dynamic>{
        'version': 1,
        'data': <String, dynamic>{
          'tags': (data['tags'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
          'tool_tags': toolTags.map((e) {
            final next = Map<String, dynamic>.from(e);
            next.remove('category_id');
            return next;
          }).toList(),
        },
      };

      final targetDb = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final targetTags = TagRepository.withDatabase(targetDb);
      final provider2 = TagSyncProvider(repository: targetTags);

      await expectLater(
        () => provider2.importData(legacyPayload),
        throwsArgumentError,
      );

      await targetDb.close();
    });

    test('工作记录导出/导入应包含任务置顶与排序字段', () async {
      final sourceDb = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final sourceTags = TagRepository.withDatabase(sourceDb);
      final sourceWorkLog = WorkLogRepository.withDatabase(sourceDb);

      final idA = await sourceWorkLog.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1, 8),
        ).copyWith(isPinned: true, sortIndex: 1),
      );
      final idB = await sourceWorkLog.createTask(
        WorkTask.create(
          title: '任务B',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1, 9),
        ).copyWith(isPinned: true, sortIndex: 0),
      );
      final idC = await sourceWorkLog.createTask(
        WorkTask.create(
          title: '任务C',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1, 10),
        ).copyWith(isPinned: false, sortIndex: 0),
      );

      final workLogProvider = WorkLogSyncProvider(
        repository: sourceWorkLog,
        tagRepository: sourceTags,
      );
      final payload = await workLogProvider.exportData();
      await sourceDb.close();

      final dataMap = payload['data'] as Map<String, dynamic>;
      final taskList = dataMap['tasks'] as List<dynamic>;
      final taskMaps = taskList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final byId = <int, Map<String, dynamic>>{
        for (final t in taskMaps) (t['id'] as int): t,
      };

      expect(byId[idA]!.containsKey('is_pinned'), isTrue);
      expect(byId[idA]!.containsKey('sort_index'), isTrue);
      expect(byId[idB]!['is_pinned'], 1);
      expect(byId[idB]!['sort_index'], 0);
      expect(byId[idC]!['is_pinned'], 0);

      final targetDb = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final targetTags = TagRepository.withDatabase(targetDb);
      final targetWorkLog = WorkLogRepository.withDatabase(targetDb);
      final workLogProvider2 = WorkLogSyncProvider(
        repository: targetWorkLog,
        tagRepository: targetTags,
      );

      await workLogProvider2.importData(payload);

      final tasks = await targetWorkLog.listTasks();
      expect(tasks.map((t) => t.id), [idB, idA, idC]);
      expect(tasks.first.isPinned, isTrue);
      expect(tasks.first.sortIndex, 0);

      await targetDb.close();
    });
  });
}
