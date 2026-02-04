import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/pages/stockpile_tool_page.dart';
import 'package:life_tools/tools/stockpile_assistant/repository/stockpile_repository.dart';
import 'package:life_tools/tools/stockpile_assistant/services/stockpile_service.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../test_helpers/floating_icon_button_expectations.dart';
import '../../test_helpers/test_app_wrapper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('囤货助手 AI 录入按钮应为右下角纯图标', (tester) async {
    late Database db;
    late StockpileService stockpileService;

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
    });

    addTearDown(() async {
      await tester.runAsync(() async => db.close());
    });

    await tester.pumpWidget(
      TestAppWrapper(
        child: ChangeNotifierProvider<StockpileService>.value(
          value: stockpileService,
          child: StockpileToolPage(service: stockpileService),
        ),
      ),
    );
    await tester.pump();

    expectBottomRightFloatingIconButton(
      tester,
      buttonKey: const ValueKey('stockpile_ai_input_button'),
      icon: CupertinoIcons.sparkles,
      shouldNotFindText: 'AI录入',
    );
  });
}
