import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/work_log/pages/task/work_task_edit_page.dart';
import 'package:life_tools/tools/work_log/pages/task/work_task_list_view.dart';
import 'package:life_tools/tools/work_log/services/work_log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/fake_work_log_repository.dart';

void main() {
  group('工作记录 - 归属文案', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('创建/编辑页应展示“归属”而不是“标签”', (tester) async {
      final service = WorkLogService(repository: FakeWorkLogRepository());

      await tester.pumpWidget(
        ChangeNotifierProvider<WorkLogService>.value(
          value: service,
          child: const MaterialApp(home: WorkTaskEditPage()),
        ),
      );

      expect(find.text('归属'), findsOneWidget);
      expect(find.text('标签'), findsNothing);
    });

    testWidgets('列表筛选栏应展示“归属”而不是“标签”', (tester) async {
      late Database db;
      late TagRepository tagRepository;
      late WorkLogService service;

      await tester.runAsync(() async {
        db = await openDatabase(
          inMemoryDatabasePath,
          version: DatabaseSchema.version,
          onConfigure: DatabaseSchema.onConfigure,
          onCreate: DatabaseSchema.onCreate,
          onUpgrade: DatabaseSchema.onUpgrade,
        );
        tagRepository = TagRepository.withDatabase(db);
        await tagRepository.createTagForToolCategory(
          name: '项目A',
          toolId: 'work_log',
          categoryId: 'affiliation',
        );
        service = WorkLogService(
          repository: FakeWorkLogRepository(),
          tagRepository: tagRepository,
        );
        await service.loadTasks();
      });
      addTearDown(() async {
        await tester.runAsync(() async => db.close());
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<WorkLogService>.value(
          value: service,
          child: const MaterialApp(home: Scaffold(body: WorkTaskListView())),
        ),
      );
      await tester.pump();

      expect(find.text('归属'), findsOneWidget);
      expect(find.text('标签'), findsNothing);
    });
  });
}
