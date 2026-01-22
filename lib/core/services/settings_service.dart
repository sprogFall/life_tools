import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/tool_info.dart';
import '../registry/tool_registry.dart';

typedef DatabaseProvider = Future<Database> Function();

/// 应用设置服务：管理工具排序与默认工具配置
class SettingsService extends ChangeNotifier {
  static const String _defaultToolKey = 'default_tool_id';
  static const String _tagManagerToolId = 'tag_manager';
  static const String _workLogToolId = 'work_log';
  static const String _stockpileToolId = 'stockpile_assistant';
  static const String _overcookedToolId = 'overcooked_kitchen';

  final DatabaseProvider _databaseProvider;

  SharedPreferences? _prefs;
  String? _defaultToolId;
  List<String> _toolOrder = [];

  SettingsService({DatabaseProvider? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => DatabaseHelper.instance.database);

  String? get defaultToolId => _defaultToolId;
  List<String> get toolOrder => List.unmodifiable(_toolOrder);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _defaultToolId = _prefs?.getString(_defaultToolKey);
    await _loadToolOrder();
  }

  Future<void> _loadToolOrder() async {
    final db = await _databaseProvider();
    final results = await db.query('tool_order', orderBy: 'sort_index ASC');

    if (results.isEmpty) {
      _toolOrder = ToolRegistry.instance.tools.map((t) => t.id).toList();
      _toolOrder = _ensureTagManagerLast(_toolOrder);
      await _saveToolOrder();
      return;
    }

    final loaded = results.map((row) => row['tool_id'] as String).toList();
    final fixed = _fixToolOrderForNewTools(loaded);
    _toolOrder = fixed;
    if (!listEquals(loaded, fixed)) {
      await _saveToolOrder();
    }
  }

  Future<void> _saveToolOrder() async {
    final db = await _databaseProvider();
    await db.delete('tool_order');

    for (var i = 0; i < _toolOrder.length; i++) {
      await db.insert('tool_order', {
        'tool_id': _toolOrder[i],
        'sort_index': i,
      });
    }
  }

  List<ToolInfo> getSortedTools() {
    final allTools = ToolRegistry.instance.tools;
    final sortedTools = <ToolInfo>[];

    for (final toolId in _toolOrder) {
      final tool = allTools.where((t) => t.id == toolId).firstOrNull;
      if (tool != null) sortedTools.add(tool);
    }

    // 兜底：如果有新注册工具未写入排序列表，则按规则插入
    var added = false;
    for (final tool in allTools) {
      if (!_toolOrder.contains(tool.id)) {
        _insertNewToolId(_toolOrder, tool.id);
        added = true;
      }
    }
    _toolOrder = _ensureTagManagerLast(_toolOrder);

    if (added) {
      sortedTools
        ..clear()
        ..addAll(getSortedTools());
    }
    return sortedTools;
  }

  Future<void> updateToolOrder(List<String> newOrder) async {
    _toolOrder = _ensureTagManagerLast(newOrder);
    await _saveToolOrder();
    notifyListeners();
  }

  Future<void> setDefaultTool(String? toolId) async {
    _defaultToolId = toolId;
    if (toolId == null) {
      await _prefs?.remove(_defaultToolKey);
    } else {
      await _prefs?.setString(_defaultToolKey, toolId);
    }
    notifyListeners();
  }

  ToolInfo? getDefaultTool() {
    if (_defaultToolId == null) return null;
    return ToolRegistry.instance.getById(_defaultToolId!);
  }

  static List<String> _fixToolOrderForNewTools(List<String> loaded) {
    final order = _ensureTagManagerLast(_dedupeStrings(loaded).toList());

    final known = ToolRegistry.instance.tools.map((t) => t.id).toList();
    for (final toolId in known) {
      if (!order.contains(toolId)) {
        _insertNewToolId(order, toolId);
      }
    }

    return _ensureTagManagerLast(order);
  }

  static void _insertNewToolId(List<String> order, String toolId) {
    if (order.contains(toolId)) return;

    final tagIndex = order.indexOf(_tagManagerToolId);

    if (toolId == _stockpileToolId) {
      final workIndex = order.indexOf(_workLogToolId);
      if (workIndex >= 0) {
        order.insert(workIndex + 1, toolId);
        return;
      }
    }

    if (toolId == _overcookedToolId) {
      final stockIndex = order.indexOf(_stockpileToolId);
      if (stockIndex >= 0) {
        order.insert(stockIndex + 1, toolId);
        return;
      }
      final workIndex = order.indexOf(_workLogToolId);
      if (workIndex >= 0) {
        order.insert(workIndex + 1, toolId);
        return;
      }
    }

    if (tagIndex >= 0) {
      order.insert(tagIndex, toolId);
    } else {
      order.add(toolId);
    }
  }

  static List<String> _ensureTagManagerLast(List<String> order) {
    final cleaned = order.where((id) => id != _tagManagerToolId).toList();
    if (order.contains(_tagManagerToolId)) cleaned.add(_tagManagerToolId);
    return cleaned;
  }

  static Iterable<String> _dedupeStrings(Iterable<String> values) sync* {
    final seen = <String>{};
    for (final v in values) {
      if (seen.add(v)) yield v;
    }
  }
}
