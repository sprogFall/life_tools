import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_prompt_resolver.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('XiaoMiPromptResolver 单边时间范围', () {
    late Database db;
    late WorkLogRepository workLogRepository;
    late TagRepository tagRepository;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
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
      tagRepository = TagRepository.withDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('应支持只传开始日期', () async {
      final now = DateTime(2026, 4, 20, 9);
      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '测试任务',
          description: '测试描述',
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
          workDate: DateTime(2026, 4, 15),
          minutes: 60,
          content: '测试内容',
          now: now,
        ),
      );

      final resolver = XiaoMiPromptResolver(
        workLogRepository: workLogRepository,
        tagRepository: tagRepository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'work_log_range_summary',
        displayText: '从4月1日开始的工作总结',
        arguments: const <String, Object?>{
          'start_date': '20260401',
        },
      );

      final metadata = resolved.metadata ?? const <String, dynamic>{};
      expect(metadata['queryStartDate'], '2026-04-01');
      expect(metadata['queryEndDate'], '2026-04-20');
      expect(resolved.aiPrompt, isNotNull);
      expect(resolved.aiPrompt, contains('工作记录'));
    });

    test('应支持只传结束日期', () async {
      final now = DateTime(2026, 4, 20, 9);
      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '测试任务',
          description: '测试描述',
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
          workDate: DateTime(2026, 3, 15),
          minutes: 60,
          content: '测试内容',
          now: now,
        ),
      );

      final resolver = XiaoMiPromptResolver(
        workLogRepository: workLogRepository,
        tagRepository: tagRepository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'work_log_range_summary',
        displayText: '到4月15日为止的工作总结',
        arguments: const <String, Object?>{
          'end_date': '20260415',
        },
      );

      final metadata = resolved.metadata ?? const <String, dynamic>{};
      expect(metadata['queryStartDate'], '1970-01-01');
      expect(metadata['queryEndDate'], '2026-04-15');
      expect(resolved.aiPrompt, isNotNull);
      expect(resolved.aiPrompt, contains('工作记录'));
    });

    test('work_log_query 应支持只传开始日期', () async {
      final now = DateTime(2026, 4, 20, 9);
      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '测试任务',
          description: '测试描述',
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
          workDate: DateTime(2026, 4, 15),
          minutes: 60,
          content: '测试内容',
          now: now,
        ),
      );

      final resolver = XiaoMiPromptResolver(
        workLogRepository: workLogRepository,
        tagRepository: tagRepository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'work_log_query',
        displayText: '查询4月1日之后的工作记录',
        arguments: const <String, Object?>{
          'start_date': '20260401',
        },
      );

      final metadata = resolved.metadata ?? const <String, dynamic>{};
      expect(metadata['queryStartDate'], '2026-04-01');
      expect(metadata['queryEndDate'], '2026-04-20');
      expect(resolved.aiPrompt, contains('工作记录查询结果'));
      expect(resolved.aiPrompt, contains('命中记录数：1'));
    });

    test('work_log_query 应支持只传结束日期', () async {
      final now = DateTime(2026, 4, 20, 9);
      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '测试任务',
          description: '测试描述',
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
          workDate: DateTime(2026, 3, 15),
          minutes: 60,
          content: '测试内容',
          now: now,
        ),
      );

      final resolver = XiaoMiPromptResolver(
        workLogRepository: workLogRepository,
        tagRepository: tagRepository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'work_log_query',
        displayText: '查询4月15日之前的工作记录',
        arguments: const <String, Object?>{
          'end_date': '20260415',
        },
      );

      final metadata = resolved.metadata ?? const <String, dynamic>{};
      expect(metadata['queryStartDate'], '1970-01-01');
      expect(metadata['queryEndDate'], '2026-04-15');
      expect(resolved.aiPrompt, contains('工作记录查询结果'));
      expect(resolved.aiPrompt, contains('命中记录数：1'));
    });
  });
}
