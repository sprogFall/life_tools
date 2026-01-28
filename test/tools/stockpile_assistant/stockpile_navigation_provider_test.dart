import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/built_in_tag_categories.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/stockpile_assistant/pages/stockpile_tool_page.dart';
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

  testWidgets('囤货助手：点击右上角 + 可进入新增页且不抛 Provider 异常', (tester) async {
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

    final tagRepository = TagRepository.withDatabase(db);
    final tagService = TagService(repository: tagRepository);
    BuiltInTagCategories.registerAll(tagService);
    final service = StockpileService.withRepositories(
      repository: StockpileRepository.withDatabase(db),
      tagRepository: tagRepository,
    );

    await tester.pumpWidget(
      TestAppWrapper(
        child: ChangeNotifierProvider<TagService>.value(
          value: tagService,
          child: StockpileToolPage(service: service),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pump();
    await _pumpUntil(tester, () => find.text('新增物品').evaluate().isNotEmpty);

    expect(tester.takeException(), isNull);
    expect(find.text('新增物品'), findsOneWidget);
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  int maxPumps = 60,
  Duration step = const Duration(milliseconds: 16),
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (predicate()) return;
    await tester.pump(step);
  }
  fail('等待条件超时');
}
