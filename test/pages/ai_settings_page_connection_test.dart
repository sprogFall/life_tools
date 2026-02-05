import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:life_tools/pages/ai_settings_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/fake_openai_client.dart';
import '../test_helpers/test_app_wrapper.dart';

void main() {
  group('AiSettingsPage 测试连接', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('点击测试连接后应弹窗显示AI返回内容', (tester) async {
      final configService = AiConfigService();
      await configService.init();

      final fakeClient = FakeOpenAiClient(replyText: '我是测试模型');
      final aiService = AiService(
        configService: configService,
        client: fakeClient,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: configService),
            Provider<AiService>.value(value: aiService),
          ],
          child: const TestAppWrapper(child: AiSettingsPage()),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('ai_apiKey_field')),
        'test-key',
      );

      await tester.tap(find.byKey(const ValueKey('ai_test_button')));
      await tester.pumpAndSettle();

      expect(find.text('测试结果'), findsOneWidget);
      expect(find.textContaining('我是测试模型'), findsOneWidget);

      expect(fakeClient.lastRequest, isNotNull);
      expect(
        fakeClient.lastRequest!.messages.last.content,
        contains('你好，请介绍一下你是什么模型'),
      );
    });
  });
}
