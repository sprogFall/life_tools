import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_flavor.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:life_tools/tools/overcooked_kitchen/services/overcooked_gacha_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('OvercookedGachaService', () {
    late Database db;
    late OvercookedRepository repository;
    late TagRepository tagRepository;

    setUpAll(() {
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
      repository = OvercookedRepository.withDatabase(db);
      tagRepository = TagRepository.withDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('按类型随机抽取：每个类型最多一份且必须匹配类型', () async {
      final typeA = await tagRepository.createTag(
        name: '主菜',
        toolIds: const ['overcooked_kitchen'],
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final typeB = await tagRepository.createTag(
        name: '汤',
        toolIds: const ['overcooked_kitchen'],
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );

      final now = DateTime(2026, 1, 2, 10);
      await repository.createRecipe(
        OvercookedRecipe.create(
          name: '红烧肉',
          coverImageKey: null,
          typeTagId: typeA,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          intro: '',
          flavors: const {OvercookedFlavor.salty},
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );
      await repository.createRecipe(
        OvercookedRecipe.create(
          name: '糖醋里脊',
          coverImageKey: null,
          typeTagId: typeA,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          intro: '',
          flavors: const {OvercookedFlavor.sweet, OvercookedFlavor.sour},
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );
      await repository.createRecipe(
        OvercookedRecipe.create(
          name: '紫菜蛋花汤',
          coverImageKey: null,
          typeTagId: typeB,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          intro: '',
          flavors: const {OvercookedFlavor.salty},
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );

      final service = OvercookedGachaService(repository: repository);
      final picked = await service.pick(
        typeTagIds: [typeA, typeB],
        seed: 42,
      );

      expect(picked.length, 2);
      expect(picked.where((e) => e.typeTagId == typeA).length, 1);
      expect(picked.where((e) => e.typeTagId == typeB).length, 1);
    });

    test('某类型没有可抽取菜谱时，会跳过该类型', () async {
      final typeA = await tagRepository.createTag(
        name: '主菜',
        toolIds: const ['overcooked_kitchen'],
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final typeB = await tagRepository.createTag(
        name: '甜品',
        toolIds: const ['overcooked_kitchen'],
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );

      final now = DateTime(2026, 1, 2, 10);
      await repository.createRecipe(
        OvercookedRecipe.create(
          name: '红烧肉',
          coverImageKey: null,
          typeTagId: typeA,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          intro: '',
          flavors: const {OvercookedFlavor.salty},
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );

      final service = OvercookedGachaService(repository: repository);
      final picked = await service.pick(typeTagIds: [typeA, typeB], seed: 1);
      expect(picked.length, 1);
      expect(picked.single.typeTagId, typeA);
    });
  });
}

