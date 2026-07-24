import '../models/work_photo_capture_item.dart';
import '../models/work_photo_hierarchy_level.dart';
import '../models/work_photo_template.dart';

String buildWorkPhotoAiContext({
  required DateTime now,
  required WorkPhotoTemplate template,
  required Iterable<WorkPhotoHierarchyLevel> levels,
  required Iterable<WorkPhotoCaptureItem> items,
  int maxNodes = 80,
}) {
  final activeLevels = levels.where((e) => !e.isArchived).toList()
    ..sort((a, b) {
      final byParent = (a.parentLevelId ?? -1).compareTo(b.parentLevelId ?? -1);
      if (byParent != 0) return byParent;
      final bySort = a.sortIndex.compareTo(b.sortIndex);
      if (bySort != 0) return bySort;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
  final activeItems = items.where((e) => !e.isArchived).toList()
    ..sort((a, b) {
      final byParent = (a.parentLevelId ?? -1).compareTo(b.parentLevelId ?? -1);
      if (byParent != 0) return byParent;
      final bySort = a.sortIndex.compareTo(b.sortIndex);
      if (bySort != 0) return bySort;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

  final lines = <String>[];
  var remaining = maxNodes;

  void appendItem(WorkPhotoCaptureItem item, int depth) {
    if (remaining <= 0) return;
    remaining -= 1;
    final indent = '  ' * depth;
    final id = item.id == null ? '' : ' [id=${item.id}]';
    final max = item.maxCount == null ? '不限' : '${item.maxCount}';
    lines.add(
      '$indent- item$id ${item.name}'
      '（min=${item.minCount}, max=$max）',
    );
  }

  void appendLevel(WorkPhotoHierarchyLevel level, int depth) {
    if (remaining <= 0) return;
    remaining -= 1;
    final indent = '  ' * depth;
    final id = level.id == null ? '' : ' [id=${level.id}]';
    lines.add(
      '$indent- level$id ${level.name}'
      '（required=${level.isRequired}）',
    );
    final levelId = level.id;
    if (levelId == null) return;
    final childLevels = activeLevels.where((e) => e.parentLevelId == levelId);
    final childItems = activeItems.where((e) => e.parentLevelId == levelId);
    for (final child in childLevels) {
      appendLevel(child, depth + 1);
    }
    for (final item in childItems) {
      appendItem(item, depth + 1);
    }
  }

  for (final level in activeLevels.where((e) => e.parentLevelId == null)) {
    appendLevel(level, 0);
  }
  for (final item in activeItems.where((e) => e.parentLevelId == null)) {
    appendItem(item, 0);
  }

  final treeText = lines.isEmpty ? '- (空)' : lines.join('\n');
  final date =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  return [
    '当前日期：$date',
    '模板：${template.name}',
    '当前模板树（仅供参考；你输出的配置会整体覆盖，不是增量修改）：',
    treeText,
  ].join('\n');
}
