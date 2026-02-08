import '../../../core/ai/ai_use_case.dart';
import '../../../core/ai/ai_service.dart';
import 'overcooked_recipe_ai_context.dart';
import 'overcooked_recipe_ai_prompts.dart';

abstract interface class OvercookedRecipeAiAssistant {
  Future<String> generateRecipeMarkdown({
    required String name,
    String? style,
    required List<String> ingredients,
    required List<String> sauces,
    required List<String> flavors,
    required String intro,
  });
}

class DefaultOvercookedRecipeAiAssistant
    implements OvercookedRecipeAiAssistant {
  final AiUseCaseExecutor _executor;

  DefaultOvercookedRecipeAiAssistant({required AiService aiService})
    : _executor = AiUseCaseExecutor(aiService: aiService);

  @override
  Future<String> generateRecipeMarkdown({
    required String name,
    String? style,
    required List<String> ingredients,
    required List<String> sauces,
    required List<String> flavors,
    required String intro,
  }) {
    final prompt = buildOvercookedRecipeAiPrompt(
      name: name,
      style: style,
      ingredients: ingredients,
      sauces: sauces,
      flavors: flavors,
      intro: intro,
    );
    return _executor.run(
      spec: OvercookedRecipeAiPrompts.recipeGenerateUseCase,
      userInput: prompt,
    );
  }
}
