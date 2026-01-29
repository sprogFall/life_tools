import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:life_tools/core/sync/services/sync_service.dart';
import 'package:life_tools/pages/home_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('HomePage', () {
    late SettingsService mockSettingsService;
    late AiConfigService aiConfigService;
    late ObjStoreConfigService objStoreConfigService;
    late SyncConfigService syncConfigService;
    late SyncService syncService;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      ToolRegistry.instance.registerAll();
      mockSettingsService = SettingsService();

      aiConfigService = AiConfigService();
      await aiConfigService.init();

      objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();

      syncConfigService = SyncConfigService();
      await syncConfigService.init();
      syncService = SyncService(configService: syncConfigService);
    });

    Future<({Database db, MessageService messageService})> createMessageService(
      WidgetTester tester,
    ) async {
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
      return (db: db, messageService: messageService);
    }

    Widget wrap(Widget child, MessageService messageService) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(
            value: mockSettingsService,
          ),
          ChangeNotifierProvider<AiConfigService>.value(value: aiConfigService),
          ChangeNotifierProvider<ObjStoreConfigService>.value(
            value: objStoreConfigService,
          ),
          ChangeNotifierProvider<SyncConfigService>.value(
            value: syncConfigService,
          ),
          ChangeNotifierProvider<SyncService>.value(value: syncService),
          ChangeNotifierProvider<MessageService>.value(value: messageService),
        ],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('应渲染应用标题', (WidgetTester tester) async {
      final deps = await createMessageService(tester);
      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));
      expect(find.text('小蜜'), findsOneWidget);
    });

    testWidgets('无消息时应展示空态文案', (WidgetTester tester) async {
      final deps = await createMessageService(tester);
      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));
      expect(find.text('当前暂时没有新的消息'), findsOneWidget);
    });

    testWidgets('有未读消息时应展示消息内容', (WidgetTester tester) async {
      final deps = await createMessageService(tester);
      await tester.runAsync(() async {
        await deps.messageService.upsertMessage(
          toolId: 'work_log',
          title: '工作记录',
          body: '这是一条测试消息',
          createdAt: DateTime(2026, 1, 1, 9),
        );
      });

      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));
      await tester.pump();

      expect(find.text('这是一条测试消息'), findsOneWidget);
    });

    testWidgets('应展示设置入口', (WidgetTester tester) async {
      final deps = await createMessageService(tester);
      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));
      expect(find.byIcon(CupertinoIcons.gear), findsOneWidget);
    });

    testWidgets('应展示工具入口', (WidgetTester tester) async {
      final deps = await createMessageService(tester);
      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));
      expect(find.text('工作记录'), findsOneWidget);
      expect(find.text('标签管理'), findsOneWidget);
    });

    testWidgets('设置弹出层应展示设置项', (tester) async {
      final deps = await createMessageService(tester);
      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));

      await tester.tap(find.byIcon(CupertinoIcons.gear));
      await tester.pumpAndSettle();

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('工具管理'), findsOneWidget);
    });

    testWidgets('设置弹出层中 AI 模型名过长应使用省略号', (tester) async {
      final deps = await createMessageService(tester);
      await aiConfigService.save(
        const AiConfig(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'test-key',
          model:
              'this-is-a-very-very-very-very-very-long-model-name-for-testing',
          temperature: 0.7,
          maxOutputTokens: 1024,
        ),
      );

      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));
      await tester.tap(find.byIcon(CupertinoIcons.gear));
      await tester.pumpAndSettle();

      final modelText = find.text(
        'this-is-a-very-very-very-very-very-long-model-name-for-testing',
      );
      expect(modelText, findsOneWidget);

      final widget = tester.widget<Text>(modelText);
      expect(widget.maxLines, 1);
      expect(widget.overflow, TextOverflow.ellipsis);
    });
  });
}
