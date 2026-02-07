import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_models.dart';
import 'package:life_tools/core/ai/openai_client.dart';

class FakeOpenAiClient extends OpenAiClient {
  AiConfig? lastConfig;
  AiChatRequest? lastRequest;
  final AiChatResult reply;
  final Duration responseDelay;

  FakeOpenAiClient({
    required String replyText,
    this.responseDelay = Duration.zero,
  }) : reply = AiChatResult(text: replyText);

  @override
  Future<AiChatResult> chatCompletions({
    required AiConfig config,
    required AiChatRequest request,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    lastConfig = config;
    lastRequest = request;
    if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }
    return reply;
  }
}
