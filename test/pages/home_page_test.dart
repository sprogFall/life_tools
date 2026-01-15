import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_tools/pages/home_page.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:life_tools/core/sync/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('HomePage', () {
    late SettingsService mockSettingsService;
    late AiConfigService aiConfigService;
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

      syncConfigService = SyncConfigService();
      await syncConfigService.init();
      syncService = SyncService(configService: syncConfigService);
    });

    Widget wrap(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(
            value: mockSettingsService,
          ),
          ChangeNotifierProvider<AiConfigService>.value(value: aiConfigService),
          ChangeNotifierProvider<SyncConfigService>.value(
            value: syncConfigService,
          ),
          ChangeNotifierProvider<SyncService>.value(value: syncService),
        ],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('åº”è¯¥æ˜¾ç¤ºåº”ç”¨æ ‡é¢˜', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const HomePage()));
      expect(find.text('小蜜'), findsOneWidget);
    });

    testWidgets('åº”è¯¥æ˜¾ç¤ºæ¬¢è¿Žå¡ç‰‡', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const HomePage()));
      expect(find.text('欢迎回来'), findsOneWidget);
    });

    testWidgets('åº”è¯¥æ˜¾ç¤ºè®¾ç½®æŒ‰é’®', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const HomePage()));
      expect(find.byIcon(CupertinoIcons.gear), findsOneWidget);
    });

    testWidgets('åº”è¯¥æ˜¾ç¤ºå·¥å…·å¡ç‰‡', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const HomePage()));

      // æ£€æŸ¥æ˜¯å¦æ˜¾ç¤ºäº†æ³¨å†Œçš„å·¥å…?
      expect(find.text('工作记录'), findsOneWidget);
      expect(find.text('标签管理'), findsOneWidget);
    });

    testWidgets('ç‚¹å‡»è®¾ç½®æŒ‰é’®åº”è¯¥æ‰“å¼€è®¾ç½®å¼¹å‡ºå±?', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const HomePage()));

      await tester.tap(find.byIcon(CupertinoIcons.gear));
      await tester.pumpAndSettle();

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('默认打开工具'), findsOneWidget);
    });

    testWidgets('设置弹出层中 AI 模型名过长应使用省略号', (tester) async {
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

      await tester.pumpWidget(wrap(const HomePage()));
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
