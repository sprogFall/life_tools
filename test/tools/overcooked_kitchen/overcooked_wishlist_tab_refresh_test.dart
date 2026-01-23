import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_auth.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_client.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:life_tools/core/obj_store/storage/local_obj_store.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/tabs/overcooked_wishlist_tab.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('OvercookedWishlistTab', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    Future<
      ({
        Database db,
        OvercookedRepository repository,
        TagService tagService,
        ObjStoreService objStoreService,
      })
    >
    createDeps(WidgetTester tester) async {
      late Database db;
      late OvercookedRepository repository;
      late TagRepository tagRepository;
      late TagService tagService;
      late ObjStoreService objStoreService;

      await tester.runAsync(() async {
        db = await openDatabase(
          inMemoryDatabasePath,
          version: DatabaseSchema.version,
          onConfigure: DatabaseSchema.onConfigure,
          onCreate: DatabaseSchema.onCreate,
          onUpgrade: DatabaseSchema.onUpgrade,
        );
        repository = OvercookedRepository.withDatabase(db);
        tagRepository = TagRepository.withDatabase(db);
        tagService = TagService(repository: tagRepository);

        final configService = ObjStoreConfigService(
          secretStore: InMemorySecretStore(),
        );
        await configService.init();
        objStoreService = ObjStoreService(
          configService: configService,
          localStore: LocalObjStore(
            baseDirProvider: () async => Directory.systemTemp.createTemp(),
          ),
          qiniuClient: QiniuClient(
            authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
          ),
        );
      });

      addTearDown(() async {
        await tester.runAsync(() async => db.close());
      });

      return (
        db: db,
        repository: repository,
        tagService: tagService,
        objStoreService: objStoreService,
      );
    }

    Widget wrap({
      required OvercookedRepository repository,
      required TagService tagService,
      required ObjStoreService objStoreService,
      required Widget child,
    }) {
      return MultiProvider(
        providers: [
          Provider<OvercookedRepository>.value(value: repository),
          ChangeNotifierProvider<TagService>.value(value: tagService),
          Provider<ObjStoreService>.value(value: objStoreService),
        ],
        child: MaterialApp(home: child),
      );
    }

    Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
      for (int i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('等待组件超时: $finder');
    }

    Future<void> pumpUntilNotFound(WidgetTester tester, Finder finder) async {
      for (int i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        if (finder.evaluate().isEmpty) return;
      }
      fail('等待组件消失超时: $finder');
    }

    Future<void> pumpUntilCupertinoButtonEnabled(
      WidgetTester tester,
      Finder finder,
    ) async {
      for (int i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        final matches = finder.evaluate().toList();
        if (matches.isEmpty) continue;
        final button = tester.widget<CupertinoButton>(finder.first);
        if (button.onPressed != null) return;
      }
      fail('等待按钮可点击超时: $finder');
    }

    testWidgets('保存菜谱后，愿望单中应能立即选到新添加的菜谱', (tester) async {
      final deps = await createDeps(tester);
      final day = DateTime(2026, 1, 10, 12);
      final now = DateTime(2026, 1, 2, 10);

      await tester.runAsync(() async {
        await deps.repository.createRecipe(
          OvercookedRecipe.create(
            name: '旧菜谱',
            coverImageKey: null,
            typeTagId: null,
            ingredientTagIds: const [],
            sauceTagIds: const [],
            flavorTagIds: const [],
            intro: '',
            content: '',
            detailImageKeys: const [],
            now: now,
          ),
        );
      });

      await tester.pumpWidget(
        wrap(
          repository: deps.repository,
          tagService: deps.tagService,
          objStoreService: deps.objStoreService,
          child: OvercookedWishlistTab(
            date: day,
            onDateChanged: (_) {},
            onWishesChanged: () {},
          ),
        ),
      );

      // 等待首轮异步加载完成，避免用例结束时仍有 DB 查询在跑
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      final pickButton = find.widgetWithText(CupertinoButton, '选择菜谱');
      await pumpUntilCupertinoButtonEnabled(tester, pickButton);

      // 先打开一次选择器，确保“旧菜谱”可见
      await tester.tap(pickButton);
      await tester.pump();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await pumpUntilFound(tester, find.text('选择愿望单菜谱'));
      expect(find.text('旧菜谱'), findsOneWidget);

      // 点击遮罩关闭（避免不同窗口尺寸下标题栏按钮不可点击）
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await pumpUntilNotFound(tester, find.text('选择愿望单菜谱'));

      await tester.runAsync(() async {
        await deps.repository.createRecipe(
          OvercookedRecipe.create(
            name: '新菜谱',
            coverImageKey: null,
            typeTagId: null,
            ingredientTagIds: const [],
            sauceTagIds: const [],
            flavorTagIds: const [],
            intro: '',
            content: '',
            detailImageKeys: const [],
            now: now,
          ),
        );
      });

      await pumpUntilCupertinoButtonEnabled(tester, pickButton);
      await tester.tap(pickButton);
      await tester.pump();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await pumpUntilFound(tester, find.text('选择愿望单菜谱'));

      expect(find.text('新菜谱'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await pumpUntilNotFound(tester, find.text('选择愿望单菜谱'));
    });
  });
}
