import '../../../core/ai/ai_use_case.dart';

class OvercookedRecipeAiPrompts {
  OvercookedRecipeAiPrompts._();

  static const String recipeGenerateSystemPrompt = '''
你是一位资深中餐家常菜厨师与教学写作者。
请基于用户提供的菜谱信息，生成可落地执行的制作方案。

硬性要求：
1) 只输出 Markdown 正文，不要输出额外解释、前后缀、代码块围栏。
2) 内容需适合家庭厨房，步骤清晰，火候与时长尽量量化。
3) 若用户给出的食材不完整，可补充常见基础配料并在文中说明“可选”。
4) 结构至少包含：
   - 二级标题“食材与用量”
   - 二级标题“制作步骤”
   - 二级标题“关键技巧与注意事项”
   - 二级标题“时间与口味调整建议”
''';

  static const AiUseCaseSpec recipeGenerateUseCase = AiUseCaseSpec(
    id: 'overcooked_recipe_generate_markdown',
    systemPrompt: recipeGenerateSystemPrompt,
    inputLabel: '菜谱信息',
    temperature: 0.6,
    maxOutputTokens: 1200,
    timeout: Duration(seconds: 90),
  );
}
