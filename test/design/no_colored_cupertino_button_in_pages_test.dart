import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('业务页面不应直接使用 CupertinoButton(color: ...)', () async {
    final targetFiles = <String>{
      ..._collectDartFiles('lib/pages'),
      ..._collectDartFiles('lib/tools'),
      ..._collectDartFiles('lib/core/backup/pages'),
      ..._collectDartFiles('lib/core/messages/pages'),
      ..._collectDartFiles('lib/core/sync/pages'),
      ..._collectDartFiles('lib/core/tags/widgets'),
    };

    final violations = <String>[];

    for (final path in targetFiles) {
      final content = await File(path).readAsString();
      final colorExpressions = _findCupertinoButtonTopLevelColorArgs(content);
      for (final expression in colorExpressions) {
        violations.add('$path -> $expression');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下业务页面仍在直接使用 CupertinoButton(color: ...)，请改为 IOS26Button / IOS26IconButton 统一组件：\n${violations.join('\n')}',
    );
  });
}

Set<String> _collectDartFiles(String rootPath) {
  final root = Directory(rootPath);
  if (!root.existsSync()) {
    return {};
  }

  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path.replaceAll('\\\\', '/'))
      .toSet();
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
