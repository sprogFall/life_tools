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
    return _parseChatResult(json);
  }

  Future<AiChatResult> chatCompletions({
    required AiConfig config,
    required AiChatRequest request,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = _buildChatCompletionsUri(config.baseUrl);
    final body = _buildChatRequestBody(
      config: config,
      request: request,
      stream: false,
    );

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
    return _parseChatResult(json);
  }

  Stream<AiChatStreamChunk> chatCompletionsStream({
    required AiConfig config,
    required AiChatRequest request,
    Duration timeout = const Duration(seconds: 60),
  }) async* {
    final uri = _buildChatCompletionsUri(config.baseUrl);
    var response = await _sendChatCompletionsStreamRequest(
      uri: uri,
      config: config,
      body: _buildChatRequestBody(
        config: config,
        request: request,
        stream: true,
      ),
      timeout: timeout,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = await _buildStreamError(response);
      if (!_shouldRetryStreamWithoutUsage(error)) {
        throw error;
      }
      response = await _sendChatCompletionsStreamRequest(
        uri: uri,
        config: config,
        body: _buildChatRequestBody(
          config: config,
          request: request,
          stream: true,
          includeStreamUsage: false,
        ),
        timeout: timeout,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw await _buildStreamError(response);
      }
    }

    yield* _readChatCompletionsStreamResponse(response);
  }

  Future<http.StreamedResponse> _sendChatCompletionsStreamRequest({
    required Uri uri,
    required AiConfig config,
    required Map<String, dynamic> body,
    required Duration timeout,
  }) {
    final httpRequest = http.Request('POST', uri)
      ..headers.addAll({
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode(body);
    return _httpClient.send(httpRequest).timeout(timeout);
  }

  Future<AiApiException> _buildStreamError(
    http.StreamedResponse response,
  ) async {
    final responseBodyBytes = await response.stream.toBytes();
    final responseBody = _decodeUtf8Bytes(responseBodyBytes);
    return AiApiException(
      statusCode: response.statusCode,
      message: _extractErrorMessageFromBody(responseBody, response.statusCode),
      responseBody: responseBody,
    );
  }

  bool _shouldRetryStreamWithoutUsage(AiApiException error) {
    final detail = '${error.message}\n${error.responseBody ?? ''}'
        .toLowerCase();
    return detail.contains('stream_options') ||
        detail.contains('include_usage') ||
        detail.contains('include usage');
  }

  Stream<AiChatStreamChunk> _readChatCompletionsStreamResponse(
    http.StreamedResponse response,
  ) async* {
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    if (contentType.contains('application/json')) {
      final responseBodyBytes = await response.stream.toBytes();
      final responseBody = _decodeUtf8Bytes(responseBodyBytes);
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final result = _parseChatResult(json);
      yield AiChatStreamChunk(
        textDelta: result.text,
        reasoningDelta: result.reasoning,
        usage: result.usage,
      );
      return;
    }

    final pendingDataLines = <String>[];
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        final parsed = _parseSsePayload(pendingDataLines);
        pendingDataLines.clear();
        if (parsed.done) {
          break;
        }
        final chunk = parsed.chunk;
        if (chunk != null && !chunk.isEmpty) {
          yield chunk;
        }
        continue;
      }

      if (trimmedLine.startsWith('data:')) {
        pendingDataLines.add(trimmedLine.substring(5).trimLeft());
      }
    }

    if (pendingDataLines.isNotEmpty) {
      final parsed = _parseSsePayload(pendingDataLines);
      final chunk = parsed.chunk;
      if (!parsed.done && chunk != null && !chunk.isEmpty) {
        yield chunk;
      }
    }
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

  Map<String, dynamic> _buildChatRequestBody({
    required AiConfig config,
    required AiChatRequest request,
    required bool stream,
    bool includeStreamUsage = true,
  }) {
    final body = <String, dynamic>{
      'model': config.model,
      'messages': request.messages.map((m) => m.toJson()).toList(),
      'temperature': request.temperature ?? config.temperature,
      'max_tokens': request.maxOutputTokens ?? config.maxOutputTokens,
    };

    if (request.responseFormat == AiResponseFormat.jsonObject) {
      body['response_format'] = {'type': 'json_object'};
    }

    if (stream) {
      body['stream'] = true;
      if (includeStreamUsage) {
        body['stream_options'] = {'include_usage': true};
      }
    }

    return body;
  }

  AiChatResult _parseChatResult(Map<String, dynamic> json) {
    final choices = (json['choices'] as List<dynamic>?);
    final first = (choices?.firstOrNull as Map<String, dynamic>?);
    final message = first?['message'] as Map<String, dynamic>?;
    final content = _extractMessageText(message?['content']);
    final reasoning = _extractReasoningFromMessage(message);
    if (content.isEmpty) {
      throw const AiApiException(
        statusCode: 200,
        message: '响应中未找到 choices[0].message.content',
      );
    }
    return AiChatResult(
      text: content,
      reasoning: reasoning,
      usage: _parseTokenUsage(json['usage']),
    );
  }

  _SseParseResult _parseSsePayload(List<String> dataLines) {
    if (dataLines.isEmpty) {
      return const _SseParseResult();
    }

    final payload = dataLines.join('\n').trim();
    if (payload.isEmpty) {
      return const _SseParseResult();
    }
    if (payload == '[DONE]') {
      return const _SseParseResult(done: true);
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      throw AiApiException(
        statusCode: 200,
        message: '流式响应解析失败：$payload',
        responseBody: payload,
      );
    }

    final choices = (json['choices'] as List<dynamic>?);
    final first = (choices?.firstOrNull as Map<String, dynamic>?);
    final delta = first?['delta'] as Map<String, dynamic>?;
    if (delta == null) {
      final usage = _parseTokenUsage(json['usage']);
      if (usage != null) {
        return _SseParseResult(chunk: AiChatStreamChunk(usage: usage));
      }
      return const _SseParseResult();
    }

    final textDelta = _extractMessageText(delta['content']);
    final reasoningDelta = _extractReasoningFromDelta(delta);
    return _SseParseResult(
      chunk: AiChatStreamChunk(
        textDelta: textDelta,
        reasoningDelta: reasoningDelta,
        usage: _parseTokenUsage(json['usage']),
      ),
    );
  }

  AiTokenUsage? _parseTokenUsage(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = raw.cast<Object?, Object?>();
    final usage = AiTokenUsage(
      promptTokens: _readInt(map, const ['prompt_tokens', 'input_tokens']),
      completionTokens: _readInt(map, const [
        'completion_tokens',
        'output_tokens',
      ]),
      totalTokens: _readInt(map, const ['total_tokens']),
    );
    return usage.isEmpty ? null : usage;
  }

  int? _readInt(Map<Object?, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value.trim());
      }
    }
    return null;
  }

  String _extractReasoningFromMessage(Map<String, dynamic>? message) {
    if (message == null) {
      return '';
    }
    final buffer = StringBuffer()
      ..write(_extractFlexibleText(message['reasoning_content']))
      ..write(_extractFlexibleText(message['reasoning']))
      ..write(_extractReasoningFromContentParts(message['content']));
    return buffer.toString();
  }

  String _extractReasoningFromDelta(Map<String, dynamic> delta) {
    final buffer = StringBuffer()
      ..write(_extractFlexibleText(delta['reasoning_content']))
      ..write(_extractFlexibleText(delta['reasoning']))
      ..write(_extractReasoningFromContentParts(delta['content']));
    return buffer.toString();
  }

  String _extractReasoningFromContentParts(Object? content) {
    if (content is! List<dynamic>) {
      return '';
    }
    final buffer = StringBuffer();
    for (final part in content) {
      if (part is! Map<String, dynamic>) {
        continue;
      }
      final type = (part['type'] as String?)?.toLowerCase() ?? '';
      if (!_isReasoningPart(type)) {
        continue;
      }
      buffer.write(_extractFlexibleText(part));
    }
    return buffer.toString();
  }

  String _extractMessageText(Object? content) {
    if (content is String) {
      return content;
    }
    if (content is List<dynamic>) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is String) {
          buffer.write(part);
          continue;
        }
        if (part is! Map<String, dynamic>) {
          continue;
        }
        final type = (part['type'] as String?)?.toLowerCase() ?? '';
        if (_isReasoningPart(type)) {
          continue;
        }
        buffer.write(_extractFlexibleText(part));
      }
      return buffer.toString();
    }
    if (content is Map<String, dynamic>) {
      final type = (content['type'] as String?)?.toLowerCase() ?? '';
      if (_isReasoningPart(type)) {
        return '';
      }
      return _extractFlexibleText(content);
    }
    return '';
  }

  bool _isReasoningPart(String type) {
    return type.contains('reason') || type.contains('think');
  }

  String _extractFlexibleText(Object? raw) {
    if (raw is String) {
      return raw;
    }
    if (raw is List<dynamic>) {
      return raw.map(_extractFlexibleText).join();
    }
    if (raw is Map<String, dynamic>) {
      final directText = raw['text'];
      final directContent = raw['content'];
      final value = raw['value'];
      final outputText = raw['output_text'];

      final candidates = <Object?>[
        directText,
        directContent,
        value,
        outputText,
      ];
      for (final candidate in candidates) {
        final extracted = _extractFlexibleText(candidate);
        if (extracted.isNotEmpty) {
          return extracted;
        }
      }
    }
    return '';
  }

  String _extractErrorMessage(http.Response response) {
    return _extractErrorMessageFromBody(
      _decodeUtf8(response),
      response.statusCode,
    );
  }

  String _extractErrorMessageFromBody(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    } catch (_) {
      // ignore
    }
    if (body.trim().isNotEmpty) return body;
    return '请求失败，HTTP $statusCode';
  }

  static String _decodeUtf8(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return response.body;
    }
  }

  static String _decodeUtf8Bytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }
}

class _SseParseResult {
  final bool done;
  final AiChatStreamChunk? chunk;

  const _SseParseResult({this.done = false, this.chunk});
}
