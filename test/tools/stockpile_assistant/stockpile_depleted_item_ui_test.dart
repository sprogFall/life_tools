import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stock_item.dart';
import 'package:life_tools/tools/stockpile_assistant/pages/stockpile_tool_page.dart';
import 'package:life_tools/tools/stockpile_assistant/repository/stockpile_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/services/stockpile_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('已耗尽列表不展示临期/到期信息', (tester) async {
    late Database db;
    late StockpileRepository repo;
    late StockpileService service;

    await tester.runAsync(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      repo = StockpileRepository.withDatabase(db);
      await repo.createItem(
        StockItem.create(
          name: '牛奶',
          location: '冰箱',
          unit: '盒',
          totalQuantity: 2,
          remainingQuantity: 0,
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 1, 2),
          remindDays: 3,
          restockRemindDate: null,
          restockRemindQuantity: null,
          note: '',
          now: DateTime(2026, 1, 1, 9),
        ),
      );
      service = StockpileService.withRepositories(
        repository: repo,
        tagRepository: TagRepository.withDatabase(db),
      );
      await service.loadItems();
    });
    addTearDown(() async {
      await tester.runAsync(() async => db.close());
    });

    await tester.pumpWidget(
      TestAppWrapper(child: StockpileToolPage(service: service)),
    );
    await tester.pump();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(CupertinoSlidingSegmentedControl<int>), findsNothing);

    await tester.tap(find.text('已耗尽'));
    await tester.pump();
    await _pumpUntil(tester, () => find.text('牛奶').evaluate().isNotEmpty);

    expect(find.text('牛奶'), findsOneWidget);
    expect(find.textContaining('到期：'), findsNothing);
    expect(find.text('临期'), findsNothing);
    expect(find.text('已过期'), findsNothing);
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  int maxPumps = 80,
  Duration step = const Duration(milliseconds: 16),
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (predicate()) return;
    await tester.runAsync(() async => Future<void>.delayed(step));
    await tester.pump(step);
  }
  fail('等待条件超时');
}
