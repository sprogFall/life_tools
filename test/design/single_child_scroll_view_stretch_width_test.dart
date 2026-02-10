import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('业务页面中 SingleChildScrollView 的直系 Column 需要声明横向拉伸', () async {
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
      final ranges = _findSingleChildScrollViewColumnRanges(content);
      for (final range in ranges) {
        final args = content.substring(range.start, range.end);
        final hasStretch = _singleChildScrollViewChildColumnHasStretch(args);
        if (!hasStretch) {
          violations.add(path);
          break;
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下文件存在 SingleChildScrollView(child: Column(...)) 但未配置 crossAxisAlignment: CrossAxisAlignment.stretch，可能出现卡片宽度不占满：\n${violations.join('\n')}',
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

class _TextRange {
  final int start;
  final int end;

  const _TextRange(this.start, this.end);
}

List<_TextRange> _findSingleChildScrollViewColumnRanges(String source) {
  const marker = 'SingleChildScrollView(';
  final ranges = <_TextRange>[];
  var searchStart = 0;

  while (true) {
    final callStart = source.indexOf(marker, searchStart);
    if (callStart < 0) break;

    final openParenIndex = callStart + marker.length - 1;
    final closeParenIndex = _findMatchingParen(source, openParenIndex);
    if (closeParenIndex < 0) break;

    final argsStart = openParenIndex + 1;
    final argsEnd = closeParenIndex;
    final args = source.substring(argsStart, argsEnd);

    final topLevelArgs = _splitTopLevelArguments(args);
    final childArg = topLevelArgs
        .map((s) => s.trim())
        .where((s) => s.startsWith('child:'))
        .cast<String?>()
        .firstWhere((s) => s != null, orElse: () => null);

    if (childArg != null) {
      final childExpr = childArg.substring('child:'.length).trimLeft();
      if (childExpr.startsWith('Column(')) {
        ranges.add(_TextRange(argsStart, argsEnd));
      }
    }

    searchStart = closeParenIndex + 1;
  }

  return ranges;
}

bool _singleChildScrollViewChildColumnHasStretch(String args) {
  final childIndex = args.indexOf('child:');
  if (childIndex < 0) return true;

  final childExpr = args.substring(childIndex + 'child:'.length).trimLeft();
  if (!childExpr.startsWith('Column(')) {
    return true;
  }

  final openParenIndex = args.indexOf('(', childIndex);
  if (openParenIndex < 0) return true;

  final closeParenIndex = _findMatchingParen(args, openParenIndex);
  if (closeParenIndex < 0) return true;

  final columnArgs = args.substring(openParenIndex + 1, closeParenIndex);
  final topLevelArgs = _splitTopLevelArguments(columnArgs);

  for (final argument in topLevelArgs) {
    final trimmed = argument.trim();
    if (!trimmed.startsWith('crossAxisAlignment:')) continue;
    return trimmed.contains('CrossAxisAlignment.stretch');
  }

  return false;
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
