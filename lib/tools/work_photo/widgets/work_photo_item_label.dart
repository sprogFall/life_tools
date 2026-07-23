import 'package:flutter/cupertino.dart';

import '../../../core/theme/ios26_theme.dart';
import '../models/work_photo_project_item.dart';

/// 拍摄界面中统一展示层级路径和拍摄项名称。
///
/// 层级只占辅助行，拍摄项名称使用独立行并通过 [FittedBox] 优先保持完整。
class WorkPhotoItemLabel extends StatelessWidget {
  final WorkPhotoProjectItem item;
  final TextStyle? itemTextStyle;
  final TextStyle? hierarchyTextStyle;
  final Color? itemColor;
  final TextAlign textAlign;
  final CrossAxisAlignment crossAxisAlignment;

  const WorkPhotoItemLabel({
    super.key,
    required this.item,
    this.itemTextStyle,
    this.hierarchyTextStyle,
    this.itemColor,
    this.textAlign = TextAlign.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  String get semanticLabel => [
    ...item.hierarchyPathSnapshot,
    item.nameSnapshot,
  ].where((value) => value.trim().isNotEmpty).join(' / ');

  @override
  Widget build(BuildContext context) {
    final hierarchy = item.hierarchyPathSnapshot
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final nameStyle = (itemTextStyle ?? IOS26Theme.titleSmall).copyWith(
      color: itemColor,
    );
    final pathStyle = hierarchyTextStyle ?? IOS26Theme.bodySmall;
    // 居中场景（拍摄页 AppBar）不要 width: infinity 撑满 middle 槽：
    // 否则 NavigationToolbar / 不对称左右控件会让「槽内居中」偏离屏幕中线。
    // 用 maxWidth 约束保证长文案仍可 ellipsis / scaleDown。
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : double.infinity;
          final nameAlignment = textAlign == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: crossAxisAlignment,
            children: [
              if (hierarchy.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        for (
                          var index = 0;
                          index < hierarchy.length;
                          index++
                        ) ...[
                          if (index > 0)
                            TextSpan(
                              text: ' / ',
                              style: pathStyle.copyWith(
                                color: IOS26Theme.textTertiary,
                              ),
                            ),
                          TextSpan(
                            text: hierarchy[index],
                            style: pathStyle.copyWith(
                              color: _hierarchyColor(index),
                            ),
                          ),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: textAlign,
                    softWrap: false,
                  ),
                ),
              if (hierarchy.isNotEmpty)
                const SizedBox(height: IOS26Theme.spacingXs),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: FittedBox(
                  alignment: nameAlignment,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.nameSnapshot,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: textAlign,
                    style: nameStyle,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Color _hierarchyColor(int index) {
  return switch (index % 5) {
    0 => IOS26Theme.toolPurple,
    1 => IOS26Theme.toolOrange,
    2 => IOS26Theme.toolGreen,
    3 => IOS26Theme.toolPink,
    _ => IOS26Theme.toolBlue,
  };
}
