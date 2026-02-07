import '../../../core/ai/ai_use_case.dart';
import '../../../core/ai/ai_service.dart';
import 'stockpile_ai_prompts.dart';

abstract interface class StockpileAiAssistant {
  Future<String> textToIntentJson({
    required String text,
    required String context,
  });
}

class DefaultStockpileAiAssistant implements StockpileAiAssistant {
  final AiUseCaseExecutor _executor;

  DefaultStockpileAiAssistant({required AiService aiService})
    : _executor = AiUseCaseExecutor(aiService: aiService);

  @override
  Future<String> textToIntentJson({
    required String text,
    required String context,
  }) {
    return _executor.run(
      spec: StockpileAiPrompts.textToIntentUseCase,
      userInput: text,
      context: context,
    );
  }
}
