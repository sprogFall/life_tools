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
    // 先本地更新顺序，避免闪烁
    final reordered = <TagWithTools>[];
    for (final id in tagIds) {
      final item = _all.firstWhere((e) => e.tag.id == id);
      reordered.add(item);
    }
    _all = reordered;
    notifyListeners();
    // 异步保存到数据库
    await _repository.reorderTags(tagIds);
  }
}
