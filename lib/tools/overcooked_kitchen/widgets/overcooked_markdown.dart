import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/theme/ios26_theme.dart';

MarkdownStyleSheet overcookedMarkdownStyleSheet() {
  return MarkdownStyleSheet(
    p: IOS26Theme.bodyMedium.copyWith(
      height: 1.5,
      color: IOS26Theme.textPrimary,
    ),
    h1: IOS26Theme.headlineMedium.copyWith(
      height: 1.28,
      color: IOS26Theme.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    h2: IOS26Theme.titleLarge.copyWith(
      height: 1.3,
      color: IOS26Theme.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    h3: IOS26Theme.titleMedium.copyWith(
      height: 1.32,
      color: IOS26Theme.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    em: IOS26Theme.bodyMedium.copyWith(
      fontStyle: FontStyle.italic,
      color: IOS26Theme.textPrimary,
    ),
    strong: IOS26Theme.bodyMedium.copyWith(
      fontWeight: FontWeight.w700,
      color: IOS26Theme.textPrimary,
    ),
    code: IOS26Theme.bodySmall.copyWith(
      color: IOS26Theme.toolBlue,
      fontWeight: FontWeight.w600,
    ),
    blockquote: IOS26Theme.bodyMedium.copyWith(
      height: 1.45,
      color: IOS26Theme.textSecondary,
    ),
    listBullet: IOS26Theme.bodyMedium.copyWith(color: IOS26Theme.textSecondary),
    blockquoteDecoration: BoxDecoration(
      color: IOS26Theme.toolPurple.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
      border: Border(
        left: BorderSide(
          color: IOS26Theme.toolPurple.withValues(alpha: 0.4),
          width: 3,
        ),
      ),
    ),
    codeblockDecoration: BoxDecoration(
      color: IOS26Theme.toolBlue.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
      border: Border.all(
        color: IOS26Theme.toolBlue.withValues(alpha: 0.2),
        width: 1,
      ),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: IOS26Theme.textTertiary.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
    ),
    a: IOS26Theme.bodyMedium.copyWith(
      color: IOS26Theme.primaryColor,
      decoration: TextDecoration.underline,
    ),
  );
}

class OvercookedMarkdownBody extends StatelessWidget {
  final String data;

  const OvercookedMarkdownBody({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: overcookedMarkdownStyleSheet(),
    );
  }
}

class OvercookedMarkdownView extends StatelessWidget {
  final String data;

  const OvercookedMarkdownView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: data,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: overcookedMarkdownStyleSheet(),
      padding: EdgeInsets.zero,
    );
  }
}
