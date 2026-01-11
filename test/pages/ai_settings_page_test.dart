import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/pages/home_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AI设置入口', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('设置弹窗中应显示AI配置入口', (tester) async {
      final settingsService = SettingsService();
      final aiConfigService = AiConfigService();
      await aiConfigService.init();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsService),
            ChangeNotifierProvider.value(value: aiConfigService),
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

