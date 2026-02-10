import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('核心页面 CupertinoButton 顶层 color 参数必须走语义按钮 token', () async {
    const targetFiles = <String>{
      'lib/core/backup/pages/backup_restore_page.dart',
      'lib/core/messages/pages/message_detail_page.dart',
      'lib/core/sync/pages/sync_settings_page.dart',
      'lib/pages/ai_settings_page.dart',
      'lib/pages/obj_store_settings_page.dart',
    };

    final violations = <String>[];

    for (final path in targetFiles) {
      final content = await File(path).readAsString();
      final colorExpressions = _findCupertinoButtonTopLevelColorArgs(content);
      for (final expression in colorExpressions) {
        final usesDirectThemeColor = expression.contains('IOS26Theme.');
        final usesSemanticToken = expression.contains('buttonColors(');
        if (usesDirectThemeColor && !usesSemanticToken) {
          violations.add('$path -> $expression');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下 CupertinoButton 的顶层 color 仍直接使用 IOS26Theme 颜色，请改为 IOS26Theme.buttonColors(...) 语义 token：\n${violations.join('\n')}',
    );
  });
}

List<String> _findCupertinoButtonTopLevelColorArgs(String source) {
  const marker = 'CupertinoButton(';
  final result = <String>[];
  var searchStart = 0;

  while (true) {
    final callStart = source.indexOf(marker, searchStart);
    if (callStart < 0) break;

    final openParenIndex = callStart + marker.length - 1;
    final closeParenIndex = _findMatchingParen(source, openParenIndex);
    if (closeParenIndex < 0) break;

    final args = source.substring(openParenIndex + 1, closeParenIndex);
    final topLevelArgs = _splitTopLevelArguments(args);

    for (final argument in topLevelArgs) {
      final trimmed = argument.trim();
      if (!trimmed.startsWith('color:')) continue;
      result.add(trimmed.substring('color:'.length).trim());
    }

    searchStart = closeParenIndex + 1;
  }

  return result;
}

int _findMatchingParen(String text, int openParenIndex) {
  var depth = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaped = false;

  for (var i = openParenIndex; i < text.length; i++) {
    final ch = text[i];

    if (inSingleQuote) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\\') {
        escaped = true;
      } else if (ch == "'") {
        inSingleQuote = false;
      }
      continue;
    }

    if (inDoubleQuote) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\\') {
        escaped = true;
      } else if (ch == '"') {
        inDoubleQuote = false;
      }
      continue;
    }

    if (ch == "'") {
      inSingleQuote = true;
      continue;
    }
    if (ch == '"') {
      inDoubleQuote = true;
      continue;
    }

    if (ch == '(') {
      depth++;
      continue;
    }

    if (ch == ')') {
      depth--;
      if (depth == 0) {
        return i;
      }
    }
  }

  return -1;
}

List<String> _splitTopLevelArguments(String args) {
  final segments = <String>[];
  var start = 0;

  var parenDepth = 0;
  var bracketDepth = 0;
  var braceDepth = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaped = false;

  for (var i = 0; i < args.length; i++) {
    final ch = args[i];

    if (inSingleQuote) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\\') {
        escaped = true;
      } else if (ch == "'") {
        inSingleQuote = false;
      }
      continue;
    }

    if (inDoubleQuote) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\\') {
        escaped = true;
      } else if (ch == '"') {
        inDoubleQuote = false;
      }
      continue;
    }

    if (ch == "'") {
      inSingleQuote = true;
      continue;
    }
    if (ch == '"') {
      inDoubleQuote = true;
      continue;
    }

    switch (ch) {
      case '(':
        parenDepth++;
      case ')':
        parenDepth--;
      case '[':
        bracketDepth++;
      case ']':
        bracketDepth--;
      case '{':
        braceDepth++;
      case '}':
        braceDepth--;
      case ',':
        final isTopLevel =
            parenDepth == 0 && bracketDepth == 0 && braceDepth == 0;
        if (isTopLevel) {
          segments.add(args.substring(start, i));
          start = i + 1;
        }
    }
  }

  if (start < args.length) {
    segments.add(args.substring(start));
  }

  return segments;
}
