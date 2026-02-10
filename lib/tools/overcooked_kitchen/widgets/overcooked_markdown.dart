import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/widgets/ios26_markdown.dart';

MarkdownStyleSheet overcookedMarkdownStyleSheet() {
  return ios26MarkdownStyleSheet(
    accentColor: IOS26Theme.toolPurple,
    codeColor: IOS26Theme.toolBlue,
    quoteColor: IOS26Theme.toolPurple,
    linkColor: IOS26Theme.primaryColor,
  );
}

class OvercookedMarkdownBody extends StatelessWidget {
  final String data;

  const OvercookedMarkdownBody({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return IOS26MarkdownBody(
      data: data,
      styleSheet: overcookedMarkdownStyleSheet(),
    );
  }
}

class OvercookedMarkdownView extends StatelessWidget {
  final String data;

  const OvercookedMarkdownView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return IOS26MarkdownView(
      data: data,
      styleSheet: overcookedMarkdownStyleSheet(),
    );
  }
}
