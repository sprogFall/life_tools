import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('WorkLogRepository - 标签筛选', () {
    late TagRepository tagRepository;
    late WorkLogRepository repository;
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
      repository = WorkLogRepository.withDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('按单个标签筛选任务（任意匹配）', () async {
      final urgentId = await tagRepository.createTag(
        name: '紧急',
        toolIds: const ['work_log'],
      );
      final routineId = await tagRepository.createTag(
        name: '例行',
        toolIds: const ['work_log'],
      );

      final a = await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 2),
        ),
      );
      final b = await repository.createTask(
        WorkTask.create(
          title: '任务B',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );

      await tagRepository.setTagsForWorkTask(a, [urgentId]);
      await tagRepository.setTagsForWorkTask(b, [routineId]);

      final urgentTasks = await repository.listTasks(tagIds: [urgentId]);
      expect(urgentTasks.map((t) => t.title), ['任务A']);

      final anyTasks = await repository.listTasks(
        tagIds: [urgentId, routineId],
      );
      expect(anyTasks.map((t) => t.title), ['任务A', '任务B']);
    });
  });
}
