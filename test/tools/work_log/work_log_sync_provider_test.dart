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

    test('导出/导入应包含全部 operation_logs（不应截断）', () async {
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
      expect(exportedLogs.length, total);

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
      expect(await targetRepo.getOperationLogCount(), total);

      await sourceDb.close();
      await targetDb.close();
    });
  });
}
