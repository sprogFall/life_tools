import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_models.dart';
import 'package:life_tools/core/ai/openai_client.dart';

class FakeOpenAiClient extends OpenAiClient {
  AiConfig? lastConfig;
  AiChatRequest? lastRequest;
  final AiChatResult reply;

  FakeOpenAiClient({required String replyText})
    : reply = AiChatResult(text: replyText);

  @override
  Future<AiChatResult> chatCompletions({
    required AiConfig config,
    required AiChatRequest request,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    lastConfig = config;
    lastRequest = request;
    return reply;
  }
}
