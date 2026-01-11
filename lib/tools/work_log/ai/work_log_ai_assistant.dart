import '../../../core/ai/ai_models.dart';
import '../../../core/ai/ai_service.dart';
import 'work_log_ai_prompts.dart';

abstract interface class WorkLogAiAssistant {
  Future<String> voiceTextToIntentJson({
    required String voiceText,
    required String context,
  });
}

class DefaultWorkLogAiAssistant implements WorkLogAiAssistant {
  final AiService _aiService;

  const DefaultWorkLogAiAssistant({required AiService aiService}) : _aiService = aiService;

  @override
  Future<String> voiceTextToIntentJson({
    required String voiceText,
    required String context,
  }) {
    final prompt = '$context\n\n用户语音转写：\n$voiceText';
    return _aiService.chatText(
      prompt: prompt,
      systemPrompt: WorkLogAiPrompts.voiceToIntentSystemPrompt,
      responseFormat: AiResponseFormat.jsonObject,
      temperature: 0.2,
      maxOutputTokens: 800,
      timeout: const Duration(seconds: 60),
    );
  }
}

