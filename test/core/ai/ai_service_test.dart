import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/ai/ai_errors.dart';
import 'package:life_tools/core/ai/ai_models.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/fake_openai_client.dart';

void main() {
  group('AiService', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('未配置时应抛出AiNotConfiguredException', () async {
      final configService = AiConfigService();
      await configService.init();

      final aiService = AiService(
        configService: configService,
        client: FakeOpenAiClient(replyText: 'ok'),
      );

      await expectLater(
        () => aiService.chatText(prompt: 'hi'),
        throwsA(isA<AiNotConfiguredException>()),
      );
    });

    test('配置后应能返回文本，并正确拼装messages', () async {
      final configService = AiConfigService();
      await configService.init();
      await configService.save(
        const AiConfig(
          baseUrl: 'https://example.com',
          apiKey: 'k',
          model: 'm',
          temperature: 0.2,
          maxOutputTokens: 128,
        ),
      );

      final fakeClient = FakeOpenAiClient(replyText: 'hello');
      final aiService = AiService(
        configService: configService,
        client: fakeClient,
      );

      final text = await aiService.chatText(
        prompt: '请回复OK',
        systemPrompt: '你是一个助手',
        responseFormat: AiResponseFormat.jsonObject,
      );

      expect(text, 'hello');
      expect(fakeClient.lastConfig, isNotNull);
      expect(fakeClient.lastRequest, isNotNull);
      expect(fakeClient.lastRequest!.messages.length, 2);
      expect(fakeClient.lastRequest!.messages.first.role, AiRole.system);
      expect(
        fakeClient.lastRequest!.responseFormat,
        AiResponseFormat.jsonObject,
      );
    });

    test('chatStream 应返回流式分片', () async {
      final configService = AiConfigService();
      await configService.init();
      await configService.save(
        const AiConfig(
          baseUrl: 'https://example.com',
          apiKey: 'k',
          model: 'm',
          temperature: 0.2,
          maxOutputTokens: 128,
        ),
      );

      final fakeClient = FakeOpenAiClient(
        replyText: 'hello',
        replyUsage: const AiTokenUsage(
          promptTokens: 12,
          completionTokens: 5,
          totalTokens: 17,
        ),
        streamReply: const [
          AiChatStreamChunk(textDelta: 'A'),
          AiChatStreamChunk(reasoningDelta: '思考'),
          AiChatStreamChunk(textDelta: 'B'),
          AiChatStreamChunk(
            usage: AiTokenUsage(
              promptTokens: 21,
              completionTokens: 8,
              totalTokens: 29,
            ),
          ),
        ],
      );
      final aiService = AiService(
        configService: configService,
        client: fakeClient,
      );

      final chunks = await aiService
          .chatStream(messages: const [AiMessage.user('请流式返回')])
          .toList();

      expect(chunks.length, 4);
      expect(chunks[0].textDelta, 'A');
      expect(chunks[1].reasoningDelta, '思考');
      expect(chunks[2].textDelta, 'B');
      expect(chunks[3].usage?.promptTokens, 21);
      expect(chunks[3].usage?.completionTokens, 8);
      expect(chunks[3].usage?.totalTokens, 29);

      final chatResult = await aiService.chat(
        messages: const [AiMessage.user('请返回')],
      );
      expect(chatResult.usage?.promptTokens, 12);
      expect(chatResult.usage?.completionTokens, 5);
      expect(chatResult.usage?.totalTokens, 17);
    });
  });
}
