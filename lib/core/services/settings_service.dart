import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/tool_info.dart';
import '../registry/tool_registry.dart';
import '../sync/services/app_config_updated_at.dart';

typedef DatabaseProvider = Future<Database> Function();

/// 应用设置服务：管理工具排序与默认工具配置
class SettingsService extends ChangeNotifier {
  static const String _defaultToolKey = 'default_tool_id';
  static const String _hiddenToolIdsKey = 'hidden_tool_ids';
  static const String _themeModeKey = 'theme_mode';
  static const String _tagManagerToolId = 'tag_manager';
  static const String _workLogToolId = 'work_log';
  static const String _stockpileToolId = 'stockpile_assistant';
  static const String _overcookedToolId = 'overcooked_kitchen';

  final DatabaseProvider _databaseProvider;

  SharedPreferences? _prefs;
  String? _defaultToolId;
  List<String> _toolOrder = [];
  Set<String> _hiddenToolIds = {};
  ThemeMode _themeMode = ThemeMode.light;

  SettingsService({DatabaseProvider? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => DatabaseHelper.instance.database);

  String? get defaultToolId => _defaultToolId;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkModeEnabled => _themeMode == ThemeMode.dark;
  List<String> get toolOrder => List.unmodifiable(_toolOrder);
  List<String> get hiddenToolIds {
    final ordered = <String>[];
    for (final id in _toolOrder) {
      if (_hiddenToolIds.contains(id)) ordered.add(id);
    }
    for (final id in _hiddenToolIds) {
      if (!ordered.contains(id)) ordered.add(id);
    }
    return List.unmodifiable(ordered);
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _defaultToolId = _prefs?.getString(_defaultToolKey);
    _hiddenToolIds = _loadHiddenToolIds();
    _themeMode = _loadThemeMode();
    await _loadToolOrder();
  }

  Set<String> _loadHiddenToolIds() {
    final raw = _prefs?.getStringList(_hiddenToolIdsKey) ?? const <String>[];
    final known = ToolRegistry.instance.tools.map((t) => t.id).toSet();
    return raw.where(known.contains).toSet();
  }

  ThemeMode _loadThemeMode() {
    final raw = _prefs?.getString(_themeModeKey);
    return switch (raw) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  String _themeModeToStorageValue(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => 'dark',
      _ => 'light',
    };
  }

  Future<void> _saveHiddenToolIds() async {
    final ids = hiddenToolIds;
    await _prefs?.setStringList(_hiddenToolIdsKey, ids);
  }

  Future<void> _touchUpdatedAt() async {
    final prefs = _prefs;
    if (prefs != null) {
      await AppConfigUpdatedAt.touch(prefs);
    }
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

  List<ToolInfo> getHomeTools() {
    return getSortedTools()
        .where((t) => !_hiddenToolIds.contains(t.id))
        .toList(growable: false);
  }

  Future<void> updateToolOrder(List<String> newOrder) async {
    _toolOrder = _ensureTagManagerLast(newOrder);
    await _saveToolOrder();
    await _touchUpdatedAt();
    notifyListeners();
  }

  Future<void> updateHomeToolOrder(List<String> newVisibleOrder) async {
    // 按“旧顺序中的可见位置”替换，从而保留隐藏工具的占位顺序。
    final current = List<String>.from(_toolOrder);
    final visibleInCurrent = current.where(
      (id) => !_hiddenToolIds.contains(id),
    );

    final visibleSet = visibleInCurrent.toSet();
    final normalized = <String>[
      ...newVisibleOrder.where(visibleSet.contains),
      ...visibleInCurrent.where((id) => !newVisibleOrder.contains(id)),
    ];

    var visibleWriteIndex = 0;
    final merged = current
        .map((id) {
          if (_hiddenToolIds.contains(id)) return id;
          if (visibleWriteIndex >= normalized.length) return id;
          return normalized[visibleWriteIndex++];
        })
        .toList(growable: false);

    await updateToolOrder(merged);
  }

  bool isToolHidden(String toolId) => _hiddenToolIds.contains(toolId);

  Future<void> setToolHidden(String toolId, bool hidden) async {
    final known = ToolRegistry.instance.getById(toolId);
    if (known == null) return;

    final changed = hidden
        ? _hiddenToolIds.add(toolId)
        : _hiddenToolIds.remove(toolId);
    if (!changed) return;

    await _saveHiddenToolIds();
    await _touchUpdatedAt();
    notifyListeners();
  }

  Future<void> setHiddenToolIds(Iterable<String> toolIds) async {
    final known = ToolRegistry.instance.tools.map((t) => t.id).toSet();
    final next = toolIds.where(known.contains).toSet();
    if (setEquals(next, _hiddenToolIds)) return;
    _hiddenToolIds = next;
    await _saveHiddenToolIds();
    await _touchUpdatedAt();
    notifyListeners();
  }

  Future<void> setDefaultTool(String? toolId) async {
    _defaultToolId = toolId;
    if (toolId == null) {
      await _prefs?.remove(_defaultToolKey);
    } else {
      await _prefs?.setString(_defaultToolKey, toolId);
    }
    await _touchUpdatedAt();
    notifyListeners();
  }

  ToolInfo? getDefaultTool() {
    if (_defaultToolId == null) return null;
    return ToolRegistry.instance.getById(_defaultToolId!);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final next = mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == next) return;
    _themeMode = next;
    await _prefs?.setString(_themeModeKey, _themeModeToStorageValue(next));
    await _touchUpdatedAt();
    notifyListeners();
  }

  Future<void> setDarkModeEnabled(bool enabled) async {
    await setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
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
