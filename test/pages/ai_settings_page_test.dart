import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:life_tools/core/sync/services/sync_service.dart';
import 'package:life_tools/pages/home_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('AI设置入口', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      ToolRegistry.instance.registerAll();
    });

    testWidgets('设置弹窗中应显示AI配置入口', (tester) async {
      final settingsService = SettingsService();
      final aiConfigService = AiConfigService();
      await aiConfigService.init();

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();
      final syncService = SyncService(configService: syncConfigService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsService),
            ChangeNotifierProvider.value(value: aiConfigService),
            ChangeNotifierProvider.value(value: syncConfigService),
            ChangeNotifierProvider.value(value: syncService),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await tester.tap(find.byIcon(CupertinoIcons.gear));
      await tester.pumpAndSettle();

      expect(find.text('AI配置'), findsOneWidget);
    });
  });
}

