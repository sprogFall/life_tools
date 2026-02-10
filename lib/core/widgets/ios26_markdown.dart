import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../theme/ios26_theme.dart';

MarkdownStyleSheet ios26MarkdownStyleSheet({
  Color? accentColor,
  Color? codeColor,
  Color? quoteColor,
  Color? linkColor,
}) {
  final resolvedAccent = accentColor ?? IOS26Theme.secondaryColor;
  final resolvedCode = codeColor ?? IOS26Theme.toolBlue;
  final resolvedQuote = quoteColor ?? resolvedAccent;
  final resolvedLink = linkColor ?? IOS26Theme.primaryColor;

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
      color: resolvedCode,
      fontWeight: FontWeight.w600,
    ),
    blockquote: IOS26Theme.bodyMedium.copyWith(
      height: 1.45,
      color: IOS26Theme.textSecondary,
    ),
    listBullet: IOS26Theme.bodyMedium.copyWith(color: IOS26Theme.textSecondary),
    blockquoteDecoration: BoxDecoration(
      color: resolvedQuote.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
      border: Border(
        left: BorderSide(color: resolvedQuote.withValues(alpha: 0.4), width: 3),
      ),
    ),
    codeblockDecoration: BoxDecoration(
      color: resolvedCode.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
      border: Border.all(color: resolvedCode.withValues(alpha: 0.2), width: 1),
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
      color: resolvedLink,
      decoration: TextDecoration.underline,
    ),
  );
}

class IOS26MarkdownBody extends StatelessWidget {
  final String data;
  final bool selectable;
  final md.ExtensionSet? extensionSet;
  final MarkdownStyleSheet? styleSheet;

  const IOS26MarkdownBody({
    super.key,
    required this.data,
    this.selectable = true,
    this.extensionSet,
    this.styleSheet,
  });

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: selectable,
      extensionSet: extensionSet ?? md.ExtensionSet.gitHubFlavored,
      styleSheet: styleSheet ?? ios26MarkdownStyleSheet(),
    );
  }
}

class IOS26MarkdownView extends StatelessWidget {
  final String data;
  final bool selectable;
  final md.ExtensionSet? extensionSet;
  final MarkdownStyleSheet? styleSheet;
  final EdgeInsets padding;

  const IOS26MarkdownView({
    super.key,
    required this.data,
    this.selectable = true,
    this.extensionSet,
    this.styleSheet,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: data,
      selectable: selectable,
      extensionSet: extensionSet ?? md.ExtensionSet.gitHubFlavored,
      styleSheet: styleSheet ?? ios26MarkdownStyleSheet(),
      padding: padding,
    );
  }
}
