import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/pages/stock_item_edit_page.dart';
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

  testWidgets('新增物品页：输入框应显示外置字段标题（非仅占位符）', (tester) async {
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
          child: const StockItemEditPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('名称'), findsOneWidget);
    expect(find.text('位置'), findsOneWidget);
    expect(find.text('数量'), findsOneWidget);
    expect(find.text('采购日期'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('备注'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('备注'), findsOneWidget);
  });
}
