import 'package:flutter/cupertino.dart';
import '../models/tool_info.dart';
import '../theme/ios26_theme.dart';
import '../../tools/placeholder_tool_page.dart';
import '../../tools/work_log/pages/work_log_tool_page.dart';

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
      description: '日常工作管理',
      icon: CupertinoIcons.briefcase,
      color: IOS26Theme.toolBlue,
      pageBuilder: () => const WorkLogToolPage(),
    ));

    register(ToolInfo(
      id: 'review',
      name: '复盘笔记',
      description: '工作和生活复盘记录',
      icon: CupertinoIcons.doc_text,
      color: IOS26Theme.toolOrange,
      pageBuilder: () => const PlaceholderToolPage(toolName: '复盘笔记'),
    ));

    register(ToolInfo(
      id: 'expense',
      name: '日常开销',
      description: '记录日常消费支出',
      icon: CupertinoIcons.creditcard,
      color: IOS26Theme.toolRed,
      pageBuilder: () => const PlaceholderToolPage(toolName: '日常开销'),
    ));

    register(ToolInfo(
      id: 'income',
      name: '收入记录',
      description: '记录各类收入来源',
      icon: CupertinoIcons.chart_bar_alt_fill,
      color: IOS26Theme.toolGreen,
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
