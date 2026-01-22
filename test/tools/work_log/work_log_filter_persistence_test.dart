import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/work_log/services/work_log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers/fake_work_log_repository.dart';

void main() {
  group('WorkLogService - 筛选状态持久化', () {
    late Database db;
    late TagRepository tagRepository;

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
    });

    tearDown(() async {
      await db.close();
    });

    test('应自动清理不存在的标签筛选条件并回写到 SharedPreferences', () async {
      final validId = await tagRepository.createTag(
        name: '标签1',
        toolIds: const ['work_log'],
        now: DateTime(2026, 1, 1),
      );

      SharedPreferences.setMockInitialValues({
        'work_log_tag_filters': [validId.toString(), '999999'],
      });

      final service = WorkLogService(
        repository: FakeWorkLogRepository(),
        tagRepository: tagRepository,
      );

      await service.loadTasks();

      expect(service.tagFilters, [validId]);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('work_log_tag_filters'), [validId.toString()]);
    });
  });
}
