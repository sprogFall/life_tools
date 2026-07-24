import '../../../core/ai/ai_service.dart';
import '../../../core/ai/ai_use_case.dart';
import 'work_photo_ai_prompts.dart';

abstract interface class WorkPhotoAiAssistant {
  Future<String> textToTemplateTreeJson({
    required String text,
    required String context,
  });
}

class DefaultWorkPhotoAiAssistant implements WorkPhotoAiAssistant {
  final AiUseCaseExecutor _executor;

  DefaultWorkPhotoAiAssistant({required AiService aiService})
    : _executor = AiUseCaseExecutor(aiService: aiService);

  @override
  Future<String> textToTemplateTreeJson({
    required String text,
    required String context,
  }) {
    return _executor.run(
      spec: WorkPhotoAiPrompts.textToTemplateTreeUseCase,
      userInput: text,
      context: context,
    );
  }
}
