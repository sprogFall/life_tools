import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/ai/stockpile_ai_intent.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stockpile_drafts.dart';
import 'package:life_tools/tools/stockpile_assistant/pages/stockpile_ai_batch_entry_page.dart';
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

  testWidgets('AI 批量录入页：可增加/删除物品条目', (tester) async {
    late Database db;
    await tester.runAsync(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
    });
    addTearDown(() async {
      await tester.runAsync(() async => db.close());
    });

    final service = StockpileService.withRepositories(
      repository: StockpileRepository.withDatabase(db),
      tagRepository: TagRepository.withDatabase(db),
    );

    await tester.pumpWidget(
      TestAppWrapper(
        child: ChangeNotifierProvider<StockpileService>.value(
          value: service,
          child: StockpileAiBatchEntryPage(
            initialItems: [
              StockItemDraft(
                name: '牛奶',
                location: '',
                totalQuantity: 1,
                remainingQuantity: 1,
                unit: '',
                purchaseDate: DateTime(2026, 1, 1),
                expiryDate: null,
                remindDays: 3,
                note: '',
              ),
            ],
            initialConsumptions: const <StockpileAiConsumptionEntry>[],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('stockpile_ai_batch_item_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stockpile_ai_batch_add_item')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('stockpile_ai_batch_add_item')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('stockpile_ai_batch_item_1')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('stockpile_ai_batch_item_0_delete')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('stockpile_ai_batch_item_0_delete')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stockpile_ai_batch_item_0')),
      findsNothing,
    );
  });

  testWidgets('AI 批量录入页：无物品时默认进入消耗页', (tester) async {
    late Database db;
    await tester.runAsync(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
    });
    addTearDown(() async {
      await tester.runAsync(() async => db.close());
    });

    final service = StockpileService.withRepositories(
      repository: StockpileRepository.withDatabase(db),
      tagRepository: TagRepository.withDatabase(db),
    );

    await tester.pumpWidget(
      TestAppWrapper(
        child: ChangeNotifierProvider<StockpileService>.value(
          value: service,
          child: StockpileAiBatchEntryPage(
            initialItems: const [],
            initialConsumptions: [
              StockpileAiConsumptionEntry(
                itemRef: const StockpileAiItemRef(name: '牛奶'),
                draft: StockConsumptionDraft(
                  quantity: 1,
                  method: '',
                  consumedAt: DateTime(2026, 1, 2, 9),
                  note: '',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    expect(
      find.byKey(const ValueKey('stockpile_ai_batch_add_consumption')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stockpile_ai_batch_add_item')),
      findsNothing,
    );
  });
}
