import 'package:flutter/foundation.dart';

import 'models/tag.dart';
import 'models/tag_with_tools.dart';
import 'tag_repository.dart';

/// 标签公共服务：供各工具查询用户为该工具配置的标签
class TagService extends ChangeNotifier {
  final TagRepository _repository;

  TagService({TagRepository? repository})
    : _repository = repository ?? TagRepository();

  bool _loading = false;
  bool get loading => _loading;

  List<TagWithTools> _all = const [];
  List<TagWithTools> get allTags => List.unmodifiable(_all);

  Future<void> refreshAll() async {
    _loading = true;
    notifyListeners();
    try {
      _all = await _repository.listAllTagsWithTools();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<Tag>> listTagsForTool(String toolId) {
    return _repository.listTagsForTool(toolId);
  }

  Future<int> createTag({
    required String name,
    required List<String> toolIds,
    int? color,
  }) async {
    final id = await _repository.createTag(
      name: name,
      toolIds: toolIds,
      color: color,
    );
    await refreshAll();
    return id;
  }

  Future<void> updateTag({
    required int tagId,
    required String name,
    required List<String> toolIds,
    int? color,
  }) async {
    await _repository.updateTag(
      tagId: tagId,
      name: name,
      toolIds: toolIds,
      color: color,
    );
    await refreshAll();
  }

  Future<void> deleteTag(int tagId) async {
    await _repository.deleteTag(tagId);
    await refreshAll();
  }

  Future<void> reorderTags(List<int> tagIds) async {
    if (_all.isEmpty) return;

    // 先本地更新顺序，避免闪烁；同时兜底处理：入参缺失/重复/包含未知 id
    final byId = <int, TagWithTools>{
      for (final item in _all)
        if (item.tag.id != null) item.tag.id!: item,
    };

    final used = <int>{};
    final normalizedIds = <int>[];
    for (final id in tagIds) {
      if (byId.containsKey(id) && used.add(id)) {
        normalizedIds.add(id);
      }
    }
    for (final item in _all) {
      final id = item.tag.id;
      if (id != null && used.add(id)) {
        normalizedIds.add(id);
      }
    }

    final reordered = normalizedIds.map((id) => byId[id]!).toList();
    if (reordered.length != _all.length) {
      // 极端情况下（例如本地缓存里存在 null id），直接刷新以恢复一致性
      await refreshAll();
      return;
    }

    _all = reordered;
    notifyListeners();

    try {
      await _repository.reorderTags(normalizedIds);
    } catch (_) {
      // 保存失败时回滚到数据库状态，避免 UI 与数据不一致
      await refreshAll();
    }
  }
}
