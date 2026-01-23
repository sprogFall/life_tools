import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';
import 'package:life_tools/pages/ai_settings_page.dart';
import 'package:life_tools/tools/tag_manager/pages/tag_edit_page.dart';
import 'package:life_tools/tools/tag_manager/pages/tag_manager_tool_page.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/pages/log/operation_log_list_page.dart';
import 'package:life_tools/tools/work_log/pages/task/work_task_detail_page.dart';
import 'package:life_tools/tools/work_log/pages/task/work_task_edit_page.dart';
import 'package:life_tools/tools/work_log/pages/time/work_time_entry_edit_page.dart';
import 'package:life_tools/tools/work_log/pages/work_log_tool_page.dart';
import 'package:life_tools/tools/work_log/services/work_log_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test_helpers/fake_work_log_repository.dart';

void main() {
  group('IOS26AppBar consistency', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ToolRegistry.instance.registerAll();
    });

    Future<TagService> createTagService(WidgetTester tester) async {
      late Database db;
      late TagRepository repository;
      late TagService service;
      await tester.runAsync(() async {
        db = await openDatabase(
          inMemoryDatabasePath,
          version: DatabaseSchema.version,
          onConfigure: DatabaseSchema.onConfigure,
          onCreate: DatabaseSchema.onCreate,
          onUpgrade: DatabaseSchema.onUpgrade,
        );

        // 预置一条标签并提前刷新缓存，避免 TagManagerToolPage 在测试结束后仍发起异步查询。
        repository = TagRepository.withDatabase(db);
        await repository.createTag(name: '测试', toolIds: const ['work_log']);
        service = TagService(repository: repository);
        await service.refreshAll();
        await service.refreshToolTags('work_log');
      });
      addTearDown(() async {
        await tester.runAsync(() async => db.close());
      });
      return service;
    }

    testWidgets('AiSettingsPage uses IOS26AppBar', (tester) async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: aiConfigService,
          child: const MaterialApp(home: AiSettingsPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(IOS26AppBar), findsOneWidget);
    });

    testWidgets('TagEditPage uses IOS26AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TagEditPage()));
      await tester.pump();

      expect(find.byType(IOS26AppBar), findsOneWidget);
    });

    testWidgets('TagManagerToolPage uses IOS26AppBar', (tester) async {
      final service = await createTagService(tester);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: const MaterialApp(home: TagManagerToolPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(IOS26AppBar), findsOneWidget);
    });

    testWidgets('WorkLogToolPage uses IOS26AppBar', (tester) async {
      final repository = FakeWorkLogRepository();

      await tester.pumpWidget(
        MaterialApp(home: WorkLogToolPage(repository: repository)),
      );
      await tester.pump();

      expect(find.byType(IOS26AppBar), findsOneWidget);
    });

    testWidgets('WorkTaskEditPage uses IOS26AppBar', (tester) async {
      final repository = FakeWorkLogRepository();
      final service = WorkLogService(repository: repository);
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: const MaterialApp(home: WorkTaskEditPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(IOS26AppBar), findsOneWidget);
    });

    testWidgets('WorkTimeEntryEditPage uses IOS26AppBar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: WorkTimeEntryEditPage(taskId: 1)),
      );
      await tester.pump();

      expect(find.byType(IOS26AppBar), findsOneWidget);
    });

    testWidgets('OperationLogListPage uses IOS26AppBar', (tester) async {
      final repository = FakeWorkLogRepository();
      final service = WorkLogService(repository: repository);
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: const MaterialApp(home: OperationLogListPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(IOS26AppBar), findsOneWidget);
    });

    testWidgets('WorkTaskDetailPage uses IOS26AppBar', (tester) async {
      final repository = FakeWorkLogRepository();
      final taskId = await repository.createTask(
        WorkTask.create(
          title: 'Task A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
        ),
      );
      final service = WorkLogService(repository: repository);
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: MaterialApp(
            home: WorkTaskDetailPage(taskId: taskId, title: 'Task A'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(IOS26AppBar), findsOneWidget);
    });
  });
}
