import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/pages/home_page.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('HomePage 工具卡片', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    testWidgets('右上角扩散装饰应被圆角裁剪', (WidgetTester tester) async {
      ToolRegistry.instance.registerAll();
      final settingsService = SettingsService();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsService>.value(
          value: settingsService,
          child: const MaterialApp(home: HomePage()),
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
