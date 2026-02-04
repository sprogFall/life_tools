import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';
import 'package:life_tools/pages/ai_settings_page.dart';
import 'package:life_tools/pages/home_page.dart';
import 'package:life_tools/tools/stockpile_assistant/pages/stockpile_tool_page.dart';
import 'package:life_tools/tools/stockpile_assistant/services/stockpile_service.dart';
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
import '../test_helpers/test_app_wrapper.dart';

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
        await repository.createTagForToolCategory(
          name: '测试',
          toolId: 'work_log',
          categoryId: 'affiliation',
        );
        service = TagService(repository: repository);
        await service.refreshAll();
        await service.refreshToolTags('work_log');
      });
      addTearDown(() async {
        await tester.runAsync(() async => db.close());
      });
      return service;
    }

    Future<MessageService> createMessageService(WidgetTester tester) async {
      late Database db;
      late MessageService messageService;
      await tester.runAsync(() async {
        db = await openDatabase(
          inMemoryDatabasePath,
          version: DatabaseSchema.version,
          onConfigure: DatabaseSchema.onConfigure,
          onCreate: DatabaseSchema.onCreate,
          onUpgrade: DatabaseSchema.onUpgrade,
        );
        messageService = MessageService(
          repository: MessageRepository.withDatabase(db),
        );
        await messageService.init();
      });
      addTearDown(() async {
        await tester.runAsync(() async => db.close());
      });
      return messageService;
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

    testWidgets('HomePage uses IOS26AppBar', (tester) async {
      final settingsService = SettingsService();
      final messageService = await createMessageService(tester);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsService>.value(
              value: settingsService,
            ),
            ChangeNotifierProvider<MessageService>.value(value: messageService),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await tester.pump();

      expect(find.byType(IOS26AppBar), findsOneWidget);
    });

    testWidgets('StockpileToolPage uses IOS26AppBar', (tester) async {
      final service = StockpileService();
      addTearDown(service.dispose);

      await tester.pumpWidget(
        TestAppWrapper(child: StockpileToolPage(service: service)),
      );
      await tester.pump();

      expect(find.byType(IOS26AppBar), findsOneWidget);
    });

    testWidgets('TagManagerToolPage uses IOS26AppBar', (tester) async {
      final service = await createTagService(tester);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: const TestAppWrapper(child: TagManagerToolPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(IOS26AppBar), findsOneWidget);
    });

    testWidgets('WorkLogToolPage uses IOS26AppBar', (tester) async {
      final repository = FakeWorkLogRepository();

      await tester.pumpWidget(
        TestAppWrapper(child: WorkLogToolPage(repository: repository)),
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
