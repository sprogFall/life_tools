import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/tool_info.dart';
import '../registry/tool_registry.dart';

/// 应用设置服务，管理工具排序和默认工具配置
class SettingsService extends ChangeNotifier {
  static const String _defaultToolKey = 'default_tool_id';

  SharedPreferences? _prefs;
  String? _defaultToolId;
  List<String> _toolOrder = [];

  String? get defaultToolId => _defaultToolId;
  List<String> get toolOrder => List.unmodifiable(_toolOrder);

  /// 初始化设置服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _defaultToolId = _prefs?.getString(_defaultToolKey);
    await _loadToolOrder();
  }

  /// 加载工具排序
  Future<void> _loadToolOrder() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query('tool_order', orderBy: 'sort_index ASC');

    if (results.isEmpty) {
      // 首次使用，按默认顺序初始化
      _toolOrder = ToolRegistry.instance.tools.map((t) => t.id).toList();
      await _saveToolOrder();
    } else {
      _toolOrder = results.map((row) => row['tool_id'] as String).toList();
    }
  }

  /// 保存工具排序到数据库
  Future<void> _saveToolOrder() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('tool_order');

    for (var i = 0; i < _toolOrder.length; i++) {
      await db.insert('tool_order', {
        'tool_id': _toolOrder[i],
        'sort_index': i,
      });
    }
  }

  /// 获取排序后的工具列表
  List<ToolInfo> getSortedTools() {
    final allTools = ToolRegistry.instance.tools;
    final sortedTools = <ToolInfo>[];

    for (final toolId in _toolOrder) {
      final tool = allTools.where((t) => t.id == toolId).firstOrNull;
      if (tool != null) {
        sortedTools.add(tool);
      }
    }

    // 添加新注册但未在排序列表中的工具
    for (final tool in allTools) {
      if (!_toolOrder.contains(tool.id)) {
        sortedTools.add(tool);
        _toolOrder.add(tool.id);
      }
    }

    return sortedTools;
  }

  /// 更新工具排序
  Future<void> updateToolOrder(List<String> newOrder) async {
    _toolOrder = List.from(newOrder);
    await _saveToolOrder();
    notifyListeners();
  }

  /// 设置默认打开的工具
  Future<void> setDefaultTool(String? toolId) async {
    _defaultToolId = toolId;
    if (toolId == null) {
      await _prefs?.remove(_defaultToolKey);
    } else {
      await _prefs?.setString(_defaultToolKey, toolId);
    }
    notifyListeners();
  }

  /// 获取默认工具
  ToolInfo? getDefaultTool() {
    if (_defaultToolId == null) return null;
    return ToolRegistry.instance.getById(_defaultToolId!);
  }
}
