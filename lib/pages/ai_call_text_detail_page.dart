import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/ios26_theme.dart';
import '../core/ui/app_scaffold.dart';
import '../core/widgets/ios26_markdown.dart';

class AiCallTextDetailPage extends StatefulWidget {
  final String title;
  final String content;

  const AiCallTextDetailPage({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  State<AiCallTextDetailPage> createState() => _AiCallTextDetailPageState();
}

class _AiCallTextDetailPageState extends State<AiCallTextDetailPage> {
  bool _useMarkdown = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Column(
        children: [
          IOS26AppBar(title: widget.title, showBackButton: true),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(IOS26Theme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: IOS26Theme.spacingLg,
                      vertical: IOS26Theme.spacingMd,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Markdown 预览',
                            style: IOS26Theme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoSwitch(
                          key: const ValueKey('ai_history_markdown_switch'),
                          value: _useMarkdown,
                          onChanged: (value) {
                            setState(() => _useMarkdown = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: IOS26Theme.spacingMd),
                  GlassContainer(
                    padding: const EdgeInsets.all(IOS26Theme.spacingLg),
                    child: _useMarkdown
                        ? IOS26MarkdownBody(
                            key: const ValueKey('ai_history_markdown_view'),
                            data: widget.content,
                          )
                        : SelectableText(
                            widget.content,
                            key: const ValueKey('ai_history_plain_text_view'),
                            style: IOS26Theme.bodyMedium.copyWith(height: 1.5),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
