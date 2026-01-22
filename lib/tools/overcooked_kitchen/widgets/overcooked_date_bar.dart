import 'package:flutter/cupertino.dart';

import '../../../core/theme/ios26_theme.dart';
import '../utils/overcooked_utils.dart';

class OvercookedDateBar extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final String? title;

  const OvercookedDateBar({
    super.key,
    required this.date,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final text = title == null
        ? OvercookedFormat.date(date)
        : '$title · ${OvercookedFormat.date(date)}';
    return Row(
      children: [
        _iconButton(
          icon: CupertinoIcons.chevron_left,
          onPressed: onPrev,
          label: '前一天',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: onPick,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _iconButton(
          icon: CupertinoIcons.chevron_right,
          onPressed: onNext,
          label: '后一天',
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 44,
        width: 44,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          child: Icon(icon, size: 18, color: IOS26Theme.textPrimary),
        ),
      ),
    );
  }
}
