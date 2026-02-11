import 'ai_call_source.dart';
import 'ai_models.dart';
import 'ai_service.dart';

class AiUseCaseSpec {
  final String id;
  final String systemPrompt;
  final String inputLabel;
  final double? temperature;
  final int? maxOutputTokens;
  final AiResponseFormat responseFormat;
  final Duration timeout;
  final AiCallSource source;

  const AiUseCaseSpec({
    required this.id,
    required this.systemPrompt,
    this.inputLabel = '用户输入',
    this.temperature,
    this.maxOutputTokens,
    this.responseFormat = AiResponseFormat.text,
    this.timeout = const Duration(seconds: 60),
    this.source = AiCallSource.unknown,
  });
}

class AiPromptComposer {
  static String compose({
    required String inputLabel,
    required String userInput,
    String? context,
  }) {
    final normalizedLabel = inputLabel.trim().isEmpty
        ? '用户输入'
        : inputLabel.trim();
    final normalizedInput = userInput.trim();
    final normalizedContext = context?.trim() ?? '';
    if (normalizedContext.isEmpty) {
      return '$normalizedLabel：\n$normalizedInput';
    }
    return '$normalizedContext\n\n$normalizedLabel：\n$normalizedInput';
  }
}

class AiUseCaseExecutor {
  final AiService _aiService;

  const AiUseCaseExecutor({required AiService aiService})
    : _aiService = aiService;

  Future<String> run({
    required AiUseCaseSpec spec,
    required String userInput,
    String? context,
  }) {
    final prompt = AiPromptComposer.compose(
      context: context,
      inputLabel: spec.inputLabel,
      userInput: userInput,
    );
    return runWithPrompt(spec: spec, prompt: prompt);
  }

  Future<String> runWithPrompt({
    required AiUseCaseSpec spec,
    required String prompt,
  }) {
    return _aiService.chatText(
      prompt: prompt,
      systemPrompt: spec.systemPrompt,
      responseFormat: spec.responseFormat,
      temperature: spec.temperature,
      maxOutputTokens: spec.maxOutputTokens,
      timeout: spec.timeout,
      source: spec.source,
    );
  }
}
