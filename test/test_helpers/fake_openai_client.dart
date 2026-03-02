import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_models.dart';
import 'package:life_tools/core/ai/openai_client.dart';

class FakeOpenAiClient extends OpenAiClient {
  AiConfig? lastConfig;
  AiChatRequest? lastRequest;
  final AiChatResult reply;
  final Duration responseDelay;
  final List<AiChatStreamChunk> streamReply;
  final Duration streamChunkDelay;

  FakeOpenAiClient({
    required String replyText,
    String replyReasoning = '',
    this.responseDelay = Duration.zero,
    this.streamReply = const [],
    this.streamChunkDelay = Duration.zero,
  }) : reply = AiChatResult(text: replyText, reasoning: replyReasoning);

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

  @override
  Stream<AiChatStreamChunk> chatCompletionsStream({
    required AiConfig config,
    required AiChatRequest request,
    Duration timeout = const Duration(seconds: 60),
  }) async* {
    lastConfig = config;
    lastRequest = request;

    if (streamReply.isEmpty) {
      if (reply.text.isNotEmpty || reply.reasoning.isNotEmpty) {
        yield AiChatStreamChunk(
          textDelta: reply.text,
          reasoningDelta: reply.reasoning,
        );
      }
      return;
    }

    for (final chunk in streamReply) {
      if (streamChunkDelay > Duration.zero) {
        await Future<void>.delayed(streamChunkDelay);
      }
      yield chunk;
    }
  }
}
