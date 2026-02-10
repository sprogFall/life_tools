import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/ios26_theme.dart';

class WorkLogVoiceInputSheet extends StatefulWidget {
  final String title;
  final String helperText;
  final String placeholder;
  final Key textFieldKey;

  const WorkLogVoiceInputSheet({
    super.key,
    this.title = 'AI录入',
    this.helperText = '告诉AI你想记录什么吧',
    this.placeholder = '例如：今天完成了登录模块的开发，花了3小时…',
    this.textFieldKey = const ValueKey('work_log_ai_text_field'),
  });

  static Future<String?> show(
    BuildContext context, {
    String title = 'AI录入',
    String helperText = '告诉AI你想记录什么吧',
    String placeholder = '例如：今天完成了登录模块的开发，花了3小时…',
    Key textFieldKey = const ValueKey('work_log_ai_text_field'),
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WorkLogVoiceInputSheet(
        title: title,
        helperText: helperText,
        placeholder: placeholder,
        textFieldKey: textFieldKey,
      ),
    );
  }

  @override
  State<WorkLogVoiceInputSheet> createState() => _WorkLogVoiceInputSheetState();
}

class _WorkLogVoiceInputSheetState extends State<WorkLogVoiceInputSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: IOS26Theme.surfaceColor,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  _buildInputCard(),
                  const SizedBox(height: 12),
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.title,
            style: IOS26Theme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildInputCard() {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.helperText,
            style: IOS26Theme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          CupertinoTextField(
            key: widget.textFieldKey,
            controller: _controller,
            maxLines: 4,
            placeholder: widget.placeholder,
            autofocus: true,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: IOS26Theme.textFieldDecoration(),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: IOS26Button(
            onPressed: _confirm,
            variant: IOS26ButtonVariant.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            borderRadius: BorderRadius.circular(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const IOS26ButtonIcon(CupertinoIcons.sparkles, size: 18),
                const SizedBox(width: 8),
                IOS26ButtonLabel('提交给AI', style: IOS26Theme.labelLarge),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        IOS26Button(
          onPressed: () {
            setState(() {
              _controller.clear();
            });
          },
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          variant: IOS26ButtonVariant.ghost,
          borderRadius: BorderRadius.circular(14),
          child: const IOS26ButtonIcon(CupertinoIcons.trash, size: 20),
        ),
        const SizedBox(width: 10),
        IOS26Button(
          onPressed: () => Navigator.pop(context),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          variant: IOS26ButtonVariant.ghost,
          borderRadius: BorderRadius.circular(14),
          child: IOS26Icon(
            CupertinoIcons.xmark,
            size: 20,
            color: IOS26Theme.textSecondary,
          ),
        ),
      ],
    );
  }

  void _confirm() {
    final text = _controller.text.trim();
    Navigator.pop(context, text.isEmpty ? null : text);
  }
}
