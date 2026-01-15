import 'package:flutter/cupertino.dart';
import '../models/tool_info.dart';
import '../theme/ios26_theme.dart';
import '../../tools/placeholder_tool_page.dart';
import '../../tools/work_log/pages/work_log_tool_page.dart';
import '../../tools/work_log/repository/work_log_repository.dart';
import '../../tools/work_log/sync/work_log_sync_provider.dart';
import '../../core/tag/repository/tag_repository.dart';
import '../../core/tag/sync/tag_sync_provider.dart';
import '../../tools/tag_management/tag_management_tool_page.dart';

/// 工具注册表，管理所有可用工具
class ToolRegistry {
  ToolRegistry._();
  static final ToolRegistry instance = ToolRegistry._();

  final List<ToolInfo> _tools = [];

  List<ToolInfo> get tools => List.unmodifiable(_tools);

  /// 初始化注册所有工具
  void registerAll() {
    _tools.clear();

    // 创建Tag的Repository和SyncProvider
    final tagRepository = TagRepository();
    final tagSyncProvider = TagSyncProvider(repository: tagRepository);

    // 注册标签管理工具（支持同步）
    register(ToolInfo(
      id: 'tag_management',
      name: '标签管理',
      description: '统一管理所有标签',
      icon: CupertinoIcons.tag,
      color: IOS26Theme.toolPurple,
      pageBuilder: () => const TagManagementToolPage(),
      syncProvider: tagSyncProvider,
    ));

    // 创建WorkLog的Repository和SyncProvider
    final workLogRepository = WorkLogRepository();
    final workLogSyncProvider = WorkLogSyncProvider(repository: workLogRepository);

    // 注册工作记录工具（支持同步）
    register(ToolInfo(
      id: 'work_log',
      name: '工作记录',
      description: '日常工作管理',
      icon: CupertinoIcons.briefcase,
      color: IOS26Theme.toolBlue,
      pageBuilder: () => const WorkLogToolPage(),
      syncProvider: workLogSyncProvider, // 添加同步支持
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
