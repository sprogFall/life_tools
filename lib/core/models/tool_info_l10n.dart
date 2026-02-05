import 'package:life_tools/l10n/app_localizations.dart';

import 'tool_info.dart';

extension ToolInfoL10n on ToolInfo {
  String displayName(AppLocalizations l10n) {
    return switch (id) {
      'work_log' => l10n.tool_work_log_name,
      'stockpile_assistant' => l10n.tool_stockpile_name,
      'overcooked_kitchen' => l10n.tool_overcooked_name,
      'tag_manager' => l10n.tool_tag_manager_name,
      _ => name,
    };
  }

  String displayDescription(AppLocalizations l10n) {
    return switch (id) {
      'work_log' => l10n.tool_work_log_desc,
      'stockpile_assistant' => l10n.tool_stockpile_desc,
      'overcooked_kitchen' => l10n.tool_overcooked_desc,
      'tag_manager' => l10n.tool_tag_manager_desc,
      _ => description,
    };
  }
}
