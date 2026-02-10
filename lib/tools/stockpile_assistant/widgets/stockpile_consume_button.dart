import 'package:flutter/cupertino.dart';

import '../../../core/theme/ios26_theme.dart';
import '../models/stock_item.dart';

bool canShowConsumeButton(StockItem item) => item.remainingQuantity > 0;

class StockpileConsumeButton extends StatelessWidget {
  final VoidCallback onPressed;

  const StockpileConsumeButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IOS26Button(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      variant: IOS26ButtonVariant.warning,
      borderRadius: BorderRadius.circular(14),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IOS26ButtonIcon(CupertinoIcons.minus_circle_fill, size: 18),
          const SizedBox(width: 6),
          IOS26ButtonLabel('消耗', style: IOS26Theme.labelLarge),
        ],
      ),
    );
  }
}
