import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/pages/home_page.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test_helpers/test_app_wrapper.dart';

void main() {
  group('HomePage 工具卡片', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    testWidgets('右上角扩散装饰应被圆角裁剪', (WidgetTester tester) async {
      final settingsService = SettingsService();
      late Database db;
      late MessageService messageService;

      await tester.runAsync(() async {
        ToolRegistry.instance.registerAll();
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
            ChangeNotifierProvider<SettingsService>.value(
              value: settingsService,
            ),
            ChangeNotifierProvider<MessageService>.value(value: messageService),
          ],
          child: const TestAppWrapper(child: HomePage()),
        ),
      );

      final clipFinder = find.byKey(
        const ValueKey('ios26_tool_card_clip_work_log'),
      );
      expect(clipFinder, findsOneWidget);

      final clip = tester.widget<ClipRRect>(clipFinder);
      expect(clip.borderRadius, BorderRadius.circular(24));
    });
  });
}
