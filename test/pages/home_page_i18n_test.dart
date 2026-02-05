import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/pages/home_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test_helpers/test_app_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('HomePage 在英文环境下应展示英文文案', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ToolRegistry.instance.registerAll();

    final settingsService = SettingsService();

    late Database db;
    late MessageService messageService;
    await tester.runAsync(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
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
          ChangeNotifierProvider<SettingsService>.value(value: settingsService),
          ChangeNotifierProvider<MessageService>.value(value: messageService),
        ],
        child: const TestAppWrapper(
          locale: Locale('en', 'US'),
          child: HomePage(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Honey'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('All messages'), findsOneWidget);
    expect(find.text('No new messages right now.'), findsOneWidget);
    expect(find.text('My Tools'), findsOneWidget);
    expect(find.text('Work Log'), findsOneWidget);
    expect(find.text('Daily work tracking'), findsOneWidget);
  });
}
