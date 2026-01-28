import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/tags/built_in_tag_categories.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/stockpile_assistant/pages/stock_item_edit_page.dart';
import 'package:life_tools/tools/stockpile_assistant/repository/stockpile_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/services/stockpile_service.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  group('囤货助手 - 物品类型/位置来自标签', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    Future<
      ({
        Database db,
        TagRepository tagRepository,
        TagService tagService,
        StockpileService stockpileService,
        MessageService messageService,
      })
    >
    depsFactory(WidgetTester tester) async {
      late Database db;
      late TagRepository tagRepository;
      late TagService tagService;
      late StockpileService stockpileService;
      late MessageService messageService;

      await tester.runAsync(() async {
        db = await openDatabase(
          inMemoryDatabasePath,
          version: DatabaseSchema.version,
          onConfigure: DatabaseSchema.onConfigure,
          onCreate: DatabaseSchema.onCreate,
          onUpgrade: DatabaseSchema.onUpgrade,
        );
        tagRepository = TagRepository.withDatabase(db);
        tagService = TagService(repository: tagRepository);
        BuiltInTagCategories.registerAll(tagService);
        stockpileService = StockpileService.withRepositories(
          repository: StockpileRepository.withDatabase(db),
          tagRepository: tagRepository,
        );
        await stockpileService.loadItems();
        messageService = MessageService(
          repository: MessageRepository.withDatabase(db),
        );
        await messageService.init();
      });
      addTearDown(() async {
        await tester.runAsync(() async => db.close());
      });

      return (
        db: db,
        tagRepository: tagRepository,
        tagService: tagService,
        stockpileService: stockpileService,
        messageService: messageService,
      );
    }

    Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
      for (int i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('等待组件超时: $finder');
    }

    testWidgets('编辑页使用框选 chip 选择物品类型，并支持快速新增', (tester) async {
      final deps = await depsFactory(tester);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TagService>.value(value: deps.tagService),
            ChangeNotifierProvider<StockpileService>.value(
              value: deps.stockpileService,
            ),
            ChangeNotifierProvider<MessageService>.value(
              value: deps.messageService,
            ),
          ],
          child: const TestAppWrapper(child: StockItemEditPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('物品类型'), findsOneWidget);
      expect(find.text('物品标签'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('stock_item_pick_item_types')),
      );
      await tester.pumpAndSettle();

      // 空列表也应支持快速新增
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('stockpile-tag-quick-add-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('stockpile-tag-quick-add-button')),
      );
      await tester.pump();
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('stockpile-tag-quick-add-field')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('stockpile-tag-quick-add-field')),
        '零食',
      );
      await tester.tap(
        find.byKey(const ValueKey('stockpile-tag-quick-add-button')),
      );
      await tester.pump();

      await pumpUntilFound(tester, find.text('零食'));
      await tester.tap(find.byKey(const ValueKey('stockpile-tag-done')));
      await tester.pump();
      await pumpUntilFound(tester, find.textContaining('零食'));
    });

    testWidgets('位置改为从标签单选获取（点选后自动返回）并支持快速新增', (tester) async {
      final deps = await depsFactory(tester);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TagService>.value(value: deps.tagService),
            ChangeNotifierProvider<StockpileService>.value(
              value: deps.stockpileService,
            ),
            ChangeNotifierProvider<MessageService>.value(
              value: deps.messageService,
            ),
          ],
          child: const TestAppWrapper(child: StockItemEditPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('位置'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('stock_item_pick_location')));
      await tester.pumpAndSettle();

      // 快速新增一个位置标签，并应自动选中且返回
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('stockpile-location-quick-add-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('stockpile-location-quick-add-button')),
      );
      await tester.pump();
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('stockpile-location-quick-add-field')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('stockpile-location-quick-add-field')),
        '冰箱',
      );
      await tester.tap(
        find.byKey(const ValueKey('stockpile-location-quick-add-button')),
      );
      await tester.pump();
      await pumpUntilFound(tester, find.textContaining('冰箱'));
    });
  });
}
