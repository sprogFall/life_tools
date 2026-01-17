import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/pages/stock_item_edit_page.dart';
import 'package:life_tools/tools/stockpile_assistant/repository/stockpile_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/services/stockpile_service.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  group('StockItemEditPage', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    testWidgets('新增临期物品后应立即写入首页提醒消息', (tester) async {
      late Database db;
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
        stockpileService = StockpileService.withRepositories(
          repository: StockpileRepository.withDatabase(db),
          tagRepository: TagRepository.withDatabase(db),
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

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MessageService>.value(value: messageService),
            ChangeNotifierProvider<StockpileService>.value(value: stockpileService),
          ],
          child: const TestAppWrapper(child: _Host()),
        ),
      );
      await tester.pumpAndSettle();

      expect(messageService.messages, isEmpty);

      await tester.tap(find.byKey(const ValueKey('open_edit')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('stock_item_name')),
        '牛奶',
      );

      // 开启保质期/提醒，并把提醒天数设置为 10（默认到期日=今天+7，会被判定为“临期”）
      await tester.scrollUntilVisible(
        find.text('保质期/提醒'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      final expirySwitch = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch),
      );
      expirySwitch.onChanged?.call(true);
      await tester.pump();
      expect(find.text('到期日期'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stock_item_remind_days')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('stock_item_remind_days')),
        '10',
      );

      final saveButton = tester.widget<CupertinoButton>(
        find.widgetWithText(CupertinoButton, '保存'),
      );
      saveButton.onPressed?.call();
      await tester.pump();

      for (var i = 0; i < 80; i++) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 30));
        if (messageService.messages.isNotEmpty && stockpileService.items.isNotEmpty) {
          break;
        }
      }

      expect(stockpileService.items.length, 1);
      expect(stockpileService.items.single.expiryDate, isNotNull);
      expect(stockpileService.items.single.remindDays, 10);

      expect(messageService.messages.length, 1);
      expect(messageService.messages.single.toolId, 'stockpile_assistant');
      expect(messageService.messages.single.isRead, isFalse);
      expect(messageService.messages.single.body, contains('牛奶'));
    });
  });
}

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CupertinoButton(
          key: const ValueKey('open_edit'),
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute<void>(builder: (_) => const StockItemEditPage()),
            );
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}
