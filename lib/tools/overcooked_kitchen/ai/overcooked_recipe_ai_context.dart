String buildOvercookedRecipeAiPrompt({
  required String name,
  String? style,
  required List<String> ingredients,
  required List<String> sauces,
  required List<String> flavors,
  required String intro,
}) {
  final normalizedName = name.trim();
  final normalizedStyle = style?.trim();
  final normalizedIntro = intro.trim();

  final ingredientText = _joinOrFallback(ingredients);
  final sauceText = _joinOrFallback(sauces);
  final flavorText = _joinOrFallback(flavors);

  return '''
请根据以下信息生成菜谱制作方案：
- 菜名：${normalizedName.isEmpty ? '未填写' : normalizedName}
- 风格：${(normalizedStyle == null || normalizedStyle.isEmpty) ? '未填写' : normalizedStyle}
- 主料：$ingredientText
- 配料/调味：$sauceText
- 风味关键词：$flavorText
- 简介：${normalizedIntro.isEmpty ? '未填写' : normalizedIntro}

输出要求：
- 使用简洁、可执行的 Markdown。
- 步骤按顺序编号。
- 若存在可替换食材或可选调味，请明确标注“可选”。
''';
}

String _joinOrFallback(List<String> values) {
  final normalized = values
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (normalized.isEmpty) {
    return '未填写';
  }
  return normalized.join('、');
}
