import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/ai/ai_models.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:life_tools/core/ai/ai_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/fake_openai_client.dart';

void main() {
  group('AiPromptComposer', () {
    test('有上下文时应拼接上下文和输入标签', () {
      final prompt = AiPromptComposer.compose(
        context: '当前日期：2026-02-07',
        inputLabel: '用户输入',
        userInput: '  买了牛奶2盒  ',
      );

      expect(prompt, '当前日期：2026-02-07\n\n用户输入：\n买了牛奶2盒');
    });

    test('无上下文时应只输出输入标签与内容', () {
      final prompt = AiPromptComposer.compose(
        inputLabel: '用户语音转写',
        userInput: '记录工时90分钟',
      );

      expect(prompt, '用户语音转写：\n记录工时90分钟');
    });
  });

  group('AiUseCaseExecutor', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('run 应按 spec 组装请求参数并调用 chatText', () async {
      final configService = AiConfigService();
      await configService.init();
      await configService.save(
        const AiConfig(
          baseUrl: 'https://example.com',
          apiKey: 'k',
          model: 'm',
          temperature: 0.7,
          maxOutputTokens: 1024,
        ),
      );

      final fakeClient = FakeOpenAiClient(replyText: 'ok');
      final aiService = AiService(
        configService: configService,
        client: fakeClient,
      );
      final executor = AiUseCaseExecutor(aiService: aiService);
      const spec = AiUseCaseSpec(
        id: 'work_log_voice_to_intent',
        systemPrompt: '你是一个解析器',
        inputLabel: '用户语音转写',
        responseFormat: AiResponseFormat.jsonObject,
        temperature: 0.2,
        maxOutputTokens: 800,
        timeout: Duration(seconds: 30),
      );

      final text = await executor.run(
        spec: spec,
        context: '当前日期：2026-02-07',
        userInput: '今天开发了 2 小时',
      );

      expect(text, 'ok');
      final request = fakeClient.lastRequest;
      expect(request, isNotNull);
      expect(request!.messages.length, 2);
      expect(request.messages.first.role, AiRole.system);
      expect(request.messages.first.content, '你是一个解析器');
      expect(request.messages.last.role, AiRole.user);
      expect(
        request.messages.last.content,
        '当前日期：2026-02-07\n\n用户语音转写：\n今天开发了 2 小时',
      );
      expect(request.temperature, 0.2);
      expect(request.maxOutputTokens, 800);
      expect(request.responseFormat, AiResponseFormat.jsonObject);
    });

    test('runWithPrompt 应直接使用传入 prompt', () async {
      final configService = AiConfigService();
      await configService.init();
      await configService.save(
        const AiConfig(
          baseUrl: 'https://example.com',
          apiKey: 'k',
          model: 'm',
          temperature: 0.7,
          maxOutputTokens: 1024,
        ),
      );

      final fakeClient = FakeOpenAiClient(replyText: 'summary');
      final aiService = AiService(
        configService: configService,
        client: fakeClient,
      );
      final executor = AiUseCaseExecutor(aiService: aiService);
      const spec = AiUseCaseSpec(
        id: 'work_log_generate_summary',
        systemPrompt: '你是工作总结助手',
        temperature: 0.2,
        maxOutputTokens: 1600,
      );

      final text = await executor.runWithPrompt(
        spec: spec,
        prompt: '请根据以下记录输出总结',
      );

      expect(text, 'summary');
      final request = fakeClient.lastRequest;
      expect(request, isNotNull);
      expect(request!.messages.last.content, '请根据以下记录输出总结');
      expect(request.temperature, 0.2);
      expect(request.maxOutputTokens, 1600);
    });
  });
}
