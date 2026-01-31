import 'package:flutter/cupertino.dart';

import '../theme/ios26_theme.dart';

/// iOS 26 风格 BottomSheet 标题栏（真正居中）。
///
/// 使用 `NavigationToolbar(centerMiddle: true)` 避免 `Row + Expanded` 在左右宽度不一致时标题偏移。
class IOS26SheetHeader extends StatelessWidget {
  final String title;
  final String cancelText;
  final String doneText;
  final VoidCallback? onCancel;
  final VoidCallback? onDone;
  final Key? doneKey;

  const IOS26SheetHeader({
    super.key,
    required this.title,
    this.cancelText = '取消',
    this.doneText = '完成',
    this.onCancel,
    this.onDone,
    this.doneKey,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: NavigationToolbar(
        centerMiddle: true,
        leading: CupertinoButton(
          onPressed: onCancel ?? () => Navigator.pop(context),
          child: Text(cancelText),
        ),
        middle: Text(
          title,
          textAlign: TextAlign.center,
          style: IOS26Theme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: CupertinoButton(
          key: doneKey,
          onPressed: onDone,
          child: Text(doneText),
        ),
      ),
    );
  }
}
