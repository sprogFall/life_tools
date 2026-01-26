/// 工具导入顺序：部分工具（如标签）需要优先导入，避免引用关系缺失。
List<MapEntry<String, T>> sortToolEntries<T>(Map<String, T> toolsData) {
  final entries = toolsData.entries.toList();
  entries.sort((a, b) {
    if (a.key == 'tag_manager' && b.key != 'tag_manager') return -1;
    if (b.key == 'tag_manager' && a.key != 'tag_manager') return 1;
    return 0;
  });
  return entries;
}
