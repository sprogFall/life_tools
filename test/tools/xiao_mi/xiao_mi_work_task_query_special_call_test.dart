import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_prompt_resolver.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('XiaoMiPromptResolver work_task_query', () {
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

    test('应支持按任务标题查询，即使没有工时记录也能命中任务', () async {
      final now = DateTime(2026, 4, 20, 9);
      await workLogRepository.createTask(
        WorkTask.create(
          title: '今日防汛巡查',
          description: '河道巡查与排查',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 180,
          now: now,
        ),
      );

      final resolver = XiaoMiPromptResolver(
        workLogRepository: workLogRepository,
        tagRepository: tagRepository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'work_task_query',
        displayText: '查一下标题里有防汛的任务',
        arguments: const <String, Object?>{
          'keyword': '防汛',
          'fields': <String>['task_title', 'task_status', 'estimated_minutes'],
        },
      );

      expect(resolved.aiPrompt, contains('任务查询结果'));
      expect(resolved.aiPrompt, contains('命中任务数：1'));
      expect(
        resolved.aiPrompt,
        contains(
          'task_title=今日防汛巡查 | task_status=doing | estimated_minutes=180',
        ),
      );
    });

    test('用户明确要求按归属标签查询任务时，仍应严格按标签过滤', () async {
      final now = DateTime(2026, 4, 20, 9);
      final floodTagId = await tagRepository.createTagForToolCategory(
        name: '防汛',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );

      await workLogRepository.createTask(
        WorkTask.create(
          title: '防汛值守',
          description: '标题命中但未打标签',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 120,
          now: now,
        ),
      );
      final taggedTaskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '值守复盘',
          description: '通过标签命中',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 60,
          now: now,
        ),
      );
      await tagRepository.setTagsForWorkTask(taggedTaskId, [floodTagId]);

      final resolver = XiaoMiPromptResolver(
        workLogRepository: workLogRepository,
        tagRepository: tagRepository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'work_task_query',
        displayText: '查归属标签为防汛的任务',
        arguments: const <String, Object?>{
          'keyword': '防汛',
          'affiliation_names': <String>['防汛'],
          'fields': <String>['task_title', 'affiliations', 'estimated_minutes'],
        },
      );

      expect(resolved.aiPrompt, contains('归属标签：防汛'));
      expect(resolved.aiPrompt, contains('命中任务数：1'));
      expect(
        resolved.aiPrompt,
        contains('task_title=值守复盘 | affiliations=防汛 | estimated_minutes=60'),
      );
      expect(resolved.aiPrompt, isNot(contains('task_title=防汛值守')));
    });
  });
}
