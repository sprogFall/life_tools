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

  /// 语音转文字（占位实现）
  ///
  /// 当前仓库已引入语音录音能力，但尚未接入转写 API。
  /// 若你需要开启该能力，我可以按你的服务端/模型要求补全实现（例如 OpenAI /whisper）。
  Future<String> transcribeAudioFile({
    required String filePath,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    throw UnimplementedError('当前版本暂未实现语音转文字（filePath: $filePath, timeout: $timeout）');
  }
}
