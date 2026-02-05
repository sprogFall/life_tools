import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:life_tools/pages/obj_store_settings_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/test_app_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ObjStoreSettingsPage 在英文环境下应展示英文文案', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final configService = ObjStoreConfigService(
      secretStore: InMemorySecretStore(),
    );
    await configService.init();

    await tester.pumpWidget(
      ChangeNotifierProvider<ObjStoreConfigService>.value(
        value: configService,
        child: const TestAppWrapper(
          locale: Locale('en', 'US'),
          child: ObjStoreSettingsPage(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Object Storage'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Qiniu'), findsOneWidget);
    expect(find.text('Data Capsule'), findsOneWidget);
  });

  testWidgets('ObjStoreSettingsPage Qiniu 配置区在英文环境下应完整国际化且 SecretKey 默认隐藏', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final configService = ObjStoreConfigService(
      secretStore: InMemorySecretStore(),
    );
    await configService.init();

    await tester.pumpWidget(
      ChangeNotifierProvider<ObjStoreConfigService>.value(
        value: configService,
        child: const TestAppWrapper(
          locale: Locale('en', 'US'),
          child: ObjStoreSettingsPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Qiniu'));
    await tester.pumpAndSettle();

    expect(find.text('Qiniu Settings'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Danger Zone'), findsOneWidget);

    final secretFieldFinder = find.byKey(const Key('obj_store_qiniu_secret'));
    expect(secretFieldFinder, findsOneWidget);
    CupertinoTextField secretField = tester.widget(secretFieldFinder);
    expect(secretField.obscureText, isTrue);

    await tester.ensureVisible(
      find.byKey(const Key('obj_store_qiniu_secret_toggle')),
    );
    await tester.tap(find.byKey(const Key('obj_store_qiniu_secret_toggle')));
    await tester.pump();
    secretField = tester.widget(secretFieldFinder);
    expect(secretField.obscureText, isFalse);
  });

  testWidgets(
    'ObjStoreSettingsPage Data Capsule 配置区在英文环境下应完整国际化且 SecretKey 默认隐藏',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final configService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await configService.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<ObjStoreConfigService>.value(
          value: configService,
          child: const TestAppWrapper(
            locale: Locale('en', 'US'),
            child: ObjStoreSettingsPage(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Data Capsule'));
      await tester.pumpAndSettle();

      expect(find.text('Data Capsule Settings'), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);
      expect(find.text('Danger Zone'), findsOneWidget);

      final secretFieldFinder = find.byKey(
        const Key('obj_store_data_capsule_secret'),
      );
      expect(secretFieldFinder, findsOneWidget);
      CupertinoTextField secretField = tester.widget(secretFieldFinder);
      expect(secretField.obscureText, isTrue);

      await tester.ensureVisible(
        find.byKey(const Key('obj_store_data_capsule_secret_toggle')),
      );
      await tester.tap(
        find.byKey(const Key('obj_store_data_capsule_secret_toggle')),
      );
      await tester.pump();
      secretField = tester.widget(secretFieldFinder);
      expect(secretField.obscureText, isFalse);
    },
  );
}
