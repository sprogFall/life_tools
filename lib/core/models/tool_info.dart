import 'package:flutter/material.dart';

/// 工具信息模型，定义每个工具的基本属性
class ToolInfo {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final Widget Function() pageBuilder;

  const ToolInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.pageBuilder,
  });
}
