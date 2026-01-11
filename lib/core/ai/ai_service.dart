import 'dart:convert';
import 'dart:io';

import 'ai_config.dart';
import 'ai_config_service.dart';
import 'ai_errors.dart';
import 'ai_models.dart';
import 'openai_client.dart';

class AiService {
  final AiConfigService _configService;
  final OpenAiClient _client;

  /// AI 调用入口（OpenAI 兼容）。
  ///
  /// 说明：
  /// - 默认从 `AiConfigService` 读取配置（由 UI 保存到本地）。
  /// - 需要在业务层处理异常：未配置/调用失败等。
  AiService({
    required AiConfigService configService,
    OpenAiClient? client,
  })  : _configService = configService,
        _client = client ?? OpenAiClient();

  /// 发送完整 messages（多轮对话/自定义 role 等）。
  ///
  /// 如果你只需要「一段 prompt -> 返回文本」，优先使用 `chatText(...)`。
  Future<AiChatResult> chat({
    required List<AiMessage> messages,
    double? temperature,
    int? maxOutputTokens,
    AiResponseFormat responseFormat = AiResponseFormat.text,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final config = _configService.config;
    if (config == null || !config.isValid) {
      throw const AiNotConfiguredException('请先在设置中完成 AI 配置');
    }

    return _client.chatCompletions(
      config: config,
      request: AiChatRequest(
        messages: messages,
        temperature: temperature,
        maxOutputTokens: maxOutputTokens,
        responseFormat: responseFormat,
      ),
      timeout: timeout,
    );
  }

  /// 便捷方法：传入 prompt（可选 systemPrompt/history），返回纯文本内容。
  ///
  /// 当你希望 AI 返回 JSON 给业务侧解析时，传 `responseFormat: AiResponseFormat.jsonObject`。
  Future<String> chatText({
    required String prompt,
    String? systemPrompt,
    List<AiMessage> historyMessages = const [],
    double? temperature,
    int? maxOutputTokens,
    AiResponseFormat responseFormat = AiResponseFormat.text,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final messages = <AiMessage>[
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        AiMessage.system(systemPrompt),
      ...historyMessages,
      AiMessage.user(prompt),
    ];

    final result = await chat(
      messages: messages,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
      responseFormat: responseFormat,
      timeout: timeout,
    );

    return result.text;
  }

  /// 用“临时配置”直接发起请求（不依赖已保存的配置）。
  ///
  /// 主要用于「AI配置页」的连接测试：用户可能还没点保存，也需要立即验证可用性。
  Future<String> chatTextWithConfig({
    required AiConfig config,
    required String prompt,
    String? systemPrompt,
    List<AiMessage> historyMessages = const [],
    double? temperature,
    int? maxOutputTokens,
    AiResponseFormat responseFormat = AiResponseFormat.text,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (!config.isValid) {
      throw const AiNotConfiguredException('AI 配置不合法，请检查 Base URL / API Key / Model 等配置');
    }

    final messages = <AiMessage>[
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        AiMessage.system(systemPrompt),
      ...historyMessages,
      AiMessage.user(prompt),
    ];

    final result = await _client.chatCompletions(
      config: config,
      request: AiChatRequest(
        messages: messages,
        temperature: temperature,
        maxOutputTokens: maxOutputTokens,
        responseFormat: responseFormat,
      ),
      timeout: timeout,
    );

    return result.text;
  }

  Future<String> transcribeAudioFile({
    required String filePath,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final config = _configService.config;
    if (config == null || !config.isValid) {
      throw const AiNotConfiguredException('请先在设置中完成 AI 配置');
    }

    final bytes = await File(filePath).readAsBytes();
    final base64Audio = base64Encode(bytes);
    final format = _inferAudioFormat(filePath);

    final body = <String, Object?>{
      'model': config.speechToTextModel,
      'messages': [
        {
          'role': 'system',
          'content': '你是语音转写助手。请把用户提供的音频转写为中文纯文本，只输出转写结果，不要输出多余内容。',
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_audio',
              'input_audio': {
                'data': base64Audio,
                'format': format,
              },
            },
            {
              'type': 'text',
              'text': '请转写以上音频为中文文本。',
            },
          ],
        },
      ],
      'temperature': 0,
      'max_tokens': 1024,
    };

    final result = await _client.chatCompletionsRaw(
      config: config,
      body: body,
      timeout: timeout,
    );

    return result.text;
  }

  static String _inferAudioFormat(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.wav')) return 'wav';
    if (lower.endsWith('.mp3')) return 'mp3';
    if (lower.endsWith('.m4a')) return 'm4a';
    if (lower.endsWith('.aac')) return 'aac';
    return 'wav';
  }
}
