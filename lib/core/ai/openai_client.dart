import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_config.dart';
import 'ai_errors.dart';
import 'ai_models.dart';

class OpenAiClient {
  final http.Client _httpClient;

  OpenAiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Future<AiChatResult> chatCompletionsRaw({
    required AiConfig config,
    required Map<String, Object?> body,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = _buildChatCompletionsUri(config.baseUrl);

    final response = await _httpClient
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
        responseBody: response.body,
      );
    }

    final json = jsonDecode(_decodeUtf8(response)) as Map<String, dynamic>;
    final choices = (json['choices'] as List<dynamic>?);
    final first = (choices?.firstOrNull as Map<String, dynamic>?);
    final message = first?['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null) {
      throw const AiApiException(
        statusCode: 200,
        message: '响应中未找到 choices[0].message.content',
      );
    }
    return AiChatResult(text: content);
  }

  Future<AiChatResult> chatCompletions({
    required AiConfig config,
    required AiChatRequest request,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = _buildChatCompletionsUri(config.baseUrl);
    final body = <String, dynamic>{
      'model': config.model,
      'messages': request.messages.map((m) => m.toJson()).toList(),
      'temperature': request.temperature ?? config.temperature,
      'max_tokens': request.maxOutputTokens ?? config.maxOutputTokens,
    };

    if (request.responseFormat == AiResponseFormat.jsonObject) {
      body['response_format'] = {'type': 'json_object'};
    }

    final response = await _httpClient
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
        responseBody: response.body,
      );
    }

    final json = jsonDecode(_decodeUtf8(response)) as Map<String, dynamic>;
    final choices = (json['choices'] as List<dynamic>?);
    final first = (choices?.firstOrNull as Map<String, dynamic>?);
    final message = first?['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null) {
      throw const AiApiException(
        statusCode: 200,
        message: '响应中未找到 choices[0].message.content',
      );
    }
    return AiChatResult(text: content);
  }

  Uri _buildChatCompletionsUri(String baseUrl) {
    final base = Uri.parse(baseUrl);
    final segments = <String>[
      ...base.pathSegments.where((s) => s.trim().isNotEmpty),
    ];

    if (segments.isNotEmpty && segments.last == 'v1') {
      segments.addAll(['chat', 'completions']);
    } else {
      segments.addAll(['v1', 'chat', 'completions']);
    }

    return base.replace(pathSegments: segments);
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final json = jsonDecode(_decodeUtf8(response)) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    } catch (_) {
      // ignore
    }
    final body = response.body;
    if (body.trim().isNotEmpty) return body;
    return '请求失败，HTTP ${response.statusCode}';
  }

  static String _decodeUtf8(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return response.body;
    }
  }
}
