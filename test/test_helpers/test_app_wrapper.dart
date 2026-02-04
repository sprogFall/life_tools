import 'package:flutter/material.dart';
import 'package:life_tools/l10n/app_localizations.dart';

/// 测试用的应用包装器，包含国际化配置
class TestAppWrapper extends StatelessWidget {
  final Widget child;
  final Locale? locale;

  const TestAppWrapper({super.key, required this.child, this.locale});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale ?? const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }
}
