import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('关键页面的 CupertinoTextField 必须使用 IOS26Theme.textFieldDecoration', () async {
    const targetFiles = <String>{
      'lib/core/ui/app_dialogs.dart',
      'lib/pages/ai_settings_page.dart',
      'lib/core/sync/pages/sync_settings_page.dart',
      'lib/pages/obj_store_settings_page.dart',
      'lib/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_edit_page.dart',
      'lib/tools/overcooked_kitchen/pages/tabs/overcooked_meal_tab.dart',
      'lib/tools/work_log/pages/task/work_task_edit_page.dart',
      'lib/tools/work_log/pages/task/work_log_voice_input_sheet.dart',
      'lib/tools/work_log/pages/time/work_time_entry_edit_page.dart',
      'lib/tools/stockpile_assistant/pages/stock_consumption_edit_page.dart',
      'lib/tools/stockpile_assistant/pages/stock_item_edit_page.dart',
      'lib/tools/stockpile_assistant/widgets/stockpile_batch_entry_ui.dart',
    };

    final violations = <String>[];

    for (final path in targetFiles) {
      final source = await File(path).readAsString();
      final infos = _findCupertinoTextFieldDecoration(source);
      for (final info in infos) {
        if (!info.hasDecoration) {
          violations.add('$path:${info.line} -> 缺少 decoration 参数');
          continue;
        }
        final decoration = info.decorationExpression!;
        final normalized = decoration.replaceAll(RegExp(r'\s+'), '');
        final usesThemeDecoration =
            normalized.startsWith('IOS26Theme.textFieldDecoration(') ||
            normalized == 'IOS26Theme.textFieldDecoration()';
        if (!usesThemeDecoration) {
          violations.add('$path:${info.line} -> decoration: $decoration');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下输入框未统一使用 IOS26Theme.textFieldDecoration，可能导致暗色模式分隔不清晰：\n${violations.join('\n')}',
    );
  });
}

class _FieldDecorationInfo {
  final int line;
  final bool hasDecoration;
  final String? decorationExpression;

  const _FieldDecorationInfo({
    required this.line,
    required this.hasDecoration,
    required this.decorationExpression,
  });
}

List<_FieldDecorationInfo> _findCupertinoTextFieldDecoration(String source) {
  const marker = 'CupertinoTextField(';
  final result = <_FieldDecorationInfo>[];
  var searchStart = 0;

  while (true) {
    final callStart = source.indexOf(marker, searchStart);
    if (callStart < 0) break;

    final openParenIndex = callStart + marker.length - 1;
    final closeParenIndex = _findMatchingParen(source, openParenIndex);
    if (closeParenIndex < 0) break;

    final args = source.substring(openParenIndex + 1, closeParenIndex);
    final topLevelArgs = _splitTopLevelArguments(args);

    String? decorationExpression;
    for (final argument in topLevelArgs) {
      final trimmed = argument.trim();
      if (!trimmed.startsWith('decoration:')) continue;
      decorationExpression = trimmed.substring('decoration:'.length).trim();
      break;
    }

    result.add(
      _FieldDecorationInfo(
        line: _lineNumberAt(source, callStart),
        hasDecoration: decorationExpression != null,
        decorationExpression: decorationExpression,
      ),
    );

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
