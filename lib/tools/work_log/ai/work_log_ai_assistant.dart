import '../../../core/ai/ai_service.dart';
import '../../../core/ai/ai_use_case.dart';
import 'work_log_ai_prompts.dart';

abstract interface class WorkLogAiAssistant {
  Future<String> voiceTextToIntentJson({
    required String voiceText,
    required String context,
  });
}

class DefaultWorkLogAiAssistant implements WorkLogAiAssistant {
  final AiUseCaseExecutor _executor;

  DefaultWorkLogAiAssistant({required AiService aiService})
    : _executor = AiUseCaseExecutor(aiService: aiService);

  @override
  Future<String> voiceTextToIntentJson({
    required String voiceText,
    required String context,
  }) {
    return _executor.run(
      spec: WorkLogAiPrompts.voiceToIntentUseCase,
      userInput: voiceText,
      context: context,
    );
  }
}
