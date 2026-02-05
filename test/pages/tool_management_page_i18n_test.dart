import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/pages/tool_management_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/test_app_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ToolManagementPage 在英文环境下应展示英文文案', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final settingsService = SettingsService(
      databaseProvider: () async => throw 0,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: settingsService,
        child: const TestAppWrapper(
          locale: Locale('en', 'US'),
          child: ToolManagementPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tool Management'), findsOneWidget);
    expect(find.text('Default on Launch'), findsOneWidget);
    expect(find.text('Show on Home'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
