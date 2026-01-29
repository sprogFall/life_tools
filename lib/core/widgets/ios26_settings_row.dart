import 'package:flutter/cupertino.dart';
import '../theme/ios26_theme.dart';

class IOS26SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const IOS26SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: IOS26Theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: IOS26Theme.primaryColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
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
                    style: const TextStyle(
                      fontSize: 16,
                      color: IOS26Theme.textSecondary,
                    ),
                  ),
                ),
              if (showChevron) ...[
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: IOS26Theme.textTertiary,
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
