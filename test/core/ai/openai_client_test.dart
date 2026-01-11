import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_errors.dart';
import 'package:life_tools/core/ai/ai_models.dart';
import 'package:life_tools/core/ai/openai_client.dart';

void main() {
  group('OpenAiClient', () {
    test('baseUrl不含/v1时应自动补全chat/completions路径', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://example.com/v1/chat/completions');
        expect(request.headers['Authorization'], 'Bearer test-key');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'gpt-4o-mini');
        expect(body['messages'], isA<List<dynamic>>());

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'hello'},
              },
            ],
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final client = OpenAiClient(httpClient: mockClient);
      const config = AiConfig(
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        model: 'gpt-4o-mini',
        temperature: 0.2,
        maxOutputTokens: 128,
      );

      final result = await client.chatCompletions(
        config: config,
        request: const AiChatRequest(
          messages: [AiMessage.user('hi')],
        ),
      );

      expect(result.text, 'hello');
    });

    test('baseUrl含/v1时不应重复拼接/v1', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://example.com/v1/chat/completions');
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'ok'},
              },
            ],
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final client = OpenAiClient(httpClient: mockClient);
      const config = AiConfig(
        baseUrl: 'https://example.com/v1',
        apiKey: 'test-key',
        model: 'gpt-4o-mini',
        temperature: 0.2,
        maxOutputTokens: 128,
      );

      final result = await client.chatCompletions(
        config: config,
        request: const AiChatRequest(
          messages: [AiMessage.user('hi')],
        ),
      );

      expect(result.text, 'ok');
    });

    test('错误响应应抛出AiApiException并包含服务端信息', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'invalid api key'},
          }),
          401,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final client = OpenAiClient(httpClient: mockClient);
      const config = AiConfig(
        baseUrl: 'https://example.com',
        apiKey: 'bad-key',
        model: 'gpt-4o-mini',
        temperature: 0.2,
        maxOutputTokens: 128,
      );

      await expectLater(
        () => client.chatCompletions(
          config: config,
          request: const AiChatRequest(messages: [AiMessage.user('hi')]),
        ),
        throwsA(
          isA<AiApiException>().having(
            (e) => e.message,
            'message',
            contains('invalid api key'),
          ),
        ),
      );
    });

    test('chatCompletionsRaw 应使用与文字相同的 chat/completions 路径', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://example.com/v1/chat/completions');
        expect(request.headers['Authorization'], 'Bearer test-key');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'whisper-1');
        expect(body['messages'], isA<List<dynamic>>());

        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': '转写文本'},
                },
              ],
            }),
          ),
          200,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      });

      final client = OpenAiClient(httpClient: mockClient);
      const config = AiConfig(
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        model: 'gpt-4o-mini',
        speechToTextModel: 'whisper-1',
        temperature: 0.2,
        maxOutputTokens: 128,
      );

      final result = await client.chatCompletionsRaw(
        config: config,
        body: const {
          'model': 'whisper-1',
          'messages': [
            {'role': 'user', 'content': 'hi'},
          ],
        },
      );

      expect(result.text, '转写文本');
    });
  });
}

