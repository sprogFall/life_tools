import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stock_item.dart';
import 'package:life_tools/tools/stockpile_assistant/pages/stock_item_detail_page.dart';
import 'package:life_tools/tools/stockpile_assistant/repository/stockpile_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/services/stockpile_reminder_service.dart';
import 'package:life_tools/tools/stockpile_assistant/services/stockpile_service.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('StockItemDetailPage', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    testWidgets('删除物品应同步删除对应提醒消息', (tester) async {
      late Database db;
      late int itemId;
      late MessageService messageService;
      late StockpileService stockpileService;

      await tester.runAsync(() async {
        db = await openDatabase(
          inMemoryDatabasePath,
          version: DatabaseSchema.version,
          onConfigure: DatabaseSchema.onConfigure,
          onCreate: DatabaseSchema.onCreate,
          onUpgrade: DatabaseSchema.onUpgrade,
        );

        final stockpileRepo = StockpileRepository.withDatabase(db);
        itemId = await stockpileRepo.createItem(
          StockItem.create(
            name: '牛奶',
            location: '冰箱',
            unit: '盒',
            totalQuantity: 1,
            remainingQuantity: 1,
            purchaseDate: DateTime(2026, 1, 1),
            expiryDate: DateTime(2026, 1, 2),
            remindDays: 3,
            note: '',
            now: DateTime(2026, 1, 1, 9),
          ),
        );

        messageService = MessageService(
          repository: MessageRepository.withDatabase(db),
        );
        await messageService.init();
        await messageService.upsertMessage(
          toolId: 'stockpile_assistant',
          title: '囤货助手',
          body: '测试提醒',
          dedupeKey: StockpileReminderService.dedupeKeyForItem(itemId: itemId),
          createdAt: DateTime(2026, 1, 1, 9),
        );

        stockpileService = StockpileService.withRepositories(
          repository: stockpileRepo,
          tagRepository: TagRepository.withDatabase(db),
        );
        await stockpileService.loadItems();
      });
      addTearDown(() async {
        await tester.runAsync(() async => db.close());
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MessageService>.value(value: messageService),
            ChangeNotifierProvider<StockpileService>.value(value: stockpileService),
          ],
          child: MaterialApp(
            home: _Host(itemId: itemId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(messageService.messages.length, 1);

      await tester.tap(find.byKey(const ValueKey('open_detail')));
      await tester.pump();
      for (int i = 0; i < 60; i++) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 30));
        if (find.byType(CupertinoActivityIndicator).evaluate().isEmpty) {
          break;
        }
      }
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      final deleteButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, CupertinoIcons.delete),
      );
      deleteButton.onPressed!.call();
      await tester.pump();
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        if (find.byType(CupertinoDialogAction).evaluate().isNotEmpty) break;
      }

      final actions = find.byType(CupertinoDialogAction);
      expect(actions, findsNWidgets(2));
      await tester.tap(actions.at(1));
      await tester.pump();
      for (int i = 0; i < 120; i++) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 30));
        if (messageService.messages.isEmpty) break;
      }

      expect(messageService.messages, isEmpty);
    });
  });
}

class _Host extends StatelessWidget {
  final int itemId;

  const _Host({required this.itemId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CupertinoButton(
          key: const ValueKey('open_detail'),
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => StockItemDetailPage(itemId: itemId),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}
