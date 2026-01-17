import 'package:flutter/cupertino.dart';

class StockpileFormat {
  static String date(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String dateTime(DateTime d) {
    final date = StockpileFormat.date(d);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }

  static String num(double v) {
    final i = v.toInt();
    if (i.toDouble() == v) return '$i';
    return v
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class StockpileDialogs {
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
}
