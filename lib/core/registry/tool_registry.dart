import 'package:flutter/material.dart';
import '../models/tool_info.dart';
import '../../tools/placeholder_tool_page.dart';

/// 工具注册表，管理所有可用工具
class ToolRegistry {
  ToolRegistry._();
  static final ToolRegistry instance = ToolRegistry._();

  final List<ToolInfo> _tools = [];

  List<ToolInfo> get tools => List.unmodifiable(_tools);

  /// 初始化注册所有工具
  void registerAll() {
    _tools.clear();

    // 注册示例工具（后续可以在这里添加更多工具）
    register(ToolInfo(
      id: 'work_log',
      name: '工作记录',
      description: '记录和管理日常工作内容',
      icon: Icons.work_outline,
      color: Colors.blue,
      pageBuilder: () => const PlaceholderToolPage(toolName: '工作记录'),
    ));

    register(ToolInfo(
      id: 'review',
      name: '复盘笔记',
      description: '工作和生活复盘记录',
      icon: Icons.rate_review_outlined,
      color: Colors.orange,
      pageBuilder: () => const PlaceholderToolPage(toolName: '复盘笔记'),
    ));

    register(ToolInfo(
      id: 'expense',
      name: '日常开销',
      description: '记录日常消费支出',
      icon: Icons.account_balance_wallet_outlined,
      color: Colors.red,
      pageBuilder: () => const PlaceholderToolPage(toolName: '日常开销'),
    ));

    register(ToolInfo(
      id: 'income',
      name: '收入记录',
      description: '记录各类收入来源',
      icon: Icons.trending_up,
      color: Colors.green,
      pageBuilder: () => const PlaceholderToolPage(toolName: '收入记录'),
    ));
  }

  /// 注册单个工具
  void register(ToolInfo tool) {
    _tools.add(tool);
  }

  /// 根据ID获取工具
  ToolInfo? getById(String id) {
    try {
      return _tools.firstWhere((tool) => tool.id == id);
    } catch (_) {
      return null;
    }
  }
}
