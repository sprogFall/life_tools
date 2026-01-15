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

      final urgentId = await sourceTags.createTag(
        name: '紧急',
        toolIds: const ['work_log'],
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
  });
}
