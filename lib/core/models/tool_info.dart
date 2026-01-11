import 'package:flutter/material.dart';
import '../sync/interfaces/tool_sync_provider.dart';

/// 工具信息模型，定义每个工具的基本属性
class ToolInfo {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final Widget Function() pageBuilder;
  final ToolSyncProvider? syncProvider; // 可选的同步提供者

  const ToolInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.pageBuilder,
    this.syncProvider, // 可选参数，保持向后兼容
  });

  /// 判断工具是否支持同步
  bool get supportSync => syncProvider != null;
}
