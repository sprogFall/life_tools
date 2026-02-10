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
      'lib/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_edit_page.dart',
      'lib/tools/overcooked_kitchen/pages/tabs/overcooked_calendar_tab.dart',
      'lib/tools/overcooked_kitchen/pages/tabs/overcooked_gacha_tab.dart',
      'lib/tools/overcooked_kitchen/pages/tabs/overcooked_meal_tab.dart',
      'lib/tools/overcooked_kitchen/pages/tabs/overcooked_recipes_tab.dart',
      'lib/tools/overcooked_kitchen/pages/tabs/overcooked_wishlist_tab.dart',
      'lib/tools/overcooked_kitchen/widgets/overcooked_date_bar.dart',
      'lib/tools/overcooked_kitchen/widgets/overcooked_recipe_picker_sheet.dart',
      'lib/tools/stockpile_assistant/pages/stock_consumption_edit_page.dart',
      'lib/tools/stockpile_assistant/pages/stock_item_edit_page.dart',
      'lib/tools/stockpile_assistant/pages/stockpile_ai_batch_entry_view.dart',
      'lib/tools/stockpile_assistant/widgets/stockpile_consume_button.dart',
      'lib/tools/tag_manager/pages/tag_manager_tool_page.dart',
      'lib/tools/work_log/pages/calendar/work_log_ai_summary_page.dart',
      'lib/tools/work_log/pages/task/work_log_voice_input_sheet.dart',
      'lib/tools/work_log/pages/task/work_task_detail_page.dart',
    };

    final violations = <String>[];

    for (final path in targetFiles) {
      final content = await File(path).readAsString();
      final colorExpressions = _findCupertinoButtonTopLevelColorArgs(content);
      for (final expression in colorExpressions) {
        final normalized = expression.replaceAll(RegExp(r'\s+'), '');
        final usesSemanticToken =
            expression.contains('buttonColors(') ||
            expression.contains('Button.background');
        final isTransparentPassThrough = normalized == 'Colors.transparent';
        if (!usesSemanticToken && !isTransparentPassThrough) {
          violations.add('$path -> $expression');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下 CupertinoButton 的顶层 color 未走语义按钮 token（应使用 IOS26Theme.buttonColors(...) 的 background，或显式透明透传）：\n${violations.join('\n')}',
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
