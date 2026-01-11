import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/ios26_theme.dart';
import '../../../../core/voice/speech_input_service.dart';

class WorkLogVoiceInputSheet extends StatefulWidget {
  final SpeechInputService speechInputService;

  const WorkLogVoiceInputSheet({super.key, required this.speechInputService});

  static Future<String?> show(
    BuildContext context, {
    required SpeechInputService speechInputService,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WorkLogVoiceInputSheet(
        speechInputService: speechInputService,
      ),
    );
  }

  @override
  State<WorkLogVoiceInputSheet> createState() => _WorkLogVoiceInputSheetState();
}

class _WorkLogVoiceInputSheetState extends State<WorkLogVoiceInputSheet> {
  final _controller = TextEditingController();
  bool _listening = false;
  String? _error;

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
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 13,
                        color: IOS26Theme.toolRed.withValues(alpha: 0.95),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
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
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          onPressed: _listening ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        const Expanded(
          child: Text(
            '语音输入',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: IOS26Theme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          onPressed: _listening ? null : _confirm,
          child: const Text('确认'),
        ),
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
            '识别文本（可编辑）',
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
              key: const ValueKey('work_log_voice_text_field'),
              controller: _controller,
              maxLines: 4,
              placeholder: '点击下方按钮开始说话…',
              enabled: !_listening,
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
            onPressed: _listening ? null : _startListening,
            color: IOS26Theme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_listening ? '识别中…' : '开始说话'),
          ),
        ),
        const SizedBox(width: 10),
        CupertinoButton(
          onPressed: _listening
              ? null
              : () {
                  setState(() {
                    _controller.clear();
                    _error = null;
                  });
                },
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: const Text('清空'),
        ),
      ],
    );
  }

  Future<void> _startListening() async {
    setState(() {
      _listening = true;
      _error = null;
    });

    try {
      final text = await widget.speechInputService.listenOnce(
        onPartial: (partial) {
          if (!mounted) return;
          _controller.text = partial;
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        },
      );

      if (!mounted) return;
      if (text == null || text.trim().isEmpty) {
        setState(() {
          _error = '未识别到有效内容（或当前平台不支持），请重试或直接手动输入';
        });
      } else {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
      }
    } on SpeechInputNotSupportedException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '语音识别失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() => _listening = false);
      }
    }
  }

  void _confirm() {
    final text = _controller.text.trim();
    Navigator.pop(context, text.isEmpty ? null : text);
  }
}
