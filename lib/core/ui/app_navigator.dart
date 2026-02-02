import 'package:flutter/cupertino.dart';

/// 统一导航管理器
class AppNavigator {
  AppNavigator._();

  /// 推入新页面
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      CupertinoPageRoute<T>(builder: (_) => page),
    );
  }

  /// 替换当前页面
  static Future<T?> pushReplacement<T>(BuildContext context, Widget page) {
    return Navigator.of(context).pushReplacement<T, void>(
      CupertinoPageRoute<T>(builder: (_) => page),
    );
  }

  /// 推入新页面并移除直到...
  static Future<T?> pushAndRemoveUntil<T>(
    BuildContext context,
    Widget page,
    bool Function(Route<dynamic>) predicate,
  ) {
    return Navigator.of(context).pushAndRemoveUntil<T>(
      CupertinoPageRoute<T>(builder: (_) => page),
      predicate,
    );
  }

  /// 返回上一页
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop<T>(result);
  }

  /// 回到根页面
  static void popToRoot(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
