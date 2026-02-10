import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('页面层 CupertinoTextField 不允许使用 decoration: null', () async {
    final violations = <String>[];

    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final source = await file.readAsString();
      final callOffsets = _findNullDecorationCupertinoTextFields(source);
      for (final offset in callOffsets) {
        final line = _lineNumberAt(source, offset);
        violations.add('${file.path}:$line');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下页面层输入框使用了 decoration: null，暗色模式可能导致输入区边界不清晰：\n${violations.join('\n')}',
    );
  });
}

List<int> _findNullDecorationCupertinoTextFields(String source) {
  const marker = 'CupertinoTextField(';
  final result = <int>[];
  var searchStart = 0;

  while (true) {
    final callStart = source.indexOf(marker, searchStart);
    if (callStart < 0) break;

    final openParenIndex = callStart + marker.length - 1;
    final closeParenIndex = _findMatchingParen(source, openParenIndex);
    if (closeParenIndex < 0) break;

    final args = source.substring(openParenIndex + 1, closeParenIndex);
    final topLevelArgs = _splitTopLevelArguments(args);

    final hasNullDecoration = topLevelArgs.any((argument) {
      final normalized = argument.trim().replaceAll(RegExp(r'\s+'), '');
      return normalized == 'decoration:null';
    });

    if (hasNullDecoration) {
      result.add(callStart);
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

int _lineNumberAt(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}
