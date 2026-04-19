import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_ai_prompts.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_prompt_resolver.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('XiaoMiPromptResolver work_log_query', () {
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

    test('预选提示词应声明 work_log_query 的筛选与字段协议', () {
      expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('work_log_query'));
      expect(
        XiaoMiAiPrompts.preRouteSystemPrompt,
        contains('affiliation_names'),
      );
      expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('statuses'));
      expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('fields'));
    });

    test('work_log_query 应支持组合筛选与字段投影', () async {
      final now = DateTime(2026, 4, 20, 9);
      final projectAId = await tagRepository.createTagForToolCategory(
        name: '项目A',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );
      final projectBId = await tagRepository.createTagForToolCategory(
        name: '项目B',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );

      final taskAId = await workLogRepository.createTask(
        WorkTask.create(
          title: '接口联调',
          description: '支付链路对接',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: now,
        ),
      );
      final taskBId = await workLogRepository.createTask(
        WorkTask.create(
          title: '月度复盘',
          description: '复盘四月事项',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.done,
          estimatedMinutes: 0,
          now: now,
        ),
      );

      await tagRepository.setTagsForWorkTask(taskAId, [projectAId]);
      await tagRepository.setTagsForWorkTask(taskBId, [projectBId]);

      await workLogRepository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskAId,
          workDate: DateTime(2026, 4, 12),
          minutes: 90,
          content: '完成支付接口联调并验证回调',
          now: now,
        ),
      );
      await workLogRepository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskAId,
          workDate: DateTime(2026, 3, 28),
          minutes: 30,
          content: '历史接口预研',
          now: now,
        ),
      );
      await workLogRepository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskBId,
          workDate: DateTime(2026, 4, 15),
          minutes: 45,
          content: '接口问题复盘',
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
        displayText: '查询四月项目A中与接口相关且进行中的工作记录',
        arguments: const <String, Object?>{
          'start_date': '20260401',
          'end_date': '20260430',
          'keyword': '接口',
          'statuses': <String>['doing'],
          'affiliation_names': <String>['项目A'],
          'fields': <String>[
            'work_date',
            'task_title',
            'task_status',
            'affiliations',
            'minutes',
          ],
          'limit': 1,
        },
      );

      final metadata = resolved.metadata ?? const <String, dynamic>{};
      expect(metadata['triggerSource'], 'pre_route');
      expect(metadata['queryStartDate'], '2026-04-01');
      expect(metadata['queryEndDate'], '2026-04-30');
      expect(metadata['triggerTool'], 'work_log');
      expect(resolved.aiPrompt, contains('工作记录查询结果'));
      expect(resolved.aiPrompt, contains('关键词：接口'));
      expect(resolved.aiPrompt, contains('任务状态：doing'));
      expect(resolved.aiPrompt, contains('归属标签：项目A'));
      expect(
        resolved.aiPrompt,
        contains(
          'work_date=2026-04-12 | task_title=接口联调 | task_status=doing | affiliations=项目A | minutes=90',
        ),
      );
      expect(resolved.aiPrompt, isNot(contains('content=')));
      expect(resolved.aiPrompt, isNot(contains('接口问题复盘')));
      expect(resolved.aiPrompt, isNot(contains('历史接口预研')));
    });
  });
}
