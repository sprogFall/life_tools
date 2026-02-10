import 'package:flutter/cupertino.dart';

import '../theme/ios26_theme.dart';

/// iOS26 风格的“下拉选择”表单项（用于从列表/标签选择一个或多个值）。
class IOS26SelectField extends StatelessWidget {
  final Key? buttonKey;
  final String text;
  final bool isPlaceholder;
  final VoidCallback? onPressed;

  const IOS26SelectField({
    super.key,
    required this.text,
    required this.isPlaceholder,
    required this.onPressed,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = IOS26Theme.buttonColors(IOS26ButtonVariant.secondary);
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(IOS26Theme.radiusFormField),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: IOS26Button.plain(
          key: buttonKey,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          borderRadius: BorderRadius.circular(IOS26Theme.radiusFormField),
          foregroundColor: colors.foreground,
          onPressed: onPressed,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IOS26Theme.titleSmall.copyWith(
                    color: isPlaceholder
                        ? IOS26Theme.textSecondary
                        : colors.foreground,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_down,
                size: 16,
                color: IOS26Theme.iconColor(IOS26IconTone.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
