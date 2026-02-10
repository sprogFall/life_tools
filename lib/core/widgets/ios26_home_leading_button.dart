import 'package:flutter/cupertino.dart';

import '../../l10n/app_localizations.dart';
import '../theme/ios26_theme.dart';

class IOS26HomeLeadingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const IOS26HomeLeadingButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return IOS26Button.plain(
      padding: const EdgeInsets.all(IOS26Theme.spacingSm),
      minimumSize: IOS26Theme.minimumTapSize,
      foregroundColor: IOS26Theme.iconColor(IOS26IconTone.accent),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.home, size: 20),
          const SizedBox(width: IOS26Theme.spacingXs),
          Text(l10n.common_home, style: IOS26Theme.labelLarge),
        ],
      ),
    );
  }
}
