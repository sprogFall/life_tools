import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/ios26_theme.dart';

class WorkLogVoiceInputSheet extends StatefulWidget {
  const WorkLogVoiceInputSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WorkLogVoiceInputSheet(),
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
        const Expanded(
          child: Text(
            'AI录入',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
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
          const Text(
            '输入内容（告诉AI你想记录什么）',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: IOS26Theme.surfaceColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: CupertinoTextField(
              key: const ValueKey('work_log_ai_text_field'),
              controller: _controller,
              maxLines: 4,
              placeholder: '例如：今天完成了登录模块的开发，花了3小时…',
              autofocus: true,
              decoration: null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            onPressed: _confirm,
            color: IOS26Theme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            borderRadius: BorderRadius.circular(14),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.sparkles, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  '提交给AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        CupertinoButton(
          onPressed: () {
            setState(() {
              _controller.clear();
            });
          },
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          child: const Icon(
            CupertinoIcons.trash,
            size: 20,
            color: IOS26Theme.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        CupertinoButton(
          onPressed: () => Navigator.pop(context),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: IOS26Theme.textTertiary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          child: const Icon(
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
