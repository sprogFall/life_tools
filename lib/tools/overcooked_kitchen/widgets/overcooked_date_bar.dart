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
    final ghostButton = IOS26Theme.buttonColors(IOS26ButtonVariant.ghost);
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
                color: ghostButton.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(text, style: IOS26Theme.titleSmall),
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
        child: IOS26Button(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          variant: IOS26ButtonVariant.ghost,
          borderRadius: BorderRadius.circular(14),
          child: IOS26ButtonIcon(icon, size: 18),
        ),
      ),
    );
  }
}
