import 'ai_config_service.dart';
import 'ai_errors.dart';
import 'ai_models.dart';
import 'openai_client.dart';
import 'ai_config.dart';

class AiService {
  final AiConfigService _configService;
  final OpenAiClient _client;

  AiService({
    required AiConfigService configService,
    OpenAiClient? client,
  })  : _configService = configService,
        _client = client ?? OpenAiClient();

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
}
