import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_call_history_service.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:life_tools/pages/ai_settings_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/fake_openai_client.dart';

void main() {
  group('AiSettingsPage 历史入口与按钮布局', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    Future<void> pumpPage(WidgetTester tester) async {
      final configService = AiConfigService();
      await configService.init();

      final historyService = AiCallHistoryService();
      await historyService.init();

      final aiService = AiService(
        configService: configService,
        client: FakeOpenAiClient(replyText: 'ok'),
        historyService: historyService,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: configService),
            ChangeNotifierProvider.value(value: historyService),
            Provider<AiService>.value(value: aiService),
          ],
          child: const MaterialApp(home: AiSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('保存按钮应在测试按钮下方且尺寸一致', (tester) async {
      await pumpPage(tester);

      final testButtonFinder = find.byKey(const ValueKey('ai_test_button'));
      final saveButtonFinder = find.byKey(const ValueKey('ai_save_button'));

      expect(testButtonFinder, findsOneWidget);
      expect(saveButtonFinder, findsOneWidget);

      final testSize = tester.getSize(testButtonFinder);
      final saveSize = tester.getSize(saveButtonFinder);
      expect(saveSize, testSize);

      final testOffset = tester.getTopLeft(testButtonFinder);
      final saveOffset = tester.getTopLeft(saveButtonFinder);
      expect(saveOffset.dy, greaterThan(testOffset.dy));
    });

    testWidgets('点击右上角历史按钮应进入历史页', (tester) async {
      await pumpPage(tester);

      final historyButton = find.byKey(const ValueKey('ai_history_button'));
      expect(historyButton, findsOneWidget);

      await tester.tap(historyButton);
      await tester.pumpAndSettle();

      expect(find.text('AI 调用历史'), findsOneWidget);
      expect(find.text('暂无 AI 调用记录'), findsOneWidget);
    });
  });
}
