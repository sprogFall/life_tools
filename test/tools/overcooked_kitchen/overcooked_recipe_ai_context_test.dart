import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/overcooked_kitchen/ai/overcooked_recipe_ai_context.dart';

void main() {
  group('buildOvercookedRecipeAiPrompt', () {
    test('会拼接菜谱生成所需上下文字段', () {
      final prompt = buildOvercookedRecipeAiPrompt(
        name: '宫保鸡丁',
        style: '川菜',
        ingredients: const ['鸡腿肉', '花生米'],
        sauces: const ['干辣椒', '花椒'],
        flavors: const ['麻辣', '下饭'],
        intro: '15分钟快手菜',
      );

      expect(prompt, contains('菜名：宫保鸡丁'));
      expect(prompt, contains('风格：川菜'));
      expect(prompt, contains('主料：鸡腿肉、花生米'));
      expect(prompt, contains('配料/调味：干辣椒、花椒'));
      expect(prompt, contains('风味关键词：麻辣、下饭'));
      expect(prompt, contains('简介：15分钟快手菜'));
    });

    test('空字段会使用默认占位，避免提示词缺失', () {
      final prompt = buildOvercookedRecipeAiPrompt(
        name: '番茄炒蛋',
        style: null,
        ingredients: const [],
        sauces: const [],
        flavors: const [],
        intro: '',
      );

      expect(prompt, contains('菜名：番茄炒蛋'));
      expect(prompt, contains('风格：未填写'));
      expect(prompt, contains('主料：未填写'));
      expect(prompt, contains('配料/调味：未填写'));
      expect(prompt, contains('风味关键词：未填写'));
      expect(prompt, contains('简介：未填写'));
    });
  });
}
