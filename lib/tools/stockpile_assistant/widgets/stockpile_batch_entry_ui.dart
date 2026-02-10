import 'package:flutter/cupertino.dart';

import '../../../core/theme/ios26_theme.dart';

Future<bool> showStockpileConfirmDeleteDialog(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (_) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: IOS26Theme.spacingSm),
        child: Text(content),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showStockpileDatePicker({
  required BuildContext context,
  required DateTime initial,
  required ValueChanged<DateTime> onSelected,
}) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) {
      var temp = DateTime(initial.year, initial.month, initial.day);
      return Container(
        height: 300,
        color: IOS26Theme.surfaceColor,
        child: Column(
          children: [
            SizedBox(
              height: IOS26Theme.minimumTapSize.height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      onSelected(temp);
                      Navigator.pop(context);
                    },
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: temp,
                onDateTimeChanged: (value) => temp = value,
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showStockpileDateTimePicker({
  required BuildContext context,
  required DateTime initial,
  required ValueChanged<DateTime> onSelected,
}) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) {
      var temp = initial;
      return Container(
        height: 320,
        color: IOS26Theme.surfaceColor,
        child: Column(
          children: [
            SizedBox(
              height: IOS26Theme.minimumTapSize.height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      onSelected(temp);
                      Navigator.pop(context);
                    },
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: temp,
                onDateTimeChanged: (value) => temp = value,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class StockpileBatchEntryCompactField extends StatelessWidget {
  final String title;
  final Widget child;

  const StockpileBatchEntryCompactField({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: IOS26Theme.bodySmall),
        const SizedBox(height: IOS26Theme.spacingSm),
        child,
      ],
    );
  }
}

class StockpileBatchEntryInlineField extends StatelessWidget {
  final String title;
  final Widget child;

  const StockpileBatchEntryInlineField({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: IOS26Theme.spacingMd,
        vertical: IOS26Theme.spacingSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IOS26Theme.bodySmall,
            ),
          ),
          const SizedBox(width: IOS26Theme.spacingMd),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class StockpileBatchEntryTwoColRow extends StatelessWidget {
  final Widget left;
  final Widget right;

  const StockpileBatchEntryTwoColRow({
    super.key,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - IOS26Theme.spacingMd) / 2;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: w, child: left),
            const SizedBox(width: IOS26Theme.spacingMd),
            SizedBox(width: w, child: right),
          ],
        );
      },
    );
  }
}

class StockpileBatchEntryPickerRow extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap;

  const StockpileBatchEntryPickerRow({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: IOS26Theme.spacingMd,
        vertical: IOS26Theme.spacingSm,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: IOS26Theme.bodySmall.copyWith(
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
            Text(value, style: IOS26Theme.bodySmall),
            const SizedBox(width: IOS26Theme.spacingSm),
            IOS26Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: IOS26Theme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class StockpileBatchEntryAddRow extends StatelessWidget {
  final Key buttonKey;
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const StockpileBatchEntryAddRow({
    super.key,
    required this.buttonKey,
    required this.text,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: IOS26Theme.spacingMd,
        vertical: IOS26Theme.spacingMd,
      ),
      child: CupertinoButton(
        key: buttonKey,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Row(
          children: [
            IOS26Icon(icon, size: 20, color: color),
            const SizedBox(width: IOS26Theme.spacingMd),
            Expanded(child: Text(text, style: IOS26Theme.titleSmall)),
            const IOS26Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              tone: IOS26IconTone.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class StockpileBatchEntryTextField extends StatelessWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;

  const StockpileBatchEntryTextField({
    super.key,
    required this.fieldKey,
    required this.controller,
    required this.placeholder,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceColor.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(IOS26Theme.radiusLg),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: IOS26Theme.spacingMd,
        vertical: IOS26Theme.spacingXs,
      ),
      child: CupertinoTextField(
        key: fieldKey,
        controller: controller,
        placeholder: placeholder,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        padding: const EdgeInsets.symmetric(
          horizontal: IOS26Theme.spacingSm,
          vertical: IOS26Theme.spacingSm,
        ),
        decoration: null,
      ),
    );
  }
}
