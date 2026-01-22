import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stock_item.dart';
import 'package:life_tools/tools/stockpile_assistant/pages/stock_consumption_edit_page.dart';
import 'package:life_tools/tools/stockpile_assistant/repository/stockpile_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/services/stockpile_service.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('StockConsumptionEditPage 应展示“消耗数量”字段标题', (tester) async {
    late Database db;
    late StockpileService stockpileService;
    late MessageService messageService;
    late int itemId;

    await tester.runAsync(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      stockpileService = StockpileService.withRepositories(
        repository: StockpileRepository.withDatabase(db),
        tagRepository: TagRepository.withDatabase(db),
      );
      messageService = MessageService(
        repository: MessageRepository.withDatabase(db),
      );
      await messageService.init();

      itemId = await stockpileService.createItem(
        StockItem.create(
          name: '牛奶',
          location: '',
          unit: '盒',
          totalQuantity: 2,
          remainingQuantity: 2,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: null,
          remindDays: -1,
          restockRemindDate: null,
          restockRemindQuantity: null,
          note: '',
          now: DateTime(2026, 1, 1),
        ),
      );
      await stockpileService.loadItems();
    });

    addTearDown(() async {
      await tester.runAsync(() async => db.close());
    });

    await tester.pumpWidget(
      TestAppWrapper(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<MessageService>.value(value: messageService),
            ChangeNotifierProvider<StockpileService>.value(
              value: stockpileService,
            ),
          ],
          child: StockConsumptionEditPage(itemId: itemId),
        ),
      ),
    );

    await tester.pump();
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 30));
      if (find.text('消耗数量').evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.text('消耗数量'), findsOneWidget);
    expect(find.byKey(const ValueKey('stock_consumption_qty')), findsOneWidget);
  });
}
