import 'package:flutter/cupertino.dart';
import 'package:life_tools/l10n/app_localizations.dart';
import '../theme/ios26_theme.dart';

/// 统一弹窗管理器
class AppDialogs {
  AppDialogs._();

  /// 显示简单提示弹窗
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String content,
    String? buttonText,
  }) {
    final l10n = AppLocalizations.of(context);
    final resolvedButtonText = buttonText ?? l10n?.common_confirm ?? '知道了';
    return showCupertinoDialog<void>(
      context: context,
      builder:
          (ctx) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(resolvedButtonText),
              ),
            ],
          ),
    );
  }

  /// 显示确认弹窗
  static Future<bool> showConfirm(
    BuildContext context, {
    required String title,
    required String content,
    String? cancelText,
    String? confirmText,
    bool isDestructive = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final resolvedCancelText = cancelText ?? l10n?.common_cancel ?? '取消';
    final resolvedConfirmText = confirmText ?? l10n?.common_confirm ?? '确定';
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder:
          (ctx) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(resolvedCancelText),
              ),
              CupertinoDialogAction(
                isDestructiveAction: isDestructive,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(resolvedConfirmText),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  /// 显示输入弹窗
  static Future<String?> showInput(
    BuildContext context, {
    required String title,
    String? content,
    String? placeholder,
    String? defaultValue,
    String? cancelText,
    String? confirmText,
  }) async {
    final l10n = AppLocalizations.of(context);
    final resolvedCancelText = cancelText ?? l10n?.common_cancel ?? '取消';
    final resolvedConfirmText = confirmText ?? l10n?.common_confirm ?? '确定';
    final controller = TextEditingController(text: defaultValue);
    return showCupertinoDialog<String>(
      context: context,
      builder:
          (ctx) => CupertinoAlertDialog(
            title: Text(title),
            content: Column(
              children: [
                if (content != null) ...[
                  Text(content),
                  const SizedBox(height: 12),
                ],
                CupertinoTextField(
                  controller: controller,
                  placeholder: placeholder,
                  autofocus: true,
                  style: IOS26Theme.bodyLarge,
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(resolvedCancelText),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: Text(resolvedConfirmText),
              ),
            ],
          ),
    );
  }

  /// 显示底部菜单
  static Future<T?> showActionSheet<T>(
    BuildContext context, {
    String? title,
    String? message,
    required List<Widget> actions,
    Widget? cancelButton,
  }) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder:
          (ctx) => CupertinoActionSheet(
            title: title != null ? Text(title) : null,
            message: message != null ? Text(message) : null,
            actions: actions,
            cancelButton: cancelButton,
          ),
    );
  }

  /// 显示加载中弹窗
  /// 返回一个用于关闭弹窗的回调函数
  static void showLoading(BuildContext context, {String? title}) {
    final l10n = AppLocalizations.of(context);
    final resolvedTitle = title ?? l10n?.common_loading ?? '加载中...';
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => CupertinoAlertDialog(
            title: Text(resolvedTitle),
            content: const Padding(
              padding: EdgeInsets.only(top: 12),
              child: CupertinoActivityIndicator(),
            ),
          ),
    );
  }
}
