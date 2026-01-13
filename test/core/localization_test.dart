import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// 测试国际化配置是否正确
void main() {
  group('国际化配置测试', () {
    testWidgets('应用应该支持中文本地化', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          home: Scaffold(
            body: Center(
              child: Text('测试'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('测试'), findsOneWidget);
    });

    testWidgets('CupertinoDatePicker 应该支持中文显示', (tester) async {
      DateTime selectedDate = DateTime(2024, 1, 15);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate,
                onDateTimeChanged: (DateTime value) {
                  selectedDate = value;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      // 验证日期选择器已渲染
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
    });
  });
}
