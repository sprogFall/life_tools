import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/pages/ai_settings_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/test_app_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AiSettingsPage 在英文环境下应展示英文文案', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final configService = AiConfigService();
    await configService.init();

    await tester.pumpWidget(
      ChangeNotifierProvider<AiConfigService>.value(
        value: configService,
        child: const TestAppWrapper(
          locale: Locale('en', 'US'),
          child: AiSettingsPage(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('AI Settings'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('OpenAI-Compatible Settings'), findsOneWidget);
    expect(find.text('Test Connection'), findsOneWidget);
  });
}
