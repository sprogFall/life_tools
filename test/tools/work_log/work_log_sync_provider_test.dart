import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/work_log/models/operation_log.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository.dart';
import 'package:life_tools/tools/work_log/sync/work_log_sync_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('WorkLogSyncProvider', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('导出/导入 operation_logs 时应只保留最近10条', () async {
      final sourceDb = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final sourceRepo = WorkLogRepository.withDatabase(sourceDb);
      final sourceTags = TagRepository.withDatabase(sourceDb);

      const total = 1005;
      for (int i = 0; i < total; i++) {
        await sourceRepo.createOperationLog(
          OperationLog.create(
            operationType: OperationType.updateTask,
            targetType: TargetType.task,
            targetId: i + 1,
            targetTitle: '任务${i + 1}',
            summary: '测试日志 ${i + 1}',
            now: DateTime(2026, 1, 1, 8).add(Duration(seconds: i)),
          ),
        );
      }

      final provider = WorkLogSyncProvider(
        repository: sourceRepo,
        tagRepository: sourceTags,
      );
      final exported = await provider.exportData();
      final data = exported['data'] as Map<String, dynamic>;
      final exportedLogs = (data['operation_logs'] as List?) ?? const [];
      expect(exportedLogs.length, 10);
      final exportedIds = exportedLogs
          .map((e) => (e as Map)['target_id'] as int)
          .toList();
      expect(exportedIds.first, total);
      expect(exportedIds.last, total - 9);

      final targetDb = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final targetRepo = WorkLogRepository.withDatabase(targetDb);
      final targetTags = TagRepository.withDatabase(targetDb);
      final provider2 = WorkLogSyncProvider(
        repository: targetRepo,
        tagRepository: targetTags,
      );

      await provider2.importData(exported);
      expect(await targetRepo.getOperationLogCount(), 10);

      await sourceDb.close();
      await targetDb.close();
    });

    test('可导入 dashboard 更新后的 work_log 快照并恢复到本地仓库', () async {
      final targetDb = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final targetRepo = WorkLogRepository.withDatabase(targetDb);
      final targetTags = TagRepository.withDatabase(targetDb);
      final provider = WorkLogSyncProvider(
        repository: targetRepo,
        tagRepository: targetTags,
      );

      await provider.importData({
        'version': 1,
        'data': {
          'tasks': [
            {
              'id': 1,
              'title': '整理周报',
              'description': '补齐项目进度与风险',
              'status': 1,
              'estimated_minutes': 90,
              'is_pinned': 1,
              'sort_index': 0,
              'created_at': 1730000000000,
              'updated_at': 1730000000100,
            },
            {
              'id': 2,
              'title': '需求拆分',
              'description': '按 dashboard 调整后的归属继续处理',
              'status': 0,
              'estimated_minutes': 45,
              'is_pinned': 0,
              'sort_index': 1,
              'created_at': 1730000000200,
              'updated_at': 1730000000300,
            },
          ],
          'time_entries': [
            {
              'id': 10,
              'task_id': 2,
              'work_date': 1730000000000,
              'minutes': 60,
              'content': '产出初稿',
              'created_at': 1730000000000,
              'updated_at': 1730000000400,
            },
          ],
          'task_tags': const [],
          'operation_logs': [
            {
              'id': 1,
              'operation_type': 4,
              'target_type': 1,
              'target_id': 10,
              'target_title': '产出初稿',
              'before_snapshot': '{"task_id":1,"task_title":"整理周报"}',
              'after_snapshot': '{"task_id":2,"task_title":"需求拆分"}',
              'summary': '将工时“产出初稿”从“整理周报”调整到“需求拆分”',
              'created_at': 1730000000500,
            },
          ],
        },
      });

      final task1 = await targetRepo.getTask(1);
      final task2 = await targetRepo.getTask(2);
      final task2Entries = await targetRepo.listTimeEntriesForTask(2);

      expect(task1, isNotNull);
      expect(task1!.isPinned, isTrue);
      expect(task2, isNotNull);
      expect(task2!.title, '需求拆分');
      expect(task2Entries, hasLength(1));
      expect(task2Entries.first.id, 10);
      expect(task2Entries.first.taskId, 2);
      expect(task2Entries.first.content, '产出初稿');
      expect(await targetRepo.getOperationLogCount(), 1);

      await targetDb.close();
    });
  });
}
