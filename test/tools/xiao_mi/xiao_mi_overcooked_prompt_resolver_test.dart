import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_prompt_resolver.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers/fake_work_log_repository.dart';

void main() {
  group('XiaoMiPromptResolver overcooked special_call', () {
    late Database db;
    late OvercookedRepository overcookedRepository;
    late XiaoMiPromptResolver resolver;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      overcookedRepository = OvercookedRepository.withDatabase(db);
      resolver = XiaoMiPromptResolver(
        workLogRepository: FakeWorkLogRepository(),
        overcookedRepository: overcookedRepository,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('overcooked_context_query 菜谱命中时应注入菜谱信息', () async {
      final recipeId = await overcookedRepository.createRecipe(
        OvercookedRecipe.create(
          name: '宫保鸡丁',
          coverImageKey: null,
          typeTagId: null,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '下饭菜',
          content: '步骤1：滑油。步骤2：爆香。',
          detailImageKeys: const [],
          now: DateTime(2026, 3, 5, 10),
        ),
      );
      expect(recipeId, greaterThan(0));

      final resolved = await resolver.resolveSpecialCall(
        callId: 'overcooked_context_query',
        displayText: '宫保鸡丁怎么做',
        arguments: const <String, Object?>{
          'query_type': 'recipe_lookup',
          'recipe_name': '宫保鸡丁',
        },
      );

      expect((resolved.metadata ?? const {})['triggerSource'], 'pre_route');
      expect(resolved.aiPrompt, contains('胡闹厨房菜谱查询结果'));
      expect(resolved.aiPrompt, contains('命中菜谱数：1'));
      expect(resolved.aiPrompt, contains('菜名：宫保鸡丁'));
      expect(resolved.aiPrompt, contains('简介：下饭菜'));
      expect(resolved.aiPrompt, contains('菜谱正文：步骤1：滑油。步骤2：爆香。'));
    });

    test('overcooked_context_query 菜谱未命中时应回退为用户原始提问', () async {
      final resolved = await resolver.resolveSpecialCall(
        callId: 'overcooked_context_query',
        displayText: '鱼香肉丝怎么做',
        arguments: const <String, Object?>{
          'query_type': 'recipe_lookup',
          'recipe_name': '鱼香肉丝',
        },
      );

      expect((resolved.metadata ?? const {})['triggerSource'], 'pre_route');
      expect(resolved.aiPrompt, '鱼香肉丝怎么做');
      expect(resolved.aiPrompt, isNot(contains('胡闹厨房菜谱查询结果')));
    });

    test('overcooked_context_query 按日期查询时应注入当天做菜记录', () async {
      final recipeA = await overcookedRepository.createRecipe(
        OvercookedRecipe.create(
          name: '番茄炒蛋',
          coverImageKey: null,
          typeTagId: null,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '',
          content: '步骤略',
          detailImageKeys: const [],
          now: DateTime(2026, 3, 5, 10),
        ),
      );
      final recipeB = await overcookedRepository.createRecipe(
        OvercookedRecipe.create(
          name: '可乐鸡翅',
          coverImageKey: null,
          typeTagId: null,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '',
          content: '步骤略',
          detailImageKeys: const [],
          now: DateTime(2026, 3, 5, 10),
        ),
      );
      await overcookedRepository.replaceMeal(
        date: DateTime(2026, 3, 5),
        recipeIds: [recipeA, recipeB, recipeA],
        now: DateTime(2026, 3, 5, 11),
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'overcooked_context_query',
        displayText: '2026-03-05 做了什么菜',
        arguments: const <String, Object?>{
          'query_type': 'cooked_on_date',
          'date': '20260305',
        },
      );

      expect((resolved.metadata ?? const {})['triggerSource'], 'pre_route');
      expect((resolved.metadata ?? const {})['queryDate'], '2026-03-05');
      expect(resolved.aiPrompt, contains('胡闹厨房做菜记录查询结果'));
      expect(resolved.aiPrompt, contains('查询日期：2026-03-05'));
      expect(resolved.aiPrompt, contains('番茄炒蛋'));
      expect(resolved.aiPrompt, contains('可乐鸡翅'));
    });
  });
}
