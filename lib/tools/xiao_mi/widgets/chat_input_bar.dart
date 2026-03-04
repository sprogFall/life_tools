import 'package:flutter/cupertino.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../l10n/app_localizations.dart';

/// ChatGPT风格底部输入栏
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _focusAnimationController;
  late final Animation<double> _focusAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _focusAnimation = CurvedAnimation(
      parent: _focusAnimationController,
      curve: Curves.easeInOut,
    );
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    _focusAnimationController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final hasFocus = widget.focusNode.hasFocus;
    if (hasFocus != _isFocused) {
      setState(() => _isFocused = hasFocus);
      if (hasFocus) {
        _focusAnimationController.forward();
      } else {
        _focusAnimationController.reverse();
      }
    }
  }

  void _handleSend() {
    final text = widget.controller.text.trim();
    if (text.isEmpty || widget.sending) return;
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: _focusAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _focusAnimation.value),
          child: child,
        );
      },
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                IOS26Theme.backgroundColor.withValues(alpha: 0),
                IOS26Theme.backgroundColor.withValues(alpha: 0.92),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: IOS26Theme.glassBorderColor.withValues(alpha: 0.35),
                width: 0.5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              IOS26Theme.spacingLg,
              IOS26Theme.spacingSm,
              IOS26Theme.spacingLg,
              IOS26Theme.spacingMd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 输入框
                Expanded(
                  child: _InputField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    placeholder: l10n.xiao_mi_input_placeholder,
                    enabled: !widget.sending,
                  ),
                ),
                const SizedBox(width: IOS26Theme.spacingSm),
                // 发送按钮
                _SendButton(sending: widget.sending, onPressed: _handleSend),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final bool enabled;

  const _InputField({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: IOS26Theme.radiusXxl,
      padding: EdgeInsets.zero,
      color: IOS26Theme.surfaceColor.withValues(
        alpha: IOS26Theme.isDarkMode ? 0.6 : 0.8,
      ),
      border: Border.all(
        color: IOS26Theme.glassBorderColor.withValues(alpha: 0.5),
        width: 0.5,
      ),
      child: CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        maxLines: 5,
        minLines: 1,
        padding: const EdgeInsets.symmetric(
          horizontal: IOS26Theme.spacingMd,
          vertical: IOS26Theme.spacingSm + 2,
        ),
        decoration: const BoxDecoration(),
        style: IOS26Theme.bodyLarge,
        placeholderStyle: IOS26Theme.bodyLarge.copyWith(
          color: IOS26Theme.textTertiary,
        ),
        enabled: enabled,
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool sending;
  final VoidCallback onPressed;

  const _SendButton({required this.sending, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sending ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: sending
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [IOS26Theme.primaryColor, IOS26Theme.secondaryColor],
                ),
          color: sending
              ? IOS26Theme.surfaceColor.withValues(alpha: 0.5)
              : null,
        ),
        child: Center(
          child: sending
              ? CupertinoActivityIndicator(
                  radius: 10,
                  color: IOS26Theme.textSecondary,
                )
              : const IOS26Icon(
                  CupertinoIcons.arrow_up,
                  size: 18,
                  tone: IOS26IconTone.onAccent,
                ),
        ),
      ),
    );
  }
}
