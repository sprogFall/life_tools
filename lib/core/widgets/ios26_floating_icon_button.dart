import 'package:flutter/cupertino.dart';

import '../theme/ios26_theme.dart';

/// iOS 26 风格：右下角悬浮纯图标按钮（毛玻璃 + 安全区适配）。
///
/// 注意：该组件内部使用 [Positioned]，需要放在 [Stack] 下使用。
class IOS26FloatingIconButton extends StatelessWidget {
  final Key? buttonKey;
  final IconData icon;
  final VoidCallback onPressed;
  final String? semanticLabel;

  final double right;
  final double bottom;
  final double iconSize;
  final Color? iconColor;

  const IOS26FloatingIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.buttonKey,
    this.semanticLabel,
    this.right = 16,
    this.bottom = 16,
    this.iconSize = 20,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: right,
      bottom: bottom,
      child: SafeArea(
        top: false,
        left: false,
        child: GlassContainer(
          borderRadius: 999,
          padding: const EdgeInsets.all(6),
          child: CupertinoButton(
            key: buttonKey,
            padding: EdgeInsets.zero,
            minimumSize: IOS26Theme.minimumTapSize,
            onPressed: onPressed,
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor ?? IOS26Theme.primaryColor,
              semanticLabel: semanticLabel,
            ),
          ),
        ),
      ),
    );
  }
}
