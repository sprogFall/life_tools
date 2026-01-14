import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// 测试用的应用包装器，包含国际化配置
class TestAppWrapper extends StatelessWidget {
  final Widget child;
  final Locale? locale;

  const TestAppWrapper({super.key, required this.child, this.locale});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale ?? const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      home: child,
    );
  }
}
