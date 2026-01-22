import 'package:flutter/cupertino.dart';

class OvercookedFormat {
  static String date(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String yearMonth(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    return '$y-$m';
  }
}

class OvercookedDialogs {
  static Future<void> showMessage(
    BuildContext context, {
    required String title,
    required String content,
  }) async {
    await showCupertinoDialog<void>(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(content),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确认',
    String cancelText = '取消',
    bool isDestructive = false,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(content),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelText),
              ),
              CupertinoDialogAction(
                isDestructiveAction: isDestructive,
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmText),
              ),
            ],
          ),
    );
    return result ?? false;
  }
}

