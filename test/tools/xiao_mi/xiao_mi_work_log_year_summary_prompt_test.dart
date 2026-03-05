import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_work_log_prompt_builder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('XiaoMiWorkLogSummaryPromptBuilder.buildCurrentYear', () {
    late Database db;
    late WorkLogRepository workLogRepository;

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
      workLogRepository = WorkLogRepository.withDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('应基于当年工作记录生成 prompt', () async {
      final now = DateTime(2026, 10, 1, 8);
      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: now,
        ),
      );
      await workLogRepository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 2, 3),
          minutes: 45,
          content: '实现登录功能',
          now: now,
        ),
      );

      final builder = XiaoMiWorkLogSummaryPromptBuilder(
        repository: workLogRepository,
        nowProvider: () => now,
      );

      final prompt = await builder.buildCurrentYear();

      expect(prompt, contains('时间范围：2026-01-01 至 2026-12-31（含）'));
      expect(prompt, contains('任务：任务A'));
      expect(prompt, contains('内容：实现登录功能'));
      expect(prompt, contains('总记录数：1'));
    });

    test('当年无工作记录时应返回 null', () async {
      final now = DateTime(2026, 10, 1, 8);
      final builder = XiaoMiWorkLogSummaryPromptBuilder(
        repository: workLogRepository,
        nowProvider: () => now,
      );

      final prompt = await builder.buildCurrentYear();
      expect(prompt, isNull);
    });
  });
}
