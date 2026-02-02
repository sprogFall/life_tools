import 'package:flutter/material.dart';
import '../theme/ios26_theme.dart';

/// 统一的小节标题组件
class SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.only(left: 4, bottom: 8, top: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: IOS26Theme.titleSmall.copyWith(
          color: IOS26Theme.textSecondary,
        ),
      ),
    );
  }
}
