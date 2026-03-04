import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../ai/xiao_mi_prompt_resolver.dart';

/// ChatGPT风格空状态/欢迎页
class ChatEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<XiaoMiQuickPrompt> prompts;
  final ValueChanged<XiaoMiQuickPrompt> onTapPrompt;

  const ChatEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.prompts,
    required this.onTapPrompt,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          IOS26Theme.spacingLg,
          IOS26Theme.spacingXxl,
          IOS26Theme.spacingLg,
          IOS26Theme.spacingXl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // AI头像
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    IOS26Theme.primaryColor,
                    IOS26Theme.secondaryColor,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: IOS26Theme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.bubble_left_bubble_right_fill,
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: IOS26Theme.spacingLg),
            // 大标题
            Text(
              title,
              textAlign: TextAlign.center,
              style: IOS26Theme.displayMedium.copyWith(
                color: IOS26Theme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: IOS26Theme.spacingSm),
            // 副标题
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: IOS26Theme.bodyMedium.copyWith(
                color: IOS26Theme.textSecondary,
                height: 1.5,
              ),
            ),
            // 快捷提示按钮
            if (prompts.isNotEmpty) ...[
              const SizedBox(height: IOS26Theme.spacingXxl),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: IOS26Theme.spacingSm,
                runSpacing: IOS26Theme.spacingSm,
                children: prompts
                    .map(
                      (prompt) => _QuickPromptChip(
                        prompt: prompt,
                        onTap: () => onTapPrompt(prompt),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  final XiaoMiQuickPrompt prompt;
  final VoidCallback onTap;

  const _QuickPromptChip({required this.prompt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: IOS26Theme.radiusFull,
      padding: EdgeInsets.zero,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(
          horizontal: IOS26Theme.spacingMd,
          vertical: 8,
        ),
        minSize: IOS26Theme.minimumTapSize.height,
        onPressed: onTap,
        child: Text(
          prompt.text,
          style: IOS26Theme.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: IOS26Theme.textPrimary,
          ),
        ),
      ),
    );
  }
}
