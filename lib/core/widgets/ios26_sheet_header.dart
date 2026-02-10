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
    final cancelColor = IOS26Theme.iconColor(IOS26IconTone.secondary);
    final doneColor = IOS26Theme.iconColor(IOS26IconTone.accent);
    return SizedBox(
      height: 54,
      child: NavigationToolbar(
        centerMiddle: true,
        leading: IOS26Button.plain(
          padding: const EdgeInsets.symmetric(horizontal: IOS26Theme.spacingSm),
          minimumSize: IOS26Theme.minimumTapSize,
          foregroundColor: cancelColor,
          onPressed: onCancel ?? () => Navigator.pop(context),
          child: Text(cancelText, style: IOS26Theme.labelLarge),
        ),
        middle: Text(
          title,
          textAlign: TextAlign.center,
          style: IOS26Theme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IOS26Button.plain(
          key: doneKey,
          padding: const EdgeInsets.symmetric(horizontal: IOS26Theme.spacingSm),
          minimumSize: IOS26Theme.minimumTapSize,
          foregroundColor: doneColor,
          onPressed: onDone,
          child: Text(doneText, style: IOS26Theme.labelLarge),
        ),
      ),
    );
  }
}
