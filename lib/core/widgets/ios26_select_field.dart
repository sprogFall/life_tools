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
    return SizedBox(
      height: 48,
      child: CupertinoButton(
        key: buttonKey,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
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
                      : IOS26Theme.textPrimary,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_down,
              size: 16,
              color: IOS26Theme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
