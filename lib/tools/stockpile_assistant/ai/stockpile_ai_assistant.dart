import '../../../core/ai/ai_models.dart';
import '../../../core/ai/ai_service.dart';
import 'stockpile_ai_prompts.dart';

abstract interface class StockpileAiAssistant {
  Future<String> textToIntentJson({
    required String text,
    required String context,
  });
}

class DefaultStockpileAiAssistant implements StockpileAiAssistant {
  final AiService _aiService;

  const DefaultStockpileAiAssistant({required AiService aiService})
    : _aiService = aiService;

  @override
  Future<String> textToIntentJson({
    required String text,
    required String context,
  }) {
    final prompt = '$context\n\n用户输入：\n$text';
    return _aiService.chatText(
      prompt: prompt,
      systemPrompt: StockpileAiPrompts.textToIntentSystemPrompt,
      responseFormat: AiResponseFormat.jsonObject,
      temperature: 0.2,
      maxOutputTokens: 900,
      timeout: const Duration(seconds: 60),
    );
  }
}
