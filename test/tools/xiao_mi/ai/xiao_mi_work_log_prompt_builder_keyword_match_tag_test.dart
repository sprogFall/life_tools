import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_work_log_prompt_builder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('XiaoMiWorkLogSummaryPromptBuilder 关键词匹配标签', () {
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

    test('关键词应该能匹配标签：海曙应急局 -> 标签"海曙应急管理局"', () async {
      final now = DateTime(2026, 4, 20, 9);
      final tagId = await tagRepository.createTagForToolCategory(
        name: '海曙应急管理局',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );
      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '系统维护',
          description: '日常维护',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: now,
        ),
      );
      await tagRepository.setTagsForWorkTask(taskId, [tagId]);
      await workLogRepository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 4, 12),
          minutes: 120,
          content: '现场支持',
          now: now,
        ),
      );

      final builder = XiaoMiWorkLogSummaryPromptBuilder(
        repository: workLogRepository,
        tagRepository: tagRepository,
        nowProvider: () => now,
      );

      final prompt = await builder.buildQuery(
        displayText: '查询海曙应急局工作记录',
        start: DateTime(2026, 4, 1),
        endInclusive: DateTime(2026, 4, 30),
        keyword: '海曙应急局',
        fields: const <String>[
          'work_date',
          'task_title',
          'affiliations',
          'minutes',
        ],
      );

      expect(prompt, contains('工作记录查询结果'));
      expect(prompt, contains('关键词：海曙应急局'));
      expect(prompt, contains('命中记录数：1'));
      expect(
        prompt,
        contains(
          'work_date=2026-04-12 | task_title=系统维护 | affiliations=海曙应急管理局 | minutes=120',
        ),
      );
    });

    test('关键词应该能匹配标签子串：应急局 -> 标签"海曙应急管理局"', () async {
      final now = DateTime(2026, 4, 20, 9);
      final tagId = await tagRepository.createTagForToolCategory(
        name: '海曙应急管理局',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );
      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '系统维护',
          description: '日常维护',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: now,
        ),
      );
      await tagRepository.setTagsForWorkTask(taskId, [tagId]);
      await workLogRepository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 4, 12),
          minutes: 120,
          content: '现场支持',
          now: now,
        ),
      );

      final builder = XiaoMiWorkLogSummaryPromptBuilder(
        repository: workLogRepository,
        tagRepository: tagRepository,
        nowProvider: () => now,
      );

      final prompt = await builder.buildQuery(
        displayText: '查询应急局工作记录',
        start: DateTime(2026, 4, 1),
        endInclusive: DateTime(2026, 4, 30),
        keyword: '应急局',
        fields: const <String>[
          'work_date',
          'task_title',
          'affiliations',
          'minutes',
        ],
      );

      expect(prompt, contains('工作记录查询结果'));
      expect(prompt, contains('关键词：应急局'));
      expect(prompt, contains('命中记录数：1'));
      expect(
        prompt,
        contains(
          'work_date=2026-04-12 | task_title=系统维护 | affiliations=海曙应急管理局 | minutes=120',
        ),
      );
    });

    test('关键词不匹配标签时应返回空结果', () async {
      final now = DateTime(2026, 4, 20, 9);
      final tagId = await tagRepository.createTagForToolCategory(
        name: '其他项目',
        toolId: 'work_log',
        categoryId: 'affiliation',
      );
      final taskId = await workLogRepository.createTask(
        WorkTask.create(
          title: '系统维护',
          description: '日常维护',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: now,
        ),
      );
      await tagRepository.setTagsForWorkTask(taskId, [tagId]);
      await workLogRepository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 4, 12),
          minutes: 120,
          content: '现场支持',
          now: now,
        ),
      );

      final builder = XiaoMiWorkLogSummaryPromptBuilder(
        repository: workLogRepository,
        tagRepository: tagRepository,
        nowProvider: () => now,
      );

      final prompt = await builder.buildQuery(
        displayText: '查询海曙应急局工作记录',
        start: DateTime(2026, 4, 1),
        endInclusive: DateTime(2026, 4, 30),
        keyword: '海曙应急局',
        fields: const <String>[
          'work_date',
          'task_title',
          'affiliations',
          'minutes',
        ],
      );

      expect(prompt, contains('工作记录查询结果'));
      expect(prompt, contains('命中记录数：0'));
      expect(prompt, contains('- (无)'));
    });
  });
}
