import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/widgets/ios26_markdown.dart';

/// ChatGPT风格思考过程折叠面板
class ChatThinkingPanel extends StatefulWidget {
  final String thinking;

  const ChatThinkingPanel({super.key, required this.thinking});

  @override
  State<ChatThinkingPanel> createState() => _ChatThinkingPanelState();
}

class _ChatThinkingPanelState extends State<ChatThinkingPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _rotationController;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotationAnimation = Tween(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _rotationController.forward();
      } else {
        _rotationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 头部
        GestureDetector(
          onTap: _toggleExpanded,
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: IOS26Theme.spacingXs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 灯泡图标（渐变色）
                Container(
                  width: 18,
                  height: 18,
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
                  ),
                  child: const Icon(
                    CupertinoIcons.lightbulb_fill,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: IOS26Theme.spacingXs),
                Text(
                  '思考过程',
                  style: IOS26Theme.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: IOS26Theme.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationAnimation.value * 3.14159,
                      child: Icon(
                        CupertinoIcons.chevron_down,
                        size: 12,
                        color: IOS26Theme.textTertiary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // 内容区（带动画）
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(top: IOS26Theme.spacingXs),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: IOS26Theme.secondaryColor.withValues(alpha: 0.6),
                  width: 2.5,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              IOS26Theme.spacingSm,
              0,
              0,
              IOS26Theme.spacingXs,
            ),
            child: IOS26MarkdownBody(data: widget.thinking),
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}
