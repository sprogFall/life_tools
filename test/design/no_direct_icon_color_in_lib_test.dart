import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('业务层不应直接使用 Icon(color: ...)，应改用 IOS26Icon / IOS26ButtonIcon', () async {
    const allowedFiles = <String>{
      'lib/core/theme/ios26_theme.dart',
      'lib\\core\\theme\\ios26_theme.dart',
    };

    final violations = <String>[];
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      if (allowedFiles.contains(file.path)) continue;

      final content = await file.readAsString();
      final colorExpressions = _findIconTopLevelColorArgs(content);
      for (final expression in colorExpressions) {
        violations.add('${file.path} -> $expression');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下文件仍直接使用 Icon(color: ...)，请改为 IOS26Icon / IOS26ButtonIcon：\n${violations.join('\n')}',
    );
  });
}

List<String> _findIconTopLevelColorArgs(String source) {
  final result = <String>[];
  final matches = RegExp(r'\bIcon\s*\(').allMatches(source);

  for (final match in matches) {
    final openParenIndex = source.indexOf('(', match.start);
    if (openParenIndex < 0) continue;

    final closeParenIndex = _findMatchingParen(source, openParenIndex);
    if (closeParenIndex < 0) continue;

    final args = source.substring(openParenIndex + 1, closeParenIndex);
    final topLevelArgs = _splitTopLevelArguments(args);

    for (final argument in topLevelArgs) {
      final trimmed = argument.trim();
      if (!trimmed.startsWith('color:')) continue;
      result.add(trimmed.substring('color:'.length).trim());
    }
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
