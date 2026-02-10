import 'package:flutter/cupertino.dart';

import '../theme/ios26_theme.dart';

class IOS26SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final IOS26IconTone iconTone;

  const IOS26SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.showChevron = true,
    this.onTap,
    this.iconTone = IOS26IconTone.accent,
  });

  @override
  Widget build(BuildContext context) {
    final iconColors = IOS26Theme.iconChipColors(iconTone);
    return IOS26Button.plain(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(IOS26Theme.spacingSm),
              decoration: BoxDecoration(
                color: iconColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: iconColors.border, width: 0.8),
              ),
              child: IOS26Icon(icon, color: iconColors.foreground, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: IOS26Theme.titleMedium)),
            if (trailing != null) ...[
              trailing!,
            ] else ...[
              if ((value ?? '').trim().isNotEmpty)
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: IOS26Theme.bodyMedium,
                  ),
                ),
              if (showChevron) ...[
                const SizedBox(width: 8),
                const IOS26Icon(
                  CupertinoIcons.chevron_right,
                  tone: IOS26IconTone.secondary,
                  size: 18,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
