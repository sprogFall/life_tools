import 'package:flutter/cupertino.dart';

import '../registry/tool_registry.dart';
import 'models/app_message.dart';

class MessageNavigation {
  static String? toolIdFor(AppMessage message) {
    final route = message.route?.trim();
    if (route == null || route.isEmpty) return message.toolId;

    if (route.startsWith('tool://')) {
      final id = route.substring('tool://'.length).trim();
      return id.isEmpty ? message.toolId : id;
    }

    return route;
  }

  static bool canOpen(AppMessage message) {
    final toolId = toolIdFor(message);
    if (toolId == null || toolId.trim().isEmpty) return false;
    return ToolRegistry.instance.getById(toolId) != null;
  }

  static void open(BuildContext context, AppMessage message) {
    final toolId = toolIdFor(message);
    if (toolId == null || toolId.trim().isEmpty) return;
    final tool = ToolRegistry.instance.getById(toolId);
    if (tool == null) return;

    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => tool.pageBuilder()));
  }
}
