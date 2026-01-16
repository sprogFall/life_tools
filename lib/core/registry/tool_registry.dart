import 'package:flutter/cupertino.dart';
import '../models/tool_info.dart';
import '../tags/tag_repository.dart';
import '../tags/tag_sync_provider.dart';
import '../theme/ios26_theme.dart';
import '../../tools/stockpile_assistant/pages/stockpile_tool_page.dart';
import '../../tools/stockpile_assistant/repository/stockpile_repository.dart';
import '../../tools/stockpile_assistant/sync/stockpile_sync_provider.dart';
import '../../tools/tag_manager/pages/tag_manager_tool_page.dart';
import '../../tools/work_log/pages/work_log_tool_page.dart';
import '../../tools/work_log/repository/work_log_repository.dart';
import '../../tools/work_log/sync/work_log_sync_provider.dart';

/// 工具注册表，管理所有可用工具
class ToolRegistry {
  ToolRegistry._();
  static final ToolRegistry instance = ToolRegistry._();

  final List<ToolInfo> _tools = [];

  List<ToolInfo> get tools => List.unmodifiable(_tools);

  /// 初始化注册所有工具
  void registerAll() {
    _tools.clear();

    // 创建WorkLog的Repository和SyncProvider
    // 创建标签管理的 Repository 和 SyncProvider（供全局工具复用）
    final tagRepository = TagRepository();
    final tagSyncProvider = TagSyncProvider(repository: tagRepository);

    final workLogRepository = WorkLogRepository();
    final workLogSyncProvider = WorkLogSyncProvider(
      repository: workLogRepository,
      tagRepository: tagRepository,
    );

    final stockpileRepository = StockpileRepository();
    final stockpileSyncProvider = StockpileSyncProvider(
      repository: stockpileRepository,
      tagRepository: tagRepository,
    );

    // 注册工作记录工具（支持同步）
    register(
      ToolInfo(
        id: 'work_log',
        name: '工作记录',
        description: '日常工作管理',
        icon: CupertinoIcons.briefcase,
        color: IOS26Theme.toolBlue,
        pageBuilder: () => const WorkLogToolPage(),
        syncProvider: workLogSyncProvider, // 添加同步支持
      ),
    );

    // 注册囤货助手（放在工作记录之后）
    register(
      ToolInfo(
        id: 'stockpile_assistant',
        name: '囤货助手',
        description: '家庭库存与临期提醒',
        icon: CupertinoIcons.cube_box,
        color: IOS26Theme.toolGreen,
        pageBuilder: () => const StockpileToolPage(),
        syncProvider: stockpileSyncProvider,
      ),
    );

    // 注册标签管理工具（放到最后）
    register(
      ToolInfo(
        id: 'tag_manager',
        name: '标签管理',
        description: '公共标签维护',
        icon: CupertinoIcons.tag,
        color: IOS26Theme.toolPurple,
        pageBuilder: () => const TagManagerToolPage(),
        syncProvider: tagSyncProvider,
      ),
    );
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
