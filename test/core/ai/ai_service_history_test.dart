import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_call_history_service.dart';
import 'package:life_tools/core/ai/ai_call_source.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/fake_openai_client.dart';

void main() {
  group('AiService 调用历史记录', () {
    const source = AiCallSource(
      toolId: 'work_log',
      toolName: '工作记录',
      featureId: 'voice_to_intent',
      featureName: '语音解析',
    );

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('chatText 传入来源时应写入历史', () async {
      final configService = AiConfigService();
      await configService.init();
      await configService.save(
        const AiConfig(
          baseUrl: 'https://example.com',
          apiKey: 'k',
          model: 'gpt-4o-mini',
          temperature: 0.2,
          maxOutputTokens: 800,
        ),
      );

      final historyService = AiCallHistoryService();
      await historyService.init();

      final aiService = AiService(
        configService: configService,
        client: FakeOpenAiClient(replyText: 'ok'),
        historyService: historyService,
      );

      await aiService.chatText(
        systemPrompt: '你是解析器',
        prompt: '用户输入',
        source: source,
      );

      expect(historyService.records.length, 1);
      final record = historyService.records.first;
      expect(record.source.toolName, '工作记录');
      expect(record.source.featureName, '语音解析');
      expect(record.model, 'gpt-4o-mini');
      expect(record.prompt, contains('[system]'));
      expect(record.prompt, contains('[user]'));
      expect(record.response, 'ok');
    });

    test('模型测试调用 chatTextWithConfig 不应写入历史', () async {
      final configService = AiConfigService();
      await configService.init();

      final historyService = AiCallHistoryService();
      await historyService.init();

      final aiService = AiService(
        configService: configService,
        client: FakeOpenAiClient(replyText: 'ok'),
        historyService: historyService,
      );

      await aiService.chatTextWithConfig(
        config: const AiConfig(
          baseUrl: 'https://example.com',
          apiKey: 'k',
          model: 'gpt-test',
          temperature: 0.3,
          maxOutputTokens: 300,
        ),
        prompt: '连接测试',
      );

      expect(historyService.records, isEmpty);
    });
  });
}
